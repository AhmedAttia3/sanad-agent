# خطة المرحلة الثانية والعشرين: إعادة ترتيب مصادقة البوابة وإضافة تدفق Mobile PKCE

## الأهداف

تهدف هذه الخطة إلى تثبيت نموذج مصادقة آمن ومناسب لكل منصة قبل النشر العام:

1. الحفاظ على تدفق device-code الحالي للـ desktop وCLI وheadless agents.
2. إعادة ترتيب تجربة `sanad-portal` بحيث يسجل المستخدم الدخول أولًا ثم يدخل كود ربط الجهاز.
3. إضافة تدفق Mobile OAuth مستقل يعتمد على PKCE ومتصفح النظام بدل جعل كود الجهاز هو التجربة الأساسية على Android وiOS.
4. إبقاء الباكند provider-agnostic حتى يمكن إضافة Google وApple وEmail لاحقًا دون تعديل الوكيل أو معظم منطق الواجهة.
5. ضمان توافق تجربة الموبايل مع سياسات Google وApple بخصوص OAuth في التطبيقات الأصلية.

---

## القرار المعماري

لا نرجع للطريقة القديمة التي تجعل `session_id` الظاهر في المتصفح قادرًا وحده على سحب التوكنات.

لا نجعل device-code flow هو التجربة الأساسية للموبايل.

نعتمد ثلاثة مسارات واضحة:

| المنصة | التدفق الأساسي | السبب |
|---|---|---|
| Desktop app | Device-code عبر البوابة | آمن ومناسب لتجربة المتصفح الخارجي، ولا يتطلب deep link موثوق |
| CLI / Headless | Device-code عبر البوابة | مناسب للأجهزة التي لا تملك UI أو تعمل على سيرفرات |
| Web | Popup أو redirect داخل المتصفح | المتصفح هو البيئة الأصلية للمستخدم |
| Android | Authorization Code + PKCE عبر Custom Tabs | تجربة أصلية ومتوافقة مع OAuth للموبايل |
| iOS | Authorization Code + PKCE عبر ASWebAuthenticationSession أو plugin موثوق مبني عليه | تجربة أصلية ومتوافقة مع Apple وOAuth |

---

## النطاق

### 1. إعادة ترتيب Device-Code Portal Flow

التدفق الحالي في البوابة يطلب من المستخدم إدخال الكود قبل الضغط على زر Google. هذا آمن نسبيًا لكنه غير مألوف UX.

التدفق الجديد المطلوب:

1. التطبيق أو CLI يبدأ جلسة device-code من الباكند.
2. التطبيق أو CLI يعرض `user_code` للمستخدم ويحتفظ بـ `polling_token` محليًا فقط.
3. البوابة تفتح في المتصفح على `flow=device`.
4. المستخدم يسجل الدخول أولًا عبر Google أو Apple أو Email.
5. بعد نجاح تسجيل الدخول، تعرض البوابة شاشة إدخال الكود.
6. المستخدم يدخل الكود المعروض في التطبيق.
7. البوابة ترسل الكود للباكند ضمن سياق مستخدم مصادق.
8. الباكند يربط جلسة الجهاز بالمستخدم ويكمل جلسة polling.
9. التطبيق أو CLI يستقبل التوكنات عبر `/api/auth/device/status`.

### 2. Mobile PKCE Flow

يجب إضافة تدفق مخصص للموبايل بدل استخدام device-code كتجربة أساسية.

Android:

- فتح صفحة المصادقة عبر Android Custom Tabs.
- استخدام Authorization Code + PKCE.
- العودة للتطبيق عبر App Link أو deep link callback.
- عدم استخدام embedded WebView.

iOS:

- فتح المصادقة عبر ASWebAuthenticationSession أو plugin موثوق يستخدمه داخليًا.
- استخدام Authorization Code + PKCE.
- العودة للتطبيق عبر Universal Link أو custom URL scheme.
- عدم استخدام WKWebView لتسجيل الدخول عبر Google.

### 3. Backend Provider-Agnostic API

يجب أن يبقى الباكند غير مربوط بمزود واحد.

المسارات المقترحة:

- `POST /api/auth/mobile/{provider}/start`
  - ينشئ حالة OAuth مؤقتة.
  - يرجع authorization URL ومعلمات PKCE المطلوبة للعميل.
  - يحفظ `state` وبيانات الجلسة المؤقتة في Redis أو مخزن مؤقت آمن.

- `POST /api/auth/mobile/{provider}/callback`
  - يستقبل `code` و`state` وربما `redirect_uri`.
  - يتحقق من `state`.
  - يكمل تبادل OAuth عبر الباكند.
  - يصدر توكنات Sanad للواجهة.

أو بديل أكثر ملاءمة لبعض مكتبات الموبايل:

- endpoint لتبادل `authorization_code + code_verifier` بعد عودة التطبيق من المتصفح.

يجب أن تكون أسماء المزودين مثل `google` و`apple` تفاصيل portal/backend، وليست جزءًا من منطق الوكيل.

---

## المتطلبات الأمنية

- لا يتم استخدام embedded WebView لتسجيل الدخول عبر Google أو Apple.
- يجب استخدام PKCE في mobile auth flow.
- يجب التحقق من `state` لمنع CSRF وتبديل الجلسات.
- يجب ألا تظهر refresh tokens في query strings أو logs.
- يجب ألا تعتمد أي منصة على إخفاء طريقة الاتصال كوسيلة حماية.
- يجب أن يبقى `polling_token` الخاص بـ device-code داخل التطبيق أو CLI فقط.
- يجب أن يكون `user_code` مجرد كود تأكيد قصير، وليس bearer credential.
- يجب إضافة rate limits لمسارات start/callback/verify.
- يجب دعم revoke/expiry لجلسات mobile auth المؤقتة.

---

## متطلبات Apple قبل نشر iOS

إذا بقي Google ظاهرًا كخيار تسجيل دخول اجتماعي للمستخدمين على iOS، يجب إضافة Sign in with Apple أو خيار مكافئ يلتزم بسياسات Apple قبل نشر التطبيق على App Store.

يجب ألا تكون Apple إضافة شكلية فقط؛ يجب أن:

- تنشئ أو تربط مستخدم Sanad بنفس نموذج المستخدم الحالي.
- تدعم إخفاء البريد عند Apple.
- تحفظ هوية المزود بشكل يسمح بربط الحسابات لاحقًا.
- تعرض زر Apple بشكل متوافق بصريًا مع إرشادات Apple.

---

## تغييرات الباكند

- إضافة خدمة OAuth provider abstraction بدل تكرار منطق Google داخل handlers.
- فصل منطق:
  - إنشاء authorization URL.
  - تبادل authorization code.
  - التحقق من id token.
  - إنشاء أو ربط مستخدم Sanad.
  - إصدار Sanad JWT.
- إضافة mobile auth session store.
- إضافة endpoints لمسار mobile PKCE.
- تعديل device-code portal flow ليدعم إدخال الكود بعد المصادقة.
- إضافة اختبارات:
  - رفض `state` غير صالح.
  - رفض callback منتهي الصلاحية.
  - نجاح mobile start.
  - نجاح mobile callback mock.
  - استمرار device-code polling بدون كشف `polling_token`.

---

## تغييرات sanad-portal

- تحويل صفحة device-code إلى مرحلتين:
  - مرحلة تسجيل الدخول.
  - مرحلة إدخال الكود بعد نجاح تسجيل الدخول.
- جعل اختيار المزود في البوابة فقط.
- إضافة شاشة تأكيد ربط الجهاز:
  - تعرض اسم التطبيق.
  - تعرض رسالة واضحة أن المستخدم يربط جهازًا أو وكيلًا جديدًا بحسابه.
  - تطلب إدخال الكود.
- عدم إرسال `user_code` إلى مسار provider login قبل المصادقة.
- دعم مزودي مستقبلًا دون تغيير التطبيق أو CLI.

---

## تغييرات Flutter Client

- تعديل `AuthService.login()` ليختار التدفق حسب المنصة:
  - `AppPlatform.isMobile`: mobile PKCE flow.
  - Web: popup flow الحالي.
  - Desktop: device-code flow الحالي.
- إبقاء app-wide device-code overlay للـ desktop وCLI-like flows.
- عدم عرض device-code overlay كتجربة أساسية على Android/iOS.
- إضافة mobile callback handler في طبقة navigation أو app lifecycle حسب plugin المختار.
- التأكد من أن cancel يوقف الجلسة المؤقتة محليًا ويعيد UI لحالة قابلة لإعادة المحاولة.

---

## تغييرات CLI / Agent

- لا يلزم تغيير جوهري في CLI.
- يستمر `sanad login` في استخدام device-code flow.
- يستمر الوكيل في حفظ التوكنات محليًا مع صلاحيات آمنة.
- لا يعرف CLI أو الوكيل أسماء مزودي المصادقة.

---

## معايير القبول

### Device-Code Portal

- عند فتح البوابة من desktop/CLI، يرى المستخدم أزرار تسجيل الدخول أولًا.
- بعد نجاح تسجيل الدخول، يرى المستخدم شاشة إدخال الكود.
- إدخال كود صحيح يكمل جلسة polling في التطبيق أو CLI.
- إدخال كود خاطئ يعرض رسالة خطأ دون كشف تفاصيل حساسة.
- لا يظهر `polling_token` في URL أو صفحة البوابة أو logs.

### Mobile PKCE

- Android يفتح تسجيل الدخول عبر Custom Tabs أو plugin يستخدم Custom Tabs.
- iOS يفتح تسجيل الدخول عبر ASWebAuthenticationSession أو plugin موثوق يستخدمه داخليًا.
- العودة للتطبيق تكمل تسجيل الدخول دون نسخ كود يدوي.
- رفض callback عند `state` غير صالح.
- نجاح Google mobile login في بيئة dev.
- قبل نشر iOS، يتوفر Apple Sign-In إذا بقي Google ظاهرًا.

### عدم كسر المسارات الحالية

- `sanad login` يستمر في العمل.
- Desktop Flutter login يستمر في عرض كود داخل app-wide overlay.
- Web popup لا يعتمد على device-code كحل وحيد إذا كان redirect/popup مناسبًا.
- refresh token لا يعود إلى query string.
- Socket.IO لا يقبل mock auth tokens.

---

## خطة التنفيذ المقترحة

### المرحلة 1: إعادة ترتيب Portal Device-Code

- إضافة حالة مستخدم مصادق مؤقتًا داخل البوابة بعد نجاح OAuth.
- إضافة endpoint لربط `user_code` بعد المصادقة.
- تعديل Google callback ليعيد المستخدم إلى شاشة إدخال الكود عند `flow=device`.
- إضافة اختبارات backend للتدفق الجديد.

### المرحلة 2: Mobile PKCE Backend

- إضافة provider abstraction.
- إضافة mobile start/callback endpoints.
- إضافة Redis session state للموبايل.
- إضافة اختبارات start/callback/state/expiry.

### المرحلة 3: Flutter Mobile Integration

- اختيار plugin مناسب لـ Custom Tabs وASWebAuthenticationSession.
- إضافة platform routing في `AuthService`.
- إضافة deep link أو universal/app link handling.
- إضافة اختبارات unit لمسار اختيار flow.

### المرحلة 4: Apple Sign-In

- إضافة provider `apple` في الباكند.
- إضافة زر Apple في portal/mobile UI عند الحاجة.
- إضافة ربط مستخدم Apple مع نموذج المستخدم الحالي.

### المرحلة 5: QA قبل النشر

- تجربة desktop login.
- تجربة CLI login.
- تجربة web login.
- تجربة Android login.
- تجربة iOS login.
- تجربة إلغاء login وإعادة المحاولة.
- تجربة انتهاء صلاحية الجلسة.
- مراجعة logs للتأكد من عدم ظهور توكنات خام.

---

## خارج النطاق الحالي

- بناء نظام إدارة حسابات كامل داخل البوابة.
- ربط حسابات متعددة لنفس المستخدم إلا إذا تطلب Apple ذلك أثناء التنفيذ.
- تغيير نظام JWT الحالي إلا إذا كشف التنفيذ حاجة أمنية مباشرة.
- إزالة device-code flow من desktop أو CLI.

---

## قائمة تنفيذ المهام (Checklist)

> تُحدَّث هذه القائمة بعد إنجاز كل مهمة. علامة `[x]` تعني مكتمل، `[ ]` تعني قيد الانتظار.

### المرحلة 1: إعادة ترتيب Portal Device-Code

- [x] **B1.1** إنشاء `backend/app/services/oauth_providers.py` لاستخلاص منطق المزودين (Google + Apple stub).
- [x] **B1.2** إضافة `portal session` مؤقتة في Redis لحمل سياق المستخدم المصادق بعد OAuth.
- [x] **B1.3** تعديل `/api/auth/device/{provider}/login` ليدعم بدء OAuth دون `user_code` مسبقًا (مسار portal جديد) مع الحفاظ على التوافق الخلفي.
- [x] **B1.4** إضافة `POST /api/auth/device/verify` لربط `user_code` بجلسة الجهاز بعد المصادقة.
- [x] **B1.5** تعديل Google callback ليدعم بادئة `device_portal:` وتخزين توكنات المستخدم في portal session ثم redirect لشاشة إدخال الكود.
- [x] **B1.6** تحويل `sanad-portal/index.html` لتدفق مرحلتين: تسجيل دخول أولًا ثم إدخال الكود.
- [x] **B1.7** اختبارات backend للتدفق الجديد (verify ناجح/فاشل، portal session منتهية).

### المرحلة 2: Mobile PKCE Backend

- [x] **B2.1** إضافة schemas لمسار mobile (`MobileStartRequest/Response`, `MobileCallbackRequest`, `MobileStatusRequest/Response`).
- [x] **B2.2** إنشاء `backend/app/api/auth_mobile.py` مع `POST /api/auth/mobile/{provider}/start`.
- [x] **B2.3** إضافة `POST /api/auth/mobile/{provider}/callback` (تبادل `code + code_verifier`).
- [x] **B2.4** إضافة `POST /api/auth/mobile/{provider}/status` للـ polling fallback.
- [x] **B2.5** حفظ `state` + بيانات PKCE في Redis مع TTL و expiry/revoke.
- [x] **B2.6** rate limits على start/callback/status/verify.
- [x] **B2.7** تسجيل الراوتر الجديد في `server.py`.
- [x] **B2.8** اختبارات: رفض state غير صالح، رفض callback منتهي، نجاح start، نجاح callback mock، نجاح status.

### المرحلة 3: Flutter Mobile Integration

- [x] **F3.1** إضافة `crypto` لـ pubspec لتوليد PKCE (S256).
- [x] **F3.2** إنشاء `MobileAuthService` (توليد code_verifier/challenge، استدعاء /start، فتح متصفح النظام، polling /status).
- [x] **F3.3** تعديل `AuthService.login()` ليختار التدفق حسب المنصة (`AppPlatform.isMobile` → mobile PKCE، Web → popup، Desktop → device-code).
- [x] **F3.4** إبقاء app-wide device-code overlay للـ desktop/CLI flows فقط.
- [x] **F3.5** معالجة cancel (إيقاف الجلسة المؤقتة محليًا + إعادة UI لحالة قابلة لإعادة المحاولة).
- [x] **F3.6** اختبارات unit لاختيار التدفق حسب المنصة.
- [x] **F3.7** إعداد Android intent-filter + iOS URL scheme لـ deep link `sanad://oauth` (موجود مسبقًا في المنصتين؛ polling هو الـ fallback الموثوق، ودمج `app_links` لاستقبال فوري هو تحسين مستقبلي).

### المرحلة 4: Apple Sign-In

- [x] **B4.1** إضافة provider `apple` في `oauth_providers.py` (stub مع TODO لتبادل code+client_secret JWT).
- [x] **B4.2** دعم مسار mobile/device لـ apple في الباكند (عبر `get_provider('apple')`).
- [ ] **B4.3** تفعيل زر Apple في portal/mobile UI عند الحاجة (موجود كـ Coming Soon؛ يحتاج تفعيل بعد إكمال تبادل Apple).
- [x] **B4.4** ربط مستخدم Apple بنموذج المستخدم الحالي مع دعم إخفاء البريد (في `AppleOAuthProvider.get_or_create_user`).

### المرحلة 5: QAقبل النشر

- [ ] **Q5.1** تجربة desktop login.
- [ ] **Q5.2** تجربة CLI login.
- [ ] **Q5.3** تجربة web login.
- [ ] **Q5.4** تجربة Android login (device QA).
- [ ] **Q5.5** تجربة iOS login (device QA).
- [ ] **Q5.6** تجربة إلغاء login وإعادة المحاولة.
- [ ] **Q5.7** تجربة انتهاء صلاحية الجلسة.
- [ ] **Q5.8** مراجعة logs للتأكد من عدم ظهور توكنات خام.
- [x] **Q5.9** `fvm flutter analyze` + `fvm flutter test` يمران دون أخطاء.
- [x] **Q5.10** `PYTHONPATH=../agent ../.venv/bin/python -m pytest tests/` يمر دون أخطاء.

---

## ملاحظات التنفيذ

- **PKCE mode المتبع للموبايل:** `server_pkce` كافتراضي (يولّد الباكند verifier ويتبادل الكود بنفسه)، مع دعم `client_pkce` (العميل يولّد verifier ويرسله في `/callback`) لمسار deep link. الـ polling عبر `/status` هو الـ fallback الموثوق ولا يتطلب إعداد deep link.
- **التوافق الخلفي:** مسار `user_code` القديم في `/api/auth/device/{provider}/login` ما زال يعمل للعملاء الحاليين؛ المسار الجديد عبر `portal_session` هو الافتراضي للبوابة.
- **نقاط TODO قبل نشر iOS:** إكمال تبادل كود Apple (client_secret JWT) و verify id_token في `AppleOAuthProvider`، وتفعيل زر Apple في البوابة.

