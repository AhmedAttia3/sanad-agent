---
title: "Plan 30 Runtime Recovery Hardening and Durable State"
description: "بوابات تنفيذ متسلسلة لتصحيح أخطاء SSE والتصنيف، ثم بناء استعادة durable آمنة لا تفقد الرسائل أو تكرر الأدوات بعد إعادة تشغيل daemon."
parent_plan: "docs/plans/30-runtime-recovery-and-provider-rate-limits.md"
status: "complete"
---

# Plan 30 Runtime Recovery Hardening and Durable State

## 1. الهدف

تغلق هذه المهمة الفجوات المتبقية في Plan 30 عبر مسارين مرتبطين:

1. التقاط أخطاء المزود المضمنة في SSE وتصنيف `504` و`ResourceExhausted`
   بصورة صحيحة مع الحفاظ على retry hints ورسالة المزود المنقحة.
2. بناء durable recovery بعد إعادة تشغيل daemon دون فقد work items، أو كسر
   FIFO، أو تكرار أداة ذات side effects، أو عرض notice لا يملكها runtime.

التغييرات الموجودة في Git stage هي خط الأساس المعتمد. أما التنفيذ غير
المرحلي الحالي للـpersistence وSSE فهو implementation provisional يجب تدقيقه
وتصحيحه وفق هذه المهمة قبل اعتماده.

## 2. قاعدة التنفيذ المتسلسل

- [x] يعمل المنفذ على Gate واحدة فقط في كل وقت.
- [x] لا يبدأ Gate لاحقة حتى تكتمل كل checkboxes في Gate الحالية.
- [x] لا تعتبر Gate مكتملة بمجرد كتابة الكود؛ يلزم الاختبارات والتوثيق وشروط
      الخروج الخاصة بها.
- [x] إذا كشف الاختبار خللًا في Gate سابقة، تعاد تلك Gate إلى غير مكتملة قبل
      مواصلة العمل.
- [x] لا يعمل المنفذ `stage` أو `commit`؛ تتم المراجعة بين البوابات أولًا.
- [x] تبقى Plan 30 `in_progress` وPhase H/8 مفتوحة حتى إغلاق Gate G.

ترتيب التنفيذ الإلزامي:

```text
Gate A -> Review A -> Gate B -> Review B -> Gate C -> Review C
       -> Gate D -> Review D -> Gate E -> Review E -> Gate F
       -> Review F -> Gate G -> Final Review
```

## 3. حدود الأمان

- [x] الوكيل هو مصدر الحقيقة للnotice والqueue والroute وحالة التنفيذ.
- [x] لا تعرض الواجهة `waiting` إذا لم توجد recovery state فعلية في runtime.
- [x] لا تعاد أداة ذات side effects اعتمادًا على history وحدها.
- [x] لا يدعى دعم mid-stream resume؛ الاستئناف من checkpoint آمن فقط.
- [x] لا تحذف durable work قبل وصوله إلى terminal state موثوق.
- [x] لا تستخدم debug commands عامة في production transport لإثبات E2E.
- [x] لا تسجل raw headers أو credentials أو response bodies غير المنقحة.

## Gate A: SSE and Failure Classification Hardening

### A.1 SSE error envelope

- [x] يحافظ OpenAI-compatible SSE error على `type`, `code`, و`message`.
- [x] يحافظ Anthropic SSE `event: error` على `error.type`, `code`, و`message`.
- [x] تمرر adapters response headers إلى `LlmHttpException` بدل إسقاطها.
- [x] يظل `Retry-After` وrate-limit reset قابليْن للاكتشاف في SSE errors.
- [x] يبنى body مهيكل للتصنيف والعرض دون تسريب headers أو أسرار.
- [x] لا يتحول SSE error إلى assistant response فارغ.

### A.2 HTTP 504

- [x] يصنف `504` و`gateway timeout` كفشل transient timeout/server، لا
      `upstreamRateLimit` لمجرد وجود كلمة gateway.
- [x] يحصل `504` على retry budget محدود وbackoff فعليين.
- [x] يبقى `unknown` يدويًا افتراضيًا، ولا تدعي الاختبارات عكس ذلك.
- [x] لا يستخدم provider cooldown الخاص بالـrate limit لفشل timeout عادي.

### A.3 ResourceExhausted

- [x] لا تكفي `ResourceExhausted` وحدها لتصنيف `rateLimit`.
- [x] `request limit`, `total request limit`, `rate limit`, أو reset موثوق
      تؤدي إلى `rateLimit`.
- [x] `insufficient quota` بلا reset تؤدي إلى billing/blocked.
- [x] capacity أو worker unavailable تؤدي إلى overloaded.
- [x] الرسالة الغامضة تبقى محافظة ولا تدخل auto-retry طويلًا بلا دليل.

### A.4 Verification

- [x] unit tests لـOpenAI HTTP-200 SSE error.
- [x] unit tests لـAnthropic `overloaded_error` داخل SSE.
- [x] unit tests لـSSE rate limit مع `Retry-After`.
- [x] اختبار يثبت وصول رسالة المزود بعد redaction.
- [x] اختبارات قرار وميزانية retry لـ504.
- [x] اختبارات فروع `ResourceExhausted` المؤقتة والدائمة والغامضة.
- [x] تحليل agent نظيف بلا warnings أو infos.
- [x] اختبارات Gate A والسويت الكاملة ناجحة.
- [x] تحديث العقود الفنية وQA matrix.

### Gate A Exit

- [x] تمت مراجعة Gate A واعتمادها قبل بدء Gate B.
- [x] أزيلت كل ملاحظات analyzer في كود واختبارات Gate A، ثم أعيد تشغيل
      الاختبارات المستهدفة والسويت الكاملة قبل طلب المراجعة.

## Gate B: Quarantine Unsafe Persistence

الغرض من هذه البوابة منع تفعيل persistence غير مكتملة أثناء إعادة تصميمها.

- [x] لا يستدعي production startup استعادة غير مثبتة قد تفقد أو تكرر العمل.
- [x] تزال أو تعطل دعوة `restorePersistedState()` الحالية حتى اعتماد Gate F؛
      لا يكفي إحاطتها بـtry/catch مع متابعة التشغيل.
- [x] لا يعرض history persisted notice كأنها active إذا لم يستعدها runtime.
- [x] تبقى schema/repository provisional قابلة للاختبار دون تفعيل سلوك مضلل.
- [x] لا تحذف البيانات الموجودة دون migration أو cleanup policy موثقة.
- [x] توثق Plan 30 أن daemon restart recovery غير مكتملة حتى Gate F.
- [x] يوجد اختبار يثبت أن التفعيل المؤقت الآمن لا يغير recovery الحالي مع
      استمرار daemon.
- [x] تحليل agent والسويت الكاملة ناجحان.

### Gate B Exit

- [x] تمت مراجعة Gate B واعتمادها قبل بدء تصميم durable state.

## Gate C: Durable Work State Machine

### C.1 Model

- [x] يوجد `work_item_id` ثابت وفريد لكل عمل.
- [x] يحفظ كل work item: `session_id`, `request_id`, `sequence`, route، workspace،
      payload منقح، attempt، timestamps، وcontinuation metadata.
- [x] الحالات المعرفة صراحة هي: `queued`, `running`, `waiting`, `blocked`,
      `resuming`, `completed`, و`cancelled`.
- [x] يوجد unique constraint يمنع تكرار work item/request داخل الجلسة.
- [x] يوجد active work item واحد فقط لكل جلسة.
- [x] يوجد جدول durable أساسي واحد للwork items؛ تزال الكتابة المزدوجة إلى
      `session_pending_runs`/`session_suspended_runs` أو توثق migration انتقالية
      ذرية لا تسمح باختلاف مصدرين للحقيقة.

### C.2 Atomic transitions

- [x] `queued -> running` transaction ذرية.
- [x] `running -> waiting|blocked` transaction ذرية.
- [x] `waiting|blocked -> resuming` transaction ذرية.
- [x] `resuming -> completed` لا يحدث قبل حفظ history والterminal response.
- [x] `active -> cancelled` يمسح ownership والnotice والqueue حسب Stop contract.
- [x] لا يستخدم pop/delete قبل التنفيذ.
- [x] لا يحذف suspended أو queued record قبل نجاح claim والانتقال الذري؛
      `resumeSuspended` لا يزيل durable checkpoint قبل terminal transition.
- [x] يستخدم claim/lease أو interrupted marker لاسترداد `running` بعد crash.
- [x] `_nextSeq` والتزام FIFO آمنان تحت التنافس المتوقع.
- [x] توجد transition graph صريحة ترفض الانتقالات غير المسموحة، وليس مجرد
      التحقق أن `fromState` يطابق القيمة الحالية.

### C.3 Session lifecycle

- [x] حذف session ينظف كل runtime rows عبر FK حقيقية أو cleanup ذري مختبر.
- [x] schema documentation تطابق SQL الفعلي حرفيًا.
- [x] migration آمنة لقواعد البيانات القائمة.
- [x] orphan rows تكتشف وتنظف دون إنشاء جلسات وهمية.

### C.4 Repository verification

- [x] اختبارات transitions الصحيحة والمرفوضة.
- [x] اختبارات ترفض صراحة `queued -> completed`, `blocked -> running`، وكل
      اختصار يتجاوز `resuming` أو claim المعتمد.
- [x] اختبارات uniqueness وactive-item invariant.
- [x] اختبارات FIFO عبر restart لقاعدة SQLite حقيقية مؤقتة.
- [x] اختبار crash بين claim والتنفيذ دون فقد أو duplication.
- [x] اختبار cleanup عند حذف session.
- [x] تحليل agent والسويت الكاملة ناجحان.

### Gate C Exit

- [x] تمت مراجعة schema والانتقالات واعتمادها قبل ربطها بالتنفيذ.

## Gate D: Safe Continuation Checkpoints

### D.1 Continuation kinds

- [x] يدعم `initial_model_request` كcheckpoint صريحة.
- [x] يدعم `after_tool_result` كcheckpoint صريحة.
- [x] لا يصنف حدثًا غامضًا تلقائيًا كأحد النوعين.

### D.2 Tool safety

- [x] يحفظ `tool_call_id`, `tool_name`, execution state، tool result، و`is_error`.
- [x] يحفظ هل أرسلت tool result إلى المزود أم لا.
- [x] إذا كان result محفوظًا فلا تعاد الأداة؛ ترسل النتيجة للمزود فقط.
- [x] إذا كانت حالة التنفيذ غامضة تتحول الجلسة إلى blocked.
- [x] لا يستأنف call ذات side effects بلا idempotency/checkpoint موثوق.
- [x] redaction تطبق قبل تخزين arguments/results الحساسة.
- [x] idempotency تأتي من contract/metadata مملوكة للأداة، لا من قائمتين
      hard-coded داخل AgentRunner وSessionRunOrchestrator.
- [x] لا تصنف أدوات تغيير الحالة مثل `manage_task` أو file edits كـidempotent.
- [x] في parallel tool batches تحفظ نتيجة كل أداة ذريًا فور اكتمالها؛ crash بعد
      اكتمال أداة وقبل بقية المجموعة لا يعيد تنفيذ الأداة المكتملة.

### D.3 Runner integration

- [x] الاستئناف لا يكرر user echo أو user history message.
- [x] الاستئناف لا يكرر assistant tool call أو tool result.
- [x] runner جديد بعد restart يبدأ من checkpoint الآمنة، لا من تخمين history.
- [x] فشل الاستئناف يعيد work item إلى durable blocked state ولا يفقده من
      `_suspendedEvents`؛ يجب أن يظل Retry/Change Provider قابلين للتنفيذ بعد
      فشل checkpoint validation أو أي فشل أثناء resume.

### D.4 Verification

- [x] restart بعد initial request يستأنف مرة واحدة.
- [x] restart بعد tool result لا يعيد تنفيذ الأداة.
- [x] tool state غامضة تبقى blocked مع Stop/Retry الآمن المناسب.
- [x] crash أو failure أثناء resume لا يفقد durable work item ولا in-memory
      suspended owner، ويمكن إجراء محاولة لاحقة دون رسالة مستخدم جديدة.
- [x] اختبارات side-effect counter تثبت عدم التنفيذ مرتين، بما في ذلك E2E
      daemon restart؛ عد طلبات LLM وحده لا يثبت أن الأداة لم تنفذ مرتين.
- [x] اختبار parallel batch يحدث crash بعد اكتمال أداة واحدة ويثبت أن نتيجتها
      تستعاد دون إعادة تنفيذها.
- [x] تحليل agent والسويت الكاملة ناجحان.

### Gate D Exit

- [x] تمت مراجعة checkpoint safety واعتمادها بعد إغلاق ملاحظات المراجعة
      النهائية الخاصة بملكية suspended run وعدم تكرار side effects.

## Gate E: Runtime Restoration and FIFO

### E.1 RuntimeRecoveryService restoration

- [x] API restore صريحة تعيد notice إلى active state الفعلية.
- [x] يعاد cancel token وprovider cooldown عند الحاجة.
- [x] يعاد timer من `resume_at` دون استخدام مدة قديمة غير محدثة.
- [x] `resume_at` الماضي يؤدي إلى استئناف فوري آمن مرة واحدة.
- [x] timer المستعاد يملك callback فعلية تصل إلى claim ثم `resumeSuspended`؛
      تسجيل provider cooldown وحده لا يعد auto-resume.
- [x] blocked state تستعيد Retry/Change Provider/Stop.
- [x] clear/stop يزيلان memory وdurable state باتساق ذري.

### E.2 Queue bootstrap

- [x] تستعاد العناصر حسب sequence.
- [x] يستعاد active/suspended work واحد لكل جلسة.
- [x] queue بلا active work لا تبقى stranded.
- [x] bootstrap يبدأ drain لأقدم queue-only item أو يحولها إلى blocked واضحة؛
      لا ينتظر وصول رسالة أحدث كي تبدأ الرسائل القديمة.
- [x] لا تنفذ رسالة جديدة قبل العناصر الأقدم.
- [x] تغيير provider/model يعيد كتابة route لكل work غير terminal ذريًا.
- [x] restored notice لا تظهر إلا إذا runtime تملك recovery المقابلة.

### E.3 Restart integration tests

- [x] waiting خمس ساعات ثم restart يعيد notice والتايمر.
- [x] انتهاء `resume_at` أثناء توقف daemon يؤدي إلى resume آمن.
- [x] blocked ثم restart يسمح بـRetry.
- [x] blocked ثم restart يسمح بتغيير provider/model.
- [x] رسالة جديدة بعد restart تستأنف القديم ثم تكمل FIFO.
- [x] Stop بعد restart يمسح active/queue/notice ويبث stopped/cleared.
- [x] queue-only crash لا يعكس FIFO ولا يترك queue بلا drain.
- [x] crash أثناء running/resuming لا يفقد ولا يكرر work item.
- [x] عميلان يريان route وstop/clear نفسيهما.
- [x] تستخدم الاختبارات SQLite مؤقتة ثم services جديدة لمحاكاة restart حقيقي.
- [x] تحليل agent والسويت الكاملة ناجحان.

### Gate E Exit

- [x] تمت مراجعة restart integration واعتمادها قبل production activation.

## Gate F: Production Activation and Daemon-Backed E2E

### F.1 Activation

- [x] يفعل restore في startup بعد نجاح Gates C-E فقط.
- [x] يبدأ restore قبل قبول gateway events الجديدة.
- [x] failure في restore معزول ويظهر blocked state قابلة للتحكم بدل crash صامت.
- [x] فشل restore لا يكتفي بالطباعة أو log ثم متابعة التشغيل بحالة مجهولة.
- [x] لا توجد production debug commands أو magic messages للاختبار.

### F.2 E2E

- [x] يستخدم daemon حقيقيًا وstate directory نفسها عبر عمليتي تشغيل.
- [x] يستخدم fake LLM adapter محقونًا عبر test harness، لا transport shortcut.
- [x] ينشئ waiting أو blocked حقيقية عبر AgentRunner/Orchestrator.
- [x] يوقف daemon الأول ويشغل daemon ثانيًا.
- [x] يعيد إنشاء client ويعمل hydration للnotice والqueue.
- [x] يختبر Retry أو Change Provider أو Stop عبر البروتوكول الحقيقي.
- [x] يثبت أن turn حقيقية تبدأ بعد recovery دون magic response.
- [x] يثبت عدم تكرار tool side effect في سيناريو post-tool-result بقياس أثر
      الأداة نفسه أو counter مملوك للـfixture، لا باستنتاجه من عدد طلبات LLM.
- [x] تشغل اختبارات المنافذ بتسلسل لمنع التصادم.

### F.3 Verification

- [x] E2E ناجح ومتكرر بلا flakiness زمنية.
- [x] الاختبار السابق الذي يستخدم debug protocol event أو magic success message
      لا يحتسب كدليل Gate F حتى يستبدل بمسار AgentRunner/Orchestrator حقيقي.
- [x] تحليل agent وclient نظيفان.
- [x] سويتا agent وclient الكاملتان ناجحتان.
- [x] وثيقة QA تسجل الاختبار والسيناريو المثبت بدقة.

### Gate F Exit

- [x] تمت مراجعة E2E واعتماد production activation بعد اجتياز اختبار side
      effect حقيقي وإغلاق فقدان suspended owner عند فشل resume.

## Gate G: Documentation and Closure

- [x] تحديث `agent/AGENTS.md` بالعقد النهائي المختصر.
- [x] تحديث `agent/lib/interfaces/AGENTS.md` بملكية restore/checkpoints.
- [x] تحديث `provider_protocol.md` لأوامر وأحداث recovery بعد restart.
- [x] تحديث `agent_database_schema.md` وفق schema الفعلية.
- [x] تحديث `agent_runtime.md` لدورة bootstrap والاستئناف.
- [x] تحديث `plan30_runtime_recovery_matrix.md` بكل test مثبت.
- [x] إزالة النصوص القديمة أو المتناقضة التي تدعي دعمًا غير موجود.
- [x] إبقاء Plan 30 أقل من 900 سطر وربطها بهذه المهمة بدل تكرار التفاصيل.
- [x] تعليم Phase H/8 مكتملة بعد اجتياز جميع البوابات فقط.
- [x] تغيير Plan 30 إلى `complete` بعد عدم بقاء أي acceptance item مفتوح.
- [x] تغيير هذه المهمة إلى `complete` ونقلها إلى `tasks/done` بعد المراجعة.

## 4. Final Definition of Done

- [x] لا تضيع queued أو suspended work عبر restart.
- [x] يبقى FIFO صحيحًا قبل restart وبعده.
- [x] لا تنفذ أداة ذات side effects مرتين، ومثبت ذلك بعداد side effect حقيقي
      عبر daemon restart.
- [x] notice المعروضة تطابق active runtime state.
- [x] timer الطويل يعود ويستأنف في موعده أو يقبل Stop.
- [x] Retry/Change Provider/new message تعمل بعد restart وبَعد فشل محاولة resume
      بالroute الحالية دون فقد suspended owner.
- [x] Stop من أي client يعيد الجلسة إلى idle ويمسح العمل غير المنفذ.
- [x] SSE/504/ResourceExhausted مصنفة وفق الأدلة لا الكلمات العامة.
- [x] لا توجد warnings أو infos في analyzers.
- [x] unit، integration، full suites، وdaemon-backed E2E ناجحة بعد إضافة
      regressions الخاصة بملاحظات المراجعة أدناه.

## 5. Final Review Findings (2026-07-11)

تنفذ هذه النقاط بالترتيب، ولا يعاد إغلاق Gate D أو Gate F قبل اجتيازها:

1. [x] **P1 - Preserve suspended ownership when resume fails.**
   `SessionRunOrchestrator.resumeSuspended()` يزيل العنصر من
   `_suspendedEvents` قبل تشغيل `_runTurn`. مسار `_runTurn` يمسك الفشل داخليًا
   ويحوّل durable work item إلى `blocked`، لكنه لا يعيد `_SuspendedRun` إلى
   الذاكرة. النتيجة أن Retry أو Change Provider التالي قد يجد notice وrow
   دائمين لكن لا يجد عملًا ليستأنفه. غيّر lifecycle إلى claim/peek ثم لا تزل
   suspended owner إلا بعد terminal success/cancel، أو أعده صراحة عند كل فشل.
2. [x] أضف integration regression يبدأ suspended run، يجعل resume يفشل في
   checkpoint validation أو runner، ثم يثبت أن المحاولة الثانية مع route جديدة
   تستأنف نفس work item ولا تضيف user echo ولا تحتاج رسالة جديدة.
3. [x] **P1 - Do not clear recovery before resume is owned.** مسارات
   `session.runtime_retry` و`session.runtime_continue_with_provider` وauto-resume
   تبث `resuming` ثم تمسح notice قبل التحقق من نتيجة `resumeSuspended`. يجب أن
   يكون انتقال notice/work item من waiting أو blocked إلى resuming متسقًا، وألا
   يبث `cleared` إلا بعد امتلاك suspended work أو الوصول إلى terminal outcome.
   إذا أعادت `resumeSuspended` القيمة `false` أو فشلت، أعد/أبقِ blocked notice
   قابلة لـRetry/Change Provider/Stop بدل ترك session صامتة.
4. [x] أضف اختبارات للبروتوكول وauto-resume تغطي `resumeSuspended == false`
   وفشل resume بعد بدء المحاولة، وتثبت عدم فقد notice أو work item.
5. [x] **P1 - Make the E2E side-effect assertion real.** اختبار `F.2.2` الحالي
   يستنتج عدم إعادة تنفيذ `list_scheduled_tasks` من فرق عدد طلبات LLM. هذا لا
   يكشف إعادة تشغيل turn من البداية إذا أعاد الـLLM جوابًا نهائيًا في الطلب
   التالي. استخدم tool fixture لها counter/observable side effect يظل قابلًا
   للقراءة بعد restart، ثم اثبت أن قيمته `1` بعد recovery.
6. [x] **P2 - Emit one clear event per Stop transition.** اختبار E2E أظهر بث
   `session.runtime_notice_cleared` مرتين عند `session.runtime_stop` لأن أكثر من
   طبقة تستدعي clear. اجعل orchestrator/recovery owner واحدًا للانتقال والبث،
   وأضف اختبار multi-client يثبت وصول `stopped` وclear واحد لكل client.
7. [x] شغّل daemon-backed E2E المعدل بتسلسل أكثر من مرة لإثبات عدم flakiness،
   ثم شغّل analyzer والسويت الكاملة. حدث QA matrix بوصف ما يقيسه الاختبار
   فعليًا، لا ما يستنتجه بصورة غير مباشرة.
8. [x] **P1 - Make concurrent resume commands idempotent.** القيمة `false` من
   `resumeSuspended()` تخلط حاليًا بين حالتين مختلفتين: عدم وجود durable/suspended
   work، وكون عميل آخر قد claim العمل وبدأ resume بالفعل. عند وصول Retry أو
   Change Provider متزامنين من عميلين، قد يبدأ الأول التنفيذ بينما يحول الثاني
   notice إلى `blocked` برسالة missing saved work، ثم يكتمل التنفيذ وتبقى notice
   الخاطئة. استخدم نتيجة صريحة مثل `claimed` / `alreadyResuming` / `missing` أو
   claim state ذرية مكافئة؛ تعامل مع `alreadyResuming` كنجاح idempotent ولا تبث
   blocked أو clear إضافيين.
9. [x] أضف integration/protocol regression بعميلين أو أمرين متزامنين يثبت أن
   runner يستأنف مرة واحدة فقط، ولا تظهر missing-work blocked notice، وينتهي
   work item وnotice في الحالة المتسقة نفسها. غطِّ Retry+Retry، ويفضل أيضًا
   Retry+Change Provider مع توثيق قاعدة حسم route عند التنافس.
10. [x] بعد الإصلاح أعد تشغيل الاختبارات المستهدفة، full agent suite، وE2E
    daemon-backed، ثم لا تغلق Gate D أو Final DoD قبل المراجعة التالية.
11. [x] **P1 - Keep the winning route consistent across runner, session, queue,
    and clients.** الـbridge يحدّث `SessionManager` ويبث
    `session_preferences_updated` قبل معرفة نتيجة `resumeSuspended`. إذا بدأ
    Retry أولًا ثم وصل Change Provider من عميل ثانٍ وحصل على
    `alreadyResuming`، يستمر runner على route الأول بينما تصبح route الجلسة
    والواجهات هي route الثاني. هذا يخالف عقد "first claimant wins" ويجعل الرد
    الجاري وحالة الجلسة مختلفين. نفذ route mutation حسب نتيجة claim: `claimed`
    يطبق route داخل ownership transition، `alreadyResuming` لا يغير route،
    و`missing` يغير default route فقط وفق عقد no-work/active-waiting الواضح.
12. [x] أضف regression معكوسًا للاختبار الحالي: Retry يبدأ ويصل إلى
    `resumeStarted`، ثم يصل Change Provider. اثبت أن runner وSessionManager
    والqueued work وحدث `session_preferences_updated` تتفق كلها على route
    الفائزة، ولا يبث الأمر الخاسر route متناقضة.
13. [x] **P1 - Restore Change Provider for an active waiting runner.** عندما
    تكون الجلسة داخل retry wait فعلية لكن لا يوجد suspended owner بعد، يعيد
    `resumeSuspended` القيمة `missing`. مسار Retry يملك fallback لتحديث active
    runner وإلغاء الانتظار، لكن `session.runtime_continue_with_provider` لا
    يفعل ذلك حاليًا؛ يحدّث default session ثم يبث blocked بينما runner القديم
    يظل منتظرًا/موجهًا للمزود القديم. اجعل Change Provider يميز active waiting
    عبر notice/runtime state موثوقة، يحدّث active runner والqueued route، يلغي
    wait القديمة، ويستأنف على provider/model الجديدين.
14. [x] لا تستخدم `isSessionBusy && !hasSuspendedEvent` وحدها لإثبات active
    waiting؛ فهي تشمل turn طبيعية قيد التنفيذ. اشترط active recovery notice
    بحالة `waiting` أو state صريحة مكافئة، وأضف اختبارًا يثبت أن Retry stale
    أثناء turn طبيعية لا يلغيها ولا يبث resuming/cleared كاذبة.
15. [x] أضف integration tests لمسار Change Provider أثناء active waiting
    الفعلية، ثم شغّل targeted tests، full agent suite، وdaemon-backed E2E قبل
    طلب المراجعة التالية.
