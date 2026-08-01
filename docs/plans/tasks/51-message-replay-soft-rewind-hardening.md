---
title: "Task 51: Message Replay Soft Rewind and Idle Hardening"
description: "إغلاق فجوات Task 49 عبر soft rewind ذري، وهوية turn ثابتة، واشتراط idle authoritative قبل Edit/Retry دون حذف التاريخ الأصلي."
status: "planned"
priority: "high"
scope: "Sanad agent replay persistence/protocol and Flutter conversation replay recovery"
depends_on: "Task 49 completed behavior, Task 31 authoritative session state, Task 36 queue/steer/stop recovery"
coordinates_with: "Task 50 cancellation hardening"
---

# Task 51: Message Replay Soft Rewind and Idle Hardening

## 1. المشكلة

نفذت Task 49 تجربة Edit/Retry، بوابة الإيقاف، تأكيد آثار الأدوات، واستخدام
المزود والنموذج الحاليين. لكن عقد replay الحالي ما زال يصف إزالة أو `truncate`
للرسالة المستهدفة وذيلها. هذا يفقد التاريخ الأصلي ويجعل التعافي والتدقيق عرضة
للفجوات إذا نجح تعديل التاريخ ثم فشل قبول الجولة البديلة.

كذلك يجب ألا تكون `terminal cancellation` وحدها بوابة كافية لبدء الجولة الجديدة:
كل حالة غير `idle`، بما فيها `queued` و`stopping`، يجب أن تنتهي إلى snapshot
authoritative تؤكد `idle`. وبعد الانتظار يجب إعادة التحقق من هوية الرسالة وحد
الجولة ومراجعة التاريخ حتى لا ينفذ أمر replay قديم فوق حالة أحدث.

توجد فجوة أهلية إضافية من Task 49: رسالة `steer` تظهر في timeline كحدث user
وتحمل `request_id`، ولذلك قد تعرض الواجهة Edit/Retry عليها باعتبارها آخر رسالة
مستخدم. لكن steer ليست بداية turn مستقلة؛ إنها input تابعة لجولة المستخدم
الأصلية وقد تكون محفوظة كسجل user بعلامة steer أو معاد بناؤها من metadata داخل
tool result. معاملتها كحد replay مستقل قد يفشل في العثور على الحد، أو يقطع
الجولة من موضع غير صحيح، أو يصنف أدوات سبقت steer على أنها آمنة خطأً.

## 2. الهدف

1. استبدال الحذف أو `truncate` بـ**Soft Rewind** ذري يحفظ الرسالة الأصلية وكل
   أحداث الجولة القديمة كسجلات غير نشطة.
2. عدم بدء Edit Send أو Retry إلا بعد وصول الجلسة إلى `idle` authoritative،
   دون قبول حالة terminal وسيطة كبديل.
3. تثبيت هوية الرسالة والجولة والطلب والتشغيل، مع revision متزايدة لتاريخ
   الجلسة وحماية compare-and-swap من الأوامر القديمة.
4. جعل تعطيل الذيل وقبول الرسالة البديلة عملية ذرية: إما ينجحان معًا أو يبقى
   التاريخ الأصلي ظاهرًا وفعالًا دون تغيير.
5. الحفاظ على سلوك Task 49 المعتمد: inline Edit، الإلغاء عند navigation، تأكيد
   `unsafe|unknown` قبل أي Stop، واستخدام route الحالية عند الإرسال النهائي.
6. قصر Edit/Retry على أحدث **root user turn** مؤهلة، ومنع عرضهما أو قبولهما
   على pending/delivered/embedded steer مهما كان شكل تخزينها أو إعادة بنائها.

## 3. قرارات التصميم الملزمة

### 3.1 هوية التاريخ والجولة

- لكل سجل رسالة `message_id` ثابت لا يتغير بسبب hydration أو pagination.
- كل أحداث محاولة تنفيذ واحدة تحمل `turn_id` واحدًا.
- `request_id` يعرّف قبول طلب المستخدم أو أمر replay الجديد، و`run_id` يعرّف
  محاولة runtime الفعلية؛ لا يستخدم أي منهما بدل الآخر.
- لكل جلسة `history_revision` متزايدة تُحدّث داخل معاملات تغيير التاريخ.
- يحمل أمر replay على الأقل:
  `session_id + target_message_id + target_turn_id + target_request_id + expected_history_revision`.
- الرسالة البديلة تحصل على `message_id`, `turn_id`, `request_id`, و`run_id`
  جديدة، مع مرجع `replays_turn_id` أو `supersedes_turn_id` إلى الجولة القديمة.
- لا يسمح fallback بالنص أو timestamp عند غياب الهوية؛ تعاد نتيجة typed ولا
  يتغير التاريخ.

### 3.2 Soft Rewind

- عند القبول، تصبح رسالة المستخدم المستهدفة وكل الأحداث النشطة التابعة لها
  بعدها `inactive/superseded` بدل حذفها.
- تحتفظ السجلات القديمة بالمحتوى، reasoning، tool calls/results، provider state،
  metadata، والترتيب الأصلي لأغراض التدقيق والتعافي.
- history العادية، timeline، وسياق النموذج تعرض السجلات النشطة فقط.
- لا تعيد Retry تشغيل tool results القديمة؛ إنها تنشئ محاولة جديدة وقد تعيد
  تنفيذ الأدوات بعد التأكيد المطلوب.
- لا تصبح السجلات القديمة فعالة تلقائيًا بعد reconnect أو cache hydration.

### 3.3 ترتيب العملية

الترتيب الملزم عند Retry أو Edit Send هو:

1. تصنيف replay safety والتحقق من هوية الهدف.
2. طلب تأكيد المستخدم إذا كان التصنيف `unsafe|unknown`؛ الرفض لا يرسل Stop ولا
   يغير التاريخ.
3. إيقاف/إلغاء العمل المملوك للجلسة إذا كانت حالتها
   `queued|running|waiting|blocked|resuming|stopping`.
4. انتظار snapshot جديدة تؤكد `idle` تحديدًا.
5. إعادة قراءة الهدف و`history_revision` والتأكد أنه ما زال آخر user turn فعالة.
6. تنفيذ Soft Rewind وقبول الرسالة البديلة ذريًا، ثم زيادة revision.
7. dispatch مرة واحدة باستخدام provider/model/thinking المختارة حاليًا.

فتح محرر Edit فقط يبقى تغيير UI محليًا ولا يرسل Stop. يبدأ الترتيب السابق عند
ضغط `Send`. أما Retry فيبدأ preflight مباشرة.

### 3.4 Queue وSteer

- لا تختلط queued message أو pending steer مع الجولة البديلة.
- يستخدم الإلغاء مسار Task 36 authoritative، ويحافظ على أي نص قابل للاستعادة
  كمسودة وفق عقد Stop recovery بدل إسقاطه بصمت.
- إذا ظهر user turn أحدث أثناء الانتظار، يفشل replay بنتيجة `stale_turn_boundary`
  ولا يعطل أي سجل.
- لا يمس الإلغاء work أو queue في جلسة أخرى.

### 3.5 أهلية Steer وملكية الجولة

- steer ليست turn مستقلة ولا يجوز استخدامها كـreplay boundary حتى لو ظهرت
  كـ`EventKind.userMessage` أو حملت `request_id` مستقلة.
- يضاف تصنيف canonical دائم لمدخل المستخدم، مثل
  `input_kind: root_turn|steer` أو `turn_role: root|steer`؛ لا تعتمد الأهلية على
  `role=user` أو موضع الحدث أو وجود `request_id` فقط.
- daemon هو المالك النهائي للأهلية ويعيد outcome typed مثل
  `target_not_replayable_input` لأي pending/delivered/embedded steer، حتى لو
  أرسل client قديم أو تالف الأمر مباشرة.
- client يعرض Edit/Retry على أحدث root user turn مؤهلة فقط. pending steer تحتفظ
  بإجراء Cancel/Delete الخاص بها، ولا تجمع بينه وبين إجراءات replay.
- latest-turn validation تتجاهل steer كمرشح root مستقل، لكنها تعدها جزءًا من
  ذيل الجولة الأصلية عند Soft Rewind.
- عند replay للجولة الأصلية، تصبح كل steers التابعة لها superseded مع بقية
  أحداث الجولة ولا يعاد حقنها تلقائيًا؛ إعادة حقنها عند tool boundaries القديمة
  ليست replay صحيحة.
- إذا احتوت الجولة الأصلية على steer واحدة أو أكثر، يعيد preflight علامة
  `contains_steers` ويطلب تأكيدًا واضحًا بأن رسائل التوجيه التابعة لن تعاد
  تلقائيًا، حتى إن كان تصنيف الأدوات `safe`.
- tool replay safety تُحسب على **كامل الجولة الأصلية** من root user boundary،
  لا من موضع steer ولا من request ID الخاصة بها، حتى لا تُستبعد أدوات سبقتها.

## 4. بوابة التنفيذ

- [ ] مراجعة وثائق Task 49 الحالية وتحديد كل موضع يصف delete أو `truncate`.
- [ ] اعتماد تمثيل `active/superseded` وعلاقة supersession قبل تعديل التخزين.
- [ ] اعتماد ملكية `message_id`, `turn_id`, `request_id`, `run_id`, و`history_revision`.
- [ ] تحديد المعاملة الذرية التي تجمع Soft Rewind مع قبول الجولة البديلة.
- [ ] تحديد migration/backfill للسجلات الحالية دون مطابقة بالنص أو timestamp.
- [ ] توثيق outcomes الجديدة أو المعدلة قبل تغيير client/agent contract.
- [ ] اعتماد تصنيف root/steer canonical لكل صور steer القديمة والحالية.

## 5. النطاق المرحلي

### Gate A — Persistence identity and migration

- [ ] إضافة الهوية الثابتة وحقول النشاط/supersession ومراجعة التاريخ المطلوبة.
- [ ] backfill deterministic للسجلات القابلة للهجرة، ووسم legacy غير القابل
      للتحديد كغير قابل لـreplay بدل التخمين.
- [ ] جعل القراءة العادية تعيد السجلات النشطة فقط مع مسار داخلي صريح للتدقيق.
- [ ] ضمان أن pagination والترتيب يعتمدان مفاتيح ثابتة ولا يعيدان سجلات superseded.

#### Gate A Exit

- [ ] restart وhistory hydration يحافظان على نفس الهويات وحالة النشاط.
- [ ] لا تختفي السجلات القديمة من قاعدة البيانات بعد replay.

### Gate B — Atomic replay admission

- [ ] توسيع `session.turn_replay` بهوية الهدف و`expected_history_revision`.
- [ ] رفض أي target مصنفة steer قبل Stop أو history mutation، مع outcome typed.
- [ ] تسلسل replay command لكل جلسة ومنع قبول أمرين متزامنين للهدف نفسه.
- [ ] تنفيذ CAS داخل معاملة واحدة: revalidate target، soft rewind، إنشاء/قبول
      الرسالة البديلة، زيادة revision.
- [ ] إذا فشل قبول الرسالة البديلة، rollback كامل يبقي الجولة الأصلية فعالة.
- [ ] إنشاء typed outcomes لـrevision mismatch والهدف القديم وعدم الوصول إلى idle.

#### Gate B Exit

- [ ] كل أمر مقبول ينتج محاولة بديلة واحدة فقط.
- [ ] لا توجد حالة يصبح فيها التاريخ القديم غير نشط دون قبول بديل دائم.

### Gate C — Authoritative idle and client reconciliation

- [ ] توحيد كل الحالات غير idle عبر stop/cancel scoped ثم انتظار `idle` فقط.
- [ ] عدم اعتبار terminal work item أو cancellation acknowledgement تصريح dispatch.
- [ ] إعادة التحقق من الهدف والـrevision بعد idle مباشرة وقبل المعاملة.
- [ ] تحديث cache/live projection باستخدام الهوية وrevision بدل truncate متفائل.
- [ ] إبقاء timeline الأصلية ظاهرة عند timeout أو stale boundary أو rollback.
- [ ] الحفاظ على إلغاء inline Edit عند session/device/New Conversation navigation.
- [ ] اشتقاق `canReplay` من أهلية root turn authoritative، لا من آخر user event.
- [ ] عدم عرض Edit/Retry على pending steer أو delivered steer أو steer معاد بناؤها
      من tool-result metadata.

#### Gate C Exit

- [ ] لا يبدأ provider run جديد قبل snapshot idle authoritative.
- [ ] reconnect أو live event متأخر لا يعيد الجولة superseded ولا يكرر البديلة.

### Gate D — Side-effect and route parity

- [ ] الحفاظ على تصنيف `safe|unsafe|unknown` قبل أي mutation.
- [ ] حساب tool safety من root boundary عبر كامل الجولة بما فيها الأدوات السابقة
      واللاحقة لأي steer.
- [ ] الرفض في confirmation لا يرسل Stop ولا يغير history revision.
- [ ] طلب تأكيد مستقل عند `contains_steers` يوضح أن التوجيهات التابعة لن تعاد.
- [ ] بعد الموافقة يستخدم dispatch provider/model/thinking الحالية في الطلب النهائي.
- [ ] تغيير route أثناء نافذة التأكيد يُقرأ مرة أخرى عند الإرسال النهائي.

### Gate E — Verification and documentation

- [ ] اختبارات DB: soft rewind، rollback، revision CAS، restart، legacy identity.
- [ ] اختبارات agent: كل حالة غير idle إلى stop/cancel ثم idle ثم replay.
- [ ] اختبارات race: replay مزدوج، رسالة أحدث أثناء الانتظار، snapshot قديمة، reconnect.
- [ ] اختبارات queue/steer recovery وعدم التأثير على جلسة أخرى.
- [ ] اختبارات أهلية UI لكل من root user، pending steer، delivered steer،
      embedded steer، وlate steer المحفوظة كرسالة user.
- [ ] اختبارات daemon تثبت رفض target steer قبل Stop/mutation حتى مع client مباشر.
- [ ] اختبار safety يثبت أن أداة unsafe سبقت steer لا تُستبعد من التصنيف.
- [ ] اختبار replay للـroot يثبت supersede لكل steers التابعة وعدم إعادة حقنها.
- [ ] اختبارات client cache/widget لعدم ظهور superseded وإبقاء الأصل عند الرفض.
- [ ] تحديث وثائق product/technical/database/QA المتأثرة وإزالة وصف `truncate` القديم.

## 6. Definition of Done

- [ ] Edit/Retry لا يحذفان تاريخ الجولة الأصلية فعليًا.
- [ ] normal history وسياق النموذج لا يعيدان السجلات superseded.
- [ ] لا dispatch قبل `idle` authoritative في أي مسار.
- [ ] Soft Rewind وقبول البديل ذريان وقابلان للـrollback.
- [ ] الهوية والـrevision تمنعان replay قديمة أو مزدوجة.
- [ ] queued/steer النصية تُستعاد وفق Task 36 ولا تختلط بالجولة الجديدة.
- [ ] لا تظهر Edit/Retry على أي steer ولا يقبل daemon steer كحد replay.
- [ ] أحدث root user turn تبقى هي المرشح الصحيح حتى عند وجود steers تابعة بعدها.
- [ ] replay للجولة ذات steers يتطلب إقرار إسقاط إعادة حقنها ويحسب tool safety
      على كامل الجولة.
- [ ] تحذير آثار الأدوات وroute الحالية وسلوك inline Edit لا تتراجع.
- [ ] تحليلات agent/client والاختبارات المركزة المناسبة ناجحة.

## 7. سيناريو النجاح

توجد جلسة `blocked` بعد تنفيذ أداة `unsafe`. يضغط المستخدم Retry، فيظهر التحذير
قبل أي Stop. بعد الموافقة تُلغى الجولة المملوكة، وتستعاد أي pending steer كمسودة،
وينتظر النظام snapshot `idle`. يعاد التحقق من الهدف والـrevision، ثم تُعلّم
الجولة القديمة ونتائج أدواتها superseded وتُقبل رسالة بديلة جديدة داخل معاملة
واحدة. بعد restart تظهر المحاولة الجديدة فقط في timeline، بينما تظل الجولة
القديمة محفوظة في قاعدة البيانات ولا يمكن لحدث متأخر إعادتها.

في نسخة السيناريو التي تحتوي steer بعد tool result، لا تظهر Edit/Retry على
فقاعة steer، ويرفض daemon استهداف request ID الخاصة بها دون Stop. تظهر الإجراءات
على root user turn فقط؛ وعند Replay لها يشمل تصنيف السلامة الأداة التي سبقت
steer، ويطلب النظام أيضًا تأكيد عدم إعادة حقن رسائل steer التابعة.

## 8. خارج النطاق

- Fork أو branch لمحادثة؛ تملكه Task 52.
- إتاحة Edit/Retry لأي turn أقدم من آخر user turn فعالة.
- دعم تعديل steer أو إعادة حقنها عند نقطة tool قديمة؛ يحتاج ذلك عقد replay خاصًا
  مختلفًا عن إعادة تشغيل root turn.
- جعل الأدوات ذات الآثار الجانبية idempotent.
- إعادة تصميم timeline أو composer خارج حالات replay الحالية.

## 9. الملفات والوثائق المتوقعة

- `agent/lib/evolution/db/`
- `agent/lib/interfaces/runtime/`
- `agent/lib/interfaces/platforms/sanad_gateway/`
- `client/lib/features/conversations/`
- اختبارات agent/client المركزة
- `docs/product/message_edit_retry_ux.md`
- `docs/technical/message_turn_replay_protocol.md`
- `docs/technical/agent_database_schema.md`
- `docs/qa_maintenance/message_edit_retry_qa.md`

## 10. سجل التقدم

```text
Date:
Gate/status:
Files changed:
Verification:
Findings:
Next gate:
```
