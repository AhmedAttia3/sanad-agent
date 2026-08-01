---
description: "خطة عمل لتجريد أنماط تشغيل الوكيل المحلي (Local Daemon) وإدارة التشغيل وإعادة التشغيل التفاعلي (Hot Restart) والتفريق التام بين التشغيل البرمجي من المصدري (fvm run) والتشغيل المستقل للمترجم."
---

# خطة المرحلة العشرين: تجريد أنماط تشغيل الوكيل وإعادة التشغيل التفاعلي (Local Daemon Execution Modes & Hot Restart)

تهدف هذه الخطة إلى فصل وتجريد منطق تشغيل وإدارة الوكيل المحلي (`sanad-agent` / `daemon`) بناءً على **طريقة تشغيل المشروع** (التشغيل البرمجي عبر `fvm flutter/dart run` في الترمنال/بيئة التطوير، مقابل تشغيل النسخة المترجمة والمبنية كبرنامج مستقل)، وتوفير آلية تفاعلية سريعة لإعادة تشغيل الوكيل سواء من واجهة المستخدم (الـ Client) أو من سطر الأوامر (الـ CLI) أو الكيبورد أثناء التطوير.

---

## 1. الأهداف الرئيسية (Goals)

1. **تجريد التحكم بالوكيل (Daemon Control Abstraction):** إنشاء واجهة برمجية موحدة `LocalDaemonController` تفصل تفاصيل إدارة الوكيل في وضع تشغيل المصدري (Source Mode) عن وضع تشغيل الخدمة المترجمة (Standalone Service Mode).
2. **توحيد فحص التشغيل من المصدري (Unified AppConfig.isSourceRun):** تعريف واستخدام `AppConfig.isSourceRun` في كلا المشروعين لتحديد ما إذا كان المشروع قد تم تشغيله برمجياً عبر الكود المصدري (`fvm flutter run` أو `fvm dart run`) أو أنه يعمل كنسخة مترجمة ومثبتة مستقلة.
3. **أمر إعادة التشغيل التفاعلي في الـ CLI (CLI restart & service restart):** دعم أمر `sanad restart` و `sanad service restart` محلياً لتسهيل إدارة الخدمة من الترمنال.
4. **نقطة نهاية إعادة التشغيل المباشر عبر HTTP (HTTP API /restart):** تفعيل مسار POST للـ `/restart` في خادم الويب للوكيل للسماح للعملاء (مثل العميل الرسومي) بطلب إنهاء الوكيل لإعادة تشغيله.
5. **مشرف تشغيل ذكي للتطوير (Interactive HotRestartManager):** ترقية `HotRestartManager` في الوكيل للاستماع لكيبورد المطور (حرف `r` لعمل Hot Restart)، والاستماع الذكي لخروج العملية الفرعية لإعادة إطلاقها تلقائياً عند استلام طلب إعادة التشغيل من الواجهة.

---

## 2. آلية التحقق من نمط التشغيل (Execution Mode Detection)

لمنع الاعتماد على ملفات التكوين البيئية (مثل `dev.json`) التي قد تُستخدم لبناء نسخ تجريبية مترجمة، سنقوم بالتحقق ديناميكياً من طريقة التشغيل الفعلية:

### أ. في العميل (sanad-client):
سنقوم بتعريف `AppConfig.isSourceRun` بحيث يعود بقيمة `true` إذا تحقق أحد الشرطين:
1. أن يكون التطبيق يعمل بوضع التطوير (`kDebugMode == true`).
2. أن يتم البحث البرمجي (Upward Traversal) من مسار الملف التنفيذي الحالي وتحديد وجود بنية مجلدات الكود المصدري للوكيل (وجود ملف `agent/bin/sanad_agent.dart` في أحد المجلدات الأبوية لمسار التشغيل). إذا وُجد، يعني هذا أن المطور يقوم بتشغيل المشروع من مجلد التطوير الخاص به.

### ب. في الوكيل (sanad-agent):
سنقوم بتعريف `AppConfig.isSourceRun` ليعود بقيمة `true` إذا كان الملف التنفيذي الحالي هو مفسر Dart VM (يحتوي على `dart-sdk` أو ينتهي بـ `dart` أو `dart.exe`)، مما يعكس أنه تم تشغيله عبر سطر الأوامر `fvm dart run`. أما إذا كان ملفاً مترجماً مستقلاً (مثل `sanad` أو `sanad.exe`) فيعود بـ `false`.

---

## 3. النطاق (Scope)

تشمل الخطة التعديلات التالية في كلا المكونين:

### أ. الوكيل (sanad-agent/agent):
* **ملف الإعدادات (lib/core/config/app_config.dart) [جديد]:**
  - تعريف كلاس `AppConfig` يحتوي على قيمة `isSourceRun` التي تفحص ديناميكياً مسار تشغيل Dart VM.
* **إدارة الخدمة وسطر الأوامر (bin/sanad_agent.dart & bin/service.dart & lib/core/setup/service_manager.dart):**
  - إضافة أمر `restart` و `service restart` لإجراء إيقاف وتشغيل الخدمة بالتتابع.
* **خادم الويب للوكيل (lib/interfaces/platforms/sanad_gateway/local_daemon_server_platform.dart):**
  - إضافة معالجة مسار POST `/restart` ينهي العملية بشكل آمن بعد إرسال رسالة النجاح.
* **مشرف التشغيل المصدري (lib/core/hot_restart_manager.dart):**
  - الاستماع لمدخلات الـ `stdin` للـ `r` key أثناء عمل أمر `daemon` لقتل وإعادة تشغيل العملية.
  - الاستماع لانتهاء كود العملية الفرعية (Self-Exit) لتوليد عملية جديدة تلقائياً.

### ب. العميل الرسومي (sanad-agent/client):
* **تجريد الإدارة وتجميع الملفات (`lib/features/devices/data/daemon/`) [جديد]:**
  - تم تنظيم كافة ملفات التحكم بالديمون في مجلد فرعي مخصص للمحافظة على نظافة وتكامل الكود.
* **الواجهة الموحدة (`lib/features/devices/data/daemon/local_daemon_controller.dart`) [جديد]:**
  - واجهة برمجية مجردة `LocalDaemonController` تحتوي على دوال الفحص والتشغيل والإيقاف وإعادة التشغيل والتحديث.
* **التطبيق المستقل للإنتاج (`lib/features/devices/data/daemon/standalone_daemon_controller.dart`) [جديد]:**
  - يطبق الواجهة للتحكم بالخدمة المترجمة (`~/.sanad/bin/sanad`).
  - تم دمج كافة وظائف `LocalServiceManager` السابق مباشرة في هذا الكود وحذف الملف القديم بالكامل لتبسيط المعمارية وتجنب التكرار.
* **التطبيق البرمجي للتطوير (`lib/features/devices/data/daemon/source_daemon_controller.dart`) [جديد]:**
  - يطبق الواجهة ويتعامل مع عملية `Process` برمجية للـ `fvm dart run`.
  - يتجنب تحميل وتحديث الـ Binary أو تعديل ملفات النظام.
  - إذا وجد الوكيل يعمل مسبقاً (تشغيل يدوي من المطور)، يكتفي بالاتصال به دون إعادة تشغيله أو التداخل معه.
* **منسق الاتصال وحقن التبعيات (`lib/features/devices/data/device_connection_coordinator.dart` & `lib/core/di/injection.config.dart`):**
  - تسجيل الـ Controller المناسب في `getIt` بناءً على `AppConfig.isSourceRun`.
  - تحديث منطق `DeviceConnectionCoordinator` ليتعامل مع الواجهة المجردة `LocalDaemonController` بدلاً من `LocalServiceManager` بشكل مباشر.

---

## 4. معايير القبول (Acceptance Criteria)

### 1. وضع التشغيل المستقل (Standalone Run - `AppConfig.isSourceRun == false`)
* عند إقلاع الواجهة الرسومية وفي حال عدم عمل الوكيل، يتم استدعاء الخدمة الخلفية لنظام التشغيل لتشغيلها تلقائياً.
* عند نقر زر إعادة التشغيل من الواجهة، يتم إيقاف الخدمة وتشغيلها مجدداً بشكل سليم وتحديث حالة الواجهة.
* عند إصدار أمر `sanad restart` أو `sanad service restart` من الترمنال، يتم إيقاف وإعادة تشغيل خدمة النظام الخلفية بنجاح.

### 2. وضع التشغيل من المصدري (Source Run - `AppConfig.isSourceRun == true`)
* لا يقوم العميل الرسومي بمحاولة تثبيت أو تشغيل الخدمة المترجمة للإنتاج أو فحص ملفاتها في النظام.
* إذا كان الوكيل لا يعمل، يحاول العميل الرسومي تشغيله في الخلفية من مسار الكود المصدري للمشروع (`fvm dart run bin/sanad_agent.dart daemon`).
* إذا كان الوكيل يعمل بالفعل يدوياً في ترمنال المطور، يتصل به العميل تلقائياً دون محاولة تشغيل عملية جديدة أو قتله عند الإغلاق.
* عند ضغط حرف `r` في ترمنال تشغيل الوكيل المصدري (الـ Hot Restart مفعّل)، يقوم المشرف بعمل إعادة تشغيل فوري للكود (Hot Restart).
* عند الضغط على زر إعادة التشغيل من الواجهة الرسومية، يتم إرسال طلب `/restart` للوكيل ليقوم بإغلاق نفسه وتوليد عملية جديدة (إما بواسطة المشرف أو العميل الرسومي).

---

## 5. قائمة المهام (Checklist)

### أولاً: تطوير وتعديل الوكيل (Agent / Daemon)
- [x] إنشاء كلاس `AppConfig` في `lib/core/app_config.dart` لتوفير فحص `AppConfig.isSourceRun`.
- [x] تعديل `lib/core/setup/service_manager.dart` لإضافة دالة `restart()`.
- [x] تعديل `bin/service.dart` لإضافة ودعم الأمر `restart`.
- [x] تعديل `bin/sanad_agent.dart` لتوجيه أمر `restart` لسطر أوامر الخدمة.
- [x] إضافة مسار POST لـ `/restart` و `/stop` في `lib/interfaces/platforms/sanad_gateway/local_daemon_server_platform.dart`.
- [x] تعديل `lib/core/hot_restart_manager.dart` للاستماع لـ `stdin` للـ `r` key، والاستماع التلقائي لانتهاء العملية لإعادة تشغيلها.

### ثانياً: تطوير وتعديل العميل (Client)
- [x] إنشاء واجهة `LocalDaemonController` في `lib/features/devices/data/daemon/local_daemon_controller.dart`.
- [x] تطبيق `StandaloneDaemonController` في `lib/features/devices/data/daemon/standalone_daemon_controller.dart` لإدارة الخدمة المدمجة.
- [x] تطبيق `SourceDaemonController` في `lib/features/devices/data/daemon/source_daemon_controller.dart` لإدارة العملية البرمجية من الكود المصدري.
- [x] تسجيل الـ Controller المناسب في `lib/core/di/injection.config.dart` بناء على `AppConfig.isSourceRun`.
- [x] تعديل `lib/features/devices/data/device_connection_coordinator.dart` ليعتمد على `LocalDaemonController` بدلاً من `LocalServiceManager`.
- [x] تحديث واجهة الإعدادات والـ StatusBar لتستعين بالـ Controller للتحقق وإعادة التشغيل.

---

## 6. خطة التحقق (Verification Plan)

### الاختبارات اليدوية والآلية (Manual & Automated Verification)
* **فحص وضع المطور:** تشغيل الـ Client عبر `fvm flutter run` والتأكد من تفعيل وضع تشغيل المصدري وعدم توليد الخدمة المترجمة في الخلفية.
* **فحص التشغيل التلقائي من المصدري:** إيقاف الوكيل، تشغيل العميل في وضع المطور، والتأكد من تشغيل الوكيل البرمجي تلقائياً والاتصال به بنجاح.
* **فحص التشغيل اليدوي:** تشغيل الوكيل يدوياً في الترمنال، ثم تشغيل العميل، والتأكد من الاتصال بالوكيل اليدوي بنجاح دون تشغيل عملية إضافية.
* **فحص الـ Hot Restart بالكيبورد:** كتابة حرف `r` في ترمنال تشغيل الوكيل المصدري والتحقق من إعادة بناء وتشغيل عملية الديمون بنجاح.
* **فحص زر إعادة التشغيل بالواجهة:** نقر زر إعادة التشغيل بالـ Client والتحقق من إرسال طلب `/restart` وإعادة التشغيل التلقائي بنجاح.
* **فحص وضع المستخدم المستقل:** بناء التطبيق بالكامل أو تشغيله بوضع الإنتاج والتأكد من تشغيل وإيقاف وإعادة تشغيل الخدمة المدمجة في النظام بشكل قياسي.
