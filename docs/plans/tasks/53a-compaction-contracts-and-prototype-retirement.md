---
title: "Task 53a: Compaction Contracts and Prototype Retirement"
description: "إزالة ContextEngine التجريبي وتثبيت حدود الملكية والأنواع والاعتماديات التي ستستهلكها مهام الضغط اللاحقة."
status: "pending"
current_gate: "A0"
priority: "critical"
depends_on: "Approved Plan 53"
file_budget: 10
---

# Task 53a: عقود compaction وإزالة النموذج التجريبي

## 1. الهدف

إزالة مسار `ContextEngine` القديم بالكامل لأنه نموذج اختباري غير صالح كأساس إنتاجي، ثم تثبيت vocabulary وحدود الملكية بين engine وpersistence وruntime وprotocol قبل أي تنفيذ جديد.

هذه المهمة لا تقدم compaction جزئية مؤقتة. بعد إغلاقها لا يوجد ضغط سياق حتى تكتمل المهام التالية، ويظل context overflow خاضعًا لسلوك recovery الحالي مؤقتًا بدل تشغيل مسار غير موثوق.

## 2. Gate A0 — تدقيق الإزالة والعقود

- [ ] حصر imports وDI registrations وconstructor parameters والاستدعاءات والاختبارات والوثائق التي تملك `ContextEngine` أو تصفه كميزة إنتاجية.
- [ ] إثبات أن الإزالة لا تمس `AgentContextAssembler` أو context-usage metrics أو provider context-limit resolution.
- [ ] تعريف boundaries التالية قبل إضافة types:
  - pressure evaluation تستهلك request material ولا تملك history.
  - compaction engine تحول immutable snapshot إلى candidate فقط.
  - persistence تملك source revision وboundary activation.
  - runtime orchestrator يملك serialization والqueue والterminal state.
  - protocol يعرض lifecycle ولا يملك summary أو قرار الضغط.
- [ ] اعتماد vocabulary موحدة: `CompactionTrigger`, `CompactionStatus`, `CompactionFailureReason`, `CompactionPressure`, `CompactionCandidate`, و`CompactionOutcome` أو أسماء مكافئة.
- [ ] تحديد metadata الداخلية التي يجب stripping لها قبل provider wire serialization.

### A0 Exit

- [ ] لا يوجد ownership مشترك غامض بين `AgentRunner` وservice جديدة.
- [ ] 53b و53c يمكنهما الاعتماد على types ثابتة دون استيراد interface أو Flutter code.

## 3. Gate A1 — إزالة النموذج التجريبي

- [ ] حذف `agent/lib/engine/context_engine.dart`.
- [ ] إزالة DI registration والحقن في `AgentRunner`.
- [ ] إزالة الاستدعاءين السابقين للضغط من sync وstream model loops.
- [ ] إزالة test/mocks المملوكة حصريًا للمحرك القديم.
- [ ] إزالة أو تصحيح عقود `AGENTS.md` والوثائق التي تقول إن history تضغط تلقائيًا بهذا المحرك.
- [ ] إبقاء provider context-limit APIs وcontext-usage indicator دون تغيير سلوكي.
- [ ] عدم ترك no-op abstraction تحمل الاسم القديم أو compatibility adapter غير مستخدمة.

### A1 Exit

- [ ] لا يعثر البحث المباشر على reference إنتاجية لـ`ContextEngine` أو `compressIfNeeded`.
- [ ] AgentRunner يبني الطلبات ويرسلها دون mutation خفية في history.
- [ ] اختبارات runner/provider usage الحالية لا تتراجع بسبب الإزالة.

## 4. Gate A2 — أنواع الأساس وحدود الاعتماد

- [ ] إضافة provider-neutral domain types المطلوبة فقط لفتح 53b و53c، دون implementation أو DB schema مبكرة.
- [ ] تمثيل trigger بقيم `manual|auto|overflow` وتمثيل lifecycle بقيم terminal صريحة.
- [ ] جعل candidate تحمل source revision/range وretained-tail range وsummary داخلية وmetrics وcontinuity validation result.
- [ ] منع الأنواع من حمل raw credentials أو adapter response bodies أو Flutter presentation fields.
- [ ] تثبيت أن summary ليست `MessageRole.system` ولا user-visible `Message`.
- [ ] تثبيت أن source selection يعتمد stable identities/revision، لا list indices العابرة.

### A2 Exit

- [ ] الأنواع قابلة للاختبار مستقلة عن DI وقاعدة البيانات.
- [ ] لا تتطلب 53b استيراد summarizer، ولا تتطلب 53c استيراد SessionDB.

## 5. Gate A3 — التحقق والتوثيق

- [ ] تحليل agent نظيف بعد الإزالة.
- [ ] اختبارات AgentRunner وcontext usage وprovider routing المركزة ناجحة.
- [ ] تحديث engine/plugin contracts لإزالة الوصف القديم.
- [ ] إضافة تصميم compaction إلى technical MOC أو صفحة technical مالكة بدل وضع design داخل `AGENTS.md`.
- [ ] مراجعة file budget وسجل الملفات الفعلية قبل التسليم.

### A3 Exit / Definition of Done

- [ ] لا يوجد مسار ضغط تجريبي أو تلقائي مخفي.
- [ ] ownership/types المعتمدة تكفي لبدء 53b و53c بالتوازي.
- [ ] لا تغير المهمة protocol أو UI أو persistence schema قبل عقودها المالكة.

## 6. الملفات المتوقعة

- `agent/lib/engine/context_engine.dart` (حذف)
- `agent/lib/engine/agent_runner.dart`
- `agent/lib/core/di.dart`
- `agent/test/engine/context_engine_test.dart` وmock المولد (حذف)
- domain types جديدة تحت owner يثبت في A0
- `agent/lib/engine/AGENTS.md`
- `agent/lib/plugins/AGENTS.md`
- `docs/technical/agent_runtime.md`
- ملف المهمة والخطة الأم

## 7. سيناريو النجاح

يبنى AgentRunner لجلسة موجودة ويرسل sync وstream turns مع exact provider/model route، ويستمر context-usage reporting كما هو. لا يحدث أي mutation في history قبل provider request، ولا يبقى أي reference للمحرك التجريبي، بينما تكون types الجديدة قابلة للاستهلاك من persistence والمحرك دون coupling متبادل.

## 8. خارج النطاق

- schema أو boundary persistence.
- summary prompt أو token budgeting.
- auto trigger أو overflow recovery.
- `/compact` أو Flutter UX.

## 9. سجل التقدم

```text
Date:
Gate/status:
Files changed:
Verification:
Findings:
Next gate:
```

