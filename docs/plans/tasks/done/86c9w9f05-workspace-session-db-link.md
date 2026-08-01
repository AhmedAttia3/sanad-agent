---
title: "نقطة البداية للمهمة: ربط مساحة العمل بالجلسة في قاعدة بيانات الديمون"
description: "مواصفات وتفاصيل ربط مساحة العمل بالجلسة (Session) محلياً داخل قاعدة بيانات SQLite الخاصة بـ sanadagent-local."
---

# نقطة البداية للمهمة: ربط مساحة العمل بالجلسة في قاعدة بيانات الديمون (Link Workspace with Session in Local DB)

<div dir="rtl" style="text-align: right; direction: rtl;">

* **معرف المهمة (Task ID):** `86c9w9f05`
* **المكونات المتأثرة (Component Tags):** `sanadagent-local`
* **الحالة (Status):** ✅ تم التنفيذ
* **الوقت المتوقع (Estimated Effort):** 4 ساعات (4 Hours)

---

## الوضع الحالي (Current State)
* **عدم وجود ربط بين الجلسة ومساحة العمل في الديمون**: في الديمون المحلي (`sanadagent-local`)، يتم استخدام قاعدة بيانات SQLite محلية (`state.db`) مخزنة في مسار التطبيق لحفظ حالة الجلسات والرسائل والمهام والذاكرة طويلة المدى.
* **هيكل جدول الجلسات الحالي**: جدول الجلسات (`sessions`) في قاعدة البيانات (في الملف النسبي `sanadagent-local/lib/evolution/db/session_db.dart`) محدد بالهيكل التالي:
  ```sql
  CREATE TABLE IF NOT EXISTS sessions (
    session_id TEXT PRIMARY KEY,
    model TEXT NOT NULL,
    title TEXT,
    metadata TEXT,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
  );
  ```
  هذا الهيكل يفتقر تماماً لوجود عمود يربط الجلسة بمسار أو معرّف مساحة العمل (`workspace_id`).
* **عزل كلاس الموديل**: كلاس الحالة `SessionState` (في الملف النسبي `sanadagent-local/lib/evolution/models/session_state.dart`) لا يحتوي على حقل `workspaceId` ولا يتم تمريره أو حفظه عند استدعاء `saveSession` أو استرجاعها عبر `SessionDB`.

---

## الوضع المستهدف / الهدف (Target State)
* **تحديث قاعدة البيانات المحلية (SQLite Migrations)**:
  * تعديل دالة التهيئة `_initDb` في الملف النسبي `sanadagent-local/lib/evolution/db/session_db.dart` لإضافة عمود `workspace_id TEXT` إلى جدول `sessions` عند الإنشاء لأول مرة.
  * كتابة جملة هجرة تلقائية (Migration block) باستخدام `try-catch` لتشغيل الأمر `ALTER TABLE sessions ADD COLUMN workspace_id TEXT` على قواعد البيانات القديمة للمستخدمين لتجنب أي أخطاء توافقية عند تحديث التطبيق (Backward Compatibility).
* **تحديث كود الحفظ والاسترجاع (SessionDB Updates)**:
  * تعديل دالة الحفظ `saveSession` لتخزين قيمة `workspace_id` الخاصة بالجلسة بنجاح داخل قاعدة البيانات:
    ```sql
    INSERT INTO sessions (session_id, model, title, workspace_id, created_at, updated_at) ...
    ```
  * تعديل استعلامات جلب البيانات (`getSession` و `getAllSessions`) لتتضمن استخراج حقل `workspace_id` وتمريره لبناء موديل الحالة.
* **تحديث موديل الجلسة (SessionState Updates)**:
  * تعديل الملف النسبي `sanadagent-local/lib/evolution/models/session_state.dart` لإضافة حقل `final String? workspaceId` مع تضمينه في الـ Constructor، وتحديث دالة التهيئة `fromMap` ودالة التصدير `toMap`.
* **ربط السياق عند استدعاء الوكيل**:
  * التأكد من تمرير `workspaceId` للجلسة بشكل ديناميكي عند استدعاء وتنفيذ المنعطفات (Turns) لضمان بقاء الوكيل على دراية تامة بمساحة العمل المحددة لهذه الجلسة بالتحديد.

---

## حالات الاختبار (Test Cases)
### حالات اختبار الهجرة البرمجية والتحقق (Database Migration & Compatibility Tests):
* **حالة 1**: التحقق من تشغيل الديمون بدون أخطاء على قاعدة بيانات جديدة (يتم إنشاء جدول `sessions` متضمناً عمود `workspace_id` بنجاح).
* **حالة 2**: التحقق من تشغيل الديمون على قاعدة بيانات قديمة (لا تحتوي على العمود)، والتأكد من نجاح جملة الهجرة المضافة `ALTER TABLE` وعدم حدوث أي انهيار للتطبيق أو تصفير للبيانات القديمة.

### حالات اختبار حفظ واسترجاع الجلسة (Session Persistence Tests):
* **حالة 3**: حفظ جلسة جديدة بمساحة عمل نشطة (`workspaceId = 'some/path'`) عبر `saveSession` والتحقق من حفظ القيمة بنجاح في جدول SQLite.
* **حالة 4**: استرجاع الجلسة المحفوظة عبر `getSession` والتأكد من تعبئة الحقل `workspaceId` بالقيم المدخلة تماماً.
* **حالة 5**: حفظ جلسة بدون مساحة عمل (`workspaceId = null`) والتأكد من أنه يتم حفظها بنجاح كـ `NULL` في قاعدة البيانات واسترجاعها بالشكل الصحيح.

</div>
