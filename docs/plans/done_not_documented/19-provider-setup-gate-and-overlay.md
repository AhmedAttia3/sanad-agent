# خطة المرحلة التاسعة عشر: بوابة إعداد مزودي LLM عبر الوكيل والواجهة

## خلفية القرار

الوضع الحالي في Sanad يعتمد على إعداد مزود LLM من الطرفية فقط عبر:

- `sanad-agent/agent/bin/setup.dart`
- `sanad-agent/agent/lib/core/setup/provider_setup.dart`
- `sanad-agent/agent/lib/core/setup/setup_helpers.dart`
- `sanad-agent/agent/lib/engine/adapters/provider_registry.dart`

تستطيع واجهة Flutter اليوم إكمال onboarding بمجرد اتصال الوكيل المحلي، لكنها لا تتحقق من وجود مزود LLM صالح داخل الوكيل. النتيجة أن المستخدم قد يدخل التطبيق بينما runtime غير قادر على إرسال أي طلب LLM.

يعتمد تصميم Sanad ثلاث أفكار أساسية لحل هذه المشكلة:

1. وجود مصدر حقيقة واحد لقائمة المزودين وطرق المصادقة.
2. وجود readiness gate يفصل بين "الإعداد موجود" و"runtime قادر على استخدام المزود".
3. وجود واجهة تفاعلية لإضافة المزود ثم اختيار النموذج، مع إمكانية إعادة استخدام نفس المنطق في onboarding والإعدادات.

## قرار معماري رئيسي

لن يتم بناء هذه الميزة حول REST endpoints جديدة للواجهة. Sanad يملك بالفعل قناة اتصال مفتوحة بين العميل والوكيل، وهذه القناة يجب أن تكون العقد الأساسي لهذه الميزة:

- في الوضع المحلي: `sanad-client` يتحدث مع `sanad-agent` عبر local gateway socket.
- في الوضع السحابي: `sanad-client` يتحدث مع الوكيل المحدد عبر Sanad Gateway وSocket.IO كما يحدث اليوم في بقية وظائف التطبيق.

لذلك يتم تنفيذ الميزة كأوامر socket/canonical protocol قابلة للنقل عبر مساري الاتصال الموجودين حاليا، وليس كواجهات HTTP مخصصة. لا تعتبر cloud path عملا لاحقا هنا؛ يجب أن تعمل أوامر إعداد المزود والنموذج من البداية مع الاتصال المحلي ومع الاتصال السحابي بدون تدمير منطق اختيار الجهاز الحالي. قد يستخدم الوكيل HTTP داخليا فقط عند الحاجة إلى callback مؤقت لتدفقات loopback OAuth، لكن هذا لا يكون عقدا عاما تتحدث معه الواجهة.

## الأهداف

1. جعل الوكيل مصدر الحقيقة الوحيد لقائمة مزودي LLM، طرق المصادقة، حالة الإعداد، والنموذج الافتراضي.
2. إتاحة إعداد المزود من الواجهة في onboarding أولا، ثم من إعدادات التطبيق لاحقا باستخدام نفس الخدمات ونفس عقود البروتوكول.
3. دعم فئات المصادقة الأساسية:
   - API key.
   - مزود محلي أو endpoint مخصص.
   - device code OAuth.
   - loopback OAuth.
   - external/manual providers عند الحاجة.
4. فصل منطق المصادقة والحفظ واكتشاف المزودين عن واجهة الطرفية الحالية حتى يستخدمه كل من CLI وFlutter.
5. منع تجربة المحادثة على الجهاز المختار عندما لا يملك ذلك الجهاز provider runtime جاهزا، مع الحفاظ على أن web/mobile لا يحتاجان local daemon إذا كانا يستخدمان جهازا سحابيا.
6. دعم عرض كل المزودين الذين سبق إعدادهم، ليختار المستخدم المزود ثم النموذج داخل المزود.

## خارج نطاق المرحلة الأولى

- بناء صفحة إعدادات كاملة لإدارة المزودين. المرحلة الأولى تجهز الخدمات والعقود وواجهة onboarding فقط، مع تصميمها بحيث يعاد استخدامها لاحقا في settings.
- دعم marketplace أو تثبيت مزودين من خارج `ProviderRegistry`.
- إضافة كل المزودين دفعة واحدة إذا احتاج بعضها بنية خاصة غير موجودة في Sanad.
- اعتبار مسار `openai-codex` الحالي في Sanad مدعوما بشكل كامل تلقائيا. المراجعة الحالية للكود تثبت أنه تنفيذ جزئي: لديه provider profile و`CodexResponsesAdapter` وdevice-code CLI، لكنه يحفظ access token في `.env` ولا يملك refresh token lifecycle أو provider auth status أو تخزين OAuth منفصل. لذلك يجب ترحيله إلى `ProviderAuthSessionService` قبل اعتباره مزودا احترافيا مدعوما من الواجهة.
- توحيد مزودي TTS/STT/image/video داخل نفس سجل LLM. هذه المرحلة تخص مزودي LLM فقط.

## نطاق LLM وعلاقته بباقي الوسائط

لا تحفظ Sanad كل أنواع المزودين في جدول واحد مسطح يخلط LLM مع TTS وSTT والصور
والفيديو. لكل قدرة registry وحالة اختيار مستقلان، مع السماح بمشاركة credential
store عندما يستخدم الحساب نفسه في أكثر من قدرة.

قرار Sanad في هذه المرحلة:

- `ProviderRegistry` في هذه الخطة هو سجل مزودي LLM فقط.
- أي توسع لاحق إلى TTS/STT/image/video يجب أن يستخدم capability registry منفصلا أو طبقة قدرات فوق التخزين، لا أن يخلطها داخل active LLM provider.
- يمكن مشاركة credential store بين القدرات لاحقا إذا احتاج مزود واحد نفس token لأكثر من نوع، لكن حالة الاختيار الافتراضي والنموذج يجب أن تبقى مفصولة حسب القدرة.

## وضع ChatGPT / openai-codex الحالي في Sanad

المراجعة الحالية لكود Sanad توضح أن `openai-codex` ليس غائبا بالكامل، لكنه ليس مكتملا كنظام مصادقة مزود:

- `ProviderRegistry` يحتوي `openai-codex` مع `authType: oauth_external` و`apiMode: codex_responses`.
- `CodexResponsesAdapter` ينفذ طلبات `/responses` ويستخدم `Authorization: Bearer`.
- `setup.dart` و`provider_setup.dart` يقدمان CLI flow لاختيار device code أو إدخال session token يدويا.
- `runCodexDeviceCodeFlow` يحصل على access token من OpenAI device-code flow.

حدود التنفيذ الحالي:

- يتم حفظ token النهائي في `.env` كـ `CHATGPT_SESSION_TOKEN` و`LLM_API_KEY`.
- لا يحفظ refresh token ولا expiry ولا auth status.
- لا توجد دالة runtime موحدة لتجديد token قبل الاستخدام.
- لا توجد واجهة Flutter لإطلاق flow أو متابعة حالته.
- لا يوجد provider credential store منفصل لمصادقات OAuth.

قرار المرحلة:

- لا يتم حذف `openai-codex` ولا التعامل معه كإضافة جديدة من الصفر.
- يتم اعتباره legacy partial implementation يجب ترحيله إلى الخدمات الجديدة.
- بعد الترحيل يجب أن يحفظ access token وrefresh token وexpiry داخل provider credential store منفصل، وأن يعرّض حالة `authenticated`, `expired`, `relogin_required`, و`runtime_ready`.
- يجب أن يبقى `CodexResponsesAdapter` قابلا لإعادة الاستخدام إذا أثبتت الاختبارات أن عقد `/responses` الحالي صالح، لكن مصدر credential يجب أن ينتقل من `.env` الخام إلى credential resolver.

## مصدر الحقيقة وحالة المزودين

### Provider Registry

يبقى `sanad-agent/agent/lib/engine/adapters/provider_registry.dart` هو مصدر الحقيقة الأول لقائمة المزودين. يجب توسيع `ProviderProfile` ليشمل البيانات التي تحتاجها الواجهة بدون hardcoding:

- `id` أو `name`.
- `displayName`.
- `description`.
- `defaultBaseUrl`.
- `envApiKeyName`.
- `envModelName`.
- `envBaseUrlName`.
- `authType`.
- `authFlow`: مثل `api_key`, `device_code`, `loopback`, `external`, أو `custom_endpoint`.
- `docsUrl`.
- `apiMode`.
- `fallbackModels`.
- `supportsModelFetch`.
- `disconnectable`.

### Provider State

لا يكفي الاعتماد على `ACTIVE_PROVIDER` فقط. يجب أن يستطيع الوكيل معرفة كل المزودين الذين تم إعدادهم سابقا.

يتم احتساب حالة المزود من عدة مصادر:

- ملف `.env` الخاص بـ Sanad، للمفاتيح البسيطة، base URLs، والنماذج.
- ملف provider credential store منفصل داخل مساحة Sanad للمصادقات طويلة العمر مثل OAuth tokens، refresh tokens، expiry، وحالة جلسات المصادقة.
- الإعداد العام الحالي مثل `ACTIVE_PROVIDER`, `LLM_MODEL`, `LLM_BASE_URL`, وحقول المزود الخاصة.

يجب عدم استخدام ملف `auth.json` الحالي الخاص بـ `AuthManager` لتخزين أسرار مزودي LLM. هذا الملف مستخدم لمصادقة Sanad Gateway وهوية الجهاز مثل `device_token`, `hardware_id`, access token, وrefresh token. تخزين بيانات المزودين داخله قد يكسر ربط الجهاز أو يخلط صلاحيات Sanad مع صلاحيات أطراف ثالثة. التخزين الجديد يجب أن يكون منفصلا بوضوح، مثل `provider_auth.json` أو store مكافئ داخل مساحة Sanad مع صلاحيات قراءة/كتابة مقيدة للمستخدم.

قاعدة التخزين:

- API keys البسيطة يمكن أن تبقى في `.env` في المرحلة الأولى للحفاظ على التوافق.
- OAuth providers مثل `openai-codex`, `xai-oauth`, و`nous` يجب ألا تحفظ token طويل العمر في `.env`.
- `.env` يمكن أن يحتفظ فقط بالاختيار النشط والقيم غير السرية مثل `ACTIVE_PROVIDER`, `LLM_MODEL`, وbase URL عند الحاجة.
- credential resolver هو المسؤول عن استخراج secret الصحيح وقت التشغيل.

تكون النتيجة التي يراها العميل قائمة موحدة:

```json
{
  "providers": [
    {
      "id": "openrouter",
      "display_name": "OpenRouter",
      "configured": true,
      "authenticated": true,
      "is_current": true,
      "auth_type": "api_key",
      "auth_flow": "api_key",
      "models": ["model-a", "model-b"],
      "selected_model": "model-a",
      "key_env": "OPENROUTER_API_KEY"
    }
  ],
  "active_provider": "openrouter",
  "active_model": "model-a"
}
```

### الفرق بين configured وruntime ready

يجب فصل حالتين:

- `configured`: توجد بيانات إعداد يمكن استخدامها نظريا، مثل مفتاح أو token أو base URL.
- `runtime_ready`: الوكيل يستطيع حل المزود والنموذج الحاليين بنجاح، أو على الأقل يملك إعدادات كافية للبدء بدون خطأ `no_provider_configured`.

هذا الفصل مهم لأن مزودا قد يكون محفوظا في `.env` لكن النموذج غير محدد، أو token منتهي، أو active provider يشير لمزود غير موجود.

## خدمات الوكيل المطلوبة

تنقل المرحلة منطق `setup.dart` إلى خدمات قابلة لإعادة الاستخدام داخل الوكيل. المقترح:

- `ProviderCatalogService`: يبني قائمة المزودين من `ProviderRegistry`.
- `ProviderStateService`: يقرأ `.env` وprovider credential store المنفصل ويرجع configured/authenticated/current state.
- `ProviderCredentialStore`: يحفظ ويمسح مفاتيح API وbase URLs وقيم المزود الخاصة.
- `ProviderAuthSessionService`: يدير جلسات device code وloopback وexternal flows.
- `ProviderReadinessService`: ينفذ `setup_status` و`runtime_check`.
- `ModelOptionsService`: يجلب النماذج الحية عند الإمكان ويرجع fallback models عند الفشل.
- `ModelSelectionService`: يحفظ المزود والنموذج الافتراضيين ويحدث الحقول العامة والخاصة بالمزود.
- `ProviderCredentialResolver`: يرجع credential صالحة وقت التشغيل، ويجدد OAuth token إذا اقتربت من الانتهاء، أو يرجع `relogin_required` عند الفشل.

يجب أن يستخدم CLI والواجهة هذه الخدمات نفسها. لا يجوز أن يبقى منطق المصادقة محصورا داخل prompt تفاعلي في `setup.dart`.

## عقود socket/canonical protocol

تضاف أوامر جديدة إلى طبقة البروتوكول القابلة للنقل بحيث تعمل عبر local gateway وعبر Sanad Gateway من البداية. يجب أن تكون الأوامر مرتبطة بالجهاز أو الوكيل المختار في الواجهة، لأن المستخدم قد يختار وكيلا محليا أو وكيلا بعيدا مسجلا في حسابه.

### Readiness

- `provider.setup_status`
  - يرجع هل يوجد مزود مهيأ، المزود الحالي، النموذج الحالي، وسبب عدم الجاهزية إن وجد.

- `provider.runtime_check`
  - يتحقق من قدرة runtime على حل المزود والنموذج.
  - يجب أن يكون فحصا خفيفا قدر الإمكان، ولا يحمل نموذج محلي ثقيل بلا داع.

### Provider Listing

- `provider.list`
  - يرجع كل المزودين المدعومين، سواء تم إعدادهم أم لا.
  - يستخدمه onboarding وsettings.

- `provider.list_configured`
  - يرجع المزودين الذين يملكون إعدادات محفوظة فقط.
  - يستخدم لاحقا في settings لاختيار مزود موجود وتغيير النموذج.

### API Key and Custom Endpoint

- `provider.save_api_key`
  - يحفظ مفتاح مزود API key.
  - لا يجب أن يجعل live network validation مانعا دائما للحفظ؛ يمكن إرجاع تحذير إن فشل الفحص.

- `provider.save_custom_endpoint`
  - يحفظ base URL ونموذج ومفتاح اختياري لمزود مخصص أو محلي.

- `provider.remove`
  - يمسح إعدادات مزود محدد دون حذف إعدادات المزودين الآخرين.

### OAuth Sessions

- `provider.auth.start`
  - يبدأ تدفق المصادقة لمزود محدد.
  - يرجع `session_id`, `flow`, وروابط أو أكواد المستخدم حسب نوع التدفق.

- `provider.auth.poll`
  - يرجع حالة جلسة device code أو loopback: `pending`, `approved`, `expired`, أو `error`.

- `provider.auth.submit`
  - يستقبل كود يدوي عند الحاجة.

- `provider.auth.cancel`
  - يغلق الجلسة وينظف أي listener أو timer مرتبط بها.

- `provider.auth.status`
  - يرجع حالة مصادقة مزود OAuth محدد: `authenticated`, `expired`, `refreshing`, `relogin_required`, أو `missing`.
  - يستخدمه onboarding وsettings قبل عرض زر sign in أو sign out.

بالنسبة إلى `openai-codex` تحديدا، يجب نقل منطق `runCodexDeviceCodeFlow` الحالي من helper الطرفية إلى service يرجع access token وrefresh token ومعلومات expiry بدل access token فقط.

### Model Selection

- `model.options`
  - يرجع مزودين مع النماذج المتاحة، ويضع `authenticated`, `auth_type`, `key_env`, و`warning` للمزودين غير المجهزين.

- `model.recommended_default`
  - يرجع النموذج المقترح لمزود محدد.

- `model.set_default`
  - يحفظ المزود والنموذج الافتراضيين.
  - يحدث الحقول العامة مثل `ACTIVE_PROVIDER`, `LLM_MODEL`, `LLM_BASE_URL`, `LLM_API_KEY` عند الحاجة، وكذلك حقول المزود الخاصة.

## واجهة Flutter في المرحلة الأولى

### Onboarding Gate

يتم تعديل onboarding بحيث لا يعتبر اتصال الوكيل المحلي وحده كافيا لتجربة محادثة محلية على desktop. الشرط في مسار desktop المحلي:

```text
local daemon connected + provider.runtime_check ready
```

لكن هذا الشرط لا يعني أن web/mobile يحتاجان local daemon. في web/mobile، وفي desktop عند اختيار جهاز من Sanad Gateway، يتم تقييم `provider.runtime_check` على الجهاز المختار عبر مسار الاتصال السحابي الحالي. إذا كان الجهاز المختار متصلا لكن لا يوجد provider جاهز، تظهر واجهة إعداد المزود لذلك الجهاز بدل فتح تجربة محادثة تفشل لاحقا.

إذن البوابة ليست "local daemon أو لا شيء"، بل:

- desktop onboarding المحلي: يحتاج local daemon ثم provider runtime جاهز على نفس الوكيل.
- اختيار جهاز مسجل عبر Sanad Gateway: يحتاج الجهاز المختار أن يرد بحالة provider جاهزة، بغض النظر عن وجود daemon محلي على جهاز الواجهة.
- web/mobile: يحافظان على منطق الاتصال السحابي الحالي، ويفحصان جاهزية المزود على الجهاز المختار فقط.

### Provider Setup UI

تبنى واجهة جديدة داخل `sanad-agent/client` تكون مستقلة وقابلة لإعادة الاستخدام لاحقا في settings. لا يجب ربطها منطقيا بشاشة onboarding فقط.

المكونات المقترحة:

- `ProviderSetupController` أو bloc/cubit مسؤول عن أوامر البروتوكول.
- `ProviderPickerView` لعرض المزودين.
- `ApiKeyProviderForm` لإدخال API key.
- `CustomEndpointForm` لإدخال base URL ومفتاح اختياري.
- `DeviceCodeAuthView` لعرض user code وفتح المتصفح والانتظار.
- `LoopbackAuthView` لعرض انتظار المتصفح.
- `ModelSelectionView` لاختيار النموذج بعد نجاح المزود.

كل النصوص داخل الواجهة يجب أن تكون بالإنجليزية حسب عقد `sanad-agent/client/AGENTS.md`.

تفاصيل واجهة API key:

- تعرض حقل المفتاح وحقول base URL/model عند الحاجة حسب `ProviderProfile`.
- تعرض زر `Get a key` عندما يحتوي المزود على `docsUrl` أو `signupUrl`.
- يفتح الزر صفحة المزود المناسبة، مثل صفحة مفاتيح OpenRouter، ولا تكون الروابط hardcoded في Flutter بل قادمة من catalog.

تفاصيل واجهة device code:

- تظهر كحالة واضحة: عنوان `Sign in with {provider}`، رسالة أن المتصفح فتح صفحة التحقق، user code كبير ومقسم، زر `Re-open verification page`، حالة انتظار authorization، وزر `Cancel`.
- تستخدم `provider.auth.start` للحصول على `verification_uri`, `verification_uri_complete` إن وجد، و`user_code`.
- تستخدم `provider.auth.poll` حتى النجاح أو الانتهاء أو الإلغاء.
- بعد النجاح تنتقل إلى اختيار النموذج داخل المزود.

### Flow في onboarding

```text
Start app
  -> resolve connection mode and selected agent
  -> if desktop local onboarding: connect local daemon
  -> provider.runtime_check on selected agent
  -> if ready: home
  -> if not ready: provider picker
  -> configure/authenticate provider
  -> fetch model options for selected provider
  -> choose or confirm model
  -> model.set_default
  -> provider.runtime_check
  -> home
```

### قابلية إعادة الاستخدام في Settings

مع أن المرحلة الأولى تستخدم الواجهة في onboarding فقط، يجب تصميمها بحيث تستخدم لاحقا في settings بدون إعادة كتابة:

- تعرض كل المزودين.
- تعرض المزودين المجهزين.
- تسمح بتغيير active provider.
- تسمح بتغيير default model داخل المزود.
- تسمح بإضافة مزود جديد.
- تسمح بإزالة مزود بدون التأثير على المزودين الآخرين.

## CLI

يتم تحديث CLI ليستخدم خدمات الوكيل نفسها:

- setup wizard يصبح واجهة طرفية فوق `ProviderCatalogService`, `ProviderAuthSessionService`, و`ModelSelectionService`.
- auth add/remove/list/status subcommands تصبح واجهات فوق نفس التخزين والحالة.
- اختيار النموذج من الطرفية يستخدم `ModelOptionsService` و`ModelSelectionService`.

الهدف أن أي مزود يضاف إلى `ProviderRegistry` ويملك flow واضحا يظهر في CLI والواجهة دون نسخ منطق جديد.

### installer handoff

التثبيت عبر `landing-page/public/install.sh` يثبت binary، يحفظ token الربط في `auth.json` عند تمريره، ثم يسجل خدمة الخلفية. المراجعة الحالية توضح أنه لا يطلق إعداد مزود LLM ولا يوجه المستخدم فعليا إلى wizard المزود بعد انتهاء التثبيت.

تشغيل الخدمة لا يمنع إدخال بيانات المزود في نفس الطرفية لأن `service install` يسجل daemon كخدمة خلفية: على macOS يكتب stdout/stderr إلى ملفات logs داخل مساحة Sanad، وعلى Linux يستخدم systemd user service مع `StandardOutput` و`StandardError` موجهين إلى ملفات logs. لذلك يمكن أن يبدأ daemon أولا، ثم يعرض installer سؤال إعداد المزود الاختياري في نفس جلسة الطرفية.

المطلوب في هذه المرحلة:

- بعد نجاح تثبيت الخدمة وربط الجهاز، يجب أن يوجه CLI/installer المستخدم إلى إعداد المزود من الطرفية، مع السماح بتخطي الخطوة.
- إذا تخطى المستخدم إعداد المزود، يجب ألا يعتبر ذلك فشلا في ربط الجهاز.
- إذا اختار المستخدم إعداد المزود من CLI بعد تشغيل الخدمة، يجب أن يحدث الوكيل إعداداته بدون الحاجة لإعادة تثبيت الخدمة. يمكن تحقيق ذلك إما بإعادة تحميل config داخل runtime أو بإعادة تشغيل الخدمة بعد حفظ إعداد المزود.
- يجب ألا يعرض installer tail مباشر للوجات daemon أثناء سؤال إعداد المزود، حتى لا تختلط logs مع prompts.
- عند ظهور الجهاز لاحقا في الواجهة واختياره، يجب أن تعرف الواجهة من `provider.setup_status` أو `provider.runtime_check` أن هذا الوكيل لا يملك مزودا جاهزا وتعرض واجهة إعداد المزود عبر نفس أوامر socket/canonical protocol.

## التخزين والأمان

- تبقى `.env` مناسبة للمفاتيح البسيطة، base URLs، والنموذج الافتراضي.
- تحفظ OAuth tokens وrefresh tokens وexpiry داخل provider credential store منفصل عن `auth.json` الخاص بـ Sanad Gateway، وليس داخل سجلات أو stdout.
- يجب ألا تطبع الواجهة أو CLI أي secret كامل.
- إزالة مزود يجب أن تمسح مفاتيحه وحالته الخاصة فقط.
- تغيير active provider لا يجب أن يحذف مزودين آخرين.
- loopback listener يجب أن يغلق عند النجاح أو الفشل أو الإلغاء.

## التغييرات على الوثائق

عند التنفيذ يجب تحديث:

- `sanad-agent/agent/AGENTS.md` لإضافة عقد أن الوكيل يملك Provider Runtime.
- `sanad-agent/client/AGENTS.md` أو أقرب عقد داخل `client/lib/features` لتثبيت أن الواجهة لا تملك سجل مزودين hardcoded.
- وثيقة تقنية جديدة أو محدثة تحت `sanad-agent/docs/technical/` تشرح provider protocol socket commands وحالة التخزين.
- `sanad-agent/docs/llms.txt` إذا أضيفت وثيقة تقنية جديدة.

## مراحل التنفيذ

### المرحلة A: Agent Provider Runtime

- توسيع `ProviderProfile`.
- إنشاء خدمات catalog/state/credential/readiness/model selection.
- إضافة provider credential store منفصل لمصادقات OAuth، بدون استخدام `auth.json` الخاص بـ Sanad Gateway.
- نقل منطق device code الحالي من `setup_helpers.dart` إلى flow service قابل لإعادة الاستخدام.
- نقل `openai-codex` من حفظ `CHATGPT_SESSION_TOKEN` في `.env` إلى credential resolver يحفظ access/refresh token ويفحص expiry ويطلب إعادة login عند الحاجة.

### المرحلة B: Socket Protocol

- إضافة أوامر provider/model إلى `SanadProtocolBridge` أو طبقة protocol المناسبة.
- ضمان أن كل response يحمل `request_id`.
- إضافة اختبارات unit لعقود serialization والاستجابات الأساسية.

### المرحلة C: Onboarding UI

- إضافة provider setup UI باللغة الإنجليزية.
- ربط onboarding gate بـ `provider.runtime_check`.
- تنفيذ API key/custom endpoint/device code/loopback states.
- إضافة model selection بعد نجاح المزود.

### المرحلة D: CLI Reuse

- تحديث setup wizard ليستخدم الخدمات الجديدة.
- إضافة list/status/remove flows للمزودين.
- التأكد أن CLI والواجهة يريان نفس المزودين ونفس active provider.

### المرحلة E: Settings Reuse Preparation

- فصل controller/state الخاص بإعداد المزود عن onboarding screen.
- إضافة public entry point يمكن استدعاؤه لاحقا من settings.
- تأجيل بناء صفحة settings الكاملة إلى مرحلة لاحقة.

## معايير القبول

1. لا يدخل المستخدم الشاشة الرئيسية من onboarding المحلي إلا إذا كان الوكيل متصلا و`provider.runtime_check` جاهزا.
2. يستطيع المستخدم إضافة مزود API key من الواجهة ثم اختيار نموذج وحفظه.
3. يستطيع المستخدم إكمال تدفق device code لمزود مدعوم من الواجهة.
4. يستطيع الوكيل إرجاع كل المزودين وكل المزودين المجهزين عبر socket commands.
5. يستطيع المستخدم إعداد أكثر من مزود، ثم اختيار active provider/model دون حذف إعدادات المزودين الآخرين.
6. يستخدم CLI والواجهة نفس خدمات الوكيل لتخزين وقراءة حالة المزودين.
7. لا توجد قائمة مزودين hardcoded في Flutter باستثناء ترتيب أو presentation hints غير حاكمة.
8. عند اختيار جهاز مسجل عبر Sanad Gateway ولا يملك مزودا جاهزا، تعرض الواجهة إعداد المزود لذلك الجهاز عبر نفس أوامر البروتوكول، دون اشتراط local daemon على جهاز الواجهة.
9. `openai-codex` لا يعتبر جاهزا لمجرد وجود `CHATGPT_SESSION_TOKEN` قديم في `.env`; يجب أن يمر عبر credential resolver ويعرض `relogin_required` إذا كان OAuth token ناقصا أو منتهيا.
10. لا توجد روابط مطلقة في الوثائق أو config.

## خطة التحقق

- اختبارات وحدة لـ `ProviderStateService` تغطي:
  - مزود API key محفوظ في `.env`.
  - أكثر من مزود محفوظ.
  - active provider مختلف عن مزود محفوظ.
  - مزود OAuth محفوظ في provider credential store المنفصل.
- اختبارات وحدة لـ readiness:
  - لا يوجد مزود.
  - مزود موجود بدون نموذج.
  - مزود جاهز.
  - configured true لكن runtime check يفشل.
- اختبارات وحدة لـ `openai-codex` migration:
  - device-code flow يرجع access token وrefresh token ويحفظهما في provider credential store.
  - credential resolver يجدد token المنتهي أو يرجع `relogin_required`.
  - وجود `CHATGPT_SESSION_TOKEN` قديم في `.env` لا يكفي وحده لاعتبار المزود OAuth جاهزا.
- اختبارات بروتوكول socket:
  - `provider.list`
  - `provider.list_configured`
  - `provider.save_api_key`
  - `model.options`
  - `model.set_default`
- اختبار onboarding widget أو integration:
  - local daemon connected لكن provider غير جاهز يبقي المستخدم في provider setup.
  - بعد حفظ provider/model ينتقل المستخدم إلى home.
- اختبار تنظيف OAuth session:
  - الإلغاء يغلق session.
  - انتهاء التدفق يغلق loopback listener.

---

## Checklist التنفيذ

### المرحلة A: Agent Provider Runtime

- [x] A1. توسيع `ProviderProfile` بحقول: `authFlow`, `docsUrl`, `supportsModelFetch`, `disconnectable`.
- [x] A2. إنشاء `ProviderCredentialStore` منفصل عن `auth.json` (يحفظ OAuth tokens/refresh/expiry).
- [x] A3. إنشاء `ProviderCatalogService` (يبني قائمة المزودين من Registry).
- [x] A4. إنشاء `ProviderStateService` (يقرأ `.env` + credential store ويرجع configured/authenticated/current).
- [x] A5. إنشاء `ProviderCredentialResolver` (يحل credential وقت التشغيل ويجدد OAuth token).
- [x] A6. إنشاء `ProviderAuthSessionService` (يرحّل `runCodexDeviceCodeFlow` من setup_helpers).
- [x] A7. إنشاء `ProviderReadinessService` (`setup_status` + `runtime_check`).
- [x] A8. إنشاء `ModelOptionsService` و`ModelSelectionService` و`ProviderConfigService`.
- [x] A9. تسجيل كل الخدمات في `di.dart`.
- [x] A10. ترحيل `openai-codex` من `.env` إلى credential resolver.
- [x] A11. اختبارات وحدة لـ `ProviderStateService`.
- [x] A12. اختبارات وحدة لـ readiness.
- [x] A13. اختبارات وحدة لترحيل `openai-codex`.

### المرحلة B: Socket Protocol

- [x] B1. إضافة canonical event types لأوامر provider/model.
- [x] B2. إضافة أوامر readiness: `provider.setup_status`, `provider.runtime_check`.
- [x] B3. إضافة أوامر listing: `provider.list`, `provider.list_configured`.
- [x] B4. إضافة أوامر API key/endpoint: `provider.save_api_key`, `provider.save_custom_endpoint`, `provider.remove`.
- [x] B5. إضافة أوامر OAuth: `provider.auth.start`, `provider.auth.poll`, `provider.auth.submit`, `provider.auth.cancel`, `provider.auth.status`.
- [x] B6. إضافة أوامر model: `model.options`, `model.recommended_default`, `model.set_default`.
- [x] B7. ضمان `request_id` في كل response.
- [x] B8. اختبارات وحدة لعقود serialization والاستجابات الأساسية.

### المرحلة C: Onboarding UI

- [x] C1. إنشاء `ProviderSetupController` (cubit/bloc).
- [x] C2. إنشاء `ProviderPickerView`.
- [x] C3. إنشاء `ApiKeyProviderForm`.
- [x] C4. إنشاء `CustomEndpointForm`.
- [x] C5. إنشاء `DeviceCodeAuthView`.
- [x] C6. إنشاء `LoopbackAuthView`.
- [x] C7. إنشاء `ModelSelectionView`.
- [x] C8. ربط onboarding gate بـ `provider.runtime_check`.
- [x] C9. اختبار onboarding widget/integration.

### المرحلة D: CLI Reuse

- [x] D1. تحديث setup wizard ليستخدم الخدمات الجديدة.
- [x] D2. إضافة list/status/remove flows للمزودين.
- [x] D3. التأكد أن CLI والواجهة يريان نفس المزودين.

### المرحلة E: Settings Reuse Preparation

- [x] E1. فصل controller/state عن onboarding screen.
- [x] E2. إضافة public entry point قابل لإعادة الاستخدام من settings.

### الوثائق

- [x] DOC1. تحديث `sanad-agent/agent/AGENTS.md` (Provider Runtime).
- [x] DOC2. تحديث `sanad-agent/client/AGENTS.md` (no hardcoded providers).
- [x] DOC3. وثيقة تقنية تحت `sanad-agent/docs/technical/` لشرح provider protocol.
- [x] DOC4. تحديث `sanad-agent/docs/llms.txt`.
