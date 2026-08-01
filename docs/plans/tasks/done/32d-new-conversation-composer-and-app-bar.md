---
title: "Task 32d: New Conversation, Composer, and App Bar"
parent_plan: "docs/plans/32-device-workspace-conversation-ux-redesign.md"
status: "complete"
current_gate: "Closed"
---

# Task 32d: New Conversation, Composer, and App Bar

## الحالة والاعتماديات

- الحالة: `complete` — اجتازت مراجعة D4 وأصبحت جاهزة للدمج.
- يمكن تنفيذها بالتوازي مع `32c` و`32e`.
- ملكية الوكيل: Home/chat presentation وdraft binding؛ لا يغير navigation history أو sidebar internals.

## قاعدة التنفيذ والتحديث

- [x] لا يبدأ D0 قبل تثبيت draft/store APIs من 32b.
- [x] يحدث الوكيل status/current gate ولوحة الخطة عند الانتقال.
- [x] لا يضيف widget state دائمًا بديلًا عن cache/draft owner. (قاعدة توجيهية)
- [x] لا تصبح المهمة `complete` قبل D4 review.

## بوابات التنفيذ

### Gate D0: UX State and Responsive Composition

- [x] تعريف الحالات المرئية: New Conversation، loading transition، وactive session.
- [x] تثبيت boundaries بين Home وBrainActivityView وcomposer وApp Bar.
- [x] تثبيت responsive behavior قبل styling النهائي.

#### Gate D0 Exit

- [x] مراجعة composition وعدم ظهور App Bar في New Conversation.

### Gate D1: New Conversation Flow

- [x] تنفيذ Sanad Agent title ورسالة المساعدة وcentered composer.
- [x] تنفيذ device/workspace selectors pre-session فقط.
- [x] تنفيذ optional clear/required validation وWorkspace preselection.
- [x] إثبات عدم إنشاء session قبل أول إرسال.

#### Gate D1 Exit

- [x] مراجعة كل capability branches قبل active-session UI.

### Gate D2: Conversation App Bar

- [x] تنفيذ desktop/tablet title hierarchy.
- [x] تنفيذ mobile menu/title/subtitle layout.
- [x] إخفاء subtitle للجلسات بلا Workspace.
- [x] ربط presented destination الذرية من 32e دون title/content mismatch.

#### Gate D2 Exit

- [x] مراجعة App Bar على المقاسات والحالات قبل composer cutover.

### Gate D3: Composer and Draft Binding

- [x] تنفيذ editor المتوسع والصف السفلي الموحد.
- [x] الحفاظ على permissions/provider/model/thinking/send/stop behavior.
- [x] ربط drafts والاستعادة وفشل/تأكيد الإرسال.
- [x] إثبات keyboard/accessibility وعدم overflow.

#### Gate D3 Exit

- [x] مراجعة الوظائف الحالية وعدم فقد capability قبل التكامل النهائي.

### Gate D4: Verification, Documentation, and Handoff

- [x] إغلاق حالات الاختبار لكل منصة وحالة session.
- [x] تحديث product spec وcontracts وQA.
- [x] تسجيل نتائج التحليل والاختبارات والملفات المعدلة.
- [x] تحديث لوحة الخطة الرئيسية.

#### Gate D4 Exit

- [x] status تصبح `in_review` ثم `complete` بعد المراجعة.

## الهدف

إعادة تصميم New Conversation وcomposer وconversation App Bar بتجربة متجاوبة، مع فصل واضح بين إعداد المحادثة قبل أول رسالة وسياق session الثابت بعدها.

## New Conversation

- لا App Bar.
- عنوان `Sanad Agent` ورسالة مساعدة مختارة عند فتح view.
- composer في منتصف المساحة بصريًا.
- device selector وWorkspace selector يظهران فوق composer.
- device selector يبدل draft context والجهاز النشط ولا ينشئ session.
- Workspace selector يعرض Workspaces الجهاز فقط.
- `No workspace` متاح عندما `workspaceRequired == false`.
- منع الإرسال برسالة واضحة فقط عندما capability تتطلب Workspace ولا يوجد اختيار.
- preselection القادمة من plus Workspace تظهر فورًا.

## Conversation App Bar

- يظهر فقط عندما توجد session قائمة أو history جاهزة للعرض.
- Desktop/tablet: يعرض Workspace name وsession name بهرمية واضحة.
- Mobile: زر drawer ثم session title كسطر رئيسي، وتحته Workspace subtitle بخط أصغر ولون أغمق قليلًا.
- session بلا Workspace لا تعرض subtitle فارغًا.
- App Bar والمحتوى ينتقلان ذريًا عند فتح session أخرى.

## Composer

- container موحد يضم text editor والصف السفلي.
- text editor كامل العرض، يتمدد حتى حد يقارب ثمانية أسطر ثم يمرر.
- الصف السفلي: permission mode، provider/model، thinking mode، send/stop.
- الإجراءات تظل قابلة للاستخدام عبر keyboard وscreen readers.
- mobile يجمع أو يلف الخيارات الثانوية دون overflow.
- device/workspace selectors تختفي بعد بدء session؛ المنتقي الدائم في sidebar لا يتأثر.
- Workspace session الحالية غير قابلة للتغيير.

## ربط المسودات

- كل composer يقرأ ويكتب draft عبر store من `32b`.
- الانتقال بين sessions/devices يستبدل controller text بالمسودة الصحيحة دون feedback save loop.
- الإرسال الفاشل لا يمسح النص.
- canonical acceptance تمسح draft المطابقة فقط.
- provider/model/thinking/permission pre-send state تستعاد مع New Conversation draft.

## حالات الاختبار

- New Conversation بلا App Bar.
- session قائمة تعرض العنوان الصحيح مع/بلا Workspace.
- mobile layout سطران دون overflow.
- selectors تظهر قبل أول رسالة وتختفي بعدها.
- optional Workspace يمكن اختيارها ومسحها.
- required Workspace تمنع الإرسال فقط عند غيابها.
- تغيير الجهاز يغير Workspaces والمسودة ولا ينشئ session.
- plus Workspace يفتح view بالقيم الصحيحة بلا create call.
- editor يتمدد حتى الحد ثم يمرر.
- فشل الإرسال يبقي المسودة؛ التأكيد يمسحها.

## الملفات المتوقعة

- `sanad-agent/client/lib/features/home/presentation/screens/home_screen.dart`
- `sanad-agent/client/lib/features/home/presentation/widgets/mobile_app_bar.dart`
- `sanad-agent/client/lib/features/conversations/presentation/screens/brain_activity_view.dart`
- `sanad-agent/client/lib/features/home/presentation/widgets/new_chat_view.dart`
- `sanad-agent/client/lib/features/conversations/presentation/widgets/conversation_input_panel.dart`
- `sanad-agent/client/lib/features/conversations/presentation/widgets/conversation_input/`

## تحديثات التوثيق المطلوبة عند التنفيذ

- `sanad-agent/docs/product/client_interface.md`
- client feature contract إذا تغيرت composition boundaries.
- widget QA coverage documentation.

## Definition of Done

- [x] New Conversation نظيفة ولا تنشئ session قبل الإرسال.
- [x] App Bar صحيحة ومتجاوبة ولا تظهر فارغة.
- [x] composer موحدة وقابلة للتوسع وتدعم كل الإجراءات الحالية.
- [x] drafts تستعاد وتمسح وفق تأكيد daemon.
- [x] لا تفقد أي capability موجودة بسبب إعادة التصميم.

## سجل التقدم

```text
Date: 2026-07-13
Task/Gate: 32d / D0
Status transition: pending → in_progress
Owner/worktree: 32d-new-conversation
Completed:
  - إنشاء ConversationVisualState enum (newConversation, loadingTransition, activeSession)
  - إضافة getter visualState إلى SessionMessagesState
  - إضافة خاصية visualState إلى BrainActivityView
  - إنشاء ConversationAppBar widget (desktop/tablet title hierarchy + mobile menu/title/subtitle layout)
  - تحديث HomeScreen لإخفاء App Bar في حالة newConversation وإظهاره فقط في activeSession
  - responsive composition بين Home وApp Bar وBrainActivityView عبر isMobile/isDesktop
Verification evidence:
  - fvm flutter analyze: No issues found
  - brain_activity_view_scroll_test: 2/2 passed
Documentation updated:
  - docs/plans/tasks/32d-new-conversation-composer-and-app-bar.md (status→in_progress, Gate D0 checks)
  - docs/plans/32-device-workspace-conversation-ux-redesign.md (لوحة التقدم)
Open findings/blockers: None
Next gate/owner: D1 — New Conversation Flow (يمكن البدء)

Date: 2026-07-13
Task/Gate: 32d / D1
Status transition: D0 → D1
Owner/worktree: 32d-new-conversation
Completed:
  - إعادة كتابة NewChatView: عنوان "Sanad Agent" + رسالة مساعدة متغيرة + centered composer
  - دمج ConversationContextChips (selectors) داخل NewChatView
  - إخفاء ConversationContextChips في ConversationInputPanel أثناء active session (sessionId != null)
  - فصل BrainActivityView: NewChatView مع composer مدمج للحالة الجديدة، Column مع messages+input للحالة النشطة
  - إضافة التحقق من صحة الإرسال (workspaceRequired) مع error SnackBar
  - إضافة خيار "No workspace" في منتقي الـ Workspace (عندما workspaceRequired == false)
  - إضافة clearWorkspace إلى ConversationInputCubit و SessionMessagesCubit
  - إثبات أن beginNewSession يمسح الحالة فقط ولا ينشئ session (موجود مسبقاً)
Verification evidence:
  - fvm flutter analyze: No issues found
  - brain_activity_view_scroll_test: 2/2 passed
Documentation updated:
  - docs/plans/tasks/32d-new-conversation-composer-and-app-bar.md (current_gate→D1, Gate D1 checks)
Open findings/blockers: None
Next gate/owner: D2 — Conversation App Bar

Date: 2026-07-13
Task/Gate: 32d / D2
Status transition: D1 → D2
Owner/worktree: 32d-new-conversation
Completed:
  - تعزيز desktop/tablet title hierarchy: إضافة chip لاسم Workspace بلون primaryContainer مع ظل خفيف ورمز chevron_right، واسم الجلسة بحجم titleSmall ووزن w600 ولون onSurface
  - تحسين mobile menu/title/subtitle layout: إضافة tooltip للزر، تحسين padding، تحديد maxLines: 1 مع ellipsis، جعل subtitle بخط bodySmall مع لون أغمق قليلاً (onSurfaceVariant alpha 0.8)
  - إخفاء subtitle للجلسات بلا Workspace عبر الشرط `if (workspace != null)` (موجود مسبقاً وتم تحسينه)
  - ربط presented destination ذرياً: إضافة `_resolvePresentedSession` الذي يبحث عن session عبر `activeSessionId` من SessionMessagesState بدلاً من الاعتماد فقط على `selectedSession` من SessionCubit، وإضافة `ValueKey` متطابق مع sessionId لضمان الانتقال الذري
Verification evidence:
  - fvm flutter analyze: No issues found
  - brain_activity_view_scroll_test: 2/2 passed
Documentation updated:
  - docs/plans/tasks/32d-new-conversation-composer-and-app-bar.md (current_gate→D2, Gate D2 checks, progress log)
  - docs/plans/32-device-workspace-conversation-ux-redesign.md (لوحة التقدم)
Open findings/blockers: None
Next gate/owner: D3 — Composer and Draft Binding (يمكن البدء)

Date: 2026-07-13
Task/Gate: 32d / D3
Status transition: D2 → D3 → D4
Owner/worktree: 32d-new-conversation
Completed:
  - Unified composer container: expandable editor (maxLines:8) + bottom row with chips (permission/model/thinking) and send/stop/voice buttons
  - Permissions/provider/model/thinking behavior preserved via _PermissionModeChip, _ModelChip, _ThinkingModeChip, _SendStopButton
  - Draft binding: autosave debounced 500ms, load on init/didUpdateWidget, preserve text on send, mark pending, cleanup subscription on snapshot
  - `_chatController.clear()` removed from send handler (text survives until canonical acceptance)
  - Keyboard/accessibility: CallbackShortcuts (enter, shift+enter, meta+enter, ctrl+enter), slash suggestion keyboard nav, proper focus management
  - Size constraints: voice/send/stop buttons fixed at 32x32
  - Fixed: _SendStopButton not reactive to text changes (wrapped in ValueListenableBuilder), send_message_btn key always set, Stop text deduplication with RuntimeNoticeCard, draft binding resilience with try-catch
Verification evidence:
  - fvm flutter analyze: No issues found
  - brain_activity_view_scroll_test: 2/2 passed
  - conversation_input_composer_toggle_test: 10/10 passed
Documentation updated:
  - docs/plans/tasks/32d-new-conversation-composer-and-app-bar.md (current_gate→D4, D3 checks, progress log)
Open findings/blockers: None
Next gate/owner: D4 — Verification, Documentation, and Handoff

Date: 2026-07-13
Task/Gate: 32d / D4
Status transition: D3 → D4 → in_review
Owner/worktree: 32d-new-conversation
Completed:
  - All D2 checkboxes verified: desktop/tablet hierarchy, mobile layout, workspace subtitle hiding, atomic binding
  - All D3 checkboxes verified: unified container, bottom row chips, draft binding, keyboard/accessibility
  - fvm flutter analyze: No issues found
  - Tests: brain_activity_view_scroll_test 2/2, conversation_input_composer_toggle_test 10/10 — 12/12 total passed
  - Modified files recorded in the final review-remediation inventory below.
  - Task doc updated (status→in_review, current_gate→D4 Complete, all gates ticked)
  - Parent plan board updated
Verification evidence:
  - Analysis clean, 12/12 tests pass
Documentation updated:
  - docs/plans/tasks/32d-new-conversation-composer-and-app-bar.md
  - docs/plans/32-device-workspace-conversation-ux-redesign.md
Open findings/blockers: None
Next gate/owner: Closed — All gates complete, awaiting review.

Date: 2026-07-14
Task/Gate: 32d / Review Fix
Status transition: in_review → in_review
Owner/worktree: 32d-new-conversation
Completed:
  - Review finding fixed: New Conversation كان يستخدم composer منفصلًا يتجاوز unified composer/draft binding.
  - NewChatView أصبح يعرض header المركزي فقط ويستخدم ConversationInputPanel نفسه للمنتقيات والـ composer قبل إنشاء الجلسة.
  - BrainActivityView يمرر onStop إلى NewChatView حتى تبقى affordances موحدة عند الحاجة.
  - Fixed draft lifecycle edge cases: session switching saves under the old session id, loads/clears the target draft text, cancels stale cleanup subscriptions, and avoids placeholder pending request ids.
  - Product spec updated to state that New Conversation and active sessions share the unified composer and draft behavior.
Verification evidence:
  - fvm flutter analyze: No issues found
  - Tests: brain_activity_view_scroll_test + conversation_input_composer_toggle_test + conversation_input_panel_rebuild_test — 22/22 passed
Documentation updated:
  - docs/product/client_interface.md
  - docs/plans/tasks/32d-new-conversation-composer-and-app-bar.md
Open findings/blockers: None
Next gate/owner: Ready for PR after reviewer approval; no commit/push performed.
```

### D4 Review Remediation

```text
Date: 2026-07-14
Task/Gate: 32d / D4 Review
Status transition: in_review → in_review (review fixes applied)
Owner/worktree: 32d-new-conversation worktree (branch 32d-new-conversation)
Completed:
  - Merged origin/main and retained the completed 32c sidebar composition.
  - Flushed draft text before send, device/session transitions, and disposal.
  - Bound New Conversation drafts to device identity and restored text plus workspace/provider/model/thinking/permission context.
  - Prevented unrelated cache snapshots and older canonical acceptances from clearing newer editor text.
  - Made App Bar metadata atomic with activeSessionId and visible for existing empty sessions.
  - Bounded narrow composer controls, long App Bar labels, and added labeled 48x48 Material actions.
  - Restored capability gating so the voice action is hidden when the active device does not support voice calls.
  - Added focused draft/App Bar/responsive regression tests, the feature contract, cache design notes, and QA matrix.
Verification evidence:
  - fvm flutter analyze: 0 issues.
  - Focused cache/composer/App Bar/sidebar integration suite: 72/72 tests pass.
  - Full client fast suite: 462/462 tests pass.
  - git diff --check: clean.
Modified files:
  - client/lib/features/AGENTS.md
  - client/lib/features/conversations/data/repositories/conversation_cache_repository.dart
  - client/lib/features/conversations/domain/models/device_conversation_context.dart
  - client/lib/features/conversations/domain/stores/conversation_cache_store.dart
  - client/lib/features/conversations/presentation/bloc/conversation_input_cubit.dart
  - client/lib/features/conversations/presentation/bloc/conversation_visual_state.dart
  - client/lib/features/conversations/presentation/bloc/session_messages_cubit.dart
  - client/lib/features/conversations/presentation/bloc/session_messages_state.dart
  - client/lib/features/conversations/presentation/screens/brain_activity_view.dart
  - client/lib/features/conversations/presentation/widgets/conversation_app_bar.dart
  - client/lib/features/conversations/presentation/widgets/conversation_input/conversation_context_chips.dart
  - client/lib/features/conversations/presentation/widgets/conversation_input/conversation_input_composer.dart
  - client/lib/features/conversations/presentation/widgets/conversation_input_panel.dart
  - client/lib/features/home/presentation/screens/home_screen.dart
  - client/lib/features/home/presentation/widgets/new_chat_view.dart
  - client/test/unit/stores/conversation_cache_store_test.dart
  - client/test/widget/brain_activity_view_scroll_test.dart
  - client/test/widget/conversation_app_bar_test.dart
  - client/test/widget/conversation_input_composer_toggle_test.dart
  - client/test/widget/conversation_input_panel_rebuild_test.dart
  - docs/plans/32-device-workspace-conversation-ux-redesign.md
  - docs/plans/tasks/32d-new-conversation-composer-and-app-bar.md
  - docs/product/client_interface.md
  - docs/qa_maintenance/MOC.md
  - docs/qa_maintenance/new_conversation_composer_app_bar_qa.md
  - docs/technical/client_conversation_cache_schema.md
Open findings/blockers: None in the 32d implementation; waiting for reviewer approval before complete/commit/push/PR.
Next gate/owner: Reviewer approval → complete and PR handoff.
```

### D4 Exit Review

```text
Date: 2026-07-14
Task/Gate: 32d / D4 Exit
Status transition: in_review → complete
Owner/worktree: 32d-new-conversation worktree (branch 32d-new-conversation)
Completed: User approved closure after review remediation; all D4 exit conditions are satisfied.
Verification evidence: fvm flutter analyze clean; focused integration suite 72/72; full client fast suite 462/462; documentation lint and git diff --check clean.
Documentation updated: Task status/checklist and parent plan board/handoff log.
Open findings/blockers: None.
Next gate/owner: Commit, push, PR, and merge; then proceed to the next worktree review.
```
