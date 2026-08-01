---
title: "Work Item Terminal Commit and Safe Admission Consistency"
description: "منع final/error المتناقض، وحماية استقبال الرسالة التالية من active-work races وUNIQUE constraint وانهيار daemon."
status: "completed"
completed_at: "2026-07-15"
scope: "agent engine and runtime interfaces"
depends_on: "Task 31 authoritative session state"
---

# Task 35: Work Item Terminal Commit and Safe Admission Consistency

## 1. نتيجة إعادة التقييم بعد Task 31

أغلقت Task 31 جزءًا من المشكلة الأصلية:

- يوجد unique partial index يضمن work item نشطة واحدة فقط لكل جلسة؛ لذلك لم
  يعد ترتيب `findActiveWorkItem` أو إضافة `ORDER BY` جزءًا مطلوبًا من هذه المهمة.
- الاستكمال الشرعي يمر من `waiting` إلى `resuming` قبل `completed`.
- انتقال callback قديمة يرفض إذا لم تعد تملك `work_item_id` الحالية.
- لا يجوز تطبيع `waiting` أو `blocked` إلى `completed` قسرًا؛ تغير الحالة إلى
  إحداهما يعني أن recovery أصبحت المالك ويجب ألا يغلقها مسار terminal قديم.

لكن بقي سباق عند حد الإنهاء: يبث `SessionTurnExecutor` final response ثم يحاول
نقل work item إلى `completed`. إذا تغيرت الحالة قبل النقل إلى `waiting` أو
`blocked`، يرفض state machine الانتقال وقد يدخل executor إلى مسار الخطأ بعد أن
رأى المستخدم الجواب النهائي. المطلوب منع نتيجة `final ثم error`، لا فتح انتقالات
غير آمنة داخل state machine.

## 2. العقد المطلوب

1. تظل الانتقالات المباشرة `waiting -> completed` و`blocked -> completed`
   ممنوعة.
2. لا يصدر final transport event إلا بعد نجاح terminal commit للجولة المالكة.
3. يتحقق terminal commit من `session_id + work_item_id + run_id/generation`
   ومن أن الحالة الحالية `running` أو `resuming`.
4. تكون رسالة المساعد النهائية محفوظة بصورة idempotent قبل إغلاق work item،
   بحيث لا يؤدي crash بعد الحفظ إلى فقد النتيجة أو إعادة أداة ذات side effect.
5. إذا أصبحت work item `waiting` أو `blocked` قبل terminal commit:
   - لا تنقل إلى `completed`.
   - لا يصدر final جديد ولا error لاحق بسبب رفض الانتقال.
   - تبقى recovery والحالة الدائمة كما هما.
   - أي partial output سبق بثه يبقى partial ولا يقدم كجواب نهائي ناجح.
6. إذا فشلت كتابة terminal commit نفسها، يصدر outcome خطأ واحد منضبط قبل أي
   final، وتبقى work item قابلة للاستعادة.
7. لا يمكن لجولة قديمة إغلاق أو بث terminal result لجولة أحدث.
8. قرار قبول رسالة جديدة يقرأ active work الدائمة، ولا يعتمد على خرائط
   `_busySessions` و`_suspendedEvents` وحدها.
9. إذا بقيت work item في `running`, `resuming`, `waiting`, أو `blocked`، تدخل
   الرسالة الجديدة queue ولا تحاول إنشاء work item ثانية بحالة `running`.
10. يكون فحص active work وإنشاء running/queued item داخل owner ذرية واحدة. إذا
    كشف unique index سباقًا، يعيد owner التصنيف إلى queued أو outcome منضبطة؛
    لا يخرج `SqliteException` إلى event loop.
11. خطأ command منفرد لا يسقط daemon ولا يترك قبول الرسالة بلا confirmation.

## 3. نطاق التنفيذ

### Gate A — Terminal commit owner

- [x] إضافة owner واحدة لقرار terminal commit بدل أن يوزع executor التحقق
      والحفظ والانتقال والبث في خطوات مستقلة.
- [x] جعل نتيجة owner صريحة: `committed`, `stale_owner`,
      `recovery_owns_state`, أو `persistence_failed`.
- [x] استخدام `transitionOwnedWorkItem` أو API أدق منه مع تحقق الحالة المتوقعة،
      دون السماح بانتقالات جديدة من waiting/blocked إلى completed.
- [x] توثيق أن unique active-work index هو invariant الذي يغني عن اختيار صف
      نشط بترتيب اصطناعي.

### Gate B — ترتيب الحفظ والبث

- [x] تجهيز final response دون بثه أولًا.
- [x] التأكد أن assistant result محفوظ idempotently بهوية الجولة.
- [x] تنفيذ terminal commit للحالة الدائمة.
- [x] بث final مرة واحدة فقط عند `committed`.
- [x] عدم تحويل `stale_owner` أو `recovery_owns_state` إلى user-visible error.
- [x] تحويل `persistence_failed` إلى error واحد مع بقاء العمل قابلًا للاستعادة.

### Gate C — Safe admission after terminal failure

- [x] جعل durable work state جزءًا من قرار `isSessionBusy`/message admission،
      مع بقاء خرائط الذاكرة projection وليست مصدر الحقيقة الوحيد.
- [x] جمع فحص active work وإنشاء running أو queued work item داخل transaction
      واحدة تمنع check-then-insert race.
- [x] عند وجود waiting أو blocked دائمة مع غياب busy flag في الذاكرة، إدخال
      الرسالة التالية queued وإصدار acceptance طبيعية لها.
- [x] التقاط unique active-work conflict داخل admission owner وإعادة القراءة
      والتصنيف بأمان، بدل إنهاء isolate.
- [x] حماية `GatewayManager` من Future errors غير المعالجة بحيث يتحول فشل
      command غير المتوقع إلى response منضبطة ويبقى daemon يعمل.

### Gate D — Regression coverage

- [x] اختبار running وresuming الطبيعيين: terminal commit ناجح، final واحد،
      ولا error.
- [x] اختبار تغير work item إلى waiting قبل حد الإنهاء: لا completed ولا
      final+error contradiction.
- [x] اختبار تغيرها إلى blocked قبل حد الإنهاء بنفس الضمان.
- [x] اختبار callback متأخرة من generation قديمة بعد بدء جولة جديدة.
- [x] اختبار فشل persistence عند terminal commit: لا final سابق للخطأ ولا
      حذف للعمل القابل للاستعادة.
- [x] الإبقاء على اختبار الاستكمال الناجح `waiting -> resuming -> completed`.
- [x] إعادة إنتاج التسلسل الفعلي: terminal transition تبقى waiting، ثم تصل
      رسالة جديدة؛ تثبت أنها queued، ولا توجد active item ثانية، ولا يحدث
      `UNIQUE constraint`، ويبقى daemon/event loop حيًا.
- [x] اختبار سباق تغير active state بين preflight وinsert يثبت أن unique index
      يؤدي إلى إعادة تصنيف منضبطة لا exception غير معالجة.
- [x] بعد حسم recovery، تنفذ الرسالة queued مرة واحدة وبـrequest id نفسها.

### Gate E — Documentation and verification

- [x] تحديث عقد terminal delivery في `docs/technical/agent_runtime.md`.
- [x] تحديث مصفوفة QA لتشمل منع final/error المزدوج لنفس الجولة.
- [x] نجاح تحليل agent والاختبارات المركزة ثم fast suite بسبب أثر التغيير على
      executor وrecovery المشتركين.

## 4. الملفات المتوقعة

- `agent/lib/interfaces/runtime/session_turn_executor.dart`
- `agent/lib/interfaces/runtime/session_run_orchestrator.dart`
- `agent/lib/interfaces/runtime/session_queue_coordinator.dart`
- `agent/lib/interfaces/gateway_manager.dart`
- `agent/lib/evolution/db/runtime/session_execution_state_coordinator.dart`
- `agent/lib/evolution/db/runtime/session_work_item_repository.dart`
- `agent/lib/core/provider_runtime/runtime_recovery_service.dart` للتكامل فقط
- اختبارات executor وruntime state وواجهات orchestrator
- `docs/technical/agent_runtime.md`
- `docs/qa_maintenance/plan30_runtime_recovery_matrix.md`

## 5. معايير القبول

- [x] لا يرى العميل final ثم error بسبب رفض terminal state transition.
- [x] لا تنتقل waiting أو blocked مباشرة إلى completed.
- [x] final يصدر مرة واحدة فقط بعد terminal commit ناجح للجولة المالكة.
- [x] stale callbacks لا تغير الحالة ولا تبث terminal outcome.
- [x] فشل persistence يبقي العمل قابلًا للاستعادة ولا يعرض نجاحًا كاذبًا.
- [x] الاستكمال الطبيعي ينتهي `resuming -> completed` كما هو.
- [x] الرسالة التالية لعمل عالق في waiting/blocked تدخل queue ولا تنشئ running
      ثانية ولا تسقط daemon.
- [x] لا يصل `SqliteException` الخاص بتفرد active work إلى event loop.
- [x] بعد recovery تنفذ الرسالة المحفوظة مرة واحدة.

## 6. خارج النطاق

- تغيير state machine للسماح بـ`waiting/blocked -> completed`.
- إضافة ترتيب إلى `findActiveWorkItem`؛ التفرد مضمون بقاعدة البيانات.
- تغيير سياسة queue أو steer أو Stop draft recovery؛ تملكها Task 36.
- تغيير واجهة Flutter.
