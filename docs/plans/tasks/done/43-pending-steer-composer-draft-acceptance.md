---
title: "Pending Steer Composer Draft Acceptance"
description: "إصلاح بقاء نص الرسالة في composer بعد قبول daemon لها كـpending steer أثناء جولة فعالة."
status: "completed"
completed_at: "2026-07-16"
priority: "high"
scope: "Flutter client draft acceptance and regression coverage"
depends_on: "Task 36"
---

# Task 43: Pending Steer Composer Draft Acceptance

## المشكلة

يمسح العميل draft فقط عند استقبال الحدث canonical `user_message`. عند إرسال
`auto` أثناء جولة فعالة، يصنف daemon الرسالة كـpending steer ويرسل
`session.pending_steer_changed` بدل `user_message` في مرحلة القبول، ولذلك يبقى
النص ظاهرًا في composer رغم أن الرسالة قُبلت وظهرت في timeline.

## الخطة

1. اعتبار أول lifecycle موثوق للـpending steer قبولًا canonical لنفس
   `request_id` لأغراض draft فقط.
2. تمرير `session_id` و`request_id` إلى مالك cache الحالي مع إبقاء مطابقة
   pending request id؛ لا يمسح قبول غير مطابق draft أحدث.
3. إضافة اختبار regression يثبت أن قبول pending steer المطابق يمسح composer،
   وأن قواعد حماية النص الأحدث تبقى دون تغيير.
4. تحديث عقد client ووثيقة QA المرتبطين، ثم تشغيل التحليل والاختبارات المركزة
   وتحديث Graphify.

## معايير القبول

- [x] إرسال `auto` أثناء تنفيذ فعلي ثم وصول `session.pending_steer_changed`
      يمسح النص المرسل من composer.
- [x] lifecycle مكرر أو request id غير مطابق لا يمسح draft أحدث.
- [x] الرسائل الفاشلة قبل قبول daemon تبقى في draft.
- [x] اختبارات Flutter المركزة والتحليل ينجحان.

## نتيجة التحقق

نجح `fvm flutter analyze`، ونجح ملفا الاختبار المركزان لـ`SessionCubit`
و`ConversationInputPanel` بعدد 58 اختبارًا.
