---
title: "Task 57: Provider Management UX and Draft Lifecycle"
description: "إعادة بناء تجربة عرض وإضافة وتعديل مزودي Sanad حول حقول فعلية فقط، وحفظ واضح قابل للتراجع، واستعادة صريحة عند فشل جلب النماذج."
status: "completed"
priority: "high"
scope: "Sanad agent provider defaults and draft lifecycle; Flutter provider setup, Settings management UX, model discovery recovery, tests, and documentation"
depends_on: "Plan 29 provider instances; Task 34 Settings Hub; provider-setup-responsive-embedding"
coordinates_with: "Task 55 provider account usage; provider protocol; provider setup QA"
---

# Task 57: Provider Management UX and Draft Lifecycle

## 1. المشكلة

تستخدم Sanad حاليًا نموذجًا عامًا واحدًا لإنشاء وتعديل كل أنواع المزودين. يعرض
النموذج حقولًا لا تمثل قرارًا حقيقيًا للمستخدم، ويكرر API key واختيار model،
ويخلط الإعدادات الأساسية بالخيارات المتقدمة. كما أن الانتقال بين الخطوات لا
يوضح متى تصبح البيانات دائمة، وقد يترك `ProviderInstance` بحالة `draft` عند
الرجوع أو إلغاء OAuth بعد بدء الإعداد.

المشكلات المؤكدة هي:

1. كل templates الإنتاجية تعلن طريقة مصادقة واحدة فقط، لكن الواجهة تعرض
   `Authentication Method` كقائمة اختيار.
2. نموذج الإنشاء يطلب API key ثم يهملها للمزود الجديد ويطلبها مرة أخرى في
   خطوة مستقلة.
3. نموذج الإنشاء يطلب `Default Model` قبل المصادقة، ثم يعرض model picker بعد
   المصادقة.
4. `Rate Limit` ظاهر رغم عدم الحاجة إليه؛ معظم templates تستخدم صفر، بينما
   NVIDIA NIM ما زال يعلن 38 ويطبق حدًا مخفيًا إذا أزيل الحقل من الواجهة فقط.
5. عرض معلومات الاتصال غير متسق بين flows. يجب أن يظهر `Base URL` و`Protocol`
   دائمًا، وأن يفرّق التصميم بوضوح بين اختيار قيم الاتصال أثناء الإضافة
   وعرضها كهوية ثابتة بعد اكتمال الإعداد.
6. وضع التعديل يعرض مسارين متناقضين لتغيير API key ويستخدم controller واحدًا
   لأكثر من حقل.
7. العمليات تستبدل النموذج كله بشاشة loading، ولذلك قد تضيع المدخلات عند
   فشل الحفظ.
8. Back/Cancel لا يملكان عقدًا صريحًا للبيانات المحلية أو draft المحفوظة.
9. فشل جلب models يتحول حاليًا إلى fallback list ورسالة تقنية، دون تجربة صريحة
   فيها Retry وAdd Model يدوي وBack.
10. نتيجة Test والعمليات الصغيرة لا تعطي feedback ناجحًا واضحًا، وبعض الصفوف
    والأزرار لا تتكيف مع العرض الضيق.
11. شاشة ChatGPT Device Code تعيد تنسيق `user_code` حتى إذا كانت تحتوي شرطة
    أصلًا، فيظهر الكود مثل `ABCD--1234`. كما تدعي أن صفحة التحقق فُتحت وتعرض
    `Re-open verification page` رغم أن الفتح لا يحدث إلا بعد ضغط المستخدم،
    وزر إلغاء المصادقة ليس واضحًا بما يكفي كمسار خروج مضمون.
12. أزرار الإجراءات موضوعة حاليًا داخل المحتوى القابل للتمرير؛ عندما يكون
    النموذج أو قائمة models أطول من المساحة المتاحة، لا يرى المستخدم Continue
    أو Confirm أو Save changes أو Cancel إلا بعد التمرير إلى نهاية الصفحة.
13. نفس واجهات إدارة وإعداد providers يعاد استخدامها داخل مضيفين مختلفين:
    صفحة Settings المدمجة وpopup/dialog الخاصة بطلب إعداد المزود. أي افتراض
    ارتفاع مناسب لمضيف واحد قد ينتج overflow أو scrolling مكسورًا في الآخر.

## 2. تدقيق توقيت الحفظ الحالي

الحفظ الحالي **يبدأ قبل التحقق من المزود**، وليس بعده:

| المرحلة الحالية | هل تكتب بيانات دائمة؟ | السلوك الحالي |
|---|---:|---|
| فتح Providers أو اختيار template | لا | تحميل وعرض فقط. |
| الكتابة في نموذج instance | لا | القيم موجودة داخل controllers محلية. |
| الضغط على `Save & Next` | نعم | يستدعي `provider.instance.create` فورًا وينشئ instance دائمة بحالة `draft`. |
| إدخال API key في الشاشة التالية | نعم | يستدعي `provider.credential.update` على draft الموجودة. |
| بدء OAuth | draft محفوظة بالفعل | يحتاج OAuth إلى `provider_instance_id`، لذلك يبدأ بعد إنشاء instance. |
| اختيار model والضغط على التأكيد | نعم | يحدث `default_model` ثم يسجل recent model. |
| التحقق النهائي | لا ينشئ instance | ينفذ `provider.runtime_check` بعد حفظ metadata وcredential وmodel. |
| تعديل instance موجودة | نعم | `Save & Next` يحدث metadata مباشرة قبل أي اختبار نهائي. |
| Back أو Cancel بعد إنشاء draft | لا rollback مضمون | قد تبقى draft محفوظة أو يرجع المستخدم اعتمادًا على قائمة state قديمة. |

إذًا لا يجوز أن توحي الواجهة بأن العملية لم تحفظ شيئًا بعد إنشاء draft. يجب أن
تملك المهمة lifecycle صريحًا للـprovisional draft، وأن تفرق بين Back داخل
الخطوات وبين Discard للعملية الجديدة بالكامل.

## 3. الهدف

1. عرض الحقول التي تمثل قرارات فعلية فقط لكل نوع provider.
2. إزالة Authentication Method من الواجهة الحالية واشتقاقها من template.
3. إخفاء Rate Limit مع جعل كل instances الحالية والجديدة غير محدودة بقيمة صفر،
   مع إبقاء بنية rate limiter في الكود dormant بدل حذفها بالكامل.
4. إدخال API key مرة واحدة واختيار default model مرة واحدة.
5. فصل تجربة الإضافة عن تجربة تعديل instance موجودة.
6. تعريف متى تحفظ كل خطوة، وكيف يعمل Back، وكيف تحذف provisional draft عند
   إلغاء إضافة جديدة.
7. إبقاء المدخلات مرئية ومحفوظة محليًا أثناء loading أو failure.
8. توفير مسار كامل عند فشل model discovery: رسالة واضحة، Retry، Add Model يدوي،
   وBack دون حفظ model غير مؤكدة.
9. إعطاء feedback واضح لاختبار الاتصال والحفظ والحذف وتغيير default.
10. الحفاظ على نفس flow في Settings والـprovider-required popup/dialog دون overflow.
11. جعل Device Code مطابقًا للقيمة الصحيحة، وربط نصوص فتح المتصفح بحالة الفتح
    الفعلية، وتوفير Cancel واضح وآمن طوال انتظار OAuth.
12. إبقاء إجراءات الخطوة الحالية ظاهرة دائمًا في footer ثابت، مع تمرير محتوى
    الصفحة وحده في الإضافة والتعديل واختيار model.
13. إبقاء `Base URL` و`Protocol` ظاهرين في الإضافة والتعديل؛ تختار القيم
    المسموح بها أثناء الإضافة ثم تعرض read-only أثناء تعديل instance موجودة.
14. اعتبار Settings والـpopup/dialog عقدي embedding متساويين؛ لا يقبل أي تعديل
    UI أوheight أوscroll قبل نجاحه في المكانين باستخدام الواجهات المشتركة نفسها.

## 4. قرارات التصميم الملزمة

### 4.1 طريقة المصادقة مشتقة وليست اختيارًا

- لا تعرض الواجهة `Authentication Method` ما دامت template تعلن طريقة واحدة.
- تستمد الواجهة والطرف المالك القيمة من `template.effectiveAuthMethods.single`.
- `openai-codex` يتجه مباشرة إلى Device Code بعد خطوة الاسم.
- templates الحالية الأخرى تتجه إلى API-key/local/custom flow المناسب.
- يتحقق agent من أن `auth_method` المرسلة تنتمي إلى methods الخاصة بالـtemplate،
  وليس فقط أنها قيمة معروفة عالميًا.
- تبقى قدرة تعدد طرق المصادقة في models والبروتوكول للمستقبل، لكنها لا تنتج
  picker وهمية الآن. إذا أضيفت template فعلية متعددة الطرق لاحقًا، تحتاج UX
  صريحة واختبارات إنتاجية قبل إظهار الاختيار.

### 4.2 مصفوفة حقول الإضافة

#### إضافة API-key provider رسمي

| الخطوة | الحقول أو المعلومات الظاهرة | الإجراءات الثابتة |
|---|---|---|
| Provider details | `Display Name` و`Base URL` قابلة للتعديل و`Protocol` ظاهرة read-only للمزود الرسمي و`API Key` واحدة فقط. | `Cancel` و`Continue`. |
| Model selection | قائمة models المكتشفة، أو `Model name` فقط بعد اختيار `Add Model` عند فشل الجلب. | `Back` و`Confirm Model`؛ وفي حالة الفشل تبقى `Retry` و`Add Model` ظاهرتين داخل الحالة. |

لا تظهر في هذا المسار `Authentication Method` أو`Rate Limit` أو`Default Model`
كنص حر في خطوة البيانات الأولى.

#### إضافة OAuth provider

| الخطوة | الحقول أو المعلومات الظاهرة | الإجراءات الثابتة |
|---|---|---|
| Provider details | `Display Name` و`Base URL` قابلة للتعديل و`Protocol` ظاهرة read-only. | `Cancel` و`Continue`. |
| Device Code | الكود canonical، وحالة فتح المتصفح، وزر `Open/Re-open verification page`؛ لا يوجد حقل API Key. | `Back` و`Cancel`. |
| Model selection | قائمة models المكتشفة، أو `Model name` اليدوي بعد فشل الجلب واختيار `Add Model`. | `Back` و`Confirm Model`؛ وفي حالة الفشل تبقى `Retry` و`Add Model` ظاهرتين داخل الحالة. |

لا تظهر في هذا المسار `Authentication Method` أو`API Key` أو`Rate Limit` أو
`Default Model` كنص حر في خطوة البيانات الأولى.

#### بقية أنواع المزودات

| نوع template | الحقول المرئية قبل model discovery |
|---|---|
| Local provider | `Display Name` + `Base URL` قابلة للتعديل + `Protocol` ظاهرة read-only + `API Key` فقط إذا كانت مطلوبة أو أراد المستخدم إضافتها. |
| Custom provider | `Display Name` + `Base URL` قابلة للتعديل + `Protocol` قابلة للاختيار + `API Key` اختيارية. |

قواعد مشتركة:

- لا يظهر `Default Model` كنص حر في نموذج metadata الأول.
- لا يظهر `Rate Limit` في أي مسار.
- يظهر `Base URL` دائمًا بالقيمة الافتراضية للـtemplate أو القيمة المحفوظة؛
  يكون قابلًا للتعديل طوال محاولة الإضافة، ثم يصبح read-only بعد اكتمال الإعداد
  وعند تعديل instance موجودة.
- يظهر `Protocol` دائمًا:
  - أثناء الإضافة يكون selector قابلًا للتعديل لـ`Custom`، أو لأي template تعلن
    مستقبلًا أكثر من protocol مسموح بها.
  - أثناء الإضافة يكون read-only لكل template مسجلة تعلن protocol واحدة، بما
    في ذلك المزودون الرسميون وOAuth والمحليون حاليًا.
  - أثناء تعديل أي instance موجودة، بما فيها `Custom`، يكون Protocol read-only.
- لا تعرض قيم read-only كحقول disabled باهتة أو مبهمة؛ تعرض بوضوح وتكون قابلة
  للتحديد والنسخ مع وصف مثل `Connection settings are fixed after setup`.
- لا ترسل شاشة Edit mutations لـ`Base URL` أو`Protocol`. إذا احتاج المستخدم
  تغيير إحداهما، ينشئ provider instance جديدة ويختبرها قبل حذف القديمة؛ تمنع
  هذه المهمة التحويل الصامت لهوية اتصال instance مستخدمة بالفعل.
- يظهر `Auto Failover` دائمًا في نموذج الإضافة والتعديل دون إخفائه داخل
  `Advanced`. يبقى تحت مفتاحه تحذير واضح بأن تفعيله يسمح لـSanad باستخدام هذا
  المزود تلقائيًا عند فشل مزود آخر، ويستخدم المفتاح لون التحذير الأحمر عند
  التفعيل. إذا كان المفتاح العام معطلًا يبقى الخيار والتحذير ظاهرين مع تعطيل
  التحكم وشرح السبب.
- يحافظ Display Name على الاقتراح الفريد والتحقق من التكرار.

### 4.3 تعطيل Rate Limit دون إزالة البنية

- يحذف حقل Rate Limit من إضافة وتعديل المزود.
- يزال استثناء NVIDIA NIM ذي القيمة 38، وتصبح
  `defaultRequestsPerMinute = 0` لكل templates.
- لا يرسل Flutter قيمة مشتقة غير صفرية عند إنشاء instance جديدة.
- تطبع migration أو upgrade خطوة واحدة كل instances الموجودة ذات القيمة غير
  الصفرية إلى صفر، حتى لا يبقى حد خفي لا يستطيع المستخدم رؤيته أو تغييره.
- يبقى `ProviderRateLimiter` والعقد والعمود موجودين للتوافق، لكن صفر يعني
  unlimited ولا يطبق throttling محليًا.
- تحدث الوثائق والاختبارات التي تصف NVIDIA 38 أو تتوقعها.

### 4.4 عقد الحفظ والـprovisional draft

- الكتابة والتنقل قبل الضغط على Continue لا يرسلان mutations.
- يحتفظ controller واحد للـwizard بكل المدخلات المحلية عبر Back/Next وفشل
  الطلبات؛ لا تعتمد استعادة القيم على إعادة بنائها من snapshot قديمة.
- عند الحاجة إلى `provider_instance_id` للمصادقة، ينشئ flow instance بحالة
  `draft` ويسجل بوضوح أنها provisional ومملوكة لمحاولة الإضافة الحالية.
- API-key وOAuth flows قد تحتاج draft قبل اكتمال الاتصال؛ هذا تفصيل runtime لا
  يظهر للمستخدم كحساب مكتمل.
- Back يرجع خطوة واحدة ولا يحفظ مدخلات الخطوة الحالية تلقائيًا، لكنه يحتفظ بها
  محليًا إذا عاد المستخدم للأمام مرة أخرى.
- Back بعد وجود provisional draft لا ينشئ draft ثانية ولا يفقد الهوية الحالية.
- إغلاق أو Cancel للعملية الجديدة بعد إنشاء provisional draft يعرض تأكيد
  `Discard provider setup?`. الموافقة تحذف draft التي أنشأتها هذه المحاولة فقط.
- لا يحذف Cancel أو Back instance كانت موجودة قبل فتح شاشة التعديل.
- إذا تعذر حذف provisional draft، تظهر في قائمة Providers كـ`Setup incomplete`
  مع Resume وDelete؛ لا تبقى hidden orphan.
- اكتمال الإعداد يحدث فقط بعد حفظ credential المطلوبة، وحفظ default model،
  ونجاح readiness/connection verification المطلوبة.
- شاشة التعديل تحفظ فقط عند `Save changes`، وتبقى instance الحالية مرئية ولا
  تتحول الصفحة كاملة إلى loading.

### 4.5 تجربة Device Code وفتح المتصفح

- تعد `user_code` القادمة من agent هي القيمة canonical. تعرض وتنسخ دون تغيير
  معناها أو إضافة فاصل ثانٍ، ويظهر بجوارها زر نسخ واضح ينسخ القيمة نفسها ويعطي
  feedback مرئيًا؛ إذا احتاج الكود غير المنسق إلى تجميع بصري، يكون formatter
  idempotent: القيمة `ABCD-1234` تبقى `ABCD-1234` ولا تصبح `ABCD--1234`.
- يختبر formatter القيم المنسقة وغير المنسقة والأطوال غير المتوقعة، ولا يفترض
  دائمًا أن طول الكود زوجي أو أن موضع الشرطة هو المنتصف.
- بعد استلام auth session صالحة، تحاول الواجهة فتح
  `verification_uri_complete` أو `verification_uri` تلقائيًا مرة واحدة فقط؛
  إعادة بناء widget أو polling لا يطلقان فتحات متكررة للمتصفح.
- تحتفظ حالة الـwizard بنتيجة محاولة الفتح (`notAttempted`, `opened`, `failed`)
  بدل استنتاجها من وجود URL فقط.
- لا تقول الواجهة إن الصفحة فُتحت إلا بعد نجاح `launchUrl` فعليًا:
  - عند `opened`: يمكن أن تقول إن الصفحة فُتحت ويصبح الزر
    `Re-open verification page`.
  - عند `notAttempted` أو `failed`: تطلب من المستخدم فتح الصفحة ويكون الزر
    `Open verification page`، مع رسالة فشل آمنة قابلة للمحاولة عند الحاجة.
- يبقى URL أو زر الفتح اليدوي متاحًا حتى إذا فشل الفتح التلقائي، ولا يمنع فشل
  launcher استمرار polling أو إدخال الكود في متصفح آخر.
- يظهر زر `Cancel` بوضوح ويظل قابلًا للوصول أثناء الانتظار أو فشل الفتح أو
  انتهاء الكود. يوقف auth polling/session الحالية ثم يطبق عقد الإلغاء:
  - في إضافة provider جديدة: يعرض `Discard provider setup?` إذا كانت provisional
    draft قد أُنشئت، ويحذفها فقط بعد التأكيد.
  - في إعادة المصادقة لـinstance موجودة: يلغي محاولة المصادقة فقط ولا يحذف
    instance أو credential السابقة.
- يظل `Back` مختلفًا عن `Cancel`: يرجع خطوة واحدة ويحافظ على محاولة الإعداد
  المحلية، بينما Cancel ينهي محاولة OAuth الحالية وفق عقد الـdiscard أعلاه.

### 4.6 model discovery والفشل والإدخال اليدوي

حالات خطوة model مطلوبة وصريحة:

1. `loading`: مؤشر داخل خطوة model مع بقاء header وBack ظاهرين.
2. `loaded`: قائمة models مع model مقترحة واختيار واحد واضح.
3. `failed`: banner آمنة للمستخدم تقول إن قائمة models لم تُجلب، دون raw
   exception أو ادعاء أن fallback list هي نتيجة live ناجحة.
4. `manual`: حقل `Model name` يملؤه المستخدم بنفسه.

عند `failed` تظهر الإجراءات التالية معًا:

- `Retry`: يعيد `model.refresh` للـinstance نفسها ويمنع double submit.
- `Add Model`: يفتح الإدخال اليدوي داخل الشاشة نفسها.
- `Back`: يرجع إلى خطوة المصادقة/الاتصال السابقة دون حفظ model جديدة.

قواعد Add Model:

- حقل Model name يقبل قيمة trimmed غير فارغة ويعرض validation inline.
- الضغط على `Use Model` أو `Save Model` هو الحد الوحيد الذي يحفظ القيمة.
- الكتابة وحدها وBack لا يرسلان `provider.instance.update`.
- تبقى القيمة المكتوبة عند فشل الحفظ أو الاختبار، ولا يعاد إنشاء controller.
- يطبع agent model id حسب protocol/template كما يفعل مع النماذج المكتشفة.
- إذا وجدت cached أو fallback suggestions، يمكن عرضها في قسم منفصل باسم واضح
  مثل `Cached suggestions`، مع بقاء رسالة فشل live discovery ظاهرة.
- Retry الناجح يستبدل حالة الفشل بالقائمة authoritative دون حفظ اختيار تلقائي.

### 4.7 تجربة تعديل provider موجودة

#### تعديل API-key provider رسمي

| القسم | الحقول القابلة للتعديل | معلومات أو إجراءات غير حقلية |
|---|---|---|
| `General` | `Display Name`. | الحالة الحالية. |
| `Connection` | لا حقول قابلة للتعديل. | `Base URL` و`Protocol` ظاهرتان read-only وقابلتان للنسخ. |
| `Credential` | لا يظهر حقل مفتاح افتراضيًا؛ بعد `Replace API Key` يظهر حقل `New API Key` واحد. | masked key hint وحالة credential، مع `Replace API Key` و`Remove API Key` حسب العقد. |
| `Default Model` | لا يظهر text field افتراضيًا؛ `Change Model` يفتح model picker، والإدخال اليدوي يظهر فقط عند مسار `Add Model`. | model الحالية وزر `Change Model`. |
| `Reliability` | `Auto Failover` فقط. | لا Rate Limit. |
| `Danger Zone` | لا حقول. | `Delete Provider` مع تحذير إضافي إذا كانت instance هي default. |

لا تظهر `Authentication Method`. استبدال المفتاح mutation مستقلة وواضحة، ولا
يتطلب إعادة إدخال المفتاح عند تعديل الاسم أو Auto Failover.

#### تعديل OAuth provider

| القسم | الحقول القابلة للتعديل | معلومات أو إجراءات غير حقلية |
|---|---|---|
| `General` | `Display Name`. | الحالة الحالية. |
| `Connection` | لا حقول قابلة للتعديل. | `Base URL` و`Protocol` ظاهرتان read-only وقابلتان للنسخ. |
| `Credential` | لا يوجد API Key ولا token text field. | حالة تسجيل الدخول وaccount label والانتهاء إن توفرت، مع `Reconnect` أو`Disconnect` حسب العقد. |
| `Default Model` | لا يظهر text field افتراضيًا؛ `Change Model` يفتح model picker، والإدخال اليدوي يظهر فقط عند مسار `Add Model`. | model الحالية وزر `Change Model`. |
| `Reliability` | `Auto Failover` فقط. | لا Rate Limit. |
| `Danger Zone` | لا حقول. | `Delete Provider` مع تحذير إضافي إذا كانت instance هي default. |

لا تظهر `Authentication Method` أو`API Key`. إعادة المصادقة mutation مستقلة؛
إلغاؤها لا يمس credential الصالحة السابقة.

قسم `Connection` موجود لكل المزودين، لكنه read-only في Edit. يعرض `Base URL`
و`Protocol` الفعليتين حتى في `Custom` وlocal. اختيار Protocol متاح فقط أثناء
إضافة `Custom` أوtemplate متعددة البروتوكولات، ويقيد بالقائمة المدعومة.

زر الحفظ في edit اسمه `Save changes` وليس `Save & Next`. مغادرة الصفحة بقيم
معدلة غير محفوظة تعرض تأكيد Discard changes.

### 4.8 feedback والأخطاء والاستجابة

- تعرض عمليات Save, Test, Make Default, Delete وReconnect progress على البطاقة
  أو الزر المعني بدل استبدال flow بالكامل.
- لا يغير `Test` حالة الـflow إلى loading عامة، ولا يخفي قائمة providers، ولا
  يستدعي reload عامة تجعل القائمة تختفي ثم تعود. يبقي snapshot القائمة وترتيبها
  ظاهرين، ويحدث نتيجة instance المستهدفة فقط أو يجري refresh خلفية غير هدامة.
- نجاح Test يعرض نتيجة مرئية مرتبطة بالـinstance، وفشله يعرض رسالة آمنة قابلة
  لإعادة المحاولة.
- تعرض بطاقة instance على الأقل Display Name والحالة وDefault Model وDefault
  badge عند انطباقها، مع حالة `Setup incomplete` وResume/Delete للـdraft غير
  المكتملة؛ لا تعتمد المعلومة الأساسية على template id أوprotocol الخام.
- لا تعرض الواجهة `StateError`, stack traces، response bodies، أو رسائل raw.
- تستخدم بطاقات instance أسماء وحالات مفهومة، ولا تجعل template id وprotocol
  الخام معلومة أساسية.
- تتحول صفوف الإجراءات إلى Wrap أو overflow menu في العرض الضيق.
- تدعم الواجهة الأسماء الطويلة، keyboard traversal، focus، semantics، وtooltips.
- يعتمد layout على عقد `provider-setup-responsive-embedding` في Settings
  والـpopup/dialog، وتزال flex widgets غير الآمنة تحت vertical constraints غير محدودة.

### 4.9 شريط الإجراءات الثابت والتمرير

- يتكون كل surface من header اختياري، وbody واحد قابل للتمرير، وaction footer
  خارج الـscroll وثابت أسفل المساحة المتاحة. لا توضع الإجراءات الأساسية في
  نهاية `ListView` أو`SingleChildScrollView`.
- يطبق هذا العقد على الأقل على Provider details، وDevice Code، وmodel
  selection، وmanual model، وشاشة Edit، وفي Settings والـprovider-required
  popup/dialog معًا.
- تبقى إجراءات الخطوة مرئية دون تمرير:
  - Provider details: `Cancel` و`Continue`.
  - Device Code: `Back` و`Cancel`.
  - model loaded: `Back` و`Confirm Model`.
  - model failed: `Back` و`Retry` و`Add Model`.
  - manual model: `Back` و`Use Model` أو`Save Model`.
  - التعديل: `Cancel` و`Save changes`.
- قد تكون الأزرار disabled أثناء validation أو request، لكنها لا تختفي؛ يظهر
  progress داخل الزر المعني ولا يستبدل footer أو الصفحة كلها.
- body وحده يتمرر عندما يزيد المحتوى، مع bottom inset يمنع آخر حقل أو رسالة من
  الاختفاء خلف footer. لا ينشأ nested scroll متنافس بين embedding والـflow.
- في العرض الضيق يلتف footer أو يرتب الأزرار رأسيًا وفق المساحة، مع بقاء الإجراء
  الأساسي واضحًا وقابلًا للوصول، واحترام SafeArea ولوحة المفاتيح.
- ظهور validation أو error banner أو قائمة models طويلة لا يغير موضع footer
  ولا يتطلب الوصول إلى نهاية القائمة لتنفيذ الإجراء الأساسي.

### 4.10 عقد العرض في Settings والـpopup/dialog

- تستخدم صفحة Settings والـprovider-required popup/dialog نفس provider views
  ونفس state/controller؛ لا تنشأ نسخة ثانية من الواجهات لإخفاء مشكلة القيود.
- المضيف هو الذي يحدد المساحة القصوى المتاحة، بينما تتكيف الواجهة المشتركة مع
  constraints الفعلية. لا تفرض view ارتفاعًا ثابتًا أوminimum height صمم لمضيف
  واحد فقط.
- أي تعديل في `height`, `Expanded`, `Flexible`, `SingleChildScrollView`,
  `ListView`, action footer، padding، أو SafeArea داخل provider UI يجب مراجعته
  واختباره في المضيفين معًا.
- تحت constraints رأسية غير محدودة لا تستخدم flex رأسيًا بصورة غير آمنة؛ وتحت
  constraints محدودة يبقى body قابلًا للتمرير والfooter ثابتًا دون overflow.
- popup/dialog تملك حدًا أقصى مناسبًا للنافذة ولا تسمح للمحتوى بتوسيعها خارج
  الشاشة. صفحة Settings تستفيد من المساحة المتاحة دون فرض ارتفاع الـdialog.
- لا ينشأ nested scroll متنافس بين scroll الخاص بالمضيف وscroll الداخلي. يجب
  أن يكون مالك التمرير واضحًا، وأن تبقى آخر قيمة وأزرار الإجراءات قابلة للوصول.
- تشمل المراجعة جميع الحالات المشتركة: قائمة providers، Provider details،
  Device Code، model loading/loaded/failed/manual، Edit، ورسائل الخطأ الطويلة.
- لا تكتمل أي UI change في هذا النطاق باختبار مضيف واحد فقط؛ الاختبار الثنائي
  شرط قبول، ويشمل viewport قصيرة وعرضًا ضيقًا ومحتوى أطول من المساحة.

## 5. خطة التنفيذ المرحلية

### Gate A — Contracts and state ownership

- [x] توثيق state machine للإضافة والتعديل وملكية provisional draft.
- [x] إضافة wizard state تحفظ المدخلات محليًا عبر الخطوات والفشل.
- [x] فصل add flow عن edit flow مع إعادة استخدام widgets الصغيرة فقط.
- [x] تعريف typed UI errors وoperation feedback لكل instance.

#### Gate A Exit

- [x] لكل mutation حد واضح ومذكور في الاختبارات.
- [x] Back وCancel وDiscard لا تعتمد على `state.instances` قديمة.
- [x] لا يمكن حذف instance قديمة بسبب إلغاء flow جديدة.

### Gate B — Provider defaults and validation

- [x] جعل defaults الخاصة بـrequests per minute صفر لكل templates.
- [x] إضافة migration تصفر القيم القديمة غير الصفرية.
- [x] منع Flutter من إرسال rate-limit غير مرئية.
- [x] اشتقاق auth method من template والتحقق منها في agent.
- [x] تحديث DTO/protocol tests دون إزالة القدرة المستقبلية متعددة الطرق.

#### Gate B Exit

- [x] كل instance حالية وجديدة تعيد `requests_per_minute = 0`.
- [x] لا يظهر rate-limit في UI ولا يعمل throttling خفي.
- [x] لا يظهر auth picker لأي template إنتاجية حالية.

### Gate C — Add-provider forms

- [x] بناء form خاص بـAPI-key دون تكرار المفتاح أو model.
- [x] بناء OAuth handoff مشتق تلقائيًا من template.
- [x] مطابقة حقول ومسارات API-key وOAuth لمصفوفة الإضافة الملزمة.
- [x] جعل formatter الخاص بـDevice Code idempotent مع حفظ القيمة canonical.
- [x] تنفيذ فتح تلقائي مرة واحدة وتخزين نتيجة launcher الفعلية في state.
- [x] ربط النص وزر `Open/Re-open verification page` بنتيجة الفتح الحقيقية.
- [x] إبقاء Cancel ظاهرًا وتنفيذ إيقاف polling/session وربطه بعقد discard.
- [x] إظهار Base URL قابلًا للتعديل أثناء الإضافة وProtocol ظاهرة دائمًا؛ يكون
      اختيار Protocol متاحًا أثناء إضافة Custom/multi-protocol فقط.
- [x] إبقاء Auto Failover ظاهرًا دائمًا دون Advanced، مع تحذير دائم ولون أحمر
      للمفتاح عند التفعيل.
- [x] إضافة validation مرئية وعدم استخدام no-op عند ضغط submit.

#### Gate C Exit

- [x] API key تكتب مرة واحدة وتصل إلى credential الخاصة بالـinstance نفسها.
- [x] OAuth يبدأ دون اختيار وهمي لطريقة المصادقة.
- [x] لا يظهر Device Code بشرطتين ولا تدعي الواجهة فتح المتصفح قبل نجاحه.
- [x] يمكن إلغاء OAuth من كل حالات الانتظار والفشل دون orphan draft أو حذف
      instance موجودة.
- [x] لا يطلب أي flow اسم model قبل model discovery.

### Gate D — Draft lifecycle and navigation

- [x] تتبع provisional instance id داخل محاولة الإضافة.
- [x] تنفيذ Back خطوة واحدة مع الحفاظ على القيم المحلية.
- [x] تنفيذ Discard confirmation وحذف provisional draft بأمان.
- [x] عرض Resume/Delete لأي draft يتعذر rollback عليها.
- [x] منع duplicate drafts عند Back ثم Next أو عند retry.

#### Gate D Exit

- [x] Cancel قبل أول mutation لا يكتب شيئًا.
- [x] Cancel بعد إنشاء provisional draft لا يترك instance مخفية.
- [x] Back لا يحفظ الخطوة الحالية ولا يفقد المدخلات.

### Gate E — Model discovery recovery

- [x] فصل loaded/failed/manual model states.
- [x] إضافة رسالة فشل آمنة مع Retry وAdd Model وBack.
- [x] إضافة manual model validation وحفظ صريح فقط.
- [x] الحفاظ على الإدخال اليدوي بعد failure.
- [x] اختبار cached/fallback labeling دون تمثيلها كـlive success.

#### Gate E Exit

- [x] يستطيع المستخدم إكمال الإعداد باسم model يدوي عند فشل الجلب.
- [x] Retry لا ينشئ instance جديدة ولا يحفظ اختيارًا تلقائيًا.
- [x] Back من failure لا يحفظ model ولا يفقد بقية بيانات flow.

### Gate F — Edit UX, feedback, and responsive integration

- [x] فصل أقسام edit وإزالة credential fields المتناقضة.
- [x] مطابقة حقول API-key وOAuth لمصفوفة التعديل الملزمة.
- [x] إضافة Connection read-only وقابل للنسخ لكل المزودين في شاشة Edit.
- [x] جعل حفظ edit inline مع الاحتفاظ بالمدخلات عند failure.
- [x] إضافة feedback مرئي لـTest وMake Default وDelete وReconnect.
- [x] جعل Test عملية instance-scoped لا تخفي القائمة ولا تطلق reload عامة.
- [x] إضافة تحذير حذف خاص بالـdefault instance.
- [x] إصلاح action rows والأسماء الطويلة والمقاسات الضيقة.
- [x] استخراج action footer ثابت مشترك وتمرير body وحده في add/edit/model flows.
- [x] التحقق من Settings والـpopup/dialog وفق dual-host embedding contract.
- [x] إزالة أي fixed/min-height أوflex/scroll assumption تعمل في مضيف واحد فقط.

#### Gate F Exit

- [x] تعديل metadata لا يطلب credential جديدة.
- [x] شاشة Edit لا ترسل أي mutation لـBase URL أوProtocol، بما في ذلك Custom.
- [x] Replace/Remove/Reconnect تؤثر في instance المقصودة فقط.
- [x] Test يبقي قائمة providers وترتيبها ظاهرين ويحدث البطاقة المقصودة فقط.
- [x] تبقى الإجراءات الأساسية ظاهرة دون scroll في كل خطوة وعلى الارتفاعات
      والمقاسات المدعومة.
- [x] نفس provider views تعمل في Settings والـpopup/dialog دون نسخ أوfork UI.
- [x] لا يوجد overflow في المقاسات المدعومة أو loss للمدخلات.

### Gate G — Documentation and regression coverage

- [x] تحديث `docs/product/settings_hub.md` بتجربة الإضافة والتعديل النهائية.
- [x] تحديث `docs/technical/provider_protocol.md` بحدود الحفظ والـdraft lifecycle.
- [x] توسيع `docs/qa_maintenance/provider_setup_plan29_regression_matrix.md`.
- [x] تحديث أقرب `AGENTS.md` فقط إذا تغير invariant دائم.
- [x] إضافة unit/widget/integration tests المركزة ثم تحديث Graphify.

## 6. Definition of Done

- [x] الحقول الظاهرة تطابق مصفوفة template ولا يوجد auth picker وهمي.
- [x] Rate Limit مخفية، وجميع القيم الحالية والجديدة صفر.
- [x] API key وDefault Model لا يطلب أي منهما مرتين.
- [x] Base URL ظاهرة دائمًا؛ editable أثناء الإضافة وread-only قابلة للنسخ في
      تعديل أي instance موجودة، وتستخدم قيم read-only حدودًا رمادية هادئة بدل
      الحدود البيضاء الساطعة.
- [x] Protocol ظاهرة دائمًا؛ يمكن اختيارها أثناء إضافة Custom أوtemplate متعددة
      البروتوكولات فقط، وتصبح read-only في Edit لكل المزودين.
- [x] Add وEdit تجربتان واضحتان بأسماء أزرار صحيحة.
- [x] حقول API-key وOAuth في الإضافة والتعديل تطابق المصفوفات الملزمة ولا تظهر
      حقول credential أوconnection غير مناسبة لنوع المزود.
- [x] المدخلات لا تضيع أثناء loading أو request failure.
- [x] توقيت كل mutation موثق ومغطى باختبار.
- [x] Back لا يحفظ الخطوة الحالية ويحافظ على draft UI المحلية.
- [x] Discard ينظف provisional draft ولا يمس instances قديمة.
- [x] فشل model discovery يعرض رسالة + Retry + Add Model + Back.
- [x] manual model تحفظ فقط بعد إجراء صريح وتبقى عند failure.
- [x] Device Code المعروض والمُنسخ مطابق للقيمة canonical ولا يكرر الفواصل،
      ويوفر زر نسخ مجاورًا يستخدم Toast Success/Error العام دون SnackBar.
- [x] Auto Failover ظاهر دائمًا في الإضافة والتعديل مع تحذير الاستخدام التلقائي
      باللون الأحمر دون خلفية ملونة، ويأخذ مفتاحه لون التحذير الأحمر عند التفعيل.
- [x] ملخص credential يقرأ حقول daemon canonical (`configured` و
      `masked_key_hint`) حتى لا يظهر API key العامل كـ`Not set` أو OAuth المتصل
      كـ`Disconnected`، مع قبول aliases القديمة أثناء الانتقال.
- [x] نتيجة Test تعتمد حقل البروتوكول `success` ولا تحول نجاح Codex إلى فشل
      بسبب فحص حقل عرض غير موجود.
- [x] فتح صفحة OAuth يُحاول تلقائيًا مرة واحدة، والنص و`Open/Re-open` يعكسان
      نتيجة launcher الفعلية.
- [x] زر Cancel واضح ومتاح في Device Code ويوقف المصادقة ويطبق discard الآمن.
- [x] Test وعمليات البطاقات تعطي feedback مرئيًا غير هدّام.
- [x] اختبار Provider لا يخفي القائمة أو يستبدلها loading أو يعيد تحميلها
      بالكامل بعد اكتمال الطلب.
- [x] أزرار Continue وConfirm Model وUse Model وSave changes وBack/Cancel تبقى
      ظاهرة دون scroll، بينما body وحده قابل للتمرير.
- [x] Settings والـpopup/dialog يعملان دون overflow أو nested-scroll regression.
- [x] كل تغيير UI أوheight أوscroll مغطى في Settings والـpopup/dialog معًا؛ لا
      يعتمد أي shared view على ارتفاع ثابت خاص بأحد المضيفين.
- [x] كل رسائل الواجهة بالإنجليزية وآمنة للمستخدم.
- [x] وثائق المنتج والبروتوكول وQA وعقود الميزة محدثة.
- [x] `fvm flutter analyze` واختبارات agent/client المركزة ناجحة.
- [x] `graphify update .` نُفذ بعد تغييرات التنفيذ.

## 7. Success Test Scenarios

### 7.1 API-key provider جديد

1. افتح Settings ثم Providers واضغط Add Provider واختر OpenAI.
2. تحقق أن الحقول هي Display Name وBase URL قابلة للتعديل وProtocol read-only
   وAPI Key واحدة، دون Auth Method أو Rate Limit أو Default Model.
3. أدخل المفتاح مرة واحدة وأكمل؛ تحقق من إنشاء instance واحدة فقط.
4. اختر model من القائمة وأكمل؛ تحقق من readiness والعودة إلى القائمة.
5. كرر الخطوات داخل viewport قصيرة ومع قائمة models طويلة؛ تحقق من بقاء
   `Continue` ثم `Confirm Model` ظاهرين دون التمرير إلى نهاية المحتوى.

### 7.2 OAuth وDiscard

1. اختر ChatGPT subscription وتحقق من عدم ظهور auth picker.
2. اجعل agent يعيد `ABCD-1234` وتحقق أن العرض والنسخ لا ينتجان
   `ABCD--1234`؛ ثم اختبر قيمة غير منسقة وطولًا غير متوقع.
3. ابدأ Device Code وتحقق من محاولة فتح صفحة التحقق تلقائيًا مرة واحدة فقط،
   حتى مع rebuild وpolling.
4. عند نجاح launcher، تحقق من النص الصادق وظهور
   `Re-open verification page`. عند فشله، تحقق من رسالة آمنة وظهور
   `Open verification page` وإمكانية المحاولة يدويًا.
5. اضغط Back وتقدم مرة أخرى؛ تحقق من عدم إنشاء draft ثانية.
6. تحقق أن Cancel ظاهر أثناء الانتظار وفشل launcher وانتهاء الكود. اضغطه ثم
   اختر Discard؛ تحقق من توقف polling وحذف provisional draft فقط.
7. اختبر Cancel أثناء Reconnect لـinstance موجودة؛ تحقق من بقاء instance
   وcredential السابقة دون تغيير.
8. كرر العملية وأكمل OAuth؛ تحقق من حفظ الحساب واختيار model.
9. تحقق أن Base URL ظاهرة وقابلة للتعديل وأن Protocol ظاهرة read-only طوال
   إعداد template الـOAuth.

### 7.3 فشل model discovery

1. اجعل model refresh يعيد failure typed.
2. تحقق من ظهور رسالة واضحة وRetry وAdd Model وBack في الشاشة نفسها.
3. اضغط Retry وتحقق من عدم إنشاء instance جديدة أو حفظ model تلقائيًا.
4. افشل الجلب مجددًا، اختر Add Model، واكتب model يدويًا ثم احفظها.
5. تحقق أن Back قبل الحفظ لا يغير default model، وأن فشل الحفظ يبقي النص.

### 7.4 تعديل provider

1. افتح instance API-key موجودة واضغط Edit.
2. تحقق من غياب Auth Method وRate Limit وحقل API Key المكرر، ومن ظهور Base URL
   وProtocol read-only وقابلتين للنسخ.
3. عدل الاسم وافشل الطلب؛ تحقق من بقاء القيمة المكتوبة.
4. استبدل credential من قسم Credential وتحقق من عزل instance.
5. افتح Change Model واختبر success وfailure وmanual model.
6. تحقق أن `Cancel` و`Save changes` ثابتان أسفل الشاشة أثناء تمرير الأقسام، وأن
   Replace API Key أو Reconnect لا يضيفان حقولًا غير مناسبة لنوع المزود.
7. تحقق أن شاشة Edit لا تسمح بتعديل Base URL أوProtocol ولا ترسل mutation لهما.
8. أضف Custom وتحقق أن Protocol selector قابلة للتعديل ومقيدة بالبروتوكولات
   المدعومة أثناء الإضافة، ثم افتحها في Edit وتحقق أنها أصبحت read-only.

### 7.5 عرض القائمة والعمليات غير الهدامة

1. افتح قائمة تحتوي عدة providers وحالات ready وerror وSetup incomplete.
2. تحقق من ظهور الاسم والحالة وDefault Model وDefault badge والإجراءات المناسبة،
   ومن ظهور Resume/Delete للمسودة غير المكتملة.
3. اضغط Test على instance واحدة وأبق الطلب pending؛ تحقق أن القائمة وترتيبها
   وبقية البطاقات ظاهرة، وأن progress داخل البطاقة أو الزر المستهدف فقط.
4. أكمل Test بنجاح ثم بفشل؛ تحقق من عرض النتيجة داخل البطاقة دون loading عامة
   أو اختفاء القائمة أو reload كاملة.
5. اختبر Make Default وDelete وReconnect وتحقق أن كل عملية معزولة إلى البطاقة
   المقصودة وتعطي feedback واضحًا.

### 7.6 Rate-limit compatibility

1. شغّل migration على قاعدة تحتوي instance بقيمة 38 وأخرى بقيمة مخصصة.
2. تحقق أن القيمتين أصبحتا صفرًا وأن runtime لا يطبق limiter.
3. أنشئ instances من NVIDIA وباقي templates وتحقق أن جميعها صفر.

### 7.7 Responsive and accessibility

1. شغّل نفس widget/harness matrix للـSettings embedding وللـprovider-required
   popup/dialog، باستخدام provider views المشتركة نفسها.
2. في كل مضيف اختبر viewport قصيرة وعرضًا ضيقًا ومحتوى طويلًا وقائمة models
   طويلة؛ تحقق أن body يتمرر وأن action footer ثابت وغير مغطى بلوحة المفاتيح
   أو SafeArea.
3. في كل مضيف مرّ على قائمة providers وProvider details وDevice Code وحالات
   model الأربع وEdit ورسالة خطأ طويلة، وتحقق من عدم وجود overflow.
4. تحقق أن آخر حقل ورسالة خطأ يمكن تمريرهما بالكامل فوق footer دون تداخل أو
   nested-scroll conflict.
5. تحقق أن تغيير ارتفاع shared view لا يجعل popup/dialog تتجاوز الشاشة ولا
   يفرض ارتفاع dialog على صفحة Settings.
6. اختبر اسم instance طويلًا ووجود كل إجراءات البطاقة.
7. تحقق من keyboard focus وBack وCancel وtooltips وsemantics.

### 7.8 أوامر التحقق

1. من `client/`: `fvm flutter analyze`.
2. من `client/`: تشغيل provider setup bloc/widget tests المركزة.
3. من `agent/`: `fvm dart analyze` وتشغيل registry, instance service, migration,
   provider protocol, وrate-limiter compatibility tests المركزة.
4. تشغيل UI verification في runtime معزولة عبر `sanad-dev run --driver` عند
   التنفيذ، ثم التحقق من Settings والـpopup/dialog ولقطات المقاسات المطلوبة.
