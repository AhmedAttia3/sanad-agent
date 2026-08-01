---
title: "المرحلة الثلاثون: حالات تعافي الجلسة وحدود طلبات المزودين"
description: "إضافة قناة عامة بين الوكيل والواجهة لحالات الانتظار والأخطاء القابلة للتعافي، وتطبيق rate limit قابل للضبط لكل ProviderInstance مع استئناف الجلسة بمزود بديل دون كسر ترتيب التنفيذ."
phase: 30
depends_on:
  - "docs/technical/provider_protocol.md"
  - "docs/technical/communication_protocols.md"
  - "docs/technical/agent_database_schema.md"
  - "docs/plans/29-provider-instances-multi-account-model-cache.md"
status: "complete"
---

# خطة المرحلة الثلاثين: حالات تعافي الجلسة وحدود طلبات المزودين

## 1. الملخص التنفيذي

تضيف هذه المرحلة طبقة عامة للتعافي أثناء تنفيذ الجلسة، بحيث لا تظهر مشاكل
runtime كتعطل صامت أو كرسائل خطأ عشوائية داخل المحادثة. يرسل الوكيل أحداثًا
رسمية لكل العملاء المفتوحين على الجلسة عندما يتوقف التنفيذ مؤقتًا، أو ينتظر
نافذة rate limit، أو يحتاج retry يدويًا.

أول استخدام لهذه الطبقة هو ضبط حد طلبات المزودين لكل `ProviderInstance`.
القيمة الافتراضية لكل القوالب تأتي من `ProviderProfile.defaultRequestsPerMinute`:
كل المزودين `0` بمعنى غير محدود، وNVIDIA NIM بقيمة `38 requests/minute`
لتفادي حدود `429` الصارمة. عند الوصول للحد ينتظر الوكيل تلقائيًا، ويظهر
للواجهة سبب الانتظار والمدة والحد المسموح. يستطيع المستخدم إيقاف التنفيذ أو
استكمال الجلسة بمزود آخر؛ كما يستطيع الوكيل، عند تفعيل الإعدادات، الانتقال
تلقائيًا إلى `ProviderInstance` بديلة مؤهلة دون كسر ترتيب queue الجلسة.

أظهر تدقيق ما بعد التنفيذ أن بعض مسارات recovery قد تحبس الجلسة دون إجراء
فعال، وأن تبديل المزود لا يبدل النموذج معه، وأن الحالة لا تعاد بعد reconnect.
لذلك تبقى الخطة قيد التنفيذ حتى إغلاق مرحلة التصحيح H ومعاييرها الجديدة.

## 2. المشكلة

- بعض المزودين مثل NVIDIA NIM يرجعون `429` عند تخطي عدد محدد من الطلبات في
  الدقيقة.
- الاعتماد على retry بعد الخطأ وحده يجعل تجربة المستخدم بطيئة وغامضة.
- الانتظار الصامت يجعل المستخدم يظن أن الوكيل تعطل.
- أخطاء أخرى، مثل الشبكة أو نفاد الرصيد أو حدود استخدام طويلة، تحتاج طريقة
  عرض موحدة فوق مدخل المحادثة.
- قد تكون عدة واجهات مفتوحة على الجلسة نفسها؛ لا يجوز أن تعتمد الواجهة على
  ضغط الزر محليًا كمصدر حقيقة.
- عندما ينتظر تنفيذ حالي مزودًا وصل إلى limit، يجب ألا يحبس ذلك باقي queue
  الجلسة على المزود القديم إذا اختار المستخدم مزودًا آخر.
- عند تفعيل الانتقال التلقائي يجب ألا يستخدم الوكيل حسابًا لا يريد المستخدم
  استهلاكه تلقائيًا، حتى لو كان من النوع نفسه أو يملك النموذج نفسه.
- قد يظهر زر `Stop` بينما يمنع client إرسال الأمر لأن الجلسة لم تعد processing.
- إعادة تشغيل client تفقد notice الحية رغم بقاء العمل المعلق والqueue في الوكيل.
- تغيير provider وحده قد يعيد استخدام model id خاصًا بالمزود السابق.
- تصنيف `unknown` القابل للتكرار افتراضيًا يهدر المحاولات ويخفي الخطأ الحقيقي.

## 3. القرارات المعمارية الملزمة

1. الوكيل هو مصدر الحقيقة لكل حالة تعافي؛ الواجهة ترسل أوامر فقط ولا تفترض
   نجاحها قبل وصول حدث من الوكيل.
2. حالات التعافي عامة لكل أخطاء runtime، وليست خاصة بالمزودين فقط.
3. تصنيف الأخطاء مركزي ومهيكل؛ لا تكرر الواجهة أو adapters تفسير نصوص
   الأخطاء بصورة متفرقة.
4. rate limit يطبق على `ProviderInstance.id` لا على اسم القالب أو الجلسة.
5. القيمة `requests_per_minute = 0` تعني غير محدود.
6. `ProviderProfile.defaultRequestsPerMinute` هو مصدر القيمة الافتراضية عند
   إنشاء instance إذا لم ترسل الواجهة قيمة صريحة؛ إرسال `0` صراحة يعني غير
   محدود ولا يستبدل بقيمة القالب.
7. NVIDIA NIM يحدد `defaultRequestsPerMinute = 38`، وباقي القوالب `0`.
8. queue الجلسة يبقى queue أعمال الجلسة؛ المزود route قابل للتغيير عند
   الاستئناف.
9. عند تغيير مزود الجلسة أثناء الانتظار، يستأنف الوكيل أول عمل معلق في queue
   بالمزود الجديد، ثم يكمل باقي الرسائل المعلقة بالترتيب.
10. إرسال رسالة مع provider override يجعل هذا المزود هو الافتراضي التالي
   للجلسة حتى يغيره المستخدم مرة أخرى، انسجامًا مع المسار الحالي.
11. الانتقال التلقائي بين المزودين لا يحدث إلا إذا كان الإعداد العام مفعلًا
    وكانت instance الهدف تسمح بذلك عبر `allow_auto_failover`.
12. عند الانتقال التلقائي يبحث الوكيل في كل instances المؤهلة، مع أولوية
    لنفس `templateId` ثم instances أخرى لديها نفس النموذج المطلوب، ولا يستخدم
    instance عليها rate limit أو exhaustion معروف.
13. يتم احترام `429` الحقيقي حتى مع وجود limiter محلي، خاصة `Retry-After`.
14. لا retry بلا نهاية؛ retries التلقائية محدودة وتتحول إلى حالة تحتاج تدخل
    المستخدم عند استمرار الفشل.
15. تستخدم retries التلقائية jittered backoff لتفادي عودة عدة جلسات لنفس
    المزود في اللحظة نفسها.
16. أخطاء billing/credit/quota النهائية لا تحصل على retry تلقائي بنفس
    الاعتماد؛ تتحول إلى blocked أو auto failover عند وجود بديل مؤهل.
17. أخطاء الشبكة قد تحصل على محاولة تعافي نقل واحدة، مثل إعادة بناء HTTP
    client/connection، قبل عرض retry يدوي.
18. إيقاف الجلسة يلغي الانتظار أو retry المجدول ولا يرسل طلبًا لاحقًا.
19. السجلات تبقى نظيفة: أحداث lifecycle فقط، دون log لكل ثانية timer.
20. تطبق قاعدة `Never-Trapped Session`: كل `waiting` أو `blocked` أو `fatal`
    مرتبط بعمل معلق يوفر `Stop` فعالًا يعيد الجلسة إلى `idle`.
21. `Stop` لا يعتمد في client على `isProcessing` إذا توجد recovery notice؛ يلغي
    العمل الجاري والانتظار ويمسح queue، مع إبقاء السجل والنتائج المكتملة والرد الجزئي.
22. route الاستئناف قيمة ذرية من `provider_instance_id + model_id`، وتطبق على
    العمل المعلق والqueue وتفضيلات الجلسة معًا.
23. `Retry` أو رسالة جديدة أثناء recovery يستأنفان العمل المعلق أولًا باستخدام
    route المحدد حاليًا في الواجهة، ثم يكملان queue بنظام FIFO.
24. حالة recovery النشطة تعاد داخل session history snapshot عبر المسار نفسه
    المستخدم لاسترجاع `queued_messages`، وتستعاد بعد restart من durable state
    بدل الاعتماد على الذاكرة فقط.
25. يبني الوكيل `message` كنص عرض واحد: رسالة تطبيق منسقة ثم رسالة المزود
    الأصلية بعد redaction؛ لا تركب الواجهة رسائل الأخطاء بنفسها.
26. auto-retry قرار خاص بالتصنيف؛ أخطاء `4xx` الحتمية و`unknown` لا يعاد
    تنفيذها تلقائيًا افتراضيًا، ولا يستبدل السبب الأصلي عند نفاد المحاولات.

## 4. تجربة المستخدم المستهدفة

### 4.1 انتظار تلقائي

عند الوصول إلى حد محلي أو `429` قابل للانتظار، يظهر banner فوق مدخل المحادثة:

```text
NVIDIA NIM rate limit reached.
Continuing automatically in 24s.
Limit: 38 requests/min.
```

الأفعال المتاحة:

- `Stop`: يلغي التنفيذ الجاري وأي retry مجدول ويحذف queue غير المنفذة.
- `Change Provider`: يعيد استخدام model picker الحالي ويعيد provider وmodel معًا.

تحدث الواجهة العداد محليًا من `resume_at` أو `retry_after_ms`، لكنها لا تغير
حالة الجلسة النهائية إلا بعد وصول event جديد من الوكيل.

### 4.2 خطأ يحتاج retry يدوي

عند خطأ غير مناسب للانتظار التلقائي، يظهر banner:

```text
Connection failed.
The agent could not reach the runtime service.
Provider response: Unknown Model, please check the model code.
```

الأفعال المتاحة حسب الحالة:

- `Retry`
- `Change provider`
- `Open provider settings`

أمثلة الحالات:

- خطأ شبكة بعد retry تلقائي محدود.
- نفاد الرصيد أو quota exhausted.
- API key غير صحيح.
- خطأ tool أو runtime قابل لإعادة المحاولة.

رسالة المزود لا تستبدل رسالة التطبيق ولا تعرض قبل تنقيح المفاتيح والتوكنات
والرؤوس الحساسة. إذا لم توجد رسالة أصلية مفيدة، يعرض التطبيق الرسالة المنسقة فقط.

### 4.3 تغيير المزود أثناء الانتظار

إذا توقف التنفيذ أثناء خطوة داخلية مثل إرسال tool result إلى NVIDIA NIM، ثم
اختار المستخدم OpenAI:

1. لا يبدأ الوكيل آخر رسالة أرسلها المستخدم مباشرة.
2. لا يتجاوز tool continuation المعلق.
3. يستأنف نفس نقطة التوقف، بنفس history وtool result، لكن عبر OpenAI.
4. بعد انتهاء العمل الحالي، يكمل باقي رسائل queue بالترتيب.
5. يصبح OpenAI مزود الجلسة الافتراضي لباقي الرسائل المعلقة والجديدة، إلا إذا
   حملت رسالة لاحقة override صريحًا.
6. يرسل model picker معرّف النموذج الخاص بالمزود الجديد؛ لا يحتفظ runtime
   بمعرّف النموذج السابق ولا يخمن نموذجًا بديلًا.

### 4.4 الانتقال التلقائي بين المزودين

إذا كان `PROVIDER_AUTO_FAILOVER=true` وكانت هناك instance بديلة تسمح
بالانتقال التلقائي، يستطيع الوكيل التحويل دون انتظار اختيار المستخدم:

```text
NVIDIA NIM is rate limited.
Continuing automatically with OpenAI Work.
```

تعرض الواجهة هذا كحالة runtime صادرة من الوكيل، وليس كتغيير محلي. داخل شاشة
تعديل كل provider instance يظهر سويتش `Allow automatic failover to this
provider` بلون تحذيري ونص واضح:

```text
This provider may be used automatically when another provider fails.
```

القيمة الافتراضية للسويتش مفعلة، لكن المستخدم يستطيع تعطيلها للحسابات التي لا
يريد استهلاكها تلقائيًا مثل حساب شخصي أو حساب عمل حساس.

### 4.5 استعادة السيطرة والاستئناف

- يظهر `Stop` في composer وbanner طوال وجود عمل معلق، حتى لو كانت الحالة
  المرئية `blocked` أو `waiting` وليست processing.
- الضغط على `Stop` ينتظر حدث `stopped`/`cleared` من الوكيل ثم يعيد الواجهة إلى idle.
- `Retry` يستخدم provider/model المحددين حاليًا، لا route الذي فشل سابقًا.
- إرسال رسالة جديدة أثناء recovery يعمل كطلب استئناف بالroute الحالي ثم يضع
  الرسالة الجديدة بعد العمل المعلق في FIFO.
- عند reconnect أو إعادة تشغيل client، يعيد history snapshot الـnotice والqueue
  معًا، فتظهر الإجراءات نفسها في كل clients.

## 5. نموذج Runtime Recovery

### 5.1 الحالة المخزنة في الوكيل

يحتاج `SessionRunOrchestrator` إلى حالة تعافي نشطة لكل جلسة:

```text
session_id
request_id
run_id أو turn_id إن وجد
status: waiting | blocked | resuming | cleared | fatal
reason
message/title، ويتضمن message تفاصيل المزود المنقحة عند توفرها
provider_instance_id اختياري
model_id اختياري
provider_display_name اختياري
retry_after_ms أو resume_at اختياري
actions[]
created_at, updated_at
```

الحالة النشطة محفوظة في الذاكرة ومُعكسة بصورة durable في `state.db`. يستعيد
daemon عند التشغيل notice والعمل المعلق والqueue ومؤقت `resume_at`، بما في ذلك
انتظار حدود طويلة مثل خمس ساعات. جدول `session_work_items` هو مصدر الحقيقة
الدائم للعمل، وتستعيد الواجهة الحالة عبر أحداث الوكيل وhistory snapshot.

### 5.2 الأحداث من الوكيل للواجهة

تضاف أحداث canonical عامة:

```text
session.runtime_notice
session.runtime_notice_cleared
```

Payload مقترح:

```json
{
  "session_id": "...",
  "request_id": "...",
  "status": "waiting",
  "reason": "provider_rate_limit",
  "severity": "warning",
  "title": "NVIDIA NIM rate limit reached",
  "message": "Continuing automatically when the provider window resets.",
  "provider_instance_id": "...",
  "provider_display_name": "NVIDIA NIM",
  "retry_after_ms": 24000,
  "resume_at": "2026-07-09T12:00:24.000Z",
  "limit": {
    "requests_per_minute": 38
  },
  "actions": ["stop", "continue_with_provider"]
}
```

للأخطاء التي تحتاج retry يدوي:

```json
{
  "session_id": "...",
  "request_id": "...",
  "status": "blocked",
  "reason": "network_error",
  "severity": "error",
  "title": "Connection failed",
  "message": "The agent could not reach the service.\n\nProvider response: Connection reset by peer",
  "actions": ["retry", "change_provider"]
}
```

### 5.3 أوامر من الواجهة للوكيل

تضاف أوامر عامة:

```text
session.runtime_retry
session.runtime_stop
session.runtime_continue_with_provider
```

الأمر `session.runtime_continue_with_provider` يحمل:

```json
{
  "session_id": "...",
  "request_id": "...",
  "provider_instance_id": "...",
  "model_id": "..."
}
```

يعيد الوكيل بث event جديد مثل `resuming` قبل استئناف التنفيذ، ثم `cleared`
عند زوال الحالة.

يحمل `session.runtime_retry` route الحالي أيضًا عند توفره. أما الرسالة الجديدة
أثناء recovery فتحمل route كالمعتاد، ويحوّلها orchestrator إلى resume للعمل
المعلق قبل إبقاء الرسالة الجديدة في queue.

### 5.4 Snapshot وإعادة الاتصال

تمدد استجابة `get_session_history` بحقل `runtime_notice` اختياري بجانب
`queued_messages`. يخزن الوكيل الحالة في الذاكرة ويعيدها لكل client يفتح الجلسة؛
يعيد client hydration للرسائل والqueue والnotice في عملية واحدة. إعادة تشغيل
daemon واستعادة execution point من قاعدة البيانات تبقى خارج النطاق.

## 6. Rate Limit لكل ProviderInstance

### 6.1 التخزين

تمدد `ProviderInstance` بحقول:

```text
requests_per_minute: int
allow_auto_failover: bool
rate_limit_enabled: bool مشتق من requests_per_minute > 0 أو مخزن صراحة
```

الخيار الأبسط والمفضل:

- تخزين `requests_per_minute INTEGER NOT NULL DEFAULT 0`.
- تخزين `allow_auto_failover INTEGER NOT NULL DEFAULT 1`.
- اعتبار `0` غير محدود، وأي رقم أكبر من صفر مفعل.
- لا حاجة لحقل `enabled` منفصل في النسخة الأولى.

يجب تحديث:

- `AgentStateDatabase`
- `ProviderInstance`
- `ProviderInstanceRepository`
- `ProviderInstanceService`
- `provider.instance.create`
- `provider.instance.update`
- DTOs في Flutter.

### 6.2 القيم الافتراضية

يمدد `ProviderProfile` بحقل:

```text
defaultRequestsPerMinute: int
```

القيم:

- كل القوالب: `defaultRequestsPerMinute = 0`.
- قالب `nvidia`: `defaultRequestsPerMinute = 38`.
- Custom Provider يبقى `0` إلا إذا ضبطه المستخدم.

عند إنشاء instance:

- إذا أرسلت الواجهة `requests_per_minute` صراحة، حتى لو كانت `0`، يستخدمها
  الوكيل كما هي.
- إذا لم ترسل الواجهة الحقل، يستخدم الوكيل `profile.defaultRequestsPerMinute`.

تعرض الواجهة قيمة القالب الافتراضية للمستخدم وتوضح أن `0 = Unlimited`.
القيمة الافتراضية تطبق عند إنشاء instance جديدة فقط. لا تغير instances موجودة
إلا عبر migration مقصود وواضح أو إعداد يدوي من المستخدم.

### 6.3 التنفيذ

تضاف خدمة:

```text
ProviderRateLimiter
```

المسؤوليات:

- يحتفظ بنافذة طلبات لكل `provider_instance_id`.
- يمنح permit قبل استدعاء LLM.
- إذا لم يوجد permit، يحسب وقت الاستئناف ويرجع حالة انتظار قابلة للإلغاء.
- يدعم cancellation عند stop أو تغيير provider.
- لا يؤثر على provider instances أخرى.

تطبيق الحد يكون عبر wrapper:

```text
RateLimitedLLMAdapter implements LLMAdapter
```

الـ wrapper يحيط بـ:

- `generateResponse`
- `generateStream`
- `getAvailableModels` إذا كان المزود قد يحسب `/models` ضمن limit.

لا يوضع المنطق داخل `BaseOpenAIAdapter` فقط، حتى يبقى عامًا لكل adapters.

## 7. التعامل مع 429 والأخطاء

### 7.1 مصنف أخطاء مركزي

تضاف طبقة تصنيف عامة بأسماء وعقود Sanad:

```text
RuntimeFailureReason:
auth | billing | rate_limit | upstream_rate_limit | overloaded
timeout | network_error | context_overflow | payload_too_large
model_not_found | content_policy_blocked | tool_runtime_error
local_runtime_error | unknown
```

يرجع المصنف قرارًا موحدًا:

```text
notice_status: waiting | blocked | fatal
retryable: bool
auto_retry_after_ms اختياري
allow_auto_failover: bool
allow_manual_retry: bool
ui_actions[]
```

يستخدم المصنف:

- HTTP status مثل `401`, `402`, `403`, `404`, `429`, `500`, `503`.
- body/error code إن وجد.
- `Retry-After`.
- patterns ضيقة للتمييز بين billing، rate limit، overload، وusage reset.
- سياق المزود والنموذج والـprovider instance.
- JSON المتداخل ورسالة upstream عند وجود aggregator، دون الاعتماد على
  `error.toString()` وحده.

### 7.2 429

إذا وصل رد `429` رغم limiter:

1. تحل طبقة HTTP الانتظار من `retry-after-ms` ثم `Retry-After` ثم reset موثوق في header/body؛ دون raw headers أو تعديل reason.
2. إذا لا يوجد، يسجل cooldown محلي لمدة دقيقة على نفس `ProviderInstance`.
3. يرسل `session.runtime_notice` بحالة `waiting`.
4. يمنع أي جلسة أخرى من إرسال طلب لنفس instance أثناء cooldown.
5. يعيد نفس الطلب تلقائيًا بعد الانتظار.
6. retries التلقائية محدودة، مثل `2` أو `3`.
7. إذا استمر `429`، تتحول الحالة إلى `blocked` مع أفعال `retry` و
   `change_provider`.

#### 7.2.1 عقد اكتشاف موعد الاستئناف

تطبع طبقة HTTP الترويسات إلى lowercase، ثم تنتج `Duration?` موحدة وفق الآتي:

1. `retry-after-ms` الصالح بالمللي ثانية.
2. `Retry-After` الصالح كعدد ثوان أو HTTP-date.
3. reset خاص بالمزود عند غياب السابقين فقط: صيغ OpenAI
   `x-ratelimit-{remaining,reset}-*` وصيغ Anthropic
   `anthropic-ratelimit-*-{remaining,reset}`.
4. reset صريح داخل body، مثل `limit will reset at 2026-07-11 04:21:28`.
5. fallback/backoff الحالي إذا لم يوجد hint صالح.

لا يحول reset header إلى انتظار إلا إذا أمكن ربطه ببعد `remaining=0`؛ وعند
نفاد أكثر من بعد يستخدم أبعد reset لازم لزوالها كلها. يقبل reset مدة واضحة
الوحدة أو timestamp مطلقًا؛ ويعامل timestamp النصي بلا timezone كـUTC ما لم
يوفر adapter سياقًا أوضح. القيم الفارغة، السالبة، المنتهية، غير محددة الوحدة،
أو غير القابلة للتحليل لا تصبح انتظارًا طويلًا.

لا يطبق cap قصير خاص بالـbackoff على موعد موثوق من المزود؛ يجب أن تعمل حالة
خمس ساعات مع timer وStop. ولا يخزن أو يرسل raw headers للواجهة. يمكن الاحتفاظ
بتفاصيل limit/remaining/reset منقحة للتشخيص لاحقًا، لكنها ليست مطلوبة الآن.

وجود reset مستقبلي يجعل `usage limit` مؤقتًا وretryable. أما
`insufficient_quota` أو `quota exceeded` بلا reset موثوق فلا يدخل حلقة retry؛
يصنف billing/quota blocked ويعرض رسالة المزود وإجراءات تغيير المزود/الإعدادات.

ليس كل `429` يعامل كـrate limit للحساب:

- `rate_limit`: حد حساب أو مفتاح؛ ينتظر أو ينتقل تلقائيًا إذا وجد بديل مؤهل.
- `upstream_rate_limit`: مزود خلف aggregator وصل للحد؛ لا يعلّم credential
  الحالي كمستنفد، ويفضل failover لنموذج/instance مؤهل.
- `overloaded`: السيرفر مشغول؛ يستخدم backoff ولا يعتبر الحساب مستهلكًا.
- `usage_limit_with_reset`: انتظار تلقائي طويل إذا كان reset واضحًا ومقبولًا
  للمنتج، أو `blocked` مع timer حسب مدة الانتظار.

### 7.3 الأخطاء الأخرى

تصنف الأخطاء إلى:

- `waiting`: يوجد وقت معروف للاستئناف التلقائي.
- `blocked`: يحتاج المستخدم retry أو تغيير إعداد أو تغيير مزود.
- `fatal`: لا يمكن التعافي داخل الجلسة الحالية، ويعرض كخطأ نهائي.

أمثلة:

- `network_timeout`: retry تلقائي واحد اختياري، ثم `blocked`.
- `invalid_api_key`: `blocked` مع `open_provider_settings`.
- `insufficient_quota`: `blocked` مع `change_provider`.
- `tool_runtime_error`: `blocked` مع `retry` إذا كان آمنًا.
- `local_database_error`: `blocked` أو `fatal` حسب قابلية التعافي.

أخطاء billing/credit مثل `402`, `insufficient credits`, `payment required`,
أو `balance_depleted` لا تحصل على retry تلقائي بنفس instance. إذا كان auto
failover مفعلًا ووجدت instance مؤهلة، ينتقل الوكيل إليها؛ وإلا يعرض `blocked`.

أخطاء الشبكة والـtimeouts يمكن أن تحصل على محاولة تعافي نقل واحدة قبل إظهار
banner، مثل إعادة بناء HTTP client أو التخلص من اتصال stale، ثم retry بجداول
jittered backoff محدودة.

سياسة المحاولات ليست رقمًا عامًا: auth/billing/model-not-found/content-policy/
payload/format وSSL verification تفشل مباشرة أو تنتقل حسب القرار؛ network
وtimeout لهما محاولة محدودة؛ overload وrate-limit فقط ينتظران وفق backoff أو
`Retry-After`. يبقى `unknown` blocked مع retry يدوي، وتظل تفاصيل الخطأ الأصلية
موجودة بعد نفاد أي ميزانية تلقائية.

## 8. الانتقال التلقائي وQueue الجلسة

### 8.1 اختيار بديل تلقائي

يقرأ الوكيل إعدادًا عامًا:

```text
PROVIDER_AUTO_FAILOVER=true
```

عند فشل مزود بسبب `rate_limit` مستمر، `billing`, `quota`, أو خطأ مصنف بأنه
قابل للحل بتغيير مزود، يبحث الوكيل عن `ProviderInstance` بديلة وفق الشروط:

- `status = ready`.
- `allow_auto_failover = true`.
- ليست هي instance الفاشلة.
- ليست عليها rate limit أو exhaustion معروف داخل runtime.
- لديها نفس `defaultModel` أو تستطيع تشغيل نفس `model_id` المطلوب كما يظهر في
  cache/metadata الحالية.

الأولوية:

1. نفس `templateId`.
2. أي template آخر لديه نفس `model_id` بالضبط.
3. لا اختيار تلقائي إذا لم يوجد تطابق واضح؛ تتحول الحالة إلى `blocked` مع
   `change_provider`.

لا يستخدم الوكيل نماذج "قريبة" أو بدائل دلالية في هذه المرحلة. ترتيب مخصص
للمستخدم وخريطة تكافؤ النماذج يتركان لمرحلة مستقبلية.

### 8.2 القاعدة العامة

عندما تتوقف الجلسة في حالة recovery، يبقى موقع التنفيذ محفوظًا. الرسائل
الجديدة تدخل queue الجلسة كالمعتاد. تغيير المزود أثناء recovery لا ينفذ آخر
رسالة أولا، بل يغير route الافتراضي للجلسة ثم يستأنف أول عمل معلق.

إذا حدث auto failover، يعامل مثل تغيير مزود صادر من الوكيل: يحدث route
الجلسة، يبث notice لكل clients، ثم يستأنف أول work item معلق بنفس ترتيب queue.

### 8.3 المطلوب من `SessionRunOrchestrator`

- حفظ recovery state المرتبطة بالعمل الجاري.
- قبول أوامر retry/stop/continue_with_provider من أي client.
- عند `continue_with_provider`:
  - تحديث provider وmodel الافتراضيين للجلسة كزوج واحد.
  - إلغاء انتظار المزود القديم.
  - استئناف نفس work item المعلق بالمزود الجديد.
  - بث الحالة لكل clients.
- عند auto failover:
  - اختيار instance مؤهلة وفق السياسة أعلاه.
  - تحديث provider الافتراضي للجلسة إلى instance المختارة.
  - بث notice يذكر المزود القديم والجديد وسبب التحويل.
  - استئناف نفس work item المعلق.
- الحفاظ على FIFO لباقي الرسائل.
- عند `runtime_stop`: إلغاء run/wait، حذف suspended work والqueue، بث stopped
  وcleared، وإتاحة رسالة جديدة فور وصول الأحداث.
  يستخدم الـ client حدث `session.stop_draft_recovery` لمسح queued-messages
  projection ذريًا أمام المستخدم، مما يطابق تنظيف الـ daemon للطابور.
- عند retry أو رسالة جديدة أثناء recovery: أخذ provider/model من الطلب الحالي،
  تحديث العمل المعلق والqueue، ثم الاستئناف قبل تنفيذ الرسالة الجديدة.

### 8.4 علاقة provider override الحالي

عند إرسال رسالة تحمل provider instance جديد، يصبح هذا provider الافتراضي
للجلسة من تلك النقطة فصاعدًا، بما في ذلك الرسائل المعلقة التي لم تبدأ بعد،
إلا إذا حملت رسالة أخرى override لاحقًا. يجب توثيق هذا السلوك في بروتوكول
الجلسات.

## 9. نطاق تعديلات الواجهة

### 9.1 Banner فوق مدخل المحادثة

تضيف الواجهة مكونًا عامًا فوق composer يعرض آخر `runtime_notice` نشط للجلسة.

المكون:

- يستقبل الحالة من store/stream معتمد على أحداث الوكيل.
- يعرض timer عندما توجد `resume_at` أو `retry_after_ms`.
- يعرض الأفعال المرسلة من الوكيل فقط.
- لا يغير الحالة محليًا بعد الضغط؛ ينتظر event من الوكيل.
- يعرض `Stop` لأي notice تحتفظ بعمل معلق، ولا يربط إرسال stop بـ`isProcessing`.
- يستخدم model picker الحالي لتغيير provider/model بدل نافذة provider مستقلة.
- يعرض `message` كما بناها الوكيل، بما فيها تفاصيل المزود المنقحة عند توفرها.

### 9.2 إعدادات provider instance

تضيف شاشة تعديل المزود:

- حقل `Requests per minute` مع توضيح `0 = Unlimited`.
- سويتش `Allow automatic failover to this provider` بلون تحذيري.
- نص يوضح أن تفعيل السويتش يعني أن الوكيل قد يستخدم هذا الحساب تلقائيًا عندما
  يفشل مزود آخر.

### 9.3 تعدد clients

كل client مفتوح على الجلسة يجب أن:

- يستقبل نفس notice.
- يرى زوال notice عند `cleared`.
- يرى `resuming` إذا أرسل client آخر أمر تغيير المزود أو retry.
- يحصل على notice الحالية من history snapshot عند فتح الجلسة بعد reconnect.

## 10. الملفات المتوقعة

- Agent runtime: `agent/lib/core/provider_runtime/`, adapters، `AgentRunner`،
  `SessionRunOrchestrator`، `SanadProtocolBridge`، وcanonical events.
- Client: provider DTO/client، conversation store/cubits/transport، model picker،
  composer، وruntime notice banner.
- Docs: provider/communication/database protocols وأقرب `AGENTS.md` مالك.

## 11. مراحل التنفيذ

### المرحلة A: العقد العام لحالات التعافي

- [x] 1. إضافة أسماء الأحداث والأوامر canonical.
- [x] 2. إضافة model داخلي لـruntime notice.
- [x] 3. بث notice/cleared من الوكيل.
- [x] 4. إضافة client store يستقبل الأحداث دون UI معقد.

### المرحلة B: Rate limit التخزيني

- [x] 1. إضافة `requests_per_minute` و`allow_auto_failover` إلى `ProviderInstance`.
- [x] 2. إضافة عمود SQLite وmigration آمن.
- [x] 3. تحديث create/update/list.
- [x] 4. إضافة `defaultRequestsPerMinute` إلى `ProviderProfile`.
- [x] 5. تطبيق default `38` لقالب `nvidia` و`0` لغيره عند غياب قيمة صريحة.

### المرحلة C: Limiter وadapter wrapper

- [x] 1. تنفيذ `ProviderRateLimiter`.
- [x] 2. تنفيذ `RateLimitedLLMAdapter`.
- [x] 3. ربطه في `AgentRuntimeService`.
- [x] 4. إصدار notice عند الانتظار وإزالته عند الاستئناف.

### المرحلة D: 429 والأخطاء القابلة للتعافي

- [x] 1. تعريف تصنيف أخطاء LLM/runtime.
- [x] 2. التقاط `429` من adapters أو طبقة wrapper.
- [x] 3. احترام `Retry-After`.
- [x] 4. إضافة jittered backoff للانتظار والتكرار.
- [x] 5. التمييز بين `rate_limit`, `upstream_rate_limit`, `overloaded`, و`billing`.
- [x] 6. تحويل استمرار الفشل إلى `blocked`.
- [x] 7. تنفيذ عقد §7.2.1 داخل طبقة HTTP، بما فيه `limit will reset at ...`،
      والتمييز بين usage reset المؤقت وquota الدائم، مع اختبارات precedence.

### المرحلة E: Queue واستئناف بمزود بديل

- [x] 1. إضافة أوامر retry/stop/continue_with_provider.
- [x] 2. حفظ نقطة التوقف القابلة للاستئناف.
- [x] 3. تحديث provider الافتراضي للجلسة عند تغيير المزود.
- [x] 4. استئناف أول work item معلق ثم إكمال queue بالترتيب.
- [x] 5. تنفيذ auto failover عند تفعيل الإعداد العام ووجود instance مؤهلة.

### المرحلة F: UI

- [x] 1. إضافة banner فوق composer.
- [x] 2. عرض timer والحد والسبب.
- [x] 3. أزرار stop/retry/change provider حسب actions.
- [x] 4. إضافة حقل requests-per-minute وسويتش auto-failover التحذيري في إعدادات
      المزود.
- [x] 5. انتظار أحداث الوكيل قبل تغيير الحالة.

### المرحلة G: التوثيق والاختبارات

- [x] 1. تحديث docs الفنية.
- [x] 2. تحديث AGENTS المحلية عند الحاجة.
- [x] 3. إضافة unit tests للـlimiter والتخزين.
- [x] 4. إضافة unit tests لمصنف الأخطاء وjittered backoff.
- [x] 5. إضافة tests لأحداث notice وتعدد clients قدر الإمكان.
- [x] 6. إضافة tests لتغيير provider أثناء recovery وحفظ ترتيب queue.
- [x] 7. إضافة tests لاختيار auto failover واحترام `allow_auto_failover`.

### المرحلة H: تدقيق Never-Trapped Session وتصحيح التنفيذ

تنفيذ hardening والاستعادة durable محكوم ببوابات متسلسلة في
[`tasks/done/plan30-runtime-recovery-hardening-and-durable-state.md`](tasks/done/plan30-runtime-recovery-hardening-and-durable-state.md)؛
اكتملت Gates A-G ومراجعتها، وأغلقت H/8 بعد نجاح التحقق النهائي.

- [x] 1. جعل stop أثناء waiting/blocked/fatal فعالًا دون شرط processing.
- [x] 2. توحيد stop لإلغاء العمل والانتظار ومسح queue وبث stopped/cleared.
- [x] 3. تمرير provider/model ذريًا في change-provider وretry والرسالة الجديدة.
- [x] 4. استئناف suspended work بالroute الحالي ثم إكمال FIFO.
- [x] 5. إعادة runtime notice داخل `get_session_history` وعمل hydration موحد.
- [x] 6. بناء `message` من رسالة التطبيق وتفاصيل المزود بعد redaction.
- [x] 7. استبدال retry العام بميزانية حسب التصنيف مع unknown يدوي افتراضيًا.
- [x] 8. إضافة اختبارات agent/client وE2E للحالات السابقة وتعدد clients/reconnect.

## 12. معايير القبول

- [x] كل provider instance جديد يملك `requests_per_minute`.
- [x] كل provider instance جديد يملك `allow_auto_failover`.
- [x] القيمة الافتراضية تأتي من `ProviderProfile.defaultRequestsPerMinute`، وكل
  المزودين `0` باستثناء NVIDIA NIM بقيمة `38`.
- [x] إرسال `requests_per_minute=0` صراحة يحفظ غير محدود ولا يستبدل بقيمة القالب.
- [x] لا يرسل الوكيل طلبًا يتجاوز الحد المحلي لنفس provider instance.
- [x] عند تفعيل auto failover، لا يستخدم الوكيل إلا instances جاهزة تسمح بذلك
  ولديها نفس النموذج المطلوب وليست rate-limited/exhausted.
- [x] auto failover يرسل notice واضحًا ويحدث مزود الجلسة الافتراضي لباقي queue.
- [x] تظهر حالة انتظار واضحة فوق input عند rate limit.
- [x] يحترم الوكيل `429` و`Retry-After`.
- [x] يحول الوكيل retry hints إلى `Duration` في HTTP؛ وتقرأ الواجهة فقط
  `resume_at`/`retry_after_ms` المولدين من الوكيل.
- [x] تنتظر رسالة usage limit ذات reset خمس ساعات حتى الموعد الحقيقي مع timer
  وStop، بينما quota بلا reset لا يعاد تلقائيًا ولا يستخدم cooldown الدقيقة.
- [x] عند `429` بلا `Retry-After` يسجل الوكيل cooldown دقيقة على نفس
  provider instance لكل الجلسات.
- [x] يميز مصنف الأخطاء بين rate limit وbilling وoverload وupstream rate limit
  وأخطاء الشبكة.
- [x] تستخدم retries التلقائية ميزانية حسب التصنيف وjittered backoff، ولا تعيد
  الأخطاء الحتمية أو unknown تلقائيًا
  بنفس instance.
- [x] لا يوجد انتظار صامت لحالة recovery معروفة.
- [x] يمكن إيقاف أي جلسة recovery من أي client ومسح queue دون فقد السجل المكتمل.
- [x] تغيير provider/model أو retry أو رسالة جديدة يستأنف نقطة التوقف بالroute الحالي.
- [x] تبقى رسائل queue مرتبة FIFO بعد تغيير المزود.
- [x] إرسال رسالة بمزود جديد يحدث مزود الجلسة الافتراضي للرسائل التالية.
- [x] الأخطاء غير الخاصة بالمزود يمكن عرضها عبر نفس notice mechanism.
- [x] لا توجد logs noisy لكل tick في timer.
- [x] استعادة الجلسة في client جديد تعيد notice والqueue عبر history snapshot.
- [x] تعرض الواجهة رسالة المزود الأصلية بعد redaction أسفل رسالة التطبيق.
- [x] لا توجد حالة recovery ذات عمل معلق دون Stop فعال يعيد الجلسة إلى idle.

## 12.1 نتيجة تدقيق ما بعد التنفيذ

تدقيق `2026-07-10` أثبت أن banner والإعدادات موجودة، لكن دورة recovery ليست
مكتملة وظيفيًا. أعيد فتح البنود المرتبطة بالإيقاف، route المزود/النموذج،
reconnect، رسالة المزود، وسياسة retry حتى تمر اختبارات المرحلة H.

تحديث `2026-07-11`: أضيفت حماية stale history في client، وفصل pending route عن
confirmed route، وبث daemon-authoritative لتأكيد route عبر
`session_preferences_updated` بعد `retry/continue_with_provider`.

تحديث لاحق `2026-07-11`: أضيف اختبار daemon-backed فعلي لمسار
`waiting -> client recreation -> history hydration -> stop -> cleared/stopped -> next message`
في `client/e2e_test/local_dual_connection_e2e_test.dart`، وأُصلح runtime stop
ليُصدر `stopped` حتى في حالة waiting-only.

تحديث الإغلاق `2026-07-11`: أُغلقت task البوابات المتسلسلة المرتبطة بهذه
الخطة (`tasks/done/plan30-runtime-recovery-hardening-and-durable-state.md`) حتى Gate G.
أصبحت restart recovery سلوكًا production: الاستعادة durable تُفعَّل في startup
قبل قبول gateway events، وتفشل إلى blocked state قابلة للتحكم بدل الاستمرار
الصامت. كما ثبتت daemon-backed E2E لسيناريوهات waiting+retry، وcheckpoint بعد
tool result دون replay، وchange-provider بعد restart، وstop cleanup بعد
restart، وqueue-only FIFO drain. تحقق الإغلاق الحالي أيضًا من:

- `fvm dart analyze`
- `fvm dart test`
- `fvm flutter analyze`
- `fvm flutter test`

تحديث الإغلاق النهائي `2026-07-12`: أُغلقت حالات التنافس بين Retry وChange
Provider وفق first-claimant-wins، ووُحِّدت route الفائزة بين runner والجلسة
والqueue وكل clients. أصبح Change Provider يستأنف active waiting run على
المزود والنموذج الجديدين، بينما stale Retry أثناء turn طبيعية تصبح no-op.
نجح التحقق النهائي في 604 اختبارات agent مع skip واحد قائم، و5 اختبارات
daemon-backed E2E، و360 اختبار client، مع analyzers نظيفة.

إصلاح ما بعد الإغلاق `2026-07-12`: رُبط Stop مباشرةً بإشارة cooperative داخل
`AgentRunner`. إذا أكمل adapter طلب HTTP/SSE بعد بث `stopped`، تُهمل الاستجابة
قبل تعديل history أو تنفيذ tool call أو بدء طلب نموذج تالٍ. أضيف regression
يؤخر استجابة مزود تحمل tool call، يضغط Stop، ثم يثبت أن الأداة لم تنفذ.

إصلاح controlled restart `2026-07-12`: ترد endpoints الخاصة بإعادة التشغيل على
caller أولًا، وتمنح نتيجة الأداة وcheckpoint وقتًا للوصول إلى durable state، ثم
تخرج من دون إلغاء active work. عند startup تُستعاد checkpoints المعروفة عبر
`resumeSuspended()`، وبذلك تصل نتيجة `sanad-dev restart agent` إلى النموذج من دون
إعادة تنفيذ أمر restart. أما `/stop` الدائم فيستدعي `requestStopAll()` ويمسح
active/queued work قبل الخروج.

## 13. خارج النطاق

- أي توسيع مستقبلي خارج العقود الحالية لتعافي restart بعد Gate G، مثل replay
  أوسع لأدوات غير idempotent أو سياسات استعادة متعددة المراحل.

- نظام billing داخلي كامل أو فرض حصة خمس ساعات من Sanad نفسها؛ الخطة تستخرج
  reset الموثوق من المزود وتعرضه وتستأنف عنده، لكنها لا تحسب حصة استخدام داخلية.
- priority queue أو تنفيذ رسائل متوازية داخل الجلسة نفسها.
- load balancing دوري بين عدة provider instances خارج حالات التعافي.
- ترتيب failover مخصص للمستخدم أو خريطة تكافؤ نماذج تقريبية.
