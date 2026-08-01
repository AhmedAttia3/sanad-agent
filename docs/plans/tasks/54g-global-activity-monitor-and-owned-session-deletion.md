---
title: "Task 54g: Global Activity Monitor and Owned Session Deletion"
description: "إضافة Background tasks(count) في status bar وActivity Monitor عامة، وربط حذف المحادثة بإلغاء مهامها قبل الحذف."
status: "pending"
current_gate: "Waiting for 54e"
priority: "high"
depends_on: "54a, 54e"
file_budget: 14
reference_grounding: "required"
evidence_id: "54g"
design_contract: "docs/technical/background_terminal_task_runtime.md"
---

# Task 54g: Global Activity Monitor and Owned Session Deletion

## 1. الهدف

توفير مراقبة عامة لكل tasks على الجهاز المحدد، مع انتقال للمحادثة وتحكم حي،
ومنع حذف session ذات process نشطة دون confirmation وإلغاء ناجح.

## Gate R0 — External Reference Grounding

- [ ] حل `evidence_id` عبر workflow التأصيل الخارجي والتحقق من freshness.
- [ ] قراءة implementations والاختبارات الإلزامية وتسجيل مصفوفة
      `Adopt / Adapt / Reject` محلية ومحايدة المصدر.
- [ ] تحويل القرارات المقبولة إلى invariants واختبارات صريحة لهذه المهمة.
- [ ] عند غياب الحزمة أو قدمها، تشغيل authoring/refresh حتى تصبح `ready`.
- [ ] عدم بدء G0 قبل `ready`؛ لا تسجل `blocked` إلا لمانع غير قابل للتعافي.

### R0 Exit

- [ ] سجل التأصيل يحمل fingerprint والرموز والاختبارات المتحققة والقرارات.
- [ ] لا يحتوي أي ملف متتبع هوية المصدر الخارجي أو مساره؛ يبقى العقد سلوكيًا.

## 2. Gate G0 — Global projection

- [ ] `Background tasks (count)` في status bar؛ count لغير النهائية فقط.
- [ ] snapshot/live store device-scoped مع ordering ثابت وrevision merge.
- [ ] recent terminal retention محددة ولا تدخل في active count.
- [ ] navigation إلى session المالكة يحترم device/workspace routing.

### G0 Exit

- [ ] count والقائمة يتطابقان بعد reconnect أو terminal transition.

## 3. Gate G1 — Activity Monitor

- [ ] list/filter active وrecent terminal tasks حسب session/status.
- [ ] output viewer،normal/secure input،cancel،وopen conversation.
- [ ] empty/loading/offline/interrupted/cleanup-failed states بالإنجليزية.
- [ ] actions تستخدم نفس authoritative commands ولا تكرر منطق session panel.
- [ ] responsive/accessibility/keyboard behavior.

### G1 Exit

- [ ] التحكم من monitor ينعكس فورًا في session panel والعكس.

## 4. Gate G2 — Owned session deletion

- [ ] delete preflight تجلب non-terminal task count authoritative.
- [ ] dialog: `Cancel tasks and delete` أو Cancel، دون حذف تفاؤلي.
- [ ] daemon cancel-all ثم ينتظر terminalization ثم يحذف session.
- [ ] cleanup failure يمنع الحذف ويحافظ على session/task records.
- [ ] repeated/multi-client delete idempotent ولا يلغي task جلسة أخرى.

### G2 Exit

- [ ] لا يمكن إنتاج ownerless process عبر أي مسار حذف UI أو protocol.

## 5. Gate G3 — Verification and docs

- [ ] count/list/filter/navigation وcross-device isolation.
- [ ] deletion success/failure/race مع task exit أو client disconnect.
- [ ] مشاركة widgets/services مع 54f بلا duplication.
- [ ] تحديث navigation/deletion/product/QA docs.

### G3 Exit / Definition of Done

- [ ] Activity Monitor تعمل كمصدر مراقبة عام، وحذف session آمن ومؤكد.
- [ ] Reference parity audit يثبت أن التنفيذ والاختبارات يحققان كل قرار
      `Adopt/Adapt` مسجل، أو يعيد أي deviation إلى تصميم المهمة.
- [ ] المهمة داخل file budget.

## 6. الملفات المتوقعة

- global task store/selectors (1–2 ملف)
- status bar integration (1 ملف)
- activity monitor widgets/route (3–4 ملفات)
- conversation deletion flow (1–2 ملف)
- اختبارات store/widget/deletion (3 ملفات)
- أقرب `AGENTS.md`
- `docs/product/background_terminal_tasks_ux.md`
- `docs/product/conversation_navigation_ux_spec.md`
- ملف المهمة والخطة الأم

## 7. سيناريو النجاح

تعمل ثلاث tasks في جلستين فيظهر `Background tasks (3)`. يلغي المستخدم واحدة
من monitor فينخفض العدد وتحدث session panel. يحاول حذف session لها مهمتان؛ بعد
confirmation تلغيان وتثبت terminalization ثم تحذف session. عند cleanup failure
تبقى session ولا توجد process بلا مالك.

## 8. سجل التقدم

```text
Date:
Gate/status:
Files changed:
Verification:
Findings:
Next gate:
```
