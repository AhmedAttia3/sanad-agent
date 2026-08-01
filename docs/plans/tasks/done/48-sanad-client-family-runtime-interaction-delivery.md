---
title: "Sanad Client Family Runtime Interaction Delivery"
description: "توحيد ظهور runtime notices وطلبات التعليق وإجراءات الاسترداد عبر واجهات Sanad Client المحلية والسحابية، مع إبقاء الـbackend راوترًا عامًا واستخدام device_command الحالي."
status: "completed"
priority: "high"
scope: "Sanad Agent and Flutter Client conversation runtime interactions"
depends_on: "Task 31 authoritative session state and Task 30 runtime recovery"
---

# Task 48: Sanad Client Family Runtime Interaction Delivery

## 1. المشكلة

توجد ثلاثة اختلالات مترابطة في تفاعلات المحادثة الحية بين Sanad Agent وواجهات
Sanad Client المحلية والسحابية:

1. يصل `session.runtime_notice` إلى العميل السحابي وتظهر علامة الانتباه في
   القائمة الجانبية، لكن بطاقة الخطأ داخل الجلسة المفتوحة لا تتحدث فورًا. تظهر
   البطاقة بعد الانتقال إلى محادثة أخرى والعودة، ما يثبت أن حالة الجهاز
   والترطيب اللاحق صحيحان وأن الخلل في إسقاط الحالة الحية على presentation
   الخاصة بالجلسة النشطة.
2. يحتفظ `PlatformRuntimeBridge` بقناة واحدة لكل `session_id`. يؤدي تسجيل قناة
   محلية أو سحابية إلى استبدال القناة السابقة، ولذلك قد يصل
   `tool_permission_request` أو سؤال `system_ask_user` إلى آخر واجهة سُجلت فقط،
   رغم أن جميع واجهات Sanad Client يجب أن تعامل كعائلة منصة منطقية واحدة.
3. ترسل بعض إجراءات الاسترداد والردود التفاعلية من العميل السحابي كـ
   `protocol_event` مباشر، بينما لا يمرر الـbackend هذا المسار إلى الجهاز.
   تظهر الأزرار في الواجهة لكن `Retry` و`Change Provider` والرد على طلب التعليق
   قد لا تصل إلى Sanad Agent.

تعالج هذه المهمة المشكلات الثلاث معًا دون أي تعديل في الـbackend.

## 2. القيود المعمارية

- يبقى الـbackend راوترًا عامًا لا يعرف أسماء أحداث runtime أو معانيها.
- يمنع تعديل `backend/` ضمن هذه المهمة.
- تستخدم الإجراءات الصادرة من Sanad Client مسار `device_command` الحالي، مع
  `device_id` صريح وغلاف payload موحد للاتصال المحلي والسحابي.
- يملك Sanad Agent وحده تفسير الأمر وسياسة توصيل الأحداث الناتجة عنه.
- تظل تصفية `device_id` في العميل فعالة؛ لا يسمح بتجاوزها للأحداث التفاعلية.
- تعامل واجهات Sanad Client المحلية والسحابية والويب والموبايل مستقبلًا كعائلة
  منطقية واحدة: `PlatformFamily.sanadClient`.
- المنصات الخارجية المستقبلية، مثل Telegram وWhatsApp، تبقى origin-scoped ولا
  تستقبل أحداثًا تخص origin آخر.
- لا يبدأ التعديل التنفيذي قبل إكمال واعتماد Gate A.

## 3. عقد التوجيه المطلوب

يحدد runtime سياسة التوصيل من `OriginContext` المالكة للتشغيل:

```text
origin.platformFamily == sanadClient
  → DeliveryPolicy.platformFamily(PlatformFamily.sanadClient)

أي platform family خارجية
  → DeliveryPolicy.origin(...)
```

ينطبق ذلك على أحداث المحادثة التفاعلية، وبخاصة طلبات الإذن والأسئلة المعلقة:

| أصل التشغيل | الوجهة المطلوبة |
|---|---|
| Sanad Client محلي | جميع واجهات Sanad Client المحلية والسحابية |
| Sanad Client سحابي | جميع واجهات Sanad Client المحلية والسحابية |
| Telegram مستقبلًا | نفس Telegram origin فقط |
| WhatsApp مستقبلًا | نفس WhatsApp origin فقط |

يجب ألا يعتمد الاختيار على آخر socket أو channel سُجلت للجلسة.

## 4. عقد حسم طلبات التعليق

- تحمل كل نسخ طلب التعليق الموجهة إلى Sanad Client نفس `event_id` و`request_id`
  و`session_id` والمحتوى canonical نفسه.
- يسمح بعرض الطلب في كل واجهات Sanad Client المؤهلة.
- أول رد صحيح يصل إلى Sanad Agent يحسم الطلب ويستأنف التشغيل مرة واحدة فقط.
- يغلق Sanad Agent الطلب ذريًا قبل بدء الاستئناف، بحيث لا تستطيع إجابتان
  متزامنتان الفوز بالطلب نفسه.
- ترفض أي إجابة لاحقة لنفس `request_id` بنتيجة authoritative منظمة مثل
  `already_resolved`؛ لا تعدل القرار المحفوظ ولا تعيد الاستئناف أو تنفيذ الأداة.
- بعد الحسم، يبث Sanad Agent نتيجة resolved/cleared authoritative إلى عائلة
  Sanad Client حتى تمسح كل الواجهات الطلب المعلق وتعطل أي عناصر رد متبقية.
- إذا ضغطت واجهة أخرى قبل وصول resolved/cleared إليها، يعيد Agent نتيجة
  `already_resolved` وتزيل الواجهة الطلب عند استلامها بدل إظهار نجاح زائف.
- reconnect وhistory hydration لا يعيدان إحياء طلب حُسم بالفعل.

## 5. النطاق المرحلي

### Gate A — Contract audit and implementation map

- [x] تتبع `session.runtime_notice` من socket إلى `DeviceConversationStore` ثم
  attention/sidebar و`SessionMessagesCubit` و`ConversationInputCubit` وتحديد
  نقطة فقد تحديث البطاقة في الجلسة النشطة بدليل اختبار مكرر.
- [x] حصر كل استدعاءات `sendProtocolEvent` في مسار المحادثة وتصنيفها إلى أوامر
  موجهة للجهاز، ردود تعليق، ونتائج lifecycle.
- [x] التحقق من دعم `SanadProtocolBridge.handleCommand` لكل أمر سينتقل إلى
  `device_command`، وتوثيق الفجوات التي يجب استكمالها داخل Agent فقط.
- [x] تتبع تسجيل واستبدال `_sessionChannels[sessionId]` وإثبات أن آخر قناة
  مسجلة تملك إرسال طلب التعليق حاليًا.
- [x] تحديد موضع حفظ `OriginContext` طوال عمر run/suspended work بحيث لا تضيع
  هوية المنصة قبل ظهور سؤال متأخر.
- [x] اعتماد خريطة التنفيذ مع تأكيد عدم الحاجة إلى أي تعديل في `backend/`.

### Gate B — Live runtime notice presentation parity

- [x] جعل presentation الخاصة بالجلسة النشطة تراقب التغير الحي authoritative
  في `attentionStates/runtimeNotice` بدل انتظار إعادة اختيار الجلسة.
- [x] تحديث بطاقة runtime notice فور وصول notice للجلسة المفتوحة دون إعادة
  تحميل history أو التنقل بعيدًا والعودة.
- [x] منع notice لجلسة خلفية من استبدال بطاقة الجلسة المفتوحة.
- [x] الحفاظ على atomic navigation gating؛ لا يسمح لحدث جلسة سابقة بتجاوز
  `requestedSessionId` أو استبدال العرض الجاري تحميله.
- [x] تطبيق `session.runtime_notice_cleared` فورًا على البطاقة والقائمة الجانبية
  من المصدر authoritative نفسه.
- [x] الحفاظ على history hydration كمسار استعادة بعد reconnect، لا كشرط لتحديث
  البطاقة الحية.

### Gate C — Device-command transport for interactive actions

- [x] نقل `session.runtime_retry` إلى `device_command` مع `device_id` و
  `session_id` وroute الحالية عند توفرها.
- [x] نقل `session.runtime_continue_with_provider` إلى `device_command` مع
  `provider_instance_id + model_id` بصورة ذرية.
- [x] نقل `tool_permission_response` وإجابة سؤال `system_ask_user` إلى مسار
  `device_command` نفسه.
- [x] حصر بقية أحداث المحادثة التفاعلية التي تستخدم `protocol_event`، ونقل ما
  يمثل أمرًا موجهًا للجهاز إلى العقد الموحد بدل ترك فجوات خاصة بالسحابة.
- [x] إضافة دعم Agent command عام لكل نوع مطلوب غير مدعوم حاليًا، دون إضافة
  أي event-specific routing إلى الـbackend.
- [x] الحفاظ على `request_id` الخام و`session_id` وحقول القرار أو التعليق أو
  الإجابة دون تحويلات transport-specific.
- [x] عدم إجراء clear متفائل للـnotice أو الطلب المعلق؛ ينتظر العميل نتيجة
  lifecycle authoritative من Sanad Agent.
- [x] إبقاء مسار `Stop` الحالي دون تغيير وظيفي، ما لم يثبت اختبار Gate A وجود
  خلل مستقل وقابل للتكرار فيه.

### Gate D — Runtime-owned suspension delivery

- [x] إزالة اعتماد بث `tool_permission_request` على قناة session واحدة
  last-writer-wins.
- [x] تمرير طلبات التعليق عبر مسار Canonical/GatewayManager الذي ينفذ
  `DeliveryPolicy` فعليًا.
- [x] اشتقاق السياسة من origin المحفوظة: عائلة Sanad Client أو origin خارجي.
- [x] ضمان أن Local وCloud يحصلان على نسخ متطابقة الهوية والمحتوى عند origin
  من Sanad Client.
- [x] تنفيذ حسم ذري first-writer-wins داخل Sanad Agent قبل الاستئناف، وإرجاع
  `already_resolved` لكل رد لاحق أو خاسر في السباق.
- [x] بث resolved/cleared outcome إلى جميع واجهات Sanad Client بعد قبول أول رد
  حتى يختفي الطلب وتتعطل إمكانية الإجابة في كل الواجهات.
- [x] ضمان أن الرد من أي واجهة Sanad Client يستطيع حسم الطلب، لا الواجهة التي
  بدأت التشغيل فقط.
- [x] وضع عقد قابل للتوسعة لمنصات Telegram وWhatsApp مستقبلًا دون تنفيذ تلك
  المنصات ضمن هذه المهمة.

### Gate E — Verification and regression coverage

- [x] اختبار client store/cubit يثبت أن notice الحية تحدث القائمة الجانبية
  وبطاقة الجلسة المفتوحة في اللحظة نفسها.
- [x] اختبار جلسات A/B يثبت أن notice الخلفية لا تظهر داخل الجلسة الخاطئة.
- [x] اختبار atomic navigation race بين notice حية وhistory متأخرة.
- [x] اختبار client transport يثبت أن Retry وChange Provider ورد السؤال تستخدم
  `device_command` مع `device_id` الصحيح على Local وCloud.
- [x] اختبار Agent command parsing والتنفيذ لكل إجراء منقول.
- [x] اختبار Agent متعدد القنوات يثبت أن تسجيل Local ثم Cloud، أو العكس، لا
  يحصر سؤال Sanad Client في آخر قناة.
- [x] اختبار origin خارجي اصطناعي يثبت أن السؤال يعود إلى origin فقط.
- [x] اختبار first-response-wins يثبت أن ردين متزامنين ينتجان فائزًا واحدًا،
  وأن الرد الخاسر يحصل على `already_resolved` دون استئناف أو تنفيذ مكرر.
- [x] اختبار resolved/cleared يثبت اختفاء الطلب وتعطيل الرد في كل واجهات Sanad
  Client، بما فيها واجهة لم ترسل الإجابة.
- [x] E2E محلي وسحابي حقيقي يثبت وصول runtime notice حيًا، وعمل Retry وChange
  Provider، وظهور السؤال والرد عليه من أي واجهة.
- [x] التحقق آليًا من عدم وجود أي تعديل في `backend/` ضمن change set.
- [x] تحديث وثائق communication protocol وruntime suspension ومصفوفة QA وعقود
  `AGENTS.md` الأقرب إلى الملفات التي ستتغير.

## 6. معايير القبول

- [x] تظهر بطاقة `session.runtime_notice` فورًا داخل الجلسة السحابية المفتوحة
  بالتزامن مع علامة الانتباه في القائمة الجانبية.
- [x] لا يحتاج المستخدم إلى مغادرة المحادثة والعودة لإظهار notice أو تحديثها.
- [x] تعمل Retry وChange Provider والرد على السؤال عبر Local وCloud باستخدام
  `device_command` الحالي.
- [x] لا يحتوي الـbackend على معرفة جديدة بأسماء أحداث runtime، ولا يتغير أي
  ملف داخله.
- [x] يصل سؤال بدأ من أي واجهة Sanad Client إلى جميع واجهات Sanad Client
  المتصلة والمؤهلة.
- [x] لا يعتمد توصيل السؤال على آخر channel سُجلت للجلسة.
- [x] يصل السؤال ذو origin خارجي مستقبلًا إلى origin نفسه فقط.
- [x] يحسم أول رد الطلب مرة واحدة، وتختفي الحالة المعلقة وتتعطل الإجابة في كل
  الواجهات بعد confirmation authoritative.
- [x] يرفض Sanad Agent كل إجابة لاحقة أو متزامنة خاسرة بنتيجة
  `already_resolved` دون تغيير القرار الأول أو تكرار الاستئناف.
- [x] تظل تصفية الجهاز وعزل الجلسات وatomic navigation فعالة.
- [x] تمر تحليلات Agent وClient والاختبارات المركزة وdaemon-backed Local/Cloud
  E2E المطلوبة.

## 7. خارج النطاق

- تعديل أي ملف في `backend/` أو إضافة event-specific backend handlers.
- تنفيذ Telegram أو WhatsApp أو واجهاتهما في هذه المهمة.
- إزالة `device_id` filtering أو بث أحداث جهاز إلى أجهزة مستخدم أخرى.
- إعادة تصميم كل أوامر Sanad protocol غير المرتبطة بتفاعلات المحادثة.
- تغيير سلوك Stop دون عيب مستقل مثبت باختبار قابل للتكرار.
- استخدام history polling بديلًا عن live event presentation الصحيح.
