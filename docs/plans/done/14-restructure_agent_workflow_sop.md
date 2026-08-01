---
title: "خطة إعادة هيكلة سير عمل الوكلاء وتوزيع المهام بصيغة SOP"
description: "خطة تفكيك وحذف ملف docs/agent_workflow.md وتوزيع محتوياته على ملف AGENTS.md والمهارات الموجودة في .agent/skills بصيغة SOP."
---
<div dir="rtl" style="direction: rtl; text-align: right;">

# خطة إعادة هيكلة سير عمل الوكلاء وتوزيع المهام بصيغة SOP

## الهدف

تفكيك وحذف ملف `docs/agent_workflow.md` وتوزيع وتوجيه كافة القواعد والمفاهيم الموجودة به إلى ملف `AGENTS.md` الرئيسي (الذي يمثل نقطة الدخول الرسمية والعقود العامة للوكلاء) وإلى ملفات المهارات في `.agent/skills/` بصيغة إجراءات تشغيل قياسية (Standard Operating Procedures - SOP). 

الهدف الأسمى هو توضيح أن `AGENTS.md` هو نقطة الدخول الأولى لجميع الوكلاء، وأن "التقمص الوظيفي" أو الانتقال إلى أدوار محددة للوكلاء يتم عن طريق الإشارة المباشرة من المطور البشري إلى المهارة SOP المحددة (مثل `sanad-orchestrator` أو `sanad-subagent-developer`).

---

## النطاق

تشمل التعديلات الملفات التالية:

1. **[AGENTS.md](AGENTS.md) (في جذر المشروع):**
   - إعادة تعريفه ليكون نقطة الدخول الأولى للوكلاء (Master Entrypoint & Contract).
   - تحديث "ميثاق الفصل الصارم بين روافد المعرفة" (The Strict Separation Pact) لتوضيح الحدود بين القوانين (`AGENTS.md`)، الأدوات والأدوار (في `.agent/skills/`)، والتصاميم (في `docs/`).
   - توضيح دورة حياة قراءة وكتابة الوثائق (Read/Write Document Lifecycle) ومبادئ كارباثي للهندسة البرمجية للوكلاء (Karpathy's Agentic Engineering).
   - إزالة أي إشارة لـ `docs/agent_workflow.md`.

2. **المهارات تحت المسار `.agent/skills/`:**
   - **[sanad-orchestrator/SKILL.md](.agent/skills/sanad-orchestrator/SKILL.md):** إعادة صياغته ليكون SOP متكامل للوكيل الرئيسي (Orchestrator Agent)، يغطي مراحل التخطيط، تفكيك المهام، ربط ClickUp، واتخاذ قرار الاستدعاء (استدعاء مباشر أم وكيل فرعي).
   - **[sanad-subagent-developer/SKILL.md](.agent/skills/sanad-subagent-developer/SKILL.md):** إعادة صياغته ليكون SOP متكامل للوكيل المطور الفرعي (Subagent Developer)، يغطي مراحل تجهيز بيئة العمل المعزولة (Git Worktree)، التعديل الفعلي، الفحص والاختبار التراكمي، رفع الـ PR، كتابة تقارير التقييم وربط ClickUp.

3. **[docs/agent_workflow.md](docs/agent_workflow.md):**
   - حذف هذا الملف نهائياً بعد نقل وتوزيع جميع مهامه وقواعده.

4. **تحديث النصوص أو الفهارس المرجعية (مثل [docs/llms.txt](docs/llms.txt)):**
   - تحديث المراجع والإشارات لتتوافق مع الهيكل الجديد وإزالة الإشارة لملف `docs/agent_workflow.md`.

---

## معايير القبول (Acceptance Criteria)

- [ ] تم نقل كافة تفاصيل سير العمل والعمليات ومبادئ كارباثي وفصل الروافد من `docs/agent_workflow.md` وتوزيعها بشكل متناسق في `AGENTS.md` الرئيسي وفي المهارات المحددة.
- [ ] تم توثيق طريقة تحول الوكيل إلى دور محدد (Role Assumption) عندما يشير المطور البشري إلى المهارة SOP الخاصة بالدور.
- [ ] تمت صياغة كل من `sanad-orchestrator/SKILL.md` و `sanad-subagent-developer/SKILL.md` بصيغة SOP واضحة تحتوي على: الهدف، المسؤوليات، والخطوات التشغيلية التفصيلية.
- [ ] تم حذف الملف `docs/agent_workflow.md` بالكامل من المستودع.
- [ ] تم تحديث ملف `AGENTS.md` الرئيسي ليوضح الهيكل التنظيمي الجديد ويحذف أي مراجع معطلة.
- [ ] نجاح الفحص والاختبار والـ Build العام للمشروع دون كسر أي عقود برمجية أو إحداث تعارضات.

</div>
