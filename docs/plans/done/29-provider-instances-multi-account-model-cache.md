---
title: "المرحلة التاسعة والعشرون: نسخ المزودين متعددة الحسابات وكاش النماذج الدائم"
description: "فصل قوالب المزودين عن النسخ المسماة، دعم عدة اعتمادات وOAuth لكل نوع، إضافة مزودات OpenAI/Anthropic المتوافقة، وتسريع محدد النماذج بكاش دائم وآخر الاختيارات."
phase: 29
depends_on:
  - "docs/technical/provider_protocol.md"
  - "docs/technical/agent_database_schema.md"
  - "docs/plans/done_not_documented/19-provider-setup-gate-and-overlay.md"
  - "docs/plans/done_not_documented/24-live-provider-reload-and-dynamic-model-dropdown.md"
status: "in-progress"
---

# خطة المرحلة التاسعة والعشرين: نسخ المزودين متعددة الحسابات وكاش النماذج الدائم

## 1. الملخص التنفيذي

تنقل هذه المرحلة Provider Runtime من نموذج **نسخة ثابتة واحدة لكل نوع مزود**
إلى نموذج يفصل بين:

1. **`ProviderTemplate`:** قالب ثابت يصف البروتوكول وطرق المصادقة والعنوان
   الافتراضي وقدرات جلب النماذج.
2. **`ProviderInstance`:** اتصال أنشأه المستخدم وله UUID ثابت، اسم قابل
   للتغيير، إعدادات واعتماد ونموذج افتراضي مستقلون.

يستطيع المستخدم إنشاء `OpenAI Work` و`OpenAI Personal` من القالب نفسه، أو
ربط أكثر من حساب OAuth من النوع نفسه، أو إنشاء `Kiro Gateway` كبوابة
OpenAI-compatible أو Anthropic-compatible دون hardcode لاسم Kiro.

تضيف المرحلة كاشًا دائمًا لآخر قائمة نماذج ناجحة لكل instance. يفتح Model
Picker بالبيانات المخزنة فورًا ثم يحدثها في الخلفية، ويعرض آخر خمسة اختيارات
بصيغة `اسم النسخة / اسم النموذج`. تستخدم الرسائل UUID داخليًا، لذلك لا تكسر
إعادة التسمية التوجيه أو الجلسات.

تعتمد الخطة على المرحلتين 19 و24، وتستبدل معنى `provider_id` الثابت في مسار
الإعداد والتوجيه بـ`provider_instance_id`. لا تتضمن ترحيل إعدادات `.env`
القديمة لأن المشروع لم يصدر إنتاجيًا، ولا تبقي مصدرَي حقيقة بعد الإغلاق.

## 2. الوضع الحالي والمشكلة

- يربط `ProviderRegistry` كل نوع بأسماء ثابتة مثل `OPENAI_API_KEY`؛ المفتاح
  الثاني يستبدل الأول ولا توجد أسماء يختارها المستخدم.
- يعني `providerId` حاليًا القالب والإعداد والاعتماد وهوية التوجيه معًا.
- يسقط المزود غير المعروف إلى OpenAI، فتضيع هويته ولا يعمل Custom Anthropic
  بصورة صحيحة.
- OAuth مفهرس بنوع المزود، لذلك لا يضمن عدة حسابات مستقلة من النوع نفسه.
- لا يميز عقد التعديل صراحة بين الاحتفاظ بالسر واستبداله وحذفه.
- قد ينتظر Model Picker جلب عدة قوائم، ويعرض presets فقط أثناء الانتظار.
- لا توجد قائمة Recent، وقد يظهر ناشر النموذج بدل اسم اتصال المستخدم.
- يبني Anthropic مسارات models/messages بقواعد مختلفة قد تنتج `/v1/v1` أو
  تطلب `/models` من root غير الصحيح.

## 3. القرارات المعمارية الملزمة

1. يبقى كتالوج القوالب ثابتًا في الوكيل؛ النسخ وحدها ديناميكية.
2. UUID النسخة هو الهوية الدائمة ولا يُشتق من `displayName`.
3. تدعم البنية عددًا غير محدود من النسخ لكل قالب، بما فيها OAuth.
4. كل OAuth transaction/refresh/credential مفهرس بـinstance ID لا template ID.
5. connector لا يدعي دعم OAuth قبل وجود تدفق فعلي واختباره.
6. metadata والكاش والحديثة في SQLite؛ الأسرار خلف `SecretStore` مستقل.
7. التنفيذ الأول لـSecretStore ملف محلي محمي، ذري ومقفول بين العمليات.
8. التعديل يستخدم `keep | replace | remove`؛ الفراغ لا يعني الحذف.
9. لا يعاد السر الحقيقي إلى Client أو CLI بعد حفظه.
10. instance غير موجودة تفشل بوضوح دون fallback إلى OpenAI.
11. OpenAI-compatible وAnthropic-compatible بروتوكولان صريحان لا heuristics.
12. العرض دائمًا `ProviderInstance.displayName / modelId`، والتوجيه بالـUUID.
13. آخر نتيجة نماذج ناجحة لا تستبدل بفشل أو قائمة فارغة.
14. Rename لا يبطل الاعتماد أو الكاش أو الجلسات.
15. تغيير protocol/Base URL/credential يغير revision الكاش والـadapter.
16. الوكيل مصدر الحقيقة؛ Client وCLI يستخدمان العقود والخدمات نفسها.

## 4. الأهداف

1. CRUD كامل لعدة instances من القالب نفسه مع Rename وDefault.
2. عدة حسابات OAuth مستقلة من النوع نفسه دون overwrite.
3. قالب Custom فارغ يدعم OpenAI-compatible وAnthropic-compatible.
4. اعتماد مستقل وآمن لكل instance دون كشفه للعملاء أو السجلات.
5. تعديل instance دون طلب المفتاح أو OAuth مجددًا ما لم يطلب المستخدم ذلك.
6. adapter وcredential وتوجيه مستقلون لكل instance ولكل جلسة.
7. فتح Model Picker فورًا من كاش دائم ثم تحديثه في الخلفية.
8. Recent Selected بآخر خمسة اختيارات عبر Client وCLI.
9. اسم instance الذي اختاره المستخدم ظاهر في المحدد والحالة والمحادثة.
10. URL normalization موحد لمسارات models/messages للبروتوكولين.
11. أهداف واختبارات وDoD قابلة للمراجعة والتحقق الآلي.

## 5. خارج النطاق

- ترحيل إعدادات المزودين القديمة من `.env` أو `provider_auth.json`.
- compatibility layer دائم بين النظامين القديم والجديد.
- Custom Headers أو query parameters أو تخصيص paths من الواجهة.
- بروتوكولات مخصصة غير OpenAI-compatible وAnthropic-compatible.
- مزامنة الأسرار بين الأجهزة أو رفعها إلى backend.
- credential pooling/rotation/load balancing التلقائي.
- استيراد حسابات من تطبيقات خارجية.
- جعل OS Keychain شرطًا في هذه المرحلة.
- بناء OAuth connector لمزود لا يملكه حاليًا.

## 6. تجربة المستخدم المستهدفة

### 6.1 Client: الإضافة والإدارة

تعرض Settings قائمة `Your Providers` كبطاقات instances، ثم زر `Add provider`.
تحتوي البطاقة الاسم والقالب/البروتوكول وحالة الاعتماد والنموذج الافتراضي وآخر
تحديث للنماذج وأفعال Edit/Rename/Set default/Remove.

تعرض كل بطاقة شارة مستقلة لطريقة المصادقة الفعلية للنسخة:

- `Account` لتدفقات OAuth/device-code/loopback/subscription.
- `API Key` لكل اتصال يستخدم تدفق API endpoint، سواء كان المفتاح مطلوبًا أو
  اختياريًا. عندما تُحفظ نسخة اختيارية دون مفتاح تعرض البطاقة `No API key`
  كحالة فرعية مفهومة، ولا تنشئ فئة مصادقة ثالثة.

لا تُخلط شارة الطريقة مع حالة الاتصال؛ يمكن أن تعرض البطاقة مثلًا `Account`
مع `Connected` أو `Needs sign-in`. أعلى القائمة توجد tabs:

```text
All | Accounts | API Keys
```

يعتمد filter على `ProviderInstance.authMethod` لا اسم القالب. الترتيب الافتراضي
داخل `All` هو Accounts أولًا ثم API Keys؛ وداخل كل فئة تظهر الجاهزة قبل غير
الجاهزة ثم يرتب الاسم ترتيبًا ثابتًا. لا يغير الترتيب default instance أو
التوجيه الفعلي.

عند الإضافة:

1. تأتي القوالب من الوكيل دون hardcode في Client.
2. يقترح اسم قابل للتعديل مثل `OpenAI` أو `OpenAI 2`.
3. قالب API Key يطلب المفتاح إذا كان `apiKeyRequirement=required`، ويسمح بتركه
   فارغًا إذا كان `optional`، ثم يختبر الاتصال في الحالتين.
4. قالب OAuth ينشئ UUID أولًا ثم يبدأ تسجيل دخول مربوطًا به.
5. يختار المستخدم نموذجًا حيًا أو يدخله يدويًا عند تعذر discovery.
6. تحفظ النسخة دون تعديل أي instance أخرى من القالب نفسه.

قالب `Custom Provider` يعرض في هذه المرحلة: Connection name، protocol، Base
URL، API Key اختياري، Fetch models أو model يدوي، Test وSave.

### 6.2 التعديل دون إعادة الاعتماد

يعرض API Key كملخص مثل `sk-p****9X2A` فقط، ولا يملأ TextField بالسر.

- Save الافتراضي يرسل `credential_action=keep`.
- `Replace API key` يفتح حقلًا فارغًا ويرسل `replace` بقيمة جديدة.
- `Remove credential` فعل مستقل وتحذيري يرسل `remove`.
- Rename أو تغيير model لا يغير السر.
- تغيير Base URL لا يطلب إعادة إدخال السر، لكنه يعيد اختبار الاتصال ويبطل
  adapter/cache المرتبطين بعد الحفظ.
- OAuth يعرض account label/status وReconnect/Disconnect ولا يعرض token hint.
- لا يبدأ OAuth مجددًا إلا بطلب Reconnect أو حالة `relogin_required`.

### 6.3 Model Picker

عند الفتح يعرض الوكيل cached snapshot فورًا، وفي أعلاه:

```text
Recently Selected
Kiro Gateway / claude-sonnet-5
OpenRouter Work / kimi-k2.6
```

ثم تظهر مجموعات النماذج باسم كل instance. يبدأ refresh في الخلفية بحد توازٍ
مركزي، ويدفع حدثًا لكل مجموعة تغيرت. لا تغلق النافذة ولا تفقد الاختيار. عند
الفشل تبقى القائمة السابقة ويظهر warning غير حاجب. عند أول استخدام بلا cache
تظهر fallback models أو الإدخال اليدوي.

### 6.4 CLI

يوفر CLI List/Add/Edit/Rename/Remove/Set default وOAuth per instance والقالب
المخصص. أثناء edit يعرض masked hint ويعني Enter الاحتفاظ بالقيمة. يعرض cached
models وRecent Selected ويستخدم الخدمات نفسها دون كتابة إعدادات instances
مباشرة إلى `.env`.

## 7. نموذج المجال والتخزين

### 7.1 `ProviderTemplate`

يتطور `ProviderProfile` أو يغلّف كقالب بالحقول:

```text
id, displayName, description, protocol, authMethods[]
defaultBaseUrl, internalDefaultHeaders, fallbackModels[]
apiKeyRequirement: required | optional
supportsModelFetch, supportsMultipleInstances, disconnectable, docsUrl
```

لا يحتوي القالب secret أو selected model أو حالة مستخدم. يبقى
`ProviderRegistry`/`ProviderCatalogService` مصدر القوالب الثابتة. يضاف قالب
`custom` يطلب protocol عند إنشاء النسخة؛ لا نضيف نوعين ثابتين باسم
`custom-openai` و`custom-anthropic`. القوالب الرسمية التي تشترط المفتاح تستخدم
`required`، بينما local engines وCustom Provider تستخدم `optional`.

### 7.2 `ProviderInstance`

```text
id: UUID
templateId, displayName, protocol, authMethod, baseUrl, defaultModel
status: draft | ready | needs_auth | error
isDefault, configRevision, credentialRevision, createdAt, updatedAt
```

القواعد:

- الاسم مطلوب بعد trim ومميز case-insensitively داخل runtime.
- `templateId=custom` يتطلب protocol وBase URL صريحين.
- قالب جاهز يرث protocol والعنوان ويمكنه override المسموح.
- توجد instance افتراضية واحدة بحد أقصى.
- حذف الافتراضية يطلب بديلًا أو يترك readiness غير جاهزة بوضوح.

### 7.3 جداول SQLite

يضاف `ProviderInstanceRepository` وجداول:

- `provider_instances`: كل metadata والـrevisions دون أسرار.
- `provider_model_cache`: instance ID، cache key، models JSON، fetchedAt،
  source، endpoint fingerprint، config/credential revisions وlast error.
- `recent_model_selections`: instance ID، model ID، selectedAt، مع uniqueness
  للزوج وحذف تابع عند حذف instance.

تعيد recent query أحدث خمسة بعد join مع الاسم الحالي، لذلك ينعكس Rename فورًا.

### 7.4 `SecretStore`

العقد الداخلي:

```text
read(instanceId)
write(instanceId, secretRecord)
summary(instanceId)
remove(instanceId)
listIds()
```

يحمل `SecretRecord` API key أو OAuth tokens/expiry/scope. لا يدمج أسرار Sanad
device identity. يحمل الملخص فقط: configured، auth type/status، masked hint
لمفتاح API، account label، expiry وreloginRequired.

`SecureFileSecretStore` الأول يحقق:

- ملف منفصل داخل Sanad home، مفهرس بـinstance UUID.
- parent/file owner-only حيث يدعم النظام، وWindows ACL للمستخدم بدل skip.
- temp file آمن، flush، atomic replace وقفل عابر للعمليات.
- عدم تسجيل raw content أو exception تكشفه.
- write/remove ذرية لا تفسد السجلات الأخرى.

لا ندعي encryption-at-rest؛ يسمح التجريد بإضافة OS vault لاحقًا.

### 7.5 عقد تعديل الاعتماد

```text
credentialAction: keep | replace | remove
newCredential: present only when action=replace
```

`keep` هو الافتراضي، و`replace` بلا قيمة يرفض، و`remove` لا يُستنتج من null أو
empty string. OAuth يستخدم reconnect/disconnect صريحين. لا يدخل السر DTOs أو
cache keys أو equality/debug strings أو events.

## 8. خدمات Provider Runtime وOAuth

### 8.1 الخدمات

- `ProviderInstanceRepository`: CRUD والمعاملات والـdefault والبحث بالـUUID.
- `ProviderInstanceService`: validation، اقتراح الاسم، draft/ready وRename.
- `ProviderCredentialService`: keep/replace/remove وsummaries وrevisions.
- `ProviderAuthSessionService`: start/poll/submit/cancel/reconnect per instance.
- `ProviderReadinessService`: default instance + credential + endpoint + model.

تتحقق readiness من `apiKeyRequirement`: غياب المفتاح يفشل القالب `required`،
ولا يفشل القالب `optional` إذا نجح endpoint/model resolution.

تُعاد صياغة `ProviderCredentialStore` و`ProviderCredentialResolver` حول
instance ID، ثم يحلان template/auth connector. يولد UUID قبل جمع المفتاح أو
OAuth. تبقى النسخة الفاشلة draft/needs_auth ويمكن استكمالها أو حذفها.

### 8.2 تعدد OAuth

- كل start يحتاج `provider_instance_id`.
- pending session يحمل instance ID وtransaction/state عشوائيين.
- يمكن تدفقان متوازيان لنسختين من القالب نفسه.
- نجاح/فشل/refresh/reconnect/disconnect لنسخة لا يغير الأخرى.
- Reconnect يستبدل اعتماد النسخة المستهدفة فقط بعد نجاح المصادقة.
- القالب يعرض auth methods تصريحية تستخدمها واجهتا Client وCLI.

## 9. التوجيه والـadapters

### 9.1 `RouteSignature`

```text
providerInstanceId, templateId, protocol, normalizedBaseUrl
modelId, configRevision, credentialRevision
```

لا يحمل signature السر. النسخ المختلفة لا تشترك في adapter حتى لو كانت من
القالب نفسه.

### 9.2 `AgentRuntimeService`

1. يستقبل UUID من turn أو session default.
2. يجلب instance؛ المفقودة خطأ واضح.
3. يحل template وcredential بالـinstance ID.
4. يبني adapter حسب protocol الصريح.
5. يخزنه بالـRouteSignature.
6. يبطل instance واحدة بعد تعديلها دون مساس بالبقية.

يحذف fallback الذي يحول unknown ID إلى OpenAI.

### 9.3 الجلسات والرسائل

- يصبح الحقل الدائم `provider_instance_id`.
- `think` و`steer` يحملانه مع model ID.
- تحفظ الجلسة آخر instance/model/thinking mode.
- Rename لا يعدل الجلسات؛ العرض يحل الاسم الحالي من repository.
- instance محذوفة تعرض unavailable وتطلب بديلًا دون fallback صامت.

## 10. URL normalization واكتشاف النماذج

### 10.1 `ProviderEndpointResolver`

تطبع خدمة مركزية scheme/host/trailing slash وتبني endpoint حسب protocol:

- OpenAI-compatible يقبل root أو `/v1` ويبني `/models` وchat completions دون
  slash أو version مكررين.
- Anthropic-compatible يبني `/v1/models` و`/v1/messages` من root، أو
  `/models` و`/messages` عندما base المطبّع ينتهي بـ`/v1`.
- Anthropic يستخدم `x-api-key` و`anthropic-version` القياسيين.

لا تبقى concatenation لمسارات provider URL موزعة بين adapters والخدمات.

### 10.2 اختبار الاتصال

يختبر draft instance دون جعلها default، ويميز invalid URL وauth failure و
unsupported protocol وmodel discovery failure. فشل discovery يسمح بإدخال
model يدوي ولا يعني وحده أن endpoint غير صالح.

### 10.3 `ProviderModelCacheService`

يطبق stale-while-revalidate:

1. `snapshot()` يعيد آخر cache متوافق فورًا.
2. `refresh()` يجلب live models دون حذف snapshot.
3. نجاح غير فارغ يستبدل entry ذريًا ويصدر event.
4. empty/error يبقي النجاح السابق ويحدث warning metadata.
5. طلبات instance نفسها coalesced إلى refresh واحد.
6. عدة instances تُحدث بتوازٍ محدود.
7. TTL/cooldown قيم مركزية، وmanual refresh يتجاوز cooldown دون duplication.
8. fingerprint/revision غير متوافق لا يعرض كاش endpoint قديم كأنه صالح.

### 10.4 `RecentModelSelectionService`

- يسجل الاختيار عند تأكيده في Client أو CLI، لا عند hover.
- upsert للاختيار نفسه ينقله للأعلى.
- يعيد خمسة عناصر بحد أقصى مع UUID والاسم الحالي وmodel ID.
- حذف instance يحذف عناصرها، وRename يغير العرض تلقائيًا.

## 11. البروتوكول canonical

### 11.1 القوالب والنسخ

```text
provider.templates.list/result
provider.instances.list/result
provider.instance.create/created
provider.instance.update/updated
provider.instance.rename/renamed
provider.instance.remove/removed
provider.instance.set_default/default_changed
provider.instance.test/test_result
provider.credential.update/updated
```

كل mutation يحمل request ID وinstance UUID عند اللزوم.

### 11.2 OAuth

```text
provider.auth.start/poll/submit/cancel
provider.auth.reconnect/disconnect/status
```

كل أمر بعد create يحمل `provider_instance_id` ولا يقبل template ID كبديل.

### 11.3 النماذج والأحداث

```text
model.snapshot/snapshot_result
model.refresh/cache_updated
model.recent.list/recent_result
model.recent.record/recent_recorded
provider_instances_changed
```

يعيد snapshot مجموعات keyed by instance ID، display name، cached models، cache
status/fetchedAt/warning، recent، والـdefault. `model.refresh` غير حاجب ويدفع
حدثًا لكل مجموعة مكتملة. توجه الأحداث لعائلة Sanad Client بعقد delivery الحالي.

تعاد كتابة استدعاءات `provider.list`, `save_api_key`, `save_custom_endpoint`,
`list_configured` و`configured_options` قبل الإغلاق. لا تبقى aliases دائمة أو
قراءة للتخزين القديم.

## 12. تغييرات Client

### 12.1 البيانات والإدارة

- DTO منفصل للقالب والـinstance وCredentialSummary.
- `ProviderSetupClient` يستهلك instance-first commands ولا يحمل raw secret.
- `ProviderSetupFlow` يخدم onboarding وsettings بالمتحكم نفسه.
- Templates picker، Instances list، Add/Edit/Rename/Remove/Default.
- auth-method badges وtabs `All/Accounts/API Keys` مع أولوية Accounts.
- API key replace/remove وOAuth connect/reconnect/disconnect.
- Custom protocol selector واختبار الاتصال والنموذج.
- Onboarding ينجح عند default instance runtime-ready.

### 12.2 حماية Edit

- يبدأ Edit بmetadata وmasked hint فقط.
- الحالة الافتراضية `keep`؛ فتح الحقل لا يعني replace قبل إدخال وتأكيد قيمة.
- Cancel لا يغير repository أو SecretStore.
- remove/disconnect يحتاج confirmation منفصلًا.

### 12.3 Model Picker والمحادثة

- `ProviderRuntimeCubit` يعرض cached snapshot بلا spinner حاجب عند وجوده.
- Background refresh وحالة صغيرة لكل group وwarning غير حاجب.
- Recent أعلى النتائج، والبحث باسم instance أو model.
- label موحد `instanceDisplayName / modelId`.
- Rename يحدث picker/recent/status دون إعادة جلب النماذج.
- اختيار النموذج يحتفظ بـinstance UUID وmodel ID منفصلين عن label.
- `ConversationInputCubit` يرسل UUID، وsession restore يحل الاسم الحالي.
- instance مفقودة تعرض `Provider unavailable` وتطلب بديلًا.

## 13. تغييرات CLI

يعاد تنظيم `CliProviderSetup` فوق الخدمات الجديدة ليدعم:

1. List templates/instances وحالاتها وdefault.
2. Add قالب جاهز أو Custom ببروتوكول صريح.
3. Edit وRename وRemove وSet default.
4. Enter-to-keep وreplace/remove API key صريحين.
5. OAuth connect/reconnect/disconnect per instance.
6. cached models وmanual refresh وRecent Selected.
7. عدم طباعة raw key/token أو الكتابة المباشرة إلى `.env`.

## 14. مراحل التنفيذ وبوابات الخروج

### A. العقود ونموذج البيانات

- [x] تثبيت domain names والبروتوكول ومخطط الجداول.
- [x] تحديث provider protocol وdatabase schema قبل كود السلوك.
- [x] repository واختباراته وإزالة افتراض env var per provider.

**البوابة:** نسختان من template واحد، Rename يحفظ UUID، وdefault constraint صحيح.

### B. SecretStore والاعتمادات

- [x] تعريف SecretStore/SecretRecord/Summary.
- [x] SecureFileSecretStore ذري ومقفول ومحمي عبر الأنظمة.
- [x] keep/replace/remove وmasked hints وresolver بالـinstance ID.

**البوابة:** Edit مع keep لا يغير السر/revision، وreplace/remove لا يمسان نسخة أخرى.

### C. CRUD وOAuth متعدد الحسابات

- [x] ProviderInstanceService وdraft/ready/default.
- [x] auth pending/store/refresh/reconnect بالـinstance ID.
- [x] تدفقان متوازيان للقالب نفسه.

**البوابة:** حسابان OAuth مستقلان، وفشل أحدهما لا يغير الآخر.

### D. التوجيه والـadapters

- [x] RouteSignature وAgentRuntimeService وturn/session payload.
- [x] إزالة unknown fallback وإبطال per instance.
- [x] ProviderEndpointResolver للبروتوكولين.

**البوابة:** جلستان بنسختين من النوع نفسه تستخدمان endpoint/credential مختلفين.

### E. كاش النماذج والحديثة

- [x] SWR/coalescing/bounded refresh/fingerprints.
- [x] RecentModelSelectionService بحد خمسة.
- [x] snapshot/refresh/events.

**البوابة:** snapshot فوري، refresh خلفي، والفشل لا يمسح آخر نجاح.

### F. البروتوكول

- [x] commands/results/events الجديدة وSanadProtocolBridge/delivery.
- [x] إزالة العقود القديمة بعد نقل كل المستهلكين.
- [x] اختبارات correlation والعزل وعدم التسريب.

**البوابة:** CRUD/auth/models تعمل instance-first دون وصول العميل للتخزين.

### G. Client UX

- [x] DTO/client/cubits وInstances management.
- [x] Add/Edit/Rename/Remove/Default وCustom/OAuth.
- [x] credential-preserving edit وcached/recent picker.
- [x] conversation payload/status/session restore.

**البوابة:** سيناريوهات القسم 6 تعمل باختبارات widget دون catalog hardcoded.

### H. CLI

- [x] نقل setup/edit/auth/model flows إلى الخدمات الجديدة.
- [x] masked/keep وCRUD/default/recent.
- [x] إزالة الكتابة المباشرة لإعدادات المزود في `.env`.

**البوابة:** CLI وClient يريان الحالة نفسها ويستخدمان المصدر نفسه.

### I. التنظيف والوثائق والتحقق

- [x] إزالة تخزين المزود القديم من المسار الفعلي، وإبقاء `.env` للإعدادات العامة.
- [x] تحديث AGENTS ووثائق التصميم والفهرس.
- [x] التحليل والاختبارات والوحدات والـE2E المتسلسلة ومراجعة الأسرار.

**البوابة:** لا مصدر حقيقة مزدوجًا، وكل معايير القبول مثبتة.

## 15. استراتيجية الاختبار

### 15.1 الوكيل والوحدات

- CRUD/unique names/single default/stable UUID/cascade delete.
- atomic SecretStore/lock/permissions/recovery/redaction/masking.
- keep/replace/remove validation وOAuth isolation/parallel pending/refresh.
- required API key يرفض الفراغ، وoptional يقبله ويجتاز readiness عند نجاح endpoint.
- URL root و`/v1` وtrailing slash للبروتوكولين.
- RouteSignature isolation وunknown instance failure.
- cache revisions/TTL/coalescing/concurrency وعدم مسح النجاح بالفشل.
- recent dedupe/order/limit/rename/delete وreadiness.

### 15.2 البروتوكول

- responses تحمل request ID وinstance UUID ولا تحمل secrets.
- auth يرفض template-only IDs.
- snapshot لا ينتظر refresh، والحدث يصل للمجموعة الصحيحة.
- turn يصل بالـinstance ID إلى adapter الصحيح.
- instance مفقودة تعطي خطأ دون OpenAI fallback.

### 15.3 Client وCLI

- إضافة نسختين من القالب نفسه وOAuth حسابين كبطاقتين مستقلتين.
- شارة auth الصحيحة لكل instance، والفلاتر تعتمد authMethod وتضع Accounts أولًا.
- Edit keep لا يرسل secret فارغًا؛ remove/replace صريحان.
- Rename يحدث card/picker/recent/status دون auth.
- picker يعرض cache/recent ثم يحدث؛ الفشل يبقي البيانات.
- الاختيار يرسل UUID ويعرض الاسم/model.
- CLI Enter-to-keep وCRUD/custom/recent وعدم طباعة الأسرار.

### 15.4 E2E والأمان

- daemon حقيقي + Client يستخدمان endpointين mock باعتمادين مختلفين.
- restart يحافظ على instances/cache/recent/default ويعرض cache قبل الشبكة.
- تغيير secret يبطل instance واحدة، وRename لا يكسر session.
- OAuth connector المتاح يختبر حسابين حيث تسمح بيئة الاختبار.
- E2E المرتبطة بالمنافذ متسلسلة.
- فحص database/files/logs/events من fixtures السرية وصلاحيات الأنظمة.

## 16. معايير القبول النهائية

1. إنشاء نسختين أو أكثر من القالب نفسه باسم وUUID واعتماد مستقل لكل واحدة.
2. حسابا OAuth من القالب نفسه لا يستبدل أو يعطل أحدهما الآخر.
3. Rename لا يغير UUID أو الاعتماد أو الكاش أو الجلسات.
4. تعديل الاسم/model/Base URL لا يطلب السر أو OAuth مجددًا.
5. update افتراضيًا `keep`، والحقل الفارغ لا يحذف أو يستبدل السر.
6. API Key يظهر masked فقط، وOAuth token لا يظهر كليًا أو جزئيًا.
7. replace/remove/reconnect/disconnect أفعال صريحة ومستقلة.
8. لا raw provider secret في SQLite أو DTO أو event أو log.
9. SecretStore ذري ومقفول ومحمي للمستخدم على الأنظمة المدعومة.
10. Custom ينشئ OpenAI-compatible أو Anthropic-compatible باسم المستخدم.
11. لا أسماء بوابات مثل Kiro hardcoded في registry أو adapters.
12. Anthropic models/messages يعملان مع root أو `/v1` دون `/v1/v1`.
13. unknown instance تفشل بوضوح ولا تسقط إلى OpenAI.
14. جلستان تستخدمان نسختين من النوع نفسه دون تداخل.
15. Model Picker يعرض آخر cache متوافق قبل network refresh.
16. refresh يحدث المجموعة في الخلفية دون إغلاق picker أو فقد الاختيار.
17. فشل/empty refresh لا يمسح آخر قائمة ناجحة.
18. refreshes المتزامنة coalesced ومقيدة التوازي.
19. Recent تعرض أحدث خمسة دون تكرار وتستمر بعد restart.
20. Recent مشتركة بين Client وCLI وRename يحدث أسماءها.
21. العرض في كل موضع `instance display name / model ID`.
22. payload يحمل `provider_instance_id` وmodel ID الخام لا label.
23. حذف instance يزيل سرها وكاشها وحديثتها دون مساس بغيرها.
24. missing/deleted instance لا تحول الجلسة إلى مزود آخر صامتًا.
25. readiness يعتمد على default instance جاهزة لا provider env القديم.
26. Client لا يحتوي catalog أو auth rules موازية للوكيل.
27. CLI لا يكتب إعدادات instances إلى `.env` مباشرة.
28. الاختبارات المتأثرة والتحليل وE2E تمر دون regression.
29. provider protocol/database schema/AGENTS محدثة مع التنفيذ.
30. بطاقات Settings تعرض طريقة المصادقة دون كشف سر أو خلطها بحالة الاتصال.
31. tabs تعرض الفئة الصحيحة، ويضع `All` نسخ Accounts أولًا بترتيب ثابت.
32. لا تظهر فئة `No authentication`؛ القالب optional يقبل مفتاحًا فارغًا ويعرض
    `No API key` داخل فئة API Keys دون اعتباره credential مفقودًا.

## 17. تعريف الاكتمال

1. اكتمال المراحل A-I وبوابات خروجها وكل معايير القبول.
2. عدم بقاء مصدر حقيقة مزدوج بين `.env` وSQLite للنسخ.
3. إزالة fallback للمزود المجهول والعقود القديمة من المستهلكين.
4. نجاح التحليل واختبارات الوحدات والـwidgets والـE2E ذات الصلة.
5. توثيق التحقق اليدوي لتخزين الأسرار على الأنظمة المدعومة.
6. مراجعة مستقلة لـsecret redaction وOAuth isolation وUX.
7. تحديث الوثائق الأقرب للكود في جلسة التنفيذ نفسها.

## 18. الوثائق التي تحدث أثناء التنفيذ

- `sanad-agent/agent/AGENTS.md` وAGENTS الخاصة بالـengine/interfaces/evolution.
- `sanad-agent/client/AGENTS.md` و`client/lib/features/provider_setup/AGENTS.md`.
- `sanad-agent/docs/technical/provider_protocol.md`.
- `sanad-agent/docs/technical/agent_database_schema.md`.
- `sanad-agent/docs/technical/agent_runtime.md`.
- سيناريوهات `sanad-agent/docs/qa_maintenance/` وفهرس `docs/llms.txt`.

## 19. المخاطر وضوابطها

| الخطر | الضابط |
|---|---|
| overwrite لحساب OAuth | storage/pending/refresh keyed by UUID واختبارات توازٍ |
| حذف سر بحقل فارغ | keep/replace/remove وkeep افتراضيًا |
| كشف سر | summaries/redaction tests ومنع SecretRecord من serialization العام |
| cache من endpoint قديم | fingerprint وconfig/credential revisions |
| بطء/إغراق APIs | snapshot أولًا، cooldown، coalescing وتوازٍ محدود |
| اختلاط الاسم بالهوية | UUID للتوجيه وdisplayName للعرض فقط |
| fallback لاعتماد آخر | fail closed عند instance/secret المفقود |
| نظامان قديم وجديد | لا migration ولا compatibility دائم؛ إزالة القديم ضمن المرحلة |
| تفاوت حماية الملفات | اختبارات وWindows ACL بدل skip صامت |
| تضخم النطاق | تأجيل headers/paths/keychain/pooling/sync |

## 20. مبادئ التصميم المعتمدة

- stable credential IDs، labels، الكتابة الذرية والقفل، URL probes، منع
  `/v1/v1`، model cache المرتبط بـfingerprint، وعدم مسح النجاح عند الفشل.
- auth methods التصريحية المشتركة بين CLI/UI، فصل الإعداد العام عن auth
  record، والتحقق في نموذج Custom Provider.
- لا ننسخ OAuth singleton أو provider-level rotation أو جعل provider ID هو
  القالب والنسخة والاعتماد معًا أو schemas قديمة متداخلة.

النتيجة المستهدفة: قالب ثابت + instance مستقلة كاملة + SecretStore +
cache/recent، دون هوية مشتقة من الاسم أو fallback صامت.
