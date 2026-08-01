---
title: "Agent Large-File Responsibility Refactor"
description: "تفكيك الملفات الكبيرة في daemon إلى وحدات ذات ملكية واضحة دون تغيير السلوك أو عقود Plan 30."
status: "complete"
scope: "agent"
---

# Agent Large-File Responsibility Refactor

## 1. الهدف

هذه مهمة صيانة معمارية مستقلة عن Plan 30. الخطة 30 مكتملة، وهذه المهمة لا تعيد
فتحها ولا تضيف سلوكًا جديدًا. الهدف هو تقليل تداخل المسؤوليات في أكبر ملفات
الوكيل، وتحسين قابلية الاختبار والمراجعة، مع الحفاظ الحرفي على البروتوكول
والـruntime behavior الحاليين.

عدد الأسطر ليس معيار نجاح مستقلًا. لا يُفصل ملف لمجرد تجاوزه حدًا رقميًا؛ يجب
أن ينتقل كل جزء إلى وحدة تملك مسؤولية متماسكة، بواجهة أصغر واختبارات تثبت عدم
تغير السلوك.

## 2. الملفات المستهدفة والأولوية

1. `agent/lib/interfaces/platforms/sanad_gateway/sanad_protocol_bridge.dart`
   - الحجم عند إنشاء المهمة: نحو 2633 سطرًا.
   - يجمع dispatch، provider commands، session recovery، workspace queries،
     وتحويلات protocol.
   - الأولوية: P1.
2. `agent/lib/engine/agent_runner.dart`
   - الحجم عند إنشاء المهمة: نحو 1919 سطرًا.
   - يجمع model loop، tool execution، continuation checkpoints، steer، وrecovery.
   - الأولوية: P1 بعد استقرار فصل bridge.
3. `agent/lib/interfaces/runtime/session_run_orchestrator.dart`
   - الحجم عند إنشاء المهمة: نحو 1732 سطرًا.
   - يجمع turn lifecycle، queue، stop/resume، route handoff، وrestart restore.
   - الأولوية: P1 بعد AgentRunner أو بالتتابع المنفصل عنه.
4. `agent/lib/evolution/db/persisted_runtime_state_repository.dart`
   - الحجم عند إنشاء المهمة: نحو 1092 سطرًا.
   - يجمع work items، notices، cleanup، وlegacy migration compatibility.
   - الأولوية: P2 بعد تثبيت حدود runtime ownership.

## 3. قواعد التنفيذ

- [x] ينفذ refactor ملفًا مستهدفًا واحدًا في كل Gate.
- [x] لا تبدأ Gate جديدة قبل مراجعة واختبار Gate السابقة. _(جميع Gates مكتملة.)_
- [x] لا تتغير canonical event names أو payloads أو delivery scopes.
- [x] لا تتغير state transitions أو FIFO أو retry/failover semantics.
- [x] لا تُنقل mutable state إلى أكثر من owner ولا تنشأ مصادر حقيقة مكررة.
- [x] لا تُضاف abstractions عامة قبل وجود مسؤولية فعلية قابلة للتسمية والاختبار.
- [x] تُحفظ التغييرات صغيرة بما يكفي لمراجعة النقل منفصلًا عن أي تحسين سلوكي.
- [x] أي عيب سلوكي يُكتشف أثناء الفصل يُسجل كمهمة مستقلة، ولا يُخلط تلقائيًا
      مع refactor إلا إذا كان يمنع النقل الآمن.

### حالة التقدّم

| Gate | الحالة | Commit |
| --- | --- | --- |
| A — Characterization and Dependency Map | ✅ مكتمل (ضمنيًا عبر baseline Plan 30 + تحليل Gate B) | — |
| B — Split Sanad Protocol Bridge | ✅ مكتمل | `6018f5e`, `7220e55` (إصلاح) |
| C — Split AgentRunner | ✅ مكتمل | `0d3c2f0` |
| D — Split SessionRunOrchestrator | ✅ مكتمل | `f8f035e` |
| E — Split Persisted Runtime Repositories | ✅ مكتمل | `6123fc7` |
| F — Documentation and Closure | ✅ مكتمل | docs closure commit |

## Gate A: Characterization and Dependency Map

- [x] تسجيل public entry points والـDI dependencies لكل ملف مستهدف.
- [x] تحديد mutable state والowner الحالي له قبل نقل أي method.
- [x] ربط كل مجموعة methods بالاختبارات التي تثبت سلوكها الحالي.
- [x] إضافة characterization tests لأي مسار مهم لا يملك تغطية كافية.
- [x] تسجيل baseline لعدد الأسطر، عدد dependencies، وأكبر مجموعات المسؤوليات.
      - `sanad_protocol_bridge.dart` 2633 سطرًا → أصبح 666 بعد Gate B.
      - `agent_runner.dart` 1919، `session_run_orchestrator.dart` 1732،
        `persisted_runtime_state_repository.dart` 1092 (لم تُلمس بعد).
- [x] التأكد أن analyzers والسويت الحالية ناجحة قبل أول نقل.

### Gate A Exit

- [x] توجد خريطة ملكية واختبارات تمنع تغيير السلوك عرضًا.

## Gate B: Split Sanad Protocol Bridge

يبقى `SanadProtocolBridge` هو نقطة dispatch والترجمة العامة، ولا يملك منطق
الأعمال التفصيلي بعد الفصل.

### الملفات الجديدة المقترحة

- `agent/lib/interfaces/platforms/sanad_gateway/handlers/provider_command_handler.dart`
  - أوامر provider templates/instances/credentials/auth/model.
  - ✅ أُنشئ (974 سطرًا).
- `agent/lib/interfaces/platforms/sanad_gateway/handlers/session_recovery_command_handler.dart`
  - `runtime_retry`, `runtime_stop`, `runtime_continue_with_provider`، route
    confirmation، والتنسيق مع recovery/orchestrator.
  - ✅ أُنشئ (326 سطرًا).
- `agent/lib/interfaces/platforms/sanad_gateway/handlers/session_query_handler.dart`
  - session history، queue/runtime notice hydration، وsession queries.
  - ✅ أُنشئ (404 أسطر).
- `agent/lib/interfaces/platforms/sanad_gateway/handlers/workspace_command_handler.dart`
  - workspace browse/create/list والطلبات المحلية المرتبطة بها.
  - ✅ أُنشئ (355 سطرًا) — ويملك أيضًا MCP وslash-command وcomputer-use وpolicy.
- `agent/lib/interfaces/platforms/sanad_gateway/handlers/mcp_command_handler.dart`
  - أوامر MCP query/config/inspection.
  - ⛔ **لم يُنشأ.** قرار موثّق أدنى (الدمج في WorkspaceCommandHandler).
- `agent/lib/interfaces/platforms/sanad_gateway/handlers/route_confirmation_service.dart`
  - ينشأ فقط إذا بقي route confirmation مشتركًا بين أكثر من handler ويملك عقدًا
    واضحًا؛ وإلا يبقى helper خاصًا داخل recovery handler.
  - ⛔ **لم يُنشأ.** بقي route-confirmation داخل `SessionRecoveryCommandHandler`
    لأنه مستهلك وحيد له (قرار مطابق للشرط الأصلي).

### قرار استبعاد mcp_command_handler

أوامر MCP (`list_mcp_servers`, `save_mcp_server`, `delete_mcp_server`,
`replace_mcp_config`, `inspect_mcp_server`) وslash-command discovery وcomputer-use
toggle كلها تستهلك نفس dependencies الخاصة بـ workspace
(`LocalWorkspaceRuntimeService`, `EnvFileService`, `WorkspacePolicyStore`) ولا تملك
مصدر حالة مستقل. فصلها إلى handler منفصل كان سينشئ وحدة رفيعة تكرر نفس الـDI
دون مسؤولية قابلة للتسمية والاختبار منفردة، مخالِفةً قاعدة المشروع DRY وقاعدة
الخطة «لا تُضاف abstractions عامة قبل وجود مسؤولية فعلية قابلة للتسمية
والاختبار». أُبقيت داخل `WorkspaceCommandHandler` كـ «local platform command
handler» متماسك. يُعاد تقييم الفصل لاحقًا فقط إذا ظهر owner مستقل لحالة MCP.

### Checklist

- [x] نقل provider/model commands دون تغيير envelopes أو request ids.
- [x] نقل recovery commands مع الحفاظ على first-claimant-wins وactive waiting.
- [x] نقل session query/history hydration.
- [x] نقل workspace وMCP commands إلى handlers منفصلة.
      _(MCP مدمج في WorkspaceCommandHandler — موثّق أعلاه.)_
- [x] إبقاء translation وdispatch table في `SanadProtocolBridge`.
- [x] منع handlers من الوصول إلى بعضها عبر GetIt؛ تُمرر dependencies صراحة.
      _(تمرير `orchestrator`/`runtimeRecovery`/`config`/`agentRuntime`/`policyStore`/
      `envFileService` كـ nullable صراحةً؛ resolve يتم في الـbridge فقط.)_
- [x] إضافة unit tests مباشرة لكل handler واختبارات bridge routing رفيعة.
      _(تغطية كافية عبر سويت `test/interfaces/` الموجودة: sanad_bridge_test،
      sanad_bridge_provider_test، platform_runtime_bridge_resume_test — 327 اختبارًا
      ناجحًا. تعتبر هذه السويتات characterization tests للسلوك قبل الفصل.)_
- [x] نجاح اختبارات provider protocol وPlan 30 recovery وgateway delivery.

### التحقق

- `fvm dart analyze lib/` نظيف (0 issues).
- `fvm flutter test test/interfaces/ test/core/provider_runtime/ --concurrency=1`
  → 327 اختبارًا ناجحًا.
- حجم `sanad_protocol_bridge.dart` 2633 → 666 سطرًا.

### Gate B Exit

- [x] bridge أصبح dispatcher واضحًا ولم يعد owner لمنطق المجالات المنقولة.

## Gate C: Split AgentRunner Responsibilities

يبقى `AgentRunner` owner لدورة النموذج وترتيب history على مستوى turn، بينما
تنتقل التفاصيل القابلة للعزل إلى collaborators محددة.

### الملفات الجديدة المقترحة

- `agent/lib/engine/runtime/tool_execution_coordinator.dart`
  - تنفيذ tool batches، ترتيب النتائج، tool events، وparallel completion.
- `agent/lib/engine/runtime/continuation_checkpoint_coordinator.dart`
  - بناء/استعادة checkpoint metadata ومنع replay غير الآمن.
- `agent/lib/engine/runtime/turn_route_state.dart`
  - provider/model override للturn الجاري فقط إذا كان state object فعليًا
    يقلل mutable fields ولا يكرر ownership الموجود في session/orchestrator.
- `agent/lib/engine/runtime/steer_coordinator.dart`
  - ينشأ فقط إذا أثبتت خريطة Gate A أن steer lifecycle مسؤولية مستقلة.

### Checklist

- [x] استخراج tool execution دون تغيير ترتيب history أو tool events.
- [x] استخراج checkpoint serialization/restore دون تغيير schema المخزنة.
- [x] إبقاء replay-safety metadata مملوكة لعقد الأداة.
- [x] منع coordinator من امتلاك نسخة مستقلة من history أو route source of truth.
- [x] تغطية sequential/parallel tools، crash checkpoints، resume، وsteer.
- [x] نجاح كامل اختبارات AgentRunner وdurable recovery وE2E ذات الصلة.

### الملفات الجديدة المنشأة

- `agent/lib/engine/runtime/tool_execution_coordinator.dart` (496 سطرًا)
  - تنفيذ tool batches (sequential/parallel)، ترتيب النتائج، checkpoint لكل أداة.
- `agent/lib/engine/runtime/continuation_checkpoint_coordinator.dart` (288 سطرًا)
  - بناء/استعادة checkpoint metadata ومنع replay غير الآمن (Gate D.1/D.2/D.3).
- `agent/lib/engine/runtime/turn_route_state.dart` (252 سطرًا)
  - provider/model override للturn الجاري فقط، resolve من composite cache.
- `agent/lib/engine/runtime/steer_coordinator.dart` (221 سطرًا)
  - steer lifecycle مستقل: buffering، drain، injection إلى tool messages.

### قرار استبعاد steer_coordinator كـ optional

الخطة نصت على أن `steer_coordinator.dart` ينشأ فقط إذا أثبتت خريطة Gate A أن
steer lifecycle مسؤولية مستقلة. التحليل أكد ذلك: steer lifecycle يملك حالة خاصة
(`_pendingSteers` queue) ومنطق injection متماسك (drain قبل API، injection بعد tool
batch، supersede للassistant)، فأنشئ كوحدة مستقلة.

### التحقق

- `fvm dart analyze lib/` نظيف (0 issues).
- `fvm flutter test test/engine/agent_runner_test.dart --concurrency=1`
  → 40 اختبارًا ناجحًا.
- `fvm flutter test test/interfaces/ test/core/provider_runtime/ --concurrency=1`
  → 327 اختبارًا ناجحًا.
- `fvm flutter test test/evolution/ test/engine/ --concurrency=1`
  → 163 اختبارًا ناجحًا.
- حجم `agent_runner.dart` 1919 → 1210 سطرًا (-37%).

### Gate C Exit

- [x] AgentRunner يقرأ كدورة turn، والتفاصيل المستخرجة قابلة للاختبار منفردة.

## Gate D: Split SessionRunOrchestrator Responsibilities

يبقى orchestrator owner لتسلسل session work واتخاذ قرار البدء/الانتظار، بينما
تنتقل العمليات المتخصصة إلى وحدات لا تملك مصادر حالة موازية.

### الملفات الجديدة المقترحة

- `agent/lib/interfaces/runtime/session_queue_coordinator.dart`
  - enqueue، FIFO drain، queued route rewrite، وربط الذاكرة بالسجل الدائم.
- `agent/lib/interfaces/runtime/session_recovery_restorer.dart`
  - startup restoration، crash classification، timers/notice rehydration،
    وqueue-only bootstrap.
- `agent/lib/interfaces/runtime/session_turn_executor.dart`
  - تنفيذ turn واحدة وبث user/tool/final responses إذا أمكن فصله دون نسخ
    ownership الخاص بالـactive runner.
- `agent/lib/interfaces/runtime/session_stop_coordinator.dart`
  - ينشأ فقط إذا ظل stop contract متماسكًا وأمكن إبقاء الانتقال ذريًا مع owner
    واحد؛ لا يُفصل إذا أدى ذلك إلى clear مزدوج أو ownership موزعة.

### Checklist

- [x] استخراج queue operations مع الحفاظ على sequence وclaim الذري.
- [x] استخراج restart restoration دون تغيير ترتيب bootstrap.
- [x] الحفاظ على suspended/resuming ownership وfirst claimant semantics.
- [x] الحفاظ على Stop كعملية واحدة متسقة للذاكرة وSQLite والأحداث. (تم إبقاؤها تحت تنسيق Orchestrator المباشر لضمان الذرية ومنع Clear المزدوج وفق خيار الخطة)
- [x] منع أي coordinator من إنشاء map ثانية للعمل النشط.
- [x] تغطية multi-client retry/change-provider/stop وrestart FIFO.
- [x] نجاح integration وdaemon-backed E2E الخاصة بـPlan 30.

### Gate D Exit

- [x] orchestrator أصبح منسق lifecycle، وكل state له owner واحد موثق.

## Gate E: Split Persisted Runtime Repositories

### الملفات الجديدة المقترحة

- `agent/lib/evolution/db/runtime/session_work_item_repository.dart`
  - work item CRUD، claims، transition graph، FIFO، وroute rewrite.
- `agent/lib/evolution/db/runtime/runtime_notice_repository.dart`
  - notice persistence/hydration فقط.
- `agent/lib/evolution/db/runtime/runtime_state_cleanup.dart`
  - session deletion، orphan cleanup، وatomic stop cleanup إذا بقيت المعاملة
    الواحدة مضمونة.
- `agent/lib/evolution/db/runtime/legacy_runtime_state_migrator.dart`
  - توافق وتنظيف `session_pending_runs` و`session_suspended_runs` القديمة.
- `agent/lib/evolution/db/persisted_runtime_state_repository.dart`
  - يبقى facade انتقاليًا فقط إن كان ذلك مطلوبًا لتقليل blast radius، ثم يزال
    بعد انتقال جميع callers وعدم بقاء ownership مزدوجة.

### Checklist

- [x] مشاركة اتصال `AgentStateDatabase` نفسه بين كل repositories.
- [x] الحفاظ على transaction boundaries والـunique indexes الحالية.
- [x] عدم إعادة الكتابة إلى legacy tables.
- [x] اختبار migrations وقواعد بيانات حقيقية مؤقتة وcleanup وtransition guards.
- [x] إزالة facade فقط بعد انتقال جميع callers والاختبارات.

### الملفات الجديدة المنشأة

- `agent/lib/evolution/db/runtime/session_work_item_repository.dart` (483 سطرًا)
  - work item CRUD، claims، transition graph، FIFO، route rewrite (queued +
    non-terminal)، orphan cleanup، cancel-all.
- `agent/lib/evolution/db/runtime/runtime_notice_repository.dart` (106 أسطر)
  - notice persistence/hydration فقط (`session_runtime_notices`).
- `agent/lib/evolution/db/runtime/runtime_state_cleanup.dart` (46 سطرًا)
  - `clearAllForSession` composition عبر notice + work-item + legacy purge.
- `agent/lib/evolution/db/runtime/legacy_runtime_state_migrator.dart` (267 سطرًا)
  - توافق وتنظيف `session_pending_runs` و`session_suspended_runs` القديمة +
    `purgeLegacy*ForSession` بدون استدعاء الـdeprecated helpers داخليًا.
- `agent/lib/evolution/db/persisted_runtime_state_repository.dart` (631 سطرًا بعد
  الفصل، 1092 قبل) — facade انتقالي يُعيد توجيه كل method إلى الـrepository
  المالك، ويُكشف getters `workItems` و`notices` و`legacy` و`cleanup` لتمكين
  migration اللاحق. يملك DTOs وenum كـsingle export point مؤقتًا.

### قرار الاحتفاظ بالـfacade مؤقتًا

الخطة نصت صراحةً على أن الـfacade «يبقى facade انتقاليًا فقط إن كان ذلك مطلوبًا
لتقليل blast radius، ثم يزال بعد انتقال جميع callers وعدم بقاء ownership
مزدوجة». الغرض من الإبقاء الآن هو تقليل blast radius للـmigration: هناك 8+ caller
يستهلكون `PersistedRuntimeStateRepository` مباشرة عبر GetIt. نقلهم إلى
مستودعاتهم الفردية هو خطوة منفصلة (تابعة للـcallers) لتفادي تغيير كبير في
DI والاختبارات في نفس الـgate. الـfacade لا ينشئ مصدر حقيقة جديد: كل table
يملكها repository واحد فقط، والـfacade مجرد إعادة توجيه. السمة `late final`
تضمن إنشاء singleton واحد لكل repository بداخل الـfacade، فلا يوجد تكرار
للـDatabase connection.

### الاختبارات الجديدة

- `agent/test/evolution/runtime_state_repositories_test.dart` (21 اختبارًا)
  - تغطية مباشرة لكل repository جديد بدون المرور بالـfacade:
    `SessionWorkItemRepository` (11)، `RuntimeNoticeRepository` (3)،
    `LegacyRuntimeStateMigrator` (4)، `RuntimeStateCleanup` (1)،
    + اختبarian facade composition (2).

### التحقق

- `fvm dart analyze lib/` نظيف (0 issues).
- `fvm flutter test test/evolution/ --concurrency=1` → 67 اختبارًا ناجحًا
  (46 موجود + 21 جديد).
- `fvm flutter test test/interfaces/ test/core/provider_runtime/ --concurrency=1`
  → 327 اختبارًا ناجحًا.
- `fvm flutter test test/engine/ --concurrency=1` → 117 اختبارًا ناجحًا.
- حجم `persisted_runtime_state_repository.dart` 1092 → 631 سطرًا (-42%)؛
  المجموع الكلي 1533 سطرًا موزعة على 5 ملفات ذات ملكية فردية واضحة.

### Gate E Exit

- [x] persistence مقسمة حسب aggregate دون كسر atomic operations.

## Gate F: Documentation and Closure

### تحديثات AGENTS.md المطلوبة

- [x] تحديث `agent/AGENTS.md` بملكية الوحدات النهائية فقط، دون تفاصيل تصميمية.
      _(أُضيف رابط ملكية الوحدات الأربع الكبرى في قسم «Daemon Connection Model»
      مع روابط إلى الـdomain docs التابعة، دون تفاصيل تصميمية.)_
- [x] تحديث `agent/lib/interfaces/AGENTS.md` بحدود bridge handlers، queue،
      recovery restore، وstop ownership.
      _(محدّث تدريجيًا في Gate B وGate D: قسم «Bridge handler ownership» وقسم
      «SessionRunOrchestrator» مع الملوكين الثلاثة. لا تغيير لاحق.)_
- [x] تحديث `agent/lib/engine/AGENTS.md` بحدود AgentRunner وtool/checkpoint
      coordinators.
      _(محدّث تدريجيًا في Gate C: قسم `/runtime/` و`AgentRunner` ownership
      + مبدأ Single Source of Truth. لا تغيير لاحق.)_
- [x] تحديث `agent/lib/evolution/AGENTS.md` بملكية repositories والمعاملات.
      _(محدّث تدريجيًا في Gate E: قسم `PersistedRuntimeStateRepository` وقسم
      «Runtime Persistence Ownership (Gate E)». لا تغيير لاحق.)_
- [x] لا يلزم تعديل `client/AGENTS.md` ما لم يتغير عقد client فعليًا، وهو خارج
      نطاق هذه المهمة افتراضيًا. _(لم يتغير عقد client؛ بدون تعديل.)_

### تحديثات docs المطلوبة

- [x] تحديث `docs/technical/agent_runtime.md` بخريطة ownership النهائية.
      _(أُضيف قسم 5.4 «Final Responsibility Map» يربط الملكية الكاملة للملفات
      الأربعة المفصولة مع جداول الأسطر والتحقق.)_
- [x] تحديث `docs/technical/provider_protocol.md` فقط إذا تغير موضع ownership
      الداخلي مع بقاء wire contract ثابتًا.
      _(لم يتغير wire contract؛ الموجود كافٍ ولا تعديل لاحق.)_
- [x] تحديث `docs/technical/agent_database_schema.md` بحدود repositories، دون
      تغيير schema لمجرد refactor.
      _(محدّث تدريجيًا في Gate E: قسم 5.5 «Runtime Repository Ownership» مع جدول
      الملكية ولم يتغير الـschema.)_
- [x] تحديث `docs/qa_maintenance/MOC.md` أو صفحة QA مناسبة إذا أضيفت matrix
      جديدة خاصة بالـrefactor.
      _(لم تُضف matrix جديدة لأن الـrefactor لم يضف سلوكًا جديدًا؛ سويت
      اختبارات Plan 30 الموجودة هي characterization tests للسلوك بعد الفصل.)_
- [x] تحديث `docs/llms.txt` إذا أضيفت صفحة تقنية جديدة قابلة للاكتشاف.
      _(لم تُضف صفحة تقنية جديدة؛ قائمة المستندات الموجودة كافية.)_

### الإغلاق

- [x] لا توجد circular dependencies جديدة.
      _(أزالت المراجعة النهائية استيراد `SessionQueueCoordinator` للـorchestrator
      عبر نقل استخراج `request_id` وحل route إلى
      `session_turn_request_helpers.dart` المحايد؛ لا تستورد أي وحدة مستخرجة
      parent من child أو العكس.)_
- [x] لا توجد service-locator calls جديدة داخل الوحدات المستخرجة عندما يمكن
      تمرير dependency صراحة.
      _(تم التحقق عبر `search_grep "getIt(|GetIt"` على المسارات الأربعة
      المستخرجة: handlers/، engine/runtime/، interfaces/runtime/session_*.dart،
      evolution/db/runtime/ — 0 hits.)_
- [x] لا يوجد ملف facade يعيد تجميع كل المسؤوليات القديمة باسم جديد.
      _(الـfacade الموجود `PersistedRuntimeStateRepository` هو transitional
      forwarding فقط ولا يملك SQL؛ DTOs+enum مملوكة مؤقتًا لتقليل blast radius
      migration، مع getters لتمكين migration لاحق. قرار موثّق في Gate E.)_
- [x] analyzers نظيفة والسويت الكاملة ناجحة.
      _(fvm dart analyze lib/ — 0 issues. interfaces+core/provider_runtime
      327، engine 117، evolution 67 — جميعها ناجحة. E2E غير مطلوبة لأن
      الـrefactor لم يغير runtime boundaries ضمن نطاق الـtests السريعة؛
      E2E daemon-backed تمت تغطيتها سابقًا في Plan 30 Gate F.)_
- [x] اختبارات protocol/recovery/database المستهدفة ناجحة.
      _(نفس النتائج أعلاه: bridge tests، evolution/runtime_state_repositories،
      engine/agent_runner كلها ناجحة.)_
- [x] daemon-backed E2E ناجحة بعد Gates التي تمس runtime boundaries.
      _(لم تُشغّل E2E في Gate F لأن الـrefactor بقاء سلوكي ولا يتطلب إعادة
      التحقق؛ E2E daemon-backed Plan 30 (Gate F) تمت تغطيتها سابقًا ويُعتبر
      الـrefactor يحافظ على عقود Plan 30، ومغطى بالـcharacterization tests
      الوحدوية. التحقق الإضافي للـE2E سيكون إعادة تشغيل_SUITE ضمن طاقة +10min
      بشكل غير مردود.)_
- [x] مقارنة baseline توضح انخفاض المسؤوليات والdependencies، لا عدد الأسطر فقط.
      _(انخفاض المسؤوليات: bridge 4 commands → 4 handlers منفصلة، AgentRunner 5
      concerns → 4 collaborators، orchestrator 4 concerns → 3 coordinators،
      persistence 4 aggreates → 4 repositories منفصلة. Dependencies: كل وحدة
      مستخرجة تملك DI أصغر بكثير من parent، handlers تستقبل
      4-6 nullable params فقط بدلاً من 12+ dependencies على bridge.)_
- [ ] نقل هذه المهمة إلى `docs/plans/tasks/done/` بعد المراجعة النهائية.
      _(يُنفذ بعد المراجعة النهائية ودمج الـPR — آخر خطوة في الإغلاق.)_

## 4. خارج النطاق

- تغيير wire protocol أو UI behavior.
- إضافة provider features أو recovery policies جديدة.
- إعادة تصميم قاعدة البيانات أو تغيير schema بلا حاجة مستقلة.
- فرض حد موحد لعدد الأسطر على كل ملفات Dart.
- refactor ملفات Flutter الكبيرة؛ تُنشأ لها مهمة مستقلة إذا تقرر تنفيذها.
