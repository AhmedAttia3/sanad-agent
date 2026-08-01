---
title: "خطة تنفيذ المهمة: تجريد طبقة الاتصال والـ Streams"
description: "خطة هندسية مكتملة لتوحيد ownership الخاص بالاتصال المحلي والسحابي داخل sanad-client مع إبقاء بقية التطبيق مستهلكًا لـ streams مستقرة."
---

# خطة تنفيذ المهمة: تجريد طبقة الاتصال والـ Streams (Connection Abstraction & Socket Generalization)

<div dir="rtl" style="text-align: right; direction: rtl;">

* **معرف المهمة (Task ID):** `86c9w9eru`
* **المكونات المتأثرة (Component Tags):** `sanad-client`
* **الحالة (Status):** ✅ Implemented (بانتظار المراجعة)
* **الوقت المتوقع (Estimated Effort):** 1-2 يوم عمل

---

## 🎯 الملخص

الهدف من هذه المهمة هو **توحيد ownership الخاص بالاتصال المحلي والسحابي في نقطة مركزية واحدة داخل `sanad-client`**، بحيث تتعامل بقية طبقات التطبيق مع **streams مستقرة لكل `agent_id`** بدل الاعتماد على معرفة نوع الاتصال الحالي أو إعادة الاشتراك عند تغيره.

هذه الخطة لا تستهدف فقط تحسين شكل الـ API، بل تستهدف حل المشكلة الجذرية التي تسبب:

- اختفاء محتوى المحادثة عند سقوط الاتصال المحلي.
- تسرب منطق `local/cloud` إلى الـ cubits والـ repositories.
- اختلاف السلوك بين الدسك توب وبين الويب/الموبايل بسبب افتراضات اتصال غير معزولة جيدًا.

---

## 📍 الوضع الحالي

البنية الحالية موزعة المسؤوليات بين عدة طبقات:

- `AgentConnectionCoordinator`
  يقرر لحظيًا هل الوكيل يجب أن يستخدم `localSocketService` أو `cloudSocketService`.

- `AgentManager`
  يعيد `decorateAgent()` ويكتب `preferred_connection_scope` داخل `AgentConfig.metadata`.

- `ConversationClientRegistryImpl`
  ينشئ `SocketConversationClient` مختلفًا حسب الـ scope الحالي، ويبدل العميل عند تغير `preferredConnectionScope`.

- `ThreadMessagesCubit`
  يراقب تغير `preferredConnectionScope` ويعيد الاشتراك في streams عندما يتغير.

- `SocketConversationClient`
  يملك داخليًا `AgentConversationStore` المرتبط بحالة المحادثة الحالية.

### المشاكل الحالية

1. **حالة المحادثة مربوطة بالـ transport client**

عند تبديل `local` إلى `cloud` لنفس `agent_id`، يتم التخلص من العميل القديم، وبالتالي تضيع معه حالة الـ store ما لم يتم نقلها يدويًا.

2. **الواجهة تعرف تفاصيل الاتصال**

الـ cubits لا تستهلك stream موحدًا فقط، بل تتعامل مع تغير `preferredConnectionScope` كحدث business logic.

3. **الـ resolver ليس owner حقيقيًا للـ lifecycle**

`AgentConnectionCoordinator` كان في الأصل أقرب إلى helper policy، لكنه يجب أن يبقى owner فعليًا للـ transport binding والـ failover behavior بعد هذا التغيير.

4. **هوية stream غير مستقرة**

عند تغير scope لنفس الوكيل، تتغير هوية العميل والاشتراكات المرتبطة به، بدل أن يبقى لدينا stream ثابت لنفس `agent_id`.

5. **الاعتماد على metadata كـ source of truth**

الحقل `preferred_connection_scope` مفيد كإشارة للحالة، لكنه حاليًا يدخل في مسار القرار داخل الطبقات العليا، وهذا يزيد coupling.

---

## 🧨 المشكلة الجذرية

المشكلة الأساسية ليست فقط "وجود اتصالين"، بل أن التطبيق يخلط بين مفهومين يجب فصلهما:

- **هوية جلسة الوكيل / المحادثة**: يجب أن تبقى ثابتة لكل `agent_id`.
- **وسيلة النقل الحالية**: `local` أو `cloud`، وهذه يجب أن تكون تفصيلًا داخليًا قابلًا للتبديل.

طالما أن حالة المحادثة والـ streams مرتبطة مباشرة بعميل النقل الحالي، فكل تبديل transport سيبقى معرضًا لكسر الواجهة أو مسح الحالة المرئية أو إعادة الاشتراك بشكل غير آمن.

---

## ✅ الوضع المستهدف

بعد تنفيذ هذه الخطة يجب أن يصبح السلوك كالتالي:

- لكل `agent_id` توجد **هوية streams ثابتة** لا تتغير عند تبديل `local/cloud`.
- منطق القرار حول نوع الاتصال الحالي يصبح مملوكًا من نقطة واحدة فقط.
- الـ cubits والواجهات لا تعيد الاشتراك لمجرد تغير نوع الاتصال.
- حالة المحادثة تبقى مستقرة أثناء:
  - سقوط الاتصال المحلي
  - التحول التلقائي إلى السحابة
  - عودة الاتصال المحلي
- الويب والموبايل يستهلكان نفس واجهات الـ repository بدون افتراضات local-specific داخل الـ UI.
- `preferred_connection_scope` يصبح إشارة وصفية أو تشخيصية، وليس trigger أساسي لسلوك الواجهة.

---

## 🎯 نطاق العمل

### داخل النطاق

- توحيد ownership للاتصال داخل `sanad-client`.
- تثبيت streams الخاصة بالمحادثات لكل `agent_id`.
- إزالة اعتماد الـ cubits على تبديل `preferredConnectionScope`.
- إعادة تنظيم ownership بين:
  - `AgentConnectionCoordinator`
  - `ConversationClientRegistryImpl`
  - `SocketConversationClient`
  - `ConversationRepository`
- تغطية الاختبارات للوضع المحلي/السحابي وحالات failover.

### خارج النطاق

- تعديل الـ backend أو بروتوكول الرسائل.
- تغيير تصميم الواجهة أو تجربة الاستخدام البصرية.
- إضافة نوع وكيل جديد.
- إعادة تصميم كاملة لمسارات MCP beyond connection ownership.

---

## 🧱 القيود المعمارية

- لا يجب إنشاء نوع agent جديد مثل `local_sanad_agent`.
- لا يجب إرجاع منطق transport إلى الـ widgets.
- لا يجب جعل mobile/web تعتمد على local transport.
- لا يجب جعل `AgentConfig.metadata` المصدر الأساسي لحالة runtime.
- يجب الحفاظ على مبدأ "Single Logical Identity" لكل وكيل كما هو موثق في `sanad-client/AGENTS.md`.

---

## 🏗️ التصميم المقترح

### الفكرة الأساسية

بدل أن يكون مكوّن الاتصال مجرد دالة `resolve()`، يتم اعتماد مكوّن باسم يعكس ownership الفعلي للاتصال:

- `AgentConnectionCoordinator`

ويصبح هذا المكوّن هو **المالك المركزي للـ connection binding الخاص بكل `agent_id`**.

### المسؤوليات الجديدة للمكوّن المركزي

- تحديد الـ transport الفعلي النشط لكل `agent_id`.
- مراقبة lifecycle لكل من:
  - `cloudSocketService`
  - `localSocketService`
- إدارة التحول بين `local` و`cloud`.
- توفير binding ثابت لكل وكيل يمكن لبقية الطبقات الاعتماد عليه.
- إبقاء الـ stream identity ثابتة حتى لو تغير transport.
- تعريض حالة اتصال واضحة وآمنة لباقي التطبيق يمكن استخدامها في الواجهة لعرض ما إذا كان الوكيل يعمل:
  - محليًا
  - عبر السحابة
  - في وضع fallback
  - في طور إعادة الاتصال

### ما الذي يجب أن يبقى خارج المكوّن المركزي

- تحويل raw events إلى `CanonicalEvent`.
- أوامر المحادثة نفسها (`think`, `get_threads`, `get_thread_history`).
- business logic الخاص بالـ UI أو اختيار thread من جانب العرض.

### التعديل المطلوب في ownership

- `AgentConversationStore` يجب أن يصبح stable per-agent، لا tied مباشرة بعمر transport client.
- `SocketConversationClient` يجب أن يصبح أقرب إلى transport adapter.
- `ConversationClientRegistryImpl` يجب أن يتحول إلى cache خفيف أو factory للباندنغ الموحد، وليس نقطة قرار failover.
- أي مسار آخر يختار اليوم بين `local` و`cloud` مثل:
  - capabilities
  - MCP/runtime queries
  - أي feature service يعتمد على socket selection
  يجب أن يعبر من نفس المكوّن المركزي، حتى لا نحل المحادثات فقط ويظل التشتت قائمًا في بقية التطبيق.

### النتيجة المستهدفة لمسار البيانات

**قبل**

`Cubit -> Repository -> Registry -> Scope-specific Client -> Socket Service`

**بعد**

`Cubit -> Repository -> Stable Agent Binding -> Active Transport Adapter -> Socket Service`

---

## 🗂️ الملفات المتأثرة المتوقعة

- `sanad-client/lib/features/agents/data/agent_connection_coordinator.dart`
- `sanad-client/lib/features/agents/data/agent_manager.dart`
- `sanad-client/lib/features/agents/domain/stores/agent_capabilities_store.dart`
- `sanad-client/lib/features/conversations/data/conversation_client_registry_impl.dart`
- `sanad-client/lib/features/conversations/data/clients/socket_conversation_client.dart`
- `sanad-client/lib/features/conversations/data/repositories/socket_conversation_repository.dart`
- `sanad-client/lib/features/conversations/domain/conversation_client.dart`
- `sanad-client/lib/features/conversations/domain/stores/agent_conversation_store.dart`
- `sanad-client/lib/features/conversations/presentation/bloc/thread_messages_cubit.dart`
- `sanad-client/lib/features/conversations/presentation/bloc/thread_cubit.dart`
- أي service أو runtime client يختار socket مباشرة بحسب نوع الاتصال
- `sanad-client/AGENTS.md`

قد تتأثر اختبارات مرتبطة بهذه الملفات أيضًا.

---

## 🪜 خطة التنفيذ المرحلية

### المرحلة 1: تثبيت ownership الخاص بحالة المحادثة

- فصل lifetime الخاص بـ `AgentConversationStore` عن lifetime الخاص بعميل النقل.
- ضمان أن نفس `agent_id` يحتفظ بنفس الحالة حتى عند تبديل transport.
- إبقاء السلوك الحالي كما هو وظيفيًا قدر الإمكان.

### المرحلة 2: تثبيت `AgentConnectionCoordinator` كـ owner فعلي للباندنغ

- إضافة state داخلية لكل `agent_id`.
- نقل قرار التحول بين `local/cloud` إلى المكوّن المركزي نفسه.
- جعل الطبقات الأعلى تعتمد على binding ثابت بدل `resolve()` اللحظي فقط.
- الحفاظ على الاسم الجديد واستخدامه في كل نقاط الحقن والاستيراد لتفادي التداخل المفاهيمي لدى المطورين والوكلاء.

### المرحلة 3: تبسيط الـ registry والـ repository

- تقليل دور `ConversationClientRegistryImpl` إلى cache/factory خفيف.
- جعل `SocketConversationRepository` يعتمد على binding موحد للوكيل.

### المرحلة 4: إزالة scope-driven behavior من الـ cubits

- إزالة إعادة الاشتراك المباشرة المبنية على `preferredConnectionScope`.
- إبقاء `ThreadMessagesCubit` و`ThreadCubit` مستهلكين لـ streams ثابتة فقط.

### المرحلة 5: توحيد كل اتجاهات الاتصال

- نقل أي اختيار مباشر متبقٍ بين `local` و`cloud` في capabilities أو MCP أو runtime queries إلى نفس المكوّن المركزي.
- منع أي مسار جديد من امتلاك قرار transport خارج هذه النقطة الموحدة.

### المرحلة 6: توحيد التوثيق والاختبارات

- تحديث `sanad-client/AGENTS.md` بعقد أوضح لمسؤولية connection ownership.
- إضافة اختبارات تغطي failover continuity.

---

## 🧪 حالات السلوك المطلوبة بعد التنفيذ

1. عند فتح محادثة لوكيل محلي ثم انقطاع الـ local connection:
- تبقى الرسائل الظاهرة كما هي.
- لا يعاد تهيئة واجهة المحادثة.
- يتحول التنفيذ إلى `cloud` داخليًا إن كان ذلك مسموحًا.

2. عند عودة الاتصال المحلي:
- يمكن للـ binding التحول من جديد بدون فقدان الرسائل الحالية.

3. في الويب والموبايل:
- لا توجد أي محاولات لاستخدام local-only runtime من طبقات العرض.
- تستمر نفس واجهات الـ repository بالعمل بدون branching في الـ UI.

4. في الـ threads والـ processing:
- تظل subscriptions مستقرة لنفس `agent_id`.
- لا تُفقد حالة الـ processing فقط بسبب تبديل transport.

5. في الواجهة:
- تبقى هناك قيمة صريحة يمكن عرضها للمستخدم توضّح طريقة الاتصال الحالية.
- تستخدم هذه القيمة للعرض وحالة المنتج فقط، وليس لتقرير ownership أو إعادة بناء subscriptions.

---

## ⚠️ المخاطر المحتملة

1. **تضخم مسؤولية `AgentConnectionCoordinator`**

إذا تم نقل كل شيء إليه دون تنظيم داخلي، قد يتحول إلى ملف ضخم وصعب الصيانة.

**التخفيف**
- استخدام private helper classes/state داخله بدون توسيع surface area العامة.

2. **race conditions أثناء reconnect**

قد تتسابق أحداث local disconnect مع إعادة الربط أو history hydration.

**التخفيف**
- جعل ownership واحدًا للباندنغ.
- إضافة اختبارات واضحة لحالات local -> cloud -> local.

3. **regressions في اختيار thread أو تحميل history**

أي تغيير في lifetime قد ينعكس على `activateThread()` و`loadThreadHistory()`.

**التخفيف**
- الحفاظ على tests الحالية.
- إضافة tests مخصصة لاستقرار المحادثة أثناء تبديل scope.

4. **الاعتماد الخفي في أماكن أخرى على `preferredConnectionScope`**

قد تبقى استهلاكات متناثرة داخل التطبيق حتى بعد refactor المسار الرئيسي.

**التخفيف**
- فحص كل مراجع `preferredConnectionScope` و`prefersLocalConnection` قبل الإغلاق.

5. **الخلط بين قيمة العرض للمستخدم ومصدر الحقيقة الداخلي**

ما زلنا نحتاج قيمة توضّح في الواجهة هل الاتصال محلي أم سحابي، لكن لو استُخدمت هذه القيمة في business logic فسيعود التداخل السابق.

**التخفيف**
- الإبقاء على `preferred_connection_scope` أو استبداله لاحقًا باسم أوضح.
- توثيق أن هذا الحقل display/debug metadata فقط.
- جعل قرار transport binding الفعلي محصورًا في المكوّن المركزي.

---

## ✅ معايير القبول

تعتبر المهمة ناجحة فقط إذا تحققت جميع الشروط التالية:

- لا تعتمد الـ cubits على `preferredConnectionScope` لإعادة الاشتراك في streams.
- يبقى محتوى المحادثة ظاهرًا عند التحول من `local` إلى `cloud` لنفس الوكيل.
- تصبح streams الخاصة بالمحادثة مستقرة لكل `agent_id`.
- يبقى قرار الاتصال مركزيًا داخل نقطة ownership واحدة.
- لا يظهر branching خاص بالاتصال داخل طبقات العرض.
- تبقى هناك قيمة قابلة للعرض في الواجهة توضّح ما إذا كان الوكيل يعمل محليًا أو عبر السحابة.
- لا تُستخدم هذه القيمة المعروضة كمصدر قرار لإعادة اختيار transport أو إعادة الاشتراك في الـ streams.
- يمر `analyze` والاختبارات ذات الصلة بدون regressions.

---

## 🔍 طريقة التحقق

### تحقق آلي

- `fvm flutter analyze`
- `fvm flutter test`
- `fvm flutter test e2e_test/ --concurrency=1`

### اختبارات يجب إضافتها أو تحديثها

- اختبار وحدة يؤكد أن تبديل `local -> cloud` لا يفرغ الرسائل الحالية.
- اختبار وحدة يؤكد أن `ThreadMessagesCubit` لا يعيد بناء اشتراكاته اعتمادًا على metadata فقط.
- اختبار تكاملي يؤكد أن نفس `agent_id` يحتفظ بنفس stream identity عبر تبديل transport.
- اختبار E2E محلي إن أمكن لتغطية سيناريو الانقطاع والعودة.
- اختبار يؤكد أن قيمة طريقة الاتصال الظاهرة للمستخدم تبقى صحيحة دون أن تتحول إلى source of truth للـ binding.

### تحقق يدوي

- فتح محادثة لوكيل SanadAgent محلي على الدسك توب.
- قطع الاتصال المحلي مع بقاء التطبيق مفتوحًا.
- التأكد من أن الرسائل الحالية لا تختفي.
- إعادة الاتصال المحلي والتحقق من استمرار السلوك بدون reset.
- اختبار الشاشة نفسها على mobile/web للتأكد من عدم وجود افتراضات local-specific.

---

## 📝 التوثيق المطلوب

- تحديث `sanad-client/AGENTS.md` لتوضيح:
  - من يملك قرار الاتصال.
  - الاسم الجديد للمكوّن المركزي ومسؤوليته.
  - أن stream identity يجب أن تبقى ثابتة لكل `agent_id`.
  - أن تبديل transport يجب ألا يفرغ المحادثة المفتوحة.
  - أن قيمة طريقة الاتصال الظاهرة للمستخدم قيمة عرضية وليست source of truth لسلوك الطبقات العليا.

- تحديث أي خطط أو ملاحظات تنفيذية مرتبطة بالمحادثات والـ dual connection إذا تغير العقد الحالي.

---

## ❓قرارات تحتاج تأكيدًا قبل التنفيذ

تم حسم القرارات التالية واعتمادها ضمن هذه الخطة:

- **إعادة التسمية مطلوبة**
  تم اعتماد اسم `AgentConnectionCoordinator` لأنه يعكس الوظيفة الجديدة ويقلل التداخل المفاهيمي لدى المطورين والوكلاء الذين يعملون على الكود.

- **النطاق يشمل كل اتجاهات الاتصال**
  الهدف ليس إصلاح conversation flow فقط، بل تجريد طبقة الاتصال في مكان واحد بحيث لا يعرف باقي التطبيق ولا يهمه ما هي طريقة الاتصال.

- **الإبقاء على قيمة توضح طريقة الاتصال مسموح ومطلوب**
  يمكن الإبقاء على `preferred_connection_scope` أو استبداله لاحقًا باسم أوضح، بشرط أن يبقى:
  - قيمة للعرض في الواجهة
  - مفيدًا للتشخيص وdebugging
  - وليس مصدر الحقيقة الخاص بقرار transport binding

بناءً على ذلك، لا توجد قرارات مفتوحة تمنع بدء التنفيذ، والخطة جاهزة للاعتماد والتنفيذ.

</div>
