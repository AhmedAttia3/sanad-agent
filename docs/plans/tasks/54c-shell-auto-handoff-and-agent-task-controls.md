---
title: "Task 54c: Shell Auto-Handoff and Agent Task Controls"
description: "إضافة background_after_ms والنقل الذري إلى supervisor وأدوات view/write/cancel مع عزل ملكية الجلسات."
status: "pending"
current_gate: "Waiting for 54a and 54b"
priority: "critical"
depends_on: "54a, 54b; Plan 50a, 50c, 50d"
file_budget: 14
reference_grounding: "required"
evidence_id: "54c"
design_contract: "docs/technical/background_terminal_task_runtime.md"
---

# Task 54c: Shell Auto-Handoff and Agent Task Controls

## 1. الهدف

جعل كل `shell_execute` تتحول تلقائيًا إلى background بعد الحد الافتراضي، ثم
إتاحة عرض المهمة والتفاعل معها وإلغائها من الوكيل دون إبقاء run نشطة.

## Gate R0 — External Reference Grounding

- [ ] حل `evidence_id` عبر workflow التأصيل الخارجي والتحقق من freshness.
- [ ] قراءة implementations والاختبارات الإلزامية وتسجيل مصفوفة
      `Adopt / Adapt / Reject` محلية ومحايدة المصدر.
- [ ] تحويل القرارات المقبولة إلى invariants واختبارات صريحة لهذه المهمة.
- [ ] عند غياب الحزمة أو قدمها، تشغيل authoring/refresh حتى تصبح `ready`.
- [ ] عدم بدء C0 قبل `ready`؛ لا تسجل `blocked` إلا لمانع غير قابل للتعافي.

### R0 Exit

- [ ] سجل التأصيل يحمل fingerprint والرموز والاختبارات المتحققة والقرارات.
- [ ] لا يحتوي أي ملف متتبع هوية المصدر الخارجي أو مساره؛ يبقى العقد سلوكيًا.

## 2. Gate C0 — Shell contract

- [ ] إضافة `background_after_ms` كإعداد اختياري default=30000 و`0` فوري.
- [ ] إبقاء `timeout_ms` absolute runtime deadline بعد handoff.
- [ ] إضافة `no_output_timeout_ms` اختياري default=0؛ الصمت لا يقتل افتراضيًا.
- [ ] تثبيت foreground result وbackground typed result وvalidation errors.
- [ ] config central بلا magic literals أو تغيير صامت للعملاء القدماء.

### C0 Exit

- [ ] schema والوصف يفسران العلاقة بين المهلتين بلا التباس.

## 3. Gate C1 — Atomic auto-handoff

- [ ] spawn تحت Plan 50 containment وregistration.
- [ ] سباق exit مقابل background timer يحسم مرة واحدة.
- [ ] عند الحد: persist task، claim supervisor، ثم release registration.
- [ ] فشل أي خطوة يلغي handoff ويبقي foreground owner أو terminalizes failure.
- [ ] إغلاق tool event الأصلية بنتيجة background handoff واحدة قبل idle.

### C1 Exit

- [ ] لا فجوة ownership ولا process تقتلها Stop بعد release ناجحة.

## 4. Gate C2 — Agent tools

- [ ] `view_task(task_id?, cursor?)` مع list-by-session عند غياب ID.
- [ ] `write_task` لـstdin غير السرية بأوضاع
      `text | keys | paste | submit | eof` وcapability errors typed.
- [ ] `submit` تكتب data الاختيارية ثم Enter ذريًا، و`eof` تغلق stdin صراحة.
- [ ] `cancel_task` idempotent يمر عبر supervisor وterminal CAS.
- [ ] ToolContext/session ownership تمنع cross-session access.
- [ ] output caps تمنع إعادة journal ضخمة إلى model context.

### C2 Exit

- [ ] الوكيل يتابع task ويدخل `Y\n` ويلغيها دون امتلاك handle خام.

## 5. Gate C3 — Verification and docs

- [ ] command تنتهي قبل الحد، عند الحد، وبعده.
- [ ] `background_after_ms=0` وtimeout قبل/بعد handoff.
- [ ] silent command مع notice فقط، ثم explicit no-output timeout منفصلة.
- [ ] write modes وDSR/cursor-mode-sensitive keys وEOF.
- [ ] capacity/draining rejection لا تنشئ task row أو registration بلا مالك.
- [ ] Stop run بعد handoff لا يلغي task؛ cancel_task تفعل.
- [ ] repeated view/write/cancel وcross-session denial.
- [ ] تحديث capability/runtime/tool docs.

### C3 Exit / Definition of Done

- [ ] الجلسة تصبح idle بعد handoff مع task حية وقابلة للتحكم.
- [ ] terminal outcome واحدة في كل race.
- [ ] Reference parity audit يثبت أن التنفيذ والاختبارات يحققان كل قرار
      `Adopt/Adapt` مسجل، أو يعيد أي deviation إلى تصميم المهمة.
- [ ] المهمة داخل file budget.

## 6. الملفات المتوقعة

- `agent/lib/capabilities/tools/system/shell_execute_tool.dart`
- background task tools تحت `agent/lib/capabilities/tools/system/` (3 ملفات)
- tool specs/registry/context integration (1–2 ملف)
- supervisor handoff service (1 ملف)
- اختبارات shell/tools/coordinator (3 ملفات)
- أقرب `AGENTS.md`
- `docs/agent_engine/capability_runtime.md`
- `docs/technical/agent_runtime.md`
- ملف المهمة والخطة الأم

## 7. سيناريو النجاح

يشغل الوكيل command تستغرق دقيقة. بعد 30 ثانية تعيد الأداة `task_id` وتصبح
الجلسة idle. `view_task` تعيد delta، ثم `write_task(mode=submit, data="Y")`
ترسل الموافقة. Stop للجلسة
لا تمس المهمة، بينما `cancel_task` تنهي شجرتها وتعيد cancelled مرة واحدة.

## 8. سجل التقدم

```text
Date:
Gate/status:
Files changed:
Verification:
Findings:
Next gate:
```
