---
title: "Task 53b: Durable Compaction Boundary and Model Projection"
description: "حفظ compaction lifecycle بصورة ذرية وبناء model projection من أحدث boundary ناجحة مع إبقاء التاريخ الأصلي كاملًا."
status: "pending"
current_gate: "B0"
priority: "critical"
depends_on: "Task 53a"
coordinates_with: "Tasks 47, 51, and 52"
file_budget: 14
---

# Task 53b: Compaction boundary دائمة وmodel projection غير هدامة

## 1. الهدف

إضافة مصدر حقيقة دائم لعمليات compaction بحيث لا تصبح أي summary فعالة إلا بعد commit ناجح، مع إبقاء canonical messages الأصلية كما هي وبناء سياق النموذج من أحدث boundary ناجحة.

## 2. Gate B0 — عقد التخزين والهوية

- [ ] تدقيق schema الحالية لـsessions/messages/work items/history metadata قبل اختيار الجدول والعلاقات.
- [ ] اعتماد هوية `compaction_id` و`session_id` و`source_history_revision` وsource/tail stable identities.
- [ ] اعتماد lifecycle `started -> completed|failed` ومنع terminal rewrite غير idempotent.
- [ ] تحديد الحقول الدائمة الدنيا:
  - trigger وstatus.
  - source range وretained-tail boundary.
  - internal validated summary.
  - provider/model route.
  - before/after/context-window metrics.
  - redacted failure reason.
  - started/completed timestamps.
- [ ] تحديد retention دون تكرار canonical message payloads داخل compaction rows.
- [ ] تحديد history revision/CAS المستخدمة لمنع activation فوق snapshot قديمة.
- [ ] تثبيت أن timeline history وpagination لا تخفي الرسائل السابقة للـboundary.

### B0 Exit

- [ ] Task 47 يمكنها paginate canonical events دون معرفة model projection internals.
- [ ] Tasks 51/52 تملكان قاعدة واضحة لإبطال أو remap boundary عند soft rewind أو fork.
- [ ] لا يعتمد العقد على ترتيب list في ذاكرة AgentRunner.

## 3. Gate B1 — Repository وmigration

- [ ] إضافة migration idempotent للجداول/الحقول/indexes المطلوبة.
- [ ] إضافة repository typed لبدء operation وتسجيل completed/failed outcome وقراءة أحدث boundary فعالة.
- [ ] جعل claim للجلسة exclusive عبر transaction/CAS؛ عمليتان متزامنتان لا تنجحان معًا.
- [ ] دعم restart عندما توجد operation في `started` بلا terminal outcome؛ تصنف interrupted/failed ولا تفعل summary.
- [ ] فصل redacted user-visible failure عن diagnostic metadata الداخلية الآمنة.
- [ ] منع حفظ summary أو transcript يحتمل احتواء secrets قبل مرور redaction contract.

### B1 Exit

- [ ] latest successful boundary تستعاد بعد إغلاق قاعدة البيانات وفتحها.
- [ ] started/failed boundary لا تغير projection.
- [ ] concurrent claims تنتج فائزًا واحدًا وtyped busy/stale outcomes للبقية.

## 4. Gate B2 — Active model projection

- [ ] إضافة builder واحد يقرأ canonical history وأحدث successful boundary ويعيد:
  - validated internal summary واحدة.
  - retained verbatim tail.
  - كل الرسائل اللاحقة للـsnapshot.
- [ ] إبقاء current system/runtime context خارج summary وإعادة تركيبه عبر `AgentContextAssembler` لكل request.
- [ ] عدم إعادة internal metadata أو compaction row fields إلى provider wire.
- [ ] الحفاظ على assistant tool call/tool result pairs وprovider state اللازمة داخل retained tail.
- [ ] رفض projection ذات source identities مفقودة أو متعارضة بدل fallback صامت إلى ترتيب تقريبي.
- [ ] ضمان repeated compaction تستخدم boundary الأحدث ولا تراكم summaries سابقة.
- [ ] توفير raw canonical timeline query مستقلة لواجهة المستخدم والتدقيق.

### B2 Exit

- [ ] model projection تبدأ من boundary الصحيحة، وtimeline تظل كاملة.
- [ ] reload يعيد projection نفسها دون الاعتماد على mutation سابقة في AgentRunner.
- [ ] summary لا تظهر كرسالة system ثانية أو user/assistant message مصطنعة.

## 5. Gate B3 — Activation transaction والتكامل مع execution state

- [ ] تفعيل candidate داخل transaction تتحقق من session/source revision والclaim الحاليين.
- [ ] حفظ terminal metrics وsummary ثم نشر projection revision جديدة بعد commit فقط.
- [ ] persistence failure يعيد original boundary ولا يسمح بمتابعة provider request من candidate volatile.
- [ ] تعريف أثر queued work وactive work item دون حذف payload أو تغيير run ownership.
- [ ] جعل late completion من operation stale no-op لا تستبدل boundary أحدث.
- [ ] نشر repository change مرة واحدة بعد commit كي تستهلكه interface layer في 53d/53e.

### B3 Exit

- [ ] crash قبل commit لا يغير active context.
- [ ] crash بعد commit يعيد نفس boundary والmetrics والprojection.
- [ ] لا يمكن لsummary قديمة أو failure outcome إلغاء boundary أحدث.

## 6. Gate B4 — التحقق والتوثيق

- [ ] اختبارات migration وCRUD وexclusive claim وrestart وstale CAS.
- [ ] اختبارات projection للboundary الأولى والمتكررة وretained tail والرسائل اللاحقة.
- [ ] اختبارات عدم حذف canonical messages وعدم ظهور summary في timeline.
- [ ] اختبارات tool pairing وprovider state داخل tail.
- [ ] تحديث database schema وagent runtime design وQA ownership.
- [ ] مراجعة file budget قبل الإغلاق.

### B4 Exit / Definition of Done

- [ ] successful boundary وحدها authoritative.
- [ ] التاريخ الأصلي كامل وقابل للقراءة بعد أي عدد من compactions.
- [ ] model projection قابلة للبناء من التخزين فقط بعد restart.
- [ ] API المعتمدة جاهزة لاستهلاك 53c candidate و53d orchestration.

## 7. الملفات المتوقعة

- `agent/lib/evolution/db/agent_state_database.dart`
- repository/model files جديدة تحت `agent/lib/evolution/db/`
- model projection builder تحت engine/evolution owner المعتمد
- `agent/lib/evolution/session_manager.dart`
- `agent/lib/evolution/db/session_db.dart` عند الحاجة فقط دون استمرار destructive compaction
- اختبارات DB/projection مركزة
- `agent/lib/evolution/AGENTS.md`
- `agent/lib/engine/AGENTS.md`
- `docs/technical/agent_database_schema.md`
- `docs/technical/agent_runtime.md`
- QA page الخاصة بالخطة
- ملف المهمة والخطة الأم

## 8. سيناريو النجاح

تبدأ compaction ثم يتوقف daemon قبل اكتمال summary؛ بعد restart يبقى التاريخ والسياق السابقان فعالين وتظهر العملية failed/interrupted. في محاولة ثانية تنجح summary وتفعل ذريًا. بعد restart جديد تبني request من summary واحدة وtail والرسائل اللاحقة، بينما session history المعروضة ما زالت تحتوي كل الرسائل الأصلية.

## 9. خارج النطاق

- تحديد الحاجة للضغط أو تشغيل summarizer.
- provider overflow recovery.
- canonical events أو Flutter timeline.
- حذف الرسائل القديمة أو تقليل حجم DB.

## 10. سجل التقدم

```text
Date:
Gate/status:
Files changed:
Verification:
Findings:
Next gate:
```

