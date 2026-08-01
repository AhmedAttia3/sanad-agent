---
title: "Task 53f: Compaction Integration and Regression QA"
description: "إثبات ضغط السياق end-to-end عبر providers وtool loops وrestart والqueue والواجهة، وإغلاق أي findings دون إضافة سياسة جديدة."
status: "pending"
current_gate: "F0"
priority: "critical"
depends_on: "Tasks 53b, 53c, 53d, and 53e"
file_budget: 12
---

# Task 53f: التحقق التكاملي والانحداري للـcompaction

## 1. الهدف

إثبات أن النظام المكتمل يحافظ على الهدف والتاريخ وسلامة الأدوات وحالة الواجهة عبر التشغيل الحقيقي والانقطاع وإعادة التشغيل، وأن manual وauto compaction تستخدمان العقد نفسها دون اختلافات مخفية.

هذه المهمة لا تضيف policy أو schema جديدة. أي finding يكشف نقصًا معماريًا يعيد فتح Gate المالكة في 53b–53e ويحدث لوحة الخطة.

## 2. Gate F0 — مصفوفة السيناريوهات والfixtures

- [ ] تثبيت long-conversation fixtures تحتوي goal وconstraints وdecisions وfiles وtool effects وblockers وpending asks.
- [ ] تثبيت provider matrix تشمل OpenAI-compatible وAnthropic-compatible وCodex Responses وOllama/local behavior عبر adapters deterministic أو fixtures آمنة.
- [ ] تعريف token-pressure fixtures: تحت threshold، عندها، فوقها، huge user message، huge tool result، media، وunknown usage.
- [ ] تعريف lifecycle matrix: manual، proactive auto، tool-loop auto، overflow recovery، summary failure، cancel/shutdown، وrestart.
- [ ] تعريف UI matrix: started/completed/failed، manual/auto، desktop hover، mobile tap، keyboard، reconnect، وhistory hydration.
- [ ] توثيق pass/fail evidence المطلوبة لكل Gate قبل تشغيل verification.

### F0 Exit

- [ ] كل acceptance criterion في Plan 53 له سيناريو واحد على الأقل.
- [ ] fixtures لا تستدعي provider حقيقية للمستخدم ولا تحمل أسرارًا.

## 3. Gate F1 — Engine quality and repeated compaction

- [ ] تشغيل goal-retention fixtures عبر compaction واحدة وثلاث compactions متتالية.
- [ ] مقارنة continuity anchors الحرجة قبل/بعد: goal، pending asks، constraints، decisions، paths/IDs، blockers، وremaining work.
- [ ] إثبات أن stale facts تزال دون حذف unresolved work.
- [ ] إثبات أن tail verbatim وtool pair invariants سليمة عبر providers.
- [ ] إثبات redaction قبل/بعد summarizer وعدم تسريب provider-state blobs.
- [ ] اختبار no-progress وrepair failure وcooldown/breaker paths.

### F1 Exit

- [ ] لا fixture ناجحة تفقد anchor حرجة.
- [ ] unvalidated summary لا تفعل boundary.
- [ ] repeated compaction تبقى تحت target ولا تراكم summaries.

## 4. Gate F2 — Persistence, restart, and concurrency

- [ ] restart بعد started وقبل summary response.
- [ ] restart بعد summary وقبل activation commit.
- [ ] restart بعد commit وقبل live delivery.
- [ ] concurrent manual/auto claims للجلسة نفسها وفصل Session A عن Session B.
- [ ] late result من operation قديمة بعد boundary أحدث.
- [ ] canonical history كاملة بعد repeated compaction وprojection صحيحة من أحدث boundary.
- [ ] soft rewind/fork/pagination coordination scenarios حسب حالة Tasks 47/51/52 وقت التنفيذ.

### F2 Exit

- [ ] كل restart point يعيد terminal state وprojection حتمية.
- [ ] لا تضيع canonical message ولا تتفعل boundary جزئية.
- [ ] claim واحدة فقط تملك mutation لكل session.

## 5. Gate F3 — Runtime, tools, overflow, and queue

- [ ] auto preflight قبل الدور وقبل provider call بعد tool result كبيرة.
- [ ] overflow قبل أول provider event: compaction ثم retry واحدة.
- [ ] overflow بعد reasoning/content/tool state: لا automatic replay.
- [ ] output-cap وpayload/media errors لا تصنف context compaction خطأً.
- [ ] tool result ذات side effect لا يعاد تنفيذها عبر compaction/restart.
- [ ] رسائل متعددة أثناء compaction تحفظ وتنفذ FIFO مرة واحدة.
- [ ] manual failure وauto failure وoverflow failure تحرر أو توقف queue وفق disposition الموثقة دون strand.
- [ ] stop/shutdown/reconnect لا تنتج duplicate lifecycle أو queued work.

### F3 Exit

- [ ] لا duplicate output أو tool effect أو user message.
- [ ] لا session تبقى compacting بعد terminal failure/restart.
- [ ] request التالية بعد success مثبتة تحت الحد المستهدف.

## 6. Gate F4 — Slash command and client parity

- [ ] capabilities تعرض `/compact` فقط ضمن runtime commands ولا تعرض الأوامر الوهمية.
- [ ] `/compact` في index صفر تنفذ command؛ slash في المنتصف لا تفعل ذلك.
- [ ] arguments ترفض محليًا ولا تتحول إلى user message.
- [ ] skills تعمل في البداية والمنتصف والنهاية ولا تتأثر command parser.
- [ ] centered tile تتحول started -> completed/failed بلا duplicate.
- [ ] manual/auto labels والأيقونات والsemantics صحيحة.
- [ ] hover/tap/focus يعرض التفاصيل نفسها ولا يكشف summary.
- [ ] navigation/reconnect/reload يعيد الحالة نفسها من history/cache.
- [ ] narrow mobile layout وlarge text scale لا يسببان overflow.

### F4 Exit

- [ ] live/history parity كاملة لكل lifecycle state.
- [ ] composer grammar لا تخلط command وskill tokens.
- [ ] accessibility والتفاعل متعدد المنصات يجتازان المصفوفة.

## 7. Gate F5 — التحليل، الاختبارات الكاملة، والتوثيق

- [ ] تحليل agent وclient نظيف.
- [ ] suites المركزة لكل مهام 53 ناجحة.
- [ ] full fast agent/client suites ناجحة أو كل failure قديمة موثقة بدليل سابق مستقل.
- [ ] daemon-backed E2E يثبت manual وauto وqueue وrestart وhistory hydration.
- [ ] تحديث Graphify بعد تعديلات الكود والتحقق من عدم بقاء references للمسار القديم.
- [ ] تحديث `AGENTS.md` المالكة وصفحات agent engine/technical/product/QA/MOC.
- [ ] تدقيق relative links والمصطلحات والحالات في الخطة والمهام.
- [ ] تسجيل الأدلة النهائية في الخطة الأم وتحديث الحالة إلى `in_review` فقط بعد إغلاق كل gates.

### F5 Exit / Definition of Done

- [ ] كل معايير القبول الكلية في Plan 53 مغلقة بدليل.
- [ ] compaction تحافظ على هدف الوكيل وتاريخ المستخدم عبر repeated boundaries وrestart.
- [ ] manual وauto وoverflow paths تمر عبر نفس engine/persistence lifecycle.
- [ ] لا توجد slash commands وهمية أو مسار ContextEngine قديم.
- [ ] النظام جاهز لمراجعة بشرية نهائية قبل `complete`.

## 8. الملفات المتوقعة

- agent unit/integration/E2E tests مركزة
- client unit/widget/integration tests مركزة
- fixtures مشتركة للgoal retention والprovider behavior
- `docs/qa_maintenance/context_compaction_qa.md`
- `docs/qa_maintenance/MOC.md`
- `docs/agent_engine/context_compaction_design.md`
- `docs/agent_engine/MOC.md`
- `docs/technical/agent_runtime.md`
- `docs/technical/agent_database_schema.md`
- `docs/technical/communication_protocols.md`
- `docs/product/client_interface.md`
- ملفات `AGENTS.md` المالكة التي عدلتها المهام السابقة
- ملف المهمة والخطة الأم

## 9. سيناريو النجاح النهائي

تبدأ جلسة طويلة بهدف متعدد المراحل وتنفذ أدوات ذات نتائج كبيرة. يحدث auto compaction داخل tool loop، وتصل رسالة جديدة أثناءه فتدخل queue. تنجح summary validated وتظهر centered auto event، ثم تستمر الجولة وتنفذ الرسالة queued. بعد compaction متكررة وrestart تظل الأهداف والقيود والملفات والعمل المتبقي محفوظة، وتعرض timeline التاريخ الكامل والأحداث نفسها. بعد ذلك ينفذ المستخدم `/compact` يدويًا من بداية composer، فتظهر manual lifecycle منفصلة دون إنشاء user message، وتظل details متطابقة بعد reload.

## 10. خارج النطاق

- إضافة features جديدة ظهرت أثناء QA ولا تمنع معايير Plan 53.
- performance tuning غير المدعوم بقياسات.
- arguments أو preview أو focus لأمر `/compact`.
- حذف canonical history أو summary editing UI.

## 11. سجل التقدم

```text
Date:
Gate/status:
Files changed:
Verification:
Findings:
Next gate:
```
