---
title: "Conversation Event Segmentation, History Parity, and Failover Recovery"
description: "فصل هوية ملكية الجولة عن هوية مقاطع التفكير والأدوات، واستعادة تطابق البث الحي والتاريخ، ومنع auto-failover من ترك الجلسة عالقة أو غير قابلة للفتح."
status: "completed"
priority: "high"
scope: "agent runtime, Sanad gateway protocol, Flutter conversation state, history hydration, and recovery QA"
depends_on: "Tasks 31, 33, 35, and 36"
research_input: "temp/analysis_report.md and Hermes Agent structured-streaming segment boundaries"
---

# Task 42: Conversation Event Segmentation, History Parity, and Failover Recovery

## 1. الهدف

استعادة العرض الكامل والمتسلسل للمحادثة في البث الحي وبعد إعادة التحميل، مع
الحفاظ على ملكية التنفيذ authoritative التي أضافتها Task 31. يجب أن يرى العميل
التسلسل الحقيقي بدل دمج كل خطوات الجولة في عنصر تفكير واحد وعنصر أداة واحد:

```text
thought segment A
tool call A
thought segment B
tool call B
thought segment C
final answer
```

تشمل المهمة أيضًا إغلاق فجوتين ظهرتا في نفس سيناريو auto-failover: بقاء work
item في `waiting` بعد نجاح المزود البديل، وفشل تحميل التاريخ عندما يحتوي على
حدث route transition بمعرّف نصي.

## 2. إعادة الإنتاج والأدلة

الجلسة التشخيصية `69891d58-e920-491a-ae8e-60c9a40dd527` أثبتت الآتي:

- قاعدة البيانات تحتوي رسائل assistant متعددة، واستدعاءات أدوات متعددة، وثماني
  رسائل assistant ذات reasoning غير فارغ؛ فقدان العناصر ليس فقدان بيانات.
- رسائل نموذج متعددة داخل الجولة نفسها تحمل `run_id` واحدًا، رغم امتلاك كل
  `ToolCall` لمعرف مستقل.
- البث الحي يرسل reasoning وtool use/result بهوية `ActiveRun.runId` نفسها، فينتج
  العميل `thinking_<run_id>` و`tool_<run_id>` ويطبّق upsert فوق العنصر السابق.
- عند وصول final answer يحذف `ConversationState` كل thinking يحمل `run_id`
  نفسه، فيختفي أيضًا المحتوى المرحلي السابق.
- auto-failover نقل durable work item إلى `waiting` عند HTTP 429، ثم واصل
  التنفيذ بالمزود البديل دون claim دائمة إلى `resuming`. نجح البث الجزئي، لكن
  terminal commit رفض الإغلاق لأن recovery ما زالت تملك الحالة.
- `get_session_history` أعاد البيانات، لكنه أضاف `session_route_transition`
  بمعرف حدث نصي. مسار client الحديث حوّله بنجاح، ثم أعاد تمرير كل الصفوف عبر
  `ChatMessage` القديم ذي `int? id`، فتحول النجاح إلى خطأ تحميل عام.
- `SessionMessagesCubit` خزّن نص استثناء history داخليًا دون تسجيل تشخيص واضح،
  لذلك أظهر لوج socket وصول التاريخ ولم يوضح سبب شاشة Retry.

## 3. قيود لا يجوز كسرها

1. يظل `run_id` هو هوية ملكية الجولة immutable، ويظل مرتبطًا بـgeneration وwork
   item وفق Tasks 31 و35 و36.
2. لا يسمح بأي انتقال مباشر `waiting -> completed` أو `blocked -> completed`.
3. لا يبث final answer إلا بعد terminal commit ناجحة للمالك الحالي.
4. لا تستبدل هوية العرض حواجز الملكية، ولا تستخدم UI IDs لاتخاذ قرار تنفيذ أو
   stop أو steer أو queue.
5. تظل `tool_use` و`tool_result` للأداة نفسها قابلين للدمج، لكن لا تندمج أدوات
   مختلفة داخل الجولة.
6. تظل أجزاء streaming للمقطع نفسه قابلة للدمج، لكن لا تندمج مقاطع نموذج
   مختلفة تفصل بينها أداة أو segment boundary.
7. تكون event IDs في البروتوكول opaque strings؛ لا يفترض العميل أنها أرقام.
8. يطابق التاريخ البث الحي في ترتيب العناصر وهوياتها ومعناها، ولا يبني نموذج
   عرض بديلًا من صفوف legacy بعد اكتمال canonical hydration.

## 4. عقد الهوية والفواصل المستهدف

### 4.1 هوية الملكية

- `run_id`: ثابت طوال active run، ويستخدم للملكية، stale-callback rejection،
  terminal commit، recovery، stop، steer، وqueue correlation.
- `generation`: الجيل المتزايد لنفس الجلسة، ولا يدخل في هوية فقاعة العرض.
- `work_item_id`: المالك الدائم للعمل ولا يستخدم لدمج عناصر المحادثة.

### 4.2 هوية العرض

- `model_step_id`: معرف ثابت وفريد لكل استدعاء نموذج أو مقطع assistant داخل
  الجولة. تستخدم كل reasoning deltas والرسالة المحفوظة الناتجة من الاستدعاء
  نفسه هذا المعرف.
- `tool_call_id`: معرف `ToolCall.id` الموجود. يستخدمه tool use/result المقابلان
  معًا، ولا يولد executor بديلًا جديدًا له.
- `event_id`: معرف الحدث canonical، ويقبل النصوص والأرقام القديمة عند القراءة
  مع تطبيعها إلى string داخل العميل.

لا يجوز استبدال `run_id` بـ`model_step_id` أو `tool_call_id`. تحمل الأحداث
هوية الملكية وهوية العرض معًا، ويختار كل مستهلك الحقل المناسب لمسؤوليته.

### 4.3 Segment lifecycle

- يبدأ model step جديد قبل كل استدعاء LLM جديد داخل الجولة.
- تتراكم deltas داخل المقطع نفسه فقط.
- بدء tool call يغلق مقطع assistant السابق ويمنع النص التالي من الكتابة فوقه.
- انتهاء أداة لا يفتح مقطعًا وهميًا؛ أول delta أو رسالة من استدعاء النموذج التالي
  تبدأ المقطع التالي.
- الاستكمال الدلالي لنفس استدعاء النموذج يحدد صراحة هل يحافظ على
  `model_step_id` أو يبدأ مقطعًا جديدًا؛ لا يعتمد القرار على timestamp.
- steer الذي يبدأ استدعاء نموذج جديد ينشئ model step جديدًا مع بقاء `run_id`
  المالك حسب عقد Task 36.
- final answer يغلق model step النهائي. يحذف العميل فقط فقاعة البث المؤقتة
  المطابقة لنفس `model_step_id` إذا كان final payload هو النسخة المكتملة منها،
  ولا يحذف المقاطع المكتملة السابقة في الجولة.

## 5. النطاق المرحلي

### Gate A — Protocol identity contract

- [x] تثبيت أسماء الحقول canonical واختيار `model_step_id` كاسم واحد في agent
      والعميل والتاريخ والوثائق، دون aliases جديدة غير ضرورية.
- [x] إضافة `model_step_id` و`tool_call_id` إلى payloads المعنية مع إبقاء
      `run_id` authoritative.
- [x] توثيق قواعد إنشاء model step والحفاظ عليه أو تغييره في retry، semantic
      continuation، steer، resume، وauto-failover.
- [x] جعل event ID نوعًا نصيًا opaque على حدود البروتوكول والعميل.
- [x] تحديد ترتيب canonical ثابت يسمح بتطابق live/history دون الاعتماد على
      hash أو وقت محلي لتكوين الهوية.

### Gate B — Agent model-step and tool emission

- [x] فصل `currentModelRunId` التاريخي إلى مفهوم model-step واضح بدل نسخه من
      `_authoritativeRunId` في `beginAuthoritativeRun`.
- [x] توليد model step جديد لكل LLM iteration المطلوبة بالعقد وحفظه في metadata
      للرسالة قبل كتابة session history.
- [x] تمرير model step الحالي مع reasoning deltas وassistant chunks والرسالة
      النهائية الخاصة بالمقطع.
- [x] تمرير `toolRunId` الحالي كـ`tool_call_id` في tool use/result بدل تجاهله
      وتحويله إلى `owner.runId`.
- [x] إبقاء `ownsRun(owner)` بوابة إلزامية قبل كل بث أو حفظ، بحيث لا يعيد فصل
      هويات العرض مشكلة stale callbacks.
- [x] حفظ checkpoint اللازمة لاستعادة model step بأمان عند restart أو resume
      دون إعادة استخدام هوية مقطع سابق لعمل جديد.

### Gate C — Auto-failover durable claim

- [x] إضافة owner ذرية واحدة لانتقال auto-failover من waiting إلى resuming قبل
      استمرار نفس runner على المزود البديل.
- [x] تحقق owner من `session_id + work_item_id + run_id + generation` ومن أن
      notice والمسار المراد استكماله يخصان الجولة نفسها.
- [x] تنفيذ route mutation وqueue rewrite وdurable resume claim بترتيب يمنع
      عرض `Resuming` قبل امتلاك الحالة فعليًا.
- [x] إذا فشل claim، لا يواصل AgentRunner الطلب البديل ولا يبث final؛ تبقى
      recovery ظاهرة وقابلة لـRetry أو Stop.
- [x] نجاح المزود البديل ينتهي فقط عبر `resuming -> completed` وterminal commit
      القائمة، دون أي إصلاح قسري من waiting إلى completed.
- [x] إنهاء notice وsnapshot بعد commit الناجحة، بحيث لا تبقى أيقونة الساعة بعد
      final answer أو restart.

### Gate D — Canonical translation and history reconstruction

- [x] تمرير `model_step_id` و`tool_call_id` في `agent_to_canonical.dart` دون
      تغيير معنى `run_id`.
- [x] بناء history thought rows من model step المحفوظ، لا من active-run ID
      المشترك وحده.
- [x] بناء history tool rows من `ToolCall.id` وربط tool result بالأداة المطابقة
      عبر backward linkage الحالي.
- [x] الحفاظ على ترتيب thought/tool/final الحقيقي عند إعادة البناء من SQLite.
- [x] دعم الصفوف القديمة التي لا تحمل model step عبر fallback حتمي مبني على
      message row/segment order، دون دمج كل الجولة في عنصر واحد.
- [x] إبقاء `session_route_transition` informational event ضمن التاريخ مع
      `event_id` النصي ومن دون تمريره عبر نموذج legacy يفرض integer ID.

### Gate E — Flutter mapping and conversation state

- [x] استخدام `model_step_id` لهوية thinking، و`tool_call_id` لهوية tool، مع
      fallback legacy محدود ومتوافق.
- [x] دمج deltas للمقطع نفسه فقط، ودمج use/result للأداة نفسها فقط.
- [x] تعديل final-answer cleanup ليستهدف streaming projection للمقطع النهائي
      المطابق، ولا يحذف thought segments السابقة.
- [x] ضمان أن `setHistory` ينتج التسلسل نفسه الذي ينتجه تطبيق الأحداث live
      بالترتيب نفسه.
- [x] إزالة إعادة التحويل غير الضرورية لكل history row عبر `ChatMessage` القديم
      أو تحديث عقد repository إلى نتيجة canonical لا تعيد فرض integer IDs.
- [x] تسجيل history hydration failure بصورة redacted تحمل session/request
      correlation والمرحلة التي فشلت، مع إبقاء رسالة UI موجزة.
- [x] نجاح Retry بعد خطأ مؤقت، وعدم تحويل payload صالح إلى شاشة خطأ بعد تحديث
      conversation store جزئيًا.

### Gate F — Legacy stuck-session recovery

- [x] تعريف تدقيق startup للجلسات القديمة العالقة في waiting/blocked بعد غياب
      recovery owner قابلة للاستكمال.
- [x] عدم استنتاج completed لمجرد وجود assistant content؛ المحتوى الجزئي ليس
      terminal proof.
- [x] تحويل الحالة غير القابلة للإثبات إلى blocked recovery مرئية أو إتاحتها
      لـStop الآمن، بدل إبقائها waiting صامتة أو إصلاحها إلى completed.
- [x] إثبات أن Stop لجلسة legacy يلغي work item ويعيد execution snapshot إلى
      idle دون حذف التاريخ المحفوظ.
- [x] توفير fixture منزوعة البيانات الحساسة تمثل بنية الجلسة التشخيصية، بدل
      ربط الاختبارات بقاعدة المستخدم المحلية.

### Gate G — Regression and parity verification

- [x] اختبار Agent لجولة واحدة تحتوي ثلاث model steps وأداتين، مع run ID ثابت
      وmodel-step IDs مستقلة وtool-call IDs مستقلة.
- [x] اختبار أن tool use/result للأداة نفسها يشتركان في الهوية، وأن الأداة
      التالية لا تكتب فوق السابقة.
- [x] اختبار reasoning deltas داخل model step واحد تتجمع، بينما model step
      التالي ينشئ thought جديدًا.
- [x] اختبار history reconstruction للتسلسل الكامل ومقارنته دلاليًا مع live
      canonical events لنفس fixture.
- [x] اختبار final answer يحذف projection المؤقتة المطابقة فقط ويحافظ على
      المقاطع السابقة.
- [x] اختبار history يحوي `session_route_transition` بمعرف UUID نصي ويُحمّل
      بلا TypeError أو شاشة Retry.
- [x] اختبار 429 قبل بدء stream مع auto-failover ناجح: الحالات المسموحة هي
      `running -> waiting -> resuming -> completed`، ويصدر final واحد وتصبح
      snapshot idle.
- [x] اختبار فشل durable resume claim: لا استمرار على المزود البديل، ولا final
      كاذب، وتبقى recovery قابلة للتفاعل.
- [x] اختبار restart بعد auto-failover ناجح لا يعيد أيقونة waiting.
- [x] اختبار fixture legacy العالقة يثبت blocked/Stop recovery الآمنة دون
      `waiting -> completed` مباشر.
- [x] اختبار Flutter للتسلسل المرئي الكامل وعدم انهياره إلى thought/tool فقط.

### Gate H — Documentation and runtime contracts

- [x] تحديث `docs/technical/agent_runtime.md` بهويات الملكية والعرض وحدودها.
- [x] تحديث `docs/technical/communication_protocols.md` بعقد segment lifecycle
      وحقول live/history canonical.
- [x] تحديث `docs/technical/provider_protocol.md` بترتيب auto-failover durable
      claim وroute mutation وterminal completion.
- [x] تحديث `docs/qa_maintenance/plan30_runtime_recovery_matrix.md` بسيناريو
      429 الناجح والجلسة legacy العالقة.
- [x] إضافة صفحة QA مركزة لتطابق conversation live/history وتسلسل المقاطع، أو
      توسيع أقرب صفحة قائمة إذا كانت تملك السطح نفسه.
- [x] تحديث Runtime Contracts الأقرب للملفات المعدلة مع الحفاظ على فصل LAWS
      عن DESIGN وSOPs.

## 6. حزم تنفيذ صغيرة

صممت الحزم التالية لتنفذ وتراجع بصورة مستقلة قدر الإمكان:

1. **42A — Identity schema:** تثبيت الحقول والوثائق واختبارات serialization.
2. **42B — Agent segments:** model-step lifecycle وحفظ metadata واختبار runner.
3. **42C — Tool identity:** تمرير tool-call identity واختبار use/result pairs.
4. **42D — Failover claim:** الانتقال الذري إلى resuming واختبارات state machine.
5. **42E — History builder:** إعادة البناء المتسلسل وlegacy fallback.
6. **42F — Client mapper/state:** هويات العرض وfinal cleanup واختبارات store.
7. **42G — History hydration:** إزالة فرض integer ID وإضافة diagnostics.
8. **42H — Legacy recovery:** fixture والتدقيق وStop recovery الآمنة.
9. **42I — Parity integration:** سيناريو live/history و429/restart الكامل.
10. **42J — Documentation:** تحديث التصميم وQA والعقود المالكة.

لا تعد الحزمة مكتملة إذا غيرت عقدًا مشتركًا دون إضافة producer وconsumer
compatibility في نفس التكامل أو خلف fallback مؤقت موثق ومختبر.

## 7. الملفات المتوقعة

### Agent

- `agent/lib/engine/agent_runner.dart`
- `agent/lib/interfaces/runtime/session_turn_executor.dart`
- `agent/lib/interfaces/runtime/session_run_orchestrator.dart`
- `agent/lib/core/provider_runtime/runtime_recovery_service.dart`
- `agent/lib/evolution/db/runtime/session_execution_state_coordinator.dart`
- `agent/lib/interfaces/platforms/sanad_gateway/translators/agent_to_canonical.dart`
- `agent/lib/interfaces/platforms/sanad_gateway/handlers/session_query_handler.dart`
- نماذج protocol/checkpoint ذات الصلة واختباراتها المركزة

### Client

- `client/lib/features/conversations/data/mappers/unified_device_mapper.dart`
- `client/lib/features/conversations/data/transport/conversation_commands.dart`
- `client/lib/features/conversations/domain/stores/conversation_state.dart`
- `client/lib/features/conversations/domain/models/canonical_event.dart`
- `client/lib/features/conversations/presentation/bloc/session_messages_cubit.dart`
- اختبارات mapper/store/commands/widget والتكامل ذات الصلة

### Documentation

- `docs/technical/agent_runtime.md`
- `docs/technical/communication_protocols.md`
- `docs/technical/provider_protocol.md`
- `docs/qa_maintenance/plan30_runtime_recovery_matrix.md`
- صفحة QA لتطابق live/history

## 8. سيناريو النجاح النهائي

يستخدم fixture محليًا منزوعة الأسرار تمثل جولة طويلة مع 429 قبل بدء stream،
ثم auto-failover إلى مزود ثانٍ، وثلاثة model steps، وأداتين، وإجابة نهائية.
يجب أن يثبت التحقق الآتي:

1. الـAgent يحافظ على `run_id` وgeneration وwork item نفسها طوال الجولة.
2. كل model step يملك هوية عرض مستقلة، وكل أداة تملك `tool_call_id` مستقلة.
3. durable state تمر من running إلى waiting ثم resuming ثم completed.
4. يصدر final answer مرة واحدة فقط بعد terminal commit.
5. sidebar تعرض idle بعد النهاية وقبل restart وبعده.
6. الواجهة الحية تعرض كل thought/tool/final بالترتيب المتوقع.
7. فتح الجلسة بعد restart يعيد التسلسل نفسه من history دون Retry.
8. وجود route transition بمعرف نصي لا يكسر hydration.
9. لا تحذف final answer المقاطع السابقة ولا تكرر streaming projection.
10. لا يظهر final ثم error، ولا يبقى waiting صامتًا، ولا تضيع رسائل SQLite.

## 9. Definition of Done

- [x] عقود `run_id`, `model_step_id`, `tool_call_id`, و`event_id` موثقة
      ومطبقة في producer وtranslator وclient وhistory.
- [x] تسلسل thought/tool المتعدد يعمل live وبعد reload دون دمج خاطئ أو حذف.
- [x] auto-failover الناجح يمتلك durable resuming قبل الاستمرار وينتهي completed.
- [x] history ذات UUID route event تُحمّل دون اعتماد على `ChatMessage.int id`.
- [x] الأخطاء الحقيقية في hydration تسجل بصورة قابلة للتشخيص ومحمية من الأسرار.
- [x] الجلسات legacy العالقة تحصل على recovery آمنة ولا تُعلن completed دون دليل.
- [x] اختبارات Agent وClient المركزة ناجحة.
- [x] fast suites للسطوح المشتركة ناجحة.
- [x] اختبار التكامل المتسلسل و429/restart ناجح بالتنفيذ المتسلسل لأنه يرتبط
      بمنافذ وحالة runtime حصرية.
- [x] analyzer وformat gates ناجحة في Agent وClient.
- [x] وثائق التصميم وQA وRuntime Contracts المالكة محدثة في الجلسة نفسها.

## 10. خارج النطاق

- السماح بـ`waiting -> completed` أو `blocked -> completed` لتسوية بيانات قديمة.
- استخدام model-step أو tool-call IDs كبديل لملكية ActiveRun.
- تغيير سياسات اختيار المزود أو ترتيب مرشحي auto-failover.
- إعادة تصميم واجهة فقاعات المحادثة بصريًا خارج ما يلزم لحفظ التسلسل.
- تعديل محتوى reasoning أو سياسات إظهاره؛ المهمة تعالج الهوية والترتيب والحفظ.
- تعديل قاعدة المستخدم المحلية مباشرة أو تضمين محتواها في fixtures أو logs.
- تغيير queue/steer/stop semantics التي تملكها Task 36 إلا عند نقطة تمرير الهوية
  المشتركة اللازمة للتوافق.

## 11. Post-merge Stop projection correction

كشف التحقق بعد الدمج أن مسار `stopped` ظل يستخدم cleanup قديمًا على مستوى
`run_id` أو الجلسة، بينما بقيت thought projections السابقة في البث الحي بحالة
`running`. صُحح العقد كالتالي:

- [x] يحمل Stop الخاص بـactive run كلًا من `run_id` و`model_step_id` الحالي.
- [x] يحمل `tool_use` هوية model step التي أنتجته ويغلق فقاعتها إلى `done`.
- [x] يحذف العميل عند Stop الـprojection غير المكتملة المطابقة فقط.
- [x] لا يحذف recovery-only Stop أي تاريخ عندما لا يوجد active model step.
- [x] يغطي اختبار live متعدد الخطوات بقاء الأفكار المكتملة بعد Stop.

## 12. Post-merge E2E isolation correction

كشف التحقق أن اختبار local-daemon القديم كان يشغّل المزود الافتراضي الحقيقي
ويورث قاعدة `state.db` النشطة. صُحح نطاق الاختبار دون تغيير سلوك الإنتاج:

- [x] يحصل كل daemon اختباري على `SANAD_STATE_HOME` مؤقت وفريد ويُحذف بعده.
- [x] يرفض `SANAD_E2E_TEST_MODE` البدء دون مسار حالة معزول.
- [x] يستخدم E2E مزودًا ونموذجًا ثابتين دون أي اتصال خارجي.
- [x] تمر الإجابة الوهمية عبر orchestrator و`AgentRunner` والحفظ وhistory بدل
      اختصار `think` داخل WebSocket.
- [x] دُمج اختبارا النموذج الحقيقي المتداخلان في سيناريو deterministic واحد.
- [x] رُحّل اختبار صلاحيات platform tool من Ollama إلى fixture حتمي يغطي
      permission request/result ثم استكمال الجولة وإصدار final answer.
- [x] تطبق awaits الخاصة بأحداث WebSocket مهلة فعلية على قراءة الإطار نفسها.

## 13. Post-merge pending-steer Stop projection correction

أصبح `session.stop_draft_recovery` يطبق نتيجته ذريًا على واجهة العميل: يحذف
فقاعات العناصر ذات `source = pending_steer` من المحادثة قبل تمرير النص إلى
مسار استعادة الـcomposer المملوك. يمنع حاجز الهوية إعادة الفقاعة بواسطة نسخة
متأخرة من lifecycle، بينما تبقى استعادة النص والـack مقيدتين بملكية العميل.

## 14. Post-merge background pending-steer isolation correction

تُحفظ تحديثات `session.pending_steer_changed` ونتائج الإلغاء للمحادثات الخلفية
داخل حالتها المرتبطة بـ`session_id`، لكنها لا تعدل timeline المرئية إلا عندما
تطابق الجلسة المفتوحة. يغطي اختبار regression انتقال المستخدم إلى محادثة أخرى
قبل وصول انتقال `pending -> delivered` وعدم تسرب الفقاعة إليها.
