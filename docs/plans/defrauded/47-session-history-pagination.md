---
title: "Session History Pagination"
description: "تصميم pagination مستقرة لتاريخ الجلسة بين Sanad Agent وSanad Client مع تحميل الأحدث أولًا والحفاظ على ترتيب الأحداث والـscroll والـlive updates."
status: "planned"
priority: "high"
scope: "Sanad agent and Flutter client session history"
depends_on: "Task 46 cloud session history payload reliability"
---

# Task 47: Session History Pagination

## 1. المشكلة

يعيد `get_session_history` حاليًا كامل المحادثة المستمرة في envelope واحدة.
إزالة الحقول المكررة خفّضت الحجم الحالي، لكن نمو الجلسة ونتائج الأدوات الكبيرة
سيظلان يرفعان استهلاك الذاكرة ووقت serialization والنقل وتحليل الواجهة وتحديث
conversation cache.

هذه مهمة Sanad فقط، ويقتصر نطاقها على `agent/` و`client/`. لا يبدأ تنفيذها قبل
مراجعة التصميم والاختبارات المطلوبة واعتماد العقد بصورة صريحة.

## 2. عقد التصميم المطلوب

- استخدام opaque keyset cursor مبني على ترتيب تخزين ثابت، لا offset قابل
  للانزلاق عند وصول رسائل جديدة.
- تحميل أحدث صفحة أولًا مع إعادة أحداث الصفحة بترتيب العرض الزمني.
- إرجاع `has_more` و`next_cursor` بصورة صريحة.
- فرض حد مركزي لعدد العناصر وbyte budget للصفحة.
- عدم فصل `tool_use` عن `tool_result` أو reasoning عن model step أو steer عن
  tool boundary المالكة له.
- منع live events المتزامنة مع تحميل الصفحات القديمة من إنشاء تكرار أو فجوة
  أو تغيير في الترتيب.
- تحديد الصفحة التي تملك session-level state مثل `execution_snapshot` وqueued
  inputs وruntime recovery وstop-draft recovery وin-flight content.
- تعريف سلوك واضح لحدث canonical واحد يتجاوز byte budget الطبيعي للصفحة.

## 3. النطاق المرحلي

### Gate A — Protocol and persistence design

- [ ] مراجعة schema الحالية وقواعد history reconstruction قبل اختيار cursor.
- [ ] تعريف request/response canonical موحد للاتصال المحلي والبعيد.
- [ ] توثيق ordering وsnapshot watermark وcursor validation.
- [ ] تحديد حدود logical turns وbyte budget وسلوك الحدث الكبير منفردًا.
- [ ] اعتماد التصميم قبل أي تعديل تنفيذي.

### Gate B — Agent pagination

- [ ] إضافة استعلام SQLite paginated بمفاتيح ثابتة وترتيب deterministic.
- [ ] توسيع `get_session_history` دون إنشاء عقد خاص باتصال واحد.
- [ ] الحفاظ على reasoning وtool pairs وsteering وroute transitions والهوية
  fallback للسجلات القديمة.
- [ ] رفض cursor التالف أو غير المتوافق بخطأ منظم.

### Gate C — Client cache and loading

- [ ] تحميل أحدث صفحة عند فتح الجلسة ثم طلب الأقدم قرب أعلى المحادثة.
- [ ] prepend للأحداث القديمة مع تثبيت موضع scroll المرئي.
- [ ] دمج الصفحات عبر conversation cache وcanonical mapper الحاليين.
- [ ] deduplicate باستخدام event/tool identities authoritative.
- [ ] فصل initial loading وolder-page loading وretry وexhausted وcancellation.
- [ ] استمرار live events أثناء طلب صفحة أقدم دون استبدالها بنتيجة history.

### Gate D — Verification and documentation

- [ ] اختبارات قاعدة البيانات للترتيب والتساوي والحذف والصفحة الفارغة وcursor
  التالف والإضافة المتزامنة.
- [ ] اختبارات reconstruction لحدود reasoning وtool pairs وsteering والهوية.
- [ ] اختبارات item cap وbyte budget مع نتائج أدوات كبيرة.
- [ ] اختبارات mapper/cache للتداخل والتكرار والاستجابات القديمة وlive races.
- [ ] اختبارات cubit/service للتقدم وإعادة المحاولة والإلغاء ونهاية التاريخ.
- [ ] اختبارات widget لثبات scroll عند prepend.
- [ ] E2E لجلسة طويلة وreconnect والتنقل السريع وlive output المتزامن.
- [ ] تحديث عقود `AGENTS.md` ووثائق البروتوكول والـcache ومصفوفات QA.

## 4. معايير القبول

- [ ] initial history hydration محدود الحجم والزمن.
- [ ] يمكن الوصول إلى كامل التاريخ تدريجيًا دون فقد أحداث.
- [ ] المحلي والبعيد يعرضان pagination semantics متطابقة.
- [ ] لا يفقد أو يتكرر أو يعاد ترتيب أي حدث canonical.
- [ ] لا تنفصل الأحداث المركبة عن logical owner الخاصة بها عبر الصفحات.
- [ ] يبقى scroll ثابتًا وتستمر live events أثناء تحميل الأقدم.
- [ ] تمر تحليلات agent/client والاختبارات المركزة والكاملة وdaemon-backed E2E.

## 5. خارج النطاق

- تغيير محتوى رسائل الجلسة أو اقتطاعه دون عقد عرض صريح.
- إنشاء مسار history مختلف لكل transport.
- البدء في التنفيذ قبل اعتماد Gate A.
