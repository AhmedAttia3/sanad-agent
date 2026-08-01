---
title: "Background Terminal Task Runtime"
description: "العقد التقني للمهام الطرفية الخلفية المملوكة، والنقل الذري من الجولة، والـPTY والمخرجات، والإيقاظ، والتفاعل الآمن، والتعافي."
---

# Background Terminal Task Runtime

## 1. الغرض وحد الإصدار الأول

عندما يتجاوز أمر shell حد foreground، يستطيع Sanad نقل ملكيته إلى supervisor
خلفية وإرجاع `task_id` كي تصبح جلسة الوكيل idle مع استمرار الأمر.

القيمة الافتراضية لـ`background_after_ms` هي 30000، ويمكن للوكيل زيادتها أو
تقليلها، و`0` تعني النقل الفوري. تبقى `timeout_ms` مهلة التشغيل الكلية حتى بعد
النقل. يحفظ daemon السجل والمخرجات، لكن العملية لا تستمر ولا تُتبنى بعد إعادة
تشغيل daemon في الإصدار الأول.

## 2. الحالة والملكية

```text
starting
  -> running_foreground
  -> handoff_claiming
  -> running_background
  -> cancelling
  -> completed | failed | cancelled | timed_out | interrupted | cleanup_failed
```

كل سجل غير نهائي يحمل:

- `task_id`, `session_id`, `origin_run_id`, `origin_tool_call_id`.
- `owner_generation`, `revision`, وcontainment fingerprint.
- timestamps للبدء والنقل وآخر output والحالة النهائية.
- cursor مطلق وحد retention للمخرجات.

الانتقالات النهائية compare-and-set ولا تتراجع. لا توجد task بلا جلسة مالكة،
ولا تحذف الجلسة قبل terminalization لكل مهامها النشطة.

## 3. النقل الذري

يحدث handoff بهذا الترتيب:

1. يبدأ الأمر كـforeground resource مسجلة في نطاق إلغاء الجولة.
2. عند بلوغ الحد، ينشأ سجل task وclaim للـowner generation الجديدة.
3. تتبنى supervisor المقبولة process handle وI/O وtimeout.
4. بعد ثبوت claim فقط، تحرر registration من نطاق الجولة.
5. تعاد نتيجة typed فيها `task_id`, status, cursor, preview, ووقت النقل.

إذا انتهى الأمر أثناء النقل تفوز terminal compare-and-set واحدة. إذا فشل
الحفظ أو supervisor admission، تبقى العملية foreground وقابلة للإلغاء؛ لا
توجد نافذة بلا مالك.

## 4. Supervisor وPTY

supervisor هي المالك الوحيد للعملية بعد النقل، وتدير:

- stdin وresize وwait وtimeout وcancel.
- output journal وcursor وretention.
- process containment وwatchdog.
- terminal transition والحدث النهائي.

حالات admission هي `accepting | draining | stopped`. حدود device/session
مركزية، والرفض typed مثل `capacity_exceeded` أو `daemon_draining` من دون queue
خفية.

تعلن adapter قدراتها الفعلية: PTY،resize،DSR،normal/application cursor keys،
bracketed paste،keys،submit،وEOF. fallback غير تفاعلية لا تدعي دعم stdin
التفاعلية.

## 5. سجل المخرجات وإعادة التشغيل الحي

كل bytes تزيد cursor مطلقًا. تحتفظ supervisor بحلقة ذاكرة صغيرة وسجل قرص
مدوّر ومحدود الحجم والعمر. يحمل snapshot:

```text
task_id, revision, status
retained_from_cursor, next_cursor
chunks, truncated
```

عند الاشتراك:

1. تلتقط supervisor نهاية replay.
2. تجمع chunks الجديدة في pending buffer.
3. ترسل replay وmetadata.
4. بعد تأكيد activation، تفرغ pending بالترتيب ثم تبدأ live.

يُflush آخر output قبل terminal DB transition. طول الصمت يحدث attention notice
ولا يلغي المهمة افتراضيًا؛ الإلغاء بسبب غياب output يعمل فقط عند مهلة صريحة.

## 6. أدوات الوكيل

- `view_task(task_id?, cursor?)`: snapshot وdelta أو قائمة مهام الجلسة.
- `write_task(task_id, mode, data?)`: modes هي `text`, `keys`, `paste`,
  `submit`, `eof`.
- `cancel_task(task_id)`: إلغاء idempotent عبر supervisor.
- `timer_to_wake(after_ms, task_ids?)`: one-shot wake مرتبط بالجلسة.

تتحقق الأدوات من `session_id` في `ToolContext`; معرفة ID ليست صلاحية. نتيجة
`view_task` هي schema نفسها المستخدمة في wake payload لتجنب اختلاف العرض.

## 7. wake وtyped pending steer

كل completion أو timer أو restart reconciliation ينشئ trigger دائمًا قبل
scheduling:

```text
scheduled -> pending -> delivering -> delivered
                   \-> suppressed | cancelled
```

يحمل trigger dedupe key وtask revision. إذا كانت الجلسة idle تبدأ drain واحدة.
إذا كانت busy، يصبح الحدث typed pending steer ويضبط `pendingWake` advisory؛ لا
يدخل FIFO queue ولا يبدأ run ثانية. تتم promotion عند أول safe boundary وفق
مالك admission القائم.

تسبق terminal task persistence إنشاء completion wake. completion وtimer لنفس
revision يندمجان، والـtimer التي لا تضيف snapshot جديدة يمكن suppress لها.

## 8. التفاعل والأسرار

الـstdin العادية من الوكيل أو المستخدم تمر كأحداث typed وتخضع للملكية. secure
input من المستخدم تسلك client-to-daemon-to-PTY مباشرة:

- لا تدخل model context أو conversation history.
- لا تحفظ في state أو output journal.
- لا تظهر في logs أو analytics أو crash diagnostics.
- تمسح من client memory بعد التسليم أو الخطأ أو مغادرة العرض.

تعرض الواجهة command منقحة فقط، ولا تعيد echo لقيمة سرية.

## 9. العرض والحذف

تعرض المحادثة مهام session فوق composer مع status والمدة وpreview وattention
والتحكم. يعرض Activity Monitor عدد المهام غير النهائية على الجهاز وقائمة
عابرة للجلسات، مع بقاء كل عملية تحكم خاضعة لملكية daemon.

حذف جلسة ذات مهام نشطة يتطلب موافقة المستخدم. يلغي daemon المهام، يثبت
terminalization، ثم يحذف transactionally. cleanup failure يمنع الحذف ويحتفظ
بالمالك والسجل.

## 10. shutdown وrestart

عند graceful shutdown تتحول supervisor إلى `draining`، ترفض spawns، تنتظر
transitions المحدودة، ثم تلغي الباقي قبل إغلاق قاعدة البيانات. يقتل watchdog
containments عند فقد owner lifetime.

عند startup تصبح سجلات owner generation السابقة `interrupted` بعد reconciliation.
لا يعاد ربط PID ولا تنفيذ command. تستخدم fingerprint لمنع قتل عملية لا تعود
للمهمة، ثم ينشأ recovery wake واحدة لكل session متأثرة.

## 11. محددات التحقق

- الأمر القصير يبقى foreground، والطويل يعيد `task_id` دون توقفه.
- handoff/exit وtimeout/cancel races تنتج terminal واحدة.
- disconnect/replay لا يفقد ولا يكرر bytes.
- secure input لا يظهر في أي سطح دائم أو model-visible.
- task completion أثناء busy تصبح pending steer لا queue ولا run موازية.
- daemon crash لا يترك containment مملوكة ولا يتبنى process قديمة.
- حذف session لا يترك task أو process بلا مالك.
- retention وcapacity وdraining تبقى محدودة وقابلة للقياس.
