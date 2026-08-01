---
title: "LLM Response State and Reasoning Parity"
description: "توحيد خيارات طلب LLM وحالة المزود والتفكير والاستكمال بين adapters ومساري sync/stream."
status: "complete"
scope: "agent engine"
---

# Task 33: LLM Response State and Reasoning Parity

## 1. المشكلة

عقود المحرك الحالية تنقل النص والأدوات وusage فقط. `thinkingMode` يبقى في مسار
الجلسة ولا يصل إلى adapter، و`reasoning` يجمع بين نص قابل للعرض وحالة بروتوكول
قد يحتاج المزود إلى إعادتها. كما تختلف معالجة sync عن stream: OpenAI-compatible
streaming لا يستخرج reasoning المنظم، وCodex Responses لا يحفظ encrypted
reasoning أو status/phase ولا يميز الرد المكتمل من الرد الذي يحتاج continuation.

يوجد أيضًا تضارب توثيقي: بعض وثائق العميل تشير إلى `previous_response_id`،
بينما التنفيذ الحالي يعيد التاريخ كاملًا ولا يرسل هذا الحقل. القرار المعتمد لهذه
الخطة هو `store: false` مع replay صريح لحالة Responses الضرورية. لا يضاف
`previous_response_id` إلا في خطة لاحقة بعد اختبارات endpoint تثبت الحاجة إليه.

## 2. قرارات التصميم

- يبقى `reasoning` نصًا موجزًا قابلًا للعرض، ولا يحمل blobs أو signatures.
- تحمل `Message.providerState` و`ToolCall.providerState` بيانات المزود opaque
  اللازمة لاستكمال المحادثة، وتبقى namespaced حسب adapter.
- يحمل `AgentResponse.finishReason` سبب النهاية الموحّد بدل استنتاج الاكتمال من
  وجود النص.
- يمرر `LLMRequestOptions` سياق الطلب العابر (`sessionId`, `requestId`,
  `thinkingMode`, `timeout`, `maxOutputTokens`) دون تخزينه داخل adapter.
- adapters stateless. `AgentRunner` يبقى المالك الوحيد للتاريخ ويستبقي
  provider state الذي يعيده adapter في مساري sync وstream.
- خصائص مزود بعينه لا تدخل `BaseOpenAIAdapter`; توضع في codec/policy محلية
  للـadapter المختص.

## 3. النطاق المرحلي

### Gate A — العقود المشتركة

- [x] إضافة `LLMRequestOptions` وتمريره عبر adapters والـrate-limit wrapper.
- [x] إضافة `providerState` إلى `Message` و`ToolCall` مع JSON persistence.
- [x] إضافة `LLMFinishReason` إلى `AgentResponse`.
- [x] تمرير session/request/thinking context من `AgentRunner`.
- [x] دمج provider state عند تجميع streaming response بدل إسقاطه.
- [x] إضافة اختبارات تثبت parity بين sync وstream وحفظ الحالة.
- [x] تحديث وثائق engine وprovider protocol والعقد المحلي.

#### نتيجة Gate A

اكتملت Gate A. أضيف `LLMProviderState` typed بدل map غير مقيدة، وأصبح request id
يبقى حيًا خلال configure/tool loop ويُمسح في `finally`. لا يستهلك أي adapter
خيارات التفكير على wire بعد؛ هذا متعمد حتى Gate B/C. نجح التحليل الكامل ونجحت
السويت السريعة كاملة (`653` اختبارًا ناجحًا واختبار واحد skipped).

### Gate B — OpenAI-compatible parity

- [x] توحيد request builder للمسارين.
- [x] تطبيع reasoning المنظم (`reasoning_content`, `reasoning`,
  `reasoning_details`) وجعل الوسوم النصية fallback فقط.
- [x] استخراج reasoning deltas في streaming دون خلطها بالنص النهائي.
- [x] إعادة provider reasoning state فقط عندما يتطلب protocol ذلك.
- [x] توحيد tool argument parsing وusage/error normalization وإدارة client.
- [x] اختبارات مزودين ونماذج متعددة لمساري sync/stream.

#### نتيجة Gate B

اكتملت Gate B داخل `BaseOpenAIAdapter`. يستخدم sync وstream builder واحدًا،
وتُرسل `reasoning_effort` فقط للنماذج المعروفة بدعم reasoning، مع تحويل
`fast/balanced/deep` إلى `low/medium/high`. يستخدم حد المخرجات
`max_completion_tokens`. تُقرأ حقول reasoning المنظمة بأولوية
`reasoning_content` ثم `reasoning` ثم `reasoning_details`، وتبقى وسوم thought
fallback للنماذج المحلية القديمة.

تحفظ `reasoning_details` في namespace خاص بـChat Completions وتُعاد فقط عند
تطابق issuer مع instance الحالي. يُطبّع `finish_reason` في sync وstream، ويُرفض
JSON غير الصالح لمعاملات الأدوات بدل تنفيذ أداة بمعاملات فارغة. أصبحت ملكية
HTTP client وإغلاقه محددة حتى عند timeout أو error أو إلغاء stream.

نجح تحليل Dart الكامل، ونجحت الاختبارات المركزة (`76` اختبارًا)، ثم السويت
السريعة كاملة (`657` اختبارًا ناجحًا واختبار واحد skipped).

### Gate B.5 — المراجعة المعمارية والتوصيل التأسيسي

أثبتت [مراجعة تصميم تشغيل Codex Responses](../../agent_engine/codex_responses_runtime_design.md)
أن أنواع Gate A/B صحيحة، وحددت متطلبات التوصيل الواجب إنجازها قبل Gate C:

- [x] جمع `finishReason` في sync وstream وعدم إسقاط terminal state.
- [x] حفظ assistant message عندما تحتوي `providerState` فقط.
- [x] اشتقاق issuer من instance مع endpoint/protocol لا UUID وحده.
- [x] إضافة مسار صريح لمسح provider state يدعم kill switch.
- [x] اختبارات reasoning-only بلا summary وstate-only عبر persistence/restart.

#### نتيجة Gate B.5

اكتملت التوصيلات التأسيسية قبل البدء في Codex Responses. أصبح
`LLMFinishReason` نموذجًا مشتركًا بين `AgentResponse` و`Message`، ويثبّت
`AgentRunner` السبب النهائي داخل assistant history في sync وstream. الرسائل
التي تحمل provider state فقط، أو terminal reason فقط، لم تعد تُسقط، ويصبح وجود
tool calls الفعلي هو الحقيقة البنيوية لتنفيذ الأدوات مع بقاء `isToolCall`
للتوافق على حدود adapter.

يشتق `BaseOpenAIAdapter` issuer من provider instance والبروتوكول وbase URL
المطبّع، لذلك لا يعيد reasoning state بعد تغيير endpoint على instance نفسها.
أضيف `clearProviderState` إلى `Message.copyWith` لمسح صريح بلا sentinel داخل
البيانات. أثبتت الاختبارات حفظ state-only وterminal reason بعد إنشاء runner
جديد لنفس الجلسة في المسار المتزامن، وتجميعها في المسار المتدفق.

نجح تحليل Dart بلا ملاحظات، ونجحت السويت السريعة كاملة (`660` اختبارًا ناجحًا
واختبار واحد skipped)، كما نجحت اختبارات تكامل البوابة وإعادة التشغيل الستة
بالتتابع.

### Gate C — Codex Responses parity

- [x] فصل request builder وresponse normalizer وSSE accumulator.
- [x] دعم encrypted reasoning replay مع issuer guard وبنية المسح اللازمة للـkill switch.
- [x] حفظ assistant message items و`phase` و`status` الآمنة.
- [x] preflight صارم، وإزالة reasoning IDs من wire عند `store: false` مع dedup محلي.
- [x] دعم argument deltas وterminal response events وusage والأخطاء النهائية.
- [x] تصنيف reasoning-only/commentary/tool-leak كـ`incomplete` عند الحاجة.
- [x] IDs حتمية للأدوات وحفظ response item IDs وحماية prompt-cache continuity.
- [x] توحيد sync وstream عبر normalizer نهائي واحد.

#### نتيجة Gate C

أصبح `CodexResponsesAdapter` طبقة نقل stateless، ويملك
`CodexResponsesCodec` بناء الطلب وpreflight والتطبيع النهائي، بينما يملك
`CodexResponsesSseAccumulator` تجميع typed SSE events. يمر المساران إلى
normalizer واحد، وتُحفظ encrypted reasoning وعناصر assistant الآمنة منفصلة عن
النص المرئي مع issuer guard وحذف reasoning IDs من wire.

يدعم التنفيذ كل text parts وreasoning summaries وfunction/custom tool calls
وargument deltas وusage والحالات والأخطاء النهائية. call IDs البديلة حتمية،
وتُحفظ response item IDs داخل `ToolCall.providerState`. تُرك التنفيذ الفعلي
لإعادة المحاولة ومسح state عند `invalid_encrypted_content` إلى Gate D لأنه
قرار orchestration وليس مسؤولية codec، ثم اكتمل هناك عبر fallback محدود ومحفوظ.

نجح تحليل Dart بلا ملاحظات، ونجحت الاختبارات المركزة (`89` اختبارًا)، ثم
السويت السريعة كاملة (`666` اختبارًا ناجحًا واختبار واحد skipped). كما نجحت
اختبارات تكامل البوابة وإعادة التشغيل الستة بالتتابع.

### Gate D — continuation والتوافق التشغيلي

- [x] continuation محدود للردود `incomplete` مستقل عن network retry.
- [x] fallback مرة واحدة لـ`invalid_encrypted_content` يمسح replay state فقط عند إرساله فعليًا.
- [x] اختبارات tool loop وrestart/persistence وتبديل المزود.
- [x] سياسات xAI/Codex الخاصة داخل provider policies فقط.
- [x] حذف أي توثيق قديم يناقض الاستراتيجية المنفذة.

#### نتيجة Gate D

أضيف منسق خاص بالدور يسمح بثلاث continuations دلالية بعد الرد غير المكتمل، ولا
يشارك عداده مع network/runtime recovery. يحفظ runner كل رد قبل الاستكمال ويعيد
الحالة عبر history في sync وstream، ويعطي steering الأولوية، ويبقي آخر رد
`incomplete` إذا انتهت الميزانية.

يكتشف adapter رفض encrypted reasoning فقط عندما يثبت الطلب أنه أعاد blob مشفرًا.
يمسح fallback لمرة واحدة `reasoning_items` للـnamespace والissuer المطابقين،
ويحفظ المسح قبل retry مع إبقاء `message_items` وحالات endpoints الأخرى. أضيفت
policy مستقلة لفروق Responses endpoints، ومنها تعقيم slash enums لـxAI دون
تغيير BaseOpenAIAdapter.

تغطي الاختبارات sync وstream وحد continuation وtool loop والمحاولة الواحدة
وحفظ المسح عبر restart وعدم مسح حالة issuer مختلف.

نجح تحليل Dart بلا ملاحظات، ونجحت الاختبارات المركزة (`66` اختبارًا)، ثم السويت
السريعة كاملة (`676` اختبارًا ناجحًا واختبار واحد skipped). كما نجحت اختبارات
تكامل البوابة وإعادة التشغيل الستة بالتتابع.

### Gate E — تصحيح نتائج التشغيل الفعلي

- [x] بث reasoning summaries كتحديثات تفكير مستقلة أثناء tool loop.
- [x] منع reasoning المرئي من الاختلاط بالنص النهائي المحفوظ.
- [x] تصنيف 503 الخاص بانقطاع upstream كخطأ شبكة لا rate limit.
- [x] اختبارات بروتوكول العرض ومسار retry والتصنيف.
- [x] تحديث عقود engine والواجهات وبروتوكول المزود.

#### نتيجة Gate E

أثبتت request dumps أن endpoint كان يرسل reasoning summary في كل tool turn،
بينما commentary المرئي كان فارغًا. كان adapter يلتقط summary لكن runner لا
يمرره إلى الواجهة. أضيف callback مستقل لتحديثات reasoning، وتحوله طبقة الواجهات
إلى `thought_stream` دون إضافته إلى النص النهائي. يعمل المسار أيضًا بعد استئناف
permission-gated tool call.

كان مصنف الأخطاء يعتبر أي 503 يذكر upstream أو gateway حد استخدام. أصبح انقطاع
الاتصال، بما فيه `upstream connect error` و`disconnect/reset` و`remote connection
failure`، خطأ شبكة. لا يصنف 5xx كـ`upstreamRateLimit` إلا بدليل throttling صريح
أو reset موثوق.

نجح تحليل Dart بلا ملاحظات، ونجحت الاختبارات المركزة (`159` اختبارًا)، ثم السويت
السريعة كاملة (`679` اختبارًا ناجحًا واختبار واحد skipped). كما نجحت اختبارات
تكامل البوابة وإعادة التشغيل الستة بالتتابع.

### Gate F — استعادة انقطاع upstream قبل بداية stream

- [x] ثلاث محاولات إجمالية لأخطاء الشبكة العابرة قبل أول stream event.
- [x] backoff قصير متدرج مع jitter واتصال HTTP جديد لكل محاولة.
- [x] منع retry الشفاف بعد وصول reasoning أو metadata أو tool/content event.
- [x] اختبارات عدد المحاولات وحد الأمان بعد بدء stream.
- [x] إعادة reasoning المحفوظ كأحداث `thought` عند فتح سجل المحادثة.
- [x] توثيق النطاق الأكبر لانقطاع stream الجزئي كمهمة مستقلة.

المهمة الأكبر مصممة في
[Task 34: Partial Stream Recovery and Delivery Safety](34-partial-stream-recovery-and-delivery-safety.md)
ولا تدخل في نطاق Gate F.

#### نتيجة Gate F

أصبح `networkError` قبل أول حدث يملك محاولتين إضافيتين بحد أقصى ثلاث محاولات
إجمالية. تستخدم خدمة الاستعادة backoff أسيًا قصيرًا مع jitter، وينشئ نقل Codex
عميل HTTP جديدًا لكل محاولة. يغلق وصول أي استجابة من المزود نافذة retry الشفاف،
حتى لو كانت reasoning أو metadata بلا content، لمنع تكرار مخرجات مرئية أو حالة
أداة.

أثبت فحص مسار history أن `Message.reasoning` كان محفوظًا في SQLite، لكن بناء
`session_history` كان يتجاهله. أصبح reasoning المحفوظ يعود كحدث `thought` قبل
الأدوات أو الإجابة النهائية، مع منع تكراره إذا طابق content. تغطي الاختبارات
القراءة من قاعدة البيانات وإعادة بناء التسلسل canonical.

نجح تحليل Dart بلا ملاحظات، ونجحت الاختبارات المركزة (`135` اختبارًا)، ثم السويت
السريعة كاملة (`682` اختبارًا ناجحًا واختبار واحد skipped). كما نجحت اختبارات
تكامل البوابة الستة بالتتابع.

## 4. الملفات المتوقعة

- `sanad-agent/agent/lib/engine/adapters/llm_adapter.dart`
- `sanad-agent/agent/lib/engine/adapters/llm_request_options.dart`
- `sanad-agent/agent/lib/core/models/message.dart`
- `sanad-agent/agent/lib/core/models/tool_call.dart`
- `sanad-agent/agent/lib/core/models/agent_response.dart`
- `sanad-agent/agent/lib/engine/agent_runner.dart`
- `sanad-agent/agent/lib/engine/runtime/turn_route_state.dart`
- adapters الإنتاجية والاختبارات التي تنفذ `LLMAdapter`.

## 5. معايير قبول Gate A

- [x] كل production adapter يقبل options دون الاحتفاظ بها كحالة داخلية.
- [x] `thinkingMode` الفعال يصل إلى adapter في كل model call داخل الدور.
- [x] `providerState` ينجو من JSON round-trip ومن تجميع streaming.
- [x] `finishReason` ينجو من JSON round-trip وله default متوافق مع التاريخ القديم،
  ويُحفظ على assistant history لا على الاستجابة العابرة فقط.
- [x] wrapper لا يسقط options عند التفويض.
- [x] التحليل والاختبارات المركزة ناجحة.
- [x] لا يتغير wire payload لأي مزود في Gate A؛ استهلاك options يبدأ في Gates
  اللاحقة.

## 6. خارج Gate A

- تغيير payload reasoning لأي مزود.
- تنفيذ Codex encrypted replay أو SSE state machine.
- continuation retries.
- دعم multimodal content.
- ترحيل تاريخ قديم أو تغيير بروتوكول العميل/البوابة.
