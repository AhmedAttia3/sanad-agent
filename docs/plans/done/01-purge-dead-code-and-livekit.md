---
title: "المرحلة الأولى: حذف الكود الميت وإزالة LiveKit"
description: "إزالة المشاريع الفرعية المهجورة وكل أثر لـ LiveKit من المنظومة تمهيداً للتحولات المعمارية في المراحل اللاحقة. هذه الخطة هي المرحلة الأولى من أربع مراحل للوصول إلى التوجه الجديد المُوثق في docs/product/prd_sanad_agent.md"
phase: 1
prd: "docs/product/prd_sanad_agent.md"
---

# المرحلة الأولى: حذف الكود الميت وإزالة LiveKit

> هذه المرحلة هي الخطوة الأولى من أربع خطوات لتحقيق التوجه الجديد للمشروع الموثق في **[وثيقة متطلبات المنتج (PRD)](../product/prd_sanad_agent.md)**. لا يمكن البدء في أي تعديلات معمارية حقيقية قبل الانتهاء من هذه المرحلة لأن الكود الميت والمشاريع المهجورة تشكّل ضجيجاً يعيق تحليل وفهم النظام الحالي.

---

## الهدف

تطهير قاعدة الكود بالكامل وجعلها تعكس بدقة التوجه الجديد لمنظومة Sanad Agent قبل البدء بأي تعديلات معمارية. يشمل ذلك:

- **إزالة مشاريع انتهى دورها:** وهي `agent/` (Python workers) و `openclaw-sanad-gateway/` اللذان لم يعودا جزءاً من المنظومة الجديدة التي تعتمد على `sanad-agent` (Dart) كوحدة تنفيذ وحيدة.
- **استئصال LiveKit بالكامل:** تقنية LiveKit لم تُستخدم بعد في الإنتاج وأصبح التوجه الجديد يعتمد على بث الصوت المحلي عبر WebSocket مباشرةً في `sanad-agent`. كل كود LiveKit في الباك اند والواجهة هو كود ميت يجب إزالته.
- **تنظيف قاعدة البيانات المركزية:** جداول `threads`, `messages`, و `sessions` (الخاصة بـ LiveKit) هي جداول ميتة لأن الجلسات والرسائل تُخزن محلياً في SQLite الخاص بـ `sanad-agent` وليس في الباك اند.
- **تنظيف ملفات التوثيق:** تحديث جميع ملفات `AGENTS.md` لإزالة الإشارات للمشاريع المحذوفة، بما يضمن أن لا يُضلَّل أي مطور أو وكيل ذكاء اصطناعي بتوثيق قديم.

---

## النطاق

### 1. حذف المشاريع الفرعية بالكامل
- حذف مجلد `agent/` (Python - SanadAgent & EastStarAI workers).
- حذف مجلد `openclaw-sanad-gateway/` (TypeScript bridge).

### 2. تنظيف Docker Compose
- حذف خدمات `sanadagent-worker` و `eaststarai-worker` من `docker-compose.yml`.
- حذف إشارات قاعدة البيانات `agent_brain` من بيئة الحاويات وملفات `.env`.

### 3. إزالة LiveKit من الباك اند
- حذف endpoints توليد توكنات الـ LiveKit من `backend/app/api/`.
- حذف خدمات LiveKit من `backend/app/services/`.
- حذف متغيرات البيئة المتعلقة بـ LiveKit (`LIVEKIT_URL`, `LIVEKIT_API_KEY`, `LIVEKIT_API_SECRET`) من ملفات `.env` وملفات الإعداد في الباك اند.

### 4. إزالة LiveKit من الواجهة (`sanad-client`)
- حذف مكتبة `livekit_client` من `pubspec.yaml`.
- حذف جميع الملفات المتعلقة بـ LiveKit (مجلد `lib/infrastructure/livekit/` ومحتوياته).
- حذف أي Voice UI متعلقة بـ LiveKit (مثل `CallCubit`, `VoiceAgentView`).

### 5. حذف الجداول الميتة من قاعدة البيانات المركزية (Backend PostgreSQL)
- حذف جداول `threads`, `messages`, و `sessions` (جلسات LiveKit) من `backend/app/models/`.
- إنشاء Alembic migration لحذف هذه الجداول من قاعدة البيانات.
- **الاستثناء:** يتم الإبقاء على جداول `usage_logs` و `pricing` لأنها ستُستخدم لاحقاً في مرحلة الاشتراكات وخدمة Sanad LLM.

### 6. تحديث ملفات التوثيق
- تحديث `/AGENTS.md` الرئيسي وكل `AGENTS.md` فرعي لإزالة أي إشارة للمشاريع المحذوفة (`agent`, `openclaw-sanad-gateway`, LiveKit, EastStarAI).
- **ملاحظة:** خطط LiveKit الموجودة في `docs/plans/` تبقى كمرجع تاريخي وضمن التوجه الجديد ولا يتم حذفها.

---

## معايير القبول (Acceptance Criteria)

- [ ] لا يوجد أي مجلد `agent/` أو `openclaw-sanad-gateway/` في المشروع.
- [ ] ملف `docker-compose.yml` لا يحتوي على أي خدمة تشير لـ LiveKit أو Python agent workers.
- [ ] الباك اند يقوم بعمل build ناجح بعد الحذف (`pip install && pytest`).
- [ ] الواجهة تقوم بعمل build ناجح بعد الحذف (`fvm flutter build`).
- [ ] قاعدة بيانات الباك اند لا تحتوي على جداول `threads`, `messages`, أو `sessions` الخاصة بـ LiveKit.
- [ ] لا يوجد أي import أو استدعاء لـ `livekit_client` في مشروع `sanad-client`.
- [ ] لا يوجد أي متغير بيئة متعلق بـ LiveKit في ملفات `.env.dev` أو `.env.prod`.
- [ ] جميع ملفات `AGENTS.md` محدثة ولا تحتوي على مراجع للمشاريع المحذوفة.
- [ ] لا يوجد أي كود ميت أو `TODO` يشير للمشاريع المحذوفة في الكود المتبقي.
