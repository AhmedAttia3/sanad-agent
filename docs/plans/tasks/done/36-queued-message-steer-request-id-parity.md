---
title: "Authoritative Steer, Queue, and Stop Draft Recovery"
description: "جعل الوكيل صاحب قرار steer/queue/think، توحيد request-id، عرض pending steer داخل المحادثة وإلغاؤها بأمان، وإدارة queue وStop draft recovery دون فقد نص المستخدم."
status: "completed"
completed_at: "2026-07-15"
priority: "high"
scope: "client + agent protocol + durable queue and pending-steer state"
depends_on: "Task 35 terminal commit and safe admission consistency; Task 31 completed"
---

# Task 36: Authoritative Steer, Queue, and Stop Draft Recovery

## 1. نتيجة إعادة التقييم

المشكلة ليست اختلاف `request_id` وحده. التدفق الحالي يحتوي خمس فجوات مترابطة:

1. زر `Steer` في `QueuedMessagesBox` يرسل `CanonicalEvent.id` ذي بادئة
   `user_` بدل `metadata.request_id` الخام الذي يملكه daemon.
2. العميل يقرر حاليًا steer عبر `mode=steer`، بينما القرار النهائي يجب أن يكون
   للوكيل وفق حالة الجولة لحظة وصول الأمر.
3. مسار steer يستدعي `getIt<AgentRunner>` المسجل كـfactory بدل استهداف
   `ActiveRun.agentRunner` المالك للتنفيذ الجاري؛ الاختبارات التي تعيد mock
   واحدًا قد تخفي هذا الفرق.
4. لا يوجد أمر authoritative لحذف رسالة queued بعينها، ولا outcome دائم يعيد
   pending steers والرسائل queued إلى draft عند Stop.
5. `SteerCoordinator` يحتفظ حاليًا بـ`PendingSteer` داخل قائمة متطايرة، ولا
   يعرّض lifecycle قابلة للعرض أو الإلغاء. لذلك لا يستطيع العميل تمييز steer
   التي تنتظر نقطة الحقن من steer دخلت فعلًا إلى model context، ولا يستطيع حذف
   الأولى بأمان من داخل timeline.

### 1.1 تثبيت المالكين وفق الكود الحالي

- `SessionRunOrchestrator` يملك تصنيف الطلب إلى think/queue/steer والوصول إلى
  `ActiveRun` الحالية.
- `ActiveRun.agentRunner` هي runner الوحيدة المسموح بحقن steer فيها.
- `SteerCoordinator` يملك buffer التنفيذ السريع، لكنه لا يكون وحده مصدر الحقيقة
  الدائم بعد هذه المهمة.
- `session_work_items` يبقى مصدر الحقيقة للعمل queued/active. لا تمثل pending
  steer كـwork item ثانية كي لا تنتهك invariant العمل النشط الواحد لكل جلسة.
- ينشأ owner دائم مستقل لحالة pending steers ونتائج Stop recovery، داخل طبقة
  runtime persistence الحالية، ويربط السجل بـ`session_id + request_id + run_id
  + generation`.
- `DeviceConversationStore` يملك projection العميل لكل جلسة، بينما timeline
  تعرضها ولا تستنتج حالتها محليًا.

## 2. مبادئ الملكية

- العميل يرسل نية المستخدم، ولا يقرر أن الرسالة أصبحت steer أو queued.
- الوكيل يصنف الرسالة من execution snapshot والجولة الفعالة التي يملكها لحظة
  الاستلام، ولا يثق في active boolean أو projection مرسلة من العميل.
- `request_id` الخام هو هوية wire الوحيدة لكل send/queue/steer/delete/stop
  recovery outcome. تبقى بادئة `user_` مفتاح عرض محلي فقط.
- كل انتقال queue أو steer أو delete يملك confirmation صريحة وقابلة للتكرار
  بأمان، ولا تحذف الواجهة شيئًا تفاؤليًا.
- كل pending steer ترتبط بـ`run_id` وgeneration التي قبلتها.
- lifecycle الخاصة بـpending steer أحادية الاتجاه وذات `revision` متزايدة:
  `pending -> delivering -> delivered` أو `pending -> cancelled`. لا يمكن
  إلغاء `delivering` أو `delivered`.
- ظهور الرسالة في timeline لا يعني أنها دخلت model context؛ حالة `pending`
  وحدها تعرض هذا الفرق للمستخدم.
- daemon هو من يحسم سباق cancel مقابل delivery. ضغط زر السلة لا يزيل الرسالة
  من الواجهة قبل confirmation.
- Stop يلغي كل العمل الموجود قبل stop barrier، بينما الطلبات الأحدث من الحاجز
  لا تتأثر.

## 3. سياسة إرسال الرسائل

### 3.1 النية الافتراضية

Enter والضغط على زر الإرسال يرسلان delivery intent باسم `auto`:

- إذا وجدت `ActiveRun` حالية تملك الجلسة وحالتها `running` أو `resuming` ولم
  يبدأ stopping، يقرر الوكيل إدخال الرسالة steer في runner نفسها.
- إذا انتهت الجولة قبل وصول الرسالة، يعاملها الوكيل كـthink عادي ويبدأها فورًا.
- إذا وجدت حالة غير نهائية بلا runner قابلة للـsteer، مثل waiting أو blocked أو
  queued أو stopping، تمر الرسالة عبر owner العادية التي تقرر enqueue أو
  recovery؛ لا تحقن في runner غير موجودة.

### 3.2 نية الطابور الصريحة

Control+Enter وCommand+Enter يرسلان delivery intent باسم `queue`:

- إذا بقي عمل أقدم غير نهائي، يدخل الطلب FIFO queue.
- إذا انتهى العمل الأقدم قبل وصول الطلب، يصبح think عاديًا بدل إنشاء queue بلا
  عنصر أمامها.
- الوكيل هو من يقرر النتيجة ويعيد classification confirmation للعميل.

### 3.3 واجهة العميل

- يظهر tooltip على زر الإرسال فقط في `running` أو `resuming`:
  `Press Enter to steer` و`Ctrl/Cmd+Enter to queue`.
- الضغط على زر الإرسال يساوي Enter.
- خارج التنفيذ الفعلي يبقى Enter وزر الإرسال think عاديين.
- لا تستخدم الواجهة `hasActiveWork` لتقرير steer؛ الحالات غير القابلة للحقن لا
  تعامل كـactive runner.

## 4. ترقية رسالة queued إلى steer

- يرسل زر `Steer` `metadata.request_id` الخام مع fallback تشخيصي فقط عند غيابه.
- يتحقق الوكيل أن request ما زالت queued وتنتمي للجلسة.
- إذا بقيت active run قابلة للـsteer، يزيل الوكيل work item من queue ذريًا
  ويحقن النص في `ActiveRun.agentRunner` نفسها.
- إذا انتهت الجولة، يرقى الطلب إلى think عادي بدل إسقاطه.
- إذا أصبحت الجلسة stopping، يرفض التحويل مؤقتًا ويبقي الرسالة queued كي تدخل
  ضمن Stop draft recovery.
- تكرار الأمر بنفس request id idempotent ولا يحقن النص مرتين.

## 5. دورة حياة pending steer داخل المحادثة

### 5.1 نموذج التخزين والهوية

ينشأ نموذج typed مثل `PendingSteerRecord` بالحقول الآتية:

```text
session_id
request_id
run_id
generation
text
received_at
state: pending | delivering | delivered | cancelled | recovered
revision
updated_at
```

القواعد:

- المفتاح الفريد هو `session_id + request_id`، ولا تستخدم `CanonicalEvent.id`
  كهوية wire.
- يحفظ السجل قبل إرسال classification confirmation بحالة `pending_steer`.
- `run_id + generation` يمنعان runner قديمة من تسليم أو إلغاء steer تخص جولة
  أحدث.
- تخزين pending steer مستقل عن `session_work_items`: الرسالة steering input
  للجولة النشطة وليست work item نشطة ثانية.
- الكتابات idempotent، و`revision` تزيد عند انتقال حقيقي فقط.
- لا يسجل النص أو marker الداخلي في logs. النص يحفظ فقط ضمن state database مثل
  بقية محتوى الرسائل المطلوبة للاستعادة.

### 5.2 القبول والظهور في timeline

عندما يصنف daemon رسالة `auto` على أنها steer:

1. يثبت أن `ActiveRun` ما زالت مالكة `session_id + run_id + generation`.
2. يحفظ `PendingSteerRecord(state=pending)`.
3. يضيف الرسالة إلى `ActiveRun.agentRunner.steerEvent` بالهوية نفسها.
4. يصدر classification confirmation وحدث
   `session.pending_steer_changed` يحملان `request_id`, `run_id`, `generation`,
   `state`, `revision`, `text`, و`received_at`.

يعرض العميل الرسالة داخل timeline في موضع وصولها بوصفها user message مؤقتة:

- أسفلها النص الإنجليزي `Pending`.
- بجواره زر سلة له semantic label باسم `Delete pending message`.
- لا تعامل كرسالة delivered عند بناء history أو model context.
- تبقى keyed بالـ`request_id` الخام حتى تتحول الرسالة نفسها إلى delivered؛ لا
  تنشأ فقاعة ثانية.
- الأحداث المكررة أو الأقدم revision لا تغير العرض ولا تعيد رسالة محذوفة.

### 5.3 الحجز والتسليم

- قبل الحقن، يحجز owner السجل ذريًا من `pending` إلى `delivering` بعد التحقق من
  owner الجولة.
- `SteerCoordinator` يسحب الرسالة المحجوزة بالـ`request_id` ولا يمسح القائمة
  كاملة بصورة لا تسمح بمعرفة ما تم تسليمه.
- بعد إدخال النص في history الصحيحة وحفظها بنجاح، ينقل owner السجل إلى
  `delivered` ويصدر revision جديدة.
- عند `delivered` تزال شارة `Pending` وزر السلة، وتبقى الفقاعة نفسها user
  message عادية في موضعها المنطقي بعد tool result وقبل استجابة LLM التالية.
- إذا فشل حفظ history بعد الحجز، لا يصدر delivered كاذب. يعيد recovery السجل
  إلى نتيجة قابلة للاستعادة أو Stop draft recovery وفق حالة الجولة.
- history/reconnect يعيدان delivered steers من metadata الحالية، ويعيدان pending
  steers من owner الدائم، ثم يدمجهما العميل بالـ`request_id` دون duplication.

### 5.4 حذف pending steer

- زر السلة يرسل `session.pending_steer_cancel` مع `session_id + request_id`
  وrequest id مستقلة لأمر الإلغاء.
- `SessionRunOrchestrator` يتحقق أن السجل يخص `ActiveRun` الحالية، ثم يستدعي
  `cancelPendingSteer(requestId)` على `ActiveRun.agentRunner` نفسها.
- owner ينقل `pending -> cancelled` ويزيلها من buffer في عملية منسقة لا تترك
  سجلًا دائمًا بلا نسخة في الذاكرة أو العكس.
- أثناء انتظار confirmation تبقى الفقاعة ظاهرة، يعطل زرها، ويظهر progress صغير.
- عند `cancelled` تزال الفقاعة فقط بعد الحدث authoritative.
- النتائج الصريحة هي:
  - `cancelled`: لم تدخل model context وحذفت.
  - `delivery_in_progress`: أصبحت `delivering` ولا تدعي الواجهة حذفها.
  - `already_delivered`: تبقى كرسالة مستخدم عادية دون شارة أو سلة.
  - `already_cancelled`: نتيجة idempotent تزيل projection إن بقيت.
  - `stale_owner` أو `not_found`: لا يحقنان النص ولا يحذفان رسالة أحدث، ويعاد
    ترطيب snapshot authoritative.
- يحسم transaction/cancel reservation السباق مع `drainPreApiSteer` و
  `applyPendingSteerToToolResults`: يفوز cancel أو delivery مرة واحدة فقط.

### 5.5 Stop وrestart

- Stop يلتقط سجلات `pending` السابقة للحاجز قبل أي await وينقلها إلى
  `recovered` ضمن outcome الاستعادة؛ لا تظهر بعدها كـPending في timeline.
- السجلات `delivering` تعالج حسب نتيجة الحجز الفعلية ولا تعاد إلى draft على
  أنها غير مسلمة بلا دليل.
- reconnect أثناء بقاء daemon يعمل يعيد pending snapshot والـrevision نفسها.
- restart لا يفقد النص: يربط recovery السجل بالجولة الدائمة؛ إذا تعذر استئناف
  owner نفسها، ينقله إلى Stop/recovery outcome بدل حقنه تلقائيًا في generation
  جديدة.
- استعادة restart لا تكشف النص لكل العملاء: تصدر أولًا مع
  `recovery_reason=daemon_restart` و`claim_required=true` دون items، ثم يفوز
  أول `session.stop_recovery_claim` ذريًا. لا يطبق النص إلا عميل يطابق
  `claimed_by` مع claim id حفظها في draft قبل إرسال الطلب.

## 6. حذف رسالة queued

- يعرض كل صف في `QueuedMessagesBox` زر Delete بجوار Steer.
- يرسل الحذف `session_id + request_id` الخام إلى الوكيل.
- يحذف الوكيل الرسالة فقط إذا بقيت queued، ويلغي work item ويعيد حساب execution
  snapshot داخل transaction واحدة.
- إذا أصبحت running يعيد outcome يطلب Stop بدل حذف عمل جارٍ.
- إذا أصبحت steer أو completed أو cancelled يعيد `already_processed` أو
  `already_removed` بصورة idempotent.
- تبقى الرسالة ظاهرة مع progress على فعلها حتى confirmation؛ لا يوجد حذف محلي
  تفاؤلي.

## 7. Stop واسترجاع المدخلات غير المنفذة

### 7.1 ما الذي يسترجع

عند قبول Stop يلتقط الوكيل، قبل أي await، كل ما كان موجودًا قبل stop barrier:

1. pending steer messages التي قبلتها الجولة ولم تحقن بعد في model context.
2. queued messages غير المطالب بها بترتيب FIFO.

لا تشمل النتيجة steer استهلكت بالفعل، ولا الطلب الجاري الأصلي، ولا رسالة وصلت
بعد stop barrier.

### 7.2 الإلغاء والترتيب

- يحذف الوكيل pending steers الملتقطة من runner ويلغي queued work items
  الملتقطة، ثم يعيد حساب snapshot.
- يرتب payload هكذا: pending steers بترتيب وصولها، ثم queued messages بترتيب
  FIFO.
- يحمل كل عنصر `request_id`, `source`, `text`, `received_at` أو sequence.

### 7.3 دمجها في draft

يعيد الوكيل stop recovery outcome مرتبطة بـstop request id. يطبق العميل
الذي بدأ Stop النتيجة مرة واحدة على draft الجلسة نفسها ولا يرسلها تلقائيًا.

إذا كانت العناصر A وB pending steer، وC وD queued، والنص الحالي E، تصبح قيمة
المدخل:

```text
A
B
C
D
E
```

- تضاف النصوص المسترجعة في البداية ولا تمسح النص الموجود.
- لا تضاف أسطر فارغة زائدة عندما يكون أحد الطرفين فارغًا.
- يحدث `ConversationCacheStore` أولًا ثم يتزامن composer المرتبط بالجلسة.
- إذا لم تكن الجلسة مفتوحة، يحدث draft المخزن لها فقط ولا يكتب في composer
  جلسة أخرى.
- outcome نفسها idempotent؛ reconnect أو ازدواج local/cloud لا يكرر النص.
- لا يطبق عميل ثانٍ النتيجة على draft محلي مختلف لمجرد أنه شاهد queue cleared.

### 7.4 ضمان عدم الفقد

- تبقى stop recovery outcome قابلة للاستعادة حتى يؤكد العميل الذي بدأ Stop
  أنه حفظها في draft.
- إذا انقطع العميل بين Stop واستلام النتيجة، يستعيدها باستخدام stop request id
  بعد reconnect.
- تأكيد العميل يحذف payload المسترجعة من مخزن الوكيل بصورة idempotent.
- إذا كان سبب الاستعادة restart، يحفظ العميل claim id أولًا، ثم يطالب
  بالنتيجة. أول claimant فقط يستلم النص، وتبقى claim قابلة للاستكمال بعد restart
  للعميل نفسه عبر `stopRecoveryClaimIds` المحفوظة في draft.

## 8. النطاق المرحلي

### Gate A — Protocol and identity

- [x] تعريف delivery intents وclassification confirmations وqueue mutation
      outcomes وstop draft recovery outcome.
- [x] تعريف `PendingSteerRecord` وحالاتها وrevision وانتقالاتها المسموحة.
- [x] تعريف `session.pending_steer_changed` و
      `session.pending_steer_cancel` ونتائج الإلغاء الصريحة.
- [x] توحيد request id الخام بين mapper وstore والعميل والوكيل.
- [x] الإبقاء على clients القديمة آمنة: غياب delivery intent يعني `auto`.

### Gate B — Agent-authoritative classification

- [x] نقل قرار auto/queue/think إلى owner واحدة في daemon.
- [x] توجيه steer إلى `ActiveRun.agentRunner` المالكة، لا AgentRunner factory جديدة.
- [x] ربط pending steer بهوية الجولة ومنع late/duplicate injection.
- [x] إضافة owner دائم يحفظ pending steer قبل confirmation ولا ينشئ work item
      نشطة ثانية.
- [x] إضافة snapshot/cancel/take APIs typed إلى `SteerCoordinator` و`AgentRunner`
      بدل مسح القائمة كاملًا دون outcome.
- [x] تغطية سباق انتهاء الجولة أثناء انتقال الأمر.

### Gate C — Queue actions

- [x] إصلاح زر Steer ليستخدم request id الخام.
- [x] إضافة Delete مع mutation ذرية وconfirmation.
- [x] تحديث queue وexecution snapshot من daemon events فقط.

### Gate D — Pending steer timeline and cancellation

- [x] إصدار pending lifecycle event بعد الحفظ وقبل عرض الرسالة كـPending.
- [x] تخزين projection per-session في العميل keyed بالـrequest id مع revision
      ordering.
- [x] عرض pending steer داخل timeline مع `Pending` وزر سلة وحالة progress.
- [x] تنفيذ cancel authoritative على runner المالكة ورفض delivery المتقدمة.
- [x] تحويل الفقاعة نفسها إلى delivered دون duplication، وإزالتها بعد
      cancelled confirmation فقط.
- [x] إعادة hydration من history + pending snapshot بعد navigation/reconnect.

### Gate E — Stop draft recovery

- [x] إضافة drain غير متلف حتى يلتقط Stop pending steers قبل إلغاء runner.
- [x] جمع pending steers ثم queued items بالترتيب المحدد.
- [x] إلغاؤها تحت stop barrier وإصدار outcome قابلة للاستعادة.
- [x] دمج النصوص في بداية draft دون حذف محتواه ودون auto-send.
- [x] إضافة acknowledgment يمنع الفقد والتكرار بين reconnect والعملاء.
- [x] حماية استعادة restart بـ`session.stop_recovery_claim` أول-writer-wins،
      وإخفاء items حتى تطابق `claimed_by` مع claim id المحفوظة للعميل.

### Gate F — Keyboard and presentation

- [x] Enter وزر الإرسال يرسلان `auto`.
- [x] Control+Enter وCommand+Enter يرسلان `queue`.
- [x] عرض tooltip أثناء running/resuming فقط.
- [x] إضافة Steer وDelete لكل queued row مع progress مستقل لكل request.
- [x] إبقاء نصوص UI والـtooltips والـsemantics باللغة الإنجليزية.

### Gate G — Verification and documentation

- [x] اختبارات client للوحات المفاتيح والـtooltip وrequest-id وأزرار الصف.
- [x] اختبارات agent للتصنيف، active runner ownership، idempotency، والحذف.
- [x] اختبار pending steer أثناء أداة طويلة: تظهر Pending، ويمكن حذفها، ولا تدخل
      إلى طلب LLM التالي.
- [x] اختبار سباق cancel مقابل delivery: نتيجة نهائية واحدة ولا اختفاء كاذب.
- [x] اختبار delivered transition: تختفي الشارة والسلة ولا تنشأ فقاعة مكررة.
- [x] اختبار navigation/reconnect/restart يعيد الحالة أو recovery outcome دون
      فقد النص أو حقنه في generation خاطئة.
- [x] اختبار أداة طويلة + pending steer + Stop + draft E يثبت الناتج A..E.
- [x] اختبار Stop barrier يثبت أن الرسائل الأحدث لا تدخل recovery القديمة.
- [x] اختبار reconnect ونسختي local/cloud يمنع duplication.
- [x] اختبار restart claim يثبت أن النص مخفي قبل claim، وأن أول claimant فقط
      يستلمه، وأن claim المحفوظة تصمد أمام restart العميل.
- [x] تحديث عقود communication protocol وdraft cache وruntime QA.

نتيجة التحقق النهائية في 2026-07-15: تحليل agent وclient نظيفان؛ نجح full
agent suite بعدد 748 اختبارًا مع skip واحد معروف، ونجح full client suite بعدد
566 اختبارًا؛ ونجح `graphify update .` لتحديث فهرس العلاقات.

## 9. معايير القبول

- [x] الوكيل، لا العميل، يقرر steer/queue/think.
- [x] Enter يوجه التنفيذ الفعلي وCtrl/Cmd+Enter يطلب queue صراحة.
- [x] لا تضيع رسالة إذا انتهت الجولة أثناء انتقال الأمر.
- [x] queued Steer يصل إلى active runner الصحيحة ويزال من الطابور مرة واحدة.
- [x] Delete يلغي queued item المحددة فقط بعد confirmation.
- [x] كل steer قبل الحقن تظهر داخل المحادثة بحالة `Pending` وزر سلة.
- [x] حذف pending steer قبل الحجز يمنع دخول نصها إلى model context ويحذفها من
      timeline بعد confirmation فقط.
- [x] إذا بدأ delivery أولًا، لا تعرض الواجهة نجاح حذف كاذب وتتحول الرسالة إلى
      delivered بصورة طبيعية.
- [x] delivery أو reconnect لا ينشئان نسختين من فقاعة steer نفسها.
- [x] stale run/generation لا تسلم ولا تلغي pending steer تخص owner أحدث.
- [x] restart لا يفقد pending steer ولا يحقنها تلقائيًا في جولة جديدة غير مالكة.
- [x] Stop يعيد pending steer والqueued القديمة إلى بداية draft بالترتيب دون
      حذف النص الموجود أو تكراره.
- [x] لا يظهر النص المسترجع في draft جلسة أو عميل غير مالك لطلب Stop.
- [x] restart recovery لا يكشف items قبل claim، ولا يطبقها إلا العميل الذي
      يطابق claim id الخاصة به مع `claimed_by`.

## 10. الملفات المتوقعة وملكية التعديل

### Agent runtime and persistence

- `agent/lib/interfaces/runtime/session_run_orchestrator.dart` — التصنيف، أوامر
  queue/steer/cancel، وربطها بالـActiveRun المالكة.
- `agent/lib/interfaces/runtime/session_turn_executor.dart` — كشف owner الحالية
  و`run_id/generation` دون نقل ملكية buffer إليه.
- `agent/lib/interfaces/runtime/session_queue_coordinator.dart` — queue mutation
  والترقية إلى steer بالهوية نفسها.
- `agent/lib/engine/agent_runner.dart` — facade typed لـpending steer snapshot,
  cancel, reserve, deliver, وStop drain.
- `agent/lib/engine/runtime/steer_coordinator.dart` — buffer APIs والسباق بين
  cancel/delivery؛ لا يفتح قاعدة البيانات مباشرة.
- `agent/lib/evolution/db/agent_state_database.dart` — schema/migration للمالك
  الدائم وstop recovery outcomes.
- owner/repository جديد تحت `agent/lib/evolution/db/runtime/` لحالة pending
  steers، revisions، والإلغاء/الحجز الذري.
- `agent/lib/evolution/db/runtime/session_execution_state_coordinator.dart` و
  `session_work_item_repository.dart` — queued delete/claim فقط؛ لا تخزن pending
  steer كعمل نشط ثانٍ.

### Protocol

- `agent/lib/interfaces/platforms/sanad_gateway/protocol/canonical_events.dart`
- `agent/lib/interfaces/platforms/sanad_gateway/sanad_protocol_bridge.dart`
- `agent/lib/interfaces/platforms/sanad_gateway/translators/canonical_to_agent.dart`
- `agent/lib/interfaces/platforms/sanad_gateway/translators/agent_to_canonical.dart`
- `agent/lib/interfaces/platforms/sanad_gateway/handlers/session_query_handler.dart`
- `agent/lib/interfaces/models/gateway_event.dart` أو نماذج typed أصغر عند
  الحاجة، دون نشر maps غير منضبطة.

### Flutter client

- `client/lib/features/conversations/domain/models/canonical_event.dart` أو model
  typed جديد لـpending input lifecycle.
- `client/lib/features/conversations/domain/stores/device_conversation_store.dart`
- `client/lib/features/conversations/domain/stores/conversation_cache_store.dart`
  لحفظ Stop draft recovery acknowledgment فقط؛ لا يحول pending إلى draft قبل
  Stop outcome.
- `client/lib/features/conversations/data/transport/conversation_commands.dart`
- `client/lib/features/conversations/data/transport/conversation_event_handler.dart`
- `client/lib/features/conversations/domain/conversation_client.dart`
- `client/lib/features/conversations/domain/repositories/conversation_repository.dart`
- `client/lib/features/conversations/data/clients/socket_conversation_client.dart`
- `client/lib/features/conversations/data/repositories/socket_conversation_repository.dart`
- `client/lib/features/conversations/presentation/bloc/session_messages_cubit.dart`
- `client/lib/features/conversations/presentation/bloc/conversation_input_cubit.dart`
- `client/lib/features/conversations/presentation/widgets/event_tile.dart` — عرض
  Pending والسلة داخل user bubble.
- `client/lib/features/conversations/presentation/widgets/conversation_input/queued_messages_box.dart`
- `client/lib/features/conversations/presentation/widgets/conversation_input/conversation_input_composer.dart`

### Documentation and tests

- `docs/technical/communication_protocols.md`
- `docs/technical/agent_database_schema.md`
- `docs/technical/agent_runtime.md`
- `docs/technical/client_conversation_cache_schema.md`
- QA matrix مناسبة تحت `docs/qa_maintenance/`.
- اختبارات agent للـSteerCoordinator/orchestrator/persistence/protocol، واختبارات
  Flutter للـstore/cubit/timeline/queued box/composer.

## 11. ترتيب التنفيذ الإلزامي

1. **A — Models/schema:** typed lifecycle، migration، repository، والانتقالات
   الذرية مع اختبارات persistence.
2. **B — Agent ownership:** classification owner، ActiveRun الصحيحة، APIs الخاصة
   بـSteerCoordinator، وسباقات cancel/delivery.
3. **C — Protocol:** intents، confirmations، lifecycle events، cancel outcomes،
   history/pending hydration.
4. **D — Client state:** mapper/store/revision ordering ودمج الفقاعة بالـrequest
   id دون duplication.
5. **E — UI:** keyboard، queued actions، Pending label، trash/progress، وStop
   draft merge.
6. **F — Recovery/docs/full verification:** reconnect/restart/local-cloud، تحديث
   الوثائق، ثم التحليل والاختبارات المركزة والـfast suites المتأثرة.

لا يبدأ UI على payload مفترض قبل تثبيت Gate C، ولا تعدل queue policy قبل اكتمال
Task 35 ودمج admission owner الآمنة التي تعتمد عليها هذه المهمة.

## 12. سيناريوهات نجاح حاسمة

### سيناريو 1 — Pending ثم Delete

1. تبدأ أداة طويلة في session A.
2. يرسل المستخدم رسالة Enter فتصنف steer.
3. تظهر فقاعة واحدة بالنص مع `Pending` وسلة.
4. يضغط المستخدم السلة قبل انتهاء الأداة.
5. تبقى الفقاعة مع progress حتى `cancelled` ثم تختفي.
6. ينتهي tool loop ولا يحتوي طلب LLM التالي على النص المحذوف.

### سيناريو 2 — Delivery يسبق Delete

1. تبدأ عملية حقن pending steer في اللحظة نفسها التي يصل فيها cancel.
2. يفوز حجز `delivering` أو cancel ذريًا.
3. إذا فاز delivery، يعود `delivery_in_progress/already_delivered`، تختفي الشارة
   والسلة، وتبقى فقاعة واحدة delivered.
4. إذا فاز cancel، لا يدخل النص model context وتختفي الفقاعة بعد confirmation.

### سيناريو 3 — Queue إلى Steer

1. توجد رسالة queued بهوية request R.
2. يضغط المستخدم Steer.
3. يحول daemon R ذريًا من queue إلى pending steer على runner المالكة.
4. تزال من `QueuedMessagesBox` وتظهر في timeline كـPending بالهوية R نفسها.
5. delivery أو delete يحدثان مرة واحدة فقط.

### سيناريو 4 — Stop وReconnect

1. توجد pending steers A وB وqueued C وD وdraft E.
2. ينقطع العميل ثم يعيد الاتصال؛ تعود A وB Pending بلا duplication.
3. يقبل Stop ويلتقط A..D تحت الحاجز.
4. تختفي pending/queued projections بعد outcomes authoritative.
5. يصبح draft `A\nB\nC\nD\nE` مرة واحدة، ويبقى كذلك بعد reconnect آخر.

## 13. خارج النطاق

- مؤشر زر الإرسال حتى canonical acceptance؛ تملكه Task 41.
- تغيير سياسة Stop للعمل الجاري الأصلي أو حواجز generation في Plan 30.
- إعادة تصميم تاريخ المحادثة أو ترحيل رسائل قديمة بلا request id.
- Fork للجلسة، وإعادة تشغيل أو تعديل آخر turn؛ تملكها خطط مستقلة.
- حذف steer بعد وصولها إلى model context أو التراجع عن side effects نتجت عنها.
- تنفيذ هذه المهمة داخل worktree Task 31؛ تبدأ بعد دمج Task 31.
