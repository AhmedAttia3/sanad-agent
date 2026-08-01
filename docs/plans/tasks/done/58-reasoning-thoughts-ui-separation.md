---
title: "Task 58: Reasoning, Thoughts, and Final Answer UI Separation"
description: "فصل هويات Reasoning وThoughts وFinal Answer مع عرضها عبر Markdown الأساسي وتمرير محادثة واحد."
status: "complete"
current_gate: "Verified"
priority: "high"
depends_on: ""
file_budget: 12
reference_grounding: "required"
evidence_id: "55"
evidence_fingerprint: "sha256:d470f11ba38e03cf068a2d350f76a6abc85f1547774282752501b6651de4df9c"
design_contract: "docs/technical/reasoning_thoughts_separation.md"
---

# Task 58: Reasoning, Thoughts, and Final Answer UI Separation

## 1. الهدف

الحفاظ على الفصل البروتوكولي والمنطقي بين Reasoning وThoughts وFinal Answer،
مع تجربة قراءة مباشرة لا تضيف تمريرًا أو viewport داخل عناصر المساعد:

- `thought_stream` يبقى `EventKind.thinking`.
- `reasoning_stream` يبقى `EventKind.reasoning`.
- `final_answer` يبقى `EventKind.finalAnswer`.
- الأنواع الثلاثة تستخدم عارض Markdown الأساسي نفسه للمحتوى.
- Thoughts وReasoning يضيفان label بسيطًا فقط أعلى المحتوى.
- تمرير المحادثة الخارجي هو المالك الوحيد للـscroll والـstreaming auto-follow.

## Gate R0 — External Reference Grounding

- [x] حُصر التأصيل في مصدرين مرجعيين فقط.
- [x] روجعت نماذج فصل reasoning، lifecycle، العرض الحي، والـsticky scrolling.
- [x] حُولت النتائج إلى التزامات source-neutral واختبارات قابلة للتحقق.
- [x] ثُبتت الحزمة بالـfingerprint الموجود في front matter.

## 2. Gate F0 — الفصل البروتوكولي

- [x] Reasoning يستخدم أنواع canonical مستقلة عن Thoughts وFinal Answer.
- [x] reasoning callbacks تمر عبر `Message.reasoning`.
- [x] Reasoning وThoughts يملكان timeline identities مختلفة داخل model step نفسه.
- [x] history replay يحافظ على الحقلين إذا اجتمعا في رسالة واحدة.
- [x] أحداث البث الفارغة لا تنشئ timeline rows.
- [x] كتل reasoning المدعومة لا تُسرّب الوسوم إلى Final Answer.
- [x] adapters تحافظ على فصل reasoning المنظم أو المعلّم عن النص النهائي.

## 3. Gate F1 — العرض المباشر والتمرير الواحد

- [x] Thoughts وReasoning وFinal Answer تستخدم نفس primary Markdown renderer.
- [x] Thoughts تعرض label بأيقونة ونص `Thinking` أثناء البث و`Thoughts` بعده.
- [x] Reasoning تعرض label بأيقونة ونص `Reasoning`.
- [x] labels تتبع تنسيق عناوين الأدوات: أيقونة يسارًا ثم عنوان داكن.
- [x] Thoughts وReasoning لا تعرضان metadata الخاصة بـFinal Answer، وتحتفظان
      بزر نسخ أسفل المحتوى.
- [x] إزالة القياس حسب الأسطر وmeasurement probe والـbounded viewport.
- [x] إزالة expand/collapse والـnested ScrollController والـinner auto-follow.
- [x] إزالة scroll-overflow handoff وأي استثناء يمنع outer auto-follow لتحديثات Reasoning.
- [x] الإبقاء على ScrollController المحادثة كمالك وحيد للتمرير.
- [x] نمو محتوى streaming يتبع سلوك auto-scroll الخارجي المعتاد عند وجود المستخدم أسفل المحادثة.
- [x] الإبقاء على invariant صف running واحد لكل assistant stream kind دون خلط Thoughts وReasoning.

## 4. Gate V0 — الاختبارات والتحقق

- [x] Widget: الأنواع الثلاثة تشترك في primary Markdown style.
- [x] Widget: labels تميّز Thoughts/Thinking عن Reasoning.
- [x] Widget: Reasoning الطويل لا ينشئ disclosure أو viewport أو scrollbar داخليًا.
- [x] Widget: Thoughts وReasoning تحتفظان بزر النسخ من دون metadata.
- [x] Widget: نمو Reasoning أثناء وجود المحادثة في الأسفل يستخدم outer auto-scroll.
- [x] `fvm flutter analyze`: no issues.
- [x] focused client tests: 63 passed، ثم 4 widget assertions نهائية passed.
- [x] client full fast suite: 731 passed.
- [x] `graphify update .`.
- [x] `scripts/sanad-dev restart client` من الـworktree: نجح hot restart، والـruntime
      بقي running مع bounded client logs بلا startup errors.

## 5. Gate F2 — تصحيح Codex commentary

- [x] مراجعة evidence packet رقم `55` ونسخة Hermes المثبتة.
- [x] إضافة `Message.thought` كقناة typed مستقلة عن reasoning وfinal content.
- [x] توجيه Codex `phase=commentary` إلى thought، و`phase=analysis` إلى reasoning.
- [x] منع thought من الدخول إلى `AgentRunner.fullContent` أو Final Answer.
- [x] تمرير thought callback إلى `thought_stream` وحفظه مستقلًا للتاريخ.
- [x] إضافة سطر Markdown فارغ عند الانتقال بين reasoning summary parts.
- [x] اختبار المثال المركب: عنوانا reasoning غامقان + commentary عربي + final منفصل.
- [x] focused agent tests: 176 passed.
- [x] `fvm dart analyze` النهائي: no issues.
- [x] agent full fast suite: 877 passed، 2 skipped، بعد عزل متغيرات `sanad-dev`
      من أمر الاختبار فقط.
- [x] client full regression suite: 731 passed.
- [x] `graphify update .`.
- [x] restart agent وclient عبر `scripts/sanad-dev`: نجحا والاتصال المحلي بقي
      connected؛ cloud profile endpoint المحلي غير المتاح أصدر warning غير مرتبط.
