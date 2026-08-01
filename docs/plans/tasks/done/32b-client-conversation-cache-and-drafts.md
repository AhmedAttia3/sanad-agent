---
title: "Task 32b: Client Conversation Cache and Drafts"
parent_plan: "docs/plans/32-device-workspace-conversation-ux-redesign.md"
status: "complete"
current_gate: "closed"
---

# Task 32b: Client Conversation Cache and Drafts

## الحالة والاعتماديات

- الحالة: `complete` — أغلقت بعد المراجعة المستقلة وإصلاح ملاحظاتها.
- تسبق: `32c`, `32d`, `32e`, و`32f`.
- ملكية الوكيل: conversation domain/data stores وطبقة persistence؛ لا يعيد تصميم widgets.
- المرجع الحاكم: `sanad-agent/docs/plans/32-device-workspace-conversation-ux-redesign.md`.

## قاعدة التنفيذ والتحديث

- [x] لا يبدأ B0 قبل أن تصبح 32a `complete` ويثبت عقدها في الخطة الرئيسية.
- [x] يحدث الوكيل status وcurrent gate ولوحة الخطة عند كل انتقال.
- [x] لا تعد واجهات store مستقرة للمهام المتوازية قبل B3 Exit.
- [x] لا تصبح المهمة `complete` قبل B4 review.

## بوابات التنفيذ

### Gate B0: Ownership and Cache Schema

- [x] تدقيق الخرائط والمخازن الحالية وتحديد ما يزال وما يزال يهاجر.
- [x] تعريف domain snapshots وresource states ومفاتيح versioned.
- [x] تعريف logout/local inventory boundary وسياسة الحجم والتنظيف.
- [x] اعتماد persistence backend متعدد المنصات دون تخزين أسرار.

#### Gate B0 Exit

- [x] مراجعة schema وownership قبل كتابة persistence implementation.

### Gate B1: Persistent Storage and Migration

- [x] تنفيذ serialization/version migration والإبطال الآمن.
- [x] تنفيذ load/save/cleanup وحدود الحجم.
- [x] إثبات recovery بعد restart وعزل أجهزة وحسابات مختلفة.
- [x] اختبارات persistence مستقلة ناجحة.

#### Gate B1 Exit

- [x] مراجعة بيانات التخزين والأمان قبل ربط live state.

### Gate B2: Store, Pagination Merge, and Live Events

- [x] تنفيذ stale-while-revalidate وحالات resource.
- [x] دمج الصفحات بلا تكرار ورفض responses القديمة.
- [x] تطبيق created/updated/deleted/user-message events.
- [x] حفظ last session وWorkspace expansion.
- [x] اختبارات store/repository ناجحة.

#### Gate B2 Exit

- [x] مراجعة invariants والordering قبل إضافة drafts وcutover.

### Gate B3: Drafts and Stable Consumer API

- [x] تنفيذ drafts لكل session وNew Conversation لكل جهاز.
- [x] تنفيذ debounce/lifecycle flush ونقل هوية new draft.
- [x] تحويل cubits إلى APIs الموحدة وإزالة مصادر الحالة المنافسة.
- [x] تثبيت interfaces المستهلكة بواسطة 32c/32d/32e.

#### Gate B3 Exit

- [x] مراجعة API وتسجيلها stable؛ بعدها فقط تفتح المهام 32c/32d/32e.

### Gate B4: Verification, Documentation, and Handoff

- [x] إغلاق حالات cold start/restart/logout/delete/failure.
- [x] تحديث client contracts والوثائق التقنية وQA.
- [x] تسجيل التحليل والاختبارات والملفات المعدلة.
- [x] تحديث لوحة الخطة وتسليم interfaces للمهام المتوازية.

#### Gate B4 Exit

- [x] status تصبح `in_review` ثم `complete` بعد المراجعة.

## الهدف

إنشاء owner موحد في Flutter للكاش الدائمة ومسودات المحادثات وحالة كل جهاز، وتقديم snapshots مستقرة للواجهة وفق stale-while-revalidate.

## نموذج البيانات

يجب أن يمثل store على الأقل:

- active device context.
- cached Workspace list لكل جهاز.
- صفحة unscoped conversations لكل جهاز.
- صفحات conversations لكل `deviceId + workspaceId`.
- cursors و`hasMore` وحالة التحميل والخطأ ووقت آخر تحديث لكل resource.
- آخر session مختارة لكل جهاز.
- expansion preference لكل Workspace.
- draft لكل session وNew Conversation draft لكل جهاز.

تستخدم مفاتيح namespaced/versioned تسمح بترحيل schema أو إبطال نسخة قديمة دون crash.

## قواعد persistence

- تحفظ snapshots اللازمة لإعادة بناء sidebar بعد إعادة التشغيل.
- تعرض memory snapshot فورًا ثم persistent snapshot ثم remote refresh دون blank intermediate state.
- الكتابات المتكررة مثل draft text تستخدم debounce وتُflush عند lifecycle pause/close بقدر ما تسمح المنصة.
- لا تخزن tokens أو credentials أو raw transport payloads.
- لا تخزن history كاملة لكل sessions ضمن هذه المهمة.
- logout ينظف cloud user scope ويحافظ على local desktop scope وفق inventory boundary.
- حذف جهاز أو session أو Workspace ينظف keys التابعة لها.

## API المقدم للواجهة

يجب أن تكون العمليات intent-based، مثل:

- select/switch device context.
- observe device sidebar snapshot.
- refresh Workspaces أو conversation section.
- load more لقسم محدد.
- set Workspace expansion preference.
- read/write/clear conversation draft.
- record/restore last selected session.
- apply canonical session created/updated/deleted/user-message event.

لا تتعامل widgets مباشرة مع قاعدة التخزين أو serialization أو cursor merging.

## دمج البيانات والأحداث

- refresh يدمج snapshot ولا يستبدل state بخريطة فارغة.
- item identity تعتمد على `deviceId + sessionId`.
- live user message تحدث timestamp ثم تعيد ترتيب القسم في snapshot واحدة.
- session_created توضع في القسم الصحيح وفق `workspace_id`.
- session_deleted تزال من كل الصفحات والمسودات ومؤشرات الاختيار.
- الصفحات المتداخلة تدمج بلا تكرار وتحافظ على server order.
- response قديمة تحمل request generation غير الحالية لا تستبدل نتيجة أحدث.

## المسودات

- existing session draft key: `deviceId + sessionId`.
- New Conversation draft key مستقل لكل جهاز.
- draft الجديدة تشمل Workspace الاختيارية وprovider/model/thinking/permission mode.
- إرسال الرسالة لا يمسح النص حتى يصل canonical user acceptance المطابق للطلب.
- فشل الإرسال يبقي النص.
- إنشاء session ينقل الربط من new draft إلى session identity بأمان.
- session deletion تمسح draft.

## حالات الاختبار

- cold start يعرض persistent snapshot قبل remote response.
- device switch يعرض cache الخاصة به ولا يسرب بيانات الجهاز السابق.
- refresh failure يبقي البيانات ويحول الحالة إلى stale error.
- restart يستعيد expansion وآخر session والمسودات.
- user event يعيد ترتيب session في cache فورًا.
- حذف session ينظف draft والصفحات والاختيار.
- logout لا يمسح local inventory cache.
- schema version قديمة تهاجر أو تُبطل بأمان.
- debounce لا يفقد آخر نص عند lifecycle flush.

## الملفات المتوقعة

- models/stores جديدة داخل `sanad-agent/client/lib/features/conversations/domain/`.
- repository/persistence implementation داخل `sanad-agent/client/lib/features/conversations/data/`.
- composition داخل `sanad-agent/client/lib/core/presentation/app/app_providers.dart` أو DI owner المناسب.
- تكامل محدود مع `session_cubit.dart` و`session_messages_cubit.dart` لإزالة الخرائط المتفرقة بعد cutover.

## تحديثات التوثيق المطلوبة عند التنفيذ

- `sanad-agent/client/lib/features/AGENTS.md`
- وثيقة تقنية جديدة أو قائمة تصف client conversation cache schema وownership.
- QA recovery documentation لاستعادة cache/drafts.

## Definition of Done

- [x] مصدر client state واحد للكاش والمسودات وحالة الجهاز.
- [x] persistent recovery تعمل بعد إعادة التشغيل.
- [x] UI consumers لا تملك persistence logic.
- [x] daemon يظل authoritative ولا توجد history database منافسة في Flutter.
- [x] واجهات store مستقرة وجاهزة للمهام `32c` إلى `32e`.

## سجل التقدم

### 2026-07-13 — بدء Gate B0 (Ownership and Cache Schema)

- **Task/Gate:** 32b / Gate B0
- **Status transition:** `pending` → `in_progress`
- **Owner/worktree:** `32b-client-conversation` worktree (`.agent/worktrees/32b-client-conversation`)
- **Audit of current client state:**
  - `SessionCubit` (539 سطرًا) يملك `agentSessions: Map<deviceId, List<Session>>` مسطّحة، غير paginated، غير cached على القرص، وتمزج بين default snapshot وrequest-scoped responses بلا cacheKey isolation.
  - `DeviceConversationStore` (376 سطرًا) يملك message history + processing/queued/runtime-notice state لكل جهاز — هذا المكون يبقى كما هو (يملك history runtime، لا يدخل في 32b).
  - `SessionSidebarCubit` (27 سطرًا) يملك expandedAgentIds فقط — لا يملك expansion preference لكل workspace ولا lastSelectedSessionId ولا drafts.
  - `ProcessingStore` مركزي لكل الأجهزة، يبقى كما هو.
  - لا يوجد persistence backend حاليًا لأي من: cached workspaces، conversation pages، drafts، expansion prefs، last session.
  - الموجود في `SharedPreferences` (عبر `DevicePreferencesRepositoryImpl`): model + thinking mode فقط لكل deviceId.
- **Dependencies:** لا تبعيات على كود 32b الموجود حاليًا خارج ملفات 32b الجديدة (نطاق مضاف فقط، لا تعديل تخريبي للمستهلكين الحاليين في هذه البوابة).
- **Open findings/blockers:** لا يوجد.
- **Next gate/owner:** B0 exit (schema + ownership review)، ثم B1 (persistence implementation).

### 2026-07-13 — Gate B0/B1/B2/B4 (تنفيذ كامل للبنية التحتية)

- **Task/Gate:** 32b / B0→B4
- **Status transition:** `in_progress` → `in_review`
- **Completed (الملفات الجديدة):**

  Domain models (9 ملفات):
  - `domain/models/conversation_resource_state.dart` — حالات `notLoaded/loading/refreshing/ready/staleError`.
  - `domain/models/conversation_section_page.dart` — صفحة محادثة cursor-aware.
  - `domain/models/cached_workspace_section.dart` — snapshot لقائمة workspaces.
  - `domain/models/conversation_draft.dart` — مسودة محادثة (نص + workspace + provider/model/thinking/permission).
  - `domain/models/device_conversation_context.dart` — شريحة حالة كاملة لكل جهاز.
  - `domain/models/device_conversation_cache_snapshot.dart` — root snapshot للكاش.
  - `domain/models/request_generation.dart` — monotonic token لرفض responses القديمة.
  - `domain/models/sidebar_conversation_group.dart` — group جاهز للعرض.
  - `domain/models/device_sidebar_snapshot.dart` — sidebar view-model.

  Domain store + interfaces:
  - `domain/stores/conversation_cache_store.dart` — الـ owner الموحد (memory cache + merge + events + drafts + cleanup).
  - `domain/repositories/conversation_cache_persistence.dart` — واجهة backend متعدد المنصات.

  Data layer:
  - `data/persistence/conversation_cache_codec.dart` — JSON codec versioned (v1) مع invalidation آمن.
  - `data/persistence/shared_preferences_conversation_cache_persistence.dart` — SharedPreferences backend.
  - `data/persistence/conversation_cache_persistor.dart` — debounced persistence + lifecycle flush.
  - `data/repositories/conversation_cache_repository.dart` — intent-based facade للواجهة.

  DI:
  - `core/di/injection.dart` — تسجيل `ConversationCacheStore` + `ConversationCachePersistence` + `ConversationCachePersistor`.

- **Verification evidence:**
  - `fvm dart analyze lib/` = 0 issues.
  - `fvm dart analyze test/unit/persistence/ test/unit/stores/ test/unit/repositories/` = 0 issues.
  - اختبارات: 32 اختبارًا ناجحًا (codec 5, store 22, persistor 5, repository 6 — بما في ذلك cold start, device switch, stale rejection, refresh failure, drafts, deletion, logout boundary).
- **Documentation updated:**
  - `client/lib/features/AGENTS.md` — قسم "Conversation Cache and Drafts Ownership (Plan 32b)".
  - `docs/technical/client_conversation_cache_schema.md` — وثيقة تقنية كاملة للـ schema.
  - `docs/qa_maintenance/conversation_cache_recovery_qa.md` — سيناريوهات استعادة QA.
- **Open items at this intermediate checkpoint (أغلقت في إدخال المراجعة التالي):**
  - B3 checkbox "تحويل cubits إلى APIs الموحدة وإزالة مصادر الحالة المنافسة" و "تثبيت interfaces المستهلكة" متروكتان بدون علامة لأن cutover الفعلي لـ `SessionCubit`/`SessionSidebarCubit` يحتاج مراجعة لتجنب كسر المهام المتوازية 32c/32d/32e. البنية الجديدة مضافة ولا تمس المستهلكين الحاليين.
  - DoD الأخير "واجهات store مستقرة وجاهزة" ينتظر مراجعة المراجع.
- **Next gate/owner:** مراجعة بشرية، ثم تحديد ما إذا كان cutover يدوي أم عبر مهمة منفصلة.

### 2026-07-13 — المراجعة المستقلة وإغلاق Gate B3/B4

- **Task/Gate:** 32b / B3→B4 Exit.
- **Status transition:** `in_review` → `complete`.
- **ملاحظات حرجة اكتشفت وأصلحت:**
  - كانت البنية الجديدة غير مستخدمة في runtime: لم يسجل `ConversationCacheRepository`، ولم يستدع `hydrate()`، ولم يوجد lifecycle flush. تم ربطها بالـ DI والـ bootstrap ودورة حياة التطبيق.
  - ظل `SessionCubit` مالكًا لخريطة جلسات منافسة. أصبح في الإنتاج projection مشتقًا من `ConversationCacheStore`، وتطبق أحداث الجلسة canonical على الكاش أولًا.
  - استعلام Conversations غير المرتبطة لم يرسل `unscoped_only`، وكانت أجيال Workspaces وunscoped sessions تتشارك المفتاح نفسه. تم تصحيح الاستعلام وفصل generation ownership.
  - أول refresh كان يحتفظ إلى الأبد بصفوف cached غير موجودة في الرد authoritative. أصبح stale snapshot ظاهرًا أثناء الطلب فقط ثم تستبدله الصفحة الأولى الصحيحة.
  - serialization كتب حقول `Session` بأسماء لا يقرأها `Session.fromJson`، ما كان يفقد device/workspace/last-user-message بعد restart. وحدت الحقول مع العقد canonical ورفعت schema إلى v2.
  - حالات `loading/refreshing` كانت تعود بعد restart ويمكن أن تعلق دون طلب حي. أصبحت تطبع إلى `ready/notLoaded` حسب وجود snapshot.
  - المسودة لم تكن تربط القبول بـ `request_id`، ولم يمكن إزالة Workspace أو إعداد nullable بصورة مستقلة. أضيف pending request correlation وclear intents صريحة، مع نقل آمن لمسودة New Conversation.
  - أصلحت تداخل flush writes، وحددت persistence إلى 50 ملخص جلسة لكل قسم دون الاحتفاظ cursor قد يتجاوز صفوفًا غير مخزنة.
  - refresh Workspaces أصبح ينظف صفحات وتفضيلات Workspaces المحذوفة، وlogout يمسح cloud scope ويفلشه مع الحفاظ على local scope.
- **واجهات مستقرة للمراحل التالية:**
  - `ConversationCacheRepository`: device selection، sidebar snapshots، section refresh/load-more، workspace expansion، last session، drafts، canonical events، cleanup.
  - `DeviceSidebarSnapshot` و`SidebarConversationGroup`: مدخل 32c للعرض المجمع دون cursor أو merge logic داخل widgets.
  - `ConversationDraft` مع `pendingRequestId`: مدخل 32d لربط composer بالمسودة الدائمة.
- **Verification evidence:**
  - `fvm flutter analyze` = no issues.
  - focused cache/persistence/repository/production SessionCubit suite = 61 tests passed.
  - full `fvm flutter test` = 416 tests passed.
  - لم يشغل E2E لأن النطاق client state/persistence داخلي ولا يغير daemon/socket boundary.
- **Open findings/blockers:** لا يوجد ضمن نطاق 32b.
- **Next gate/owner:** تبدأ 32c و32d و32e من الواجهات المثبتة أعلاه.
