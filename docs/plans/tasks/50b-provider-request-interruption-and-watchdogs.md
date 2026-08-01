---
title: "Task 50b: Provider Request Interruption and Watchdogs"
description: "جعل اتصالات المزود قابلة للقطع بالـrun cancellation أثناء connect/send/SSE مع timeouts مرحلية ومنع retry بعد user stop."
status: "pending"
current_gate: "Waiting for 50a"
priority: "critical"
depends_on: "50a"
file_budget: 14
reference_grounding: "required"
evidence_id: "50b"
design_contract: "docs/technical/run_cancellation_and_process_ownership.md"
---

# Task 50b: Provider Request Interruption and Watchdogs

## 1. الهدف

قطع طلب المزود فورًا عند Stop سواء كان معلقًا قبل headers أو أثناء stream، دون إغلاق طلبات جلسات أخرى أو تصنيف الإلغاء كفشل شبكة قابل لإعادة المحاولة.

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

## 2. Gate B0 — Transport ownership contract

- [ ] تحديد request-owned cancel handle يستهلك `RunCancellationScope` من options.
- [ ] منع إغلاق HTTP client مشتركة بين runs.
- [ ] تعريف exception/result typed للإلغاء اليدوي منفصل عن timeout/network.
- [ ] تثبيت مراحل watchdog: connect/headers، first byte، stream idle، وtotal الاختيارية.

### B0 Exit

- [ ] كل adapter تستطيع قطع request واحدة دون التأثير على غيرها.
- [ ] قيم watchdog مركزية وقابلة للتهيئة وليست literals موزعة.

## 3. Gate B1 — OpenAI-compatible وCodex Responses

- [ ] قطع `send` المعلقة عند cancellation.
- [ ] قطع SSE byte stream عند cancellation أو stream-idle timeout.
- [ ] ضمان إغلاق transport في success/error/cancel paths.
- [ ] منع request dump أو accumulated response المتأخر من تغيير run الملغاة.
- [ ] الحفاظ على provider state semantics في Codex Responses.

### B1 Exit

- [ ] fake transport قبل headers وأثناء SSE ينتهي فور Stop.
- [ ] cancellation لا تتحول إلى retry أو runtime network notice.

## 4. Gate B2 — Anthropic-compatible وOllama

- [ ] تطبيق نفس transport contract دون تكرار منطق cancellation.
- [ ] توحيد parsing behavior الحالي مع إغلاق stream الآمن.
- [ ] التأكد من أن inherited/overridden paths كلها تستهلك scope.

### B2 Exit

- [ ] جميع adapters الإنتاجية تتبع العقد نفسه.
- [ ] adapter لا تدعم الإلغاء لا يمكن تسجيلها صامتًا كproduction-ready.

## 5. Gate B3 — Recovery/rate-limit integration

- [ ] دمج cancel token الحالي للـrate-limit مع scope الموحدة أو تفويضه لها.
- [ ] منع auto retry/failover بعد `userStop`.
- [ ] إبقاء network retry المشروع مستقلًا عن cancellation.
- [ ] رفض أي progress متأخر لا تملكه run الحالية.

### B3 Exit

- [ ] user stop لا يولد provider recovery notice جديدة.
- [ ] rate-limit waits القديمة لا تستأنف run ملغاة.

## 6. Gate B4 — التحقق والتوثيق

- [ ] اختبارات send لا تنتهي، headers بلا body، stream يتوقف، وlate chunk.
- [ ] اختبار عزل طلبين متوازيين وإلغاء أحدهما فقط.
- [ ] اختبارات adapters الحالية وprovider-state تمر دون تراجع.
- [ ] تحديث engine contract وprovider/runtime QA.

### B4 Exit / Definition of Done

- [ ] Stop يقطع كل provider path إنتاجية دون انتظار server response.
- [ ] لا leak لاتصال ولا retry/failover بعد user cancellation.
- [ ] Reference parity audit يثبت أن التنفيذ والاختبارات يحققان كل قرار
      `Adopt/Adapt` مسجل، أو يعيد أي deviation إلى تصميم المهمة.
- [ ] المهمة داخل file budget.

## 7. الملفات المتوقعة

- `agent/lib/engine/adapters/llm_request_options.dart`
- transport/cancellation helper جديد تحت `agent/lib/engine/adapters/`
- `agent/lib/engine/adapters/base_openai_adapter.dart`
- `agent/lib/engine/adapters/codex_responses_adapter.dart`
- `agent/lib/engine/adapters/base_anthropic_adapter.dart`
- `agent/lib/engine/adapters/ollama_adapter.dart`
- `agent/lib/engine/adapters/rate_limited_llm_adapter.dart`
- اختبارات adapters المركزة (3–4 ملفات)
- `agent/lib/engine/AGENTS.md`
- `docs/technical/provider_protocol.md`
- ملف المهمة والخطة الأم

## 8. سيناريو نجاح

يبدأ طلبان لمزودين أو جلستين؛ الأول لا يعيد headers والثاني يبث طبيعيًا. إلغاء الأول يقطع اتصاله داخل deadline، ولا يغلق الثاني، ولا ينشئ retry أو failover أو notice جديدة للأول.

## 9. سجل التقدم

```text
Date:
Gate/status:
Files changed:
Verification:
Findings:
Next gate:
```
