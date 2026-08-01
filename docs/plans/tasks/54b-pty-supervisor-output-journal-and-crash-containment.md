---
title: "Task 54b: PTY Supervisor, Output Journal, and Crash Containment"
description: "بناء owner موحدة للعملية التفاعلية والمخرجات والـwatchdog مع containment عبر المنصات وبدون تبني process بعد restart."
status: "pending"
current_gate: "Waiting for 54a"
priority: "critical"
depends_on: "54a; Plan 50c process controller"
file_budget: 14
reference_grounding: "required"
evidence_id: "54b"
design_contract: "docs/technical/background_terminal_task_runtime.md"
---

# Task 54b: PTY Supervisor, Output Journal, and Crash Containment

## 1. الهدف

توفير supervisor تملك PTY/process handle من spawn إلى terminal، وتدير output
journal وstdin/resize/timeout/cancel، وتضمن قتل containment عند daemon crash.

## Gate R0 — External Reference Grounding

- [ ] حل `evidence_id` عبر workflow التأصيل الخارجي والتحقق من freshness.
- [ ] قراءة implementations والاختبارات الإلزامية وتسجيل مصفوفة
      `Adopt / Adapt / Reject` محلية ومحايدة المصدر.
- [ ] تحويل القرارات المقبولة إلى invariants واختبارات صريحة لهذه المهمة.
- [ ] عند غياب الحزمة أو قدمها، تشغيل authoring/refresh حتى تصبح `ready`.
- [ ] عدم بدء B0 قبل `ready`؛ لا تسجل `blocked` إلا لمانع غير قابل للتعافي.

### R0 Exit

- [ ] سجل التأصيل يحمل fingerprint والرموز والاختبارات المتحققة والقرارات.
- [ ] لا يحتوي أي ملف متتبع هوية المصدر الخارجي أو مساره؛ يبقى العقد سلوكيًا.

## 2. Gate B0 — PTY and supervisor abstraction

- [ ] interface موحدة لـspawn/read/write/resize/wait/terminate عبر المنصات.
- [ ] إعادة استخدام Plan 50 process controller بدل tree killer ثانية.
- [ ] كل handle تحمل PID fingerprint وcontainment identity وowner generation.
- [ ] PTY adapter تعالج DSR position requests وتحفظ normal/application cursor
      key mode وتدعم bracketed paste،keys،submit،EOF،وresize.
- [ ] supervisor admission state هي `accepting | draining | stopped` مع حدود
      مركزية لكل session/device وtyped rejection دون hidden queue.
- [ ] دعم non-interactive fallback صريح إذا تعذر PTY، دون ادعاء stdin تفاعلية.

### B0 Exit

- [ ] fake adapter يثبت lifecycle كاملة ويمكن استبداله بتنفيذ المنصة.

## 3. Gate B1 — Output journal and replay cursor

- [ ] absolute byte cursor وretained-from cursor لكل task.
- [ ] memory ring صغيرة مع disk journal rotation وحدود حجم/عمر مركزية.
- [ ] replay snapshot ثم activation؛ chunks الحية أثناء replay تدخل pending buffer.
- [ ] flush terminal output قبل terminal DB transition.
- [ ] تحديث `last_output_at` عند bytes فعلية وإصدار attention notice غير نهائية
      بعد silence threshold؛ no-output cancellation تعمل فقط عند مهلة صريحة >0.
- [ ] file permissions محلية ضيقة وتنظيف journals حسب retention.

### B1 Exit

- [ ] disconnect/replay لا يفقد ولا يكرر bytes، وtruncation معلنة بالcursor.

## 4. Gate B2 — Crash containment and restart reconciliation

- [ ] graceful shutdown يلغي supervisors ضمن deadline ويثبت outcomes.
- [ ] shutdown يرفض spawns الجديدة أولًا، ينتظر drain bounded، ثم يلغي الباقي.
- [ ] POSIX owner-lifetime watchdog عبر pipe/heartbeat ينهي containments ثم يخرج.
- [ ] Windows Job Object kill-on-close أو fallback موثق ومختبر.
- [ ] startup يحول owner-generation القديمة إلى `interrupted` دون adopt/re-exec.
- [ ] PID fingerprint mismatch تمنع قتل عملية غير مملوكة.

### B2 Exit

- [ ] kill قسري للdaemon لا يترك child tree، والسجل يعود interrupted.

## 5. Gate B3 — Verification and docs

- [ ] اختبارات stdin/resize/output/exit وTERM-resistant descendants.
- [ ] اختبارات DSR،cursor key modes،bracketed paste،submit،EOF،وcapability fallback.
- [ ] اختبارات capacity/draining وsilent notice وexplicit no-output timeout.
- [ ] اختبارات rotation،cursor gap،replay/live race، وslow subscriber.
- [ ] platform gates حقيقية ولا تحول unit suite كلها إلى sequential.
- [ ] تحديث runtime/database/QA contracts.

### B3 Exit / Definition of Done

- [ ] supervisor owner الوحيدة لكل process خلفية.
- [ ] لا orphan ولا unbounded buffer ولا restart adoption.
- [ ] Reference parity audit يثبت أن التنفيذ والاختبارات يحققان كل قرار
      `Adopt/Adapt` مسجل، أو يعيد أي deviation إلى تصميم المهمة.
- [ ] المهمة داخل file budget.

## 6. الملفات المتوقعة

- supervisor/PTY abstractions تحت `agent/lib/capabilities/runtime/` (4–5 ملفات)
- journal/retention helper (1–2 ملف)
- platform process adapters التي أسستها 50c (1–2 ملف)
- اختبارات supervisor/journal/watchdog (3 ملفات)
- أقرب `AGENTS.md`
- `docs/technical/agent_runtime.md`
- `docs/qa_maintenance/plan54_background_tasks_matrix.md`
- ملف المهمة والخطة الأم

## 7. سيناريو النجاح

تشغل supervisor أمرًا تفاعليًا يطبع output وينشئ child مقاومة لـTERM. ينقطع
subscriber أثناء 50 chunk ثم يعيد الاتصال من cursor. تصل كل bytes مرة واحدة،
ثم يقتل daemon قسريًا؛ watchdog تنهي الشجرة ويصبح السجل `interrupted` بعد restart.

## 8. سجل التقدم

```text
Date:
Gate/status:
Files changed:
Verification:
Findings:
Next gate:
```
