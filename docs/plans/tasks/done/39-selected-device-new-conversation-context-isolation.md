---
title: "Selected-Device Conversation Context Isolation and New Session Restoration"
description: "ضمان عرض سياق كل محادثة بصورة صحيحة، وعزل سياق الأجهزة، وتهيئة New Session من آخر محادثة مفتوحة على الجهاز المحدد مع احترام Workspace المقصود."
status: "completed"
completed_at: "2026-07-16"
scope: "client ui, device-scoped conversation state, and thinking-mode naming compatibility"
---

# Task 39: Selected-Device Conversation Context Isolation and New Session Restoration

## 1. الهدف

ضمان أن تعرض واجهة المحادثة دائمًا السياق الصحيح للمحادثة أو للجلسة الجديدة،
من دون تسريب `workspace` أو `provider` أو `model` أو `thinking mode` أو
`permission mode` من محادثة أو جهاز آخر.

المقصود بـ **الجهاز** في هذه المهمة هو `Selected Device` الحالي. جميع عمليات
الحفظ والاستعادة والبحث عن آخر محادثة تكون معزولة بمفتاح ذلك الجهاز، وليست
حالة عامة مشتركة على مستوى تطبيق العميل.

## 2. المشكلات المشمولة

- عند التنقل بين المحادثات قد تعرض أدوات الإدخال مساحة العمل أو المزوّد أو
  النموذج أو مستوى التفكير أو الإذن الخاص بالمحادثة السابقة.
- Draft الجلسة الجديدة يحتفظ أحيانًا بقيم قديمة بسبب نمط `copyWith` الذي يبقي
  الحقل السابق عند عدم تمرير قيمة جديدة أو أمر مسح صريح.
- زر `New Session` أعلى السايدبار يفتح حاليًا جلسة بلا Workspace صريح بدل
  استعادة سياق آخر محادثة مفتوحة على الجهاز المحدد.
- زر `+` بجوار Workspace قد يترك بعض سياق New Session السابق ظاهرًا، أو يسمح
  بربط إذن Workspace سابق بالـ Workspace الجديد.
- إذا كانت شاشة New Session مفتوحة على `Workspace A` ثم ضغط المستخدم `+`
  بجوار `Workspace B`، يجب أن تتحول الشاشة نفسها إلى `Workspace B` فورًا.
- عند فتح جلسة ذات `thinkingMode` فارغ أو مختلف، يحتفظ
  `SessionMessagesCubit` أحيانًا بالقيمة السابقة داخل الحالة المفهرسة حسب
  الجهاز؛ وبما أن واجهة message-scope تفضّل `nextMessageThinkingMode`، فقد
  تعرض مستوى تفكير الجلسة السابقة بدل الحالة الصحيحة للجلسة الحالية.

## 3. تجربة المستخدم المطلوبة

### 3.1 التنقل إلى محادثة موجودة

عند فتح محادثة موجودة، تعرض الواجهة القيم التابعة لتلك المحادثة فقط:

- Workspace المحادثة.
- المزوّد والنموذج.
- مستوى التفكير.
- الإذن الحقيقي للـ Workspace المرتبط بها.

لا تبقى أي قيمة مرئية من المحادثة السابقة، ولا تنتقل قيم من جهاز آخر.

### 3.2 زر `New Session` أعلى السايدبار

عند الضغط على الزر:

1. يكون الجهاز المستهدف هو `Selected Device` الحالي.
2. تُحدد آخر محادثة كانت مفتوحة على هذا الجهاز فقط.
3. تُهيأ New Session باستخدام Workspace والمزوّد والنموذج ومستوى التفكير من
   تلك المحادثة.
4. يُعرض الإذن الحقيقي للـ Workspace المستعاد، ولا يُنسخ إذن محفوظ من محادثة
   أو Workspace آخر.
5. إذا لم توجد محادثة سابقة صالحة على الجهاز، تُستخدم القيم الافتراضية الآمنة
   المتاحة لذلك الجهاز، من دون الرجوع إلى سياق جهاز آخر.

### 3.3 زر `+` بجوار Workspace

عند الضغط على `+` بجوار `Workspace B`:

1. يكون الجهاز المستهدف هو الجهاز الذي تنتمي إليه `Workspace B`.
2. تُفرض `Workspace B` على New Session بصرف النظر عن Workspace المعروضة قبل
   الضغط.
3. يُعرض الإذن الحقيقي الخاص بـ `Workspace B`، ولا يُورث إذن Workspace آخر.
4. يُستعاد المزوّد والنموذج ومستوى التفكير من آخر محادثة مفتوحة على الجهاز
   نفسه.
5. إذا كانت New Session ظاهرة بالفعل على `Workspace A`، تتحدث فورًا إلى
   `Workspace B` من دون إنشاء جلسة قبل إرسال أول رسالة.

## 4. ملكية الحالة وقواعد العزل

- آخر محادثة مفتوحة وسياق New Session ملكية مستقلة لكل `deviceId`.
- تغيير `Selected Device` يعيد ربط الواجهة بسياق الجهاز الجديد كاملًا.
- لا يجوز استخدام آخر محادثة عامة على مستوى العميل كمرجع للاستعادة.
- بيانات الجلسة الموجودة هي المرجع لعرض provider/model/thinking الخاص بها.
- عند ربط جلسة موجودة، يجب استبدال حالة التفكير المرئية صراحةً بقيمة الجلسة؛
  غياب `thinkingMode` لا يعني الاحتفاظ الصامت بقيمة الجلسة السابقة. عند
  الغياب يُعرض fallback المعلن في capabilities أو تفضيل الجهاز فقط وفق قاعدة
  موحدة، وليس أثرًا متبقيًا من جلسة أخرى.
- `thinkingMode` القادم من session payload/cache هو مرجع الجلسة الموجودة،
  بينما `ConversationDraft.thinkingMode` هو مرجع New Session الخاصة بالجهاز.
  لا يجوز خلط المصدرين أثناء انتقال route أو session binding.
- سياسة Workspace هي المرجع لإذنها؛ draft المحادثة لا يملك صلاحية كتابة إذن
  موروث على Workspace أخرى أثناء الاستعادة.
- تمرير Workspace صريحة من زر `+` له أولوية على Workspace المستعادة من آخر
  محادثة.
- إنشاء الجلسة الفعلية يبقى مؤجلًا إلى إرسال أول رسالة.

### 4.1 عقد تسمية مستوى التفكير

تعتمد المهمة اسمًا واحدًا فقط لمستوى التفكير:

- الاسم canonical داخل جميع نماذج Dart وحالات Cubit وواجهات Repository هو
  `thinkingMode`.
- الاسم الوحيد في wire payloads وJSON persistence وSQLite هو `thinking_mode`.
- لا توجد طبقة توافق أو تسمية بديلة؛ أي payload أو cache أو metadata خاص بهذه
  المنظومة يجب أن يستخدم `thinking_mode` مباشرة.
- هذا القرار يوحّد تمثيل القيمة فقط. ترجمة `thinkingMode` إلى حقول كل مزود LLM
  مثل `reasoning_effort` أو token budget تبقى خارج Task 39 ومملوكة لـ Task 43.

## 5. النطاق المرحلي

### Gate A — تحديد مصادر الحالة ومنع العرض العابر

- [x] تتبع ربط الواجهة عند الانتقال بين الجلسات والأجهزة وتحديد مواضع بقاء
  provider/model/thinking/workspace/permission من الربط السابق.
- [x] جعل إعادة ربط المحادثة عملية ذرية أو محمية بهوية الجلسة والجهاز، بحيث لا
  تظهر بيانات جلسة أخرى أثناء الاستعادة غير المتزامنة.
- [x] عند تغيير الجلسة، استبدال أو مسح حالة التفكير السابقة قبل عرض الجلسة
  الجديدة؛ لا يكفي تحديث الخريطة عندما تكون القيمة الجديدة non-null فقط.
- [x] ضمان أن إعادة session payload أو cache hydration المتأخرة لا تعيد
  `thinkingMode` لجلسة لم تعد هي الجلسة النشطة.
- [x] جعل selector يعرض مصدرًا محددًا حسب السطح: session metadata للجلسة
  الموجودة، وdevice-scoped draft لـ New Session، مع fallback واضح عند الغياب.
- [x] إضافة اختبارات انتقال بين محادثتين بقيم مختلفة، وبين جلسة بقيمة وجلسة
  بلا قيمة، واختبار انتقال بين جهازين بقيم مختلفة.

### Gate B — استعادة New Session حسب الجهاز المحدد

- [x] إنشاء مسار واحد يحدد آخر محادثة مفتوحة لكل `deviceId` ويستخرج منها
  Workspace والمزوّد والنموذج ومستوى التفكير.
- [x] جعل زر `New Session` العلوي يستخدم ذلك المسار للجهاز المحدد.
- [x] توفير fallback آمن عند غياب آخر محادثة أو عدم صلاحية Workspace أو
  provider/model المحفوظين.
- [x] منع أي fallback إلى سياق جهاز آخر.

### Gate C — فرض Workspace من زر `+` وعزل الإذن

- [x] توحيد مساري الزر العلوي وزر Workspace مع دعم Workspace override صريح.
- [x] ضمان أن الضغط على `+` بجوار `Workspace B` يستبدل `Workspace A` حتى إذا
  كانت New Session مفتوحة بالفعل.
- [x] منع استعادة permission mode موروث على Workspace المستهدفة.
- [x] تحميل وعرض سياسة Workspace المستهدفة باعتبارها المصدر الموثوق للإذن.
- [x] التحقق من عدم إرسال `workspace.set_permission_mode` لمجرد فتح أو استعادة
  New Session.

### Gate D — توحيد تسمية Thinking Mode

- [x] توحيد حقول Dart الداخلية على `thinkingMode`، وبالأخص نموذج `Session`
  ومسارات mapping/cache/UI التابعة له.
- [x] جعل daemon session payload وclient commands وcanonical payloads تكتب
  `thinking_mode` فقط.
- [x] تحديث Conversation Cache codec لاستخدام الاسم canonical فقط.
- [x] البحث عن أي تسمية بديلة ومنع بقائها في code أو payloads أو persistence.
- [x] إضافة اختبارات round-trip للـ daemon SQLite/session payload ولـ client cache.

### Gate E — التوثيق والتحقق

- [x] إضافة اختبارات Cubit/Store لمسارات الاستعادة والعزل حسب الجهاز.
- [x] إضافة اختبارات Widget لكلا زري New Session وللتنقل بين الجلسات.
- [x] تحديث وثائق UX وQA وعقد `client/AGENTS.md` أو العقدة الأقرب بما يعكس
  الملكية حسب الجهاز وقواعد الاستعادة.
- [x] نجاح `fvm flutter analyze` والاختبارات المركزة المتأثرة.

## 6. سيناريوهات القبول

- [x] على الجهاز `D1`، فتح جلسة `S2` بعد `S1` يعرض قيم `S2` فقط لكل حقول
  السياق الخمسة.
- [x] إذا كان `S1.thinkingMode = deep` و`S2.thinkingMode = fast`، يعرض
  selector القيمة `fast` فور اكتمال ربط `S2` ولا يعود إلى `deep` بسبب استجابة
  متأخرة.
- [x] إذا كان `S1.thinkingMode = deep` ولا تحمل `S2` قيمة، لا تعرض الواجهة
  `deep` على أنها قيمة `S2`؛ تستخدم قاعدة fallback المعلنة دون أثر متبقٍ من
  `S1`.
- [x] بعد إعادة تشغيل العميل أو إعادة hydration، تعرض كل جلسة `thinkingMode`
  المستعاد من session metadata/cache، وتعرض New Session قيمة draft الخاصة
  بالجهاز المحدد فقط.
- [x] الانتقال من `D1` إلى `D2` لا يعرض أو يستعيد أي Workspace أو provider أو
  model أو thinking أو permission من `D1`.
- [x] زر `New Session` على `D1` يستعيد Workspace/provider/model/thinking من
  آخر محادثة مفتوحة على `D1`، حتى إذا كانت آخر محادثة عامة في العميل على
  `D2`.
- [x] إذن New Session يطابق سياسة Workspace المستعادة فعليًا ولا يغيّرها.
- [x] زر `+` بجوار `Workspace B` يفتح New Session على `B` ويعرض إذن `B`، مع
  استعادة provider/model/thinking من آخر محادثة على الجهاز نفسه.
- [x] أثناء عرض New Session على `Workspace A`، الضغط على `+` بجوار
  `Workspace B` يحدّث الاختيار إلى `B` فورًا.
- [x] فتح New Session أو استعادة draft لا يكتب permission mode على daemon ولا
  يبث `workspace.policy_changed` بلا اختيار صريح من المستخدم.
- [x] لا تُنشأ جلسة daemon قبل إرسال الرسالة الأولى.
- [x] لا يحتوي domain/presentation على تسمية بديلة؛ يستخدم `thinkingMode` فقط.
- [x] كل payload صادر عن client أو daemon وكل cache يستخدم `thinking_mode` فقط.

## 7. مناطق الكود المتوقع فحصها

- `client/lib/features/conversations/presentation/bloc/session_cubit.dart`
- `client/lib/features/conversations/presentation/bloc/session_sidebar_cubit.dart`
- `client/lib/features/conversations/presentation/bloc/session_messages_cubit.dart`
- `client/lib/features/conversations/presentation/bloc/conversation_input_cubit.dart`
- `client/lib/features/conversations/presentation/widgets/conversation_input_panel.dart`
- `client/lib/features/conversations/presentation/widgets/sidebar/device_workspace_sidebar.dart`
- `client/lib/features/conversations/domain/models/device_conversation_context.dart`
- `client/lib/features/conversations/domain/stores/conversation_cache_store.dart`
- `client/lib/features/conversations/data/persistence/conversation_cache_codec.dart`
- `agent/lib/interfaces/session_payload_builder.dart`
- `agent/lib/evolution/models/session_state.dart`
- `agent/lib/evolution/db/session_db.dart`
- الاختبارات المركزة المقابلة تحت `client/test/` و`agent/test/`.

القائمة استكشافية وليست إذنًا لتغيير كل الملفات؛ يُحسم نطاق التعديل بعد تتبع
مصدر كل قيمة واختبار السلوك الحالي.

## 8. خارج النطاق

- تغيير بروتوكول daemon أو ملكيته لسياسة Workspace ما لم يثبت وجود خلل مستقل
  لا يمكن إصلاحه في العميل. الاستثناء المحدد داخل النطاق هو توحيد مفتاح `thinking_mode` في session payload.
- جعل حالة New Session مشتركة بين جميع الأجهزة.
- تغيير Workspace لجلسة موجودة بعد إنشائها.
- إنشاء جلسة مبكرًا عند فتح New Session.
- إعادة تصميم عناصر اختيار provider/model/thinking بصريًا ما لم يلزم تصحيح
  عرض الحالة.

## 9. Regression hardening — New Conversation presentation ownership

- [x] الاحتفاظ بـ `lastSelectedSessionId` لاستعادة سياق New Conversation لا يعني
  إعادة اختيار تلك الجلسة بعد أن أصبحت New Conversation هي الوجهة المعروضة.
- [x] تحديثات cache المتأخرة أو الناتجة عن تهيئة draft لا تخرج الواجهة من
  `/conversations/:deviceId/new` ولا تطلب history لجلسة سابقة.
- [x] إعادة تطبيق نفس New Conversation route لنفس الجهاز وWorkspace عملية
  idempotent: لا تعيد `beginNewSession` ولا تعيد بث تهيئة draft/policy.
- [x] إضافة اختبار regression ينتظر cache microtasks بعد `startNewChat` ويثبت بقاء
  `selectedSession == null` مع عدم تكرار new-session initialization.

### Composer transition isolation

- [x] عند الانتقال من New Conversation إلى جلسة موجودة، يرتبط composer draft
  بـ `requestedSessionId` فورًا ولا ينتظر اكتمال history hydration.
- [x] تبقى هوية timeline المعروضة مملوكة لـ `activeSessionId` حتى يكتمل التبديل
  الذري؛ فصل draft identity لا يضعف عقد atomic session presentation.
- [x] اختبار Widget يثبت أن New Conversation draft لا يظهر في loading transition
  لجلسة موجودة.
