---
title: "Task 55: GitHub Copilot Subscription Provider"
description: "إضافة GitHub Copilot كمزود اشتراك مباشر داخل Sanad عبر GitHub Device Code وتبادل توكن Copilot، دون CLI أو SDK خارجي."
status: "planned"
priority: "high"
scope: "Sanad agent provider registry, instance-scoped OAuth credentials, model routing, adapters, setup protocol, and documentation"
depends_on: "Plan 29 provider instances and credential isolation; existing Codex device-code runtime; current OpenAI Chat Completions and Responses adapters"
coordinates_with: "Provider setup UI, model catalog, provider protocol, and runtime route selection"
---

# Task 55: GitHub Copilot Subscription Provider

## 1. المشكلة

يدعم Sanad مزودات API key ومزود اشتراك ChatGPT/Codex عبر Device Code، لكنه لا
يسمح للمستخدم الذي يملك اشتراك GitHub Copilot بإضافته كـprovider instance
واستخدام نماذجه داخل Sanad.

المشروع المرجعي `refrence_projects/hermes-agent` يثبت إمكانية الاتصال المباشر
بـCopilot عبر GitHub Device Code ثم استبدال GitHub user token بتوكن Copilot API
قصير العمر. لكن نسخ تكامل Hermes كما هو سيخلق أخطاء مع معمارية Sanad الحالية:

- polling في `ProviderAuthSessionService` موجه حاليًا إلى Codex فقط.
- التشغيل الحديث يخزن الأسرار حسب `provider_instance_id`، بينما refresh القديم
  في `ProviderCredentialResolver` ما زال provider-keyed.
- هيدرز Copilot ليست كلها ثابتة؛ بعضها يعتمد على الطلب ودور turn والرؤية.
- بعض نماذج Copilot تستخدم Chat Completions وبعضها يحتاج Responses API.
- token exchange قد يعيد endpoint خاصًا بحساب Business أو Enterprise.

يجب لذلك إضافة Copilot كمزود مباشر داخل Dart وبأقل امتداد منظم للبنية الحالية،
دون تثبيت Copilot CLI، ودون تضمين Copilot SDK أو agent runtime خارجي.

## 2. الهدف

1. إضافة قالب `github-copilot` إلى Provider Registry وعرضه في مسار إعداد المزودات.
2. تسجيل دخول المستخدم عبر GitHub Device Code باستخدام واجهة Sanad الحالية.
3. استبدال GitHub user token بتوكن Copilot API قصير العمر وتخزينهما بأمان لكل
   provider instance دون اختلاط الحسابات.
4. تجديد توكن Copilot قبل انتهائه وإعادة المحاولة مرة واحدة عند فشل المصادقة.
5. إرسال طلبات النماذج مباشرة من Sanad إلى Copilot API دون CLI أو مكتبة تشغيل خارجية.
6. اختيار Chat Completions أو Responses API حسب الموديل وقدراته الفعلية.
7. دعم endpoint الافتراضي والحسابي المعاد من token exchange دون كسر عزل instances.
8. الحفاظ على agent loop والأدوات والصلاحيات والبث الحالية المملوكة لـSanad.

## 3. قرارات التصميم الملزمة

### 3.1 حد التكامل

- التكامل **HTTP مباشر مكتوب بـDart** ويستخدم عميل HTTP الحالي.
- لا يعتمد التشغيل على `copilot` CLI أو `gh` CLI أو Node.js أو Python.
- لا يضمّن GitHub Copilot SDK ولا يفوض دورة الوكيل إلى process خارجي.
- يبقى Sanad مالكًا للـagent loop، tool calls، permissions، session history،
  cancellation، وstream normalization.
- وضع ACP أو SDK خارجي خارج نطاق هذه المهمة.

### 3.2 هوية تطبيق GitHub

- لا يعتمد إصدار Sanad الإنتاجي على Client ID مملوك لـVS Code أو Hermes.
- يستخدم Device Flow من GitHub App/OAuth App مملوك للمشروع، ويُحفظ Client ID
  في إعداد مركزي غير سري قابل للتغيير دون نشره كقيمة سحرية داخل عدة ملفات.
- لا يُخزن client secret داخل Sanad sanad project.
- تُراجع صلاحيات GitHub المطلوبة بأقل scope ممكن قبل تثبيت العقد.

### 3.3 ملكية التوكن ودورة حياته

- GitHub user token طويل العمر هو مادة إعادة التبادل ولا يرسل إلى Copilot inference API.
- Copilot API token القصير هو `accessToken` المستخدم مع `Bearer`.
- يسجل `expiresAt` من استجابة exchange مع safety margin مركزي قبل الانتهاء.
- تحفظ الحزمة في `SecretStore` حسب `provider_instance_id`، لا حسب template id.
- لا يسجل أي raw token أو authorization header أو exchange response كامل.
- refresh هو إعادة token exchange باستخدام GitHub user token، وليس OAuth
  `grant_type=refresh_token` التقليدي.
- نجاح refresh يحدث credential revision ويبطل adapter المرتبط بالنسخة القديمة.

### 3.4 Device Code وPolling

- يعاد استخدام DTOs وcommands وتجربة UI الحالية لـDevice Code.
- يصبح `poll()` provider-aware ولا يرسل جلسة Copilot إلى parser الخاص بـCodex.
- تُحترم `interval`, `authorization_pending`, `slow_down`, `expired_token`,
  `access_denied`، والإلغاء بصورة typed.
- لا تستبدل credential قديمة صالحة إلا بعد نجاح login وtoken exchange كاملين.

### 3.5 Endpoint وهيدرز الطلب

- يستخدم registry endpoint افتراضيًا موثوقًا لحسابات Copilot العادية.
- إذا أعاد exchange `endpoints.api` أو endpoint حسابيًا صالحًا، يُطبّق على instance
  نفسها فقط ويُتحقق من scheme/host قبل استخدامه.
- يحدد Gate A مكان حفظ endpoint المكتشف دون خلط configuration مع secret material.
- تدعم الطلبات هيدرز Copilot المطلوبة، بما يشمل القيم الثابتة والديناميكية.
- `x-initiator` يعكس أول model request في user turn والطلبات اللاحقة داخل tool loop.
- يضاف vision header فقط عند وجود مدخل رؤية فعلي.

### 3.6 اختيار API حسب الموديل

- لا يثبت قالب Copilot كله على `chat_completions` إذا كانت بعض موديلاته تحتاج Responses.
- يحدد model capability أو catalog endpoint المسار الصحيح لكل موديل.
- يعاد استخدام `BaseOpenAIAdapter` و`CodexResponsesAdapter` حيث تتطابق العقود،
  مع سياسة Copilot صغيرة مشتركة بدل نسخ adapter كامل دون حاجة.
- أي فرق في request/response أو replay state يثبت باختبار قبل إعلان الموديل مدعومًا.
- fallback models لا تحتوي موديلات غير مثبتة باختبار أو catalog موثوق.

## 4. بوابة التنفيذ

- [ ] اعتماد GitHub App/OAuth App المملوك لـSanad وClient ID ونطاق الصلاحيات.
- [ ] تثبيت شكل استجابة device code وtoken exchange وحالات الخطأ المستخدمة.
- [ ] حسم مكان حفظ GitHub user token وCopilot token وendpoint المكتشف لكل instance.
- [ ] حسم آلية refresh-before-request وإبطال adapter revision دون استخدام المخزن القديم.
- [ ] تعريف سياسة `x-initiator` والرؤية وإعادة المحاولة عند `401`.
- [ ] إعداد مصفوفة موديلات تحدد Chat Completions مقابل Responses قبل تعديل fallback list.
- [ ] توثيق قرار عدم استخدام CLI/SDK/ACP في التصميم التقني.
- [ ] تحديد mock fixtures لاختبار OAuth وexchange دون الاتصال الحقيقي في unit tests.

لا يبدأ تعديل runtime قبل إغلاق هذه القائمة وتسجيل القرارات في وثيقة provider protocol.

## 5. النطاق المرحلي

### Gate A — Contract and provider profile

- [ ] إضافة قالب `github-copilot` وaliases ووصف وطريقة مصادقة صحيحة.
- [ ] تحديد protocol/api-mode policy دون الادعاء أن كل الموديلات تستخدم endpoint واحدًا.
- [ ] تحديد constants المركزية لـGitHub OAuth وexchange وdefault Copilot endpoint.
- [ ] إضافة contract typed لنتيجة exchange: token، expiry، وoptional account endpoint.
- [ ] تحديث provider protocol بالملكية ودورة الحياة وحدود التكامل المباشر.

#### Gate A Exit

- [ ] يظهر القالب كـAccount provider يدعم Device Code فقط.
- [ ] لا توجد قيمة سرية أو Client ID لطرف ثالث موزعة في adapter أو UI.
- [ ] تحدد الوثائق بوضوح مخزن كل قيمة ومسؤولية كل طبقة.

### Gate B — GitHub Device Code and token exchange

- [ ] إضافة start flow خاص بـGitHub ضمن `ProviderAuthSessionService`.
- [ ] توجيه polling حسب provider/session handle بدل استدعاء Codex دائمًا.
- [ ] معالجة حالات RFC device flow و`slow_down` والفشل والإلغاء.
- [ ] تنفيذ Copilot token exchange بهيدرز exchange المطلوبة والتحقق من الاستجابة.
- [ ] كتابة SecretRecord للـinstance بعد نجاح المسارين فقط.
- [ ] إبقاء المسار legacy provider-keyed متوافقًا دون جعله أساس التشغيل الجديد.

#### Gate B Exit

- [ ] حسابان Copilot متوازيان لا يتبادلان session أو token أو نتيجة polling.
- [ ] فشل exchange لا يمحو credential سابقة ولا يجعل instance جاهزة جزئيًا.
- [ ] cancel يغلق العميل وينهي الجلسة دون كتابة secret.

### Gate C — Instance-scoped refresh and recovery

- [ ] إضافة resolver/exchanger يعمل على `SecretRecord` الخاصة بالـinstance الفعلية.
- [ ] تنفيذ refresh قبل expiry margin ومنع exchanges متزامنة مكررة لنفس instance.
- [ ] حفظ Copilot token الجديد مع بقاء GitHub user token مادة إعادة التبادل.
- [ ] زيادة credential revision وإبطال adapter cache بعد نجاح refresh.
- [ ] عند `401` تنفيذ exchange واحدًا وإعادة الطلب مرة واحدة فقط.
- [ ] تحويل فشل GitHub token النهائي إلى `relogin_required` typed.

#### Gate C Exit

- [ ] لا يرسل runtime Copilot token منتهيًا إذا كان GitHub token صالحًا للتبادل.
- [ ] refresh لحساب لا يغير secret أو adapter لحساب آخر.
- [ ] لا توجد retry loop غير محدودة عند `401` أو فشل الشبكة.

### Gate D — Request policy and model routing

- [ ] إضافة سياسة هيدرز Copilot مشتركة لمساري Chat Completions وResponses.
- [ ] توليد `x-initiator` من turn state الفعلية وإضافة vision header عند الحاجة فقط.
- [ ] اختيار adapter حسب model capability ضمن RouteSignature أو policy مكافئة.
- [ ] التحقق من streaming، tool calls/results، reasoning، usage، وfinish reasons.
- [ ] تطبيق account endpoint المكتشف على instance المعنية مع fallback آمن.
- [ ] منع replay لprovider state غير المتوافق بين Chat Completions وResponses.

#### Gate D Exit

- [ ] موديل Chat Completions مثبت ينفذ turn وأداة ثم final answer بصورة صحيحة.
- [ ] موديل Responses مثبت ينفذ turn مكافئة دون كسر session continuation.
- [ ] هيدرز user/agent/vision واختيار endpoint مثبتة بطلبات HTTP مسجلة في الاختبار.

### Gate E — Setup, catalog, and protocol integration

- [ ] عرض Copilot في provider setup للـCLI والعميل من registry دون special-case UI غير لازم.
- [ ] جلب model options بالمصادقة الصحيحة وتصفية الموديلات غير النصية أو غير المدعومة.
- [ ] إكمال اختيار الموديل والتحقق من endpoint قبل ترقية instance إلى ready.
- [ ] عرض حالات missing subscription، policy-disabled، token expired، وCLI-not-required بوضوح.
- [ ] ضمان أن protocol responses لا تعيد token أو raw upstream payload للعميل.

#### Gate E Exit

- [ ] يستطيع المستخدم إنشاء instance، إتمام Device Code، اختيار موديل، وبدء محادثة.
- [ ] reconnect وdisconnect يعملان على instance واحدة فقط.
- [ ] لا يطلب المنتج تثبيت Copilot CLI أو `gh` CLI في أي مسار.

### Gate F — Verification and documentation

- [ ] اختبارات registry وaliases وauth methods وfallback models.
- [ ] اختبارات start/poll/pending/slow-down/denied/expired/cancel للـDevice Code.
- [ ] اختبارات token exchange والexpiry margin والendpoint الافتراضي والحسابي.
- [ ] اختبارات refresh concurrency وcredential revision و`401` retry/relogin.
- [ ] اختبارات adapter headers وChat/Responses routing والبث والأدوات والرؤية.
- [ ] اختبارات multi-account isolation وdisconnect/reconnect وdaemon restart.
- [ ] اختبار تكاملي opt-in بحساب Copilot حقيقي، مع skip واضح عند غياب credential.
- [ ] تشغيل analyzer والاختبارات المركزة مع bounded output وفق عقد المشروع.
- [ ] تحديث `docs/technical/provider_protocol.md` ووثائق QA والفهارس ذات الصلة.
- [ ] تشغيل `graphify update .` بعد اكتمال تغييرات الكود والوثائق المرتبطة.

## 6. معايير القبول

- [ ] يظهر GitHub Copilot كمزود اشتراك مستقل قابل لإنشاء عدة instances منه.
- [ ] تسجيل الدخول يتم عبر Device Code داخل تجربة Sanad الحالية.
- [ ] لا يحتاج المستخدم إلى تثبيت Copilot CLI أو GitHub CLI أو runtime خارجي.
- [ ] لا يعتمد المنتج على Copilot SDK أو Client ID مملوك لتطبيق طرف ثالث.
- [ ] كل instance تحتفظ بتوكناتها وتجديدها وendpoint الخاص بها بصورة معزولة.
- [ ] يجدد Copilot API token تلقائيًا قبل الانتهاء دون مطالبة المستخدم بتسجيل متكرر.
- [ ] `401` يؤدي إلى exchange وإعادة محاولة واحدة، ثم خطأ typed قابل للتعافي.
- [ ] تعمل موديلات Chat Completions وResponses المعلنة عبر adapter الصحيح.
- [ ] تعمل streaming والأدوات ونتائجها والإلغاء دون تغيير agent loop في Sanad.
- [ ] لا تظهر tokens أو authorization headers في logs أو protocol أو UI.
- [ ] disconnect/reconnect/restart لا تؤثر في حساب Copilot آخر أو مزود آخر.
- [ ] analyzer والاختبارات المركزة والتكاملية المطلوبة ناجحة.
- [ ] وثائق التصميم والبروتوكول وQA محدثة ولا تصف CLI/ACP كمتطلب.

## 7. Definition of Done

- [ ] أغلقت Gates A–F مع تسجيل دليل التحقق لكل Gate.
- [ ] لا يوجد مسار runtime جديد يعتمد على provider-keyed legacy credentials.
- [ ] كل claim دعم لموديل أو endpoint مثبت باختبار أو fixture موثق.
- [ ] أخطاء المصادقة والاشتراك والسياسة والشبكة منفصلة وقابلة للفهم.
- [ ] التغييرات تحافظ على عزل provider instances وcredential revisions.
- [ ] وثائق `docs/` تعكس التصميم النهائي، وأقرب `AGENTS.md` لا يعدل إلا إذا تغير عقد دائم.
- [ ] Graphify محدث بعد تغييرات التنفيذ.

## 8. سيناريو النجاح

ينشئ المستخدم instance باسم `Work Copilot` ويختار Device Code. تعرض Sanad رابط
GitHub والكود، ويكمل المستخدم التفويض. تحفظ Sanad GitHub user token وتستبدله
بتوكن Copilot قصير العمر داخل SecretStore الخاصة بالـinstance، ثم تجلب الموديلات
وتسمح باختيار موديل مدعوم.

يرسل المستخدم رسالة تحتاج أداة؛ يختار runtime adapter الصحيح للموديل، ويرسل
هيدرز Copilot المناسبة، وينفذ tool loop داخل Sanad ثم يبث final answer. بعد قرب
انتهاء توكن Copilot يعاد exchange تلقائيًا دون تدخل المستخدم. بعد restart تستمر
المحادثة، بينما يبقى حساب Copilot ثانٍ معزولًا تمامًا. لم يُثبت أو يُشغّل أي CLI خارجي.

## 9. سيناريوهات الفشل الملزمة

- رفض المستخدم Device Code أو انتهاء الكود لا يكتب credential جزئية.
- حساب بلا اشتراك Copilot يعيد خطأ اشتراك واضحًا ولا يصنف كفشل شبكة عام.
- endpoint حسابي غير صالح أو غير موثوق يُرفض ويستخدم fallback أو يفشل بصورة typed.
- GitHub user token ملغى ينقل instance إلى `relogin_required` دون retry loop.
- فشل refresh لحساب لا يوقف turns العاملة على حساب آخر.
- موديل يحتاج Responses لا يرسل خطأً إلى Chat Completions.
- وصول `401` بعد إعادة exchange لا ينتج محاولة ثالثة.

## 10. خارج النطاق

- GitHub Copilot ACP.
- Copilot SDK أو Copilot CLI كـagent runtime.
- تفويض دورة الوكيل أو أدوات Sanad إلى process خارجي.
- استخدام `gh auth token` كمصدر تلقائي للهوية.
- دعم classic PAT من نوع `ghp_*`.
- إدارة أو شراء اشتراك Copilot من داخل Sanad.
- تغيير نظام usage limits العام خارج ما يلزم لعرض أخطاء Copilot الصحيحة.

## 11. الملفات والوثائق المتوقعة

- `agent/lib/engine/adapters/provider_registry.dart`
- `agent/lib/core/provider_runtime/provider_auth_session_service.dart`
- provider-instance credential exchange/refresh policy تحت `agent/lib/core/provider_runtime/`
- request/model routing policy تحت `agent/lib/engine/`
- اختبارات auth/provider runtime/adapters/interfaces المركزة
- `docs/technical/provider_protocol.md`
- وثيقة QA جديدة لتسجيل الدخول والتجديد والعزل وتوجيه الموديلات
- فهارس `docs/technical/MOC.md`, `docs/qa_maintenance/MOC.md`, و`docs/llms.txt` عند إضافة صفحات جديدة

## 12. أوامر التحقق المتوقعة

```bash
cd agent
set -o pipefail; fvm dart analyze 2>&1 | tail -5
set -o pipefail; fvm dart test test/core/provider_runtime 2>&1 | tail -5
set -o pipefail; fvm dart test test/engine 2>&1 | tail -5
```

يستخدم `--concurrency=1` فقط للاختبارات التي تربط ports أو تشارك runtime resource؛
أما unit tests البحتة فتعمل بالتوازي وفق العقد العام.

## 13. سجل التقدم

```text
Date:
Gate/status:
Files changed:
Verification:
Findings:
Next gate:
```
