---
title: "Task 32e: Conversation Navigation History and Deletion Safety"
parent_plan: "docs/plans/32-device-workspace-conversation-ux-redesign.md"
status: "complete"
current_gate: "Closed"
---

# Task 32e: Conversation Navigation History and Deletion Safety

## الحالة والاعتماديات

- الحالة: `complete` — اكتملت مراجعة E0-E4 واعتمدت للإغلاق وفتح PR.
- يمكن تنفيذها بالتوازي مع `32c` و`32d` بعد اعتماد navigation/store interfaces.
- ملكية الوكيل: core navigation، conversation selection coordinator، وحالات الحذف؛ لا يعيد تصميم sidebar أو composer.

## قاعدة التنفيذ والتحديث

- [x] لا يبدأ E0 قبل تثبيت store APIs ونموذج الوجهة المشترك.
- [x] يحدث الوكيل status/current gate ولوحة الخطة في كل انتقال.
- [x] لا يغير sidebar/chat styling خارج intents المطلوبة للتكامل.
- [x] لا تصبح المهمة `complete` قبل E4 review.

## بوابات التنفيذ

### Gate E0: Route and Destination Contract

- [x] تدقيق GoRouter وbrowser behavior وكل session selection paths.
- [x] تعريف typed destination وroute identity وNew Conversation marker.
- [x] تعريف قواعد URL/deep-link/device reconciliation.
- [x] تعريف pruning/fallback عند حذف أو فقد وجهة.

#### Gate E0 Exit

- [x] مراجعة contract مع 32c و32d قبل تعديل history behavior.

### Gate E1: Navigation History and Browser Synchronization

- [x] تنفيذ back/current/forward semantics ومنع duplicates.
- [x] مزامنة browser pop وUI intents دون loops.
- [x] دعم الانتقال بين أجهزة واستعادة last session.
- [x] اختبارات router/history الأساسية ناجحة.

#### Gate E1 Exit

- [x] مراجعة web/deep-link behavior قبل transitions المرئية.

### Gate E2: Atomic Session Presentation

- [x] فصل requested عن presented destination.
- [x] تنفيذ request generations ورفض stale/superseded responses.
- [x] إبقاء المحتوى السابق مع delayed loading ثم atomic swap.
- [x] failure يبقي presented session ويعرض retry.

#### Gate E2 Exit

- [x] مراجعة عدم وجود New Conversation/blank flash أو title mismatch.

### Gate E3: Deletion Safety and History Pruning

- [x] تنفيذ current/non-current/external deletion paths.
- [x] تنظيف cache/drafts/history وإبطال الطلبات بعد تأكيد الحذف.
- [x] تنفيذ same-device previous fallback ثم New Conversation.
- [x] route replacement يمنع العودة إلى deleted URL.
- [x] اختبارات late response والفشل والتزامن ناجحة.

#### Gate E3 Exit

- [x] مراجعة deletion invariants قبل الاستعادة والإغلاق.

### Gate E4: Restore, Verification, Documentation, and Handoff

- [x] إثبات restart/deep link/missing last session recovery.
- [x] إغلاق جميع حالات الاختبار في المهمة.
- [x] تحديث core/features contracts وproduct/QA docs.
- [x] تسجيل نتائج التحقق والملفات المعدلة وتحديث لوحة الخطة.

#### Gate E4 Exit

- [x] status تصبح `in_review` ثم `complete` بعد المراجعة.

## الهدف

توحيد التنقل بين الأجهزة والجلسات وNew Conversation، إضافة Back/Forward متزامنة مع الويب، ومنع بقاء رسائل جلسة محذوفة أو عودتها باستجابة متأخرة.

## نموذج الوجهة

تعرف وجهة typed تحتوي دلاليًا على:

- device id.
- session id أو New Conversation marker.
- workspace preselection للمحادثة الجديدة عند الحاجة.
- route identity مستقرة للمقارنة ومنع التكرار.

يحتفظ history controller بـback stack وcurrent وforward stack، ويزامن GoRouter URL دون إنشاء حلقة بين route parsing وstate emission.

## Back/Forward

- فتح وجهة جديدة يدفع current إلى back ويمسح forward.
- Back ينقل current إلى forward ويفتح آخر وجهة صالحة.
- Forward يعكس ذلك.
- تكرار اختيار current لا يضيف entry.
- التاريخ يعبر الأجهزة؛ فتح وجهة يبدل active device أولًا ثم يستعيد بياناتها.
- browser back/forward على web يطبق state نفسها.
- deep link يبني الوجهة الصحيحة ويستعيد device/session.
- الوجهات المحذوفة أو غير المتاحة يتم تجاوزها وإزالتها.

## انتقال session بلا وميض

- فصل `requestedDestination` عن `presentedDestination`.
- إبقاء presented conversation حتى history الجديدة جاهزة.
- delayed loading indicator بعد عتبة قصيرة بدل blank أو New Chat flash.
- تبديل App Bar والرسائل وcomposer binding ذريًا.
- generation/token لكل request؛ response أقدم أو superseded تُرفض.
- failure يبقي الوجهة القديمة مع retry غير هدّام.

## حذف session

### جلسة غير مفتوحة

- بعد تأكيد daemon تزال من cache/history/drafts.
- لا يتغير presented conversation.

### الجلسة المفتوحة

- لا تظل رسائلها معروضة بعد نجاح الحذف.
- تزال من back/current/forward ومن cache والمسودات.
- تلغى أو تبطل كل history requests الخاصة بها.
- تفتح آخر وجهة صالحة للجهاز نفسه إن وجدت، وإلا New Conversation.
- تستخدم route replacement حتى لا يعود Back إلى deleted URL.
- delete event خارجي يطبق القواعد نفسها.
- فشل delete يبقي session الحالية ولا ينفذ removal متفائلًا نهائيًا.

## الاستعادة

- آخر selected session لكل جهاز تستعاد بعد restart إذا ما زالت موجودة.
- active device وroute العميقة يتصالحان دون فتح session من جهاز مختلف مؤقتًا.
- إذا كانت last session محذوفة أثناء غياب العميل، تزال ويظهر fallback صالح.

## حالات الاختبار

- Back/Forward داخل جهاز وبين جهازين.
- browser navigation وUI buttons ينتجان الوجهة نفسها.
- فتح وجهة بعد Back يمسح forward.
- deleted entries لا تعود عبر Back أو deep cached state.
- حذف current يفتح previous valid same-device destination أو New Conversation.
- حذف non-current لا يغير العرض.
- late history response بعد delete لا يعيد الرسائل.
- تبديل سريع A -> B -> C يعرض C فقط.
- fetch سريع لا يظهر loading؛ fetch بطيء يظهر delayed overlay.
- fetch failure يبقي previous conversation.

## الملفات المتوقعة

- `sanad-agent/client/lib/core/navigation/app_routes.dart`
- `sanad-agent/client/lib/core/navigation/app_router.dart`
- navigation history/controller جديد في owner مناسب.
- `sanad-agent/client/lib/features/conversations/presentation/bloc/session_cubit.dart`
- `sanad-agent/client/lib/features/conversations/presentation/bloc/session_messages_cubit.dart`
- repository/store hooks الخاصة بالحذف والطلب الجاري.

## تحديثات التوثيق المطلوبة عند التنفيذ

- `sanad-agent/client/lib/core/AGENTS.md`
- `sanad-agent/client/lib/features/AGENTS.md`
- product UX spec للتنقل والحذف.
- QA recovery matrix لحالات late response/deletion/history.

## Definition of Done

- [x] UI والbrowser navigation متزامنان.
- [x] لا تعرض الواجهة رسائل session محذوفة.
- [x] لا يسبب فتح session وميض New Conversation.
- [x] fallback بعد الحذف deterministic ومغطى بالاختبارات.
- [x] آخر session لكل جهاز تستعاد بأمان.

## سجل التقدم

### Gate E0 — 2026-07-13

**الحالة**: مكتملة — العقد معرفة ومراجعة.

**الملفات المنشأة**:
- `client/lib/core/navigation/conversation_destination.dart` — نموذج الوجهة المكتوب مع route identity و New Conversation marker.
- `client/lib/core/navigation/navigation_history_controller.dart` — واجهة history controller مع back/current/forward stacks.
- `docs/product/conversation_navigation_ux_spec.md` — مواصفات تجربة المستخدم للتنقل والحذف.
- `docs/qa_maintenance/conversation_navigation_recovery_matrix.md` — مصفوفة اختبارات الاسترداد QA.

**الملفات المحدثة**:
- `client/lib/core/navigation/app_routes.dart` — إضافة `newConversation` route و `newConversationLocation()`.
- `client/lib/core/navigation/app_router.dart` — إضافة مسار New Conversation، تحليل `ConversationDestination` من المعاملات.
- `client/lib/core/AGENTS.md` — إضافة عقد التنقل والحذف (Plan 32e).
- `client/lib/features/AGENTS.md` — إضافة قواعد ملكية الحذف والتنقل.
- `client/lib/features/home/presentation/screens/home_screen.dart` — تحديث لاستقبال `ConversationDestination` بدلاً من المعاملات النصية.
- `docs/plans/tasks/32e-conversation-navigation-history-and-deletion.md` — تحديث الحالة.

**التحقق**:
- ✅ 13 اختبار `app_router` ناجحة.
- ✅ `flutter analyze` لـ `lib/core/navigation/` = No issues found.
- ✅ `flutter analyze` لـ `lib/features/home/` = No issues found.

**الملاحظات**:
- New Conversation له مسار مستقل `/conversations/:deviceId/new` وليس مجرد sessionId فارغ.
- `ConversationDestination` يوفر `fromRouteParams()` لتحليل معاملات GoRouter.
- العقود متوافقة مع Plan 32c (sidebar) و Plan 32d (chat UI) — لا تعيد تصميم sidebar أو composer.
- التنفيذ الكامل للـ NavigationHistoryController في Gate E1.

### Gate E1 — 2026-07-13

**الحالة**: مكتملة — history controller منفذ بالكامل مع مزامنة GoRouter.

**الملفات المنشأة**:
- `client/lib/core/navigation/navigation_history_controller.dart` — تحويل الواجهة إلى تطبيق كامل `ConversationHistoryController` مع back/current/forward stacks، منع التكرار، و `GoRouterHistorySync` لمزامنة الاتجاهين.
- `client/test/unit/core/navigation/navigation_history_controller_test.dart` — 26 اختبار وحدة لتغطية كل وظائف history controller.

**الملفات المحدثة**:
- `client/lib/core/navigation/app_router.dart` — إضافة `AppRouterSetup` (يحمل `GoRouter` و `GoRouterHistorySync`); قبول `ConversationHistoryController` اختياري.
- `client/lib/core/presentation/app/app_shell.dart` — استخدام `AppRouterSetup` بدلاً من `GoRouter` المباشر.
- `client/lib/features/home/presentation/screens/home_screen.dart` — مزامنة `ConversationDestination` المستقبل مع `ConversationHistoryController`.
- `client/lib/core/di/injection.dart` — تسجيل `ConversationHistoryController` كـ lazy singleton في `getIt`.
- `client/test/unit/core/navigation/app_router_test.dart` — تحديث لاستخدام `AppRouterSetup.router`.

**التحقق**:
- ✅ 39 اختبارات ناجحة (26 history controller + 13 app router).
- ✅ `flutter analyze` لجميع الملفات المعدلة = No issues found.

**الملاحظات**:
- `GoRouterHistorySync` يتجنب التكرارات عبر مقارنة الوجهة مع الـ back/forward stacks بدلاً من flags.
- `reconcileFromRoute()` يسمح لـ `HomeScreen` بمزامنة التغييرات الخارجية (browser pop، deep link) مع الـ controller.
- الاتجاه UI → GoRouter يستخدم `navigateTo()` الذي يحدث الـ controller ثم `router.go()`.
- جاهز لتكامل E3 (Deletion Safety).

### Gate E2 — 2026-07-13

**الحالة**: مكتملة — atomic session presentation مع request generations و delayed loading indicator.

**الملفات المحدثة**:
- `client/lib/features/conversations/presentation/bloc/session_messages_state.dart` — إضافة `requestedSessionId`, `isHistoryLoading`, `historyLoadError`, `showDelayedLoading`.
- `client/lib/features/conversations/presentation/bloc/session_messages_cubit.dart` — إضافة `_requestGeneration`, `_delayedLoadingTimer`, `_loadHistoryForAtomicSwap()`; فصل requested عن presented في `_handleSessionStateChange`; تفعيل الـ gate لجميع stream handlers أثناء التحميل; تكييف `_subscribeToAgent` للتحميل الذري.
- `client/test/unit/bloc/session_cubit_test.dart` — إضافة 5 اختبارات E2 (atomic swap, failure handling, rapid switching, generation token rejection, delayed loading indicator) وثلاثة fake clients مساعدة (`_FakeFailingClient`, `_FakeDelayedClient`, `_FakeControlledClient`).

**التحقق**:
- ✅ 66 اختبارات (27 session + 39 navigation) ناجحة.
- ✅ `flutter analyze` = No issues found.

**الملاحظات**:
- `_loadHistoryForAtomicSwap()` تستخدم `loadSessionHistory` لل transport مباشرة (تستدعي activateSession داخلياً) بدلاً من استدعاء `activateSession` من الـ cubit.
- جميع stream handlers (`watchMessages`, `watchQueuedMessages`, `watchPendingSuspension`, `watchRuntimeNotice`, `watchProcessing`) و `_emitCurrentState()` ممنوعة أثناء `requestedSessionId != null` لمنع الكتابة فوق content المعروض.
- `_FakeDelayedClient` يستخدم `Completer<void>` وحيد لحظر `loadSessionHistory` حتى تستدعي `completeHistory()`.
- `_FakeControlledClient` يُستخدم لاختبار رفض الاستجابات القديمة (generation mismatch).

### Gate E3 — 2026-07-13

**الحالة**: مكتملة — deletion safety مع fallback و history pruning.

**الملفات المحدثة**:
- `client/lib/features/conversations/presentation/bloc/session_cubit.dart` — إضافة `historyController` (حقن اختياري); إضافة `_handleDeletionFallback()` و `_selectFallbackSession()`; تعديل `deleteSession()` لاستخدام fallback بعد تأكيد daemon بدلاً من المسح المتفائل; تعديل `_onSessionDeleted()` لاستخدام منطق fallback نفسه للمسارين (cache/non-cache).
- `client/lib/features/home/presentation/screens/home_screen.dart` — حقن `ConversationHistoryController` في `SessionCubit`; إضافة `BlocListener<SessionCubit, SessionState>` لـ New Conversation fallback navigation.
- `client/test/unit/bloc/session_cubit_test.dart` — إضافة 3 اختبارات E3 (back stack fallback, session_deleted event → New Conversation, non-current يحافظ على selectedSession).

**التحقق**:
- ✅ 69 اختبارات (30 session + 39 navigation) ناجحة.
- ✅ 450 اختبارات كاملة ناجحة.
- ✅ `flutter analyze` = No issues found.

**الملاحظات**:
- `_handleDeletionFallback()` تشترك بين `deleteSession()` (استدعاء المستخدم) و `_onSessionDeleted()` (حدث daemon) لتجنب تكرار المنطق.
- ترتيب fallback: back stack → forward stack → New Conversation.
- `deleteSession()` لا تمسح selectedSession بشكل متفائل; تنتظر تأكيد daemon عبر حدث `session_deleted` (أو تتعامل مع fallback فورًا بعد الاستجابة في `deleteSession()`).
- `BlocListener` في `HomeScreen` يلتقط حالة `selectedSession == null` ويستخدم `context.go(fallback.routePath)` للتنقل إلى New Conversation مع post-frame callback لتجنب التنقل أثناء build.

### Gate E4 — 2026-07-13

**الحالة**: مكتملة — restore/verification/handoff. Task ready for review.

**الملفات المحدثة**:
- `client/lib/features/conversations/presentation/bloc/session_cubit.dart` — إضافة `historyController.navigateTo()` في `selectSession()` و `startNewChat()` لمزامنة history controller مع جميع مسارات التنقل.
- `client/test/unit/bloc/session_cubit_test.dart` — إضافة 3 اختبارات E4 (selectSession يزامن history، startNewChat يزامن history، recovery من cache).

**التحقق**:
- ✅ 72 اختبارات (33 session + 39 navigation) ناجحة.
- ✅ 453 اختبارات كاملة ناجحة.
- ✅ `flutter analyze` = No issues found.

**الملاحظات**:
- `selectSession()` الآن يستدعي `historyController.navigateTo()` بعد emit لتحديث back/current/forward stacks.
- `startNewChat()` يستدعي `historyController.navigateTo(ConversationDestination.newConversation(...))` بعد clearSelectedSession.
- ملاحظة لاحقة: استعادة restart أصبحت تعتمد حصريًا على `ConversationCacheStore.recordLastDestination(ConversationDestination)`؛ يبقى `lastSelectedSessionId` مرجعًا لوراثة سياق الجلسة فقط ولا يحدد route الاستعادة.
- جميع بوابات E0-E4 مكتملة. المهمة جاهزة للمراجعة.
- E4 review: تمت مراجعة الكود — `selectSession()` و `startNewChat()` يزامنان history controller بشكل صحيح، استعادة restart تعمل عبر cache + `_onCacheSnapshot` + `HomeScreen._applyInitialDestination()`، جميع الاختبارات (72 session+navigation, 453 total) ناجحة، `flutter analyze` نظيف.

### مراجعة Sanad — 2026-07-14

**الحالة**: تمت مراجعة التنفيذ وإصلاح ملاحظات قبل PR، ولا تزال المهمة `in_review` بانتظار موافقة بشرية للإغلاق.

**الأخطاء التي تم إصلاحها**:
- منع `HomeScreen` من قراءة `SessionCubit` من سياق أعلى من `MultiBlocProvider`; أصبحت session/New Conversation selection داخل `_HomeScreenContent` فقط لأن سياقها تحت providers.
- توحيد `ConversationHistoryController` المستخدم في `AppShell` مع singleton المسجل في `getIt` بدل إنشاء controller منفصل غير مستخدم.
- جعل route sync بعد fallback يستجيب لتغير هوية `selectedSession` وليس فقط `selectedSession == null`، حتى يتم استبدال URL المحذوف عند fallback إلى session أخرى.
- وضع route `/conversations/:deviceId/new` قبل route الديناميكي `/conversations/:deviceId/:sessionId` لتجنب التقاطه كـ session عامة.
- إزالة trailing whitespace في `client/lib/features/AGENTS.md` وتحديث التوثيق/لوحة الخطة.

**التحقق بعد الإصلاح**:
- ✅ `git diff --check` بدون مشاكل.
- ✅ `fvm flutter analyze` = No issues found.
- ✅ Focused tests: `fvm flutter test test/unit/core/navigation/navigation_history_controller_test.dart test/unit/core/navigation/app_router_test.dart test/unit/bloc/session_cubit_test.dart` = 72/72 ناجحة.
- ✅ Full fast suite: `fvm flutter test` = 453/453 ناجحة.

- الحالة: `in_review` — تنتظر المراجعة البشرية قبل الإغلاق.

### مراجعة التكامل النهائية — 2026-07-14

**الحالة**: اكتملت مراجعة 32e فوق أحدث `main` بعد دمج 32c و32d، وأصلحت ملاحظات المراجعة، ثم اعتمدت المهمة للإغلاق وفتح PR والدمج.

**الإصلاحات الجوهرية**:
- أصبح حذف الجلسة يتطلب تأكيد daemon صريحًا؛ الفشل يحافظ على الجلسة والـURL بدل تنفيذ fallback كاذب.
- أصبحت cache والمسودة تنظفان فور نجاح الحذف المحلي، مع إشارة موحدة تبطل الجلسة المحذوفة حتى لو كانت هي المحتوى المعروض تحت وجهة أحدث مطلوبة.
- أصبح كل انتقال إلى New Conversation أو جهاز آخر يبطل generation السابقة، ولا تستطيع history response متأخرة إعادة جلسة محذوفة أو superseded.
- أزيل التفعيل المبكر من `SessionCubit`; يركب requested/presented gate قبل أن يفعّل تحميل history الجلسة المستهدفة.
- يحافظ الانتقال بين الأجهزة على المحتوى السابق حتى اكتمال atomic swap، ويعرض delayed loading وfailure banner مع Retry حقيقي.
- أصبح fallback يستهلك أول وجهة صالحة من back/forward ويزيل الوجهات غير الصالحة، لذلك لا يتكرر current عند أول Back بعد الحذف.
- أضيفت Back/Forward controls لسطح desktop/tablet، وربطت مباشرة بالـtyped history والـURL.
- أصلح مسار زر workspace `+` إلى New Conversation canonical route، مع حفظ workspace preselection واستعادتها من deep link.
- أضيف canonical restore من `/home`، fallback للأجهزة والجلسات المعروفة المفقودة، وترميز آمن لكل أجزاء المسار/query.
- حدثت عقود core/features وفهارس product/QA ووثائق المهمة بعد المراجعة.

**التحقق النهائي**:
- ✅ static analysis: بلا ملاحظات.
- ✅ اختبارات navigation/session المركزة واختبارات أوامر الحذف وتكامل sidebar/32c وcomposer/App Bar/32d ناجحة.
- ✅ full client fast suite: **508/508** ناجحة.
- ✅ `git diff --check`: بلا مشاكل.

- الحالة: `complete` — اعتمدت للإغلاق وفتح PR والدمج.
