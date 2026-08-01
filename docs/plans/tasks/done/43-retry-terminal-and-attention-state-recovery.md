---
title: "Task 43: Retry Terminal and Attention State Recovery"
description: "إصلاح بقاء work item وواجهة المحادثة في blocked بعد نجاح retry وإنتاج الإجابة النهائية."
status: "completed"
priority: "high"
---

# Task 43: Retry Terminal and Attention State Recovery

## 1. المشكلة المثبتة

عند فشل طلب قبل بدء stream، ينشر runtime recovery حالة `blocked` أو `waiting`
ثم يعيد المحاولة تلقائيًا. مسار retry الحالي ينشر notice من نوع `resuming` لكنه
لا يطالب بالـwork item الدائمة وينقلها إلى `resuming`. لذلك يرفض terminal commit
الإجابة الناجحة لأن الحالة الدائمة ما زالت recovery-owned، ولا يبث
`final_answer`، وتبقى snapshot وأيقونة الـsidebar في حالة خطأ.

كما يمسح المسار notice الخاصة بـ`resuming` فور نشرها، قبل ظهور model progress
حقيقي، فينتج flicker بين الخطأ والاستكمال.

## 2. النطاق

- إضافة claim ذرية للـretry تتحقق من `session_id + work_item_id + run_id + generation`.
- السماح فقط بانتقال `waiting|blocked -> resuming` للمالك نفسه قبل متابعة الطلب.
- إبقاء notice `resuming` حتى أول progress حقيقي أو اكتمال الجولة.
- عدم تغيير أولوية selector في Flutter؛ يجب أن تتغير الأيقونة عبر snapshot
  authoritative من `blocked` إلى `resuming` ثم `idle`.
- إضافة diagnostics لنتائج terminal commit غير المرسلة.

## 3. معايير القبول

- [x] retry ناجح ينشر snapshots بالترتيب `blocked|waiting -> resuming -> idle`.
- [x] لا يستمر retry إذا فشل claim أو تغير مالك الجولة.
- [x] لا تمسح notice `resuming` قبل progress أو terminal completion.
- [x] تبث إجابة نهائية واحدة بعد terminal commit الناجحة.
- [x] تتغير أيقونة الـsidebar من خطأ إلى running ثم تختفي عند `idle`.
- [x] الرسائل queued خلف الجولة تبدأ بعد اكتمالها.
- [x] اختبارات Agent وClient المركزة وanalyzers ناجحة.
- [x] وثائق runtime وQA والعقود المالكة محدثة، ثم يشغل `graphify update .`.

## 4. خارج النطاق

- تغيير سياسة عدد retries أو اختيار provider.
- إعادة تصميم أيقونات الـsidebar أو ترتيب أولويات attention state.
- تعديل بيانات المستخدم المحلية العالقة يدويًا.
