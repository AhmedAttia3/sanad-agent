---
title: "Task 52: Conversation Fork with Materialized History"
description: "إنشاء fork مستقل من أي final answer دائمة عبر نسخ ذري لتاريخ المحادثة حتى نقطة الاختيار مع lineage وتسمية متسلسلة."
status: "planned"
priority: "high"
scope: "Sanad agent session persistence/protocol and Flutter conversation timeline/navigation"
depends_on: "Task 51 stable message/turn identity and active-history contract, Task 35 terminal-state consistency"
coordinates_with: "Task 47 session history pagination, Task 44 background session titles"
---

# Task 52: Conversation Fork with Materialized History

## 1. المشكلة

يحتاج المستخدم إلى بدء مسار جديد من إجابة نهائية سابقة دون تغيير المحادثة
الأصلية. يجب ألا يعتمد fork على الرسائل المحملة حاليًا في Flutter أو ينسخ
الرسالة المختارة وحدها، وألا يعيد تنفيذ tools حدثت قبل نقطة الفرع.

المعمارية المعتمدة هي **materialized copy**: ينشئ daemon جلسة جديدة وينسخ
السجلات النشطة من بداية المصدر حتى `final answer` المختارة داخل معاملة واحدة.
لا تستخدم الجلسة الجديدة message rows مشتركة مع الأصل، وتبقى الجلستان مستقلتين
تمامًا بعد نجاح العملية.

## 2. الهدف

1. إظهار زر `Fork` أسفل كل `final answer` دائمة وقابلة للتحديد بهوية ثابتة.
2. إنشاء جلسة جديدة من كامل prefix حتى الإجابة المختارة، شاملًا reasoning،
   tool calls/results، metadata، وprovider state اللازم لاستكمال السياق.
3. تنفيذ إنشاء الجلسة والنسخ وتخصيص اسم الفرع داخل معاملة DB واحدة بلا جلسة
   جزئية أو نسخ best-effort.
4. إبقاء الجلسة الأصلية قابلة للاستمرار وعدم تعديل رسائلها أو حالتها.
5. فتح الجلسة الجديدة مباشرة أمام المستخدم بعد نجاح daemon، مع استقلال كامل
   لكل الرسائل والجولات اللاحقة.
6. حفظ lineage ونقطة fork مع بقاء الفرع صالحًا إذا حُذفت الجلسة الأصلية.

## 3. قرارات التصميم الملزمة

### 3.1 نقطة الـFork

- الهدف يجب أن يكون canonical `final_answer` دائمة، terminal، ونشطة، وتحمل
  `message_id + turn_id` ثابتين.
- يرسل client هوية الهدف فقط؛ daemon يقرأ prefix من قاعدة البيانات ولا يثق
  بقائمة الرسائل المحملة أو paginated في الواجهة.
- يشمل prefix كل السجلات النشطة من بداية الجلسة حتى نهاية الـturn المالكة
  للإجابة المحددة inclusive، وليس final answer وحدها.
- لا تُنسخ queued inputs أو pending steers أو execution snapshots أو partial
  events الواقعة بعد الإجابة المختارة.
- إذا لم تعد الإجابة نشطة أو لم تكن terminal، يفشل الأمر بنتيجة typed دون
  إنشاء جلسة.

### 3.2 نموذج التخزين والاستقلال

- ينشئ fork صف session جديدًا وصفوف messages جديدة بهويات جديدة.
- تحتفظ الرسائل المنسوخة بهويتها الأصلية في حقل lineage اختياري مثل
  `origin_message_id`، لكن لا تشارك الصف نفسه مع المصدر.
- تحفظ النسخة content، roles، tool identity/pairs، reasoning، finish state،
  provider state، metadata، وترتيب العرض/السياق بصورة lossless.
- يبدأ الفرع في حالة `idle` بلا active run أو work item أو queue من المصدر.
- تنفذ العملية بمعاملة واحدة ويفضل نسخ DB-native set-based؛ أي فشل يعيد rollback
  للجلسة والرسائل والاسم معًا.
- لا يعاد تنفيذ أي tool أثناء الإنشاء؛ المنسوخ هو التاريخ الدائم فقط.

### 3.3 Lineage والحذف

- لكل شجرة فروع `lineage_id` ثابت مستقل عن عمر أي session row.
- تحفظ الجلسة الجديدة `parent_session_id`, `forked_from_message_id`,
  `forked_from_turn_id`, و`fork_sequence`.
- حذف الأصل لا يحذف الفروع ولا رسائلها؛ علاقة الأب تستخدم `SET NULL` أو عقدًا
  مكافئًا، بينما يبقى `lineage_id` وبيانات نقطة الفرع محفوظين.
- حذف فرع لا يؤثر على الأصل أو الأشقاء أو عداد lineage المستخدم سابقًا.

### 3.4 التسمية

- اسم أول fork هو `(1) <base session title>` ثم `(2) ...` وهكذا.
- العداد فريد ومتزايد على مستوى `lineage_id` كله، بما في ذلك branch-from-branch.
- تخصيص الرقم ذري ومحمي بقيد uniqueness أو retry منظم لمنع اسمين بالرقم نفسه.
- يحفظ base title كبيانات lineage/branch واضحة؛ لا يعتمد النظام على regex قد
  يزيل بادئة كتبها المستخدم بنفسه.
- يستخدم fork اسم الجلسة الحالية المنظّم عند الإنشاء، ولا يغير اسم المصدر.

### 3.5 فتح الفرع وتجربة الفشل

- يظهر زر Fork فقط عندما تكون الإجابة دائمة وهوية الهدف متاحة.
- الضغط المتكرر أثناء الطلب معطل، ويحمل الأمر `request_id` لجعله idempotent.
- بعد نجاح daemon يضيف client الجلسة إلى cache/sidebar ويعرضها مباشرة.
- إذا نجح الإنشاء وفشل navigation محليًا، تبقى الجلسة الجديدة محفوظة وقابلة
  للفتح من sidebar؛ لا يعاد fork تلقائيًا.
- فشل daemon قبل commit يبقي المستخدم في الأصل ولا يظهر جلسة وهمية.

## 4. بوابة التنفيذ

- [ ] اعتماد schema للـlineage، نقطة fork، sequence، وorigin identities.
- [ ] اعتماد تعريف prefix canonical وحد الـturn inclusive.
- [ ] حسم حقول session التي تُنسخ وحقول runtime التي تبدأ فارغة.
- [ ] توثيق command/result ونتائج الفشل وidempotency قبل تعديل الواجهة.
- [ ] تحديد سلوك العناوين بعد rename دون الاعتماد على تحليل النص وحده.
- [ ] إثبات أن التنفيذ يقرأ التاريخ server-side ولا يعتمد على pagination client.

## 5. النطاق المرحلي

### Gate A — Persistence and lineage schema

- [ ] إضافة `lineage_id`, parent/fork target metadata، وfork sequence للجلسات.
- [ ] إضافة origin identity للرسائل المنسوخة عند الحاجة للتدقيق.
- [ ] تعريف قيود وفهارس lineage والعداد ونقطة الهدف.
- [ ] migration للجلسات الحالية يجعل كل جلسة قائمة root lineage مستقلة.
- [ ] تثبيت delete behavior بحيث لا يوجد cascade من الأصل إلى الفرع.

#### Gate A Exit

- [ ] يمكن حذف parent مع بقاء child قابلة للقراءة والاستمرار.
- [ ] branch-from-branch يحتفظ بنفس lineage ويخصص sequence جديدة صحيحة.

### Gate B — Atomic daemon fork command

- [ ] إضافة command canonical مثل `session.fork` بهوية المصدر والـfinal target
      و`request_id` idempotent.
- [ ] التحقق من أن المصدر والهدف ينتميان للجهاز/النطاق المصرح بهما.
- [ ] تثبيت snapshot للـprefix حتى نهاية target turn داخل المعاملة.
- [ ] إنشاء session والاسم ونسخ prefix losslessly في معاملة واحدة.
- [ ] إنشاء message identities جديدة مع origin references وعدم نسخ runtime work.
- [ ] إعادة result يحمل child session summary والlineage ونقطة fork.
- [ ] تكرار command بنفس request identity يعيد النتيجة نفسها ولا ينشئ فرعًا آخر.

#### Gate B Exit

- [ ] لا توجد جلسة جزئية عند فشل أي سجل أو قيد أو تخصيص اسم.
- [ ] المصدر لا يتغير والفرع يبدأ `idle` ويمكن إرسال رسالة جديدة إليه.

### Gate C — Client timeline and navigation

- [ ] إضافة `Fork` أسفل كل final answer مؤهلة، لا الأخيرة فقط.
- [ ] تمرير target identity إلى daemon دون إرسال transcript من client.
- [ ] منع الضغط المزدوج وعرض progress/failure غير هدّام في الرسالة المالكة.
- [ ] بعد النجاح تحديث cache/sidebar واختيار child وفتح timeline الخاصة بها.
- [ ] إبقاء الأصل في cache وتاريخه دون أي optimistic truncation أو mutation.
- [ ] التعامل مع final answers المحملة عبر pagination بنفس السلوك.

#### Gate C Exit

- [ ] fork من إجابة قديمة يفتح child تحتوي prefix الصحيح فقط.
- [ ] الرجوع إلى الأصل يعرض كامل تاريخه ويمكن متابعة العمل فيه بشكل مستقل.

### Gate D — History fidelity and continuation

- [ ] التحقق من نسخ user/assistant/tool/reasoning/provider metadata دون فقد.
- [ ] الحفاظ على tool call/result pairing وترتيب model steps داخل prefix.
- [ ] استبعاد كل event بعد target final حتى لو كان محملًا في client.
- [ ] إرسال turn جديدة في child لا يضيف أو يعدل أي سجل في parent والعكس.
- [ ] reconnect/restart يعيدان lineage والفرع والتاريخ نفسه.

### Gate E — Verification and documentation

- [ ] اختبارات DB للنسخ الذري، rollback، ترتيب prefix، والهويات الجديدة.
- [ ] اختبارات lineage للأسماء المتزامنة، branch-from-branch، rename، وحذف parent.
- [ ] اختبارات protocol للهدف غير الموجود/غير terminal/superseded وidempotency.
- [ ] اختبارات fidelity تشمل reasoning وأدوات وprovider state وmetadata كبيرة.
- [ ] اختبارات client widget لكل final answer، الضغط المزدوج، الفشل، والnavigation.
- [ ] اختبار daemon-backed لجلسة بها عدة turns وfork من إجابة وسطية ثم استمرار
      parent وchild برسالتين مختلفتين.
- [ ] تحديث وثائق product/technical/database/QA وفهارسها ذات الصلة.

## 6. Definition of Done

- [ ] كل final answer دائمة ومؤهلة تعرض Fork.
- [ ] child تحتوي كل التاريخ النشط حتى الإجابة المختارة فقط وبترتيب lossless.
- [ ] الإنشاء والنسخ والاسم atomic ولا يتركون partial session.
- [ ] parent وchild لا تشتركان في message rows وتستمران بصورة مستقلة.
- [ ] الأسماء `(1)`, `(2)`, ... فريدة عبر lineage كاملة تحت التزامن.
- [ ] حذف parent لا يحذف child، وحذف child لا يؤثر على أي جلسة أخرى.
- [ ] لا تعتمد العملية على الرسائل المحملة في Flutter أو تعيد تنفيذ tools.
- [ ] restart/reconnect/pagination لا تغير نقطة fork أو التاريخ المنسوخ.
- [ ] تحليلات agent/client والاختبارات المركزة والتكاملية المناسبة ناجحة.

## 7. سيناريو النجاح

تحتوي جلسة بعنوان `Refactor auth` على ثلاث جولات، وفي الجولة الثانية tool call
ونتيجة ثم final answer. يضغط المستخدم Fork أسفل إجابة الجولة الثانية. ينشئ
daemon داخل معاملة واحدة جلسة `(1) Refactor auth`، وينسخ كل السجلات النشطة حتى
نهاية الجولة الثانية inclusive بهويات جديدة، ويفتحها client. يرسل المستخدم
رسالة مختلفة في كل من parent وchild؛ لا يظهر أي تغيير متبادل بينهما. بعد حذف
parent وإعادة تشغيل التطبيق، تبقى child وتاريخها وlineage قابلة للفتح والاستمرار.

## 8. خارج النطاق

- shared-prefix/message graph أو deduplication بين الجلسات.
- Fork من user message أو reasoning أو partial/in-flight response.
- دمج فرعين أو إعادة مزامنتهما بعد الإنشاء.
- نسخ queued work أو pending steer أو حالة run من المصدر.
- تغيير سلوك Edit/Retry الذي تملكه Task 51.

## 9. الملفات والوثائق المتوقعة

- `agent/lib/evolution/db/`
- `agent/lib/interfaces/platforms/sanad_gateway/`
- `agent/lib/interfaces/runtime/`
- `client/lib/features/conversations/`
- اختبارات agent/client المركزة والتكاملية
- وثيقة product جديدة لتجربة Conversation Fork
- وثيقة technical جديدة لعقد Session Fork وlineage
- `docs/technical/agent_database_schema.md`
- وثيقة QA جديدة لمصفوفة fork والاستقلال

## 10. سجل التقدم

```text
Date:
Gate/status:
Files changed:
Verification:
Findings:
Next gate:
```
