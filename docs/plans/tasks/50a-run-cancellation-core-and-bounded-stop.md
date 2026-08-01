---
title: "Task 50a: Run Cancellation Core and Bounded Stop"
description: "إضافة cancellation primitive مملوكة للـrun وإزالة الانتظار غير المحدود من مسار Stop مع حماية ملكية الجولات."
status: "pending"
current_gate: "A0"
priority: "critical"
depends_on: "Plan 30 run isolation, Task 31 authoritative execution snapshots, Task 36 stop recovery"
file_budget: 12
reference_grounding: "required"
evidence_id: "50a"
design_contract: "docs/technical/run_cancellation_and_process_ownership.md"
---

# Task 50a: Run Cancellation Core and Bounded Stop

## 1. الهدف

توفير `RunCancellationScope` واحد لكل `ActiveRun` يصبح عقد الإلغاء المشترك للمزود والأدوات والانتظارات، وجعل Stop محدودًا زمنيًا ويحافظ على عزل run القديمة عن أي run أحدث.

## Gate R0 — External Reference Grounding

- [ ] حل `evidence_id` عبر workflow التأصيل الخارجي والتحقق من freshness.
- [ ] قراءة implementations والاختبارات الإلزامية وتسجيل مصفوفة
      `Adopt / Adapt / Reject` محلية ومحايدة المصدر.
- [ ] تحويل القرارات المقبولة إلى invariants واختبارات صريحة لهذه المهمة.
- [ ] عند غياب الحزمة أو قدمها، تشغيل authoring/refresh حتى تصبح `ready`.
- [ ] عدم بدء A0 قبل `ready`؛ لا تسجل `blocked` إلا لمانع غير قابل للتعافي.

### R0 Exit

- [ ] سجل التأصيل يحمل fingerprint والرموز والاختبارات المتحققة والقرارات.
- [ ] لا يحتوي أي ملف متتبع هوية المصدر الخارجي أو مساره؛ يبقى العقد سلوكيًا.

## 2. بوابة الدخول A0 — تثبيت العقد

- [ ] توثيق حالات scope وأسباب الإلغاء ونتيجة cleanup typed.
- [ ] تحديد deadline الافتراضية ومصدر إعدادها دون magic values.
- [ ] تثبيت ترتيب `invalidate -> signal -> cleanup -> terminalize -> idle`.
- [ ] تحديد مسار cleanup failure وعدم إبقاء `stopping` بلا نهاية.
- [ ] إثبات أن scope keyed بالـrunId ولا يعاد استخدامها بين runs.
- [ ] اعتماد registration handle قابلة لـ`release()` دون إلغاء المورد، مع منع
      تحريرها قبل إثبات انتقال الملكية عند وجود handoff مستقبلي.

### A0 Exit

- [ ] API معتمدة ولا تتطلب تغييرًا لاحقًا من 50b أو50c.
- [ ] لا توجد سياسة تعتمد على sessionId وحده عند وجود runId.

## 3. Gate A1 — Cancellation primitive وملكية ActiveRun

- [ ] إضافة primitive تدعم signal idempotent وتسجيل cleanup callbacks.
- [ ] جعل التسجيل بعد بدء cancellation ينفذ cleanup بأمان مرة واحدة.
- [ ] جعل كل registration تعيد handle ذات `release()` idempotent وتزيل callback
      من cleanup المستقبلية دون تشغيلها.
- [ ] حفظ reason وtimestamps وتقرير الموارد التي انتهت أو فشلت.
- [ ] ربط scope بـ`ActiveRun` وتمريرها إلى `AgentRunner`.
- [ ] إبطال run synchronously قبل أول await في Stop.

### A1 Exit

- [ ] الإلغاء المتكرر لا ينفذ cleanup مرتين.
- [ ] release متكررة آمنة، وcancel بعد release لا ينفذ cleanup المحررة.
- [ ] run A الملغاة لا تستطيع إبطال أو إكمال run B.

## 4. Gate A2 — Bounded stop orchestration

- [ ] استبدال await المفتوح على subscription cancellation بانتظار bounded.
- [ ] فصل إكمال session state عن Future متأخرة مع إبقاء late-result guards.
- [ ] إنهاء work item إلى `cancelled` قبل نشر `idle` في مسار النجاح.
- [ ] تعريف transition واضح عند cleanup deadline failure.
- [ ] الحفاظ على stop recovery والqueued/steer barrier الحالية.

### A2 Exit

- [ ] hanging stream وهمية لا تبقي الجلسة `stopping` بلا نهاية.
- [ ] رسالة أحدث بعد stop barrier تبقى محفوظة ولا تمسحها run القديمة.

## 5. Gate A3 — التحقق والتوثيق

- [ ] اختبارات primitive: first cancel, repeated cancel, late registration, cleanup failure.
- [ ] اختبارات registration release: normal completion، repeated release، cancel
      after release، وفشل handoff قبل release.
- [ ] اختبارات orchestrator: hanging subscription, bounded exit, stale run، وmulti-client Stop.
- [ ] تحديث عقود engine/interfaces وأقرب وثيقة runtime/QA.
- [ ] مراجعة file budget قبل الإغلاق.

### A3 Exit / Definition of Done

- [ ] cancellation scope مستقرة ويمكن أن تستهلكها 50b و50c.
- [ ] العقد العام قابل لاستهلاك Plan 54 لاحقًا دون وجود أي dependency عكسية أو
      background implementation داخل هذه المهمة.
- [ ] Stop لا يعتمد على اكتمال provider/tool Future كي يخرج من الانتظار غير المحدود.
- [ ] اختبارات run isolation وstop recovery الحالية لا تتراجع.
- [ ] Reference parity audit يثبت أن التنفيذ والاختبارات يحققان كل قرار
      `Adopt/Adapt` مسجل، أو يعيد أي deviation إلى تصميم المهمة.

## 6. الملفات المتوقعة

- `agent/lib/engine/runtime/run_cancellation_scope.dart` (جديد)
- `agent/lib/interfaces/runtime/session_turn_executor.dart`
- `agent/lib/interfaces/runtime/session_run_orchestrator.dart`
- `agent/lib/engine/agent_runner.dart`
- `agent/lib/engine/AGENTS.md`
- `agent/lib/interfaces/AGENTS.md`
- اختبارات engine/interfaces المركزة (2–3 ملفات)
- `docs/technical/agent_runtime.md`
- `docs/qa_maintenance/plan30_runtime_recovery_matrix.md`
- ملف المهمة والخطة الأم

## 7. سيناريو نجاح

يبدأ fake run بموارد مسجلة؛ ينتهي مورد أول طبيعيًا ويحرر registration، بينما
يبقى مورد ثان معلقًا. عند Stop مرتين من عميلين لا ينفذ cleanup للمورد المحرر،
ويلغي المورد الثاني مرة واحدة، ويخرج من `stopping` داخل deadline مع الحفاظ على
رسالة أحدث وصلت بعد stop barrier.

## 8. سجل التقدم

```text
Date:
Gate/status:
Files changed:
Verification:
Findings:
Next gate:
```
