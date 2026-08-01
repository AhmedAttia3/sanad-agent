# بناء مثبت Sanad Client على Windows

هذا الدليل مخصص للمساهم الذي يبني حزمة Windows. المستخدم النهائي يحمل
`sanad-client-<version>-windows-x64.exe` من GitHub Releases ولا يحتاج إلى
Flutter أوFVM.

## المتطلبات

- Windows 10 أوأحدث بنواة 64-bit.
- Flutter SDK المثبت عبر FVM.
- Visual Studio مع Desktop development with C++.
- NSIS لبناء المثبت الأساسي.

يستخدم مسار البناء الرسمي `sanad_client_installer.nsi`. يوجد ملف Inno Setup
لأعمال التطوير والمقارنة، لكنه ليس المسار الذي يستدعيه
`build_installer.ps1`.

## بناء المثبت الرسمي

من جذر المستودع:

```powershell
cd client
powershell -ExecutionPolicy Bypass -File release/windows/build_installer.ps1
```

ينفذ السكربت التنظيف، وجلب الحزم، وبناء Flutter مع `config/prod.json`، وتجهيز
Microsoft Visual C++ Redistributable، ثم بناء NSIS installer. لا حاجة إلى
تشغيل أوامر Flutter نفسها يدويًا قبل السكربت.

لاختيار ملف إعداد آخر:

```powershell
powershell -ExecutionPolicy Bypass -File release/windows/build_installer.ps1 `
  -EnvConfig config/dev.json
```

ينتج المثبت النهائي في:

```text
client/build/sanad-client-<version>-windows-x64.exe
```

يستخدم NSIS الاسم المؤقت `sanad-client-setup.exe` أثناء البناء فقط، ثم يوقع
مسار الإصدار الملف التنفيذي الداخلي والمثبت ويعتمد الاسم versioned أعلاه.
يرفض البناء الرسمي حزمة غير موقعة؛ خيار السماح ببناء غير موقع مخصص للتطوير
المحلي ولا ينتج release candidate.

يشمل المثبت التطبيق وملفات DLL وassets المطلوبة، ويضيف اختصارات قائمة Start
وسطح المكتب وإلغاء التثبيت. كما يثبت Visual C++ Redistributable المضمن عند
الحاجة.

## بناء تطبيق Portable

يمكن اختبار التطبيق أو توزيعه داخليًا دون installer عن طريق ضغط المجلد:

```text
client/build/windows/x64/runner/Release/
```

يجب ضغط المجلد كاملًا، وليس `sanad-client.exe` وحده، لأن التطبيق يعتمد على
ملفات DLL ومجلد `data/` وFlutter assets الموجودة بجواره.

نسخة Portable ليست بديلًا عن الحزمة الرسمية عند النشر؛ يجب أن يكون اسمها
ومعمارية Windows والـchecksum واضحين إذا أضيفت إلى GitHub Releases.

## محتويات الحزمة

يتحقق مسار البناء من وجود:

- `sanad-client.exe`.
- `flutter_windows.dll` وملفات plugin DLL.
- مجلد `data/` بما فيه ICU وFlutter assets.
- الخطوط والموارد المضمنة.
- Microsoft Visual C++ Redistributable.

لا تضف أسرارًا أوملفات إعداد محلية إلى Flutter assets. ملف البيئة المضمن يجب
أن يكون إعداد إصدار آمنًا ومقصودًا للنشر.

## التحقق

شغّل فحص المثبت على بيئة Windows نظيفة:

```powershell
powershell -ExecutionPolicy Bypass -File release/windows/verify_installer.ps1
```

قبل النشر يجب التحقق من:

- التوقيع الرقمي.
- تثبيت التطبيق وتشغيله.
- اتصال العميل بالوكيل المحلي.
- إلغاء التثبيت.
- تطابق اسم الملف مع GitHub Release ومسار التحديث.

ملفات الشهادات ومفاتيح التوقيع لا تحفظ داخل المستودع، وتوفرها بيئة CI
المحمية فقط.

## اختبار دورة الحياة

لا يكفي نجاح إنشاء ملف EXE. اختبر بالترتيب:

1. التثبيت على حساب Windows لا يحتوي Flutter أوFVM.
2. تشغيل Sanad Client من قائمة Start ومن اختصار سطح المكتب.
3. اكتشاف الوكيل المحلي أوعرض مسار تثبيته بصورة صحيحة.
4. تسجيل الدخول وربط جهاز بعيد عند اختبار الوضع المتصل.
5. التحديث من إصدار أقدم موقّع.
6. إلغاء التثبيت والتأكد من إزالة ملفات البرنامج والاختصارات.
7. تثبيت الإصدار السابق مرة أخرى عند اختبار rollback.

حالة المستخدم وSanad Home ليست جزءًا من ملفات البرنامج؛ لا تحذف بيانات
المستخدم ضمن uninstall إلا من خلال خيار صريح ومراجع.

## استكشاف الأخطاء

### لم يعثر السكربت على NSIS

ثبت NSIS وتأكد أن `makensis.exe` موجود في أحد مسارات التثبيت المعتادة أوعلى
`PATH`.

### مجلد Release غير موجود

تحقق من تثبيت Visual Studio workload المطلوب ومن نجاح:

```powershell
fvm flutter doctor
fvm flutter build windows --release --dart-define-from-file=config/prod.json
```

### يعمل التطبيق من مجلد البناء ولا يعمل بعد التثبيت

راجع محتويات المثبت، ووجود DLL و`data/`، وسياسة antivirus، ونتيجة التوقيع
الرقمي. شغّل `verify_installer.ps1` قبل إعادة بناء الحزمة.

## أسئلة شائعة

**هل يحتاج المستخدم إلى Flutter أوFVM؟**

لا. هذه أدوات بناء للمساهمين فقط، والحزمة النهائية تتضمن Flutter runtime
والملفات اللازمة لتشغيل التطبيق.

**هل يدعم المثبت العربية والإنجليزية؟**

نعم، يضم سكربت NSIS لغتي واجهة المثبت الإنجليزية والعربية، بينما لغة التطبيق
تتبع إعداداته.

**هل يمكن نشر Inno Setup بدل NSIS؟**

يمكن تطوير مسار Inno Setup، لكن لا يعامل كحزمة رسمية قبل تحديث بياناته
ومساراته وإدخاله في CI والتحقق من ناتجه. مسار الإصدار الحالي في هذا المجلد هو
NSIS.

**هل يمكن تشغيل نسخة 32-bit؟**

الحزمة الحالية تستهدف Windows x64. أي معمارية إضافية تحتاج build artifact
واسم ملف واختبارات تثبيت وتحديث مستقلة.
