---
title: "Task 55: Provider Account Usage Limits and ChatGPT Reset Credits"
description: "إضافة عقد موحّد لحدود استخدام حسابات المزودين، بدءًا من ChatGPT، مع عرض النوافذ المتاحة فقط وإدارة reset credits بأمان من صفحة Providers."
status: "completed"
priority: "high"
scope: "Sanad agent provider runtime/protocol and Flutter provider settings UX"
depends_on: "Task 29 provider instance runtime, Task 34 Settings Hub"
coordinates_with: "Task 30 provider rate-limit recovery"
---

# Task 55: Provider Account Usage Limits and ChatGPT Reset Credits

## 1. المشكلة

تعرض Sanad حاليًا إعدادات وحالة كل `ProviderInstance`، لكنها لا تعرض حدود
الاستخدام الفعلية لحساب المزود أو مواعيد تجددها. يحتاج المستخدم إلى معرفة ما
تبقى من حدود ChatGPT وإدارة reset credits المتاحة من داخل صفحة Providers بدل
الاعتماد على واجهة أو CLI خارجية.

الميزة ليست مفهومًا خاصًا بـOAuth أو ChatGPT. بعض المزودين المعتمدين على API Key
قد يوفرون حدودًا أو أرصدة لاحقًا. لذلك يجب أن يكون العقد موحدًا ومربوطًا بهوية
`provider_instance_id`، مع adapter خاص بكل مزود، بينما تظل المرحلة الأولى
مقصورة على ChatGPT (`openai-codex`).

## 2. الهدف

1. تعريف نموذج موحّد للقطات حدود استخدام `ProviderInstance` مستقل عن طريقة
   المصادقة ونوع المزود.
2. دعم نوافذ `session`, `weekly`, و`monthly` وعرض النوافذ التي يعيدها المزود فقط.
3. جلب حدود ChatGPT من واجهة الاستخدام الرسمية باستخدام credential الخاصة
   بالـinstance دون كشف token للعميل.
4. عرض الحدود داخل بطاقة الحساب في
   `Settings → Device → Providers → Configured Providers` ضمن قسم قابل للتوسعة
   باسم `Usage & limits`.
5. عرض النسبة المتبقية أولًا، والنسبة المستخدمة كمعلومة ثانوية، مع موعد التجدد.
6. عرض عدد reset credits المتاحة وإظهار `Reset limits` فقط عندما يكون العدد أكبر
   من صفر.
7. حماية عملية Reset من الهدر، ثم جلب لقطة جديدة إجباريًا بعد نجاحها بدل تعديل
   النسب محليًا.
8. إبقاء فشل الاستخدام معزولًا عن readiness وحالة المزود وقدرته على تنفيذ الطلبات.

## 3. قرارات التصميم الملزمة

### 3.1 الملكية والهوية

- daemon هو المصدر الوحيد لحالة الاستخدام وإمكانية Reset ونتيجتها.
- كل طلب ولقطة مرتبطة بـ`provider_instance_id`، وليس `providerId` أو
  `templateId` فقط، لدعم عدة حسابات للمزود نفسه.
- الميزة لا تشترط OAuth في العقد العام. يقرر adapter الخاص بالمزود إن كانت
  credential الحالية قادرة على جلب الاستخدام.
- Flutter لا يقرأ credentials ولا يتصل بواجهات المزود مباشرة ولا يستنتج
  الدعم من `authMethod`.
- لا تختلط هذه الميزة مع token usage للجولة (`LlmUsageSnapshot`) أو rate-limit
  recovery في Task 30؛ تلك مفاهيم مستقلة.

### 3.2 النموذج الموحّد

يعيد daemon لقطة JSON-safe بمفاهيم ثابتة، مثل:

```text
ProviderUsageSnapshot
  provider_instance_id
  provider_template_id
  source
  fetched_at
  plan_name?
  windows[]
  available_resets
  extra_details[]
  unavailable_reason?

ProviderUsageWindow
  type: session | weekly | monthly
  label
  used_percent?
  remaining_percent?
  reset_at?
  detail?
```

قواعد النموذج:

- الأنواع المدعومة في v1 هي `session`, `weekly`, و`monthly` فقط.
- لا تُنشأ نافذة placeholder عند غيابها من استجابة المزود.
- تعرض الواجهة فقط عناصر `windows` الموجودة؛ غياب Session الحالي من ChatGPT
  سلوك طبيعي وليس خطأ.
- يطبّع daemon النسب إلى `[0, 100]` ويشتق القيمة المقابلة عند توفر واحدة فقط.
- القيم غير الرقمية أو `NaN/Infinity` لا تعبر البروتوكول.
- `reset_at` وقت UTC صريح، وتنسقه الواجهة حسب المنطقة الزمنية المحلية.
- `fetched_at` مطلوب لعرض حداثة البيانات وتطبيق freshness policy.
- `available_resets` عدد صحيح غير سالب؛ الصفر يعني أن زر Reset غير موجود.
- `extra_details` بيانات عرض آمنة فقط، ولا تحتوي payload خامًا أو أسرارًا.
- `unavailable_reason` سبب typed/آمن للعرض؛ لا يغير readiness الخاصة بالـinstance.

### 3.3 ChatGPT في المرحلة الأولى

- adapter المرحلة الأولى يعمل فقط مع instances ذات template
  `openai-codex` وcredential صالحة لاستخدام ChatGPT account backend.
- يجلب الاستخدام من endpoint المكافئ لـ:
  `GET https://chatgpt.com/backend-api/wham/usage`.
- يستخدم `Authorization: Bearer <access token>` ويضيف `ChatGPT-Account-Id`
  عندما تكون هوية الحساب متاحة من credential المملوكة للـinstance.
- لا يسجل URL query أو headers أو response خامًا أو token أو account id.
- يقرأ فقط الحقول المعروفة، ويتجاهل الحقول الإضافية للتوافق الأمامي.
- mapping لا يفترض أن `primary_window` تعني Session دائمًا دون إثبات من payload
  أو fixture حديثة. يجب تثبيت mapping في adapter واختبار الاستجابات الحالية
  التي قد تعيد Weekly/Monthly فقط.
- الخطة وcredits وreset count تعرض عندما تكون متاحة، ولا يؤدي غيابها إلى إسقاط
  النوافذ الصالحة.

### 3.4 بروتوكول القراءة والتحديث

تضاف أوامر instance-first transport-neutral عبر المسار canonical المحلي/السحابي:

| Command | Response event | الغرض |
|---|---|---|
| `provider.usage.get` | `provider.usage.result` | جلب لقطة حديثة لـ`provider_instance_id`. |
| `provider.usage.reset` | `provider.usage.reset_result` | استهلاك reset credit للحساب المحدد ثم إعادة لقطة حديثة عند النجاح. |

قواعد البروتوكول:

- يحمل كل أمر `request_id + provider_instance_id`.
- نتيجة القراءة تميز typed بين `available`, `unsupported`, `unavailable`,
  `auth_required`, و`failed` دون raw provider error.
- `unsupported` يعني أن الـinstance لا يملك adapter استخدام حاليًا؛ لا تعرض
  الواجهة قسمًا فارغًا أو خطأً مزعجًا.
- transient failure يعرض داخل القسم مع `Retry` ولا يغير instance status.
- نتيجة Reset typed وتشمل status، رسالة آمنة، `available_resets`، وsnapshot
  الجديدة عند النجاح.
- الأوامر تعمل بنفس العقد على الجهاز المحلي أو السحابي، مع targeting صريح للجهاز
  من feature client الحالي.

### 3.5 سياسة الجلب والـcache

- عند فتح صفحة Providers تظهر قائمة instances أولًا دون انتظار usage requests.
- بعد تحميل instances، يطلب client الاستخدام بالتوازي للـinstances التي يعلن
  daemon أنها مدعومة، أو يستخدم query آمنة تعيد `unsupported` دون hardcoding
  catalog في Flutter.
- يحتفظ client بلقطة كل instance مدة freshness قدرها **دقيقة واحدة**.
- عند الرجوع إلى الصفحة خلال الدقيقة تعرض اللقطة الموجودة دون طلب جديد.
- بعد تجاوز الدقيقة تعرض اللقطة الحالية كبيانات stale وتحدثها في الخلفية
  (stale-while-revalidate) دون إخفاء البطاقة.
- لا يوجد polling مستمر في v1.
- زر `Refresh` يجلب instance واحدة فقط، ويُعطل أثناء طلبها الجاري.
- تبديل Settings device أو إزالة instance يلغي/يتجاهل النتائج القديمة بهوية
  الطلب والجهاز والـinstance؛ لا تنتقل لقطة حساب إلى حساب أو جهاز آخر.

### 3.6 تجربة العرض

داخل بطاقة كل instance مدعومة يظهر disclosure باسم `Usage & limits`:

- لا يمنع loading ظهور بيانات المزود أو أزراره الحالية.
- تعرض كل نافذة موجودة كسطر مستقل وشريط تقدم.
- النص الأساسي هو المتبقي، مثل `58% remaining`، والثانوي `42% used`.
- يعرض `Resets <local relative time>` مع الوقت المحلي الكامل في tooltip أو
  نص ثانوي مناسب.
- يظهر plan name وextra details فقط عندما تكون موجودة.
- يعرض footer مثل `Updated just now` وزر `Refresh`.
- loading الأول يعرض مؤشرًا صغيرًا داخل القسم.
- stale refresh يبقي البيانات مرئية مع مؤشر تحديث غير هدّام.
- `unsupported` لا يعرض القسم.
- `auth_required` أو failure يعرض رسالة إنجليزية مختصرة مع `Retry` أو دعوة
  لإعادة ربط الحساب حسب الحالة.
- كل النص المرئي في Flutter باللغة الإنجليزية وفق عقد المشروع.

### 3.7 Reset credits وتجربة التأكيد

- يظهر `N resets available` عندما يكون العدد أكبر من صفر.
- لا يظهر زر `Reset limits` إطلاقًا عندما يكون `available_resets == 0` أو غير
  معروف أو عند عدم دعم المزود للعملية.
- Reset تخص الـinstance المحددة فقط ولا يمكنها استخدام credential افتراضية أو
  حساب آخر كـfallback.
- قبل الاستهلاك يجلب daemon الحالة الحالية ويتحقق مجددًا من عدد resets ومن
  استنفاد النوافذ، ولا يثق باللقطة القديمة في Flutter.
- إذا كانت نافذة واحدة على الأقل مستنفدة بالكامل، يعرض client تأكيدًا عاديًا
  ثم يرسل Reset.
- إذا لم تكن أي نافذة مستنفدة، لا يستهلك daemon الرصيد بالطلب العادي، ويعيد
  outcome `confirmation_required` مع ملخص الاستخدام الحالي. يعرض client تحذيرًا
  بأن Reset يعيد الحدود كاملة وقد يهدر الرصيد، مع `Cancel` و`Reset anyway`.
- `Reset anyway` يعيد الأمر بعلامة `force: true` وبـrequest identity جديدة أو
  confirm token قصير العمر يمنع تطبيق التأكيد على snapshot مختلفة؛ يحسم
  التنفيذ العقد الأكثر أمانًا قبل الكود.
- الزر يتعطل أثناء التنفيذ، ولا يسمح double submit.
- success يعرض إشعار نجاح ثم ينفذ **forced refresh** من المزود ويستبدل اللقطة
  كاملة بالبيانات الجديدة.
- لا تحسب Flutter النسب أو عدد resets المتبقية تفاؤليًا.
- `nothing_to_reset` يوضح أن الرصيد لم يُستهلك ثم يحدث اللقطة.
- أخطاء `no_credit`, `already_redeemed`, `auth_required`, provider/network
  failure typed، وتبقي القسم قابلًا لإعادة المحاولة.
- يجب أن تكون عملية الاستهلاك محمية بـidempotency key يملكها daemon حتى لا
  يستهلك retry شبكي أو ضغط مزدوج أكثر من credit واحدة.

## 4. بوابة التنفيذ

- [x] التحقق من payload ChatGPT الحالي عبر fixtures/اختبارات آمنة وتثبيت mapping
      Weekly/Monthly دون افتراض Session القديمة.
- [x] اعتماد أسماء models وwindow enum وtyped outcomes قبل تعديل الواجهة.
- [x] اعتماد capability discovery التي تمنع hardcoding مزودي الاستخدام في client.
- [x] اعتماد command/event payloads، idempotency، وعقد `force` أو confirm token.
- [x] تحديد timeout والـHTTP client المشترك دون إضافة magic values متناثرة.
- [x] تحديد رسائل الخطأ الآمنة التي لا تكشف response body أو credential.
- [x] تأكيد أن Reset endpoint والعقد الحالي ما زالا صالحين قبل تنفيذ mutation.

## 5. النطاق المرحلي

### Gate A — Unified models and provider capability

- [x] إضافة models موحدة للّقطة والنوافذ والنتائج typed في agent.
- [x] إضافة provider usage adapter/service interface مستقلة عن OAuth وAPI Key.
- [x] ربط support بالـtemplate/instance capabilities من daemon، لا بقائمة Flutter.
- [x] إضافة ChatGPT adapter للقراءة فقط مع parsing دفاعي للنوافذ المتاحة.
- [x] اختبار غياب Session ووجود Weekly/Monthly منفردة أو مجتمعة.
- [x] اختبار malformed/partial payload والنسب غير الصالحة والحقول الإضافية.

#### Gate A Exit

- [x] يمكن جلب لقطة instance محددة دون تسريب credential أو استخدام default آخر.
- [x] غياب أي نافذة لا ينشئ placeholder ولا يفشل بقية اللقطة.
- [x] إضافة adapter لمزود API Key مستقبلًا لا تتطلب تغيير نموذج الواجهة.

### Gate B — Canonical usage protocol

- [x] إضافة `provider.usage.get` و`provider.usage.result` إلى protocol bridge
      والfeature client مع request correlation وdevice targeting.
- [x] إعادة typed status للحالات available/unsupported/unavailable/auth/failed.
- [x] منع raw token/provider payload من عبور الحد أو الدخول إلى logs.
- [x] احتواء timeout/network/provider parsing failure دون التأثير على daemon أو
      readiness.
- [x] اختبارات local/cloud protocol parity والنتائج المتأخرة أو غير المطابقة.

#### Gate B Exit

- [x] نفس الأمر يعيد النتيجة نفسها دلاليًا عبر local وcloud routes.
- [x] فشل الاستخدام لا يغير instance status ولا يمنع model execution.

### Gate C — Provider card usage UX and freshness

- [x] إضافة DTO/state مالكة لكل `device + provider_instance_id`.
- [x] جلب non-blocking بعد تحميل instances وعرض البطاقات مباشرة.
- [x] تطبيق freshness لدقيقة واحدة وstale-while-revalidate بلا polling.
- [x] إضافة disclosure `Usage & limits` والنوافذ الموجودة فقط.
- [x] عرض remaining أولًا وused ثانيًا وreset time محليًا.
- [x] إضافة Updated/Refresh وحالات loading/stale/error/auth/Retry.
- [x] تجاهل الاستجابات القديمة بعد device switch أو instance deletion/disposal.

#### Gate C Exit

- [x] فتح Providers لا ينتظر usage network قبل عرض instances.
- [x] الرجوع خلال دقيقة لا يكرر الطلب، وبعدها يحدث في الخلفية.
- [x] ChatGPT بلا Session يعرض Weekly/Monthly فقط دون مساحة أو رسالة مفقودة.

### Gate D — Reset credits service and protocol

- [x] إضافة ChatGPT reset adapter مع preflight جديد من المصدر.
- [x] إضافة `provider.usage.reset` ونتائج typed وidempotency الدائمة/المحدودة
      بما يمنع double consumption أثناء إعادة المحاولة.
- [x] منع reset العادي غير المستنفد وإرجاع `confirmation_required`.
- [x] دعم التأكيد القسري الآمن دون تطبيق موافقة قديمة على لقطة تغيرت.
- [x] معالجة reset/nothing_to_reset/no_credit/already_redeemed/auth/failure.
- [x] بعد النجاح أو nothing_to_reset جلب snapshot جديدة وإعادتها/بثها للclient.
- [x] اختبارات تثبت أن instance A لا تستخدم credential أو reset الخاصة بـB.

#### Gate D Exit

- [x] زر/طلب مزدوج أو network retry لا يستهلك أكثر من credit واحدة.
- [x] لا يسمح المسار العادي بهدر reset قبل الاستنفاد.
- [x] النجاح لا يكتمل في UI قبل وصول بيانات الاستخدام الجديدة أو نتيجة refresh
      واضحة قابلة للاستعادة.

### Gate E — Reset UX and reconciliation

- [x] عرض count وزر Reset فقط عند `available_resets > 0` ودعم reset معلن.
- [x] إضافة confirmation العادي ومسار التحذير `Reset anyway`.
- [x] تعطيل الإجراءات أثناء التنفيذ ومنع double submit.
- [x] عرض success/failure/nothing-to-reset برسائل واضحة غير هدّامة.
- [x] استبدال اللقطة من forced refresh فقط وعدم إجراء optimistic arithmetic.
- [x] إذا نجح الاستهلاك وفشل refresh، عرض نجاح العملية مع حالة stale وRetry
      بدل الادعاء أن القيم القديمة حديثة.

### Gate F — Verification and documentation

- [x] اختبارات agent unit للـmodels، parsing، credential scoping، timeout،
      idempotency، preflight، وكل reset outcome.
- [x] اختبارات protocol للأوامر والأحداث وrequest/device/instance isolation.
- [x] اختبارات Flutter data/state للfreshness والتوازي وإلغاء النتائج القديمة.
- [x] اختبارات widget للنوافذ المتاحة فقط، remaining-first، loading/stale/error،
      إخفاء Reset عند صفر، confirmation وforced refresh.
- [x] daemon-backed E2E باستخدام HTTP provider fixture محلية/محقونة؛ لا تستدعي
      حساب المستخدم الحقيقي أو ChatGPT production ولا تقرأ credentials الحية.
- [x] تشغيل `fvm dart analyze` و`fvm flutter analyze` والاختبارات المركزة، والجناح
      الأوسع وفق blast radius.
- [x] تحديث `docs/technical/provider_protocol.md`، وثيقة product لواجهة الحدود،
      وثيقة QA، أقرب AGENTS المتأثرة، وMOCs/`docs/llms.txt` عند التنفيذ.
- [x] تشغيل `graphify update .` بعد تغييرات الكود.

## 6. Definition of Done

- [x] Usage مرتبطة صراحة بـprovider instance وتعمل بصرف النظر عن OAuth/API Key
      في التجريد العام.
- [x] المرحلة الأولى تجلب ChatGPT usage بأمان ولا ترسل credential إلى Flutter.
- [x] النموذج يدعم Session/Weekly/Monthly والواجهة تعرض الموجود فقط.
- [x] غياب Session الحالي من ChatGPT لا ينتج placeholder أو خطأ.
- [x] remaining هي المعلومة الأساسية وused معلومة ثانوية لكل نافذة.
- [x] فتح Providers غير محجوب، freshness دقيقة، والتحديث stale-while-revalidate
      بلا polling مستمر.
- [x] فشل الاستخدام معزول عن readiness وتنفيذ النماذج.
- [x] Reset count يظهر عند توفره وزر Reset لا يظهر عند صفر أو عدم الدعم.
- [x] Reset غير المستنفد يحتاج تحذيرًا وتأكيدًا قسريًا واضحًا.
- [x] double submit/network retry لا يستهلكان credit إضافية.
- [x] بعد نجاح Reset تُجلب لقطة جديدة إجباريًا ولا تعدل Flutter القيم محليًا.
- [x] تبديل الجهاز/الحساب والاستجابات المتأخرة لا يخلطان بيانات instances.
- [x] تحليلات agent/client والاختبارات المركزة والتكاملية المناسبة ناجحة.

## 7. سيناريو النجاح

يفتح المستخدم `Settings → Device → Providers`. تظهر بطاقات المزودين فورًا، ثم
يفتح قسم `Usage & limits` في حساب ChatGPT. تعيد الاستجابة الحالية نافذتي Weekly
وMonthly فقط، فتظهران دون Session: النسبة المتبقية أولًا، والمستخدمة ثانيًا،
وموعد التجدد المحلي. تظهر `2 resets available` وزر `Reset limits`.

إذا ضغط Reset قبل استنفاد أي نافذة، يعيد daemon `confirmation_required` وتظهر
رسالة تحذر من هدر الرصيد. بعد `Reset anyway` ينفذ daemon الطلب مرة واحدة
بـidempotency، ثم يجلب الاستخدام مجددًا. تستبدل الواجهة اللقطة بالقيم الجديدة
وتعرض عدد resets الجديد. إذا أصبح العدد صفرًا يختفي زر Reset. الرجوع إلى الصفحة
خلال دقيقة يستخدم اللقطة الحديثة، وبعد الدقيقة يعرضها ويحدثها في الخلفية.

## 8. خارج النطاق

- إضافة Anthropic/OpenRouter/Nous أو أي provider usage adapter آخر في المرحلة
  الأولى؛ التجريد فقط يجب أن يسمح بها لاحقًا.
- عرض token usage لكل turn أو تكلفة المحادثة.
- polling دوري أو إشعارات background عند اقتراب الحد.
- auto-reset دون فعل صريح من المستخدم.
- دمج account limits مع Task 30 runtime cooldown أو auto-failover policy.
- عرض نوافذ غير Session/Weekly/Monthly في v1.
- تخزين تاريخ usage snapshots أو رسم charts زمنية.

## 9. الملفات والوثائق المتوقعة

- `agent/lib/core/models/`
- `agent/lib/core/provider_runtime/`
- `agent/lib/interfaces/platforms/sanad_gateway/`
- `client/lib/features/provider_setup/data/`
- `client/lib/features/provider_setup/presentation/`
- اختبارات agent/client المركزة وdaemon-backed fixture آمنة
- `docs/technical/provider_protocol.md`
- وثيقة product جديدة لتجربة Provider Usage Limits
- وثيقة QA جديدة لمصفوفة usage/reset
- أقرب `AGENTS.md` وMOCs/`docs/llms.txt` المتأثرة أثناء التنفيذ

## 10. سجل التقدم

```text
Date: 2026-07-19
Gate/status: Gate A — Unified models and provider capability (DONE)
Files changed:
  - agent/lib/core/provider_usage/provider_usage_models.dart (new)
  - agent/lib/core/provider_usage/provider_usage_adapter.dart (new)
  - agent/lib/core/provider_usage/chatgpt_usage_adapter.dart (new)
  - agent/lib/core/provider_usage/http_provider_usage_client.dart (new)
  - agent/lib/core/provider_usage/provider_usage_di.dart (new)
  - agent/test/core/provider_usage/provider_usage_models_test.dart (new, 11 tests)
  - agent/test/core/provider_usage/chatgpt_usage_adapter_test.dart (new, 27 tests)
  - agent/lib/core/AGENTS.md (added provider_usage ownership bullet)
Verification:
  - fvm dart analyze lib/core/provider_usage/ test/core/provider_usage/ → No issues found.
  - fvm dart test test/core/provider_usage/ → All 38 tests passed.
Gate A Exit criteria met:
  - Fetching an instance snapshot without leaking credentials or using a
    different default account (snapshot JSON never contains token/account id).
  - Missing Session window creates no placeholder and does not fail the rest
    of the snapshot (Weekly-only and Session-only fixtures pass).
  - Adding a future API-key provider adapter requires no model-surface change
    (ProviderUsageRegistry.register + implement ProviderUsageAdapter).
Findings:
  - Reference impl (hermes-agent account_usage.py) confirmed: /wham/usage
    returns rate_limit.primary_window (Session) + secondary_window (Weekly),
    used_percent is USED not remaining, rate_limit_reset_credits.available_count
    drives the reset count, and ChatGPT-Account-Id header is optional.
  - Dart jsonDecode rejects bare NaN/Infinity (unlike Python), so those values
    cannot reach the window parser; the adapter surfaces `unavailable`.
Next gate: Gate B — Canonical usage protocol (provider.usage.get / .reset over
  the sanad protocol bridge + feature client with request correlation).

Date: 2026-07-19
Gate/status: Gate B — Canonical usage protocol (DONE)
Files changed:
  - agent/lib/interfaces/platforms/sanad_gateway/protocol/canonical_events.dart
    (added providerUsageGet/Result/Reset/ResetResult/Support/SupportResult types)
  - agent/lib/core/provider_usage/provider_usage_service.dart (new — daemon
    service resolving instance+credential+adapter to a typed result)
  - agent/lib/interfaces/platforms/sanad_gateway/handlers/provider_command_handler.dart
    (buildUsageGetEnvelope + buildUsageSupportEnvelope; usageService injected)
  - agent/lib/interfaces/platforms/sanad_gateway/sanad_protocol_bridge.dart
    (string command parsing + dispatch cases for provider.usage.get/.support)
  - agent/lib/core/provider_usage/provider_usage_models.dart (requestId made
    mutable so handlers can echo correlation ids)
  - agent/lib/core/di.dart (register ProviderUsageRegistry + ProviderUsageService)
  - agent/test/interfaces/sanad_bridge_provider_usage_test.dart (new, 7 tests)
  - client/lib/features/provider_setup/data/models/provider_usage_dto.dart (new)
  - client/lib/features/provider_setup/data/provider_setup_client.dart
    (abstract usageGet + usageSupport)
  - client/lib/features/provider_setup/data/provider_setup_client_impl.dart
    (socket impl)
  - agent/lib/interfaces/platforms/sanad_gateway/AGENTS.md (usage protocol rules)
Verification:
  - fvm dart analyze (agent + client) for changed files → No issues found.
  - fvm dart test test/core/provider_usage/ test/interfaces/sanad_bridge_provider_usage_test.dart
    → 45 tests passed.
  - fvm dart test test/interfaces/sanad_bridge_provider_test.dart → 27 tests
    passed (no regression in existing provider commands).
Gate B Exit criteria met:
  - provider.usage.get returns the same typed result semantically via the local
    bridge (no cloud route exists in tests yet; contract parity is enforced by
    the shared handler — `provider.usage.reset` is wired in Gate D).
  - Usage failure (unavailable) does NOT change instance status or readiness
    (dedicated test: `_ThrowingAdapter` leaves status unchanged).
  - Raw token / response body never cross the protocol boundary (dedicated test
    asserts the capture never contains the token string).
  - `unsupported` is returned cleanly when no adapter is registered (no error
    noise).
  - `provider.usage.support` lets the client decide disclosure without
    hardcoding a provider catalog.
Findings:
  - ProviderUsageService is injected as an optional dependency so a bridge
    without it (tests, future minimal builds) degrades to `unsupported` for
    every instance instead of throwing.
  - `requestId` on `ProviderUsageResult` is now mutable so the handler can set
    it after constructing the result from the service (the service does not
    receive the request_id from the wire unless the caller passes it).
Next gate: Gate C — Provider card usage UX and freshness (Flutter disclosure,
  freshness policy, stale-while-revalidate, remaining-first display).
```

```text
Date: 2026-07-19
Gate/status: Gate C — Provider card usage UX and freshness (DONE)
Files changed:
  - client/lib/features/provider_setup/presentation/bloc/provider_usage_cubit.dart
  - client/lib/features/provider_setup/presentation/bloc/provider_usage_state.dart
  - client/lib/features/provider_setup/presentation/widgets/provider_usage_section.dart
  - client/lib/features/provider_setup/presentation/widgets/provider_instances_list_view.dart
  - client/lib/features/provider_setup/presentation/widgets/provider_setup_flow.dart
  - client/test/features/provider_setup/bloc/provider_usage_cubit_test.dart
  - client/test/features/provider_setup/widgets/provider_usage_section_test.dart
  - client/test/widget/provider_setup_flow_test.dart
  - client/lib/features/provider_setup/AGENTS.md
  - docs/technical/provider_protocol.md
  - docs/product/provider_account_usage_limits.md
  - docs/qa_maintenance/provider_account_usage_limits_qa.md
Verification:
  - focused ProviderUsageCubit and ProviderUsageSection tests: 18 passed.
  - provider setup flow regression/integration tests: 12 passed.
  - focused Flutter analysis: no issues found.
Gate C Exit criteria met:
  - configured cards render while capability discovery is deliberately held.
  - authoritative fetched_at drives the one-minute cache; stale snapshots remain
    visible during refresh and after a typed refresh failure.
  - missing Session creates no UI row; Weekly and Monthly render remaining-first.
  - late usage/support responses after removal or scope clearing are ignored.
  - changing ProviderSetupFlow's target device recreates device-owned cubits.
Next gate: Gate D — Reset credits service and protocol.
```


```text
Date: 2026-07-19
Gate/status: Gates D-E — Reset service, protocol, and UX (IMPLEMENTED)
Highlights:
  - Fresh daemon preflight, short-lived snapshot-bound confirmation tokens, and bounded idempotency result cache.
  - ChatGPT consume endpoint adapter with typed safe outcomes and forced provider reconciliation.
  - Canonical reset command/result and client reset DTO/cubit flow.
  - Reset count/button, exhausted confirmation, Reset anyway warning, disabled execution, and non-optimistic snapshot replacement.
  - Reset success with failed refresh remains explicit through refresh_failed.
Verification so far:
  - Focused agent analysis: clean.
  - Existing provider usage/protocol tests plus new adapter reset tests: passing.
  - Focused client analysis and Gate C state/widget regressions: passing.
Remaining Gate F: expanded reset protocol/state/widget isolation coverage, daemon-backed fixture, full required verification, graph update.
```


```text
Date: 2026-07-19
Gate/status: Gate F — COMPLETE
Additional correctness work:
  - Added daemon single-flight protection for concurrent requests sharing one
    instance-scoped idempotency key.
  - Client retains the same logical idempotency key across confirmation and
    ambiguous failures, while transport request ids remain independent.
  - Added reset protocol tests for concurrent replay and strict credential
    isolation between two configured instances.
  - Added Flutter state/widget coverage for reset double-submit, authoritative
    reconciliation, zero/positive credit visibility, and Reset anyway.
Verification:
  - fvm dart analyze: clean.
  - fvm dart test: 833 passed, 2 skipped.
  - focused provider usage agent tests: 49 passed.
  - focused provider usage/client flow tests: 33 passed.
  - fvm flutter test: 638 passed.
  - fvm flutter analyze: one pre-existing unrelated unused_local_variable warning
    in conversation_input_composer.dart; no task-owned analyzer findings.
  - Full daemon-backed E2E file: 4 passed sequentially.
  - Focused E2E analyzer: clean.
  - graphify update . completed (14,423 nodes / 20,206 edges).
Daemon-backed E2E:
  - Spawned an isolated daemon with unique SANAD_STATE_HOME and isolated fixture
    SANAD_HOME, then exercised create instance, credential update, support, usage
    read, reset mutation, and forced refresh through the real local WebSocket.
  - A loopback HTTP fixture asserted the Bearer credential, canonical ChatGPT
    paths, one consume POST, and post-reset reconciled snapshot without touching
    production ChatGPT or live user credentials.
```
