---
title: "Task 32a: Session Query Pagination and Ordering"
parent_plan: "docs/plans/32-device-workspace-conversation-ux-redesign.md"
status: "complete"
current_gate: "A3"
---

# Task 32a: Session Query Pagination and Ordering

## الحالة والاعتماديات

- الحالة: `complete`.
- تسبق: `32b`, `32c`, و`32f`.
- يمكن أن ينفذها وكيل مستقل يملك ملفات agent protocol/database وclient transport فقط.
- المرجع الحاكم: `sanad-agent/docs/plans/32-device-workspace-conversation-ux-redesign.md`.

## قاعدة التنفيذ والتحديث

- [x] ينقل الوكيل status إلى `in_progress` عند بدء A0 ويحدث لوحة الخطة الرئيسية.
- [x] لا يعمل إلا على Gate واحدة ولا يبدأ التالية قبل Exit review.
- [x] يسجل نتائج الاختبارات والتوثيق والملفات المعدلة في سجل التقدم أدناه.
- [x] ينتقل إلى `in_review` بعد A3 فقط، وإلى `complete` بعد مراجعة كل القبول.

## بوابات التنفيذ

### Gate A0: Contract and Data Audit

- [x] تدقيق schema و`get_sessions` وكل consumers الحالية.
- [x] تثبيت request/response typed contract وcursor semantics وtie-breaker.
- [x] تحديد migration/fallback للجلسات بلا `last_user_message_at`.
- [x] تحديد defaults والحد الأعلى للـlimit في owner مركزي.
- [x] توثيق أي تعارض مع Plan 31 قبل تعديل التنفيذ. (لا يوجد تضارب أو ملفات تخص Plan 31 في المستودع).

#### Gate A0 Exit

- [x] مراجعة العقد واعتماده قبل أي migration أو transport cutover.

### Gate A1: Agent Persistence and Query

- [x] تنفيذ migration وحفظ `last_user_message_at` authoritative.
- [x] تنفيذ filtered keyset pagination وworkspace metadata.
- [x] ضمان أن user canonical acceptance فقط يرفع الترتيب.
- [x] اختبارات database/query/migration ناجحة.

#### Gate A1 Exit

- [x] مراجعة query plans والثبات وعدم التكرار قبل Client transport.

### Gate A2: Protocol and Client Data Cutover

- [x] تمرير العقد عبر local/cloud protocol.
- [x] إضافة typed query/result models في client.
- [x] تحويل repository دون auto-fetch لكل الصفحات.
- [x] إثبات التوافق أو إزالة fallback القديم بعد اكتمال consumers.

#### Gate A2 Exit

- [x] contract tests عبر agent/client معتمدة قبل A3.

### Gate A3: Verification, Documentation, and Handoff

- [x] إغلاق كل حالات الاختبار المذكورة في المهمة.
- [x] تحديث العقود والوثائق المالكة.
- [x] تسجيل نتائج التحليل والسويتات المتأثرة.
- [x] تسليم query API المستقرة إلى 32b وتحديث لوحة الخطة الرئيسية.

#### Gate A3 Exit

- [x] status تصبح `in_review` ثم `complete` بعد المراجعة، ويمكن بدء 32b.

## الهدف

تحويل `get_sessions` من snapshot كاملة غير مفلترة إلى استعلام paginated يستطيع جلب محادثات Workspace واحدة أو المحادثات غير المرتبطة، بترتيب authoritative حسب أحدث رسالة مستخدم.

## النطاق

### Agent

- توسيع request model لقبول `workspace_id`, `unscoped_only`, `limit`, و`cursor`.
- إضافة query قاعدة بيانات ذات ترتيب ثابت تنازليًا حسب `last_user_message_at`.
- إضافة tie-breaker ثابت يمنع تكرار أو فقد عناصر بين الصفحات.
- تحديث `last_user_message_at` فقط عند حفظ رسالة مستخدم canonical مقبولة.
- إعادة workspace display metadata داخل كل session payload.
- إرجاع `next_cursor` و`has_more`.
- الحفاظ على توافق مؤقت للطلب القديم بلا pagination خلال migration إذا كانت هناك consumers قائمة تحتاجه، ثم إزالة المسار القديم عند اكتمال cutover.

### Client transport/data

- تعريف query/result models typed بدل تمرير خرائط خام إلى presentation.
- تمرير filters وcursor إلى command gateway.
- عدم تجميع كل الصفحات تلقائيًا داخل repository.
- إبقاء live session events قابلة لتحديث الصفحة الأولى دون refresh كامل.

## عقد الترتيب

- المفتاح الأول: `last_user_message_at DESC`.
- المفتاح الثاني: session identity ثابتة باتجاه متوافق مع cursor.
- assistant/tool/system events لا ترفع الجلسة.
- رسالة user queued أو steer ترفع الجلسة عند قبولها canonical حسب تعريف daemon، ولا تعتمد الواجهة على optimistic local timestamp.
- الجلسات القديمة التي لا تملك القيمة تستخدم fallback موثقًا أثناء migration، ثم تخزن قيمة صحيحة عند أول رسالة مستخدم لاحقة.

## قواعد pagination

- `workspace_id` يعني جلسات تلك Workspace فقط.
- `unscoped_only=true` يعني `workspace_id IS NULL` أو القيمة canonical المكافئة فقط.
- اجتماع الحقلين خطأ request واضح.
- `limit` له default وحد أعلى مركزيان وغير مبعثرين كقيم سحرية.
- cursor opaque للعميل ويشمل مفاتيح الترتيب اللازمة.
- الاستجابة الفارغة تعيد `has_more=false`.
- session جديدة أثناء paging تظهر عبر live event والصفحة الأولى، ولا تفسد cursor صفحة تم تحميلها بالفعل.

## حالات الاختبار

- أول ست جلسات لكل filter مرتبة حسب آخر user message.
- Load more لا يكرر ولا يفقد جلسة عند تعادل timestamps.
- user message في جلسة قديمة يجعلها أول نتيجة.
- assistant final answer وحده لا يغير ترتيبها.
- الفصل الصحيح بين Workspace A وWorkspace B وunscoped.
- workspace metadata تستعاد بعد daemon restart.
- cursor غير صالح يعيد خطأ منظمًا.
- local وcloud gateway يعيدان الدلالة نفسها.

## الملفات المتوقعة

- `sanad-agent/agent/lib/evolution/db/session_db.dart`
- `sanad-agent/agent/lib/interfaces/session_payload_builder.dart`
- `sanad-agent/agent/lib/interfaces/platforms/sanad_gateway/sanad_protocol_bridge.dart`
- `sanad-agent/agent/lib/interfaces/platforms/sanad_gateway/protocol/`
- `sanad-agent/client/lib/features/conversations/data/transport/conversation_commands.dart`
- `sanad-agent/client/lib/features/conversations/data/clients/socket_conversation_client.dart`
- `sanad-agent/client/lib/features/conversations/data/repositories/socket_conversation_repository.dart`
- conversation domain query/result models المناسبة.

## تحديثات التوثيق المطلوبة عند التنفيذ

- `sanad-agent/docs/technical/communication_protocols.md`
- `sanad-agent/docs/technical/agent_database_schema.md`
- `sanad-agent/agent/lib/interfaces/AGENTS.md`
- `sanad-agent/client/lib/features/AGENTS.md`

## Definition of Done

- [x] العقد typed ومغطى باختبارات agent وclient transport.
- [x] pagination/filtering ينفذان في مصدر البيانات ولا يعتمدان على تصفية قائمة كاملة في Flutter.
- [x] `last_user_message_at` authoritative ودائم.
- [x] لا يوجد consumer جديد يعتمد على get-all sessions.
- [x] تسلم المهمة عقدًا مستقرًا إلى `32b` قبل بدء دمج UI.

## سجل التقدم

### [2026-07-13] المراجعة المستقلة النهائية وإغلاق 32a

#### 1. ملاحظات ظهرت في المراجعة وأُغلقت
- تصحيح startup recovery حتى لا يبدأ work item في حالة `waiting` ثم يصححها بعد التنفيذ؛ الاستئناف الآمن يمر الآن عبر claim ذري إلى `resuming` قبل تشغيل runner.
- منع auto-resume لأي checkpoint غامضة أو أداة executing غير replay-safe؛ تتحول هذه الحالات إلى `blocked` مع suspended owner قابلة لـRetry/Stop.
- إزالة suspended ownership وحالة busy بعد نجاح auto-resume، مع إبقاء FIFO للرسائل الأحدث.
- منع clear مكرر لـ`resuming` notice، واستعادة assertions الدقيقة لمسارات provider/model في اختبارات Plan 30.
- فصل كاش `getSessions()` الانتقالي الذي يجمع كل الصفحات عن كاش الطلب paginated غير المفلتر، وإضافة coalescing للطلبات المتطابقة وgeneration guard للردود القديمة.

#### 2. دليل التحقق النهائي
- ناجح: `fvm dart analyze` في `agent/`.
- ناجح: اختبارات recovery/query المستهدفة، وتشمل `interfaces_test.dart`, `persisted_runtime_state_repository_test.dart`, `sanad_bridge_provider_test.dart`, و`gateway_delivery_routing_test.dart`.
- ناجح: `fvm dart test` الكامل في `agent/`.
- ناجح: `fvm flutter analyze` في `client/`.
- ناجح: `socket_conversation_client_test.dart` مع 14 حالة.
- ناجح: `fvm flutter test` الكامل في `client/` مع 373 حالة.
- ناجح: `git diff --check`.
- نتيجة المراجعة: لا توجد ملاحظات مفتوحة تمنع تسليم العقد إلى 32b؛ انتقلت 32a من `in_review` إلى `complete`.

### [2026-07-13] إعادة فتح 32a بعد مراجعة التنفيذ

#### 0. الحالة الحالية بعد تنفيذ الإصلاحات
- الحالة أصبحت `in_review` وليست `complete`.
- التحقق المطلوب لهذه الجولة اكتمل، لكن المهمة تبقى مفتوحة حتى تمر مراجعة مستقلة أخيرة.

#### 1. ما الذي تم إصلاحه في هذه الجولة
- إلغاء اشتقاق `last_user_message_at` من history أثناء كل `saveSessionHistory`، وجعل التحديث authoritative عبر قبول user/steer canonical فقط.
- تمرير `received_at` canonical إلى مسار الحفظ الفعلي لرسالة المستخدم حتى لا يغيّر assistant/tool ordering لاحقًا.
- توحيد timestamp normalization في التخزين والمهاجرات والـ cursor، مع رفض cursor ذات timestamps غير الصالحة بدل قبول JSON صحيح زمنيًا بشكل فاسد.
- تطبيع `workspace_id` الفارغة إلى `NULL` وإضافة indices تدعم استعلامات الترتيب والـ workspace والمهاجرة.
- إصلاح `saveSession` حتى يستخدم fallback `created_at` عند INSERT الجديد فقط، بينما يحتفظ UPDATE بالقيمة المخزنة إذا كانت `last_user_message_at` الواردة `null`.
- تمرير `last_user_message_at` خلال تحديثات provider/model/thinking mode/workspace بدل السماح بإعادة ضبطها ضمنيًا.
- جعل migration لـ `last_user_message_at` idempotent، تعمل فقط على الصفوف التي تحتاج normalization/backfill، وتستخدم batches محدودة بدل `IN` غير محدود.
- إعادة عقد history إلى الدلالة الصحيحة: لا `runtime_notice: null`، ولا `metadata`/`request_id` عندما تكون غائبة، مع fallback lazy للـ blocked notice persisted-only فقط.
- عزل `sessions_list` المفلترة/المجزأة عن الـ default sessions stream في العميل، وجعل الكاش keyed بواسطة هوية الاستعلام كاملة بدل تلويث snapshot العامة.
- منع reconnect من دمج stale cache داخل الصفحة authoritative القادمة من daemon، مع استبدال snapshot فور وصول الرد الحقيقي.
- إبقاء مسار توافق مؤقت للـconsumer الحالي: `getSessions()` بلا query في العميل يجلب كل الصفحات داخليًا حتى لا تختفي الجلسات الأقدم قبل تحويل 32b إلى pagination UI صريح.
- تحديث stubs المتأثرة بإضافة `receivedAt`، وإصلاح claim guard في `session_work_items` حتى لا يحاول claim عنصر queued بينما يوجد active item قائم.
- إصلاح اختبارات الـ query والـ bridge والعميل، وتحديث العقود التقنية والوثائق المالكة المرتبطة بـ 32a.

#### 2. حالة التحقق الحالية
- ناجح: `fvm dart analyze` في `agent/`.
- ناجح: `fvm flutter analyze` في `client/`.
- ناجح: `fvm dart test test/evolution/session_db_workspace_test.dart`.
- ناجح: `fvm dart test test/interfaces/sanad_bridge_test.dart`.
- ناجح: `fvm dart test test/interfaces/sanad_bridge_provider_test.dart`.
- ناجح: `fvm dart test test/interfaces/gateway_delivery_routing_test.dart`.
- ناجح: `fvm dart test test/interfaces/interfaces_test.dart`.
- ناجح: `fvm dart test`.
- ناجح: `fvm flutter test`.
- ناجح: `git diff --check`.
- المفتوح الوحيد قبل `complete`: مراجعة مستقلة أخيرة.

### [2026-07-13] السجل السابق من الوكيل المنفذ

#### 1. ملخص ما تم إنجازه
- **قاعدة البيانات والترحيل (DB & Migrations):**
  - إضافة عمود `last_user_message_at` إلى جدول `sessions`.
  - كتابة ترحيل ديناميكي آمن يقوم باستخراج وقت آخر رسالة مستخدم من جدول `messages` وإذا لم توجد يستخدم `updated_at`/`created_at`.
  - تطبيق التحديث المباشر لحقل `last_user_message_at` عند وصول steer أو enqueuing لرسالة مستخدم canonical مقبولة.
- **استعلامات Pagination:**
  - تنفيذ keyset pagination SQL مدمج مع tie-breaker فريد (`session_id`).
  - دعم التصفية المتبادلة لـ `workspace_id` أو `unscoped_only`.
- **بروتوكول العميل والنقل (Client Transport):**
  - إنشاء نماذج طلب واستجابة مهيكلة: `SessionQueryRequest` و`SessionQueryResult`.
  - تحديث `ConversationCommands` و`SocketConversationClient` و`SocketConversationRepository` لدعم pagination والتعامل الذكي مع الكاش وتفادي الازدواجية في تحديث stream الجلسات.
- **الاختبارات:**
  - كتابة وتمرير 5 اختبارات شاملة للـ DB والترحيل والـ Pagination في `session_db_workspace_test.dart`.
  - التحقق من تمرير كامل الـ 157 اختباراً لوحدات ومكاملة العميل (Client Unit/Integration Tests) بنجاح كامل بدون أي خطأ.
