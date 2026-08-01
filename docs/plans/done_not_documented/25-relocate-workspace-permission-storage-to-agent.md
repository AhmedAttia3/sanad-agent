# خطة المرحلة الخامسة والعشرين: نقل قراءة/كتابة صلاحيات الـ Workspace من الواجهة إلى الوكيل المحلي

> [!IMPORTANT]
> **المشكلة الجوهرية:** واجهة Flutter (`sanad-client`) مكتوبة كطبقة عرض عابرة للمنصات (iOS / Android / Web / macOS / Windows / Linux) ومن المفترض أن تتواصل مع الوكيل المحلي (`sanad-agent`) حصراً عبر بوابة Sanad Gateway (WebSocket/Socket.IO). **رغم ذلك، تقوم الواجهة حالياً بقراءة وكتابة ملف `settings.json` الخاص بسياسات الـ workspace مباشرة على الـ filesystem** عبر `dart:io` (`SanadSettingsStore` + `WorkspacePolicyStore`). هذا يكسر:
>
> 1. **الاستقلالية عن المنصة (Platform Independence):** لا يمكن تشغيل الواجهة على iOS/Android/Web حيث لا يوجد وصول مباشر للـ filesystem الخاص بالوكيل.
> 2. **مبدأ المصدر الوحيد للحقيقة (Single Source of Truth):** الواجهة والوكيل يكتبان في نفس الملف بالتوازي بدون مزامنة صريحة، مما قد يسبب سباقات كتابة (race conditions) وفقدان تحديثات.
> 3. **التدفق عبر الطبقات (Layer Boundaries):** الواجهة تتجاوز طبقة النقل (`ConversationRepository` ↔ `ConversationClient` ↔ `ConversationCommandGateway`) وتصل لـ IO المحلي.
>
> **الحل:** نقل كل عمليات قراءة/كتابة `settings.json` إلى الوكيل المحلي (`sanad-agent`)، وتصبح الواجهة مستهلكاً خالصاً يستدعي أوامر عبر الـ Sanad Gateway (مثل `workspace.get_policy` و `workspace.set_permission_mode`).

---

## السياق المعماري (Architectural Context)

### البنية الحالية (Current Architecture)

```
┌─────────────────────────────────────────────────────────────┐
│  Flutter Client (sanad-client) — عبر المنصات               │
│  ┌──────────────────────────────────────────────────────┐   │
│  │ SessionMessagesCubit                                 │   │
│  │    └─► _workspacePolicyStore                         │   │
│  │           └─► SanadSettingsStore                       │   │
│  │                  └─► dart:io File(settings.json) ❌   │   │
│  └──────────────────────────────────────────────────────┘   │
└────────────────────────┬────────────────────────────────────┘
                         │ (الواجهة تكتب أيضاً على نفس الملف)
┌────────────────────────┴────────────────────────────────────┐
│  Local Dart Daemon (sanad-agent)                             │
│  ┌──────────────────────────────────────────────────────┐   │
│  │ PermissionManager                                    │   │
│  │    └─► WorkspacePolicyStore                           │   │
│  │           └─► dart:io File(settings.json) ✅         │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

### البنية المستهدفة (Target Architecture)

```
┌─────────────────────────────────────────────────────────────┐
│  Flutter Client (sanad-client) — عبر المنصات                │
│  ┌──────────────────────────────────────────────────────┐   │
│  │ SessionMessagesCubit                                 │   │
│  │    └─► ConversationRepository (abstract)              │   │
│  │           └─► SocketConversationRepository            │   │
│  │                  └─► ConversationCommandGateway       │   │
│  │                         └─► WebSocket ✅ (لا IO)     │   │
│  └──────────────────────────────────────────────────────┘   │
└────────────────────────┬────────────────────────────────────┘
                         │ Sanad Gateway (WebSocket)
                         │ workspace.get_policy
                         │ workspace.set_permission_mode
                         ▼
┌─────────────────────────────────────────────────────────────┐
│  Local Dart Daemon (sanad-agent) — Source of Truth          │
│  ┌──────────────────────────────────────────────────────┐   │
│  │ PermissionManager + WorkspacePolicyStore             │   │
│  │    └─► dart:io File(settings.json) ✅                │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

---

## 1. الهدف (Goals)

1. **إعادة الواجهة لكونها طبقة عرض خالصة:** منع أي استخدام لـ `dart:io` أو `dart:convert` داخل `lib/infrastructure/local_tools/` لأي عمليات متعلقة بسياسات الـ workspace، بحيث تعمل الواجهة بشكل متطابق على جميع المنصات.
2. **جعل الوكيل المحلي هو المصدر الوحيد للحقيقة (Source of Truth) لـ `WorkspacePolicy`:** كل قراءة/كتابة لـ `settings.json` تتم حصرياً داخل `sanad-agent`، والواجهة تستهلك هذه البيانات عبر أوامر WebSocket فقط.
3. **الحفاظ على تجربة المستخدم الحالية:** لا تغيير في الـ UI أو التفاعل الظاهر للمستخدم — التبديل يجب أن يكون شفافاً تماماً (نفس القوائم، نفس الـ Dialogs، نفس الـ persistence عند إعادة فتح التطبيق).
4. **منع سباقات الكتابة (Race Conditions):** منع السيناريوهات التي تكتب فيها الواجهة والوكيل على نفس الملف في نفس اللحظة، مما قد يؤدي لفقد تحديثات أو تلف في JSON.
5. **دعم المزامنة اللحظية (Reactive Sync):** عندما يُعدّل الوكيل السياسة (مثلاً يكتب في `permissions.allow` بعد موافقة المستخدم على أداة)، يجب أن تنعكس الحالة الجديدة في الواجهة فوراً بدون الحاجة لإعادة تحميل.

---

## 2. النطاق (Scope)

### 2.1 داخل النطاق (In Scope)

* **نقل طبقة IO من الواجهة:**
  * حذف استخدام `WorkspacePolicyStore` و `SanadSettingsStore` لعمليات `readWorkspacePolicy` و `saveWorkspacePolicy` و `savePermissionMode` من `SessionMessagesCubit` والـ UI.
  * الاحتفاظ بـ `SanadSettingsStore` في الواجهة **للاستخدامات الأخرى فقط** (MCP config، auth tokens) — لا تغيير عليها في هذا السياق.
* **إضافة أوامر WebSocket جديدة في طبقة النقل (Transport):**
  * `workspace.get_policy` (workspace_path → policy JSON)
  * `workspace.set_permission_mode` (workspace_path, permission_mode → policy JSON)
  * بث حدث `workspace.policy_changed` من الوكيل للواجهة عند كل تعديل (للحفاظ على reactive sync).
* **توسيع `ConversationRepository`:** إضافة دوال `getWorkspacePolicy(workspacePath)` و `setWorkspacePermissionMode(workspaceId, mode)` كجزء من العقد المجرد.
* **تنفيذ في `SocketConversationRepository`:** استدعاء الأوامر عبر `ConversationCommandGateway` (نفس النمط المستخدم لـ `getWorkspaces` و `createWorkspace`).
* **تنفيذ في `sanad-agent`:** إضافة `WorkspacePolicyCommandHandler` يستقبل الأوامر الجديدة ويردّ بنتيجة + يبثّ الحدث.
* **تحديث `SessionMessagesCubit`:** استبدال كل النداءات المباشرة لـ `_workspacePolicyStore` بنداءات عبر `conversationRepository`.
* **تحديث حالات التحميل (Loading States):** ضمان أن `isLoadingPermissionMode` تظل مضاءة بشكل صحيح طوال مدة الطلب الشبكي.

### 2.2 خارج النطاق (Out of Scope)

* **لا تغيير في منطق الـ `PermissionManager` نفسه في الوكيل** — يبقى كما هو يستخدم `WorkspacePolicyStore` محلياً.
* **لا تغيير في `LocalRuntimeOrchestrator` أو `buildSessionMetadata`** — يستمر استخراج `permissionMode` من الـ metadata كما هو.
* **لا تغيير في المخططات (Schemas) في الباكند** — `permission_modes: ["default", "full_access"]` تبقى كما هي.
* **لا تغيير في الـ UI Widgets** (`ConversationBottomActions`, `ConversationInputPanel`) — التفاعل مع المستخدم يبقى متطابقاً.
* **لا تغيير في MCP config أو auth settings** — `SanadSettingsStore` يبقى يُدير هذه الملفات في الواجهة.
* **لا تغيير في طبقة الصوت (`VoiceEngine`)** — خارج هذا النطاق تماماً.

---

## 3. معايير القبول (Acceptance Criteria / DoD)

1. **استقلالية المنصة:** الكود في `sanad-client/lib/features/conversations/` و `sanad-client/lib/infrastructure/local_tools/workspace_policy*.dart` **لا يستورد** `dart:io` ولا يقوم بأي استدعاء `File()` أو `Directory()` أو `Platform.pathSeparator` أو `Platform.environment` عند قراءة/كتابة سياسات الـ workspace. (يُسمح باستخدام هذه المكتبات في `SanadSettingsStore` لـ MCP config فقط.)
2. **حذف النداءات المباشرة:** لا يوجد أي استدعاء لـ `_workspacePolicyStore.readPolicy` أو `_workspacePolicyStore.savePermissionMode` أو `_workspacePolicyStore.savePolicy` داخل `SessionMessagesCubit` بعد انتهاء الخطة.
3. **اختبارات E2E على الجوال:** عند تشغيل الواجهة على iOS Simulator و Android Emulator (حيث `dart:io` لرفع المسار لا يكشف نفس الـ filesystem)، يجب أن تعمل ميزة "Full Access" بنفس السلوك تماماً.
4. **اختبارات E2E على Desktop:** الواجهة على macOS/Windows/Linux تستمر في العمل بدون أي فرق في السلوك.
5. **مزامنة reactive:** عندما يوافق المستخدم على أداة عبر كارت الإذن (`tool_permission_request`)، ويكتب الوكيل في `permissions.allow`، تستقبل الواجهة حدث `workspace.policy_changed` خلال ≤ 500ms وتعرض الـ mode الجديد.
6. **اختبارات وحدة (Unit Tests):**
   * `SessionMessagesCubit` يعمل بنجاح مع `MockConversationRepository` يُرجع `WorkspacePolicy` مُعرّف مسبقاً.
   * `SocketConversationRepository` يستدعي `request(command: 'workspace.get_policy')` بـ `requestId` صحيح.
   * `WorkspacePolicyCommandHandler` في `sanad-agent` يعالج الطلبات ويُرجع 200/400 صحيح.
7. **اختبارات تكامل (Integration Tests):**
   * سيناريو كامل: المستخدم يختار workspace → الواجهة تسأل الوكيل عن السياسة → تعرض الـ mode → يختار "Full Access" → الواجهة ترسل أمر → الوكيل يكتب على القرص → الواجهة تعيد قراءة السياسة وتتأكد من التحديث.
8. **عدم وجود سباقات كتابة (No Race Conditions):** لا يمكن للواجهة والوكيل كتابة في نفس الملف في نفس اللحظة. (يتم التحقق باختبار تكامل يحاكي كتابة متزامنة من 5 طلبات متتالية.)
9. **لا كسر في الـ Persistence:** عند إعادة فتح التطبيق، يجب أن تظل السياسة المحفوظة محفوظة وتظهر بنفس الـ mode الذي اختاره المستخدم سابقاً.
10. **تحديث الوثائق:** تحديث `sanad-client/AGENTS.md` لإزالة الإشارة إلى أن الواجهة تكتب على `settings.json`، وإضافة توضيح أن الـ permissions تُدار بالكامل من خلال الوكيل.

---

## 4. التغييرات المقترحة (Proposed Changes)

### 4.1 طبقة النقل (Transport Layer)

#### [MODIFY] [conversation_client.dart](sanad-agent/client/lib/features/conversations/domain/conversation_client.dart)
* إضافة دوال مجردة:
  ```dart
  Future<WorkspacePolicy> getWorkspacePolicy(String workspacePath);
  Future<WorkspacePolicy> setWorkspacePermissionMode({
    required String workspaceId,
    required String workspacePath,
    required WorkspacePermissionMode mode,
  });
  Stream<WorkspacePolicy> watchWorkspacePolicy(String workspaceId);
  ```

#### [MODIFY] [socket_conversation_client.dart](sanad-agent/client/lib/features/conversations/data/clients/socket_conversation_client.dart)
* تنفيذ الدوال الجديدة باستخدام `ConversationCommandGateway.request()`:
  * `command: 'workspace.get_policy'` → payload `{workspace_path}`.
  * `command: 'workspace.set_permission_mode'` → payload `{workspace_id, workspace_path, permission_mode}`.
* الاشتراك في `eventRouter` للأحداث الواردة:
  * `event == 'workspace.policy_changed'` → بث `WorkspacePolicy` جديد.

#### [MODIFY] [conversation_repository.dart](sanad-agent/client/lib/features/conversations/domain/repositories/conversation_repository.dart)
* إضافة نفس الدوال للـ abstract class مع `DeviceConfig agent` parameter.

#### [MODIFY] [socket_conversation_repository.dart](sanad-agent/client/lib/features/conversations/data/repositories/socket_conversation_repository.dart)
* تفويض الدوال الجديدة إلى `_clientFor(agent)`.

### 4.2 طبقة الـ Cubit (Presentation Layer)

#### [MODIFY] [session_messages_cubit.dart](sanad-agent/client/lib/features/conversations/presentation/bloc/session_messages_cubit.dart)
* **حذف** الحقل `final WorkspacePolicyStore _workspacePolicyStore;` (السطر 36).
* **حذف** المعامل `WorkspacePolicyStore? workspacePolicyStore` من الـ constructor.
* **استبدال** `_workspacePolicyStore.readPolicy(workspacePath)` بـ `conversationRepository.getWorkspacePolicy(workspacePath)`.
* **استبدال** `_workspacePolicyStore.savePermissionMode(workspacePath, mode)` بـ `conversationRepository.setWorkspacePermissionMode(...)`.
* **إضافة subscription** جديد `_workspacePolicySubscription` يستمع لـ `conversationRepository.watchWorkspacePolicy(workspaceId)` ويُحدّث الـ state عند ورود `WorkspacePolicy` جديد.
* **الاحتفاظ** بـ `_permissionModesByWorkspaceId` كـ cache للقراءة السريعة من الـ UI، لكن تعبئته فقط من نتائج الـ repository (لا قراءة من القرص).

#### [MODIFY] [conversation_input_cubit.dart](sanad-agent/client/lib/features/conversations/presentation/bloc/conversation_input_cubit.dart)
* لا تغيير في الواجهة العامة للدوال. التغيير في `SessionMessagesCubit` يتسرب تلقائياً عبر `_stateFromMessages()`.

### 4.3 طبقة البنية التحتية (Infrastructure Layer)

#### [MODIFY] [workspace_policy_store.dart](sanad-agent/client/lib/infrastructure/local_tools/workspace_policy_store.dart)
* **حذف** هذا الملف بالكامل، أو **تقليصه** ليبقى فقط كـ wrapper في الوكيل (لا حاجة له في الواجهة).
* **خيار A (مفضّل):** نقل الملف كاملاً إلى `sanad-agent/agent/lib/capabilities/permissions/workspace_policy_store.dart` وحذفه من العميل.
* **خيار B:** إبقاء الملف في `sanad-client` لكن **بدون أي استخدام** من الكود الإنتاجي، مع إضافة `// @Deprecated` لتجنب الاستيراد العرضي. (الأسوأ لكنه أقل خطورة.)

> [!NOTE]
> نوصي بالخيار A لأن `workspace_policy.dart` (الـ models) يبقى في `sanad-client` ليستخدمه الـ UI، بينما `workspace_policy_store.dart` (الـ IO) ينقل بالكامل.

#### [MODIFY] [sanad_settings_store.dart](sanad-agent/client/lib/infrastructure/local_tools/sanad_settings_store.dart)
* **حذف** الدوال `readWorkspacePolicy` و `saveWorkspacePolicy` و `_workspaceSettingsFile` و `settingsFileForWorkspace` و `sanadDirectoryForWorkspace`.
* **الاحتفاظ** بالدوال المتعلقة بـ MCP config و auth (لأنها لا تزال تُدار محلياً في الواجهة للـ desktop platforms).

#### [MODIFY] [workspace_policy.dart](sanad-agent/client/lib/infrastructure/local_tools/workspace_policy.dart)
* **لا تغيير** — يبقى الـ model في الواجهة ليستخدمه الـ UI والـ cubit.

### 4.4 طبقة الوكيل (Agent Layer)

#### [NEW] [sanad-agent/agent/lib/interfaces/handlers/workspace_policy_command_handler.dart]
* إنشاء معالج أوامر جديد يستقبل:
  * `workspace.get_policy` (workspace_path) → يُرجع `WorkspacePolicy` JSON.
  * `workspace.set_permission_mode` (workspace_id, workspace_path, permission_mode) → يكتب على القرص ويُرجع `WorkspacePolicy` المُحدّث.
* بعد كل كتابة، يبثّ حدث `workspace.policy_changed` لكل الواجهات المتصلة عبر نفس workspace.

#### [MODIFY] [sanad-agent/agent/lib/core/di.dart]
* تسجيل `WorkspacePolicyCommandHandler` في `getIt` container.

#### [MODIFY] [sanad-agent/agent/lib/interfaces/platforms/sanad_gateway/manager.py] — نظير الباكند
* إضافة route handler للأوامر الواردة من الواجهة:
  ```python
  @socketio.on('workspace.get_policy')
  async def handle_get_workspace_policy(data):
      # تفويض إلى الجهاز (device) عبر نفس مسار الأوامر الموجود
      ...
  ```
* إضافة بث حدث `workspace.policy_changed` من الوكيل إلى الواجهة عند كل تعديل.

> [!NOTE]
> الباكند يعمل فقط كـ relay/pass-through في هذه الحالة — لا يحتفظ بأي حالة متعلقة بالـ policy. كل العمليات على `settings.json` تحدث داخل الوكيل المحلي فقط.

#### [MODIFY] [sanad-agent/agent/lib/capabilities/AGENTS.md]
* إضافة قسم جديد يوضح أن `WorkspacePolicyStore` الآن هو **المسؤول الوحيد** عن القراءة/الكتابة، وأن الواجهة لا تصل إلى الـ filesystem.

### 4.5 طبقة الوثائق (Documentation Layer)

#### [MODIFY] [sanad-agent/client/AGENTS.md]
* إزالة أي إشارة إلى أن الواجهة تكتب `settings.json` للسياسات.
* إضافة ملاحظة: "Workspace permissions are managed exclusively by the local agent. The client communicates with the agent via the Sanad Gateway only."

#### [MODIFY] [sanad-agent/docs/technical/communication_protocols.md]
* إضافة قسم للأوامر الجديدة:
  * `workspace.get_policy` (request/response)
  * `workspace.set_permission_mode` (request/response)
  * `workspace.policy_changed` (event)
* توثيق الـ schema الكامل لكل أمر مع مثال JSON.

#### [MODIFY] [sanad-agent/docs/plans/15-voice_and_media_integration_plan.md]
* (اختياري) إضافة cross-reference في قسم "خارج النطاق" لتوضيح أن هذا الملف لم يتأثر بالخطة الحالية.

---

## 5. خطة التحقق (Verification Plan)

### 5.1 الاختبارات التلقائية (Automated Tests)

#### اختبارات وحدة (Unit Tests)

```bash
# في sanad-client
cd sanad-agent/client && fvm flutter test test/features/conversations/
cd sanad-agent/client && fvm flutter test test/infrastructure/local_tools/
```

* **`session_messages_cubit_test.dart`:** تحديث الـ tests الموجودة لاستخدام `MockConversationRepository` بدلاً من `MockWorkspacePolicyStore`. التحقق من أن `setWorkspacePermissionMode` يستدعي `repository.setWorkspacePermissionMode` ولا يصل للقرص.
* **`socket_conversation_repository_test.dart`:** اختبار أن `getWorkspacePolicy` يبني الأمر الصحيح بـ `requestId` صحيح.
* **`workspace_policy_store_test.dart`:** حذفه أو نقله إلى `sanad-agent/agent/test/`.

#### اختبارات تكامل (Integration Tests)

```bash
# تشغيل الـ daemon + backend + عميل وهمي
cd sanad-agent/agent && fvm dart test test/integration/
```

* سيناريو "End-to-End Permission Toggle":
  1. تشغيل daemon مع workspace وهمي `/tmp/test-workspace-1`.
  2. تشغيل عميل (mock) متصل عبر WebSocket.
  3. استدعاء `workspace.set_permission_mode(workspaceId, 'full_access')`.
  4. التحقق من أن الملف `/tmp/test-workspace-1/.sanad/settings.json` يحتوي على `"permissionMode": "full_access"`.
  5. استدعاء `workspace.get_policy(workspacePath)`.
  6. التحقق من أن النتيجة `WorkspacePolicy.fullAccess`.
* سيناريو "Reactive Sync":
  1. فتح اتصالين على نفس workspace.
  2. تعديل السياسة من الاتصال الأول.
  3. التحقق من أن الاتصال الثاني يستقبل `workspace.policy_changed` خلال 500ms.

#### اختبارات lint/guard

```bash
# ضمان عدم استخدام dart:io في feature layer
grep -r "import 'dart:io'" sanad-agent/client/lib/features/conversations/
# (يجب أن يكون الناتج فارغاً)

grep -r "File(\|Directory(\|Platform\." sanad-agent/client/lib/features/conversations/
# (يجب أن يكون الناتج فارغاً)
```

* إضافة هذا الفحص كـ step في CI pipeline.

### 5.2 التحقق اليدوي (Manual Verification)

1. **اختبار Desktop (macOS):**
   * تشغيل الـ daemon + الواجهة على macOS.
   * اختيار workspace.
   * التبديل بين Default / Full Access والتأكد من حفظ الإعداد.
   * إعادة تشغيل الواجهة والتأكد من أن الإعداد محفوظ.
2. **اختبار Mobile (iOS Simulator):**
   * تشغيل الـ daemon على macOS، الواجهة على iOS Simulator.
   * تكرار نفس السيناريو.
   * التحقق من أن الواجهة لا تحاول الوصول إلى `/tmp/...` على الـ iOS Simulator (يجب أن تعمل لأن الـ daemon على macOS).
3. **اختبار Reactive Sync:**
   * فتح واجهتين متصلتين بنفس الـ daemon.
   * تعديل الـ mode من الواجهة الأولى.
   * التحقق من أن الواجهة الثانية تعكس التغيير خلال ثانية.
4. **اختبار No-Race:**
   * إرسال 10 طلبات `set_permission_mode` متتالية من نفس الواجهة.
   * التحقق من أن الملف النهائي يحتوي على آخر قيمة فقط (لا تلف، لا قيم متضاربة).

---

## 6. قائمة تنفيذ المهام (Checklist)

> تُحدَّث هذه القائمة بعد إنجاز كل مهمة. علامة `[x]` تعني مكتمل، `[ ]` تعني قيد الانتظار.

### المرحلة 1: تجهيز طبقة النقل في الواجهة
- [x] **T1.1** إضافة `getWorkspacePolicy` و `setWorkspacePermissionMode` و `watchWorkspacePolicy` إلى `ConversationClient` (abstract).
- [x] **T1.2** تنفيذ الدوال في `SocketConversationClient` باستخدام `ConversationCommandGateway.request()`.
- [x] **T1.3** إضافة الدوال للـ `ConversationRepository` (abstract) و `SocketConversationRepository` (concrete).
- [x] **T1.4** إضافة subscription للأحداث الواردة `workspace.policy_changed` في `SocketConversationClient`.

### المرحلة 2: تحديث الـ Cubit ليستخدم الـ Repository
- [x] **T2.1** حذف `WorkspacePolicyStore _workspacePolicyStore` من `SessionMessagesCubit`.
- [x] **T2.2** استبدال `_loadPermissionModeForWorkspace` ليستدعي `conversationRepository.getWorkspacePolicy`.
- [x] **T2.3** استبدال `setWorkspacePermissionMode` ليستدعي `conversationRepository.setWorkspacePermissionMode`.
- [x] **T2.4** إضافة subscription جديد `_workspacePolicySubscription` يستمع للأحداث.

### المرحلة 3: تنظيف طبقة البنية التحتية
- [x] **T3.1** حذف `workspace_policy_store.dart` من `sanad-client/lib/infrastructure/local_tools/`.
- [x] **T3.2** حذف دوال `readWorkspacePolicy` و `saveWorkspacePolicy` و `settingsFileForWorkspace` و `sanadDirectoryForWorkspace` من `sanad_settings_store.dart`.
- [x] **T3.3** نقل `workspace_policy_store.dart` إلى `sanad-agent/agent/lib/capabilities/permissions/` وضمان أن الـ daemon هو المستخدم الوحيد.
- [x] **T3.4** التحقق من أن `workspace_policy.dart` (الـ model) لا يزال مستورداً في `ConversationInputState` و `SessionMessagesState`.

### المرحلة 4: تنفيذ معالج الأوامر في الوكيل
- [x] **T4.1** إنشاء `WorkspacePolicyCommandHandler` في `sanad-agent/agent/lib/interfaces/handlers/`.
- [x] **T4.2** تسجيل الـ handler في `sanad-agent/agent/lib/core/di.dart`.
- [x] **T4.3** إضافة route للأوامر في `sanad-agent/agent/lib/interfaces/platforms/sanad_gateway/manager.py` (إن وجد) أو في `sanad-agent/agent/lib/interfaces/transport/socket_router.dart`.
- [x] **T4.4** إضافة بث حدث `workspace.policy_changed` بعد كل كتابة ناجحة.

### المرحلة 5: الاختبارات
- [x] **T5.1** كتابة اختبارات وحدة لـ `SessionMessagesCubit` مع `MockConversationRepository`.
- [x] **T5.2** كتابة اختبارات وحدة لـ `SocketConversationRepository` (يتحقق من بناء الأمر الصحيح).
- [x] **T5.3** كتابة اختبارات تكامل E2E مع daemon حقيقي.
- [x] **T5.4** كتابة lint check يمنع استخدام `dart:io` في `features/conversations/`.

### المرحلة 6: التحقق اليدوي والوثائق
- [x] **T6.1** اختبار يدوي على macOS (daemon + عميل desktop).
- [x] **T6.2** اختبار يدوي على iOS Simulator (daemon على macOS + عميل iOS).
- [x] **T6.3** اختبار reactive sync بواقعتين متصلتين.
- [x] **T6.4** تحديث `sanad-agent/client/AGENTS.md`.
- [x] **T6.5** تحديث `sanad-agent/docs/technical/communication_protocols.md` بالأوامر الجديدة.
- [x] **T6.6** تحديث `sanad-agent/agent/lib/capabilities/AGENTS.md`.

---

## 7. المخاطر والاعتبارات (Risks & Considerations)

| المخاطر | الاحتمال | الأثر | التخفيف |
|---------|----------|-------|---------|
| **كسر في الـ Persistence:** مستخدم لديه بالفعل `settings.json` محفوظ، بعد الترقية الواجهة لا تقرأه. | متوسط | متوسط | يجب أن يضمن الـ daemon (عند استلام أمر `workspace.get_policy`) قراءة نفس الملف الموجود. لا تغيير في تنسيق الملف. |
| **تأخير في الاستجابة:** الطلب الشبكي أبطأ من القراءة المحلية. | مؤكد | منخفض | زمن الاستجابة في نفس الجهاز < 10ms. لا تأثير UX ملحوظ. الـ cache في `_permissionModesByWorkspaceId` يحتفظ بالقيمة أثناء الطلب. |
| **انقطاع الاتصال:** ماذا يحدث إذا انقطع الاتصال أثناء تغيير الـ mode؟ | منخفض | متوسط | يجب أن يعرض الـ UI خطأ "Connection lost" ويعيد المحاولة. لا كتابة محلية كـ fallback (لأنها تكسر المعمارية). |
| **اختبار E2E معقد:** يحتاج daemon حقيقي + backend. | مؤكد | متوسط | يمكن استخدام `MockWorkspacePolicyStore` في طبقة الوكيل لاختبار الـ handler بمعزل. |
| **تعارض مع خطة 21:** خطة 21 أزالت Redis من التوجيه. | منخفض | منخفض | هذه الخطة لا تتعارض — تستخدم نفس نمط الـ WebSocket pass-through. |

---

## 8. المراجع (References)

* [الخطة 21: إزالة Redis من بوابة التوجيه](./21-remove-redis-from-gateway-routing.md) — نمط الـ WebSocket pass-through.
* [خطة 15: دمج مشاركة الملفات](./15-voice_and_media_integration_plan.md) — مثال على نمط الـ goal/scope/DoD.
* [`sanad-client/AGENTS.md`](../client/AGENTS.md) — العقد المعماري للواجهة.
* [`sanad-agent/agent/lib/capabilities/AGENTS.md`](../agent/lib/capabilities/AGENTS.md) — عقد طبقة الصلاحيات في الوكيل.
* [`docs/technical/communication_protocols.md`](../docs/technical/communication_protocols.md) — توثيق بروتوكول WebSocket.

---

**حالة الخطة:** ✅ منتهية.
**المعرّف (Task ID):** `25-workspace-permission-relocation`
**المكونات المتأثرة (Component Tags):** `sanad-client`, `sanadagent-local`, `sanad-gateway`
**الوقت المتوقع (Estimated Effort):** 18-24 ساعة
