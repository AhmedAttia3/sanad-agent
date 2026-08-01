---
title: "Task 32f: Responsive Integration and Regression QA"
parent_plan: "docs/plans/32-device-workspace-conversation-ux-redesign.md"
status: "pending"
current_gate: "waiting_for_32a_to_32e"
---

# Task 32f: Responsive Integration and Regression QA

## الحالة والاعتماديات

- الحالة: `pending` — تنتظر اكتمال ومراجعة `32a` إلى `32e`.
- هذه مهمة دمج وتحقيق، وليست مكانًا لإعادة تعريف العقود.
- أي عيب معماري يعاد إلى المهمة المالكة بدل إضافة workaround في الاختبار.

## قاعدة التنفيذ والتحديث

- [ ] لا يبدأ F0 حتى تصبح 32a-32e `complete` أو يوثق استثناء في الخطة الرئيسية.
- [ ] يحدث الوكيل status/current gate ولوحة الخطة عند كل انتقال.
- [ ] finding تعيد فتح Gate المهمة المالكة وتحدث لوحة الخطة قبل الإصلاح.
- [ ] لا تغلق الخطة الرئيسية قبل F4 Final Review.

## بوابات التنفيذ

### Gate F0: Entry Audit and Matrix Lock

- [ ] مراجعة DoD وسجلات التحقق للمهام 32a-32e.
- [ ] حصر أي checkbox أو توثيق أو finding مفتوح وإعادته للمالك.
- [ ] تثبيت platform/scenario matrix وربط كل سيناريو باختبار أو تحقق يدوي.

#### Gate F0 Exit

- [ ] لا يبدأ الدمج حتى تصبح المدخلات مكتملة وقابلة للاختبار.

### Gate F1: Automated Integration Coverage

- [ ] تنفيذ/تحديث unit وwidget وintegration coverage للسيناريوهات.
- [ ] تغطية cache/restart/pagination/live ordering/drafts/navigation/deletion.
- [ ] تغطية regressions الخاصة بخطط 30 و31 والعقود الحالية.

#### Gate F1 Exit

- [ ] مراجعة أن assertions تقيس السلوك الحقيقي لا نتيجة غير مباشرة.

### Gate F2: Responsive and Platform Verification

- [ ] تحقق macOS/desktop وtablet وmobile portrait وweb.
- [ ] تحقق browser navigation وdeep links وmobile drawer/header.
- [ ] توثيق screenshots/findings عند الحاجة وإعادة العيوب للمهام المالكة.

#### Gate F2 Exit

- [ ] لا توجد عيوب P0/P1 أو overflow/flash/navigation blockers مفتوحة.

### Gate F3: Performance, Failure, and Full Regression

- [ ] تحقق first paint من cache وbounded cache وlazy section loading.
- [ ] تحقق rebuild scope والanimation والscroll stability.
- [ ] تحقق offline/reconnect/logout/failure/late response.
- [ ] تشغيل التحليل والسويتات المتأثرة وتوثيق النتائج.

#### Gate F3 Exit

- [ ] مراجعة النتائج وإغلاق كل regressions أو إعادة فتح مالكها.

### Gate F4: Documentation and Plan Closure

- [ ] تحديث product/technical/QA/AGENTS docs وفق التنفيذ الفعلي.
- [ ] تحديث كل مهمة وحالتها وسجلها دون checkboxes مفتوحة.
- [ ] تحديث لوحة الخطة الرئيسية إلى النتائج النهائية.
- [ ] إجراء Final Review لكل Definition of Done.
- [ ] تغيير هذه المهمة والخطة الرئيسية إلى `complete` ونقلهما للمكان المعتمد عند الإغلاق.

#### Gate F4 Exit

- [ ] لا يبقى finding أو اختبار أو توثيق مطلوب مفتوحًا.

## الهدف

إثبات أن التجربة الكاملة تعمل على desktop/tablet/mobile/web، وأن الكاش والاستعادة والتنقل والتحديث الحي لا تكسر عقود المحادثة الحالية.

## مصفوفة المنصات

- macOS desktop مع sidebar ثابتة ومساحة traffic lights.
- Windows/Linux desktop behavior المكافئ.
- tablet breakpoint مع drawer/collapsed navigation.
- mobile portrait وعرض ضيق.
- web مع browser Back/Forward وdeep links.

## سيناريوهات التكامل

1. cold start من cache ثم daemon refresh.
2. تبديل جهازين مع session ومسودة وWorkspace مختلفة لكل واحد.
3. restart واستعادة active device وآخر sessions وexpansion والدrafts.
4. توسيع Workspace وتحميل أول ست جلسات ثم Load more.
5. canonical user message في session قديمة وتحركها إلى الأعلى حيًا.
6. إنشاء New Conversation عامة وأخرى من plus Workspace دون session مبكرة.
7. optional Workspace select/clear وrequired Workspace validation.
8. فتح session سريع وبطيء وفاشل دون وميض أو فقد السياق.
9. حذف current/non-current وحذف خارجي أثناء history request.
10. Back/Forward عبر sessions وأجهزة ثم حذف entry من التاريخ.
11. offline cached device ثم reconnect وmerge.
12. logout cloud مع بقاء local inventory boundary.

## Regression coverage

- queued messages وsteering.
- pending permission/clarifying suspension.
- runtime recovery notices وخطة 30.
- execution indicators وخطة 31 إذا كانت منفذة.
- provider/model display وعدم ظهور UUID خام.
- provider setup gate عند تبديل device.
- workspace permission mode وMCP/skill runtime bindings.
- voice entry points وعدم كسر composer actions.
- deep links الحالية ومسارات settings/device management.

## جودة الواجهة

- لا overflow أو clipped controls.
- touch targets وkeyboard focus وtooltips/semantics صحيحة.
- لا empty flash عند device/session switch.
- animations لا تغير scroll position ولا تسبب rebuild storms.
- loading/error/refresh states مفهومة وغير حاجبة عند توفر cache.
- New Conversation لا تعرض App Bar أو controls غير لازمة.
- mobile header يعرض title ثم Workspace subtitle عند وجودها.

## الأداء والمراقبة

- أول paint من persistent cache لا ينتظر daemon.
- توسيع Workspace لا يجلب أقسامًا أخرى.
- event واحدة لا تعيد بناء sidebar كاملة.
- cache bounded وسياسة cleanup قابلة للاختبار.
- logging يقتصر على lifecycle/failure عالي الإشارة ولا يسجل draft text.

## مخرجات التوثيق

- تحديث `sanad-agent/docs/product/client_interface.md` بالشكل النهائي.
- تحديث `sanad-agent/docs/technical/communication_protocols.md` بالعقد المنفذ.
- إضافة QA matrix في `sanad-agent/docs/qa_maintenance/` تغطي السيناريوهات السابقة.
- تحديث العقود المحلية `AGENTS.md` المتأثرة في نفس جلسات تنفيذ الكود.
- نقل الخطة/المهام إلى حالة منجزة فقط بعد توثيق نتائج التحقق.

## Definition of Done

- [ ] كل معايير القبول في الخطة الرئيسية مثبتة آليًا أو بسيناريو يدوي موثق عند تعذر الأتمتة.
- [ ] التحليل واختبارات الوحدات/widgets والتكامل المتناسبة مع blast radius ناجحة.
- [ ] لا regressions في conversation runtime أو provider/workspace flows.
- [ ] لا تبقى TODOs عقدية أو مصادر حالة متنافسة.
- [ ] وثائق product/technical/QA والعقود المحلية متسقة مع التنفيذ الفعلي.

## سجل التقدم

لا يوجد تنفيذ بعد. يضيف المنفذ إدخالًا مؤرخًا عند كل Gate وفق قالب الخطة الرئيسية.
