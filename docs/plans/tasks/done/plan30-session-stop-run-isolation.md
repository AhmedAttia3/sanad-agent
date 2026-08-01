---
title: "Plan 30 Session Stop Run Isolation"
description: "عزل الجولة الملغاة عن أي جولة لاحقة للجلسة نفسها، ومنع سباقات الإيقاف والطابور وحالة الاسترداد من إصدار نتائج أو تغيير حالة تشغيل جديدة."
parent_plan: "docs/plans/30-runtime-recovery-and-provider-rate-limits.md"
status: "completed"
completed_by: "Task 31 authoritative session state implementation"
---

# Plan 30 Session Stop Run Isolation

## 1. الهدف

تعالج هذه المهمة سباقًا يحدث عندما يوقف المستخدم جولة نشطة ثم يرسل رسالة
جديدة للجلسة نفسها بينما يستمر طلب HTTP أو callback قديم في الخلفية. يجب أن
تبقى الجولة القديمة معزولة تمامًا: لا تبث chunks أو final/error للجولة الجديدة،
ولا تمسح حالة انشغالها أو طابورها أو حالة recovery الخاصة بها.

النتيجة المطلوبة هي أن لكل تنفيذ ملكية مستقلة (`generation` و`run_id`)؛ وتملك
الجولة الحالية فقط حق تعديل حالة الجلسة أو إرسال أحداثها.

## 2. قاعدة التنفيذ المتسلسل

- [x] يعمل المنفذ على Gate واحدة فقط في كل وقت.
- [x] لا تبدأ Gate لاحقة حتى تكتمل كل checkboxes في Gate الحالية.
- [x] لا تعتبر Gate مكتملة بمجرد كتابة الكود؛ يلزم الاختبارات والتوثيق وشروط
      الخروج الخاصة بها.
- [x] إذا كشف الاختبار خللًا في Gate سابقة، تعاد تلك Gate إلى غير مكتملة قبل
      مواصلة العمل.
- [x] لا يعمل المنفذ `stage` أو `commit`؛ تتم المراجعة بين البوابات أولًا.
- [x] تبقى Plan 30 `in_progress` حتى اعتماد جميع بوابات هذه المهمة.

ترتيب التنفيذ الإلزامي:

```text
Gate A -> Review A -> Gate B -> Review B -> Gate C -> Review C
       -> Gate D -> Final Review
```

## 3. حدود الأمان

- [x] لا تستخدم `resetSession` عامة تمحو سبب `stopped` أو cancel token لجولة
      أقدم عند بدء جولة جديدة.
- [x] لا تعتمد سلامة العزل على إلغاء HTTP؛ فـcallback متأخر مسموح ويجب أن يهمل.
- [x] لا تملك الجولة غير الحالية حق بث chunk أو final أو error أو notice.
- [x] لا تملك الجولة غير الحالية حق إزالة busy state أو استهلاك الطابور أو حفظ
      suspended state أو توليد عنوان.
- [x] يبقى حدث `stopped` الشرعي مسموحًا، لكنه ليس final assistant response
      للجولة الملغاة.
- [x] لا يعاد تشغيل request قديم لأن جولة أحدث مسحت سبب إيقافه.
- [x] لا تسجل أسرار أو response bodies خام أثناء تشخيص السباق.

## Gate A: Run Ownership Contract

### A.1 نموذج الملكية

- [x] يضاف generation داخلي ومتزايد لكل جلسة في
      `agent/lib/interfaces/runtime/session_run_orchestrator.dart`.
- [x] تحمل `_ActiveRun` على الأقل `sessionId`, `generation`, `runId`,
      `stopRequested`, و`invalidated`.
- [x] ينشأ `_ActiveRun? activeRun` في نطاق `_runTurn` الخارجي كي يبقى مرجع
      الجولة التي رمت الاستثناء متاحًا في `catch` و`finally`.
- [x] لا يعاد استخدام `runId` الجولة القديمة عند تنفيذ رسالة لاحقة.
- [x] تنشأ helper صريحة للتحقق من أن الجولة ما زالت مالكة للجلسة، تعتمد على
      الهوية والـgeneration لا على `sessionId` وحده.

### A.2 بوابات الإخراج

- [x] لا يملك `_activeRuns[sessionId]` وحده سلطة تعريف الجولة التي صدر منها
      callback متأخر.
- [x] تكون عملية فحص الملكية وتبديل الملكية خالية من `await`.
- [x] تمت مراجعة النموذج قبل تغيير مسار الإيقاف أو recovery.

### Gate A Exit

- [x] تمت مراجعة عقد ملكية الجولة واعتماده قبل بدء Gate B.

## Gate B: Stop and Queue Transition

### B.1 إيقاف الجولة القديمة

- [x] يلتقط `requestStop` الجولة الحالية ويعلّمها `stopRequested` و`invalidated`
      بصورة متزامنة قبل انتظار إلغاء الاشتراك.
- [x] يزال الطابور والتشغيل المعلّق الخاصان بالجيل الملغى فقط.
- [x] لا يمكن لرسالة تصل أثناء `await activeRun.requestStop()` أن تضيع عندما
      يبدأ تنفيذ جديد.
- [x] لا يؤدي `finally` للجولة القديمة إلى إزالة `_busySessions` أو تشغيل
      عنصر من طابور يملكه generation أحدث.
- [x] يبقى stop idempotent، ويوقف الجولة الحالية عند وصول stop ثانٍ بعد بدء
      جولة جديدة بدل الرجوع إلى الجولة القديمة.

### B.2 تشغيل الجولة الجديدة

- [x] تبدأ الرسالة الجديدة بجيل جديد، حتى لو وصل طلبها أثناء إلغاء الجولة
      السابقة.
- [x] كل مسارات التنظيف، وإدارة الطابور، وsuspended work مقيدة بشرط ملكية
      الجولة الحالية.
- [x] لا يغيّر callback قديم `busy`, queue، أو persisted runtime state للجولة
      الجديدة.

### Gate B Exit

- [x] تمت مراجعة تسلسل stop ثم رسالة جديدة مع وجود `await` متعمد في الإلغاء.

## Gate C: Recovery and Response Isolation

### C.1 Runtime recovery scope

- [x] تربط `agent/lib/core/provider_runtime/runtime_recovery_service.dart`
      cancel token وسبب الإلغاء بحقل `generation` أو `runId` ثابت، لا بـ
      `sessionId` فقط.
- [x] تقبل `waitForRetry`, `abort`, `clear`, `isStopped`, و`reportFailure`
      هوية الجولة المناسبة أو مفتاح recovery مكافئًا لها.
- [x] تمرر `AgentRunner` هوية الجولة إلى `RuntimeRecoveryService` دون الاعتماد
      على قيمة `currentModelRunId` قابلة للتغير بين المحاولات.
- [x] يبقى سبب `stopped` للجولة القديمة متاحًا حتى تنهي هي نفسها مسار الإلغاء.
- [x] لا يستطيع notice أو retry متأخر من جولة قديمة أن يستبدل حالة recovery
      أو notice الجولة الحالية.

### C.2 معالجة الاستثناء والبث

- [x] يزال `on RuntimeRecoveryCancelled` الشقيق من `_runTurn`.
- [x] يعالج `catch` العام `RuntimeRecoveryCancelled` محليًا: يعود بصمت فقط
      عندما تكون الجولة المرجعية stopped أو غير حالية.
- [x] يعالج الإلغاء غير المقصود للجولة الحالية بمنطق الخطأ القياسي الذي يرسل
      error response منضبطًا؛ لا يستخدم `rethrow` غير معالج.
- [x] تتحقق callbacks الخاصة بـchunk، final، error، title، suspended state،
      وtool events من ملكية الجولة قبل أي بث أو كتابة حالة.
- [x] تستخدم أحداث الجولة `runId` الثابت الذي أنشأه الأوركسترا، لا قيمة runner
      قابلة للتغير بسبب جولة متداخلة.

### Gate C Exit

- [x] لا يمكن لطلب قديم ملغى أن يعيد المحاولة أو يبث نتيجة بعد تشغيل جديد.
- [x] لا يصبح `RuntimeRecoveryCancelled` خطأ غير معالج.

## Gate D: Tests, Documentation, and Verification

### D.1 اختبارات منضبطة

- [x] يضاف إلى `agent/test/interfaces/interfaces_test.dart` حاجز متحكم به
      يحاكي stop للجولة A ثم رسالة B أثناء انتظار إلغاء A.
- [x] يثبت الاختبار أن رسالة B لا تحذف من الطابور وأنها تبدأ بجيل و`runId`
      مختلفين.
- [x] يثبت الاختبار أن `finally` أو callback متأخرًا من A لا يجعل B غير مشغولة
      ولا يستهلك طابورها.
- [x] يثبت الاختبار أن chunks وfinal/errors المتأخرة من A لا تصل إلى B.
- [x] يميز الاختبار بين حدث `Execution stopped.` الشرعي وfinal assistant
      response غير الشرعي للجولة A.
- [x] يثبت الاختبار أن `RuntimeRecoveryCancelled` غير المقصود للجولة الحالية
      ينتج error response منضبطًا، لا Future error غير معالج.
- [x] يضاف إلى `agent/test/engine/agent_runner_test.dart` اختبار يثبت أن
      إلغاء انتظار recovery للجولة A لا يعيد المحاولة بعد تفعيل الجولة B.

### D.2 التوثيق

- [x] يضاف السيناريو 12 إلى
      `docs/qa_maintenance/plan30_runtime_recovery_matrix.md`: stop للجولة A،
      بدء B، callback متأخر من A، وعزل كامل للجولة B.
- [x] يحدث `docs/technical/agent_runtime.md` بعقد ملكية الجولة وحدود callbacks
      المتأخرة.
- [x] يحدث `agent/lib/interfaces/AGENTS.md` بعقد مختصر: الجولة الحالية فقط
      تملك البث والتنظيف وحالة الجلسة.
- [x] يحدث `agent/AGENTS.md` بعقد مختصر يفرض ربط recovery بجولة التشغيل، لا
      بالجلسة المجردة فقط.

### D.3 Verification

- [x] تشغيل `cd sanad-agent/agent && fvm dart analyze` بنجاح.
- [x] تشغيل `cd sanad-agent/agent && fvm dart test test/interfaces/interfaces_test.dart`
      بنجاح.
- [x] تشغيل `cd sanad-agent/agent && fvm dart test test/engine/agent_runner_test.dart`
      بنجاح.
- [x] تشغيل سويت agent السريعة الكاملة إذا كشفت التغييرات أثرًا على عقد
      `AgentRunner` أو recovery المشترك.

### Gate D Exit

- [x] جميع الاختبارات والتوثيق والتحليل ناجحة ومراجعة قبل اعتبار المهمة مكتملة.

## 4. معايير القبول النهائية

- [x] الرسالة الجديدة بعد الإيقاف لا تضيع ولا تُنفذ ضمن generation قديم.
- [x] لا يظهر final مبكر أو chunk أو error قديم في الجولة الجديدة.
- [x] لا يعيد الطلب القديم المحاولة بعد stop.
- [x] لا يوجد `RuntimeRecoveryCancelled` غير معالج.
- [x] لا تؤثر الجولة القديمة في busy state أو طابور أو recovery الجولة الجديدة.
- [x] تظل جميع أحداث كل جولة مرتبطة بـ`runId` ثابت يخصها.
