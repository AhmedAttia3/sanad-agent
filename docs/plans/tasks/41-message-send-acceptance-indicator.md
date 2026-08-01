---
title: "Message Send Acceptance Indicator"
description: "عرض مؤشر إرسال داخل زر composer حتى يؤكد الوكيل قبول الرسالة canonical بنفس request id، مع عزل الحالة لكل جلسة والحفاظ على draft عند الفشل."
status: "planned"
priority: "medium"
scope: "Flutter client conversation state and composer"
depends_on: "Task 36 authoritative message delivery outcomes"
---

# Task 41: Message Send Acceptance Indicator

## 1. المشكلة

يعيد مسار الإرسال الحالي `request_id` بعد دفع الأمر إلى socket، لكنه لا يعرض
للمستخدم الفرق بين الإرسال المحلي وقبول الوكيل. يبقى سهم الإرسال ظاهرًا ويمكن
أن يبدو الطلب مكتمل التسليم بينما لم يصل canonical `user_message` بعد.

تملك طبقة draft بالفعل pending request id وتمسح النص فقط عند canonical
acceptance المطابقة، لكن هذه الحقيقة لا تُعرض كحالة زر ولا تعزل كل محاولات
الإرسال في presentation state واضحة.

## 2. تجربة المستخدم

- بعد قبول ضغطة الإرسال محليًا تختفي أيقونة السهم من زر الإرسال.
- يظهر `CircularProgressIndicator` أبيض في مركز الزر وبنفس لون السهم المفعّل.
- يبقى المؤشر حتى وصول acceptance authoritative بنفس `request_id`.
- يعطل الزر أثناء انتظار القبول لمنع duplicate dispatch لنفس draft.
- لا يعتمد المؤشر على `running` أو أول chunk أو final answer؛ القبول وحده ينهيه.
- إذا فشل dispatch أو رفض الوكيل الطلب، يعود الزر وتبقى الرسالة في draft مع
  خطأ واضح.

## 3. عقد الحالة

- تخزن حالة انتظار القبول حسب `device_id + session_id + request_id`، مع هوية
  مستقلة لـNew Conversation قبل اعتماد session id.
- لا يمسح acceptance لجلسة A مؤشر أو draft الجلسة B.
- canonical acceptance غير المطابقة لا تغير المحرر.
- أي تعديل جديد للنص بعد الإرسال يحافظ على النص الجديد ولا يسمح لإقرار قديم
  بمسحه.
- بعد `session_created` تنتقل حالة الطلب الأول من draft device-scoped إلى
  session-scoped دون وميض أو فقد.
- reconnect يحتفظ بالمؤشر أو يحسمه من history/acceptance authoritative، ولا
  يترك loading دائمًا بعد نتيجة نهائية معلومة.

## 4. التكامل مع أنواع التسليم

تتعامل الحالة بالطريقة نفسها مع التصنيفات التي يعيدها Task 36:

- think عادي.
- queued acceptance.
- steer acceptance.
- تحول explicit queue إلى think لأن الجولة انتهت.

اختلاف التصنيف لا ينهي المؤشر قبل وصول acceptance التي تحمل request id نفسها.

## 5. النطاق المرحلي

### Gate A — Pending acceptance state

- [ ] عرض pending request identity من cache/store عبر repository ثم cubit.
- [ ] فصل socket dispatch success عن agent acceptance.
- [ ] تعريف outcomes للفشل والرفض وانقطاع الاتصال.

### Gate B — Composer presentation

- [ ] استبدال سهم الإرسال بمؤشر دائري أبيض أثناء انتظار القبول.
- [ ] إبقاء حجم الزر 32x32 وتعطيله مع semantics وtooltip مناسبين.
- [ ] عدم التأثير في زر Stop أو voice أو pending permission cards.

### Gate C — Draft and session identity

- [ ] الحفاظ على النص عند الفشل.
- [ ] مسح draft فقط عند request id المطابقة.
- [ ] تغطية New Conversation adoption والتنقل بين الجلسات والتعديل اللاحق.

### Gate D — Verification and documentation

- [ ] اختبارات widget للون المؤشر وحجمه وتعطيل الزر.
- [ ] اختبارات cubit/store لقبول مطابق وغير مطابق والفشل وreconnect.
- [ ] اختبار تكامل لكل تصنيف think/queue/steer.
- [ ] تحديث وثيقة cache schema ومصفوفة QA للcomposer.

## 6. معايير القبول

- [ ] يظهر المؤشر الأبيض من dispatch حتى canonical acceptance المطابقة فقط.
- [ ] لا يستطيع المستخدم إرسال النسخة نفسها مرتين أثناء الانتظار.
- [ ] الفشل يعيد زر الإرسال ويحفظ draft.
- [ ] الجلسات والعملاء لا يمسح أحدها حالة انتظار أو draft الآخر.
- [ ] لا يبقى loading عالقًا بعد reconnect أو رفض authoritative.

## 7. خارج النطاق

- سياسة اختيار steer/queue/think وأزرار queued messages؛ تملكها Task 36.
- مؤشر Stop أثناء stopping؛ منفذ ضمن Task 31.
- تغيير شكل canonical user-message payload خارج الحقول التي تحتاجها Task 36.
