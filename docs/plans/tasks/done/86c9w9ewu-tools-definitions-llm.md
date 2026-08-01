---
title: "خطة تنفيذ المهمة: تنقية مواصفات الأدوات للوكيل"
description: "مواصفات وتفاصيل تصفية حقول مواصفات الأدوات الموجهة للـ LLM لتقليص استهلاك التوكنز."
---

# خطة تنفيذ المهمة: تنقية مواصفات الأدوات للوكيل (Triage Tool Specs for LLM)

<div dir="rtl" style="text-align: right; direction: rtl;">

* **معرف المهمة (Task ID):** `86c9w9ewu`
* **المكونات المتأثرة (Component Tags):** `sanadagent-local` / `sanadagent`
* **الحالة (Status):** ✅ Done
* **الوقت المتوقع (Estimated Effort):** ساعة واحدة (1 Hour)

---

## 🎯 الهدف البرمجي (The Goal)

التأكد من أن مواصفات الأدوات (Tool Definitions) التي يتم تمريرها إلى النموذج اللغوي (LLM) عند استدعاء الوظائف (Function Calling) تحتوي **فقط على الحقول الأساسية الثلاثة التي تهم النموذج**: الاسم (`name`)، الوصف (`description`)، ومخطط المدخلات (`inputSchema` أو `parameters`). يجب تصفية وإزالة أي بيانات إضافية (مثل الأذونات `permissions` أو منطق الموافقة `approval`) لتقليص استهلاك الرموز (Tokens) وتقليل استهلاك الجلسة دون أي فائدة. يتم فحص وتطبيق منطق الأذونات برمجياً بالكامل في كود الديمون محلياً ولا يتم تمريره للـ LLM.

---

## 🧪 خطة التحقق والاختبار (Verification Plan)

> [!TIP]
> **أولوية الاختبار الآلي الصارمة:** يتم فحص واختبار هذه المهمة بشكل مؤتمت بالكامل عبر اختبارات الوحدة للتأكد من هيكل التصدير لـ JSON الموجه للـ LLM.

### 1. الاختبارات الآلية الموجهة (Unit Tests)

نقوم بكتابة/تحديث اختبار وحدة للتحقق من هيكل التصدير المصفى:

#### [MODIFY] [runtime_catalog_test.dart](file:///sanad-agent/test/capabilities/runtime_catalog_test.dart) (أو ملف اختبار المواصفات المقابل)

* بناء سيناريو اختبار يقوم بإنشاء كائن `LocalToolSpec` يحتوي على بيانات أذونات حساسة ومحايدة (`approval`).
* استدعاء دالة التصدير الموجهة للـ LLM والتأكد من:
  * احتواء الـ JSON على `name` و `description` و `parameters` (أو `input_schema`).
  * **عدم احتواء** الـ JSON الناتج نهائياً على مفاتيح الأذونات `approval` أو `permissions` أو أي بيانات سرية زائدة عن الحاجة.

### 2. تشغيل الاختبار والتحقق من النجاح

تشغيل اختبارات الوحدة للـ registry:

```bash
fvm dart test test/capabilities/runtime_catalog_test.dart
```

</div>
