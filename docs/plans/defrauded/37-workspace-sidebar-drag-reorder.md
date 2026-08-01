---
title: "Workspace Sidebar Drag Reorder"
description: "إضافة إعادة ترتيب الـ Workspaces بالسحب في القائمة الجانبية، مع طي تلقائي لكل الـ workspaces أثناء السحب واسترجاع حالة التوسع الأصلية عند الإفلات، وحفظ الترتيب في cache العميل."
status: "planned"
scope: "client sidebar"
parent_plan: "docs/plans/32-device-workspace-conversation-ux-redesign.md"
---

# Task 37: Workspace Sidebar Drag Reorder

## 1. المشكلة

الـ sidebar الحالي (Plan 32c) يعرض الـ Workspaces بترتيب ثابت يأتي من الـ daemon،
حيث يرتّبها أبجديًا مع وضع الـ current أولاً. لا يستطيع المستخدم إعادة ترتيب
الـ workspaces يدويًا. عند كل `refreshWorkspaces` يُستبدل الترتيب بالكامل بقائمة
الـ daemon الجديدة، ولا يوجد أي مفهوم لترتيب محفوظ من المستخدم عبر الجلسات.

النموذج المرجعي موجود بالفعل في الكود: `workspaceExpansion` — وهو `Map<String, bool>`
محفوظ في `DeviceConversationContext` عبر codec ومُطبّق في `sidebarSnapshotFor()` ويُحافظ
عليه `applyWorkspacesRefreshed()` دون مسحه. لكن `workspaceOrder` يماثله لا يوجد.

السلوك التفاعلي المطلوب: يضغط المستخدم مطولاً على workspace tile ثم يسحبها لإعادة
الترتيب. أثناء السحب يجب أن تنطوي جميع الـ workspaces المفتوحة (collapse) حتى يرى
المستخدم الـ tiles فقط ويسحبها بحرية. عند الإفلات تعود كل workspace لحالتها الأصلية:
التي كانت مفتوحة تبقى مفتوحة، والتي كانت مقفلة تبقى مقفلة. ثم يُحفظ الترتيب الجديد
ويبقى عبر التنقل بين الأجهزة وإعادة تشغيل التطبيق.

## 2. قرارات التصميم

- الترتيب محفوظ **client-side فقط** في `ConversationCacheStore`، لا تعديل على الـ daemon
  أو بروتوكول socket جديد. الـ daemon يبقى المصدر لـ "أي workspaces موجودة" بينما
  الـ client يملك "ترتيب العرض".
- يُضاف `workspaceOrder: List<String>` إلى `DeviceConversationContext` يماثل
  `workspaceExpansion` في البنية والآلية: محفوظ عبر codec، مطبّق في snapshot، محفوظ
  عبر refresh.
- الـ `workspaceOrder` قائمة IDs. الـ workspaces غير المذكورة (جديدة من الـ daemon)
  تُلحق في النهاية بالترتيب الأبجدي. هذا يضمن ظهور الـ workspaces الجديدة تلقائيًا
  دون كسر ترتيب المستخدم.
- `workspaceOrder == []` يعني "استخدم الترتيب الافتراضي من الـ daemon" — آمن للتوافق
  العكسي ولا يتطلب رفع `schemaVersion`.
- طي/استرجاع الـ expansion أثناء السحب يُدار محليًا في `StatefulWidget` عبر flag
  `_isReordering` مع `onReorderStart`/`onReorderEnd`، **لا** يُضاف state للـ cubit.
  الأسباب: (1) عابر لا يحتاج persistence، (2) الـ snapshot stream يبقى مصدر الـ expansion
  الحقيقي دون تشويش بـ overlay، (3) يتجنب race condition بين snapshot stream و
  reordering flag.
- يُستخدم `SliverReorderableList` داخل الـ `CustomScrollView` الحالي لأن الـ sidebar
  يستخدم slivers بالفعل. هذا أنظف من تحويل كل الـ sidebar لمحتوى non-sliver.
- الـ "Workspaces" heading يبقى `SliverToBoxAdapter` منفصل، ثم `SliverReorderableList`
  للـ tiles، ثم `SliverToBoxAdapter` لقسم Conversations التالي. البنية الـ sliver
  الحالية تسمح بذلك مباشرة.
- الـ drag handle هو الـ workspace tile بالكامل (long press). لا يُضاف handle منفصل
  لإبقاء الـ touch target كبيرًا ومتسقًا مع النمط الحالي.

## 3. النطاق المرحلي

### Gate R1 — Domain Layer: `workspaceOrder` Model + Codec

- [ ] إضافة `workspaceOrder: List<String>` إلى `DeviceConversationContext` مع default
  `const []` ودمجه في `copyWith` و`props`.
- [ ] إضافة `workspaceOrder` إلى ترميز/فك `conversation_cache_codec.dart`
  (`_contextToJson` و`_contextFromJson`). الحقل اختياري عند decode وdefault `[]`،
  فلا يتطلب رفع `schemaVersion`.
- [ ] إضافة `workspaceOrder` إلى `DeviceSidebarSnapshot` لتمريره للـ UI إن لزم.
- [ ] اختبارات codec: encode/decode round-trip يحفظ `workspaceOrder`، و decode payload
  قديم بدون الحقل يعطي `[]`.
- [ ] `fvm flutter analyze` نظيف.

#### معايير قبول Gate R1

- [ ] `workspaceOrder` ينجو من JSON round-trip.
- [ ] decode payload بدون `workspaceOrder` لا يكسر (default `[]`).
- [ ] لا يرتفع `schemaVersion` ولا يبطل cache قديم.
- [ ] التحليل واختبارات codec المركزة ناجحة.

### Gate R2 — Store: `setWorkspaceOrder` + Snapshot Ordering Projection

- [ ] إضافة `setWorkspaceOrder(String deviceId, List<String> orderedIds)` إلى
  `ConversationCacheStore` يعدّل `workspaceOrder` ويُصدر snapshot.
- [ ] إضافة `_applyWorkspaceOrder(List<DeviceWorkspace>, List<String>)` helper
  يطبّق ترتيب المستخدم: الـ IDs المذكورة بترتيبها، ثم الـ workspaces الجديدة
  (غير المذكورة) ملحقة بالترتيب الأبجدي.
- [ ] استخدام `_applyWorkspaceOrder` في `sidebarSnapshotFor()` بدل `ctx.workspaces.workspaces`
  المباشر.
- [ ] تحديث `applyWorkspacesRefreshed()` لتنظيف `workspaceOrder` من الـ IDs المهجورة
  (محذوفة من الـ daemon) مع الحفاظ على ترتيب الباقي.
- [ ] تحديث `applyWorkspaceCreated()` لإدراج الـ workspace الجديد في موضع يحترم
  `workspaceOrder` (في النهاية إذا لم يذكر، أو موقعه إن كان موجودًا).
- [ ] اختبارات store: الترتيب يطبّق، workspaces جديدة تُلحق، مهجورة تُحذف من الـ order،
  refresh يحافظ على order، create يحترم order.

#### معايير قبول Gate R2

- [ ] snapshot.workspaces تأتي بترتيب المستخدم عند وجود `workspaceOrder`.
- [ ] `workspaceOrder == []` يعطي ترتيب الـ daemon الأصلي.
- [ ] refresh لا يمسح ترتيب المستخدم للـ workspaces الباقية.
- [ ] workspace محذوف من الـ daemon يُحذف من `workspaceOrder` تلقائيًا.
- [ ] workspace جديد يظهر في نهاية الترتيب.
- [ ] التحليل واختبارات store المركزة ناجحة.

### Gate R3 — Repository + Cubit: `reorderWorkspaces` Intent

- [ ] إضافة `reorderWorkspaces(String deviceId, List<String> orderedWorkspaceIds)`
  إلى `ConversationCacheRepository` يفوّض إلى `_cache.setWorkspaceOrder`.
- [ ] إضافة `reorderWorkspaces(String deviceId, List<String> orderedWorkspaceIds)`
  إلى `SessionSidebarCubit` يفوّض إلى الـ repository.
- [ ] اختبار cubit: استدعاء `reorderWorkspaces` يمرّر الترتيب للـ repository.

#### معايير قبول Gate R3

- [ ] الـ intent يصل من cubit إلى store دون تخزين state إضافي في الـ cubit.
- [ ] الـ cubit لا يملك ترتيبًا محليًا؛ الـ store هو المصدر الوحيد.
- [ ] التحليل والاختبارات المركزة ناجحة.

### Gate R4 — UI: Reorderable Section Widget مع Collapse/Restore

- [ ] إنشاء `_ReorderableWorkspacesSection` كـ `StatefulWidget` يدير:
  - `_isReordering: bool` عبر `onReorderStart`/`onReorderEnd`.
  - `effectiveExpansion = _isReordering ? {} : widget.expansion` (map فارغ →
    الكل مطوي أثناء السحب).
  - `onReorder` يحسب الترتيب الجديد ويطلق `widget.onReorder(oldIndex, newIndex)`.
- [ ] استخدام `SliverReorderableList` داخل الـ `CustomScrollView` الحالي في
  `device_workspace_sidebar.dart` بدل الـ `SliverToBoxAdapter` الذي يلفّ
  `SidebarWorkspacesSection` الحالي.
- [ ] الـ "Workspaces" heading يبقى `SliverToBoxAdapter` منفصل قبل الـ reorderable sliver.
- [ ] كل `SidebarWorkspaceGroupTile` يأخذ `isExpanded` من `effectiveExpansion` لا من
  `widget.expansion` المباشر، حتى ينطوي أثناء السحب ويعود بعده.
- [ ] `proxyDecorator` للـ drag preview يضمن أن الـ tile المرفوعة مطوية أيضًا.
- [ ] الاختبارات: `tester.startGesture` + `moveBy` لمحاكاة السحب؛ التأكد من طي الكل
  عند dragStart واسترجاع الحالة عند dragEnd؛ `onReorder` يطلق الترتيب الصحيح.

#### معايير قبول Gate R4

- [ ] الضغط المطول على workspace tile يبدأ السحب ويطوي جميع الـ workspaces.
- [ ] المستخدم يستطيع سحب tile وإفلاتها في موقع جديد.
- [ ] عند الإفلات: الـ workspaces تعود لحالات expansion الأصلية (مفتوح→مفتوح،
  مقفول→مقفول).
- [ ] `onReorder` يطلق ترتيب IDs صحيح (مع التعديل القياسي لـ newIndex في Flutter).
- [ ] الـ drag preview لا يحتوي على محادثات بداخلها (collapsed).
- [ ] التحليل واختبارات widget المركزة ناجحة.

### Gate R5 — Integration, Persistence, and Regression

- [ ] ربط `onReorder` من الـ widget بـ `sidebarCubit.reorderWorkspaces` مع احتساب
  الترتيب الجديد من `snapshot.workspaces` الحالي + oldIndex/newIndex.
- [ ] اختبار تكاملي: إعادة ترتيب → تبديل device → العودة → الترتيب محفوظ.
- [ ] اختبار: إعادة تشغيل (إعادة بناء الـ store من codec) → الترتيب محفوظ.
- [ ] اختبار: refresh workspaces من الـ daemon → الـ workspaces الجديدة تُلحق،
  ترتيب المستخدام لا يضيع.
- [ ] اختبار: workspace محذوف من الـ daemon → يُحذف من الترتيب، الباقي يبقى بترتيبه.
- [ ] اختبار: إنشاء workspace جديد → يظهر في نهاية الترتيب.
- [ ] تحديث QA matrix وproduct spec وclient feature contract.
- [ ] `fvm flutter analyze` نظيف + السويت السريعة الكاملة ناجحة.

#### معايير قبول Gate R5

- [ ] الترتيب يُحفظ عبر device switch وإعادة تشغيل التطبيق.
- [ ] refresh من الـ daemon لا يمسح ترتيب المستخدم.
- [ ] الـ workspaces الجديدة/المحذوفة تُعالج دون كسر الترتيب.
- [ ] الاختبارات المتكاملة ناجحة والتحليل نظيف.

## 4. الملفات المتوقعة

- `sanad-agent/client/lib/features/conversations/domain/models/device_conversation_context.dart`
- `sanad-agent/client/lib/features/conversations/domain/models/device_sidebar_snapshot.dart`
- `sanad-agent/client/lib/features/conversations/data/persistence/conversation_cache_codec.dart`
- `sanad-agent/client/lib/features/conversations/domain/stores/conversation_cache_store.dart`
- `sanad-agent/client/lib/features/conversations/data/repositories/conversation_cache_repository.dart`
- `sanad-agent/client/lib/features/conversations/presentation/bloc/session_sidebar_cubit.dart`
- `sanad-agent/client/lib/features/conversations/presentation/widgets/sidebar/device_workspace_sidebar.dart`
- `sanad-agent/client/lib/features/conversations/presentation/widgets/sidebar/sidebar_sections.dart`
- `sanad-agent/client/lib/features/conversations/presentation/widgets/sidebar/sidebar_workspace_group_tile.dart`
- اختبارات unit/widget المقابلة في `sanad-agent/client/test/`.

## 5. خارج النطاق

- حفظ الترتيب على جانب الـ daemon أو إضافة socket command له. الترتيب client-only.
- مزامنة الترتيب بين أجهزة متعددة (multi-device sync). الـ expansion state الحالي
  يعمل بنفس الطريقة (client-only) وهذا مقبول.
- إعادة ترتيب الـ Conversations داخل workspace أو إعادة ترتيب الـ unscoped section.
  هذه الميزة تقتصر على ترتيب الـ Workspaces أنفسها.
- تغيير `schemaVersion` أو migration للـ codec. الحقل الجديد اختياري ومتوافق عكسيًا.
- دعم keyboard reordering أو accessibility drag alternatives في هذه المهمة.
- إعادة ترتيب عبر drag-and-drop بين sidebar وFileChooser أو مصادر خارجية.

## 6. ملاحظات التنفيذ

- نمط `workspaceExpansion` هو المرجع الأنسب للتقليد: نفس الـ layering (context →
  store → codec → snapshot → cubit → widget) ونفس آلية الحفاظ عبر refresh.
- `SliverReorderableList` يعمل داخل `CustomScrollView` الموجود؛ لا حاجة لتحويل الـ
  sidebar كله لمحتوى non-sliver.
- `Future.delayed(Duration.zero)` يعلق داخل `testWidgets` — استخدم `tester.pump()`
  لمحاكاة مرور الوقت في اختبارات السحب.
- الـ keys للـ tiles يجب أن تكون فريدة ومستقرة: `ValueKey(ws.id)` بدون prefix لتفادي
  تضارب مع الـ drag preview.
- `onReorder` في Flutter يعدّل `newIndex` بطرح 1 إذا كان `newIndex > oldIndex`؛
  احتسب ذلك عند بناء الترتيب الجديد.
- الـ worktree الحالي `32c-device-workspace` لا يزال في gate C3_start؛ هذه المهمة
  يجب أن تُبنى فوق عمل C2 المنجز (pagination + ordering projection + expansion).
