---
title: "Runtime Contract Map and AGENTS Split"
description: "تثبيت llms.txt كخريطة عقود متتبعة، وتقليل تكرار وكثافة عقود AGENTS وتقريبها من مناطق الملكية الحساسة."
status: "planned"
scope: "documentation architecture"
---

# Task 38: Runtime Contract Map and AGENTS Split

## 1. الهدف

يجب أن يبقى `docs/llms.txt` الخريطة الحتمية التي تعرّف الوكيل بكل عقود
`AGENTS.md` النشطة، ثم يقرأ الوكيل منها العقود الحاكمة للمسار الذي سيعدله.
المطلوب أيضًا اختصار العقود وإعادة توزيعها حسب الملكية الفعلية، دون قياس التضخم
بعدد الأسطر فقط؛ فقد يحمل سطر واحد معلومات كثيرة أو مسؤوليات متداخلة.

## 2. قرارات ثابتة

- يصبح `docs/llms.txt` ملفًا مولدًا ومتتبعًا في Git، ويولده pre-commit ويضيفه
  إلى الـcommit تلقائيًا عند تغيره.
- يبقى `docs/llms-full.txt` مولدًا وغير متتبع في Git.
- لا يضاف فحص CI خاص بإعادة توليد `llms.txt`.
- تبقى في `llms.txt` إشارة عامة واحدة إلى `refrence_projects/`، ولا تفهرس
  تفاصيله أو عقوده ضمن عقود المشروع الإلزامية.
- جميع المسارات داخل العقود والفهارس نسبية وقابلة للعمل على كل الأجهزة.
- تبقى `AGENTS.md` قوانين وحدود ملكية مختصرة؛ ينتقل التصميم إلى `docs/`
  والإجراءات إلى skills أو scripts المناسبة.
- تذكر سياسة Graphify في عقد `AGENTS.md` الرئيسي فقط، ولا تضاف إلى
  `docs/llms.txt`.
- لا يتحول `README.md` إلى مصدر عقود بديل.

## 3. مراحل التنفيذ

### Gate A — دورة حياة خريطة العقود

- [ ] حصر كل ملفات `AGENTS.md` النشطة، مع استبعاد عقود `refrence_projects/`
      وملفات build/worktrees/generated outputs.
- [ ] مقارنة الحصر بقسم `System Rules & Runtime Contracts` في `docs/llms.txt`.
- [ ] إزالة `docs/llms.txt` من `.gitignore` مع إبقاء `docs/llms-full.txt`
      متجاهلًا.
- [ ] تحديث المولد بحيث ينتج `llms.txt` بصورة حتمية، ويحافظ على رابط عام واحد
      فقط إلى `refrence_projects/`.
- [ ] تحديث pre-commit ليولد الملفين، ثم يضيف `docs/llms.txt` إلى Git index بعد
      التوليد وقبل إنشاء الـcommit، ولا يضيف `docs/llms-full.txt`.
- [ ] جعل hook يوقف الـcommit عند فشل التوليد أو الإضافة، ويتحقق أن أي تغيير
      مولد في `docs/llms.txt` موجود داخل الـindex وليس في working tree فقط.
- [ ] إذا كان pre-commit الحالي محليًا داخل `.git/hooks` فقط، إنشاء مصدر hook
      أو installer متتبع يضمن تثبيت السلوك نفسه على كل جهاز وworktree.
- [ ] تصحيح وصف عقد الجذر بدل `Rules governing ..`.
- [ ] التأكد أن روابط `llms.txt` النسبية تُحل بصورة صحيحة من موقع الملف.

### Gate B — تدقيق محتوى العقود

- [ ] تدقيق كل عقد حسب كثافة المعلومات، تكرار القواعد، تداخل المسؤوليات، وقربه
      من الكود؛ لا يستخدم عدد الأسطر كمعيار وحيد.
- [ ] مراجعة العقود الكبيرة أو متعددة المسؤوليات، خصوصًا:
  - `AGENTS.md`
  - `agent/AGENTS.md`
  - `agent/lib/interfaces/AGENTS.md`
  - `client/lib/features/AGENTS.md`
- [ ] تحديد كل فقرة تصميمية أو إجرائية يجب نقلها، والوثيقة أو المهارة المالكة
      لها، قبل حذفها من العقد.
- [ ] تسجيل نتائج التدقيق داخل هذه المهمة قبل بدء التقسيم.

### Gate C — إضافة العقود المحلية اللازمة

- [ ] تقييم وإضافة `agent/lib/core/AGENTS.md` لقواعد ملكية configuration وDI.
- [ ] تقييم `agent/lib/core/provider_runtime/AGENTS.md` لعقود recovery/provider
      runtime المختصرة، مع إبقاء البروتوكول داخل `docs/technical/`.
- [ ] استخدام مسار قائم داخل `client/lib/features/conversations/` لعقد ملكية
      conversations وdevice workspace sidebar، وعدم إنشاء feature وهمية باسم
      `client/lib/features/device_workspace/`.
- [ ] تقييم الحاجة إلى عقد قريب داخل `agent/lib/evolution/db/runtime/` لقواعد
      persistence والحالة التشغيلية.
- [ ] تقييم الحاجة إلى عقد داخل `agent/lib/interfaces/platforms/sanad_gateway/`
      أو `handlers/` لحدود dispatcher/handler.
- [ ] تقييم `scripts/AGENTS.md` مع إبقاء `scripts/sanad_dev/AGENTS.md` لعقده
      المتخصص.
- [ ] إضافة العقود التي يثبت احتياجها فقط، وتحديث فهرس عقد الأب و`llms.txt`.

### Gate D — الاختصار ونقل المعرفة

- [ ] اختصار العقود العامة لتحتوي القواعد المشتركة فقط.
- [ ] نقل تفاصيل المعمارية والبروتوكولات إلى `docs/technical/` أو
      `docs/agent_engine/` أو `docs/product/` حسب الملكية.
- [ ] نقل خطوات التشغيل التفصيلية إلى skill أو script مناسب بدل تكرارها داخل
      العقود.
- [ ] إزالة التكرار والتناقض بين العقد الأعلى والعقود المحلية.
- [ ] إبقاء الروابط والإشارات المختصرة اللازمة للوصول إلى الوثيقة المالكة دون
      نسخ محتواها داخل العقد.

### Gate E — التحقق النهائي

- [ ] كل عقد نشط مذكور مرة واحدة في `docs/llms.txt` وفي فهرس عقد الأب المناسب.
- [ ] لا يحتوي `llms.txt` تفاصيل أو عقودًا من `refrence_projects/`؛ يحتوي الرابط
      العام فقط.
- [ ] `docs/llms.txt` متتبع، و`docs/llms-full.txt` غير متتبع.
- [ ] تشغيل المولد مرتين يعطي الناتج نفسه دون diff إضافي.
- [ ] pre-commit يولد ويضيف `llms.txt` إلى الـcommit نفسه تلقائيًا، ويفشل إذا
      بقي التغيير خارج الـindex، ولا يضيف `llms-full.txt`.
- [ ] لا توجد مسارات مطلقة أو روابط مكسورة.
- [ ] لا توجد تفاصيل تصميمية أو إجراءات طويلة متبقية داخل العقود.
- [ ] العقود المحلية لا تناقض العقود الأعلى.

## 4. الملفات المتوقعة

- `.gitignore`
- مصدر pre-commit أو installer المتتبع الذي يحدده Gate A
- `scripts/generate_llms_txt.dart`
- `scripts/lint_wiki.dart`
- `docs/llms.txt`
- `AGENTS.md`
- `agent/AGENTS.md`
- `agent/lib/interfaces/AGENTS.md`
- `client/AGENTS.md`
- `client/lib/features/AGENTS.md`
- العقود المحلية التي يثبت التدقيق الحاجة إليها
- وثائق `docs/` المالكة للمحتوى المنقول

## 5. سيناريو التحقق

- تشغيل مولد الفهرس وwiki linter باستخدام FVM بنجاح.
- فحص تنسيق diff وحالة تتبع `docs/llms.txt` وتجاهل `docs/llms-full.txt`.
- تشغيل المولد مرة ثانية دون ظهور تغيير جديد في `docs/llms.txt`.
- إثبات أن تعديل عقد أو وثيقة يجعل pre-commit يضع الفهرس المحدث داخل الـcommit
  نفسه، مع نظافة working tree منه بعد commit، ودون إضافة `docs/llms-full.txt`.

## 6. تعريف الاكتمال

- [ ] `llms.txt` متاح مباشرة بعد checkout لأنه جزء من Git.
- [ ] خريطة العقود كاملة وحتمية وقابلة للمراجعة داخل PR.
- [ ] المشاريع المرجعية ممثلة برابط عام فقط.
- [ ] العقود مختصرة ومقسمة حسب الملكية وكثافة المعلومات.
- [ ] المولد والـlinter وpre-commit ينجحون على جهاز جديد وداخل worktree.
- [ ] لم يتغير كود الإنتاج في `agent/` أو `client/`.
