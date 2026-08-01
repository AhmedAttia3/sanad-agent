---
title: "Task 40: Live Per-LLM Context Usage Indicator"
description: "تخزين usage لكل استدعاء LLM، وتمرير أحدث snapshot مع أحداث المحادثة الحالية، وعرض مؤشر حي لامتلاء نافذة السياق بجوار النموذج."
status: "in_progress"
priority: "medium"
parent_dependency: "docs/plans/tasks/31-authoritative-session-state-and-auto-failover-ux.md"
---

# Task 40: Live Per-LLM Context Usage Indicator

## 1. الحالة والنطاق

- الحالة: قيد التنفيذ؛ نُفذت projection الأحدث لكل جلسة، نقلها مع tool/final
  events، استعادتها من التاريخ، ومؤشر Flutter مع Cached input.
- النطاق: LLM adapters + agent metrics/persistence + canonical conversation
  events + Flutter per-session state + composer UX.
- هذه مهمة مستقلة عن حالة execution/recovery في المهمة 31.
- لا يضاف canonical event مستقل افتراضيًا؛ توسع أحداث المحادثة الموجودة بحقل
  usage موحد عندما تتوفر snapshot جديدة مؤكدة.

## 2. المشكلة

يخزن agent حاليًا usage الأخيرة ويضيفها إلى metadata الخاصة بآخر assistant
message، ثم يرسلها غالبًا مع `final_answer`. تعرض الواجهة هذه المعلومات تحت
الرسالة النهائية عبر `EventMetadataFormatter`، ولذلك لا يرى المستخدم استهلاك
نافذة السياق إلا بعد اكتمال الجولة كلها.

الجولة الواحدة قد تحتوي عدة استدعاءات LLM تفصلها tool calls. كل استدعاء قد يعيد
usage جديدة، لكن tool-call response أو reasoning response لا يحدثان مؤشرًا حيًا
في الواجهة. نتيجة ذلك أن المستخدم لا يرى اقتراب المحادثة من حد نافذة السياق
أثناء العمل الطويل.

## 3. الهدف

1. حفظ usage مستقلة لكل استدعاء LLM، بما في ذلك الاستجابات التي تنتهي بأدوات أو
   reasoning فقط، لا `final_answer` وحدها.
2. تعميم آلية usage الحالية على أحداث `thought` و`tool_use` و`final_answer`
   المرتبطة باستجابة LLM نفسها.
3. الاحتفاظ بأحدث context usage snapshot لكل جلسة وتحديثها أثناء tool loop بعد
   كل استجابة LLM مؤكدة.
4. عرض circular indicator بجوار اسم النموذج في composer.
5. عرض tooltip على hover أو tap بتفاصيل الاستهلاك، بما فيها cached tokens عند
   إبلاغ المزود عنها.
6. استعادة آخر snapshot صحيحة بعد navigation أو reconnect أو restart، وعرض آخر
   usage متاحة فور جلب المحادثة من التاريخ.
7. منع جمع input tokens عبر tool rounds؛ امتلاء السياق يعتمد على أحدث prompt
   أرسله provider، لا مجموع تكلفة الجولة.

## 4. تعريف الاستهلاك الصحيح

### 4.1 Context occupancy

القيمة الأساسية للمؤشر هي:

```text
used_context_tokens = latest provider-reported input/prompt tokens
context_window_tokens = context window of the exact active model
usage_percent = used_context_tokens / context_window_tokens * 100
```

القواعد:

- لا يستخدم `accumulatedUsage.total_tokens` لحساب الامتلاء؛ جمع كل tool round
  يضاعف نفس سياق المحادثة ويعطي نسبة خاطئة.
- لا يستخدم output tokens وحدها كـcontext occupancy.
- يعرض كل حقل كما ورد في أحدث usage من المزود بعد توحيد اسم المفتاح فقط؛ لا
  يضاف إلى قيمة أخرى، ولا تجمع snapshots متعددة، ولا يستنتج total مفقود.
- إذا كان المزود يعيد اسمًا عامًا مثل `cached_tokens` فيطبع إلى
  `cache_read_tokens`، ولا تعرض الواجهة صف Cached input عندما لا توجد قيمة
  مؤكدة. لا تعرض الواجهة Cache write.
- تبقى آخر قيمة provider-confirmed معروضة أثناء تنفيذ الأداة. tool result لا
  ينتج usage حقيقية جديدة؛ تحدث القيمة عند استدعاء LLM التالي.
- لا نخمن عدد tokens لمخرجات الأدوات في هذه المهمة. أي estimated usage مستقبلية
  يجب تمييزها صراحة عن confirmed usage.
- إذا لم يرسل provider input usage أو لم تعرف نافذة النموذج، لا تعرض نسبة مزيفة؛
  يعرض المؤشر حالة unavailable أو يختفي وفق قرار UX في المرحلة 4.
- تقيد النسبة المرئية إلى `0..100`، لكن تحفظ القيم الخام للتشخيص.

### 4.2 Cost usage مقابل context usage

يحفظ العقد نوعين دون خلط:

- `invocation_usage`: input/output/total/cache/reasoning الخاصة باستدعاء LLM واحد.
- `context_usage`: أحدث input tokens مؤكدة مقارنة بنافذة النموذج، وهي التي تغذي
  المؤشر.

## 5. نموذج البيانات

ينشأ نموذج semantic موحد، مثل `LlmUsageSnapshot`:

```text
session_id
run_id
request_id
invocation_id
invocation_sequence
provider_instance_id
model_id
input_tokens
output_tokens
total_tokens
cache_read_tokens
cache_write_tokens
reasoning_tokens
context_window_tokens
usage_percent
usage_revision
observed_at
```

القواعد:

- `invocation_id` ثابت للاستدعاء الواحد حتى إذا نتجت عنه عدة أحداث `tool_use`.
- `invocation_sequence` متزايدة داخل run لتوضيح ترتيب tool rounds.
- `usage_revision` متزايدة داخل الجلسة، وتزيد فقط عند snapshot مؤكدة جديدة.
- normalization من مفاتيح providers المختلفة يحدث في agent مرة واحدة؛ Flutter
  لا يعيد تفسير aliases مثل `prompt_tokens` و`input_tokens`.
- جميع حقول token counts أعداد صحيحة غير سالبة أو `null` عند غيابها.
- `usage_percent` يمكن اشتقاقها في العميل، لكن agent يرسل البسط والمقام؛ لا
  تصبح النسبة وحدها مصدر الحقيقة.

## 6. التخزين الدائم

يحفظ agent مستويين:

1. **Per-invocation history:** تحفظ `invocation_usage` في metadata الخاصة
   بالـassistant response المطابقة لذلك الاستدعاء، بما في ذلك assistant message
   ذات tool calls أو provider state فقط.
2. **Latest session projection:** تحفظ أحدث `context_usage` في session metadata
   أو owner دائم أوضح، حتى يعيد `sessions_list` المؤشر دون تحميل history كاملة.

القواعد:

- لا يقتصر patch على آخر final assistant message.
- يجب ربط usage بالـassistant response الصحيحة عبر `invocation_id/run_id`، لا
  عبر "آخر رسالة" بعد awaits قد تسمح بتغير التاريخ.
- كتابة history usage وتحديث latest projection يجب أن تكون idempotent.
- restart يعيد أحدث confirmed snapshot، ولا يعيد جمع السجلات التاريخية جمعًا
  تراكميًا لحساب context occupancy.
- عند طلب `session_history` يعيد agent أحدث projection المحفوظة. وإذا غابت في
  بيانات قديمة، يختار آخر snapshot مكتملة وصالحة زمنيًا من رسائل المحادثة،
  ويعيدها كـ`context_usage` دون جمع snapshots أو إنشاء revision وهمية.
- ترتيب fallback التاريخي يعتمد أولًا على `usage_revision` ثم `observed_at`، مع
  تجاهل السجلات التالفة أو التي تخص جلسة أخرى.
- لا تحفظ raw provider response أو أسرار داخل usage metadata.

## 7. عقد الأحداث الحالي بعد التوسيع

تضاف إلى payload أحداث المحادثة الحالية قيمة اختيارية:

```text
context_usage: LlmUsageSnapshot
```

### 7.1 الأحداث المؤهلة

- `final_answer`: يحمل snapshot للاستدعاء النهائي عندما تتوفر.
- `tool_use`: يحمل snapshot لاستدعاء LLM الذي قرر استدعاء الأداة.
- `thought` أو آخر `thought_stream` مناسب: يحمل snapshot عندما تنتهي استجابة
  reasoning بلا final text أو tool event آخر مناسب.
- `tool_result`: لا ينشئ revision جديدة لأنه ليس استدعاء LLM. يمكنه حمل آخر
  snapshot نفسها فقط إذا احتاج النقل ذلك، ويجب أن يتعامل العميل معها idempotently.

### 7.2 قواعد النقل

- لا تكرر usage مع كل token chunk.
- إذا ولّد استدعاء واحد عدة `tool_use` events، يمكن أن تحمل snapshot نفسها
  بنفس `usage_revision`; يطبقها العميل مرة واحدة.
- يجب أن يحمل حدث واحد على الأقل من كل استجابة LLM snapshot بعد توفر usage.
- إذا أثبت التنفيذ أن provider يعيد usage بعد آخر event مؤهل ولا يمكن إرفاقها
  بأمان، يوثق العجز أولًا؛ لا ينشأ event جديد إلا بقرار تصميم ومراجعة للعقد.
- local/cloud يحافظان على event identity وusage revision نفسيهما.
- `session_history` يعيد usage لكل رسالة محفوظة وأحدث `context_usage` للجلسة؛
  يجب أن تتضمن الاستجابة هذه القيمة قبل اكتمال hydration كي يظهر المؤشر مباشرة
  عند فتح محادثة من التاريخ، لا بعد وصول حدث حي جديد.
- كل عنصر في `sessions_list` يعيد أحدث `context_usage` عند توفرها.

## 8. Agent implementation

- [x] استخراج normalization الحالية من `MetricsTracker` إلى model/helper typed
      قابلة لإعادة الاستخدام بدل maps غير المنضبطة.
- [x] الاحتفاظ بـ`lastUsage` للاستدعاء الأخير و`accumulatedUsage` للتكلفة، مع
      منع استخدام accumulated value للمؤشر.
- [ ] تعيين `invocation_id`, sequence, وusage revision لكل استدعاء LLM.
- [x] تحديث metrics فور اكتمال كل provider response داخل tool loop.
- [x] حفظ usage على assistant message المطابقة للاستدعاء، لا final message فقط.
- [x] تحديث latest session context projection بعد نجاح الحفظ.
- [ ] تعميم `AgentToCanonical`/response mapping لإضافة `context_usage` إلى
      `tool_use`, `thought`, و`final_answer` المناسبة.
- [x] توحيد OpenAI/Anthropic/Codex/Ollama usage keys في النموذج نفسه، بما فيها
      `cached_tokens`، مع إبقاء كل قيمة مستقلة كما وردت من المزود.
- [x] جعل `session_history` يعيد latest projection، مع fallback إلى آخر snapshot
      تاريخية صالحة للمحادثات القديمة التي لا تملك projection.
- [x] تحديد context window من exact active model metadata؛ لا يستخدم default
      provider model إذا كانت الجولة تملك model override.
- [x] عدم فشل الجولة إذا غابت usage؛ الحقول تبقى nullable والمؤشر لا يكذب.

## 9. Flutter state and mapping

- [x] إضافة model typed باسم `LlmUsageSnapshot` في conversations domain.
- [ ] تحويل `CanonicalEvent.usage` الديناميكية إلى model typed أو mapper مركزي.
- [ ] تخزين أحدث snapshot في خريطة keyed by device/session id وفق عقد المهمة 31.
- [ ] قبول revision أحدث فقط؛ revision مساوية idempotent، والأقدم ترفض.
- [ ] عدم تغيير session B عند وصول usage للجلسة A.
- [ ] hydrate أحدث snapshot من `sessions_list` و`session_history` قبل عرض حالة
      composer النهائية، ومسح snapshot الجلسة السابقة أثناء انتقال history.
- [x] عرض Cached input شرطيًا من النموذج typed دون تفسير provider aliases في
      Flutter، وعدم عرض Cache write.
- [ ] الحفاظ على snapshot أثناء navigation وtransport handoff/reconnect.
- [x] إبقاء metadata الموجودة أسفل الرسالة النهائية متوافقة وعدم تكرار منطق
      formatting في أكثر من widget.

## 10. UX

يضاف circular indicator بجوار اسم النموذج في
`client/lib/features/conversations/presentation/widgets/conversation_input/conversation_input_composer.dart`.

القواعد:

- يعبر progress عن `input_tokens / context_window_tokens` لأحدث snapshot مؤكدة.
- يتحدث بعد كل LLM response داخل tool loop، لا بعد نهاية الجولة فقط.
- hover على desktop وtap على touch يعرضان tooltip/popover.
- النص المرئي إنجليزي وفق عقد UI، بالشكل الأساسي:

```text
Context window:
75% full
194k / 258k tokens used
Cached input: 120k tokens
```

- سطر `Cached input` شرطي: يظهر فقط عندما يرسل المزود قيمة مؤكدة، ولا تظهر قيمة
  صفرية أو `N/A` بدل بيانات غير متوفرة. لا يعرض tooltip قيمة Cache write.
- التفاصيل الموسعة تعرض عند توفرها: input, output, cached input, reasoning,
  model، ووقت آخر تحديث.
- عند فتح محادثة من التاريخ يظهر المؤشر بآخر snapshot متاحة بمجرد اكتمال جلب
  history؛ وإذا لم توجد usage محفوظة يبقى المؤشر unavailable/مخفيًا ولا يعرض
  بيانات المحادثة السابقة التي كانت مفتوحة.
- يستخدم formatter مشترك مع metadata الحالية في `event_tile.dart`.
- يملك المؤشر semantic label وإمكانية استخدام keyboard focus.
- لا يؤدي تحديث usage إلى إعادة بناء timeline كاملة أو فقدان draft input.
- تحدد ألوان التحذير مركزيًا، مع حالات طبيعية/مرتفعة/حرجة، دون hardcoded magic
  thresholds داخل widget.

## 11. الاختبارات

### Agent

- [x] استجابة final عادية تحفظ وترسل usage واحدة.
- [x] tool-call response تحفظ usage قبل تشغيل الأداة وترسلها مع `tool_use`.
- [ ] عدة tool rounds تنتج revisions متزايدة دون جمع input tokens للمؤشر.
- [ ] reasoning-only response لا تفقد usage.
- [ ] عدة tool calls من invocation واحدة تحمل identity/revision نفسها.
- [x] provider بلا usage لا ينتج نسبة وهمية ولا يفشل الجولة.
- [ ] exact model override يستخدم context window الصحيحة.
- [x] history وrestart يعيدان per-invocation records وأحدث projection.
- [x] history لمحادثة قديمة بلا projection يختار آخر snapshot صالحة فقط.
- [x] cached tokens تطبع إلى Cached input كما وردت، دون جمعها أو تعديلها.

### Flutter

- [ ] event usage تحدث الجلسة المطابقة فقط.
- [ ] stale revision لا تتراجع بالمؤشر.
- [x] tool-use usage تحدث المؤشر قبل final answer.
- [ ] navigation بين جلستين تحفظ مؤشرًا مستقلًا لكل جلسة.
- [ ] reconnect/history لا تسبب flicker أو duplication، وفتح محادثة تاريخية
      يعرض آخر usage لها لا usage الجلسة السابقة.
- [x] tooltip يعرض Cached input عند توفرها، يخفيها عند غيابها، ولا يعرض Cache write.
- [x] tooltip يعرض المثال المطلوب والقيم الموسعة.
- [ ] hover وtap وkeyboard accessibility تعمل.
- [x] تحديث المؤشر لا يعيد بناء timeline أو يمسح draft.

## 12. الملفات المتوقعة

### Agent

- `agent/lib/engine/metrics_tracker.dart`
- `agent/lib/engine/agent_runner.dart`
- `agent/lib/core/models/agent_response.dart`
- `agent/lib/core/models/message.dart`
- `agent/lib/interfaces/models/gateway_event.dart`
- `agent/lib/interfaces/platforms/sanad_gateway/translators/agent_to_canonical.dart`
- `agent/lib/interfaces/platforms/sanad_gateway/handlers/session_query_handler.dart`
- `agent/lib/interfaces/session_payload_builder.dart`
- model/helper typed جديد في owner يحدد أثناء Gate التصميم.

### Flutter

- `client/lib/features/conversations/domain/models/canonical_event.dart`
- `client/lib/features/conversations/domain/models/session.dart`
- `client/lib/features/conversations/data/mappers/unified_device_mapper.dart`
- `client/lib/features/conversations/domain/stores/device_conversation_store.dart`
- `client/lib/features/conversations/presentation/bloc/session_messages_cubit.dart`
- `client/lib/features/conversations/presentation/widgets/conversation_input/conversation_input_composer.dart`
- `client/lib/features/conversations/presentation/widgets/event_tile.dart`
- `client/lib/utils/format_utils.dart`

## 13. التوثيق المطلوب

- [x] تحديث `docs/technical/communication_protocols.md` بعقد `context_usage`.
- [x] تحديث `docs/technical/agent_runtime.md` بفرق invocation usage عن accumulated
      cost usage.
- [x] لا يلزم تحديث `docs/technical/client_conversation_cache_schema.md` لأن العميل
      لا يحفظ latest snapshot في ConversationCacheStore حاليًا.
- [x] إضافة QA matrix للمؤشر وtool loops وrestart/reconnect.
- [x] تعديل `AGENTS.md` فقط إذا تغير قانون تشغيلي دائم، لا لتخزين payload schema.

## 14. معايير القبول

- [ ] يرى المستخدم مؤشر context قبل انتهاء الجولة إذا أكمل LLM استدعاءً أدى إلى
      tool use أو reasoning intermediate.
- [x] المؤشر يعكس أحدث input/prompt usage مؤكدة، لا مجموع tool rounds.
- [x] tooltip يعرض النسبة والبسط والمقام بصورة صحيحة، ويعرض cached tokens
      المتاحة كما وردت من المزود دون جمعها مع أي قيمة أخرى.
- [x] فتح محادثة من التاريخ يعرض فورًا آخر usage مؤكدة تخصها؛ وعند غياب usage لا
      تتسرب قيمة المحادثة المفتوحة سابقًا.
- [x] كل LLM invocation ذات usage تحتفظ بسجلها داخل الرسالة المطابقة.
- [x] `final_answer` تستمر في عرض metadata الحالية دون regression.
- [ ] كل جلسة تحتفظ بمؤشر مستقل ولا تؤثر في الجلسات الأخرى أو الجهاز كله.
- [x] reconnect/restart يعيدان أحدث snapshot دون انتظار final answer جديدة.
- [ ] الأحداث القديمة أو المكررة عبر local/cloud لا تعيد المؤشر إلى الخلف.
- [x] لا يضاف event مستقل ما دام event حالي يضمن نقل usage بعد كل استجابة LLM.

## 15. خارج النطاق

- حساب تكلفة مالية حسب أسعار provider.
- تقدير tokens لمخرجات الأدوات قبل استدعاء LLM التالي.
- ضغط/تلخيص السياق تلقائيًا عند بلوغ threshold.
- تغيير سياسة context truncation أو provider max-output limits.
- global usage dashboard عبر كل الأجهزة والجلسات.
