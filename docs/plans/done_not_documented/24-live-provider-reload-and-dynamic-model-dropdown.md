# خطة المرحلة الرابعة والعشرين: توجيه المزود/النموذج لكل رسالة ومحدد النماذج الهرمي

## خلفية القرار

المراجعة الفعلية لكود Sanad (الخطة 19) كشفت فجوتين حرجتين:

1. **عدم التقاط حيّ لتبديل المزود:** بعد `model.set_default` من الواجهة، الوكيل لا يلتقط التغيير إلا بعد إعادة تشغيل. السبب أن `Config` يحمّل `.env` مرة واحدة (`config.dart:17-38`), و`LLMAdapter` يُبنى كـ singleton ثابت في `di.dart:110-132` بـ `ProviderProfile` واحد لا يُستبدل, و`AgentRunner` يثبّت `defaultModel = Config.llmModel` عند إنشاء الجلسة (`agent_runner.dart:123-134`) ثم يمرره كـ `modelOverride` لكل دورة دون إعادة قراءة.

2. **غياب التوجيه per-session/per-message للمزود:** الحالة الحالية تدعم نموذجاً per-session فقط (`SessionState.model` في `session_state.dart:5`), بينما المزود **عالمي واحد** عبر `Config.resolveProviderName()`. لا يوجد `providerId` في `SessionState`, ولا في `think` payload (`canonical_to_agent.dart:33,62`), ولا في `AgentTurnRequest` (`agent_turn_request.dart:1-18`). نتيجةً: لا يمكن لمحادثتين استخدام مزودين مختلفين في نفس الوقت.

## ميزة الهدف

> في واجهة المحادثة، يضغط المستخدم على محدد النموذج فتظهر قائمة هرمية: المزودون المُعدّون كمجموعات، وتحت كل مزود نماذجه. يختار المستخدم `provider+model` فيُرفق intent بالرسالة الجديدة التالية ويُرسل في `think` payload. يمكن بدء عدة محادثات في نفس الوقت كلٌّ بمزود ونموذج مختلف. التبديل يحدث عند حدود user→assistant (لا داخل turn). لا يتطلب إعادة تشغيل ولا تبديل حالة عالمية.

## قرار معماري رئيسي

نقل المركزية من **"مزود عالمي واحد + singleton adapter يُبدَّل"** إلى **"توجيه per-message + adapter cache مركّب"**:

1. **التوجيه per-message:** كل رسالة مستخدم تحمل `{provider_id, model}`. حلقة `think` تقرأهما من آخر رسالة وتُوجّه الطلب. حقل `session.model`/`session.providerId` هو **projected fallback** يُحدَّث عند التبديل، لا مصدر الحقيقة الجاري.
2. **Adapter cache مركّب:** `AgentRuntimeService` يملك `Map<RouteSignature, LLMAdapter>` بدل adapter واحد. التبديل = lookup/insert في الخريطة، **لا eviction، لا restart، لا reload عند التبديل**.
3. **عزل التزامن هيكلي:** كل جلسة لها `AgentRunner` مستقل (موجود عبر `registerFactoryParam` في `di.dart:220`) يتشارك الـ cache فقط (كائنات adapter غير قابلة للتغيير بعد البناء). لا توجد حالة عالمية قابلة للتغيير.
4. **فصل "تطبيق حيّ per-session" عن "حفظ دائم عام":** الواجهة تُرفق `provider_id`+`model` بالرسالة (تطبيق حيّ على الجلسة). الحفظ الدائم عبر `model.set_default` منفصل ويكتب `.env` (الافتراضي العام للمحادثات الجديدة).
5. **إبطال mtime في `Config`:** للالتقاط التغييرات على `.env` (مثل حفظ مفتاح جديد) دون restart. هذا للمزود الافتراضي/الإعداد فقط، **لا يُستخدم في مسار التبديل per-message**.
6. **حدث `model_switched` durable:** يُنشر كحدث في البروتوكول ويُخزَّن علامة في transcript، لكن **لا يُحقن كنص في سياق LLM**. الحفاظ على prompt cache عبر ثبات ترتيب الـ tiers.
7. **محدد نماذج هرمي:** قائمة مجمّعة حسب المزود، تدمج `ProviderRegistry` (catalog ثابت) + `ModelOptionsService` (fetch live) لكل مزود مُعدّ.

لا يتم اعتماد إعادة تشغيل كعملية افتراضية. لا يتم اعتماد `switchModel()` عالمي ولا atomic rollback معقد (غير مطلوب لأن التبديل per-message بطبيعته لا يلمس حالة عالمية).

## الأهداف

1. كل رسالة مستخدم يمكن أن تحمل `{provider_id, model}` صراحةً في `think` payload.
2. محادثتان نشطتان في نفس العملية يمكن أن تستخدما مزودين/نموذجين مختلفين دون تأثير متبادل.
3. اختيار `provider+model` من الواجهة يُرفق بالرسالة الجديدة فقط، ولا يبدّل حالة عالمية ولا يقطع الجلسات الأخرى.
4. بعد `model.set_default`, المحادثات **الجديدة** التالية تستخدم المزود الجديد كافتراضي دون restart (عبر إبطال mtime في `Config`).
5. قائمة النماذج في الواجهة هرمية (مزود → نماذج) وتتحدّث ديناميكياً.
6. فشل بناء adapter جديد يرمي استثناء للرسالة المعنية فقط دون كسر الجلسة (لا rollback عالمي مطلوب لأن الـ cache append-only).
7. الحفاظ على prompt cache: لا حقن نص "تبديل نموذج" في سياق LLM؛ علامة `model_switched` durable فقط.
8. CLI والواجهة يشتركان نفس طريق `Config` + `AgentRuntimeService` + `ProviderCredentialResolver`.

## خارج نطاق هذه المرحلة

- نظام plugin ديناميكي للمزودين (يبقى `ProviderRegistry` const).
- credential pool متعدد الحسابات لكل مزود (مفتاح واحد لكل مزود).
- callable token providers لـ JWT per-request (يؤجل لمزودي Azure/Entra ID).
- إعادة تصميم تخزين config من `.env` إلى YAML (يبقى `.env`).
- إعادة بناء `AgentContextAssembler` بالكامل (يُكتفى بإبطال cache الـ volatile tier).
- تتبع variant/reasoning-effort كمحور منفصل عن model id (يؤجل).
- downgrading reasoning عبر المزودات عند replay التاريخ (يُؤجل لمرحلة لاحقة، يُشار إليه كـ future-work).

## الأنماط المعمارية المعتمدة

| النمط | مبرر التصميم | كيف يُكيَّف لـ Sanad |
|---|---|---|
| توجيه per-message بحقل `{providerID, modelID}` على الرسالة | منع الحالة العالمية المتغيرة | `Message`/`AgentTurnRequest` يحمل `providerId`+`model`; `AgentRunner` يقرأهما من آخر رسالة |
| Adapter cache مركّب `Map<"p/m", adapter>` | إعادة استخدام آمنة حسب route | `AgentRuntimeService` يملك `Map<RouteSignature, LLMAdapter>` بدل adapter واحد |
| بناء fresh per-request من cache | ثبات route داخل الطلب | `AgentRuntimeService.adapterFor(signature)` يرجع من cache أو يبني جديداً |
| `ModelSwitched` durable event يُسقَط من سياق LLM | فصل transcript عن prompt | حدث `model_switched` في البروتوكول + علامة في history دون حقن نص |
| عزل التزامن per-session Runner | منع تسرب الحالة بين الجلسات | `AgentRunner` per-session موجود (`di.dart:220`); تأكد فقط من عدم مشاركة حالة عالمية قابلة للتغيير |
| قائمة هرمية بمجموعات المزود | قابلية اكتشاف النماذج | محدد Sanad يبني قائمة مسطّحة بـ `category: provider.name` |
| `promptCacheKey = session.id` للحفاظ على cache عبر التبديل | ثبات cache داخل الجلسة | (future-work) قد يُفيد للـ OpenAI adapter |
| Provider registry من مصادر متعددة | فصل catalog عن live state | `ProviderRegistry` (catalog ثابت) + `ModelOptionsService` (live) + `ProviderStateService` (configured) |
| Per-request credential resolution by `providerID` | منع credential عالمية | `ProviderCredentialResolver.resolveActive(providerId)` على طريق adapter |
| UI selection منفصل عن session truth | عدم جعل الواجهة مصدر الحقيقة | `nextMessageModel`/`nextMessageProviderId` في `ConversationInputCubit` يُرفق بالرسالة فقط |

## التغييرات على الوكيل

### 1. `Config` — إبطال تلقائي عبر mtime (للإعداد/الافتراضي فقط)

`sanad-agent/agent/lib/core/config.dart`:

- إضافة `DateTime? _envMtime` و `int? _envSize` كحقول خاصة.
- في كل getter رئيسي (`llmModel`, `llmApiKey`, `llmBaseUrl`, `activeProvider`, `resolveProviderName`), استدعاء `_ensureFreshEnv()` أولاً.
- `_ensureFreshEnv()`: يقرأ `File(getEnvPath()).stat()`. إن اختلف `(modified, size)` عن المخزّن → `_env = DotEnv()..load(...)`, تحديث `(_envMtime, _envSize)`. إن لم يختلف → لا شيء (hot path سريع).
- إضافة `void reload()` عام للاستخدام اليدوي (اختبارات + `sanad setup`).
- لا يزال singleton في `di.dart` (لا تغيير في التسجيل).

قاعدة الاستخدام: `Config` هو مصدر **المزود الافتراضي العام** والمفاتيح المخزّنة في `.env`. **لا يُقرأ في مسار توجيه رسالة محددة** — مسار التوجيه per-message يستخدم `providerId` الوارد في الـ payload مباشرة عبر `ProviderRegistry` + `ProviderCredentialResolver`.

### 2. `RouteSignature` + `AgentRuntimeService` — adapter cache مركّب

ملف جديد: `sanad-agent/agent/lib/core/agent_runtime_service.dart`.

```text
class RouteSignature {
  final String providerId;
  final String apiMode;
  final String baseUrl;
  final String model;
  const RouteSignature({...});
  bool operator ==(...) // Equatable على الحقول الأربعة
  int get hashCode // متسق مع ==
  String get cacheKey => '$providerId/$model';
}

class AgentRuntimeService {
  final Map<RouteSignature, LLMAdapter> _adapters = {};
  final Map<String, _SdkHandle> _sdkCache = {}; // keyed by options hash (apiKey+baseUrl+providerId)

  LLMAdapter adapterFor(RouteSignature signature);  // lookup أو build+cache
  LLMAdapter? currentFor(String sessionId);         // optional: per-session آخر signature مستخدم (للأدوات/الأرصاد فقط)
  void invalidate();                                 // مسح كامل الـ cache (بعد model.set_default)
  void invalidateProvider(String providerId);        // مسح adapters لمزود واحد (بعد save_api_key)
}

class _SdkHandle { final String apiKey; final String baseUrl; ... }
```

- يُسجَّل كـ lazy singleton في `di.dart` **قبل** `LLMAdapter` و`AgentRunner`.
- `adapterFor(signature)`: إن وُجد في `_adapters` → رجوع. وإلا → حل credential عبر `ProviderCredentialResolver.resolveActive(signature.providerId)`, بناء `ProviderProfile` من `ProviderRegistry.findByNameOrAlias(signature.providerId)`, بناء adapter بناءً على `profile.apiMode` (نفس منطق `di.dart:110-132` منقولاً هنا), تخزينه في `_adapters`, رجوعه. فشل البناء → رمي (لا rollback عالمي مطلوب؛ الـ cache append-only).
- `currentFor(sessionId)`: اختياري، يحتفظ بـ `Map<sessionId, RouteSignature>` آخر signature استُخدم للجلسة (للأرصاد/`activeModel`/`activeProvider` فقط، لا للتوجيه).
- `invalidate()` / `invalidateProvider()`: مسح الـ cache. تُستدعى بعد `model.set_default` / `provider.save_api_key` لأن الـ cache قد يحمل adapters بمفاتيح قديمة.
- `LLMAdapter` في `di.dart` يُلغى كـ singleton مباشر. بدلاً منه: `getIt<AgentRuntimeService>().adapterFor(RouteSignature.defaultFromConfig())` يُستخدم حيثما كان الافتراضي مطلوباً (`ContextEngine`, الاختبارات).
- **لا** يوجد `switchModel()` عالمي. التبديل يتم بإرسال `providerId`+`model` مختلف في الرسالة التالية، و`AgentRunner` يستدعي `adapterFor(signature)` بالـ signature الجديد.

### 3. `AgentTurnRequest` + `CanonicalToAgent` — تمرير `provider_id` + `thinking_mode` per-message

`sanad-agent/agent/lib/interfaces/models/agent_turn_request.dart`:

- إضافة `final String? providerId;` كحقل أول class (موازٍ لـ `model`).
- `thinkingMode` موجود بالفعل كحقل (`:7`). يبقى كما هو.
- إضافة `providerId` للـ constructor و `toMetadata()`.

`sanad-agent/agent/lib/interfaces/platforms/sanad_gateway/translators/canonical_to_agent.dart`:

- في فرعي `steer` و `think` (`:27-82`): قراءة `payload['provider_id'] as String?` وتمريره لـ `AgentTurnRequest.providerId`. `thinking_mode` يُقرأ بالفعل (`:34,63`).

### 4. `AgentRunner` — توجيه per-message عبر `adapterFor`

`sanad-agent/agent/lib/engine/agent_runner.dart`:

- الحقل `final LLMAdapter adapter` (`:38`) يصبح **final للنص الافتراضي فقط** (للاختبارات/الـ ContextEngine الافتراضي). يُضاف:
  ```text
  LLMAdapter _adapterForTurn(String? providerId, String? model) {
    final config = getIt.isRegistered<Config>() ? getIt<Config>() : null;
    final effProvider = providerId ?? config?.resolveProviderName() ?? 'openai';
    final effModel = model ?? _effectiveModel ?? config?.llmModel ?? 'sanad-agent';
    final profile = ProviderRegistry.findByNameOrAlias(effProvider) ??
        ProviderRegistry.findByNameOrAlias('openai')!;
    final baseUrl = config?.llmBaseUrlFor(effProvider);
    final signature = RouteSignature(
      providerId: profile.id,
      apiMode: profile.apiMode,
      baseUrl: baseUrl ?? '',
      model: effModel,
    );
    return getIt<AgentRuntimeService>().adapterFor(signature);
  }
  ```
- في كل مكان يُستخدم فيه `adapter` حالياً داخل حلقة `think`/`streamMessage`/`generateResponse` → استدعاء `_adapterForTurn(turnRequest.providerId, turnRequest.model ?? _effectiveModel)`. الأماكن الرئيسية: استدعاءات `generateResponse`/`generateStream` في حلقة الأدوات, `getContextLimit`, `ContextEngine` للضغط.
- `_effectiveModel` (`:83-86`) يبقى لقراءة `session.model` كـ fallback للنموذج فقط.
- ملاحظة التبديل: **لا تُحقن كنص في سياق LLM**. بدلاً منه: عند اكتشاف تغيّر `(providerId, model)` عن قيم الـ turn السابق لنفس الجلسة، تُسجَّل علامة `model_switched` في الـ transcript (Message metadata) ويُبَث حدث `model_switched` عبر البروتوكول. هذا يحافظ على prompt cache (مستوحى من `to-llm-message.ts:104-106`).
- `getIt<LLMAdapter>()` في `di.dart:222` (بناء `AgentRunner`) يصبح `getIt<AgentRuntimeService>().adapterFor(RouteSignature.defaultFromConfig())` كـ adapter افتراضي للجلسة (يُستخدم فقط قبل أول turn صريح).

### 5. `SessionState` + `SessionManager` — إضافة `providerId` + `thinkingMode` (projected fallback + persisted)

`sanad-agent/agent/lib/evolution/models/session_state.dart`:

- إضافة `final String? providerId;` و `final String? thinkingMode;` (nullable لأن الجلسات القديمة لا تحملهما).
- إضافتهما لـ `SessionState(...)` constructor, `toMap()` (`'provider_id'`, `'thinking_mode'`), `fromMap()`.
- ترحيل قاعدة بيانات: عمودان `provider_id TEXT` و `thinking_mode TEXT` في `sessions` عبر migration في `SessionDB`.
- **الغرض:** حفظ آخر قيم استخدمها المستخدم في هذه المحادثة تحديداً (provider + model + thinking mode), بحيث عند إعادة فتح المحادثة في أي وقت لاحق يجدها كما تركها. هذا **تخزين دائم per-session**, منفصل عن `nextMessageSelection` (وهو intent الرسالة القادمة فقط).

`sanad-agent/agent/lib/evolution/session_manager.dart`:

- `updateSessionModel(String sessionId, String model)` يصبح `updateSessionModeling(String sessionId, {String? providerId, String? model, String? thinkingMode})`. تحدّث الثلاثة معاً عند التبديل. الحقول المُمرَّرة `null` تُحافَظ على قيمتها السابقة (partial update).
- `createSession(String model)` يصبح `createSession({String? providerId, required String model, String? thinkingMode})` — يأخذ المزود الافتراضي من `Config.resolveProviderName()` و `Config.llmModel` و thinking mode الافتراضي إن لم تُمرَّر.
- عند استلام رسالة مستخدم بـ `providerId`+`model`+`thinkingMode` يختلفان عن `session.*` → تحديث الجلسة بالقيم الجديدة (projected fallback + persisted للاستعادة) + تسجيل علامة `model_switched`.

### 6. `AgentContextAssembler` — إبطال volatile tier عند التبديل

`sanad-agent/agent/lib/engine/agent_context_assembler.dart`:

- إضافة `void invalidateVolatile()` تضبط `_volatileCache = null`.
- `AgentRunner` يستدعيها عند اكتشاف تغيّر `(providerId, model, thinkingMode)` بين turn وآخر لنفس الجلسة، قبل بناء system prompt التالي.
- الـ volatile tier يعاد بناؤه ببيانات المزود/النموذج الجديدة (للأرصاد الداخلية: "Active provider: X, model: Y").

### 7. `SanadProtocolBridge` — أوامر + أحداث

`sanad-agent/agent/lib/interfaces/platforms/sanad_gateway/sanad_protocol_bridge.dart`:

- بعد `_buildModelSetDefaultEnvelope` نجاح (`:1125-1153`):
  - `getIt<AgentRuntimeService>().invalidate()` (مسح adapters لأن `.env` تغيّر).
  - `getIt<AgentContextAssembler>().invalidateVolatile()` (لا يؤثر على الجلسات النشطة لأنها توجّه per-message؛ فقط للـ ContextEngine الافتراضي).
  - emit `capabilities_changed` (يحمل قائمة `models` الجديدة + `active_provider` + `active_model` + `configured_providers`).
- بعد `provider.save_api_key` / `save_custom_endpoint` / `provider.auth.start` نجاح:
  - `getIt<AgentRuntimeService>().invalidateProvider(providerId)`.
  - emit `capabilities_changed` للمزود المعني.
- أمر جديد `model.options` موجود (الخطة 19) — يُعاد استخدامه لتعبئة dropdown الواجهة. **تغيير:** قبول `provider_id` اختياري في payload لجلب نماذج مزود محدد. إن لم يُمرَّر → المزود النشط الافتراضي.
- أمر جديد `provider.configured_options`: يرجع خريطة `{provider_id → [models]}` لكل المزودين المُعدّين دفعة واحدة (للـ dropdown الهرمي). هذا تجميع فوق `provider.list_configured` + استدعاء `model.options` لكل مزود. يُفضَّل تنفيذه كـ aggregator في البروتوكول بدل جلب كل مزود على حدة من الواجهة (يقلل round-trips).
- لا حاجة لأمر `provider.switch_for_session` عالمي في هذه المعمارية (التبديل يتم بإرسال `provider_id` في `think` payload). إن احتاجت الواجهة لـ "apply preview" قبل الإرسال يمكنها إرسال `model.options` للمزود المختار فقط لتحديث القائمة.

### 8. أحداث canonical جديدة

`sanad-agent/agent/lib/interfaces/platforms/sanad_gateway/protocol/canonical_events.dart`:

```dart
static const String capabilitiesChanged = 'capabilities_changed';
static const String modelSwitched = 'model_switched'; // durable transcript marker + broadcast
```

- `capabilities_changed`: يدفعه الوكيل بعد `model.set_default` أو `provider.save_api_key`/`save_custom_endpoint`/`auth.start` ناجح. payload: `{models: [...], active_provider, active_model, configured_providers: [{id, name, models: [...]}], auth_type, supports_model_fetch}`. يستهدف `device_id` الوكيل المعني.
- `model_switched`: يدفعه الوكيل عند اكتشاف تبديل فعلي per-session (الرسالة الجديدة تحمل `provider_id`/`model`/`thinking_mode` يختلفان عن قيم الجلسة السابقة). payload: `{session_id, previous_provider_id, previous_model, previous_thinking_mode, new_provider_id, new_model, new_thinking_mode}`. يُستخدم للواجهة لتحديث مؤشر الجلسة + حفظ علامة في transcript. **لا يُحقن في سياق LLM.**

### 9. `ProviderCredentialResolver` على طريق adapter

- `AgentRuntimeService.adapterFor(signature)` يستدعي `ProviderCredentialResolver.resolveActive(signature.providerId)` لحل الـ credential وقت البناء. هذا يربط `provider_auth.json` (OAuth tokens) بطريق `think` فعلياً، ويُجدد tokens المنتهية.
- الـ cache key لـ `_sdkCache` يشمل `apiKey`+`baseUrl`+`providerId` لضمان بناء adapter جديد عند تغيّر المفتاح (حتى لو لم يُمسح الـ cache صراحةً).

## التغييرات على الواجهة

### 1. محدد النماذج الهرمي في `ConversationBottomActions`

`sanad-agent/client/lib/features/conversations/presentation/widgets/conversation_input/conversation_bottom_actions.dart`:

- `_buildModelSelector` (`:65-92`) حالياً يعتمد على `capabilities.models` (حدث `get_capabilities` مرة واحدة) كقائمة مسطّحة.
- التغيير الجوهري: استبدال `PopupMenuButton<String>` المسطّح بـ محدد هرمي. خياران:
  - **(أ) `PopupMenuButton` متداخل** — غير مدعوم مباشرة في Material؛ يتطلب dialog مخصص.
  - **(ب) Dialog مخصص (مستحسَن)** — `showDialog` يفتح `ModelPickerDialog` يعرض قائمة مجمّعة: رأس لكل مزود (اسم + حالة readiness) وتحته نماذجه. **يدعم بحث/فلترة** — حقل بحث في أعلى النافذة، عند الكتابة تُفلتر القائمة الهرمية باسم النموذج فوراً مع إبراز التطابقات. نتائج البحث تظهر النماذج المطابقة مجمّعة تحت مزوديها، ويمكن اختيار النموذج مباشرة من نتيجة البحث.
- مصدر البيانات: `ProviderRuntimeCubit` جديد (انظر أدناه) يدمج:
  - `provider.list_configured` → قائمة المزودين المُعدّين.
  - `model.options` per provider → نماذج كل مزود (live fetch عند الحاجة).
  - `capabilities.models` → fallback للمزود النشط إن لم تتوفر خيارات live.
- عند اختيار `{providerId, modelId}`:
  - `setNextMessagePreferences(providerId: providerId, model: modelId, thinkingMode: <default للنموذج الجديد>)` في `ConversationInputCubit` (يُرفق بالرسالة التالية فقط، لا يبدّل حالة عالمية).
  - **مستوى تفكير افتراضي للنموذج:** عند اختيار نموذج، يُضبط `thinkingMode` على القيمة الافتراضية للنموذج (من `ProviderRegistry`/`ModelsDevService` إن وُجد، أو `'default'`). المستخدم يستطيع **بعدها** تغيير مستوى التفكير مستقلاً من `_buildThinkingModeSelector` الموجود (`conversation_bottom_actions.dart:94`) — يبقى منفصلاً كما هو.
  - إن اختلف `providerId` عن مزود الجلسة السابق → تحديث مؤشر الجلسة بصرياً (pill في الـ status) + لا إرسال أي أمر للوكيل الآن (التطبيق يحدث عند إرسال الرسالة).
  - لا استدعاء `provider.switch_for_session` — التبديل per-message عبر `think` payload.

### 2. `ConversationInputCubit` + `SessionMessagesCubit` — تمرير `providerId` per-message

`sanad-agent/client/lib/features/conversations/presentation/bloc/conversation_input_cubit.dart`:

- `selectModel({...})` (`:122-143`) يصبح `selectModeling({required CapabilityValueScope scope, String? providerId, String? model})`.
- `setNextMessagePreferences` يأخذ `providerId`+`model` معاً.

`sanad-agent/client/lib/features/conversations/presentation/bloc/session_messages_cubit.dart`:

- `_nextMessageModelByAgentId` (`:41`) يصبح `_nextMessageSelectionByAgentId: Map<String, ({String? providerId, String? model, String? thinkingMode})>` (record Dart 3).
- `nextMessageModel` في state يصبح `nextMessageProviderId` + `nextMessageModel` + `nextMessageThinkingMode`.
- عند إرسال رسالة (`:337` و ما حولها): تمرير `provider_id`+`model`+`thinking_mode` في `think` payload.
- **استعادة قيم الجلسة عند الفتح:** عند تحميل/اختيار محادثة، قراءة `providerId`+`model`+`thinkingMode` من بيانات الجلسة (المُ Persisted في DB) وضبطها كـ `nextMessageSelection` مبدئي + عرضها في الـ pill. المستخدم يجد آخر ما استخدمه في تلك المحادثة بالضبط.

`sanad-agent/client/lib/features/conversations/presentation/bloc/conversation_input_state.dart` + `session_messages_state.dart`:

- إضافة `final String? nextMessageProviderId;` + `final String? nextMessageThinkingMode;` موازٍ لـ `nextMessageModel`.
- تحديث `copyWith` و الـ equality.

### 3. `ProviderRuntimeCubit` جديد (مستوى المحادثة/الجهاز)

ملف جديد: `sanad-agent/client/lib/features/provider_setup/presentation/bloc/provider_runtime_cubit.dart`.

```text
class ProviderModelGroup {
  final String providerId;
  final String displayName;
  final bool runtimeReady;
  final List<ModelOption> models;
  final bool liveFetched;
}

class ProviderRuntimeState extends Equatable {
  final String? activeProviderId;       // current session's projected provider
  final String? activeModel;
  final List<ProviderModelGroup> groups; // هرم المزودين + نماذجهم
  final bool loading;
  final String? error;
}

class ProviderRuntimeCubit extends Cubit<ProviderRuntimeState> {
  final ProviderSetupClient _client;
  final DeviceConfig? agent;
  StreamSubscription? _capSub;

  // loadConfiguredOptions() → provider.configured_options (aggregator) دفعة واحدة
  // loadModelOptionsFor(providerId, {fetchLive}) → model.options لمزود واحد
  // refresh()
  // onCapabilitiesChanged → loadConfiguredOptions()
}
```

- يُسجَّل في `app_providers.dart` مع `agent` = الجهاز النشط (يتحدّث عند `DeviceCubit.switchAgent`).
- يستمع لـ `capabilities_changed` عبر `EventRouter.forDevice(agent.id)`.
- عند الاستلام → `loadConfiguredOptions()` (يعيد جلب الهرم كاملاً).
- `loadConfiguredOptions()` يفضل استدعاء `provider.configured_options` (aggregator على الوكيل) بدل إرسال `model.options` لكل مزود من الواجهة (يقلل round-trips ويتجنب race conditions).

### 4. الاستماع لـ `capabilities_changed` + `model_switched` في `SanadSocketService`

`sanad-agent/client/lib/infrastructure/socket/sanad_socket_service.dart`:

- إضافة `capabilities_changed` و `model_switched` لقائمة الأحداث المُوجَّهة عبر `EventRouter.routeEvent`.
- `DeviceCapabilitiesStore._fetchForAgent` يستمع لـ `capabilities_changed` ويعيد استدعاء `get_capabilities` أو يطبّق الـ payload مباشرة.
- `model_switched` يُوجَّه لـ `SessionMessagesCubit` (أو `ProviderRuntimeCubit`) لتحديث `activeProviderId`/`activeModel` للجلسة المعنية (`payload.session_id`).

### 5. مؤشر "مزود/نموذج الجلسة" في الـ Status Bar

`sanad-agent/client/lib/features/home/presentation/widgets/status_bar.dart`:

- إضافة pill صغير يعرض `activeProviderId / activeModel` من `ProviderRuntimeState` للجلسة المحددة.
- عند `loading` (جلب قائمة) → مؤشر دوراني صغير.
- يعطي المستخدم رؤية فورية لمزود/نموذج الجلسة الحالية.

### 6. علامة `model_switched` في transcript الواجهة

- عند استلام `model_switched` للجلسة المحددة → إدراج صف "system marker" خفيف في transcript (أيقونة + نص مثل "Switched to Anthropic / claude-..."). **لا يُرسل للـ LLM** — عرض فقط.
- متوازٍ مع صفوف `ModelSwitched` داخل transcript.

## تدفق كامل بعد التنفيذ

```text
المستخدم يفتح محدد النماذج
  → ModelPickerDialog يعرض هرم المزودين المُعدّين + نماذجهم
  → (بيانات من ProviderRuntimeCubit.groups)
المستخدم يختار {anthropic, claude-sonnet-4}
  → setNextMessagePreferences(providerId: 'anthropic', model: 'claude-sonnet-4', thinkingMode: 'default')
  → لا إرسال أي أمر للوكيل الآن
  → pill الـ status يتحدّث محلياً لـ "anthropic / claude-sonnet-4 / default"
  → (المستخدم يستطيع تغيير thinkingMode بعدها من المحدد المستقل)
المستخدم يكتب رسالة ويضغط Enter
  → think payload {message, provider_id: 'anthropic', model: 'claude-sonnet-4', thinking_mode: 'default', session_id, ...}
  → CanonicalToAgent.translate → AgentTurnRequest(providerId: 'anthropic', model: 'claude-sonnet-4', thinkingMode: 'default')
  → SessionRunOrchestrator → AgentRunner.streamMessage
  → AgentRunner._adapterForTurn('anthropic', 'claude-sonnet-4')
      → RouteSignature(providerId: 'anthropic', apiMode: 'anthropic_messages', baseUrl: '', model: 'claude-sonnet-4')
      → AgentRuntimeService.adapterFor(signature)
          → cache miss → ProviderCredentialResolver.resolveActive('anthropic')
          → ProviderRegistry.findByNameOrAlias('anthropic') → profile
          → BaseAnthropicAdapter(config, profile, credential)
          → _adapters[signature] = adapter
      → رجوع adapter
  → إن اختلف (providerId, model, thinkingMode) عن session السابق:
      → SessionManager.updateSessionModeling(sessionId, providerId: 'anthropic', model: 'claude-sonnet-4', thinkingMode: 'default')
      → AgentContextAssembler.invalidateVolatile()
      → emit model_switched {session_id, prev, new (الثلاثة)}
  → adapter.generateStream(modelOverride: 'claude-sonnet-4', thinkingMode: 'default', ...) → الطلب يذهب لـ Anthropic ✓
  → الواجهة تستلم model_switched → تحديث pill + إدراج علامة transcript

المستخدم يغلق المحادثة ويعيد فتحها لاحقاً
  → الواجهة تقرأ providerId+model+thinkingMode من بيانات الجلسة (DB)
  → تعرضها في الـ pill + تضبطها كـ nextMessageSelection مبدئي
  → المستخدم يجد آخر قيم استخدمها في هذه المحادثة ✓

محادثة ثانية في نفس العملية بمزود مختلف (openai)
  → AgentRunner منفصل (di.dart:220 factory) → _adapterForTurn('openai', 'gpt-5')
  → RouteSignature مختلف → cache entry مختلف → adapter مختلف
  → لا تأثير على محادثة anthropic ✓

المستخدم يضغط "Save as default" (منفصل)
  → model.set_default
  → ModelSelectionService.setDefault() يكتب .env
  → AgentRuntimeService.invalidate() (مسح cache؛ adapters ستبنى بمفاتيح جديدة)
  → Config._ensureFreshEnv() يلتقط .env الجديد في الدورة التالية
  → emit capabilities_changed {configured_providers الجديد}
  → الواجهة تعيد تحميل الهرم
```

## مراحل التنفيذ

### المرحلة A: إبطال mtime في Config

- A1. إضافة `_envMtime`/`_envSize` و `_ensureFreshEnv()` لـ `Config`.
- A2. استدعاء `_ensureFreshEnv()` في getters رئيسية.
- A3. إضافة `Config.reload()` عام.
- A4. اختبارات: تغيير `.env` بين قراءتين يُرجع القيم الجديدة؛ عدم التغيير لا يقرأ من القرص.

### المرحلة B: RouteSignature + AgentRuntimeService (adapter cache مركّب)

- B1. إنشاء `RouteSignature` value object (Equatable على 4 حقول + `cacheKey` + `defaultFromConfig()`).
- B2. إنشاء `AgentRuntimeService` مع `adapterFor()` + `currentFor()` + `invalidate()` + `invalidateProvider()` + `Map<RouteSignature, LLMAdapter>` + `Map<String, _SdkHandle>`.
- B3. نقل منطق بناء adapter من `di.dart:110-132` إلى `AgentRuntimeService.adapterFor()`.
- B4. تسجيل `AgentRuntimeService` في `di.dart` قبل `LLMAdapter` و `AgentRunner`.
- B5. `LLMAdapter` في `di.dart` يصبح proxy: `getIt<AgentRuntimeService>().adapterFor(RouteSignature.defaultFromConfig())`.
- B6. `AgentRunner._adapterForTurn()` + استبدال استدعاءات `adapter` في حلقة think.
- B7. ربط `ProviderCredentialResolver.resolveActive(providerId)` ببناء adapter.
- B8. اختبارات: `adapterFor` بنفس signature يرجع نفس adapter؛ signature مختلف يبني adapter مختلف؛ فشل البناء يرمي دون كسر cache القائم؛ `invalidate()` يمسح الكل؛ `invalidateProvider(p)` يمسح مزوداً واحداً.

### المرحلة C: تمرير provider_id per-message

- C1. إضافة `providerId` لـ `AgentTurnRequest` + `toMetadata()`.
- C2. `CanonicalToAgent` يقرأ `payload['provider_id']` في `think` و `steer`.
- C3. `AgentRunner._adapterForTurn` يستخدم `turnRequest.providerId` كأولوية ثم `Config` fallback.
- C4. اختبارات: `think` بـ `provider_id='anthropic'` يوجّه لـ `BaseAnthropicAdapter`; بدون `provider_id` يقع للمزود الافتراضي.

### المرحلة D: SessionState.providerId + migration

- D1. إضافة `providerId` لـ `SessionState` (constructor, toMap, fromMap).
- D2. `SessionDB` migration: عمود `provider_id TEXT` في `sessions`.
- D3. `SessionManager.createSession({providerId, model})` + `updateSessionModeling(...)`.
- D4. `AgentRunner`/`SessionRunOrchestrator` يحدّثان `providerId`+`model` للجلسة عند التبديل المكتشف.
- D5. اختبارات: تبديل مزود الجلسة يُكتب في DB ويُقرأ في الاستعادة.

### المرحلة E: الأحداث + invalidateVolatile

- E1. إضافة `capabilitiesChanged` + `modelSwitched` لـ `CanonicalEventTypes`.
- E2. بعد `model.set_default` نجاح → `invalidate()` + `invalidateVolatile()` + emit `capabilities_changed`.
- E3. بعد `provider.save_api_key`/`save_custom_endpoint`/`auth.start` → `invalidateProvider(p)` + emit `capabilities_changed`.
- E4. `AgentRunner` يكتشف التبديل بين turns → يحدّث الجلسة + `invalidateVolatile()` + emit `model_switched`.
- E5. `AgentContextAssembler.invalidateVolatile()` تضبط `_volatileCache = null`.
- E6. اختبارات بروتوكول: الاستجابات تحمل `request_id`; `capabilities_changed` payload صحيح; `model_switched` يُبَث بـ `session_id` + prev/new.

### المرحلة F: aggregator `provider.configured_options`

- F1. تنفيذ أمر `provider.configured_options` في `SanadProtocolBridge`: يجمع `provider.list_configured` + `model.options` per provider في خريطة واحدة.
- F2. إضافة `providerConfiguredOptions` + `providerConfiguredOptionsResult` لـ `CanonicalEventTypes`.
- F3. قبول `fetch_live` اختياري لجلب النماذج حياً لكل مزود.
- F4. اختبارات: aggregator يرجع هرماً صحيحاً; فشل جلب نماذج مزود واحد لا يكسر الكل (يرجع مزوده بقائمة فارغة + علامة `live_fetch_failed`).

### المرحلة G: الواجهة — محدد هرمي + تمرير provider_id

- G1. إنشاء `ProviderRuntimeCubit` + `ProviderRuntimeState` + `ProviderModelGroup`.
- G2. تسجيله في `app_providers.dart` مرتبطاً بالجهاز النشط.
- G3. الاستماع لـ `capabilities_changed` و `model_switched` في `SanadSocketService` + `EventRouter`.
- G4. `loadConfiguredOptions()` يستدعي `provider.configured_options`.
- G5. إنشاء `ModelPickerDialog` (dialog مخصص) يعرض الهرم مع بحث + رؤوس مجموعات.
- G6. تعديل `_buildModelSelector` لفتح `ModelPickerDialog` بدل `PopupMenuButton`.
- G7. `selectModel` → `selectModeling({providerId, model})` في `ConversationInputCubit`.
- G8. `_nextMessageSelectionByAgentId` record بدل `_nextMessageModelByAgentId` في `SessionMessagesCubit`.
- G9. تمرير `provider_id`+`model` في `think` payload عند الإرسال.
- G10. pill في `StatusBar` يعرض `activeProviderId/activeModel` للجلسة المحددة.
- G11. علامة `model_switched` في transcript الواجهة (system marker).
- G12. اختبارات widget: فتح الـ picker يعرض المجموعات; اختيار مزود مختلف يحدّث `nextMessageProviderId`; إرسال رسالة يمرّر `provider_id` في payload; `capabilities_changed` يعيد تحميل الهرم; `model_switched` يُدرج علامة transcript.

### المرحلة H: الوثائق والتحقق

- H1. تحديث `sanad-agent/agent/AGENTS.md` (AgentRuntimeService كـ adapter cache مركّب + إبطال mtime + توجيه per-message).
- H2. تحديث `sanad-agent/client/AGENTS.md` (محدد هرمي + ProviderRuntimeCubit + capabilities_changed + model_switched).
- H3. تحديث `sanad-agent/agent/lib/interfaces/AGENTS.md` (Turn Contract يضم `provider_id`; `provider.configured_options`; `model_switched`).
- H4. تحديث `sanad-agent/agent/lib/evolution/AGENTS.md` (SessionState.providerId + updateSessionModeling).
- H5. تحديث `sanad-agent/agent/lib/engine/AGENTS.md` (AgentRuntimeService + _adapterForTurn + invalidateVolatile + لا حقن نص تبديل).
- H6. تحديث `docs/technical/provider_protocol.md` (أمر `provider.configured_options` + حدث `model_switched` + `provider_id` في think).
- H7. تحديث `docs/llms.txt` إن لزم.

## معايير القبول

1. كل رسالة `think` يمكن أن تحمل `provider_id`+`model` صراحةً، والوكيل يوجّه الطلب للمزود/النموذج المحدد.
2. محادثتان نشطتان في نفس العملية تستخدمان مزودين/نموذجين مختلفين دون تأثير متبادل (عزل هيكلي عبر `Map<RouteSignature, LLMAdapter>` + `AgentRunner` per-session).
3. اختيار `provider+model` من الواجهة يُرفق بالرسالة الجديدة فقط، لا يبدّل حالة عالمية، لا يرسل `provider.switch_for_session`.
4. بعد `model.set_default`, المحادثات الجديدة التالية تستخدم المزود الجديد كافتراضي بدون restart (عبر إبطال mtime + `invalidate()`).
5. قائمة النماذج في الواجهة هرية (مزود → نماذج) وتتحدّث بعد `capabilities_changed`.
6. فشل بناء adapter جديد يرمي للرسالة المعنية فقط دون كسر cache القائم أو الجلسات الأخرى.
7. `Config._ensureFreshEnv()` يلتقط تغييرات `.env` دون استدعاء `reload()` يدوي.
8. `ProviderCredentialResolver.resolveActive(providerId)` يُجدد OAuth tokens المنتهية على طريق `think` الفعلي per-message.
9. علامة `model_switched` durable تُسجَّل في transcript وتُبَث كحدث، **ولا تُحقن كنص في سياق LLM** (الحفاظ على prompt cache).
10. CLI (`sanad setup` / `sanad chat`) والواجهة يشتركان نفس `Config` + `AgentRuntimeService` + `ProviderCredentialResolver`.
11. لا توجد إعادة تشغيل تلقائية كافتراض عند تبديل المزود/النموذج.
12. لا يوجد `switchModel()` عالمي ولا atomic rollback معقد (الـ cache append-only يلغي الحاجة).
13. `flutter analyze` و `dart analyze` بدون أخطاء؛ كل الاختبارات ناجحة.

## خطة التحقق

- اختبارات وحدة لـ `Config._ensureFreshEnv`:
  - تغيير `.env` بين قراءتين يُرجع قيماً جديدة.
  - عدم التغيير لا يقرأ من القرص (تحقق عبر spy على `readAsLinesSync`).
  - `reload()` يجبر القراءة.
- اختبارات وحدة لـ `AgentRuntimeService`:
  - `adapterFor(sig)` بنفس signature يرجع نفس adapter (cache hit).
  - signature مختلف (provider أو model أو baseUrl) يبني adapter مختلف.
  - فشل بناء adapter يرمي دون مسح/تغيير cache القائم.
  - `invalidate()` يمسح كل الـ adapters؛ الاستدعاء التالي يبني من جديد.
  - `invalidateProvider(p)` يمسح adapters الخاصة بـ `p` فقط.
  - `_sdkCache` key يشمل apiKey؛ تغيير المفتاح يبني sdk جديد.
- اختبارات وحدة لـ `AgentTurnRequest` + `CanonicalToAgent`:
  - `think` بـ `provider_id='anthropic'` يمرّره لـ `AgentTurnRequest.providerId`.
  - بدون `provider_id` يبقى `null` (fallback للـ Config).
- اختبارات وحدة لـ `SessionManager`:
  - `createSession(providerId: 'anthropic', model: 'claude-...')` يكتب `provider_id` في DB.
  - `updateSessionModeling` يحدّث `provider_id`+`model` معاً.
  - استعادة جلسة قديمة بدون `provider_id` → `providerId == null` (لا crash).
- اختبارات وحدة لـ `AgentRunner._adapterForTurn`:
  - `providerId='anthropic'` + `model='claude-...'` → adapter من نوع `BaseAnthropicAdapter`.
  - `providerId=null` → fallback لـ `Config.resolveProviderName()`.
- اختبارات بروتوكول:
  - `model.set_default` → `capabilities_changed` يُبَث بـ `configured_providers` كامل.
  - `provider.save_api_key` → `invalidateProvider(p)` + `capabilities_changed`.
  - `provider.configured_options` → خريطة `{provider_id → [models]}` صحيحة.
  - تبديل per-message → `model_switched` يُبَث بـ `session_id` + `prev/new`; `provider_id` يصل لـ `AgentTurnRequest`.
- اختبارات widget:
  - `ModelPickerDialog` يعرض مجموعات حسب `ProviderModelGroup`.
  - اختيار `{providerId, modelId}` يضبط `nextMessageProviderId`+`nextMessageModel`.
  - إرسال رسالة يمرّر `provider_id`+`model` في `think` payload.
  - `capabilities_changed` يعيد تحميل الهرم.
  - `model_switched` يُدرج علامة transcript + يحدّث pill.
- اختبار تكامل (daemon-backed):
  - إعداد مزود openai, إرسال think بـ `provider_id='openai'`, تأكد استخدامه.
  -在同一 العملية افتح جلسة ثانية و أرسل think بـ `provider_id='anthropic'`, تأكد استخدام anthropic دون تأثير على جلسة openai.
  - `model.set_default` لمزود anthropic, إنشاء جلسة جديدة (بدون `provider_id`), تأكد استخدام anthropic بدون restart.
  - تبديل مزود الجلسة الأولى من openai إلى anthropic عبر رسالة جديدة, تأكد عدم فقدان التاريخ و emit `model_switched`.

## التخزين والأمان

- لا تغيير في مواقع التخزين: `.env` للمفاتيح البسيطة, `provider_auth.json` لـ OAuth.
- `AgentRuntimeService` لا يطبع credentials في cache keys أو الـ logs. الـ `cacheKey` = `providerId/model` فقط (بدون مفاتيح).
- `_sdkCache` key يشمل apiKey داخلياً لكن لا يُسجَّل ولا يُعرض.
- `Config._ensureFreshEnv()` لا يخزّن محتوى `.env` في حقول قابلة للتسريب.
- `think` payload يمكن أن يحمل `provider_id`+`model`; لا `api_key` في `think` (المفاتيح تأتي من `ProviderCredentialResolver`).
- `model_switched` payload لا يحمل credentials.

## اعتبارات مستقبلية (خارج النطاق)

- `variant`/reasoning-effort كمحور منفصل عن `model`.
- Downgrading reasoning parts عبر المزودات عند replay التاريخ (كما في `to-llm-message.ts:66-89`).
- `promptCacheKey = session.id` في OpenAI adapter للحفاظ على prompt cache عبر تبديل النماذج داخل نفس المزود.
- credential pool متعدد الحسابات لكل مزود.
- نموذج تسمية موحّد `"provider/model"` للـ CLI والـ config.
- ربط الـ UI selection بـ `recent`/`favorite` persisted (كما في `local.tsx`).

---

## Checklist التنفيذ

### المرحلة A: إبطال mtime في Config

- [x] A1. إضافة `_envMtime`/`_envSize` و `_ensureFreshEnv()` لـ `Config`.
- [x] A2. استدعاء `_ensureFreshEnv()` في getters رئيسية.
- [x] A3. إضافة `Config.reload()` عام.
- [x] A4. اختبارات `Config._ensureFreshEnv`.

### المرحلة B: RouteSignature + AgentRuntimeService (adapter cache مركّب)

- [x] B1. إنشاء `RouteSignature` value object.
- [x] B2. إنشاء `AgentRuntimeService` (`adapterFor` + `currentFor` + `invalidate` + `invalidateProvider`).
- [x] B3. نقل منطق بناء adapter من `di.dart` إلى `adapterFor()`.
- [x] B4. تسجيل `AgentRuntimeService` في `di.dart`.
- [x] B5. `LLMAdapter` proxy + `ContextEngine` يستخدم الافتراضي.
- [x] B6. `AgentRunner._adapterForTurn()` + استبدال استدعاءات `adapter`.
- [x] B7. ربط `ProviderCredentialResolver.resolveActive(providerId)` ببناء adapter.
- [x] B8. اختبارات `AgentRuntimeService`.

### المرحلة C: تمرير provider_id per-message

- [x] C1. إضافة `providerId` لـ `AgentTurnRequest` + `toMetadata()`.
- [x] C2. `CanonicalToAgent` يقرأ `payload['provider_id']` في `think`/`steer`.
- [x] C3. `AgentRunner._adapterForTurn` يستخدم `turnRequest.providerId` كأولوية.
- [x] C4. اختبارات توجيه per-message.

### المرحلة D: SessionState.providerId + thinkingMode + migration

- [x] D1. إضافة `providerId` + `thinkingMode` لـ `SessionState` (constructor, toMap, fromMap).
- [x] D2. `SessionDB` migration: عمودا `provider_id TEXT` + `thinking_mode TEXT` في `sessions`.
- [x] D3. `SessionManager.createSession({providerId, model, thinkingMode})` + `updateSessionModeling({providerId, model, thinkingMode})`.
- [x] D4. `AgentRunner`/`SessionRunOrchestrator` يحدّثان الجلسة بالثلاثة عند التبديل.
- [x] D5. اختبارات SessionManager (حفظ + استعادة الثلاثة).

### المرحلة E: الأحداث + invalidateVolatile

- [x] E1. إضافة `capabilitiesChanged` + `modelSwitched` لـ `CanonicalEventTypes`.
- [x] E2. `model.set_default` → `invalidate()` + `invalidateVolatile()` + emit `capabilities_changed`.
- [x] E3. `provider.save_api_key`/`save_custom_endpoint`/`auth.start` → `invalidateProvider(p)` + emit.
- [x] E4. `AgentRunner` يكتشف التبديل → تحديث جلسة + `invalidateVolatile()` + emit `model_switched`.
- [x] E5. `AgentContextAssembler.invalidateVolatile()`.
- [x] E6. اختبارات بروتوكول.

### المرحلة F: aggregator `provider.configured_options`

- [x] F1. تنفيذ `provider.configured_options` في `SanadProtocolBridge`.
- [x] F2. إضافة `providerConfiguredOptions`/`providerConfiguredOptionsResult` لـ `CanonicalEventTypes`.
- [x] F3. قبول `fetch_live` اختياري.
- [x] F4. اختبارات aggregator (فشل جزئي لا يكسر الكل).

### المرحلة G: الواجهة — محدد هرمي + تمرير provider_id

- [x] G1. إنشاء `ProviderRuntimeCubit` + `ProviderRuntimeState` + `ProviderModelGroup`.
- [x] G2. تسجيل في `app_providers.dart` مرتبطاً بالجهاز النشط.
- [x] G3. الاستماع لـ `capabilities_changed` و `model_switched` في `SanadSocketService`.
- [x] G4. `loadConfiguredOptions()` يستدعي `provider.configured_options`.
- [x] G5. إنشاء `ModelPickerDialog` (dialog مخصص هرمي **مع حقل بحث/فلترة**).
- [x] G6. تعديل `_buildModelSelector` لفتح `ModelPickerDialog`.
- [x] G7. `selectModel` → `selectModeling({providerId, model, thinkingMode})` + ضبط thinkingMode افتراضي للنموذج الجديد.
- [x] G8. `_nextMessageSelectionByAgentId` record (الثلاثة) في `SessionMessagesCubit`.
- [x] G9. تمرير `provider_id`+`model`+`thinking_mode` في `think` payload.
- [x] G10. pill في `StatusBar` (يعرض الثلاثة).
- [x] G11. علامة `model_switched` في transcript.
- [x] G12. استعادة `providerId`+`model`+`thinkingMode` من بيانات الجلسة عند فتحها وضبطها كـ `nextMessageSelection` مبدئي + عرضها في الـ pill.
- [x] G13. اختبارات widget (البحث + الهرم + الاختيار + الاستعادة + model_switched).

### المرحلة H: الوثائق

- [x] H1. تحديث `sanad-agent/agent/AGENTS.md`.
- [x] H2. تحديث `sanad-agent/client/AGENTS.md`.
- [x] H3. تحديث `sanad-agent/agent/lib/interfaces/AGENTS.md`.
- [x] H4. تحديث `sanad-agent/agent/lib/evolution/AGENTS.md`.
- [x] H5. تحديث `sanad-agent/agent/lib/engine/AGENTS.md`.
- [x] H6. تحديث `docs/technical/provider_protocol.md`.
- [x] H7. تحديث `docs/llms.txt`.
