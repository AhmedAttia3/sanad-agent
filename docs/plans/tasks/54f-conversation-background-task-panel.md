---
title: "Task 54f: Conversation Background Task Panel"
description: "عرض مهام الجلسة فوق composer مع output حي وterminal viewer وcancel وstdin عادية/حساسة دون جعل Flutter مصدر الحقيقة."
status: "pending"
current_gate: "Waiting for 54e"
priority: "high"
depends_on: "54e"
file_budget: 14
reference_grounding: "required"
evidence_id: "54f"
design_contract: "docs/technical/background_terminal_task_runtime.md"
---

# Task 54f: Conversation Background Task Panel

## 1. الهدف

إضافة view داخل المحادثة فوق composer تعرض tasks المالكة للجلسة، وتبقى متطابقة
مع daemon snapshot بعد navigation أو reconnect، وتتيح العرض والتفاعل والإلغاء.

## Gate R0 — External Reference Grounding

- [ ] حل `evidence_id` عبر workflow التأصيل الخارجي والتحقق من freshness.
- [ ] قراءة implementations والاختبارات الإلزامية وتسجيل مصفوفة
      `Adopt / Adapt / Reject` محلية ومحايدة المصدر.
- [ ] تحويل القرارات المقبولة إلى invariants واختبارات صريحة لهذه المهمة.
- [ ] عند غياب الحزمة أو قدمها، تشغيل authoring/refresh حتى تصبح `ready`.
- [ ] عدم بدء F0 قبل `ready`؛ لا تسجل `blocked` إلا لمانع غير قابل للتعافي.

### R0 Exit

- [ ] سجل التأصيل يحمل fingerprint والرموز والاختبارات المتحققة والقرارات.
- [ ] لا يحتوي أي ملف متتبع هوية المصدر الخارجي أو مساره؛ يبقى العقد سلوكيًا.

## 2. Gate F0 — Client state and hydration

- [ ] domain models keyed بالdevice/session/task ID وrevision/cursor.
- [ ] snapshot hydration قبل/مع live subscription دون duplication.
- [ ] cache bounded للpreview فقط؛ daemon/journal هما source of truth.
- [ ] عزل تغيير المحادثة والجهاز وإلغاء subscriptions القديمة.

### F0 Exit

- [ ] navigation والعودة تعرضان الحالة نفسها بلا stale tasks من session أخرى.

## 3. Gate F1 — Session-local panel

- [ ] panel فوق composer وعلى نمط queued-message surface دون خلط القائمتين.
- [ ] صف task يعرض status،elapsed،command منقحة،output preview،وopen/stop.
- [ ] terminal viewer يدعم follow-tail،scroll،reconnect،وtruncation indicator.
- [ ] silence attention notice تظهر دون تغيير status إلى failed أو cancelled.
- [ ] states loading/empty/interrupted/cancelling/cleanup-failed واضحة بالإنجليزية.
- [ ] responsive layout وkeyboard/accessibility semantics.

### F1 Exit

- [ ] task running/terminal تنتقل فورًا بلا spinner دائم أو reload يدوي.

## 4. Gate F2 — Interactive input

- [ ] normal stdin editor مع send/newline controls.
- [ ] keyboard/paste/submit/EOF actions تحترم PTY capabilities وcursor mode.
- [ ] secure input mode masked ولا يمر عبر conversation composer/store.
- [ ] UI لا تحتفظ بالsecret بعد acknowledgement أو failure.
- [ ] permission/stale task outcomes تظهر بلا echo للنص الحساس.
- [ ] Stop task confirmation لا يخلطها بزر Stop session.

### F2 Exit

- [ ] المستخدم يجيب Y/n أو password prompt مع المسار الأمني الصحيح.

## 5. Gate F3 — Verification and docs

- [ ] widget/store tests للhydration/live/reconnect/navigation.
- [ ] output burst وcursor truncation وlate terminal event.
- [ ] secure input sentinel واختلاف Stop task عن Stop session.
- [ ] تحديث conversation product/QA/feature contracts.

### F3 Exit / Definition of Done

- [ ] session panel متطابقة live/history-like hydration وآمنة للتفاعل.
- [ ] Reference parity audit يثبت أن التنفيذ والاختبارات يحققان كل قرار
      `Adopt/Adapt` مسجل، أو يعيد أي deviation إلى تصميم المهمة.
- [ ] المهمة داخل file budget.

## 6. الملفات المتوقعة

- client background-task models/store/transport (3–4 ملفات)
- conversation panel/viewer/widgets (3–4 ملفات)
- conversation integration (1 ملف)
- اختبارات store/widget (3 ملفات)
- أقرب `AGENTS.md`
- `docs/product/background_terminal_tasks_ux.md`
- `docs/qa_maintenance/plan54_background_tasks_matrix.md`
- ملف المهمة والخطة الأم

## 7. سيناريو النجاح

تبدأ task في Session A وتظهر فوق composer. ينتقل المستخدم إلى B ثم يعود؛ تعاد
من snapshot عند cursor الصحيح. يفتح terminal ويرسل Y، ثم secret في secure mode.
تنتهي task ويتغير الصف terminal فورًا دون كشف secret أو الحاجة لإعادة فتح session.

## 8. سجل التقدم

```text
Date:
Gate/status:
Files changed:
Verification:
Findings:
Next gate:
```
