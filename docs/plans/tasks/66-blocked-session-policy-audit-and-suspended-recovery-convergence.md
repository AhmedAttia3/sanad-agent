---
title: "Task 66: Blocked Session Policy Audit and Suspended Recovery Convergence"
description: "تدقيق كل مسارات تحويل الجلسة إلى blocked، اعتماد السياسة مع المستخدم، وإعادة إنتاج وإصلاح تضارب force-stop مع system_ask_user عبر Agent وClient واختبار daemon-backed معزول."
status: "pending_policy_approval"
current_gate: "Gate A — Complete Blocked-State Audit and User Approval"
priority: "critical"
depends_on: "Plan 30 durable runtime recovery and Task 31 authoritative execution snapshots"
file_budget: 20
design_contract: "docs/technical/agent_interface_runtime.md"
qa_contract: "docs/qa_maintenance/plan30_runtime_recovery_matrix.md"
---

# Task 66: Blocked Session Policy Audit and Suspended Recovery Convergence

## 1. الهدف

منع تحويل أي جلسة إلى `blocked` بلا سبب حقيقي وقابل للتفسير، وإصلاح السيناريو
المرصود الذي تتعارض فيه حالة الجلسة بعد إغلاق قسري أثناء انتظار إجابة
`system_ask_user`:

1. يعرض الوكيل بطاقة سؤال وينتظر المستخدم.
2. لا يجيب المستخدم ويُنهى process بالقوة.
3. بعد restart تظهر الجلسة كمقاطعة و`blocked` رغم بقاء السؤال صالحاً.
4. يقبل النظام الإجابة ويستأنف التنفيذ، لكن تبقى بعض projections أو الواجهة
   `blocked` في الوقت نفسه.

المهمة ليست توثيقاً فقط. بعد موافقة المستخدم على مصفوفة Gate A، يجب إعادة
إنتاج السيناريو في runtime اختبارية معزولة وإصلاح أي خلل مثبت أو أي انتقال
`blocked` يخالف السياسة المعتمدة، ثم إثبات تقارب قاعدة البيانات والـdaemon
والـclient إلى حالة واحدة صحيحة.

---

## 2. تعريف `blocked` المثبت مبدئياً

`blocked` تعني:

> لا يستطيع النظام التقدم بأمان أو بصورة صحيحة دون تدخل صريح من المستخدم.

يشمل ذلك مبدئياً:

- خطر غير محسوم لتكرار side effect بعد crash/restart.
- checkpoint ناقصة أو غامضة لا يمكن استئنافها تلقائياً بأمان.
- auth أو billing أو provider/model/configuration تمنع التقدم ولا يوجد مسار
  تعافٍ تلقائي صالح.
- فشل transient استنفد كل مسارات التعافي التلقائي، لكنه يملك تدخلاً يدوياً
  واضحاً مثل Retry أو Change Provider أو Stop.

ولا يشمل:

- سؤال `system_ask_user` أو permission request ما زال ينتظر إجابة صالحة؛ هذه
  `waiting` مع pending suspended request.
- retry مؤقت يملك timer/owner صالحاً؛ هذه `waiting`.
- تنفيذ بدأ أو استؤنف فعلياً؛ هذه `running` أو `resuming`.
- عمل انتهى أو لم يعد له owner؛ هذه `idle` بعد التسوية، لا notice تاريخية.
- خطأ عام لم يُصنف بعد من دون إثبات أن تدخل المستخدم مطلوب؛ يجب تصنيفه أو توفير
  مسار تعافٍ، ولا تستخدم `blocked` كـcatch-all صامت.

هذا التعريف لا يصبح عقداً نهائياً للتنفيذ إلا بعد تقديم مصفوفة Gate A وموافقة
المستخدم الصريحة عليها.

---

## 3. نتائج التدقيق الأولي

### 3.1 السيناريو المرصود معروف من حيث الفئة

المصدر الحالي يحتوي بالفعل على دفاعات واختبارات تستهدف هذا النوع من الخلل:

- `SessionRecoveryRestorer` يصنف running work كـ`waiting` عندما تكون كل
  `currently_executing_tools` مملوكة لـcheckpoints غير محلولة.
- يوجد repair لمسار legacy يحول false-blocked interactive work عبر
  `blocked -> resuming -> waiting` ويحذف notice المقاطعة القديمة.
- `SuspendedResumeService` يسمح لأول إجابة بمطالبة `waiting` أو `blocked`، ثم
  ينتقل إلى `resuming` ويمسح stale recovery notice، ويشترط terminal commit إلى
  `completed` قبل final delivery.
- الاختباران الحاليان يمران:
  - `restart restores a suspended ask-user tool as waiting, not blocked`
  - `persisted ask-user answer completes durable work before final delivery`

لكن هذه التغطية لا تثبت بعد السيناريو الكامل عبر process force-kill، إعادة فتح
قاعدة on-disk، hydration إلى Client حقيقية، الإجابة من البطاقة، وترتيب
`runtime_notice_cleared` و`session.execution_state_changed` حتى `idle`.

### 3.2 `blocked` لها أكثر من مالك دخول

يجب ألا يقتصر التدقيق على `system_ask_user`. تشمل نقاط الدخول الأولية التي يجب
تتبعها إلى المصدر والاختبارات:

1. **مصنف فشل المزود** في `runtime_failure_reason.dart`:
   - auth، billing، timeout، networkError، tlsCertificate، invalidRequest،
     modelNotFound، toolRuntimeError، localRuntimeError، unknown.
2. **تغيير قرار recovery** في `RuntimeRecoveryService`:
   - force-blocking، استنفاد retry budget، promotion من waiting، واستعادة notice.
3. **فشل checkpoint/resume** في `ContinuationCheckpointCoordinator`.
4. **الاستعادة بعد restart** في `SessionRecoveryRestorer`:
   - tool غير آمن، interrupted resuming غير قابل للإعادة، waiting بلا owner مثبت،
     وفشل restore العام.
5. **أخطاء turn غير المتوقعة** في `SessionTurnExecutor` التي تحول العمل مباشرة
   إلى `blocked`.
6. **أي انتقال مباشر أو غير مباشر آخر** يظهر عبر البحث عن:
   - `SessionWorkState.blocked`
   - `SessionExecutionState.blocked`
   - `RuntimeNoticeStatus.blocked`
   - SQL أو deserialization أو migration ينتج القيمة `blocked`.
7. **Client projection**:
   - ترتيب أولوية pending question مقابل blocked notice/snapshot.
   - hydration من history ثم وصول live events بترتيب مختلف.
   - تجاهل snapshots القديمة بالـrevision.
   - إزالة notice وعدم إبقاء sidebar/input في attention state قديمة.

القائمة أعلاه seed للتدقيق وليست المصفوفة النهائية. Gate A مطالبة بإثبات أن كل
writer ومسار غير مباشر جرى حصره.

---

## 4. القرارات المثبتة للمهمة

### 4.1 بوابة موافقة بشرية إلزامية

- Gate A تدقيق فقط: قراءة المصدر والاختبارات والوثائق وإنتاج مصفوفة كاملة.
- **تتوقف المهمة بعد Gate A** ولا يُعدل أي production code قبل موافقة المستخدم
  الصريحة على المصفوفة والسياسة المقترحة لكل حالة.
- لا تُعتبر الموافقة على هذا الملف موافقة مسبقة على نتائج Gate A؛ يلزم عرض
  النتائج الفعلية بعد التدقيق والحصول على موافقة جديدة.
- يجوز تعديل task/QA documentation في Gate A لتسجيل نتائج التدقيق فقط.

### 4.2 نطاق المراجعة

النطاق end-to-end ويشمل:

- Agent work-item transitions.
- runtime notices وأسبابها وأفعالها.
- authoritative execution snapshots وrevision ordering.
- suspended checkpoints وpermission/ask-user decisions.
- startup restore وforce-stop recovery.
- protocol publication عبر local/cloud canonical events.
- Client hydration، event ordering، attention state، sidebar، وبطاقة السؤال.
- daemon-backed E2E بقاعدة وruntime معزولتين.

### 4.3 بيئة إعادة الإنتاج

- يُعاد force-stop داخل test harness/runtime اختبارية معزولة فقط.
- تستخدم كل محاولة `SANAD_STATE_HOME` مؤقتة وفريدة ومزوّد E2E الحتمي.
- لا تفتح قاعدة المستخدم، ولا تستخدم provider حياً، ولا تنفذ `sanad-dev stop`
  أو `sanad-dev switch`.
- أي إعادة إنتاج على runtime المستخدم الحالية تحتاج طلباً وموافقة منفصلة صريحة
  في وقتها؛ هذه المهمة ليست تفويضاً بذلك.

### 4.4 شرط الإصلاح

بعد اعتماد Gate A:

- إذا أعاد E2E إنتاج التضارب، فالإصلاح واختبار الانحدار إلزاميان.
- إذا لم يعد السيناريو الأساسي يُنتج الخلل، لكن التدقيق وجد انتقالاً يخالف
  السياسة أو طريق خروج ناقصاً، فالإصلاح واختباره إلزاميان.
- لا تُغلق المهمة بعبارة “cannot reproduce” اعتماداً على unit tests الحالية
  وحدها؛ يجب إكمال daemon/client scenario المعزول.
- إذا اجتاز السيناريو الكامل ولم توجد مخالفة في أي مسار، لا يُضاف تغيير
  speculative؛ تُسلّم أدلة E2E والمصفوفة المعتمدة، ولا تُغلق المهمة كـno-op إلا
  بموافقة المستخدم الصريحة.

---

## 5. مخرجات Gate A المطلوبة: Blocked-State Decision Matrix

ينشئ المنفذ جدولاً داخل هذا الملف أو design contract، بصف واحد لكل طريق دخول
فعلي إلى `blocked`. كل صف يجب أن يحتوي:

| الحقل | المطلوب |
|---|---|
| Stable case ID | معرف ثابت مثل `BLK-PROVIDER-AUTH` |
| Trigger | الحدث/الخطأ الدقيق الذي يبدأ المسار |
| Source location | الملف، symbol، والمالك |
| From state(s) | الحالات المسموح التحويل منها |
| Durable evidence | البيانات التي تثبت سبب الحجب |
| Why auto-progress is unsafe/impossible | سبب عدم جواز waiting/retry/resume تلقائياً |
| Expected work state | blocked أو بديل مقترح |
| Expected notice | status/reason/title/actions وrun/request ownership |
| Required user action | الفعل الذي يستطيع فعلاً حل الحالة |
| Exit transitions | كل الطرق الخارجة ونتيجتها النهائية |
| Restart behavior | ما يحدث عند restart آخر |
| Client projection | البطاقة/sidebar/composer المتوقعة |
| Stale cleanup | كيف تمنع notice/snapshot القديمة من البقاء |
| Existing tests | أسماء الاختبارات الحالية والفجوات |
| Proposed decision | Keep / Reclassify / Remove / Split |

### قواعد تقييم كل صف

لا يُعتمد أي صف `blocked` إلا إذا:

1. كان السبب durable أو قابلاً لإعادة البناء بعد restart.
2. لم يوجد مسار تلقائي آمن يمكن تمثيله بـ`waiting`.
3. ظهر للمستخدم فعل واحد على الأقل قابل للتنفيذ يحل الحالة أو `Stop` آمن؛ وإذا
   كانت الحالة terminal فعلاً، تُراجع الحاجة إلى `fatal/idle` بدلاً من blocked.
4. كان transition وnotice وexecution snapshot في transaction/ordering يمنع
   projections المتناقضة.
5. كان له exit path مختبر يعيد الجلسة إلى `resuming ثم completed/idle` أو
   `cancelled/idle` دون notice قديمة.
6. لا يستطيع event قديم أو history hydration متأخرة إعادة `blocked` بعد revision
   أحدث.

---

## Gate A — Complete Audit and User Approval

- [ ] تنفيذ بحث شامل لكل writers/readers للقيم الثلاث
      `SessionWorkState.blocked`, `RuntimeNoticeStatus.blocked`, و
      `SessionExecutionState.blocked`.
- [ ] تتبع كل writer إلى trigger، durable owner، notice، protocol، client، وطريق
      الخروج؛ لا يكفي تعداد نتائج grep.
- [ ] مراجعة كل `RuntimeFailureReason.decision()`، بما في ذلك الفرق بين waiting،
      blocked، fatal، وcleared.
- [ ] مراجعة كل catch/fallback يستخدم unknown أو forceBlocked.
- [ ] مراجعة startup restore وinteractive checkpoints وunsafe tool recovery.
- [ ] مراجعة Client precedence بين pending question وblocked notice/snapshot.
- [ ] إكمال Blocked-State Decision Matrix بكل الصفوف والاختبارات والفجوات.
- [ ] تقديم ملخص عربي للمستخدم يبين لكل حالة: Keep / Reclassify / Remove / Split.
- [ ] **التوقف وطلب موافقة المستخدم الصريحة.**

### A Exit — Human Gate

- [ ] وافق المستخدم صراحة على كل صف أو طلب تعديله.
- [ ] سجل تاريخ/ملخص الموافقة والقرارات النهائية في هذا الملف.
- [ ] لم يبدأ أي production implementation قبل الموافقة.

---

## Gate B — Isolated Reproduction Before Fix

لا تبدأ هذه البوابة قبل A Exit.

### السيناريو الإلزامي

1. تشغيل daemon/client اختبارية بقاعدة on-disk مؤقتة ومزوّد حتمي.
2. بدء turn يصل فعلياً إلى `system_ask_user` وتظهر البطاقة للعميل.
3. التحقق قبل الإيقاف من:
   - checkpoint = `awaiting_permission`؛
   - work item تملك tool call والـrun/generation الصحيحين؛
   - UI تعرض pending question؛
   - لا توجد blocked notice.
4. قتل process قسرياً من test harness دون controlled shutdown.
5. تشغيل daemon جديدة على **نفس state home الاختبارية** وإعادة اتصال العميل.
6. إثبات الحالة بعد hydration:
   - work item = `waiting`؛
   - execution snapshot = `waiting`؛
   - pending question موجودة؛
   - لا interrupted/blocked notice؛
   - لا تنفيذ جديد قبل الإجابة.
7. إرسال إجابة البطاقة بنفس request/checkpoint identity.
8. إثبات التسلسل authoritative:
   - claim واحد فقط؛
   - `waiting -> resuming -> completed`؛
   - execution `waiting -> resuming -> idle` بrevisions متزايدة؛
   - حذف checkpoint بعد terminal commit؛
   - حذف/clear أي stale notice مرة واحدة؛
   - final answer واحدة؛
   - Client لا تعرض blocked في أي projection نهائية.
9. إعادة فتح history بعد النجاح لإثبات أن hydration لا تعيد blocked.

### Variants إلزامية

- قاعدة legacy يبدأ فيها نفس ask-user work كـ`blocked` مع notice مقاطعة قديمة.
- إجابة تصل مباشرة بعد reconnect وقبل اكتمال history hydration.
- history blocked قديمة تصل بعد live resuming/idle event ويجب رفضها بالrevision.
- إجابتان متزامنتان لنفس السؤال؛ claimant واحد فقط ولا تضارب.
- permission request غير مجاب عنها، وليس `system_ask_user` فقط.

### B Exit

- [ ] حفظ نتيجة reproduction الدقيقة وأول divergence بين DB/daemon/protocol/client.
- [ ] ربط الخلل بصف/صفوف Gate A المعتمدة.
- [ ] تحديد root cause قبل تعديل production code.

---

## Gate C — Policy and Convergence Fix

لا يبدأ الإصلاح إلا بعد B Exit، ويجب أن يكون أصغر تغيير يعالج root cause
والمصفوفة المعتمدة.

- [ ] إصلاح كل انتقال أثبت التدقيق أنه Reclassify/Remove/Split.
- [ ] منع catch-all من تحويل خطأ إلى blocked دون reason/action/owner صالح.
- [ ] ضمان أن unresolved ask/permission checkpoint تملك `waiting` عند restart.
- [ ] ضمان repair آمن لأي legacy false-block دون تجاوز unsafe-tool evidence.
- [ ] جعل claim + work transition + execution snapshot ذرية عبر aggregate owner.
- [ ] مسح stale notice بحدث واحد ذي ownership صحيح.
- [ ] ضمان terminal commit قبل final delivery ثم execution `idle`.
- [ ] منع history أو event أقدم من إعادة blocked بعد revision أحدث.
- [ ] إبقاء Client projection مشتقة من daemon authority دون heuristics موازية.
- [ ] ضمان Stop/Retry/Change Provider/Open Settings تعمل فعلياً لكل حالة معتمدة.

### C Exit

- [ ] لا يوجد production path إلى blocked خارج المصفوفة المعتمدة.
- [ ] كل blocked لها سبب قابل للتفسير، تدخل مطلوب، وطريق خروج مختبر.
- [ ] لا تتعايش pending question صالحة مع false blocked state.
- [ ] لا تستمر blocked بعد استئناف ناجح أو completion/stop.

---

## Gate D — Verification

### Agent focused coverage

- unit tests لمصنف failure policy لكل reason.
- SQLite-backed tests لكل transition وrestart reconciliation.
- suspended answer tests تؤكد snapshot revisions وnotice clear، لا work row فقط.
- tests لكل catch/fallback وlegacy repair وstale-owner race.

### Client focused coverage

- pending suspended request تتقدم بصرياً على stale blocked projection مؤقتاً،
  مع بقاء daemon revision هي authority النهائية.
- `session.execution_state_changed` الأحدث يمنع history الأقدم من الرجوع.
- notice cleared + idle removes blocked attention من composer/sidebar/session.
- reconnect/hydration ordering variants.

### Daemon-backed E2E

- السيناريو الكامل في Gate B يصبح regression test دائم لا script يدوي فقط.
- كل process وstate home وport مؤقتة ومعزولة.
- force-kill يستهدف process الاختبار فقط.
- لا sequential execution إلا للاختبارات التي تربط ports، وتستخدم حينها
  `--concurrency=1`.

### أوامر التحقق

تنفذ الأوامر ذات الصلة فقط وفق الملفات الفعلية، مع output محدود وexit status
محفوظ:

```bash
# agent/
set -o pipefail; fvm dart analyze 2>&1 | tail -5
set -o pipefail; fvm dart test test/core/provider_runtime/runtime_failure_reason_test.dart 2>&1 | tail -5
set -o pipefail; fvm dart test test/interfaces/interfaces_test.dart 2>&1 | tail -5
set -o pipefail; fvm dart test --concurrency=1 <focused-agent-daemon-backed-test> 2>&1 | tail -5

# client/
set -o pipefail; fvm flutter analyze 2>&1 | tail -5
set -o pipefail; fvm flutter test <focused-attention-and-hydration-tests> 2>&1 | tail -5
set -o pipefail; fvm flutter test --concurrency=1 <focused-client-daemon-backed-e2e> 2>&1 | tail -5
```

يستبدل المنفذ placeholders بالمسارات الفعلية في Handoff ولا يتركها كدليل
تسليم.

### D Exit

- [ ] كل اختبارات policy والمزامنة تمر.
- [ ] force-stop E2E يمر من السؤال حتى final/idle وإعادة hydration.
- [ ] لا تمس الاختبارات runtime أو قاعدة أو provider المستخدم.
- [ ] analyzer للـAgent والـClient يمر.

---

## Gate E — Documentation and Handoff

- [ ] تحديث `docs/technical/agent_interface_runtime.md` بالتعريف والمصفوفة
      المعتمدة دون نسخ تفاصيل الاختبار.
- [ ] تحديث `docs/qa_maintenance/plan30_runtime_recovery_matrix.md` بالسيناريوهات
      النهائية وأسماء الاختبارات الفعلية.
- [ ] تحديث `docs/technical/communication_protocols.md` فقط إذا تغير عقد أحداث
      notice/execution أو ordering.
- [ ] تحديث أقرب `AGENTS.md` فقط إذا تغير قانون دائم أو أصبح نص موجود stale.
- [ ] تشغيل `graphify update .` بعد code changes.
- [ ] ملء Handoff بالأدلة والقرارات المعتمدة والنتائج.

### E Exit / Definition of Done

- [ ] وافق المستخدم على المصفوفة قبل التنفيذ.
- [ ] تمت مراجعة كل حالة تحول session/work/notice إلى blocked.
- [ ] أُصلح السيناريو المرصود إن أعيد إنتاجه وأُصلحت كل مخالفة policy مثبتة.
- [ ] كل blocked المتبقية ضرورية، قابلة للتفسير، ولها تدخل وطريق خروج يعملان.
- [ ] DB/work item/notice/execution snapshot/protocol/client تتقارب بلا حالات
      متضاربة بعد restart أو answer أو retry أو stop.
- [ ] force-stop daemon-backed E2E دائم يثبت السيناريو كاملاً.
- [ ] الوثائق والاختبارات وGraphify متزامنة.

---

## 6. الملفات المتوقعة

تحدد نهائياً بعد Gate A وB؛ القائمة الحالية نطاق مراجعة لا تفويض لتعديلها كلها:

### Agent

- `agent/lib/core/provider_runtime/runtime_failure_reason.dart`
- `agent/lib/core/provider_runtime/runtime_recovery_service.dart`
- `agent/lib/engine/runtime/continuation_checkpoint_coordinator.dart`
- `agent/lib/interfaces/runtime/session_recovery_restorer.dart`
- `agent/lib/interfaces/runtime/suspended_resume_service.dart`
- `agent/lib/interfaces/runtime/session_turn_executor.dart`
- `agent/lib/evolution/db/runtime/session_execution_state_coordinator.dart`
- اختبارات `agent/test/core/`, `agent/test/interfaces/`, وdaemon-backed test مناسب

### Client

- `client/lib/features/conversations/data/transport/conversation_event_handler.dart`
- `client/lib/features/conversations/domain/models/session_attention_state.dart`
- `client/lib/features/conversations/domain/stores/device_conversation_store.dart`
- focused unit/widget tests وdaemon-backed E2E مناسب

### Documentation

- `docs/plans/tasks/66-blocked-session-policy-audit-and-suspended-recovery-convergence.md`
- `docs/technical/agent_interface_runtime.md`
- `docs/qa_maintenance/plan30_runtime_recovery_matrix.md`
- `docs/technical/communication_protocols.md` عند تغير protocol فقط

---

## 7. Handoff Evidence

### Gate A approval

- **Matrix location:** pending
- **User-requested changes:** pending
- **Explicit approval:** pending

### Reproduction and root cause

- **Isolated runtime:** pending
- **Observed divergence:** pending
- **Root cause:** pending

### Implementation and verification

- **Changed files:** pending
- **Agent tests/analyzer:** pending
- **Client tests/analyzer:** pending
- **Daemon-backed E2E:** pending
- **Graphify update:** pending
- **Known limitations:** pending
