---
title: "Task 54h: Background Task Integration and Regression QA"
description: "إثبات auto-handoff وPTY والتفاعل والإيقاظ وcrash cleanup والواجهات كنظام واحد عبر المنصات دون توسيع السياسة."
status: "pending"
current_gate: "Waiting for 54a-54g"
priority: "high"
depends_on: "54a, 54b, 54c, 54d, 54e, 54f, 54g"
file_budget: 12
reference_grounding: "required"
evidence_id: "54h"
design_contract: "docs/technical/background_terminal_task_runtime.md"
---

# Task 54h: Background Task Integration and Regression QA

## 1. الهدف

إغلاق الميزة بأدلة system-level تغطي العملية والجلسة والبروتوكول والعميل
والتعافي والأمن، مع إعادة أي finding إلى المهمة المالكة بدل إضافة سياسة في QA.

## Gate R0 — External Reference Grounding

- [ ] حل `evidence_id` عبر workflow التأصيل الخارجي والتحقق من freshness.
- [ ] قراءة implementations والاختبارات الإلزامية ومراجعة سجلات التأصيل
      السابقة في مصفوفة `Adopt / Adapt / Reject` محايدة المصدر.
- [ ] تحويل القرارات المقبولة إلى مصفوفة تحقق تكاملية صريحة.
- [ ] عند غياب الحزمة أو قدمها، تشغيل authoring/refresh ومراجعة السجلات السابقة.
- [ ] عدم بدء H0 قبل `ready`؛ لا تسجل `blocked` إلا لمانع غير قابل للتعافي.

### R0 Exit

- [ ] سجل التأصيل يحمل fingerprint والرموز والاختبارات المتحققة والقرارات.
- [ ] لا يحتوي أي ملف متتبع هوية المصدر الخارجي أو مساره؛ يبقى العقد سلوكيًا.

## 2. Gate H0 — Readiness audit

- [ ] Plan 50 و54a–54g مكتملة ولا Gate مفتوحة.
- [ ] state/schema/tool/protocol/UI vocabularies متطابقة.
- [ ] إعدادات thresholds/retention/grace مركزية وموثقة.
- [ ] تحديد E2E التي تربط منافذ وتشغيلها sequential فقط عند الحاجة.

### H0 Exit

- [ ] matrix ثابتة ولا تحتاج قرار تصميم جديدًا.

## 3. Gate H1 — Process and handoff matrix

- [ ] foreground completion قبل الحد وhandoff عند default و`0`.
- [ ] exit مقابل timer وtimeout مقابل cancel بعد handoff.
- [ ] parent/child/grandchild،interactive prompt،TERM-resistant child.
- [ ] DSR،cursor key modes،bracketed paste،submit،EOF،وresize عبر PTY حقيقية.
- [ ] silent task تعرض notice دون kill، ومهلة no-output الصريحة تنهيها بسبب typed.
- [ ] session/device capacity وdaemon draining ترفضان spawn بلا hidden queue.
- [ ] Stop session لا تلغي task؛ cancel_task/UI Stop تلغيها.
- [ ] claim/release failure لا يترك ownership gap.

### H1 Exit

- [ ] terminal once ولا orphan في كل السيناريوهات.

## 4. Gate H2 — Wake and protocol matrix

- [ ] completion/timer أثناء idle/busy/user-message race.
- [ ] typed pending steer لا queue ولا run موازية.
- [ ] cursor replay/live race،disconnect،slow client،وretention truncation.
- [ ] duplicate/reordered events وsnapshot hydration.
- [ ] secure stdin sentinel غائبة من DB/logs/events/history/model context.

### H2 Exit

- [ ] wake exactly-once دلاليًا والبث بلا فقد/تكرار.

## 5. Gate H3 — Lifecycle and UI matrix

- [ ] navigation/client restart مع daemon حية.
- [ ] graceful daemon shutdown وforced crash/watchdog/startup interruption.
- [ ] spawn يتزامن مع drain: إما claim كاملة قبل barrier أو `daemon_draining`،
      ولا task نصف منشأة.
- [ ] session panel وActivity Monitor/count متطابقة.
- [ ] حذف session success وcleanup failure وmulti-client race.
- [ ] multi-session/device ownership isolation.

### H3 Exit

- [ ] لا spinner دائم ولا stale count ولا ownerless process.

## 6. Gate H4 — Final regression and handoff

- [ ] `fvm dart analyze` و`fvm flutter analyze` ناجحان.
- [ ] focused unit/widget suites والجناح السريع المناسب ناجحة.
- [ ] E2E الفعلية ناجحة على macOS، مع Windows coverage أو حاجز منصة موثق.
- [ ] تحديث AGENTS والtechnical/product/QA MOCs والخطة الأم.
- [ ] مراجعة file budgets وdirty worktree وعدم commit/push دون طلب المستخدم.

### H4 Exit / Definition of Done

- [ ] جميع معايير Plan 54 الكلية مثبتة بأدلة قابلة للتكرار.
- [ ] لا process تستمر بعد daemon owner loss في v1.
- [ ] الخطة جاهزة لمراجعة المستخدم.
- [ ] Reference parity audit يثبت أن التنفيذ والاختبارات يحققان كل قرار
      `Adopt/Adapt` مسجل في 54a–54h، أو يعيد deviation إلى المهمة المالكة.

## 7. الملفات المتوقعة

- agent E2E fixtures/tests (3–4 ملفات)
- client integration/widget tests (2–3 ملفات)
- watchdog/platform test helper (1 ملف)
- `docs/qa_maintenance/plan54_background_tasks_matrix.md`
- `docs/qa_maintenance/MOC.md`
- `docs/technical/MOC.md`
- `docs/product/MOC.md`
- ملف المهمة والخطة الأم

## 8. سيناريو النجاح النهائي

يشغل الوكيل installer تفاعليًا؛ بعد 30 ثانية يعود task ID والجلسة idle. يرى
المستخدم output من اللوحتين ويرسل secret بأمان. ينتهي الأمر أثناء run أخرى،
فيدخل typed pending steer ثم يستأنف الوكيل عند safe boundary. في تشغيل ثان
يقتل daemon قسريًا، فينهي watchdog الشجرة وتعود task interrupted دون PID adoption.

## 9. سجل التقدم

```text
Date:
Gate/status:
Files changed:
Verification:
Findings:
Next gate:
```
