---
title: "خطة عمل: تحسين بناء السياق وإصلاح أخطاء الوكيل"
description: "خطة عمل لتحسين بناء السياق وإصلاح أخطاء الوكيل في sanadagent-local"
---
# خطة عمل: تحسين بناء السياق وإصلاح أخطاء الوكيل (sanadagent-local)

تهدف هذه الخطة إلى مراجعة وتحسين طريقة بناء رسالة النظام (System Prompt) للوكيل `sanadagent-local` بناءً على أفضل الممارسات والملاحظات الهندسية والأمنية الأخيرة.

---

## 📊 مقارنة مكونات نافذة السياق (Context Window Comparison)

مقارنة بين محتويات رسالة النظام وهيكل السياق في كلا المشروعين:

| المكون / الطبقة | السلوك المستهدف | الوضع الحالي في `sanadagent-local` |
| :--- | :--- | :--- |
| **Stable Tier (طبقة الهوية الثابتة)** | - الهوية الأساسية (تصل إلى 7 أسطر مفصلة تدعم الفعالية المباشرة وتجنب الإسهاب).<br>- إرشادات استخدام الأدوات (مثل الذاكرة، إدارة المهارات، الكمبيوتر).<br>- إرشادات التشغيل الخاصة بنوع الموديل (مثل conciseness، التثبت قبل التعديل لـ OpenAI/Google).<br>- كشاف المهارات (المخزنة محلياً).<br>- تلميحات البيئة والمنصة النشطة (WSL، macOS، إلخ). | - هوية افتراضية مبسطة جداً (سطران فقط: "You are SanadAgent, a helpful...").<br>- (تفتقد لإرشادات التثبت والConciseness والتعامل مع الأدوات ونظم تشغيل WSL/Windows). |
| **Context Tier (طبقة سياق العمل)** | - رسالة النظام المحددة من المستخدم.<br>- ملفات سياق المشروع (يتم تحميل **ملف واحد فقط** من المجلد الحالي بناءً على الأولوية: `.reference.md` أو `AGENTS.md` أو `CLAUDE.md` أو `.cursorrules` بحد أقصى 20 ألف حرف). | - ملفات سياق المشروع (يتم الصعود للمجلدات الأب وجلب **كافة** ملفات `AGENTS.md` و `CLAUDE.md` بحد أقصى 4000 حرف للملف الواحد).<br>- قائمة المهارات المتوفرة.<br>- قائمة الأدوات (مكررة، سيتم إزالتها). |
| **Volatile Tier (الطبقة المتغيرة)** | - لقطة من الذاكرة الطويلة (`memory`).<br>- ملف ملفات تعريف المستخدم (`user profile`).<br>- سياق الذاكرة الخارجية.<br>- سياق تشغيل الجلسة النشط (التاريخ اليومي، معرّف الجلسة، الموديل الفعلي، المزود). | - التاريخ اليومي.<br>- سياق الذاكرة المسترجعة (Facts).<br>- نص ثابت يعلم الوكيل بوجود ذاكرة ويجب نقله إلى الطبقة الأنسب. |

---

## 🧠 مراجعة وتحسين الذاكرة والـ Persona والـ Caching والأمان

### 1. الـ Prompt Caching على مستوى العميل (Client-Side Caching)
* **المشكلة**: يقوم `LocalRuntimeOrchestrator` بإعادة قراءة جميع ملفات القواعد من القرص الصلب والبحث عن المهارات في كل turn، مما يسبب عمليات إدخال وإخراج (I/O) غير ضرورية.
* **التحسين**: سنقوم بإضافة ذاكرة مؤقتة بسيطة (Cache) في كلاس `LocalRuntimeOrchestrator` أو `AgentContextAssembler` لحفظ الـ `context` block؛ بحيث لا يتم إعادة بنائه وقراءة الملفات من القرص إلا عند بدء الجلسة أو عند تغير مجلد العمل (Workspace Path).

### 2. ميزانية التعليمات الذكية والترتيب الهرمي (Hierarchical Budgeting)
* **المشكلة**: يقرأ `RuntimeContextBuilder` ملفات التعليمات بالترتيب المعكوس (الأب `C:\` أولاً ثم ينزل للمشروع الفرعي `sanadagent-local`). هذا يعني أنه إذا وصلنا للحد الأقصى للميزانية، سيتم تجاهل أو قص ملف المشروع الفرعي (الـ Leaf) وهو الأهم، والاحتفاظ بملف الأب العام. كما أن آلية القص الحالية من بداية الملف فقط قد تتلف معنى العقد وتفقد القواعد الختامية المهمة.
* **التحسين**:
  - عكس اتجاه الاكتشاف ليقرأ المشروع الفرعي أولاً (أولوية قصوى) ثم يتدرج للمجلدات الأعلى.
  - اعتماد **ميزانية مجمعة ذكية** لملفات `AGENTS.md` فقط:
    - حد أقصى **`20,000` حرف لكل ملف**.
    - حد أقصى **`40,000` حرف إجمالي** لكل ملفات `AGENTS.md` المجمعة في الـ prompt.
  - آلية الدمج المقترحة:
    - إذا كان مجموع الملفات بعد تطبيق الحد الفردي `20,000` حرف لكل ملف **لا يتجاوز `40,000`**، يتم تضمين جميع الملفات دون أي قص إضافي.
    - إذا تجاوز المجموع `40,000`، يتم تطبيق **قص ذكي تدريجي** على الملفات الأقل أولوية أولاً (الأبعد عن مجلد العمل النشط)، مع الحفاظ على الملفات الأقرب للمجلد النشط كاملة قدر الإمكان.
  - اعتماد **Head + Tail Truncation** بدلاً من الاقتصاص من بداية الملف فقط؛ بحيث يتم الاحتفاظ ببداية الملف ونهايته مع وضع علامة توضيحية في المنتصف، لأن عقود `AGENTS.md` غالباً تحتوي على تعريفات مهمة في البداية وقيود/DoD مهمة في النهاية.

### 3. الفحص الأمني وحقن التعليمات (Sanitization & Threat Scanning)
* **المشكلة**: يتم تحميل ملفات مثل `SOUL.md` وعقود `AGENTS.md` خام تماماً دون أي فحص، مما قد يتيح هجمات حقن التعليمات (Prompt Injection).
* **التحسين**: سنضيف ميثود تحقق أمني مبسطة (Regex Check) في `AgentContextAssembler` و `RuntimeContextBuilder` تفحص الملفات قبل تحميلها، وتبحث عن العبارات الشائعة للحقن (مثل: `ignore previous instructions` أو `system prompt override` أو `you are now a`)؛ وإذا تم اكتشافها، يتم حجب المحتوى الخبيث واستبداله بنص تحذيري آمن.

### 4. ترقية الهوية الافتراضية بالضوابط التشغيلية (Enhanced Identity & Persona)
* **المشكلة**: نص الهوية الافتراضي لـ SanadAgent بسيط جداً ولا يوجه الوكيل للعمل البرمجي السليم.
* **التحسين**: توسيع `_defaultIdentity` ليشمل قواعد التشغيل الصارمة:
  - إعطاء الأولوية للعمل والأدوات الفاعلة على حساب التخطيط النصي الطويل.
  - وجوب قراءة محتوى الملفات والتأكد منها قبل الشروع في التعديل.
  - كتابة كود نظيف وقابل لإعادة الاستخدام، والالتزام بالاختصار والنفع.

### 5. تنظيف الذاكرة وحفظ الحقائق (Facts Extraction & Search Clean)
* **المشكلات**:
  - **البحث اللفظي (prefetch)**: تفشل مطابقة الكلمات التي تلتصق بها علامات الترقيم (مثل `like?` أو `Ahmed.`) بالحقائق المخزنة.
  - **الاستخراج والتخزين**: عند استخلاص الاسم أو التفضيل، يتم تخزين علامات الترقيم الملتصقة بالنهاية (مثل تخزين `"Ahmed."` بالنقطة).
* **التحسين**:
  - تنظيف نص الاستعلام وإزالة علامات الترقيم منه بالكامل في `prefetch` قبل مقارنة الكلمات بالحقائق.
  - تنظيف الكلمات المستخلصة (الاسم والتفضيلات) من علامات الترقيم الختامية في ميثود `_extractFactsFromText` قبل حفظها في الـ SQLite.

---

## 🎯 الأهداف والمشاكل المراد حلها

1. **إصلاح مشكلة تكرار رسائل النظام (Double System Messages)**.
2. **ترتيب طبقات السياق لدعم الـ Prefix Caching** (`stable` ← `context` ← `volatile`).
3. **إزالة الأدوات المكررة من الـ System Prompt**.
4. **تعديل اتجاه قراءة ملفات القواعد وتحديد ميزانية ذكية** (من الأسفل للأعلى، حد أقصى 40k إجمالي و 20k للملف مع قص ذكي تدريجي).
5. **إضافة فحص أمني ضد حقن التعليمات** لـ `SOUL.md` وملفات العقود بحد أقصى `20,000` حرف لـ `SOUL.md`.
6. **حقن معلومات التشغيل** (الموديل ورقم الجلسة والمزود) وترقية الهوية الافتراضية بالضوابط العملية.
7. **إصلاح وتنظيف استرجاع واستخراج الذاكرة اللفظية** (إزالة علامات الترقيم في البحث والتخزين).
8. **عمل نظام كاش محلي للـ Context** لتجنب تكرار قراءة القرص I/O في كل turn.

---

## 🛠️ التغييرات المقترحة في الملفات

### 1. الـ Plugins والذاكرة

#### [MODIFY] [vector_memory_plugin.dart]
- إزالة ميثود `preExecution` بالكامل لمنع الازدواجية.
- تعديل ميثود `prefetch` لتنظيف علامات الترقيم من استعلام البحث.
- تعديل ميثود `_extractFactsFromText` لتنظيف علامات الترقيم الختامية للحقائق المستخرجة قبل الحفظ:
  ```dart
  // Heuristic 1: Names
  if (lowerText.contains('my name is')) {
    final index = lowerText.indexOf('my name is') + 'my name is'.length;
    var name = text.substring(index).trim().split(' ').first;
    name = name.replaceAll(RegExp(r'[^\w]+$'), ''); // Clean trailing punctuation
    if (name.isNotEmpty) _addFact('User name is $name');
  }
  // Heuristic 2: Preferences
  if (lowerText.contains('i like')) {
    final index = lowerText.indexOf('i like') + 'i like'.length;
    var preference = text.substring(index).trim();
    preference = preference.replaceAll(RegExp(r'[^\w]+$'), ''); // Clean trailing punctuation
    if (preference.isNotEmpty) _addFact('User likes $preference');
  }
  ```

---

### 2. محرك بناء السياق (Engine Context)

#### [MODIFY] [agent_context_assembler.dart]
- تعديل ميثود `assemble()` للترتيب الأنسب للـ Cache: `stable` ثم `context` ثم `volatile`.
- ترقية نص `_defaultIdentity` بإضافة الضوابط التشغيلية.
- حد حجم `SOUL.md` ليكون بحد أقصى `20000` حرف في `_loadSoulMd`.
- إضافة ميثود `_sanitizeContent` لفحص حقن التعليمات أمنياً وتطبيقها على هوية SOUL:
  ```dart
  static String _sanitizeContent(String content, String filename) {
    final lower = content.toLowerCase();
    final injectionPatterns = [
      'ignore previous instructions',
      'ignore all instructions',
      'system prompt override',
      'you are now a',
    ];
    for (final pattern in injectionPatterns) {
      if (lower.contains(pattern)) {
        return '[SECURITY WARNING: Content from $filename was blocked because it contained potential prompt injection patterns. Content not loaded.]';
      }
    }
    return content;
  }
  ```
- تحديث معلومات الـ volatile لتشمل بيانات التشغيل الإضافية (اسم الموديل والمزود ورقم الجلسة).

#### [MODIFY] [runtime_context_builder.dart]
- إلغاء استدعاء وتوليد ميثود `_renderToolSummaries` في `build()`.
- ضبط حدود حجم الملفات لحفظ توازن التوكنز:
  - تعديل `_maxInstructionChars` إلى `20000`.
  - تعديل `_maxTotalInstructionChars` إلى `40000`.
- تعديل `_discoverInstructionFiles` لإبقاء مجلد CWD في المقدمة (بدون عمل `reversed` لملفات المستودع) لضمان أولوية العقد الفرعي النشط.
- حصر الميزانية المجمعة الذكية على ملفات `AGENTS.md` مع الحفاظ على إمكانية تحميل بقية ملفات التعليمات المدعومة حسب سياسة السياق الحالية.
- تحديث منطق التجميع ليعمل بهذه القاعدة:
  - العقود الأقرب للمجلد النشط تُضاف أولاً.
  - كل ملف يُطبّق عليه حد فردي `20,000` حرف.
  - إذا تجاوز مجموع ملفات `AGENTS.md` حد `40,000`، يبدأ القص الذكي التدريجي من الملفات الأقل أولوية أولاً.
- تطبيق ميثود `_sanitizeContent` على كافة عقود التعليمات قبل دمجها.
- تعديل ميثود `_describeFile` لتمييز العقود: `[Local Project Contract]` و `[Parent Contract]`.
- إضافة ترويسة توضيحية لسياسة أسبقية العقود الفرعية.
- استبدال `_truncate` الحالية بآلية **Head + Tail Truncation**، مع رسالة توضح عدد الأحرف المحتفظ بها وعدد الأحرف الأصلية.

---

### 3. نظام الكاش وتدفق الطلبات (Orchestration & Cache)

#### [MODIFY] [local_runtime_orchestrator.dart]
- تطبيق نظام كاش محلي مبسط لـ `_buildRuntimeContext`؛ بحيث يحتفظ بآخر سياق مبني ومجلد العمل النشط المقابل له.
- في حالة تطابق مجلد العمل (Workspace Path) ووجود سياق مخزن مؤخراً، يتم إرجاعه مباشرة وتخطي إعادة بناء السياق وقراءة القرص (I/O).
- يتم إفراغ الكاش وبناء سياق جديد فقط عند تغير الجلسة أو مجلد العمل.

---

### 4. ملفات الاختبارات (Unit Tests)

#### [MODIFY] [agent_context_assembler_test.dart]
- تحديث مجموعة اختبارات `tier ordering` للتأكد من أن `stable` تظهر قبل `context` وتظهر `context` قبل `volatile`.
- إضافة اختبارات للتحقق من كفاءة اقتطاع حجم `SOUL.md` وفحص حقن التعليمات أمنياً.

#### [MODIFY] [plugins_test.dart]
- تعديل أو إزالة اختبار `VectorMemoryPlugin extracts facts and injects context` الذي كان يختبر `preExecution` المباشر للـ Plugin، واستبداله باختبار يضمن عمل `prefetch` وتنظيف علامات الترقيم واستخراج الحقائق بشكل سليم.

#### [MODIFY] [runtime_catalog_test.dart]
- إزالة توقعات الاختبار التي تبحث عن `Available runtime tools:` أو `web.search` في السياق المستخرج من الـ Builder.

---

### 5. التوثيق (Documentation)

#### [MODIFY] [sanadagent-local/AGENTS.md]
- تحديث توثيق الـ `AgentContextAssembler` ليوضح التصميم الجديد: ترتيب الطبقات (`stable` ← `context` ← `volatile`) والمبادئ الأساسية لدعم كفاءة الـ KV-Cache.

---

## 🧪 خطة التحقق والتدقيق (Verification Plan)

### الاختبارات التلقائية
سنقوم بتشغيل الاختبارات للتأكد من خلو المشروع من أي كسر:
1. `fvm dart analyze` للتأكد من سلامة الأكواد وخلوها من الأخطاء البرمجية الثابتة.
2. `fvm dart test test/engine/agent_context_assembler_test.dart` لضمان عمل الترتيب الجديد وقواعد الأمان.
3. `fvm dart test test/engine/plugins_test.dart` لضمان توافق الـ plugin مع البنية الجديدة والذاكرة النظيفة.
4. `fvm dart test test/capabilities/runtime_catalog_test.dart` للتأكد من عمل الـ builder بدون توليد الأدوات.
5. تشغيل كل الاختبارات للتأكد من عدم حدوث أي تراجع: `fvm dart test`.
