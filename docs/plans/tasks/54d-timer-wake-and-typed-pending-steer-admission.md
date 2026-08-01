---
title: "Task 54d: Timer Wake and Typed Pending Steer Admission"
description: "إضافة timer_to_wake وledger دائم لأحداث completion/timer/recovery وتسليمها كـtyped steer أو pending steer دون queue أو run متوازية."
status: "pending"
current_gate: "Waiting for 54a"
priority: "critical"
depends_on: "54a; Task 36 authoritative pending steer; Task 31 snapshots"
file_budget: 14
reference_grounding: "required"
evidence_id: "54d"
design_contract: "docs/technical/background_terminal_task_runtime.md"
---

# Task 54d: Timer Wake and Typed Pending Steer Admission

## 1. الهدف

إيقاظ الوكيل عند انتهاء task أو timer، مع حفظ trigger قبل scheduling وضمان أن
الجلسة المشغولة تستقبل typed pending steer في safe boundary بدل FIFO queue أو
run ثانية.

## Gate R0 — External Reference Grounding

- [ ] حل `evidence_id` عبر workflow التأصيل الخارجي والتحقق من freshness.
- [ ] قراءة implementations والاختبارات الإلزامية وتسجيل مصفوفة
      `Adopt / Adapt / Reject` محلية ومحايدة المصدر.
- [ ] تحويل القرارات المقبولة إلى invariants واختبارات صريحة لهذه المهمة.
- [ ] عند غياب الحزمة أو قدمها، تشغيل authoring/refresh حتى تصبح `ready`.
- [ ] عدم بدء D0 قبل `ready`؛ لا تسجل `blocked` إلا لمانع غير قابل للتعافي.

### R0 Exit

- [ ] سجل التأصيل يحمل fingerprint والرموز والاختبارات المتحققة والقرارات.
- [ ] لا يحتوي أي ملف متتبع هوية المصدر الخارجي أو مساره؛ يبقى العقد سلوكيًا.

## 2. Gate D0 — Typed wake contract

- [ ] kinds: `task_terminal`, `timer_due`, `restart_interrupted`.
- [ ] payload snapshots تستخدم schema `view_task` ولا تنسخ journal كاملة.
- [ ] dedupe key تشمل session/kind/task/revision أو timer identity.
- [ ] trigger ليست user message ولا تغير session ordering كرسالة مستخدم.
- [ ] terminal task persistence تسبق trigger admission.

### D0 Exit

- [ ] Task 36 owner يمكنها حمل source typed دون كسر pending user steers.

## 3. Gate D1 — `timer_to_wake` and scheduler ledger

- [ ] أداة `timer_to_wake(after_ms, task_ids?)` تتحقق من session ownership.
- [ ] حفظ trigger قبل arm timer وإعادة timers بعد restart من DB.
- [ ] overdue timers تدمج ولا burst؛ one-shot لا تطلق مرتين.
- [ ] timer بلا تغير منذ completion wake يمكن suppress مع outcome مسجلة.
- [ ] snapshots عند الاستحقاق تشمل tasks المستهدفة أو مهام الجلسة عند غياب IDs.

### D1 Exit

- [ ] restart قبل due لا يفقد timer ولا يكرر wake.

## 4. Gate D2 — Admission and run coordination

- [ ] idle session تبدأ drain واحدة من trigger الأقدم eligible.
- [ ] busy session تحفظ pending steer وتضبط advisory `pendingWake` فقط.
- [ ] user message وwake متزامنتان لا تنشئان runين.
- [ ] promote typed steer في أول safe boundary مع CAS delivering/delivered.
- [ ] عدة interrupted tasks بعد restart تصبح recovery wake واحدة لكل session.

### D2 Exit

- [ ] لا trigger تدخل FIFO queue أو تضيع عند provider/tool boundary.

## 5. Gate D3 — Verification and docs

- [ ] completion أثناء idle/busy/stopping/restart.
- [ ] timer/completion race وduplicate task event وlate revision.
- [ ] user message تصل مع pending wake.
- [ ] provider failure يبقي trigger recoverable بلا loop ساخنة.
- [ ] تحديث steer/runtime/scheduler/QA docs.

### D3 Exit / Definition of Done

- [ ] wake exactly-once دلاليًا لكل revision، وone active run invariant محفوظة.
- [ ] Reference parity audit يثبت أن التنفيذ والاختبارات يحققان كل قرار
      `Adopt/Adapt` مسجل، أو يعيد أي deviation إلى تصميم المهمة.
- [ ] المهمة داخل file budget.

## 6. الملفات المتوقعة

- `agent/lib/evolution/cron_scheduler.dart` أو scheduler owner الأقرب
- wake trigger service/repository تحت runtime (2–3 ملفات)
- `agent/lib/interfaces/runtime/session_run_orchestrator.dart`
- pending-steer/admission owner القائمة (1–2 ملف)
- timer tool + spec (1–2 ملف)
- اختبارات scheduler/admission/races (3 ملفات)
- أقرب `AGENTS.md`
- `docs/technical/agent_runtime.md`
- `docs/qa_maintenance/task36_authoritative_steer_queue_stop_recovery_matrix.md`
- ملف المهمة والخطة الأم

## 7. سيناريو النجاح

تعمل session في run نشطة حين تنتهي task وينتهي timer قريب منها. يحفظ completion
trigger، ويصبح pending steer، ويُقمع timer إن لم تتغير revision. لا تبدأ run
موازية؛ بعد safe boundary يرى الوكيل snapshot النهائية مرة واحدة.

## 8. سجل التقدم

```text
Date:
Gate/status:
Files changed:
Verification:
Findings:
Next gate:
```
