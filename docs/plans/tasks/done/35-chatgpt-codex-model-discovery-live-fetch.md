---
title: "ChatGPT Codex Model Discovery - Live Fetch Implementation"
description: "إصلاح جلب نماذج ChatGPT Codex الحية بدل استخدام parser بصيغة OpenAI العامة."
status: "completed"
scope: "agent Codex model discovery"
priority: "high"
---

# Task 35: ChatGPT Codex Model Discovery - Live Fetch

## 1. المشكلة

مزود `openai-codex` يستخدم endpoint وصيغة استجابة مختلفين عن OpenAI API
العامة، بينما الكود الحالي يعامله كـOpenAI-compatible provider:

- الطلب الحالي يذهب إلى `/models` دون `client_version`.
- المحلل الحالي يتوقع `data[].id`.
- Codex يعيد `models[].slug` مع `visibility` و`priority`.

لهذا يفشل تحليل الاستجابة وينتقل التطبيق إلى `fallbackModels` رغم نجاح طلب
Codex.

يوجد مستهلكان لنفس الجلب ويجب أن يستخدما الإصلاح نفسه:

- `ModelOptionsService` لأمر `model.options`.
- `CodexResponsesAdapter.getAvailableModels()` لمسار `model.refresh`.

## 2. الحل المطلوب

إنشاء `CodexModelsService` صغيرة ومخصصة لجلب وتحليل قائمة Codex، ثم إعادة
استخدامها من المستهلكين الحاليين دون تعديل بنية provider runtime أو الحافظة.

سلوك الخدمة:

1. تبني الطلب من base URL المحلول:
   `.../models?client_version=<agent-version>`.
2. ترسل access token في `Authorization: Bearer ...`.
3. تقرأ القائمة من `models` وتستخدم `slug` كمعرف النموذج.
4. تستبعد العناصر التي تحمل `visibility: hide` أو `hidden`.
5. ترتب حسب `priority` ثم `slug`.
6. تزيل slugs الفارغة أو المكررة.
7. تستفيد من forward-compat الموجود في مرجع Hermes لإضافة aliases المطلوبة
   مثل `-pro` عندما لا يعيدها endpoint مباشرة.
8. عند فشل الشبكة أو HTTP أو parsing تعيد فشلًا واضحًا للمستهلك، ويستمر
   fallback الحالي كما هو.

المرجع التنفيذي:

- `refrence_projects/hermes-agent/hermes_cli/codex_models.py`
- `_fetch_models_from_api`
- `_add_forward_compat_models`

## 3. نطاق التعديل

### ملفات التنفيذ

- `agent/lib/engine/adapters/codex_models_service.dart` (جديد)
- `agent/lib/engine/adapters/codex_responses_adapter.dart`
- `agent/lib/core/provider_runtime/model_options_service.dart`
- `agent/lib/engine/adapters/provider_registry.dart` فقط لتحديث fallback Codex
  عند الحاجة وفق مرجع Hermes.

### ملفات الاختبار

- `agent/test/engine/adapters/codex_models_service_test.dart` (جديد)
- `agent/test/engine/adapters/codex_responses_adapter_test.dart`
- `agent/test/core/provider_runtime/model_options_service_test.dart`

### التوثيق المطلوب مع التنفيذ

- تحديث العقد والوثيقة التقنية الأقرب فقط إذا تغير عقد discovery الموثق.

## 4. خطوات التنفيذ

- [x] إنشاء الخدمة المشتركة مع HTTP client قابل للحقن في الاختبارات.
- [x] تنفيذ URL وheaders وparser وفق صيغة Codex.
- [x] نقل filtering وsorting وforward-compat من Hermes بصورة مناسبة لـDart.
- [x] استخدام الخدمة في فرع `openai-codex` داخل `ModelOptionsService`.
- [x] استخدام الخدمة داخل `CodexResponsesAdapter.getAvailableModels()`.
- [x] إبقاء سلوك جميع providers الأخرى دون تغيير.
- [x] إضافة اختبارات مركزة للطلب والتحليل والتكامل مع المستهلكين.

## 5. معايير القبول

- [x] طلب Codex يستخدم `/models` مع `client_version` وBearer token الصحيح.
- [x] استجابة `models[].slug` تتحول إلى قائمة نماذج مرتبة حسب `priority` ثم
      `slug`.
- [x] عناصر `hide` و`hidden` لا تظهر.
- [x] `supported_in_api: false` لا يستبعد نموذجًا صالحًا لمسار Codex OAuth.
- [x] forward-compat المطابق لـHermes لا يضيف نموذجًا مكررًا.
- [x] `ModelOptionsService.optionsFor('openai-codex')` يعيد `source: live` عند
      نجاح الجلب.
- [x] `CodexResponsesAdapter.getAvailableModels()` يعيد القائمة الحية نفسها
      لمسار `model.refresh`.
- [x] عند 401 أو timeout أو JSON غير صالح يستمر fallback الحالي دون crash.
- [x] لا يتغير جلب النماذج لأي provider آخر.
- [x] تحليل Dart والاختبارات المركزة يمران بنجاح.

## 6. خارج النطاق

- تغيير `ProviderModelCacheService` أو قاعدة البيانات أو TTL.
- إنشاء cache جديد أو قراءة cache الخاص بـCodex CLI.
- تعديل واجهة Flutter أو بروتوكولات gateway.
- إضافة metrics أو alerts أو polling.
- إعادة تصميم `ModelOption` أو provider runtime.
- اختبارات CI تستخدم حساب ChatGPT أو access token حقيقي.

## 7. تعريف الإنجاز

تظهر نماذج Codex الحية في `model.options` و`model.refresh` باستخدام parser واحد
مخصص لـCodex، مع بقاء fallback والحافظة وبقية providers كما هي.
