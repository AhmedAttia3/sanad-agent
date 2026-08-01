---
title: "Task 53e: /compact Command and Compaction Timeline UX"
description: "إزالة أوامر القدرات الوهمية، فصل slash commands عن skills في composer، وتنفيذ /compact مع timeline centered وتفاصيل live/history متطابقة."
status: "pending"
current_gate: "E0"
priority: "high"
depends_on: "Task 53d canonical command and lifecycle contract"
file_budget: 15
---

# Task 53e: أمر `/compact` وتجربة timeline الخاصة بالضغط

## 1. الهدف

تحويل slash commands من suggestions نصية مختلطة بالskills إلى runtime command vocabulary حقيقية، وتقديم `/compact` كأول أمر exact مع واجهة started/completed/failed centered قابلة للاستعادة.

## 2. Gate E0 — فصل catalogs وcomposer grammar

- [ ] إزالة `_defaultSlashCommands` الوهمية الحالية (`model`, `think`, `workspace`, `mcp`, `sessions`, `stop`) من device capability discovery.
- [ ] عدم إعادة تسمية skills إلى slash commands؛ runtime commands وskills catalogان مستقلان في agent protocol وclient domain.
- [ ] إضافة `/compact` وحدها إلى runtime slash-command catalog في الإصدار الأول.
- [ ] تعريف parser/query rules منفصلة:
  - slash query تبدأ عند composer index صفر فقط.
  - skill query/token صالحة في أي موضع كما هي حاليًا.
  - البنية تسمح بإضافة file mentions مستقبلًا كtoken family ثالثة دون تغيير command grammar.
- [ ] إنشاء domain type مستقل لـruntime command بدل `SlashCommandType.skill` أو source string مبهمة.
- [ ] إبقاء insert/render metadata للskills مستقلة وعدم كسر skill selection الحالية.

### E0 Exit

- [ ] كتابة `/` داخل منتصف الرسالة لا تعرض runtime commands.
- [ ] skill trigger في البداية أو المنتصف أو النهاية يستمر في الظهور والإدراج كtoken.
- [ ] device capabilities لا تعلن command لا يملك handler فعليًا.

## 3. Gate E1 — Enter dispatch وvalidation

- [ ] exact `/compact` token مع عدم وجود user text إضافي ينفذ canonical `compact` command ولا يرسل `think`/message command.
- [ ] arguments أو trailing non-whitespace text تعيد validation محلية واضحة وتبقي draft دون إرسالها كرسالة.
- [ ] Escape/backspace/selection تتعامل مع command token كوحدة قابلة للإزالة دون تلويث plain-text export.
- [ ] إذا session busy، يعرض typed busy feedback وتبقى draft/command قابلة للمحاولة لاحقًا.
- [ ] إذا compaction started، يزال command draft فقط بعد canonical acceptance، لا بمجرد ضغط Enter.
- [ ] command ثانية أثناء compaction تعرض in-progress outcome ولا تنشئ operation إضافية.
- [ ] الرسائل العادية تبقى قابلة للإرسال أثناء compaction وتدخل queue وفق 53d.

### E1 Exit

- [ ] repository/transport يسجل command واحدة ولا يسجل user message باسم `/compact`.
- [ ] failure قبل acceptance لا يمسح composer draft.
- [ ] skill tokens في رسالة عادية تصدر كما كانت قبل المهمة.

## 4. Gate E2 — domain mapping وlive/history state

- [ ] إضافة typed `CompactionEvent`/projection في client domain keyed بالdevice/session/compaction id.
- [ ] mapping موحد لحالات started/completed/failed وmanual/auto/overflow والmetrics الاختيارية.
- [ ] تطبيق lifecycle idempotently ورفض event أقدم أو terminal regression.
- [ ] حفظ/hydrate events ضمن conversation cache/history دون خلطها برسائل assistant أو user.
- [ ] navigation بين الجلسات لا يعرض operation من Session A في Session B.
- [ ] reconnect أثناء started ثم completed يعيد نفس tile ولا ينشئ نسختين.
- [ ] queued-message UI تبقى authoritative أثناء compaction ولا تدعي أن الرسالة بدأت التنفيذ.

### E2 Exit

- [ ] live timeline وبعد reload متطابقتان في status وtrigger والmetrics.
- [ ] event لا تؤثر على title generation أو last-user-message ordering أو assistant metadata.

## 5. Gate E3 — Centered compaction timeline tile

- [ ] إنشاء presentation واحدة تعرض centered horizontal separator:
  - divider يسار ويمين.
  - circular indicator عند started.
  - success check عند completed.
  - error indicator terminal عند failed.
- [ ] اعتماد النصوص:
  - `Context compacting`
  - `Auto context compacting`
  - `Context compacted`
  - `Auto context compacted`
  - `Context compaction failed`
  - `Auto context compaction failed`
- [ ] overflow trigger تظهر بصريًا كauto مع تفصيل `Trigger: Context overflow` داخل التفاصيل، دون إضافة label مربكة ثالثة في timeline.
- [ ] layout تعمل على desktop/tablet/mobile ولا تتسبب في horizontal overflow أو touch target صغير.
- [ ] started animation تتوقف فور terminal event أو dispose/navigation.
- [ ] accessibility semantics تعلن status وmanual/auto ولا تعتمد على اللون أو الأيقونة وحدهما.

### E3 Exit

- [ ] started/completed/failed snapshots مطابقة للتصميم centered.
- [ ] لا يظهر raw summary أو transcript أو provider body في tile.

## 6. Gate E4 — Multi-line details interaction

- [ ] إعادة استخدام interaction pattern في `context_usage_indicator.dart`: hover على desktop، click/tap على touch، keyboard focus، وdismiss semantics.
- [ ] استخراج surface/helper مشترك فقط إذا حافظ على ownership ولم يجعل compaction تعتمد على conversation-input widget.
- [ ] عرض الحقول المتوفرة فقط:
  - Type: Manual أو Auto.
  - Trigger، status، provider، model.
  - Context window.
  - Before/after request tokens ونسبة الامتلاء.
  - Reclaimed tokens/ratio.
  - Summarized range وretained-tail tokens.
  - Started/completed time وduration.
  - redacted failure reason عند الفشل.
- [ ] عدم إظهار صفوف `N/A` غير المفيدة أو استنتاج قيم لم يرسلها agent.
- [ ] عدم إظهار internal summary لأي سبب.
- [ ] tooltip/popover تبقى متعددة الأسطر وقابلة للقراءة على الشاشات الضيقة.

### E4 Exit

- [ ] hover وtap/focus يعرضان التفاصيل نفسها.
- [ ] missing metrics لا تكسر العرض أو تنتج أرقامًا وهمية.
- [ ] semantics تصف إمكانية فتح التفاصيل وحالة العملية.

## 7. Gate E5 — التحقق والتوثيق

- [ ] اختبارات parser: index صفر، mid-message slash، exact command، arguments، backspace، وskill coexistence.
- [ ] اختبارات dispatch: acceptance، busy، duplicate، failure، وعدم إنشاء user message.
- [ ] اختبارات mapper/cache: out-of-order، reconnect، hydration، session isolation.
- [ ] widget tests للحالات الست، centered layout، hover/tap/focus، mobile width، وaccessibility.
- [ ] regression tests لاختيار skills في أي موضع وإرسال الرسائل العادية أثناء compaction.
- [ ] تحديث client feature contract ووثائق product/protocol/cache/QA.
- [ ] مراجعة file budget قبل الإغلاق.

### E5 Exit / Definition of Done

- [ ] لا توجد slash commands وهمية في capabilities أو suggestions.
- [ ] `/compact` command حقيقية exact في بداية composer فقط.
- [ ] skills لا تزال tokens في أي موضع ولا تشترك مع command dispatch.
- [ ] manual/auto lifecycle تظهر centered ومتطابقة live/history.
- [ ] التفاصيل تعمل بالhover وtap/focus دون كشف summary.

## 8. الملفات المتوقعة

- `agent/lib/interfaces/runtime/local_workspace_runtime_service.dart`
- command/catalog/protocol handlers ذات الصلة
- `client/lib/features/conversations/domain/models/slash_command_entry.dart` أو استبداله بنماذج منفصلة
- `composer_slash_commands_cubit.dart` وstate/controller parser
- conversation repository/transport command mapping
- client compaction domain/cache/event mapper
- timeline event tile/widget جديد
- `client/lib/features/conversations/presentation/widgets/conversation_input/context_usage_indicator.dart`
- shared details interaction المستخرج عند الحاجة
- اختبارات agent/client مركزة
- `agent/lib/interfaces/AGENTS.md`
- `client/lib/features/AGENTS.md`
- `docs/product/client_interface.md`
- `docs/technical/communication_protocols.md`
- `docs/technical/client_conversation_cache_schema.md`
- `docs/qa_maintenance/context_compaction_qa.md`
- ملف المهمة والخطة الأم

## 9. سيناريو النجاح

يكتب المستخدم `/compact` في بداية composer ويضغط Enter في جلسة idle. لا تظهر user message، بل centered `Context compacting` مع spinner. يرسل المستخدم رسالة عادية أثناء العملية فتظهر queued. عند النجاح تتحول tile نفسها إلى `Context compacted` مع check mark، ويعرض hover/tap metrics متعددة الأسطر، ثم تبدأ الرسالة queued. بعد reload تظهر tile والرسالة والحالة نفسها. في auto trigger يظهر `Auto context compacting/compacted` دون تدخل المستخدم.

## 10. خارج النطاق

- arguments أو focus أو preview لأمر `/compact`.
- تنفيذ أوامر `model`, `think`, `workspace`, `mcp`, `sessions`, أو `stop` كslash commands.
- file mentions نفسها.
- عرض summary أو السماح بتحريرها.

## 11. سجل التقدم

```text
Date:
Gate/status:
Files changed:
Verification:
Findings:
Next gate:
```
