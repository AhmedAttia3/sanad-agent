# خطة المرحلة الثالثة والعشرين: تحويل sanad-portal إلى وسيط المصادقة الوحيد للمشروع المفتوح المصدر

## خلفية القرار

تم تنفيذ الخطة 22 بالفعل، وأصبحت هناك مسارات مباشرة بين `sanad-agent` / `sanad-client` المفتوحين المصدر وبين `backend` في جزء المصادقة، مثل device-code وmobile PKCE.

هذا ليس الحد المعماري المطلوب. المطلوب الآن هو refactor واضح يجعل المشروع المفتوح المصدر لا يعرف ولا يستدعي مسارات مصادقة الباكند مباشرة.

القرار الجديد:

- `sanad-agent` و`sanad-client` يتعاملان مع `sanad-portal` فقط في كل ما يخص المصادقة.
- `sanad-portal` يصبح Auth Broker / BFF للمصادقة.
- `backend` لا يستقبل orchestration عام للمصادقة من العملاء المفتوحين المصدر.
- تواصل `sanad-portal` مع `backend` يكون server-to-server أو عبر مسارات داخلية محمية.
- بعد اكتمال المصادقة، يمكن للعميل استخدام access token للاتصال بالـ backend في REST/Socket.IO العادي، لكن ليس لتنظيم أو بدء المصادقة.
- كل المنصات تبدأ نفس المسار العام `POST /auth/start` وتتابع نفس المسار العام `POST /auth/status`.
- العميل لا يطلب device-code كمسار منفصل. العميل يرسل `platform` و`capabilities` فقط، و`sanad-portal` وحده يقرر هل يلزم `user_code`.

---

## الأهداف

1. إزالة أي اتصال مباشر من `sanad-agent` و`sanad-client` إلى `backend` في مسارات المصادقة.
2. جعل `sanad-portal` هو public auth surface الوحيد.
3. الحفاظ على دعم:
   - Desktop عبر صفحة portal في متصفح النظام.
   - CLI/headless عبر portal session مع user code عند الحاجة.
   - Web popup/portal login.
   - Mobile عبر system browser أو ASWebAuthenticationSession/Custom Tabs.
4. عدم الرجوع للطريقة الضعيفة التي تجعل `session_id` الظاهر في المتصفح كافيًا لسحب التوكنات.
5. جعل اختيار المزودين بالكامل داخل صفحة `sanad-portal`، بحيث لا يعرف المشروع المفتوح المصدر أسماء Google أو Apple أو Email.
6. تحصين الحدود الداخلية بين `sanad-portal` و`backend`.

---

## الحدود الجديدة

### Public Boundary

هذه هي المسارات العامة التي يعرفها المشروع المفتوح المصدر:

- `sanad-portal`
  - `/auth/start`
  - `/auth/status`
  - `/auth/cancel`
  - `/auth/refresh`
  - `/auth/logout`

لا يعرف المشروع المفتوح المصدر أي مسار يتضمن اسم المزود مثل `google` أو `apple`.

لا يجب أن تظهر مسارات `backend/app/api/auth_*` في كود `sanad-agent` المفتوح المصدر.

### Internal Boundary

هذه المسارات لا يستدعيها إلا `sanad-portal`:

- `sanad-portal` داخليًا:
  - `/login`
  - `/oauth/{provider}/start`
  - `/oauth/{provider}/callback`
  - `/device/verify`
  - `/handoff`

- `backend` داخليًا:
  - `/internal/auth/google/exchange`
  - `/internal/auth/apple/exchange`
  - `/internal/auth/users/upsert`
  - `/internal/auth/tokens/issue`
  - `/internal/auth/refresh`
  - أو واجهة داخلية مكافئة حسب التصميم النهائي.

يجب حماية هذه المسارات بواسطة:

- shared internal secret.
- أو mTLS لاحقًا.
- أو network isolation داخل Docker/private network مع secret إلزامي.

لا يكفي الاعتماد على أن المسار “غير معروف”. يجب أن يرفض backend أي طلب internal auth بدون إثبات أن المصدر هو `sanad-portal`.

---

## ما يجب إزالته من المشروع المفتوح المصدر

### Flutter Client

يجب إزالة أو استبدال أي استدعاء مباشر لـ:

- `/api/auth/device/start`
- `/api/auth/device/status`
- `/api/auth/device/verify`
- `/api/auth/mobile/{provider}/start`
- `/api/auth/mobile/{provider}/callback`
- `/api/auth/mobile/{provider}/status`
- `/api/auth/session/start`
- `/api/auth/session/status`
- `/api/auth/refresh`
- أي مسار portal عام يحتوي `{provider}` أو اسم مزود مثل `google` أو `apple` داخل كود العميل.

البديل:

- `AuthService` يستخدم `PortalAuthService` أو `PortalAuthClient`.
- كل auth URLs تأتي من `AppConfig.portalUrl`.
- لا يبني العميل `backendUrl` لأغراض المصادقة.
- لا يمرر العميل `backend_url` إلى البوابة.
- لا يختار العميل مزود تسجيل الدخول. المستخدم يختار المزود داخل صفحة `sanad-portal` فقط.
- يرسل العميل إلى `POST /auth/start` معلومات عامة فقط مثل `platform`, `return_uri`, وcapabilities غير حساسة.
- لا يرسل العميل اختيار flow باسم `device-code` أو `mobile-pkce`; اختيار النمط العملي يتم داخل `sanad-portal` بناءً على platform/capabilities.

### CLI / Agent

يجب تعديل `sanad login` بحيث:

- يبدأ login من `sanad-portal` فقط.
- يعمل polling على `sanad-portal` فقط.
- لا يعرف مسارات `/api/auth/*` الخاصة بالباكند.
- لا يعرف أسماء provider endpoints في backend أو portal.

الوكيل بعد المصادقة يستطيع استخدام access token أو device token للاتصال بالـ backend كجزء من تشغيل النظام، لكن ليس كبداية أو إدارة عملية المصادقة.

---

## تصميم تدفقات المصادقة بعد refactor

### 1. جلسة Portal موحدة لكل المنصات

1. العميل يستدعي `POST {PORTAL_URL}/auth/start`.
2. `sanad-portal` ينشئ:
   - `auth_session_id`
   - `polling_token`
   - `auth_url`
   - `expires_in`
   - `interval`
   - وربما `user_code` فقط إذا قرر `sanad-portal` أن المنصة أو قدراتها تتطلب fallback آمنًا مثل CLI/headless.
3. العميل يفتح `auth_url` في المتصفح المناسب للمنصة.
4. صفحة `sanad-portal` تعرض مزودي تسجيل الدخول للمستخدم.
5. المستخدم يختار المزود داخل المتصفح.
6. `sanad-portal` يكمل OAuth/Email flow داخليًا.
7. `sanad-portal` يتواصل داخليًا مع `backend` لإصدار Sanad tokens.
8. العميل يعمل polling على `POST {PORTAL_URL}/auth/status` باستخدام `auth_session_id` و`polling_token`.
9. عند اكتمال الجلسة، يحصل العميل على توكناته من `sanad-portal`.

قواعد الأمان:

- `polling_token` لا يدخل المتصفح.
- `auth_url` يحتوي session reference غير حساس فقط، ولا يحتوي backend URL أو `polling_token`.
- التوكنات لا تظهر في query strings.
- أسماء المزودين لا تظهر في كود العميل.
- المتصفح لا يستقبل access token أو refresh token مباشرة.

### 2. Desktop / Web / Mobile

كل هذه المنصات تبدأ بنفس الواجهة العامة: `POST /auth/start`.

`sanad-portal` يقرر تجربة المتصفح المناسبة بناءً على platform/capabilities:

- Desktop: فتح `auth_url` في متصفح النظام أو نافذة داخلية آمنة حسب المنصة.
- Web: popup أو redirect إلى `auth_url`.
- Android: فتح `auth_url` عبر Custom Tabs.
- iOS: فتح `auth_url` عبر ASWebAuthenticationSession أو plugin موثوق يستخدمه داخليًا.

في جميع الحالات، اختيار Google أو Apple أو Email يحدث داخل صفحة `sanad-portal`.

يمكن دعم deep link أو handoff code لتحسين تجربة الرجوع للموبايل، لكن النتيجة الأساسية يجب أن تبقى قابلة للاكتمال عبر `POST /auth/status` باستخدام `polling_token`.

لا تظهر شاشة إدخال كود في desktop/mobile/web العادي. تظهر فقط عندما يقرر `sanad-portal` أن الجلسة تحتاج fallback مثل CLI/headless أو بيئة لا يمكن فيها ربط جلسة المتصفح بجلسة العميل بشكل آمن.

قواعد الأمان:

- عدم استخدام embedded WebView.
- استخدام PKCE داخليًا في portal/provider flow عند الحاجة.
- التحقق من `state` داخل `sanad-portal`.
- عدم وضع access token أو refresh token في deep link.
- إذا استُخدم handoff code، يكون one-time وقصير العمر ومربوطًا بـ `state`.

### 3. CLI / Headless

الـ CLI/headless لا يختار مزودًا ولا يبني provider URL.

- يبدأ من `POST /auth/start` مع platform يوضح أنه CLI/headless.
- يطبع `auth_url` وربما `user_code` إذا قرر portal أن التجربة تحتاج كودًا.
- المستخدم يختار المزود داخل portal.
- CLI يعمل polling على `/auth/status`.

---

## تغييرات sanad-portal

يجب تحويل `sanad-portal` من static HTML فقط إلى auth broker فعلي.

الخيارات المقبولة:

1. إضافة backend صغير للـ portal.
2. أو نقل `sanad-portal` إلى تطبيق server-rendered / API-capable.
3. أو خدمة مستقلة خفيفة تعمل بجانب Nginx.

متطلبات `sanad-portal`:

- امتلاك public auth endpoints.
- إدارة جلسات مؤقتة آمنة.
- إدارة OAuth callbacks.
- التواصل الداخلي مع backend.
- تقديم صفحات UX:
  - login provider selection.
  - device-code verification بعد login.
  - mobile success/failure.
  - cancel/retry.
- إخفاء كل تفاصيل المزودين عن `sanad-agent` و`sanad-client`.
- إدارة provider registry داخل portal فقط.

لا يكفي إبقاء `sanad-portal` كملف HTML ثابت إذا كان هو auth broker الوحيد.

---

## تغييرات backend

### Public API

- إبقاء REST وSocket.IO للأعمال العادية.
- إزالة أو تعطيل public auth orchestration endpoints التي يستدعيها العملاء المفتوحون المصدر.
- أي endpoint عام متبقٍ للمصادقة يجب أن يكون compatibility-only ومحدد بمرحلة انتقالية قصيرة.

### Internal Auth API

إضافة طبقة داخلية محمية يستخدمها `sanad-portal` فقط:

- إصدار توكنات Sanad بعد تحقق provider identity.
- refresh token.
- logout/revoke.
- upsert user.
- ربط provider identity بمستخدم.

متطلبات الحماية:

- header مثل `X-Sanad-Internal-Auth` بقيمة secret من env.
- رفض أي طلب بلا secret أو بقيمة خاطئة.
- عدم تسجيل السر أو التوكنات.
- rate limits حتى على المسارات الداخلية إذا كانت قابلة للوصول شبكيًا.

---

## تغييرات Flutter Client

- إضافة `PortalAuthClient`.
- نقل كل auth calls إلى `portalUrl`.
- حذف `backendUrl` من مسارات المصادقة.
- إبقاء `backendUrl` فقط للـ REST/Socket.IO بعد الحصول على access token.
- تعديل `AuthService.login()`:
  - يستدعي `POST /auth/start` دائمًا.
  - يفتح `auth_url` حسب المنصة.
  - يعمل polling على `POST /auth/status`.
  - لا يحتوي أي branching حسب provider.
  - لا يحتوي أي branching لاختيار device-code مقابل mobile PKCE؛ يرسل platform/capabilities فقط.
- تعديل refresh:
  - refresh عبر `sanad-portal`.
  - أو إذا تقرر أن refresh من backend مسموح بعد المصادقة، يجب توثيق ذلك كاستثناء صريح. الافتراضي في هذه الخطة: refresh عبر portal.
- تحديث الاختبارات للتأكد من عدم وجود `/api/auth/` backend calls داخل `AuthService`.
- تحديث الاختبارات للتأكد من عدم وجود `google`, `apple`, أو `{provider}` في auth client paths.

---

## تغييرات CLI / Agent

- `sanad login` يستخدم `PORTAL_URL`.
- لا يطبع أو يبني أي backend auth URL.
- لا يستدعي `/api/auth/device/start` أو `/api/auth/session/start`.
- لا يستدعي أي مسار provider-specific.
- لا يطلب device-code كـ flow منفصل؛ يرسل platform/capabilities ويعرض `user_code` فقط إذا أعاده portal.
- polling يتم على `sanad-portal`.
- حفظ التوكنات في `auth.json` يبقى كما هو مع صلاحيات `0600`.

---

## التوافق الانتقالي بعد تنفيذ الخطة 22

بما أن الخطة 22 نُفذت بالفعل، يجب تنفيذ refactor على مراحل لتجنب كسر النظام:

### المرحلة A: إضافة Portal Auth Broker دون حذف القديم

- إضافة endpoints في `sanad-portal`.
- إبقاء backend auth endpoints القديمة مؤقتًا.
- تحديث Flutter/CLI لاستخدام portal.
- إضافة اختبارات تمنع أي اتصال auth مباشر من المشروع المفتوح المصدر إلى backend.

### المرحلة B: تحويل backend auth إلى internal

- إضافة internal auth endpoints محمية.
- نقل OAuth exchange/token issue لاستخدامها من portal.
- منع العملاء من استدعاء public backend auth endpoints.

### المرحلة C: إزالة أو تعطيل public backend auth

- حذف أو إخفاء مسارات:
  - `auth_session.py` العامة.
  - `auth_mobile.py` العامة.
  - device-code العامة.
- أو إبقاؤها فقط خلف feature flag داخلي لفترة انتقالية قصيرة.

### المرحلة D: تنظيف docs/tests/config

- تحديث `AGENTS.md` في backend/client/agent.
- تحديث docs التقنية.
- حذف references في `sanad-agent` لأي backend auth endpoint.
- إضافة guard tests.

---

## اختبارات Guard إلزامية

### في sanad-agent/client

- test أو lint يفشل إذا ظهر داخل auth code:
- `/api/auth/`
- `auth/device`
- `auth/mobile`
- `auth/session`
- `mobile/`
- `google`
- `apple`
- `{provider}`
- `backendUrl` داخل auth login/refresh flows.

### في sanad-agent/agent

- test أو lint يفشل إذا ظهر داخل `bin/login.dart` أو `AuthManager`:
- `/api/auth/`
- backend auth URL construction.
- أسماء مزودين داخل login flow.

### في backend

- test يتأكد أن internal auth endpoints ترفض الطلب بلا internal secret.
- test يتأكد أن public clients لا يمكنهم إكمال auth orchestration عبر backend مباشرة.

### في sanad-portal

- test لمسارات:
  - auth start/status/cancel.
  - provider selection داخل portal.
  - OAuth provider start/callback الداخلي.
  - refresh/logout.
  - رفض replay للـ handoff code.
  - رفض state خاطئ.

---

## معايير القبول

- لا يوجد في `sanad-agent` المفتوح المصدر أي استدعاء مباشر لمسارات backend auth.
- `sanad-agent` و`sanad-client` يعرفان `PORTAL_URL` كمصدر auth الوحيد.
- `sanad-agent` و`sanad-client` لا يعرفان أسماء مزودي تسجيل الدخول ولا يبنيان مسارات provider-specific.
- `sanad-agent` و`sanad-client` لا يختاران auth flow باسم device-code أو mobile PKCE؛ الاختيار العملي يتم داخل `sanad-portal`.
- `backend` لا يقبل auth orchestration عام من العملاء المفتوحين المصدر.
- Google وApple callbacks العامة تنتهي في `sanad-portal` وليس backend.
- التوكنات لا تظهر في URLs أو logs.
- refresh يتم عبر portal أو موثق كاستثناء صريح ومؤمن.
- Mobile يفتح صفحة portal عبر متصفح النظام، والـ portal يدير PKCE/provider flow داخليًا.
- Desktop/Web يفتحان صفحة portal، والـ portal يعرض المزودين.
- CLI/headless يستخدمان portal session وpolling، مع user code فقط عند الحاجة.
- لا تظهر شاشة إدخال الكود في desktop/mobile/web العادي.
- تظهر شاشة إدخال الكود فقط في CLI/headless أو fallback موثق عندما لا يمكن ربط جلسة المتصفح بجلسة العميل بشكل آمن.
- Socket.IO والـ REST بعد المصادقة يستمران في استخدام backend access token بشكل طبيعي.

---

## خارج النطاق

- منع العميل بعد المصادقة من الاتصال بالـ backend للأعمال العادية.
- إخفاء backend URL بالكامل عن العميل. هذا ليس هدفًا أمنيًا واقعيًا بعد المصادقة.
- الاعتماد على غموض endpoint names كوسيلة حماية.
- بناء نظام billing/subscriptions كامل داخل portal.

---

## Checklist تنفيذ الخطة

تُحدَّث بعد الانتهاء من كل بند. الحالة: `[ ]` = لم يبدأ، `[~]` = قيد التنفيذ، `[x]` = منتهٍ.

### المرحلة A: إضافة Portal Auth Broker

- [x] **A1.** إنشاء تطبيق `sanad-portal` كخدمة FastAPI قادرة على تقديم HTML + API.
  - [x] A1.1 `sanad-portal/app/main.py` + `sanad-portal/app/server.py` (FastAPI app + static mounts).
  - [x] A1.2 إدارة جلسات في Redis (`sanad-portal/app/services/session_store.py`).
  - [x] A1.3 عميل داخلي للـ backend (`sanad-portal/app/services/backend_client.py`) مع `X-Sanad-Internal-Auth`.
  - [x] A1.4 سجل المزودين (`sanad-portal/app/services/provider_registry.py`).
  - [x] A1.5 Pydantic schemas للـ public و internal endpoints.
- [x] **A2.** Public endpoints في `sanad-portal/app/api/public_auth.py`:
  - [x] A2.1 `POST /auth/start` (يقرر `user_code` حسب platform/capabilities).
  - [x] A2.2 `POST /auth/status` (polling بـ `auth_session_id` + `polling_token`).
  - [x] A2.3 `POST /auth/cancel`.
  - [x] A2.4 `POST /auth/refresh`.
  - [x] A2.5 `POST /auth/logout`.
- [x] **A3.** Internal endpoints في `sanad-portal/app/api/internal_auth.py`:
  - [x] A3.1 `GET /oauth/{provider}/start`.
  - [x] A3.2 `GET /oauth/{provider}/callback`.
  - [x] A3.3 `POST /login` (اختياري لتسجيل دخول email مستقبليًا).
  - [x] A3.4 `POST /device/verify`.
  - [x] A3.5 `POST /handoff`.
- [x] **A4.** تحويل صفحات HTML (index.html، success.html) لتستخدم endpoints الـ portal فقط (لا `backend_url` ولا أسماء مزودين تظهر للعميل).
- [x] **A5.** تحديث `sanad-portal/Dockerfile` ليبني تطبيق Python بدل nginx-only.
- [x] **A6.** إضافة `PORTAL_URL` إلى `AppConfig` في Flutter client (`backendUrl` يبقى لـ REST/Socket.IO بعد المصادقة فقط).
- [x] **A7.** إنشاء `sanad-agent/client/lib/features/auth/infrastructure/portal_auth_client.dart`.
- [x] **A8.** إعادة كتابة `AuthService.login()` و `_loginDeviceCode()` في Flutter لاستخدام `/auth/start` و `/auth/status` على portal فقط (يرسل `platform` + `capabilities` فقط، بدون أسماء مزودين).
- [x] **A9.** إعادة كتابة `_loginMobile()` و `MobileAuthService.login()` في Flutter لاستخدام portal `/auth/start` (لا `/api/auth/mobile/*`) — حُذف `MobileAuthService` ودمِجت المنصات في تدفق portal موحد.
- [x] **A10.** نقل `_refreshAccessToken()` في Flutter ليستخدم `POST {portalUrl}/auth/refresh`.
- [x] **A11.** إعادة كتابة `sanad-agent/agent/bin/login.dart` لاستخدام `PORTAL_URL` فقط (لا `gatewayUrl`، لا `/api/auth/device/*`).

### المرحلة B: تحويل backend auth إلى internal

- [x] **B1.** إضافة `SANAD_INTERNAL_AUTH_SECRET` إلى env (يقرأه `auth_internal.py` عبر `os.getenv`).
- [x] **B2.** إنشاء `backend/app/api/auth_internal.py` بالمسارات الداخلية المحمية:
  - [x] B2.1 `POST /internal/auth/google/exchange`.
  - [x] B2.2 `POST /internal/auth/apple/exchange`.
  - [x] B2.3 `POST /internal/auth/users/upsert`.
  - [x] B2.4 `POST /internal/auth/tokens/issue`.
  - [x] B2.5 `POST /internal/auth/refresh`.
  - [x] B2.6 `POST /internal/auth/tokens/revoke` (إضافي لـ logout).
- [x] **B3.** Dependency مشترك `require_internal_secret` يرفض الطلب بدون/بخطأ `X-Sanad-Internal-Auth`.
- [x] **B4.** تسجيل الراوتر في `backend/app/server.py` على المسار `/api/internal/auth/...`.

### المرحلة C: إزالة أو تعطيل public backend auth

- [x] **C1.** تعطيل مسارات `auth_session.router` و `auth_mobile.router` العامة في `backend/app/server.py` (إبقاء `auth_google` و`auth_local` للاستخدام الداخلي/الانتقالي).
- [x] **C2.** حذف اختبارات `tests/test_auth_mobile.py` و `tests/test_auth_session.py` الموافقة للمسارات المعطلة.
- [x] **C2.1.** الـ portal يستدعي فقط `/api/internal/auth/...` (مُوثَّق في `sanad-portal/app/services/backend_client.py`).

### المرحلة D: اختبارات Guard + توثيق + إعدادات

- [x] **D1.** Guard test في `sanad-agent/client/test/guards/test_portal_auth_surface_guard.dart` يفشل إذا ظهر في auth code: `/api/auth/`, `auth/device`, `auth/mobile`, `auth/session`, `google`, `apple`, `{provider}`, أو `backendUrl` داخل login/refresh.
- [x] **D2.** Guard test في `sanad-agent/agent/test/guards/test_login_contract_guard.dart` يفشل إذا ظهر في `bin/login.dart` أو `AuthManager`: `/api/auth/`، بناء backend auth URL، أسماء مزودين داخل login flow.
- [x] **D3.** Backend test `tests/test_auth_internal_guard.py` يتأكد أن internal auth endpoints ترفض بدون `X-Sanad-Internal-Auth` أو بقيمة خاطئة.
- [x] **D4.** Portal tests في `sanad-portal/tests/test_internal_endpoints.py` لمسارات: `/auth/start`, `/auth/status`, `/auth/cancel`, `/auth/refresh`, `/oauth/{provider}/start`, `/oauth/{provider}/callback`, رفض replay للـ handoff، رفض state خاطئ.
- [x] **D5.** تحديث `backend/AGENTS.md` (PORTAL_URL → internal auth contract، إزالة device-code/mobile PKCE public reference).
- [x] **D6.** تحديث `sanad-agent/client/lib/features/AGENTS.md` (Portal-first auth flow، إزالة device-code/Mobile PKCE backend refs).
- [x] **D7.** تحديث `sanad-agent/agent/AGENTS.md` (sanad login عبر PORTAL_URL فقط).
- [x] **D8.** إنشاء `sanad-portal/.env`-style توثيق داخل `sanad-portal/app/config.py` و `sanad-portal/requirements.txt`.
- [x] **D9.** تحديث `docker-compose.yml`: إضافة `SANAD_INTERNAL_AUTH_SECRET`، `PORTAL_URL`، متغيرات الـ portal، وتحويل الـ portal من nginx إلى FastAPI على المنفذ 8083.
- [x] **D10.** تحديث `.env.dev` و `.env.prod` بالمتغيرات الجديدة.

### التحقق النهائي

- [x] **V1.** `fvm flutter analyze` (sanad-agent/client) بدون أخطاء.
- [x] **V2.** `fvm dart analyze` (sanad-agent/agent) بدون أخطاء.
- [x] **V3.** `fvm flutter test` (sanad-agent/client) نجاح (338 اختبار).
- [x] **V4.** `fvm dart test` (sanad-agent/agent) نجاح.
- [x] **V5.** `PYTHONPATH=.. ../.venv/bin/python -m pytest tests/` (backend) نجاج (124 اختبار).
- [x] **V5.1.** Portal tests: `PYTHONPATH=. ../.venv/bin/python -m pytest tests/` نجاح (15 اختبار).
- [x] **V6.** مراجعة نهائية: لا وجود لأي `/api/auth/` أو `google`/`apple`/`{provider}` في كود auth المفتوح لكلاً من `sanad-agent` و`sanad-client` (مُطبَّق عبر guard tests V1/D1 و V4/D2).
