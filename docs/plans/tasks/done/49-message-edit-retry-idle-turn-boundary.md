---
title: "Task 49: Message Edit and Retry Idle Turn Boundary"
description: "تثبيت تجربة تعديل الرسائل وإعادة المحاولة بحيث تلغي أي turn نشطة أو blocked أولًا، وتحول الجلسة إلى idle قبل بدء turn جديدة، مع حماية من إعادة تنفيذ أدوات ذات أثر جانبي."
status: "completed"
completed_at: "2026-07-18"
priority: "high"
scope: "Sanad agent runtime contracts and Flutter client conversation UI"
depends_on: "Task 31 authoritative session state, Task 34 partial stream recovery safety, Task 36 queued/steer/stop recovery"
---

# Task 49: Message Edit and Retry Idle Turn Boundary

## 1. المشكلة

تعديل رسالة مستخدم أو إعادة محاولة آخر turn قد يحدثان بينما الجلسة ليست idle:
قد تكون `running`, `waiting`, `blocked`, `resuming`, أو في حالة إيقاف انتقالية.
بدء turn جديدة فوق حالة نشطة أو blocked يخلق سباقات بين stop/retry/edit، وقد
يعيد تشغيل أجزاء من الجولة السابقة أو يترك حالة runtime قديمة ظاهرة في الواجهة.

في الواجهة، يجب أن تتحول الرسالة المراد تعديلها إلى محرر inline في مكانها داخل
timeline. إذا انتقل المستخدم إلى محادثة أخرى قبل الضغط على Send، يجب إلغاء
التعديل كأنه ضغط Cancel. حاليًا يجب تثبيت هذا كسلوك عقدي لا كمصادفة UI محلية.

إعادة المحاولة أخطر من التعديل العادي لأن الجولة السابقة قد تكون نفذت أدوات.
إذا احتوى آخر turn على أدوات تغيّر ملفات أو أنظمة خارجية، فقد تؤدي إعادة
المحاولة إلى تكرار الأثر الجانبي. لذلك يجب طلب تأكيد من المستخدم قبل retry/edit
الذي يعيد تشغيل turn ذات أدوات side-effect.

## 2. الهدف

1. تقديم تجربة edit inline واضحة: الرسالة نفسها تتحول إلى input قابل للتعديل،
   مع زري `Send` و`Cancel` أسفل المدخل من جهة اليسار.
2. إلغاء edit draft تلقائيًا عند تغيير الجلسة أو الجهاز أو مغادرة المحادثة قبل
   الضغط على Send.
3. جعل edit وretry يبدآن دائمًا من جلسة idle: إذا كانت للجلسة turn نشطة أو
   blocked، يرسل النظام stop/cancel أولًا وينتظر اكتمال التحول إلى idle.
4. توحيد ترتيب العمليات: `stop active or blocked turn -> recompute idle -> edit/retry turn`.
5. منع retry غير آمن عندما يحتوي turn السابق على أدوات ذات أثر جانبي إلا بعد
   تأكيد صريح من المستخدم.
6. استخدام المزود والنموذج المعروضين حاليًا في الواجهة وقت ضغط Send/Retry،
   وليس بالضرورة المزود والنموذج اللذين نفذا الجولة الأصلية.
7. الحفاظ على عقود Task 31/34/36: لا re-run غامض، لا ازدواج أدوات، ولا استنتاج
   UI لحالة التنفيذ بدل snapshot authoritative من daemon.

## 3. قرارات التصميم

- `Edit` حالة UI عابرة مرتبطة بـ`device_id + session_id + message_id`.
- لا تنتقل حالة edit بين الجلسات. أي navigation خارج الجلسة المالكة يلغيها.
- `Cancel` يعيد timeline إلى الرسالة الأصلية دون socket command.
- `Send` على edit لا يبدأ turn مباشرة إذا كانت الجلسة غير idle؛ يجب المرور
  عبر مسار stop/cancel authoritative أولًا.
- `Retry` و`Edit Send` يستخدمان نفس بوابة idle boundary.
- `blocked` ليست idle. يجب إلغاء work item المحفوظ أو تحويله إلى terminal/cancelled
  قبل بدء turn جديدة.
- stop/cancel يجب أن يكون scoped للجلسة والـwork item المالكة فقط، ولا يمس queued
  أو active work في جلسات أخرى.
- إذا كان turn السابق يحتوي tool calls مصنفة side-effect أو replay-unsafe، تعرض
  الواجهة تأكيدًا قبل retry/edit send.
- إذا تعذر معرفة side-effect safety، يعامل النظام turn كغير آمن ويطلب تأكيدًا.
- edit/retry لا يعيدان استخدام route الجولة الأصلية تلقائيًا. عند dispatch يجب
  إرسال `provider_instance_id` و`model_id` الحاليين كما تعرضهما الواجهة في تلك
  اللحظة، مع fallback منظم فقط إذا كان الاختيار الحالي غير معروف أو غير صالح.

## 4. بوابة التنفيذ

لا يبدأ التنفيذ قبل إغلاق هذه البوابة:

- [x] مراجعة state graph في Task 31 لحالات `idle`, `queued`, `running`,
      `waiting`, `blocked`, `resuming`, `stopping`.
- [x] مراجعة Task 34 لتصنيف tool replay safety والآثار الجانبية.
- [x] مراجعة Task 36 لعقود stop recovery وqueued/steer cancellation.
- [x] تحديد الأمر أو العقد المستخدم لتحويل `blocked` وactive work إلى cancelled
      قبل retry/edit.
- [x] تحديد payload المطلوب لـedit/retry turn، وهل هو command جديد أو توسيع
      لأمر موجود.
- [x] تحديد مصدر الاختيار الحالي للمزود والنموذج في الواجهة وكيف يمر atomically
      مع أمر edit/retry.
- [x] تحديد مصدر معرفة “آخر turn يحتوي أدوات side-effect” في history أو metadata
      أو execution snapshot.
- [x] اعتماد نص confirmation ومتى يظهر ومتى لا يظهر.

## 5. النطاق المرحلي

### Gate A — Runtime idle boundary contract

- [x] تعريف helper أو protocol path موحد: `ensureSessionIdleBeforeNewTurn`.
- [x] إذا كانت الجلسة `running|waiting|blocked|resuming` يرسل cancel/stop scoped.
- [x] الانتظار حتى يصدر daemon snapshot يؤكد `idle` أو terminal cancellation.
- [x] منع بدء edit/retry turn إذا بقيت الجلسة `stopping` أو `blocked`.
- [x] جعل المسار idempotent عند ضغط المستخدم أكثر من مرة أو وصول snapshot متأخر.

#### Gate A Exit

- [x] لا يمكن لأي retry/edit أن يبدأ turn جديدة قبل idle authoritative.
- [x] إلغاء work في جلسة A لا يؤثر على جلسة B.

### Gate B — Side-effect replay confirmation

- [x] تعريف تصنيف side-effect tool calls داخل turn السابق:
      `safe`, `unsafe`, `unknown`.
- [x] استخراج التصنيف من metadata/history/execution snapshot دون قراءة UI تخمينية.
- [x] عرض تأكيد قبل retry/edit send عندما التصنيف `unsafe|unknown`.
- [x] إذا رفض المستخدم التأكيد، لا يرسل stop ولا retry/edit.
- [x] إذا وافق المستخدم، يمر الطلب عبر Gate A قبل بدء turn جديدة.

#### Gate B Exit

- [x] لا يمكن إعادة تشغيل turn ذات أدوات unsafe أو unknown دون موافقة صريحة.
- [x] الأدوات safe لا تعرض تأكيدًا زائدًا.

### Gate C — Client inline edit UX

- [x] إضافة action لتعديل user message المؤهلة.
- [x] تحويل bubble الرسالة إلى input في نفس موضعها داخل timeline.
- [x] عرض `Send` و`Cancel` أسفل input من جهة اليسار.
- [x] `Cancel` يلغي الحالة محليًا دون تغيير الرسالة.
- [x] تغيير session/device/route أثناء التحرير يلغي edit كأن المستخدم ضغط Cancel.
- [x] تعطيل edit أثناء انتظار idle boundary أو confirmation لمنع dispatch مزدوج.

#### Gate C Exit

- [x] edit state لا يتسرب بين الجلسات أو الأجهزة.
- [x] timeline يعود للشكل الطبيعي عند cancel أو navigation.

### Gate D — Retry and edited-turn dispatch

- [x] توحيد retry وedit send في مسار dispatch واحد بعد idle boundary.
- [x] تمرير المزود والنموذج الحاليين من الواجهة مع retry/edit، وعدم افتراض route
      الجولة الأصلية.
- [x] إذا تغير اختيار النموذج أثناء انتظار idle boundary أو confirmation، يستخدم
      dispatch الاختيار الأحدث وقت التأكيد النهائي من المستخدم.
- [x] تحديد الرسائل التي تزال أو تعاد كتابتها بعد edit/retry وفق history contract.
- [x] تحديث session cache/live store دون حذف أحداث غير مملوكة للجولة المعاد تشغيلها.
- [x] منع retry إذا كانت history غير كافية لتحديد turn boundary.
- [x] ضمان أن queued messages الحالية لا تختلط مع retry/edit turn الجديدة.

#### Gate D Exit

- [x] retry/edit يعيدان تشغيل turn محددة فقط.
- [x] لا يحدث duplicate user message أو final answer بسبب race مع history/live events.

### Gate E — Verification and documentation

- [x] اختبارات agent لمسار active -> stop -> idle -> retry/edit.
- [x] اختبارات agent لمسار blocked -> cancel -> idle -> retry/edit.
- [x] اختبارات tool replay safety: safe, unsafe, unknown, user confirms, user cancels.
- [x] اختبارات client widget لتحويل الرسالة إلى input وأزرار Send/Cancel.
- [x] اختبارات client navigation لإلغاء edit عند تغيير session/device.
- [x] اختبارات cubit/store لعدم تسرب edit state بين الجلسات.
- [x] اختبار تكامل محلي فقط إذا تغير عقد socket/daemon command فعليًا.
- [x] تحديث وثائق product/technical/QA والعقود المحلية المتأثرة.

#### Gate E Exit

- [x] التحليل والاختبارات المركزة المناسبة للـblast radius ناجحة.
- [x] لا توجد E2E إلا إذا تغير عقد runtime/socket أو ظهرت حاجة لا تغطيها mocks.

## 6. معايير القبول

- [x] الضغط على Edit يحول الرسالة إلى input inline في مكانها.
- [x] تظهر أزرار `Send` و`Cancel` أسفل input من جهة اليسار.
- [x] الضغط على Cancel أو الانتقال إلى جلسة أخرى يلغي التعديل دون أثر runtime.
- [x] الضغط على Send أثناء جلسة غير idle يوقف/يلغي الجولة المالكة أولًا وينتظر idle.
- [x] Retry يتبع نفس ترتيب stop/cancel ثم idle ثم dispatch.
- [x] `blocked` لا تعد idle ولا يبدأ retry/edit فوقها.
- [x] retry/edit يستخدمان المزود والنموذج الحاليين في الواجهة عند الإرسال، لا
      route الجولة الأصلية.
- [x] لا تكرر retry/edit أدوات ذات side-effect دون تأكيد المستخدم.
- [x] إذا رفض المستخدم تأكيد side-effect، لا يرسل أي stop أو retry/edit.
- [x] لا تتأثر الجلسات الأخرى أو turns أحدث لا تملكها العملية.

## 7. خارج النطاق

- إعادة تصميم كامل timeline أو composer.
- تعديل بروتوكول tools registry نفسه.
- جعل كل الأدوات idempotent؛ هذه المهمة تكتفي بالتصنيف والتحذير.
- fork conversation أو branch history مستقل؛ هذه ميزة منفصلة.
- E2E إلزامي لكل تغييرات UI؛ يظل E2E حسب نطاق العقد فقط.

## 8. الملفات المتوقعة

- `agent/lib/interfaces/runtime/` لمسار idle boundary والـcommands إن لزم.
- `agent/lib/evolution/db/` أو repositories المالكة لـwork items/history عند الحاجة.
- `client/lib/features/conversations/` لحالة edit والـtimeline actions.
- `client/test/` و`agent/test/` للاختبارات المركزة.
- `docs/product/`, `docs/technical/`, و`docs/qa_maintenance/` للوثائق المالكة
  بعد اعتماد التنفيذ.

## 9. سجل التقدم

- الحالة الأولية: `planned`.
- أغلقت بوابة التنفيذ باعتماد `session.turn_replay` كعقد مستقل عن runtime recovery، وربطه بحد turn خام عبر `target_request_id`.
- التنفيذ الحالي يقصر Edit/Retry على آخر user turn موثوقة حتى لا يحذف turns أحدث يملكها المستخدم.
- تصنيف replay هو `safe|unsafe|unknown` من tool calls وmetadata الدائمة؛ `unsafe|unknown` يعيدان `confirmation_required` قبل أي Stop.
- بعد الموافقة ينفذ daemon الترتيب `stop scoped work -> require authoritative idle -> revalidate boundary -> truncate -> dispatch`.
- أضيفت تجربة inline وأزرار Send/Cancel وإلغاء التحرير عند navigation، مع تمرير route الحالية عند الطلب النهائي.
- نجحت تحليلات agent/client والاختبارات المركزة واختبار local-daemon E2E لعقد replay والتأكيد fail-closed.
- الحالة: `completed` بعد نجاح التحقق الآلي واعتماد الإغلاق والنقل إلى `done`.
