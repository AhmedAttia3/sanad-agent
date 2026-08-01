---
title: "Task 31: Authoritative Session State and Auto-Failover UX"
description: "إنشاء snapshot تنفيذ دائم ومراجع لكل جلسة، وإزالة استنتاج حالة التشغيل من أحداث المحادثة، وجعل auto-failover مرئيًا ومتزامنًا بين العملاء."
status: "completed"
priority: "high"
---

# Task 31: Authoritative Session State and Auto-Failover UX

## 1. الحالة والنطاق

- الحالة: مكتملة ومعتمدة للدمج بعد مراجعة المستخدم ونجاح التحقق الآلي الكامل.
- الأولوية: عالية.
- النطاق: agent protocol + durable runtime + Flutter client.
- التنفيذ متسلسل: لا تبدأ مرحلة قبل إغلاق checklist المرحلة السابقة واختبارها.
- الاعتماد السابق: يجب إكمال عقد عزل الجولة الملغاة في
  `docs/plans/tasks/done/plan30-session-stop-run-isolation.md`، أو إثبات أن حواجز
  `generation/run_id` المطلوبة فيه موجودة، قبل بث حالات التنفيذ؛ وإلا قد تعدّل
  callback قديمة snapshot جولة أحدث.

## 2. نتيجة مراجعة ما قبل التنفيذ

صححت هذه النسخة المشكلات الآتية في المسودة الأصلية:

1. لا يكفي إسقاط `SessionWorkState` إلى enum آخر؛ يلزم snapshot دائم يملك
   `revision`، وإلا لا يمكن ضمان ordering بعد restart أو بين local/cloud.
2. `queued` قد تتعايش مع work item نشطة. لذلك حالة الجلسة aggregate لها أولوية
   واضحة، وليست نسخة من آخر work item تغيرت.
3. بعد اكتمال work item لا تصبح الجلسة `idle` إذا بقيت عناصر queued؛ يعاد حساب
   snapshot وقد تصبح `queued` أو `running`.
4. `stopping` حالة جلسة انتقالية وليست `SessionWorkState` جديدة، ولا يجوز
   إضافتها إلى جدول work items.
5. `canStop` لا يشمل `stopping`؛ يظل Stop idempotent في الوكيل، لكن الواجهة
   تعطل الزر بعد قبول الطلب لمنع أوامر مكررة.
6. revision حالة التنفيذ وrevision مسار provider سلسلتان مستقلتان، ولا يجوز
   مقارنتهما ببعض.
7. route confirmation وحده لا يجعل إشعار auto-failover قابلًا للاستعادة؛ يلزم
   سجل route transition دائم ذو هوية ثابتة.
8. صححت مسارات الملفات لتكون نسبية إلى workspace root، وحددت المالك الحالي
   لجدول work items بدل إضافة SQL إلى facade الانتقالية.
9. أزيل طلب وضع تفاصيل event/schema داخل `AGENTS.md`. عقود التصميم والبروتوكول
   توثق في `docs/`، ولا تعدل ملفات `AGENTS.md` إلا إذا تغير قانون تشغيلي دائم.

## 3. المشكلة

تعرض الواجهة حاليًا حالة الجلسة عبر `isProcessing` مشتقة من أحداث مثل
`thinking` و`final_answer` و`runtime_resuming`. هذه ليست حالة تنفيذ حقيقية،
وتنتج حالات تظهر فيها الجلسة idle بينما تعمل في الخلفية، أو active بعد انتهاء
العمل.

المثال الأوضح هو Change Provider: يرسل الوكيل `resuming` ثم يمسح recovery
notice عند بدء ظهور progress. تضيف الواجهة الجلسة إلى processing عند
`resuming` ثم تحذفها عند `session.runtime_notice_cleared` رغم أن العمل ما زال
`resuming/running`.

يوجد نقص مماثل في auto-failover: يغير الوكيل provider الفعلي ويعيد توجيه queue،
لكنه لا يرسل route confirmation دائمًا وواضحًا مع revision مستقل، ولا يحفظ
route transition مرئية يمكن استعادتها. لذلك قد لا يعرف المستخدم أن الانتقال
حدث، وقد يعرض model chip مسارًا قديمًا.

## 4. الهدف

1. جعل الوكيل المصدر الوحيد لحالة تنفيذ كل جلسة.
2. إيقاف استنتاج active/idle من أسماء أحداث المحادثة أو recovery notice.
3. استعادة الحالة الصحيحة بعد reconnect أو restart وعلى كل clients المفتوحة.
4. جعل auto-failover مرئيًا ومفهومًا وتحديث route الجلسة والعمل المعلق ذريًا.
5. إبقاء execution state وruntime recovery notice وpermission suspension وroute
   عقودًا مستقلة مترابطة، لا boolean واحدًا يحمل معاني متعددة.
6. جعل كل حالة مرتبطة بـ`session_id` صراحة؛ لا توجد runtime notice أو permission
   request أو sidebar attention state مشتركة على مستوى الجهاز.
7. توحيد اختيار حالة الـsidebar والـcomposer من reducer واحد لكل جلسة، مع منع
   event قديم من تعديل أو مسح حالة أحدث.

## 5. نموذج حالة التنفيذ

ينشأ enum دلالي مشترك باسم `SessionExecutionState` بالقيم:

- `idle`: لا توجد work item غير نهائية ولا عملية Stop قيد الإغلاق.
- `queued`: توجد عناصر queued، ولا توجد work item نشطة.
- `running`: الوكيل ينفذ turn فعليًا.
- `waiting`: work item محفوظة وتنتظر موعد retry.
- `blocked`: work item محفوظة ومتوقفة بسبب recovery يحتاج تدخل المستخدم.
- `resuming`: تم claim لعمل محفوظ ويجري استكماله.
- `stopping`: قبل الوكيل Stop، ولم يكتمل إلغاء الجولة التي يملكها الطلب بعد.

### 5.1 خصائص العرض المشتقة

لا تخزن الخصائص التالية كحقائق مستقلة:

- `isExecuting`: `running` أو `resuming`.
- `hasActiveWork`: كل حالة عدا `idle`.
- `canStop`: `queued`, `running`, `waiting`, `blocked`, `resuming` فقط.
- `needsUserAction`: `blocked`.
- `isWaiting`: `waiting`.
- `isStopping`: `stopping`.

لا تعني `blocked` وجود permission prompt. يظل
`pending_permission_request`/permission suspension عقدًا مستقلًا، ويجمع composer
القرار النهائي من execution snapshot وruntime notice وpermission suspension.

### 5.2 عزل الحالة لكل جلسة وAttention State

يملك كل `session_id` حالة مستقلة تشمل:

```text
SessionAttentionState {
  session_id
  execution_snapshot
  runtime_notice: nullable
  pending_suspended_request: nullable
  attention_revision
}
```

`attention_revision` قيمة مشتقة من أحدث execution revision أو notice revision أو
permission request identity، وليست مصدر حقيقة جديدًا. القواعد الإلزامية:

- يخزن Flutter execution snapshots وruntime notices وpermission requests في
  خرائط keyed by `session_id`؛ لا يجوز أن تكون permission request الحالية قيمة
  واحدة مشتركة بين كل جلسات الجهاز.
- عند فتح جلسة أو وصول history، يقرأ composer والـsidebar حالة `session_id`
  الحالي فقط. لا تستخدم آخر قيمة وصلت من transport دون مطابقة session id.
- أي clear أو update يقبل فقط إذا كان session id مطابقًا وrevision/identity
  أحدث؛ event قديم لجلسة لا يمسح حالة أحدث للجلسة نفسها ولا يؤثر في جلسة أخرى.
- يشتق الـsidebar والـcomposer من reducer/selector واحدة، ولا يكرر كل منهما
  منطقًا خاصًا لتفسير runtime notice أو permission metadata.
- أولوية visual state الموحدة هي:
  `user_question_or_permission > blocked_or_fatal > waiting > stopping > running_or_resuming > queued > normal`.
- حالة الجلسة A لا تغير رسالة أو أيقونة أو composer للجلسة B، ولا تغير حالة
  الجهاز العامة. الحالات العامة للاتصال تبقى في device/gateway state فقط.

### 5.3 إسقاط durable work إلى حالة الجلسة

يحسب agent حالة الجلسة من snapshot aggregate وفق الأولوية الآتية:

1. إذا كانت عملية Stop المقبولة لم تكتمل: `stopping`.
2. وإلا إذا وجدت work item نشطة، تستخدم حالتها من:
   `running | waiting | blocked | resuming`.
3. وإلا إذا وجدت work item واحدة أو أكثر بحالة `queued`: `queued`، وتشير
   `work_item_id` و`request_id` إلى رأس FIFO فقط.
4. وإلا: `idle`، وتكون معرفات العمل `null`.

وجود queued items خلف work item نشطة لا يغير الحالة aggregate عن حالة العنصر
النشط. بعد `completed` أو `cancelled` يعاد الحساب؛ لا يصدر `idle` إلا إذا لم
يبق أي عمل غير نهائي. حالات notice مثل `fatal` لا تحدد execution state وحدها؛
يجب أولًا إنهاء work item إلى `completed` أو `cancelled` وفق نتيجة الجولة، ثم
إعادة حساب snapshot.

لا تضاف `stopping` إلى `SessionWorkState`. وإذا كان الاستكمال ينتقل فعليًا من
مرحلة claim إلى تنفيذ عادي، يضاف الانتقال الصريح `resuming -> running` إلى
state graph؛ وإلا تبقى work item `resuming` حتى نهايتها ويجب توثيق ذلك واختباره
بصورة موحدة.

## 6. المصدر الدائم وrevision

يضاف جدول/aggregate دائم باسم `session_execution_snapshots` يملكه repository
مركزية في `agent/lib/evolution/db/runtime/`. الحد الأدنى للحقول:

```text
session_id PRIMARY KEY
state
work_item_id NULLABLE
request_id NULLABLE
revision
updated_at
```

القواعد:

- `revision` عدد صحيح متزايد داخل الجلسة لهذه السلسلة فقط.
- أي تغيير فعلي في `(state, work_item_id, request_id)` يزيد revision مرة واحدة.
- إعادة تطبيق النتيجة نفسها idempotent ولا تزيد revision ولا تبث event جديدًا.
- جلسة قديمة لا تملك row تعامل كـ`idle` مع `revision=0` حتى أول انتقال.
- transition العمل وتحديث execution snapshot يحدثان داخل transaction واحدة على
  اتصال `AgentStateDatabase` المشترك.
- يبث event بعد نجاح commit فقط. فشل البث لا يلغي الحالة الدائمة؛ تعالج
  reconnect snapshots الحدث المفقود.
- لا تضاف ملكية SQL إلى `PersistedRuntimeStateRepository`; يبقى facade
  انتقالية، ويكون لكل جدول repository مالكة واحدة.
- يجب أن تمنع حواجز `generation/run_id` الجولة القديمة من كتابة snapshot جولة
  أحدث.

## 7. العقد البروتوكولي لحالة التنفيذ

يضاف canonical event باسم:

`session.execution_state_changed`

Payload:

```text
session_id
state
work_item_id: nullable
request_id: nullable
revision
updated_at
```

قواعد العقد:

- event يستخدم `delivery.scope=platform_family` لعائلة `sanad_client`.
- ينشأ `event_id` مرة واحدة قبل fan-out، وتحافظ نسختا local/cloud على نفس
  event identity ونفس revision.
- العميل يقبل snapshot فقط إذا كان revision أكبر من المخزن، أو مساويًا له
  ومطابقًا تمامًا؛ payload متعارضة بنفس revision خطأ contract يسجل ويرفض.
- event لا يحمل نص الخطأ أو recovery actions؛ تبقى في
  `session.runtime_notice`.
- response `session_history` يضم مفتاحًا ثابتًا `execution_snapshot` وحقول
  attention الخاصة بنفس الجلسة فقط.
- كل عنصر داخل response `sessions_list` يضم `execution_snapshot` وملخص
  `attention_state` الخاص به حتى يعمل sidebar دون فتح الجلسة.
- لا يعيد البروتوكول حالة pending أو runtime notice دون `session_id` صريح.
- snapshots وattention updates القادمة من history/list/live تمر عبر reducer واحد
  يطبق session-id وrevision/identity guards نفسها.
- غياب `in_flight` أو notice أو حدث terminal ليس دليلًا على `idle`.
- `final_answer`, `error`, `stopped`, و`session.runtime_notice_cleared` أحداث
  محتوى/تعافٍ فقط، ولا تغير execution snapshot في Flutter.

## 8. عقد route وauto-failover

يظل `session_preferences_updated` هو route confirmation canonical، ويضاف إليه:

```text
session_id
source: user | recovery | auto_failover
previous_provider_instance_id: nullable
provider_instance_id
model
reason: nullable
request_id: nullable
route_revision
updated_at
```

### 8.1 قواعد route revision والذرية

- `route_revision` مستقل تمامًا عن execution `revision`.
- كل session route mutation، سواء من المستخدم أو Retry أو Change Provider أو
  auto-failover، تمر عبر owner واحدة وتزيد `route_revision` بعد تغير فعلي فقط.
- تحديث session provider/model وكل work items غير النهائية يحدث داخل transaction
  واحدة. تستخدم repositories اتصال `AgentStateDatabase` المشترك وواجهات
  transaction-aware؛ لا تنشأ transactions متداخلة مستقلة.
- يبث confirmation بعد commit فقط، ويحمل القيم المقروءة من الحالة الدائمة لا
  القيم المطلوبة تفاؤليًا.
- Flutter يطبق route confirmation فقط إذا كان `route_revision` أحدث، ويحدث
  model chip في كل clients منه، لا من الضغط المحلي.
- migration/backfill يعطي route الحالية revision ابتدائية معروفة، ولا يعيد
  توجيه جلسات قديمة أثناء migration.

### 8.2 اختيار auto-failover

- يبقى model id كما هو؛ المرشح يجب أن يدعم exact model id وفق سياسة Plan 30.
- لا يطبق alias أو fuzzy/semantic model mapping ضمن هذه المهمة.
- لا تختار instance إذا كان `status != ready` أو
  `allow_auto_failover=false` أو كانت ضمن excluded/cooldown set.
- إذا لم يوجد بديل، لا يرسل route confirmation مزيف؛ تبقى recovery notice
  العادية القابلة للتحكم.

### 8.3 route transition المرئية والقابلة للاستعادة

يجب حفظ route transition الناتجة من auto-failover كسجل دائم به على الأقل:

```text
session_id
route_revision
event_id
source
previous_provider_instance_id
provider_instance_id
previous_provider_display_name
provider_display_name
model
reason
created_at
```

ويكون `(session_id, route_revision)` فريدًا. يمكن تنفيذ ذلك بجدول route events
مخصص أو durable conversation event معادل، لكن لا يجوز الاعتماد على runtime
notice transient أو تكوين النص في Flutter فقط.

- history يعيد route transition الدائمة كعنصر informational canonical.
- يُلتقط `previous_provider_display_name` و`provider_display_name` لحظة الكتابة
  (snapshot-at-write) عبر `ProviderInstanceRepository` المحقون صراحة في منسق
  المسار، حتى يبقى نص history صحيحًا بأسماء المزودين المقروءة حتى لو أُعيدت
  تسمية الـinstance أو حُذف لاحقًا؛ لا يُعرض الـUUID الخام في النص.
- موضع الرسالة في history يرتبط بـ`request_id` الدائم للجولة المالكة، والذي
  يحفظه `AgentRunner` على رسالة المستخدم نفسها لكي يبقى متاحًا بعد restart
  (لأن timestamps رسائل history اصطناعية)، مع سقوط زمني للسجلات القديمة بلا
  `request_id`.
- live وhistory يحملان الهوية نفسها، ويمنع العميل التكرار بواسطة
  `(session_id, route_revision)` أو `event_id` canonical.
- لا يعتمد هذا الضمان على dedupe المؤقت الحالي `event_id + transport`، لأنه
  يسمح بنسخة local ونسخة cloud من الحدث المنطقي نفسه.
- النص المرئي إنجليزي وفق عقد UI، مثل:
  `Switched automatically from NVIDIA NIM to Z.ai because NVIDIA NIM reached its rate limit. Continuing with GLM 5.2.`
- informational event لا تصبح recovery block ولا توقف composer.

### 8.4 قرارات التصميم المعتمدة في المرحلة 0

اعتمد التنفيذ الحدود الآتية بعد تدقيق ملاك قاعدة البيانات ومسارات runtime
والعميل. لا تجيز هذه القرارات بث execution events قبل إغلاق عقد عزل الجولة في
Plan 30.

#### ملكية البيانات والـschema

- يملك `SessionExecutionSnapshotRepository` وحده جدول
  `session_execution_snapshots`. غياب row يعني `idle/revision=0` ولا ينشئ
  migration صفوف idle لكل الجلسات القديمة.
- يضاف إلى `sessions` مسار route مراجع مستقل يبدأ بـ`route_revision=1` للمسار
  الحالي، مع backfill لا يغير provider أو model الموجودين.
- يملك `SessionRouteTransitionRepository` وحده جدول
  `session_route_transitions`. يكون `(session_id, route_revision)` فريدًا،
  وتكون `event_id` هوية canonical فريدة قابلة لإعادة الاستخدام في live/history.
- يبقى `PersistedRuntimeStateRepository` facade انتقالية بلا SQL جديد.

#### حدود المعاملة

- يضيف `AgentStateDatabase` transaction owner واحدة قابلة للتمرير إلى
  `SessionDB` وruntime repositories. تفتح public operations معاملة فقط عندما
  لا تستقبل transaction قائمة، لمنع `BEGIN` متداخل.
- يملك `SessionExecutionStateCoordinator` معاملة work mutation ثم إعادة حساب
  snapshot. يعيد snapshot المتغيرة للمنتج، ويحدث البث بعد commit فقط.
- يملك `SessionRouteMutationCoordinator` معاملة route mutation كاملة: تحديث
  session route وكل work items غير النهائية وroute revision وسجل transition.
  لا يبث confirmation قبل commit، ولا يبث عند نتيجة idempotent بلا تغير.
- تمسك كل جولة `work_item_id` وrun lease ثابتة (`generation` + `run_id`). لا
  تبحث terminal callbacks عن "العنصر النشط الحالي" بواسطة `session_id` فقط.

#### سياسة الاستكمال

- تبقى work item المستأنفة في `resuming` طوال model/tool execution حتى تنتقل
  مباشرة إلى `completed | waiting | blocked | cancelled`؛ لا يضاف انتقال
  `resuming -> running`.
- claim عادي يستخدم `queued -> running`، وclaim لاستكمال محفوظ يستخدم
  `queued -> resuming`. توثق state graph والاختبارات هذا الفرق صراحة.

#### حدود Flutter

- `DeviceConversationStore` يملك registry واحدة keyed by `session_id` لتطبيق
  execution snapshots وruntime notices وpermission requests وroute revisions.
- تمر live/history/sessions-list عبر reducer نفسها. تبقى
  `ConversationCacheStore` مالك pagination/cache فقط، ولا تفسر attention state.
- تتحول processing stores الحالية إلى compatibility projections مشتقة من
  registry، ثم تزال بعد انتقال جميع المستهلكين؛ لا يحتفظ `SessionCubit` بمصدر
  حقيقة ثانٍ.

## 9. مراحل التنفيذ

### المرحلة 0: المتطلبات السابقة وتثبيت التصميم

- [x] إغلاق/إثبات عقد run isolation المشار إليه في القسم 1.
- [x] اعتماد schema ومالك `session_execution_snapshots` وroute transition log.
- [x] تحديد transaction boundary المشتركة بين SessionDB وwork-item repository.
- [x] تحديد سياسة `resuming -> running` بصورة واحدة وتحديث state graph عند الحاجة.
- [x] إضافة اختبارات migration/backfill قبل توصيل أحداث الواجهة.

### المرحلة 1: المصدر الدائم لحالة التنفيذ

- [x] إضافة `SessionExecutionState` و`SessionExecutionSnapshot` في agent domain.
- [x] إضافة repository والـmigration للـsnapshot الدائمة.
- [x] إنشاء reducer/owner واحدة تعيد حساب aggregate وفق أولوية القسم 5.2.
- [x] تمرير enqueue/claim/transition/stop عبر transaction تحدث العمل والـsnapshot.
- [x] إصدار `running` عند claim الحقيقي، لا عند استقبال user message فقط.
- [x] إصدار `resuming` عند claim الخاص بـRetry/Change Provider/auto-resume.
- [x] عدم تغيير execution state عند مسح recovery notice.
- [x] إصدار `waiting` و`blocked` دون اعتبارهما idle.
- [x] إصدار `stopping` بعد قبول Stop وقبل انتظار الإلغاء.
- [x] بعد Stop أو terminal transition يعاد الحساب؛ `idle` فقط عند غياب كل العمل
      غير النهائي، مع عدم إلغاء عمل يملكه generation أحدث.
- [x] ضمان idempotency ومنع callback قديمة من الكتابة.
- [x] نجاح اختبارات repository/orchestrator قبل المرحلة 2.

### المرحلة 2: البروتوكول والاستعادة

- [x] إضافة canonical event وpayload parser/builder للحالة.
- [x] إضافة `execution_snapshot` إلى `session_history`.
- [x] إضافة `execution_snapshot` لكل عنصر في `sessions_list` paginated.
- [x] ضمان نفس `event_id` وrevision عبر local/cloud fan-out.
- [x] اختبار stale revision وequal-conflicting revision.
- [x] اختبار restart أثناء `running`, `waiting`, `blocked`, `resuming`, `stopping`.
- [x] اختبار client ثانٍ يتصل أثناء التنفيذ ويحصل على snapshot صحيحة.
- [x] اختبار sessions بلا row قديمة كـ`idle/revision=0`.
- [x] لا تبدأ المرحلة 3 قبل نجاح contract tests.

### المرحلة 3: تحويل Flutter إلى الحالة الصريحة

- [x] إنشاء `SessionExecutionSnapshot` داخل conversations domain.
- [x] استبدال `Set<String> processingSessionIds` بخريطة snapshots لكل جلسة.
- [x] جعل `DeviceConversationStore` يطبق reducer واحدة لكل live/history/list.
- [x] إضافة خرائط per-session للـexecution snapshot وruntime notice وpermission
      request؛ إزالة أي قيمة pending مشتركة على مستوى الجهاز.
- [x] إنشاء `SessionAttentionState` وselector واحد يستخدمه الـsidebar والـcomposer.
- [x] إيقاف `updateProcessingState(type, sessionId)` كمالك للحقيقة.
- [x] تبقى أحداث الرسائل مسؤولة عن المحتوى فقط.
- [x] hydrate snapshots وattention state من history ومن sessions list.
- [x] رفض update أو clear قديم لا يطابق session id أو revision/identity الحالية.
- [x] الحفاظ على snapshots أثناء transport handoff/reconnect.
- [x] تحديث `SessionMessagesCubit` و`SessionCubit` من store واحدة.
- [x] فصل draft request pending قبل `session_created` عن session execution state؛
      لا يختلق العميل session snapshot قبل تأكيد agent.
- [x] عدم مسح active state بسبب `runtime_notice_cleared` أو `final_answer`.
- [x] نجاح اختبارات Flutter domain/data قبل المرحلة 4.

### المرحلة 4: تجربة المستخدم

- [x] sidebar يعرض spinner فقط لـ`running/resuming`.
- [x] `waiting` تعرض حالة انتظار مميزة دون spinner تنفيذ مضلل.
- [x] `blocked` تعرض علامة خطأ/تدخل مستخدم واضحة.
- [x] permission/question تعرض أيقونتها الخاصة ولا تختلط مع runtime error.
- [x] `queued` تعرض علامة queue.
- [x] يستخدم sidebar selector الـattention الموحد وبالأولوية المحددة في القسم 5.2.
- [x] لا تنتقل أيقونة أو رسالة من جلسة إلى جلسة عند navigation أو history race.
- [x] `stopping` تعرض زر Stop معطلًا وتستبدل أيقونة الإيقاف بمؤشر دائري أحمر
      داخل الزر حتى يصدر الوكيل snapshot تالية.
- [x] زر Stop يعتمد على `canStop` وليس `isProcessing`.
- [x] composer يجمع execution state وruntime notice وpermission suspension كلًا
      على حدة.
- [x] Change Provider يبقي الجلسة `resuming/running` حتى الانتقال النهائي.
- [x] reconnect لا يسبب active/idle flicker؛ تبقى snapshot السابقة حتى وصول
      snapshot مساوية أو أحدث.
- [x] اختبارات widget تغطي الحالات السبع وخصائص العرض المشتقة.

### المرحلة 5: route revision وauto-failover المرئي

- [x] توسيع `session_preferences_updated` بالحقول في القسم 8.
- [x] توحيد جميع route mutations تحت owner واحدة ذات `route_revision` دائم.
- [x] تحديث session route وكل work items غير النهائية داخل transaction واحدة.
- [x] تحديث model chip في كل clients من confirmation authoritative.
- [x] حفظ auto-failover route transition وإعادتها في history.
- [x] عرض informational event يذكر provider القديم والجديد والسبب والنموذج.
- [x] منع التكرار بين live/history وlocal/cloud بالهوية المنطقية نفسها.
- [x] اختبار exact model وثبات model id.
- [x] اختبار استبعاد `allow_auto_failover=false` وغير الجاهزة والمستبعدة.
- [x] اختبار عدم وجود بديل: لا route revision جديدة ولا switch event.

### المرحلة 6: إزالة المسار القديم والتحقق النهائي

- [x] حذف event-name processing heuristics بعد اكتمال migration.
- [x] حذف booleans/mirrors غير اللازمة دون ترك مصدرين للحقيقة.
- [x] تحديث الاختبارات القديمة لتختبر snapshots والعقود بدل أسماء الأحداث.
- [x] اختبار FIFO وqueue وStop وRetry وChange Provider وauto-resume.
- [x] اختبار local-only وcloud-only وlocal+cloud.
- [x] اختبار disconnect/reconnect أثناء كل حالة غير نهائية.
- [x] اختبار عميلين مفتوحين على الجلسة نفسها.
- [x] تشغيل analyzers والاختبارات المركزة والسريعة المتأثرة واختبارات عقود socket/
      restart persistence.
- [x] تشغيل `graphify update .` بعد تغييرات الكود والتوثيق.
- [x] إبقاء الحالة `ready_for_review` حتى تكتمل مراجعة المستخدم اليدوية؛ التحقق
      الآلي مكتمل ولا يوجد stage أو commit.

## 10. الملفات المتوقعة

القائمة إرشادية ويجب تحديثها إذا كشف التنفيذ owner أوضح.

### ملفات جديدة مرجحة

- `agent/lib/evolution/models/session_execution_snapshot.dart`
- `agent/lib/evolution/db/runtime/session_execution_snapshot_repository.dart`
- `client/lib/features/conversations/domain/models/session_execution_snapshot.dart`
- migration/schema ownership داخل `agent/lib/evolution/db/agent_state_database.dart`

### ملفات agent مرجحة التعديل

- `agent/lib/evolution/db/agent_state_database.dart`
- `agent/lib/evolution/db/runtime/session_work_item_repository.dart`
- `agent/lib/evolution/db/runtime/runtime_state_cleanup.dart`
- `agent/lib/evolution/db/persisted_runtime_state_repository.dart` كـfacade/exports فقط
- `agent/lib/interfaces/runtime/session_run_orchestrator.dart`
- `agent/lib/interfaces/runtime/session_turn_executor.dart`
- `agent/lib/interfaces/runtime/session_queue_coordinator.dart`
- `agent/lib/interfaces/runtime/session_recovery_restorer.dart`
- `agent/lib/interfaces/platforms/sanad_gateway/handlers/session_query_handler.dart`
- `agent/lib/interfaces/platforms/sanad_gateway/handlers/session_recovery_command_handler.dart`
- `agent/lib/interfaces/platforms/sanad_gateway/protocol/canonical_events.dart`
- `agent/lib/interfaces/platforms/sanad_gateway/sanad_protocol_bridge.dart`
- `agent/lib/core/provider_runtime/runtime_recovery_service.dart`

لا يضاف منطق domain جديد إلى `sanad_protocol_bridge.dart`؛ يبقى dispatcher/
translator، وتوضع الأوامر في handlers/owners المتخصصة.

### ملفات Flutter مرجحة التعديل

- `client/lib/features/conversations/domain/stores/device_conversation_store.dart`
- `client/lib/features/conversations/domain/stores/processing_store.dart`
- `client/lib/features/conversations/domain/models/session_attention_state.dart`
- `client/lib/features/conversations/data/transport/conversation_event_handler.dart`
- `client/lib/features/conversations/data/transport/conversation_commands.dart`
- `client/lib/features/conversations/presentation/bloc/session_cubit.dart`
- `client/lib/features/conversations/presentation/bloc/session_state.dart`
- `client/lib/features/conversations/presentation/bloc/session_messages_cubit.dart`
- `client/lib/features/conversations/presentation/widgets/sidebar/sidebar_conversation_row.dart`
- `client/lib/features/conversations/presentation/widgets/sidebar/device_workspace_sidebar.dart`
- `client/lib/features/conversations/presentation/widgets/conversation_input_panel.dart`
- `client/lib/features/conversations/presentation/widgets/conversation_input/`

## 11. تحديثات التوثيق المطلوبة

- [x] تحديث `docs/technical/agent_database_schema.md` بالجدول والـrevision/migration.
- [x] تحديث `docs/technical/communication_protocols.md` بعقد execution snapshot
      وordering والاستعادة.
- [x] تحديث `docs/technical/provider_protocol.md` بعقد route revision وauto-failover.
- [x] تحديث `docs/technical/client_conversation_cache_schema.md`: يخزن cache
      `route_revision` المؤكدة فقط؛ execution/attention snapshots تبقى داخل store
      الجهاز وتستعاد من daemon list/history.
- [x] توثيق per-session attention state، وعدم مشاركة runtime notice أو permission
      request على مستوى الجهاز.
- [x] إضافة/تحديث QA matrix تغطي الحالات السبع وper-session isolation وnavigation
      races وdual-client/reconnect وroute deduplication.
- [x] تحديث فهرس `docs/qa_maintenance/MOC.md`؛ لا يوجد `docs/llms.txt` في checkout
      الحالي لتحديثه.
- [x] تعديل أقرب `AGENTS.md` فقط لعقد عزل الجولة التشغيلي الدائم؛ لا توضع schema أو
      event payload أو شرح التصميم داخل `AGENTS.md`.

## 12. التحقق المطلوب

### Agent

- [x] `fvm dart analyze` داخل `agent/`.
- [x] اختبارات repository/migration المركزة.
- [x] اختبارات orchestrator وsession handlers وgateway delivery المركزة.
- [x] اختبارات restart persistence وعقود gateway/dual delivery.

### Client

- [x] `fvm flutter analyze` داخل `client/`.
- [x] اختبارات store/event handler/cubits المركزة.
- [x] widget tests لجميع الحالات السبع.
- [x] اختبارات dual-connection/handoff السريعة؛ السيناريو السحابي الحي الحصري
      يظل خارج مراجعة worktree المحلية.

الاختبارات التي تربط منافذ حقيقية فقط تشغل بـ`--concurrency=1`؛ لا يطبق ذلك
على unit/widget suites العادية.

## 13. معايير القبول

- [x] Change Provider لا تعرض الجلسة idle أثناء الاستكمال.
- [x] Retry وauto-resume وauto-failover تعرض الحالة الصحيحة حتى النهاية.
- [x] blocked/waiting لا تعرضان كجلسة بلا عمل.
- [x] إكمال work item مع بقاء queue لا ينتج `idle` خاطئة.
- [x] missed terminal event يصحح عبر snapshot بعد reconnect.
- [x] لا يستطيع event أقدم من cloud أو local التراجع عن execution/route revision أحدث.
- [x] payload متعارضة بنفس revision ترفض وتظهر كخطأ contract قابل للتشخيص.
- [x] Stop متاح للحالات القابلة للإيقاف، يصبح `stopping` بعد القبول، ويعرض
      مؤشرًا دائريًا أحمر داخل الزر المعطل، ثم يعاد حساب الحالة دون إفساد
      generation أحدث.
- [x] auto-failover ظاهر للمستخدم وقابل للاستعادة ويحدث provider/model chip في
      كل clients.
- [x] session route وكل work items غير النهائية تصبح على provider الجديد،
      والنموذج يبقى exact match.
- [x] لا يوجد استنتاج لحالة التنفيذ من `final_answer`, `error`, `stopped`,
      `in_flight`, أو `runtime_notice_cleared`.
- [x] لا يوجد مصدران متنافسان لحالة الجلسة داخل Flutter.
- [x] runtime notice وpermission request وattention state محفوظة ومطبقة لكل
      session id، ولا توجد قيمة مشتركة على مستوى الجهاز.
- [x] خطأ أو permission prompt في الجلسة A لا يظهر في الجلسة B ولا يغير أيقونتها
      أو composer الخاص بها.
- [x] history/live/navigation races لا تنقل رسالة أو أيقونة بين الجلسات.
- [x] لا يظهر route informational event مرتين عند وصول local وcloud أو عند دمج
      live مع history.

## 14. خارج النطاق

- ترتيب failover مخصص من المستخدم.
- fuzzy أو alias model matching بين مزودين مختلفين.
- إعادة تصميم conversation timeline بالكامل.
- تغيير سياسة ترتيب مرشحي auto-failover الحالية خارج ضمان exact model match.
- توحيد revisions المختلفة في global session revision واحدة.
