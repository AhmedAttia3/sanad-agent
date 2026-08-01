# خطة المرحلة الثامنة والعشرين: نقل تنفيذ كل الأدوات (Tool Execution) وإدارة خوادم MCP من الواجهة إلى الوكيل المحلي

> [!IMPORTANT]
> **المشكلة الجوهرية:** واجهة Flutter (`sanad-client`) مصممة للعمل كطبقة عرض عابرة للمنصات (iOS / Android / Web / Desktop) وتتصل بالوكيل المحلي (`sanad-agent`) الذي قد يعمل على جهاز مختلف أو خادم بعيد. **رغم ذلك، كانت الواجهة تقوم سابقاً بتنفيذ الأدوات محلياً** (مثل محاكاة الماوس والكيبورد، والتحكم بالملفات، والبحث في الويب، وتشغيل خوادم MCP المحلية كعمليات فرعية Subprocesses). هذا يسبب:
>
> 1. **تضارب البيئة (Environment Disconnect):** عندما تعمل الواجهة على الهاتف المحمول أو المتصفح، أو تتصل بوكيل يعمل على جهاز بعيد، تفشل أدوات مساحة العمل (Workspace) والويب والأتمتة تماماً أو تنفذ على جهاز المستخدم بدلاً من خادم الوكيل حيث توجد ملفات المشروع الفعلية.
> 2. **صعوبة التجميع (Compilation Restrictions):** استيراد الحزم الأصلية الخاصة بالتحكم المباشر لسطح المكتب وعمليات نظام التشغيل والتحكم في العمليات الفرعية يمنع تجميع تطبيق الواجهة لمنصات الهاتف (Android/iOS) والويب بشكل طبيعي.
> 3. **إساءة استخدام الحدود البرمجية (Layer Boundaries):** الواجهة من المفترض أن تكون طبقة عرض للأحداث والحدثيات فقط، ولا ينبغي أن تنفذ أدوات مباشرة على نظام التشغيل أو تعدل على ملفات القرص.
>
> **الحل:** نقل كافة أعمال التنفيذ الخاصة بالأدوات وإدارة خوادم MCP من الواجهة كلياً إلى الوكيل المحلي (`sanad-agent`). يتم التحكم في تفعيل ميزات التحكم التلقائي للأتمتة عبر إعداد بيئة الوكيل `COMPUTER_USE` في ملف الـ `.env`. تكتفي الواجهة بإرسال أوامر عبر الـ WebSocket واستقبال النتائج لعرضها.

---

## السياق المعماري (Architectural Context)

### البنية الحالية (Current Architecture)

```
┌─────────────────────────────────────────────────────────────┐
│  Flutter Client (sanad-client)                               │
│  ├──────────────────────────────────────────────────────┤   │
│  │ LocalToolRuntimeService (توجيه الأوامر وتنسيقها)         │   │
│  │    ├─► automation_service.dart (ماوس، كيبورد، شل)     │   │
│  │    ├─► workspace_tools_service.dart (قراءة/كتابة القرص) │   │
│  │    ├─► web_search_service / web_fetch_service (ويب)  │   │
│  │    ├─► skill_load_service (مهارات)                   │   │
│  │    └─► mcp_service.dart (تشغيل subprocesses محلياً)   │   │
│  └──────────────────────────────────────────────────────┘   │
└────────────────────────┬────────────────────────────────────┘
                         │ (الواجهة تنفذ كل الأدوات محلياً)
┌────────────────────────┴────────────────────────────────────┐
│  Local Dart Daemon (sanad-agent)                             │
│  ┌──────────────────────────────────────────────────────┐   │
│  │ LocalRuntimeCatalog                                  │   │
│  │    └─► Request Platform Tools from Client            │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

### البنية المستهدفة (Target Architecture)

```
┌─────────────────────────────────────────────────────────────┐
│  Flutter Client (sanad-client) — طبقة عرض فقط               │
│  ├──────────────────────────────────────────────────────┤   │
│  │ SettingsScreen (تعديل القيمة وإرسال أوامر فحص الصلاحيات)   │
│  │    └─► SanadSocketService (WebSocket)                 │   │
│  │           └─► Send Canonical Events                  │   │
│  │                                                      │   │
│  │ Stubs: (مفرغة لمنع أخطاء التجميع وتجنب تشغيل كود IO)  │   │
│  │    └─► LocalToolRuntimeService / McpService /        │   │
│  │        WorkspaceToolsService (Stubs)                 │   │
│  └──────────────────────────────────────────────────────┘   │
└────────────────────────┬────────────────────────────────────┘
                         │ Sanad Gateway (WebSocket)
                         │ system.check_computer_use_permissions
                         │ system.request_computer_use_permissions
                         │ system.toggle_computer_use
                         ▼
┌─────────────────────────────────────────────────────────────┐
│  Local Dart Daemon (sanad-agent) — منفذ الأدوات             │
│  ┌──────────────────────────────────────────────────────┐   │
│  │ LocalRuntimeCatalog (تسجيل الأدوات محلياً)              │   │
│  │    ├─► Builtin Workspace Tools (Grep/Write/Edit)     │   │
│  │    ├─► ScreenshotTool / MouseTool / KeyboardTool     │   │
│  │    ├─► McpRuntimeManager (خوادم MCP المحلية والبعيدة)   │   │
│  │    └─► AutomationServiceFactory                      │   │
│  │           └─► Macos/Windows/Linux FFI Services ✅    │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

---

## 1. الأهداف (Goals)

1. **دعم تعدد المنصات الفعلي للواجهة:** إزالة حزم الأتمتة والعمليات الفرعية وقراءة القرص التي تتطلب شفرات أصلية (Native code) من الواجهة لتسهيل تجميعها وتطبيقها على الهواتف والويب.
2. **عزل التنفيذ في الوكيل:** نقل كافة خدمات الـ IO والويب ومحاكاة الأحداث والمهارات وتشغيل خوادم MCP إلى الوكيل المحلي (`sanad-agent`) حصرياً.
3. **التخلص من تشغيل العمليات الفرعية (Subprocesses):** منع إطلاق أي عمليات MCP StdIO أو أوامر شل محلياً من كود الواجهة.
4. **الحفاظ على استقرار واستمرارية كود الواجهة:** استبدال الطبقات البرمجية التي كانت تقوم بالتنفيذ بـ Stubs مفرغة متوافقة برمجياً مع نظام حقن التبعيات (Dependency Injection) لتجنب إعادة كتابة شاملة للواجهة.

---

## 2. النطاق (Scope)

### 2.1 داخل النطاق (In Scope)

يغطي هذا النطاق إزالة وتحجيم 5 مكونات رئيسية في كود الواجهة:

1. **إدارة وتوجيه تنفيذ الأدوات الرئيسي (Execution Routing):**
   * إفراغ `local_tool_runtime_service.dart` وجعله لا ينفذ أي طلبات محلياً.
   * إفراغ `device_command_handler.dart` بحيث لا يوجه أحداث `execute_tool` أو `call_tool`.
   * إفراغ `local_tool_execution_coordinator.dart` وإيقاف استماع طلبات التنفيذ وبث الأدوات من جهة العميل.
2. **تنفيذ أدوات نظام التشغيل والتحكم التلقائي (System Automation Tools):**
   * حذف ملف `automation_service.dart` بالكامل وإيقاف استدعاءات `execute_terminal` ومحاكاة الماوس/الكيبورد/لقطة الشاشة.
   * إزالة حزمتي `bixat_key_mouse` و `screen_capturer` من `pubspec.yaml` للواجهة.
3. **تنفيذ أدوات مساحة العمل (Workspace Files Tools):**
   * استبدال كود `workspace_tools_service.dart` بـ Stub لا يلمس الـ filesystem نهائياً (إلغاء تنفيذ `file_read` / `file_write` / `file_edit` / `search_glob` / `search_grep` من العميل).
4. **تنفيذ أدوات الويب والمهارات (Web & Skills Tools):**
   * إفراغ كود `web_search_service.dart` (أداة `web_search`).
   * إفراغ كود `web_fetch_service.dart` (أداة `web_fetch`).
   * إفراغ كود `skill_load_service.dart` (تحميل المهارات).
5. **تشغيل خوادم MCP وتنفيذ أدواتها (Local MCP Execution):**
   * إفراغ كود `mcp_service.dart` لمنع تشغيل خوادم MCP المحلية كعمليات فرعية (Subprocesses) أو محاولة تنفيذ أدواتها محلياً.

* **داخل الوكيل (sanad-agent):**
  * بناء خدمات محاكاة أحداث أنظمة التشغيل macOS/Windows/Linux وأدوات الأتمتة الثلاثة (`system.screenshot`, `system.mouse`, `system.keyboard`).
  * تفعيل وتشغيل أدوات الأتمتة فقط عند ضبط `COMPUTER_USE=true`.
  * تولي فحص وتفعيل وإرجاع حالة الصلاحيات عبر WebSocket وتعديل الإعدادات.

### 2.2 خارج النطاق (Out of Scope)

* **شاشات إعدادات الـ MCP:** تستمر الواجهة في عرض خوادم الـ MCP وتعديل ملفات إعداداتها كبيانات يتم حفظها وإرسالها للوكيل، لكن دون تشغيل العمليات محلياً في الواجهة.

---

## 3. معايير القبول (Acceptance Criteria / DoD)

1. **الواجهة خالية من حزم أتمتة سطح المكتب:** خلو ملف `pubspec.yaml` للواجهة من حزمتي `bixat_key_mouse` و `screen_capturer`.
2. **خلو الواجهة من قراءة الملفات/العمليات للمشروع:** الكود في الواجهة لا يقوم بتشغيل أي subprocesses لـ MCP StdIO أو استخدام `Process.run`/`Process.start` لتشغيل الماوس/لوحة المفاتيح/المهارات/الملفات.
3. **سلامة نظام DI والتجميع:** الواجهة تتجمع بنجاح مع تسجيل الخدمات كـ Stubs وبدون أي مشاكل في بناء `injection.config.dart`.
4. **عمل أدوات الأتمتة والملفات بالكامل في الوكيل:** قيام الوكيل بتشغيل وتنفيذ كافة الأدوات (الملفات، الأتمتة، الويب، خوادم MCP) محلياً وإرجاع النتيجة للـ Gateway.
5. **نجاح كافة الاختبارات:** نجاح اختبارات العميل (352 اختباراً) والوكيل (240 اختباراً) بالكامل بنسبة 100%.

---

## 4. التغييرات المقترحة والتنفيذ الفعلي (Proposed and Implemented Changes)

### 4.1 التغييرات في الوكيل (sanad-agent)

- تفعيل معمارية الأتمتة للأنظمة الثلاثة وإدراج أدوات الأتمتة كأدوات داخلية في `LocalRuntimeCatalog` كما هو موضح بالخطة السابقة.
- معالجة طلبات `check_computer_use_permissions` و `toggle_computer_use` بالوكيل لضمان المزامنة.

---

### 4.2 التغييرات في الواجهة (sanad-client)

#### [MODIFY] [pubspec.yaml](sanad-agent/client/pubspec.yaml)
* حذف `bixat_key_mouse` و `screen_capturer`.

#### [DELETE] [automation_service.dart](sanad-agent/client/lib/infrastructure/platform/automation_service.dart)
* حذف ملف التحكم التلقائي كلياً.

#### [MODIFY] Stubs في مجلد `lib/infrastructure/local_tools/`
* **[local_tool_runtime_service.dart](sanad-agent/client/lib/infrastructure/local_tools/local_tool_runtime_service.dart)**: مفرغ كلياً لحجب التنسيق المحلي للعمليات.
* **[workspace_tools_service.dart](sanad-agent/client/lib/infrastructure/local_tools/workspace_tools_service.dart)**: مفرغ كلياً ولا يقوم بأي نداءات لـ `dart:io`.
* **[web_search_service.dart](sanad-agent/client/lib/infrastructure/local_tools/web_search_service.dart)**: مفرغ كلياً.
* **[web_fetch_service.dart](sanad-agent/client/lib/infrastructure/local_tools/web_fetch_service.dart)**: مفرغ كلياً.
* **[skill_load_service.dart](sanad-agent/client/lib/infrastructure/local_tools/skill_load_service.dart)**: مفرغ كلياً.

#### [MODIFY] Stubs في مجلد `lib/infrastructure/mcp/`
* **[mcp_service.dart](sanad-agent/client/lib/infrastructure/mcp/mcp_service.dart)**: مفرغ لمنع تشغيل subprocesses لـ MCP StdIO محلياً من العميل.

#### [MODIFY] [device_command_handler.dart](sanad-agent/client/lib/features/devices/presentation/state/device_command_handler.dart)
* تفريغ منطق استقبال وتوجيه أوامر تشغيل الأدوات.

#### [MODIFY] [local_tool_execution_coordinator.dart](sanad-agent/client/lib/infrastructure/local_tools/local_tool_execution_coordinator.dart)
* تفريغ كود استماع وتوجيه طلبات التشغيل عن بعد.

#### [MODIFY] [settings_screen.dart](sanad-agent/client/lib/features/settings/presentation/screens/settings_screen.dart)
* ربط زر تفعيل `Computer Use` بإرسال واستقبال أوامر الصلاحيات وتفعيل الخاصية عبر قناة Socket المفتوحة مع الوكيل.

---

## 5. خطة التحقق والتدقيق (Verification Plan)

### 5.1 الاختبارات المؤتمتة (Automated Tests)
* تشغيل اختبارات الوكيل بالكامل والتأكد من خلو كود `LocalRuntimeCatalog` من أخطاء GetIt وتمرير الفحوصات:
  ```bash
  fvm dart test
  ```
* تشغيل اختبارات الواجهة بالكامل والتأكد من استقرار عمل الـ Cubits وتحديث شاشة الإعدادات:
  ```bash
  fvm flutter test
  ```

### 5.2 التحقق اليدوي (Manual Verification)
1. تشغيل الوكيل وتغيير قيمة `COMPUTER_USE=true`.
2. فحص قدرة الوكيل على تسجيل أدوات `system.screenshot` و `system.mouse` بنجاح واستخدامها.
3. فتح شاشة الإعدادات في الواجهة للتأكد من المزامنة والتحقق من الصلاحيات وطلبها عبر النافذة المنبثقة لنظام macOS.
