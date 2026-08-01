---
description: "خطة عمل معمارية لتضمين الديمون sanadagent-local كمكتبة مدمجة داخل تطبيق الواجهة sanad-client وتفعيل معمارية الاتصال الهجين على أجهزة سطح المكتب."
---

# خطة عمل: معمارية الديمون المضمن والاتصال الهجين (Embedded Daemon & Hybrid Connection)

تستعرض هذه الخطة خطوات تحويل وتضمين الديمون المحلي `sanadagent-local` كمكتبة (Dart Package) يتم تشغيلها مباشرة داخل تطبيق الواجهة الرسومية `sanad-client` في خيط منفصل (Isolate) للتخلص من مقابس الشبكة المحلية، مع الاحتفاظ بوضع الاتصال السحابي، ودعم تشغيل التطبيق بالخلفية، وإمكانية بث مقبس WebSocket خارجي لربط الإضافات الأخرى (مثل VS Code وسطر الأوامر).

---

## 1. الأهداف الرئيسية (Goals)
1. **التضمين في عملية واحدة (In-Process Execution)**: استدعاء وتشغيل محرك الوكيل محلياً داخل تطبيق فلاتر مباشرة بدون الحاجة لبناء أو تشغيل عملية مستقلة للديمون على أجهزة سطح المكتب.
2. **الاتصال بالذاكرة (In-Memory Communication)**: استبدال مقابس الويب سوكت المحلية (`localhost`) بقنوات بث مباشر في الذاكرة (Streams) عبر حدود خيوط المعالجة (Dart Isolates) لتسريع نقل الصوت والبيانات.
3. **خادم ويب سوكت اختياري**: إبقاء خادم ويب سوكت صامت داخل الوكيل المضمن لتسجيل الإضافات الخارجية (VS Code, CLI) إذا رغب المستخدم بذلك.
4. **التشغيل بالخلفية (Background Run)**: دعم إخفاء نافذة فلاتر بدلاً من إغلاقها عند الضغط على زر الإغلاق، وعرض أيقونة في شريط النظام (System Tray) لإبقاء المهام المجدولة والوكيل نشطاً.

---

## 2. التغييرات البرمجية المقترحة (Proposed Code Changes)

## 2.0 المتطلبات المسبقة قبل البدء بالتضمين (Required Prerequisites Before Embedding)

قبل إدخال `EmbeddedDaemonSocketService` فعلياً، يجب إكمال بعض أعمال التنظيف المعماري داخل `sanad-client` حتى لا يتم إدخال نوع اتصال ثالث فوق بنية ما زالت مرتبطة ضمنياً بمساري `cloud/local websocket` فقط.

### أ. تعميم طبقة إدارة الاتصال
* **فك الارتباط عن `SanadSocketService`:** المنسق الحالي `AgentConnectionCoordinator` ما زال يعتمد مباشرة على `SanadSocketService` بدل الاعتماد على abstraction عام. يجب تحويله ليعتمد على عقد موحد مثل `ISocketService` الموسع أو `ISanadTransport` بحيث يصبح أي transport جديد قابلاً للحقن بدون تعديل منطق المنسق نفسه.
* **استبدال ثنائية `cloud/local`:** `ConnectionScope` الحالي يعكس حالتين فقط. قبل إضافة التضمين، يجب استبداله بمفهوم أوسع مثل:
  * `transportType: cloud`
  * `transportType: local_ws`
  * `transportType: embedded`
  أو أي تسمية مكافئة تعبّر عن نوع endpoint الحقيقي بدل اختزاله إلى “محلي/سحابي”.
* **تحويل المنسق إلى selector عام:** بدلاً من منطق if/else خاص بالـ localhost، يجب أن يمتلك المشروع طبقة اختيار transport من مجموعة strategies/providers وفق:
  * المنصة
  * نفس الجهاز أو جهاز بعيد
  * readiness / lifecycle
  * إعدادات المستخدم
  * تفضيل embedded عند توفره

### ب. إزالة الافتراضات الصلبة بأن “المحلي = WebSocket”
* توجد أجزاء من المشروع ما زالت تعتبر أن الاتصال المحلي يعني بالضرورة `localhost websocket`. يجب تنظيف هذه الافتراضات قبل إدخال embedded transport حتى لا يتحول لاحقاً إلى استثناء خاص.
* أي منطق من نوع:
  * “إذا كان local فافعل connect على localhost”
  * “إذا كان local فاستمع لهذا socket تحديداً”
  يجب نقله إلى طبقة transport/provider بدل بقائه مبعثراً في ميزات متعددة.

### ج. توحيد lifecycle وreadiness contract
* التضمين يتطلب contract موحداً يصف:
  * `connecting`
  * `ready`
  * `disconnected`
  * `error`
  * القدرة على بث `events`
  * دعم `connect()` و`disconnect()` إن لزم
* يجب أن يلتزم transport المضمن بنفس العقد السلوكي الذي تتعامل معه طبقات البيانات والواجهة، حتى لا نضيف branching خاصاً لـ embedded في كل مكان.

### د. تثبيت حدود المسؤوليات الحالية قبل التوسعة
تم بالفعل تحسين بنية المحادثات مؤخراً، وأصبح:
* `watchThreads(...)` هو مسار bootstrap القياسي لقائمة المحادثات.
* `refreshThreads(...)` هو مسار التحديث اليدوي الصريح.
* `ThreadCubit` لم يعد يملك منطق bootstrap/reconnect hydration.

لكن قبل إدخال transport جديد، يجب الحفاظ على هذا الاتجاه وعدم إعادة منطق الاتصال إلى طبقة العرض أثناء التوسعة.

### هـ. ما الذي يجب اعتباره شرط دخول (Entry Criteria) قبل تنفيذ `EmbeddedDaemonSocketService`
يُفضّل عدم بدء تنفيذ transport المضمن قبل تحقق الشروط التالية:
1. وجود abstraction عام للـ transport غير مربوط بـ `SanadSocketService`.
2. وجود model واضح لنوع transport أو endpoint يتسع لـ `embedded`.
3. انتقال منطق اختيار المسار النشط بالكامل إلى coordinator/selector عام.
4. إزالة أي افتراض مباشر في الميزات بأن “local” يعني WebSocket فقط.
5. وجود اختبارات وحدة تغطي تبديل transport بين ثلاثة أنواع بدل نوعين.

### أولاً: ربط المشاريع وتخطي قيود الويب والموبايل
* **pubspec.yaml**: إضافة حزمة الديمون المحلي كاعتمادية مسار في ملف [pubspec.yaml](file:///sanad-client/pubspec.yaml):
  ```yaml
  dependencies:
    sanadagent_local:
      path: ../sanadagent-local
  ```
* **عزل الاستيراد (Conditional Compilation)**: نظراً لأن الديمون يعتمد على `dart:io` و `sqlite3` واللذان لا يترجمان على الويب، سننشئ كلاس مجرد لحقن الخدمة ونستخدم الاستيراد الشرطي أو حقن الاعتماديات برمجياً بناءً على المنصة:
  ```dart
  // في DI Configuration الخاص بـ get_it
  if (AppPlatform.isDesktop) {
    // تسجيل الخدمة المضمنة التي تستدعي الديمون
  }
  ```

### ثانياً: جسر الاتصال بالذاكرة (Direct Isolate Bridge)
* **EmbeddedDaemonSocketService**: إنشاء كلاس جديد يحقق عقد [ISocketService](file:///sanad-client/lib/core/interfaces/socket_service.dart). بدلاً من تهيئة مكتبة `socket_io` أو الـ WebSocket، يقوم هذا الكلاس بإنشاء خيط معالجة منفصل (Dart Isolate) وتخزين الـ `SendPort` الخاص به.
* **Isolate Protocol**: يتم تبادل الرسائل بين الواجهة والوكيل بصيغة رسائل مبسطة (Envelopes) تمرر عبر الـ Ports:
  * من الواجهة للوكيل: `sendPort.send({'type': 'execute_command', ...})`
  * من الوكيل للواجهة: مستمع الـ `ReceivePort` يستقبل البيانات ويضخها في تدفق الـ `events` التابع لـ `ISocketService`.

### ثالثاً: ترقية مسار الصوت الفوري
* **IsolateVoiceTransportChannel**: إنشاء فئة جديدة ترث من [VoiceTransportChannel](file:///sanad-agent/lib/infrastructure/voice/voice_transport_channel.dart) في الديمون:
  * بدلاً من الكتابة على مقبس الويب سوكت، تقوم دالة `sendOutputAudio` بإرسال بايتات الصوت الخام (PCM 24kHz) مباشرة لـ `SendPort` الخاص بالواجهة الرسومية لتشغيلها.
  * يستمع الوكيل الخلفي لتدفق الميكروفون الممرر برمجياً من خيط الواجهة.

### رابعاً: تشغيل فلاتر في الخلفية (Minimize to Tray)
* **تنصيب واجهة النظام**: استخدام حزم مثل `system_tray` لبناء أيقونة في شريط القوائم أو صينية النظام.
* **منع الإغلاق الفعلي**: ربط الحدث بـ `window_manager` في كود سطح المكتب لتنفيذ `windowManager.hide()` بدلاً من إغلاق العملية عند النقر على (X).

---

## 3. خطة التحقق والضمان (Verification Plan)

### الاختبارات المؤتمتة (Automated Tests)
* إنشاء اختبارات وحدة (Unit Tests) لـ `EmbeddedDaemonSocketService` للتأكد من إرسال واستقبال الأوامر النصية عبر منافذ الـ Isolate بنجاح.
* اختبار تكامل للتحقق من تدفق بايتات الصوت من خيط فلاتر إلى خيط الوكيل بشكل متسلسل وبدون فقدان للمصفوفات.
* إضافة اختبارات تبديل transport تغطي المسارات التالية على الأقل:
  * `cloud -> local_ws`
  * `cloud -> embedded`
  * `local_ws -> embedded`
  * `embedded -> cloud`
* إضافة اختبارات تضمن أن طبقة العرض لا تحتاج أي تعديل سلوكي عند إدخال transport ثالث.

### التحقق اليدوي (Manual Verification)
1. تشغيل التطبيق في وضع سطح المكتب وإغلاق النافذة، والتأكد من بقاء أيقونة النظام نشطة واستمرار تنفيذ المهام الخلفية.
2. فتح أداة سطر الأوامر (CLI) ومحاولة إرسال أمر للجهاز المحلي للتحقق من أن خادم الويب سوكت الاختياري المدمج يستقبل الاتصالات بنجاح.
