---
title: "Task 54e: Background Task Protocol, Replay, and Secure Input"
description: "تثبيت canonical commands/events/snapshots لمهام الخلفية مع cursor replay وsecure stdin وعزل الأجهزة والجلسات."
status: "pending"
current_gate: "Waiting for 54b, 54c, and 54d"
priority: "high"
depends_on: "54a, 54b, 54c, 54d"
file_budget: 14
reference_grounding: "required"
evidence_id: "54e"
design_contract: "docs/technical/background_terminal_task_runtime.md"
---

# Task 54e: Background Task Protocol, Replay, and Secure Input

## 1. الهدف

توفير wire contract واحدة يستخدمها Flutter للhydration والبث والتحكم، مع
output cursor تمنع الفقد/التكرار ومسار stdin حساسة لا يصل إلى النموذج أو السجل.

## Gate R0 — External Reference Grounding

- [ ] حل `evidence_id` عبر workflow التأصيل الخارجي والتحقق من freshness.
- [ ] قراءة implementations والاختبارات الإلزامية وتسجيل مصفوفة
      `Adopt / Adapt / Reject` محلية ومحايدة المصدر.
- [ ] تحويل القرارات المقبولة إلى invariants واختبارات صريحة لهذه المهمة.
- [ ] عند غياب الحزمة أو قدمها، تشغيل authoring/refresh حتى تصبح `ready`.
- [ ] عدم بدء E0 قبل `ready`؛ لا تسجل `blocked` إلا لمانع غير قابل للتعافي.

### R0 Exit

- [ ] سجل التأصيل يحمل fingerprint والرموز والاختبارات المتحققة والقرارات.
- [ ] لا يحتوي أي ملف متتبع هوية المصدر الخارجي أو مساره؛ يبقى العقد سلوكيًا.

## 2. Gate E0 — Canonical schema

- [ ] task snapshot تشمل IDs/status/revision/cursors/timestamps المنقحة.
- [ ] events: added, changed, output, removed/retention، وcount changed.
- [ ] commands: list/get/subscribe/unsubscribe/write/cancel/cancel-all-before-delete.
- [ ] write command تحمل mode typed (`text|keys|paste|submit|eof`) وPTY
      capability snapshot؛ لا يخمن client escape sequences غير المدعومة.
- [ ] wire semantics تثبت أن submit ترسل data ثم Enter في write واحدة، وأن eof
      لا تقبل data وتغلق stdin idempotently.
- [ ] request correlation وidempotency outcomes لكل mutation.
- [ ] session/device ownership validation قبل أي payload أو input.

### E0 Exit

- [ ] live events وquery hydration تستخدمان schema دلالية واحدة.

## 3. Gate E1 — Replay then live activation

- [ ] subscribe يحمل cursor أو `-1` للtail.
- [ ] daemon يعيد retained range وabsolute cursor وtruncation metadata.
- [ ] chunks الحية تُحجز حتى يؤكد activation بعد replay.
- [ ] reconnect/duplicate packets تدمج بالtask ID + revision + cursor.
- [ ] backpressure وchunk caps تمنع client بطيئة من استهلاك الذاكرة بلا حد.

### E1 Exit

- [ ] reconnect أثناء output كثيفة لا يفقد ولا يكرر bytes.

## 4. Gate E2 — Secure and normal stdin

- [ ] normal input من UI يمكن عرضه محليًا حسب PTY echo ولا يدخل chat history.
- [ ] keys/paste/submit/eof تمر عبر encoder مالك للPTY وcursor key mode الحالية.
- [ ] secure input flag يمر client→daemon→PTY دون persistence/log/event echo.
- [ ] payload الحساسة لا تدخل analytics،request dumps،errors،أو model tools.
- [ ] agent `write_task` لا يقرأ secure input ولا يسترجعها لاحقًا.
- [ ] permission/ownership errors لا تعيد النص في error message.

### E2 Exit

- [ ] اختبار sentinel secret لا يجدها في DB/logs/events/model history.

## 5. Gate E3 — Verification and docs

- [ ] snapshot/live parity وrevision ordering وcursor truncation.
- [ ] cross-session/device denial وrepeated cancel/write.
- [ ] reconnect قبل/بعد activation وslow consumer.
- [ ] DSR request/response وnormal/application cursor modes وbracketed paste.
- [ ] تحديث communication/database/security QA.

### E3 Exit / Definition of Done

- [ ] البروتوكول authoritative وآمن ويمكن للواجهتين 54f/54g استهلاكه بلا تخمين.
- [ ] لا WebSocket PTY ثانية في v1.
- [ ] Reference parity audit يثبت أن التنفيذ والاختبارات يحققان كل قرار
      `Adopt/Adapt` مسجل، أو يعيد أي deviation إلى تصميم المهمة.
- [ ] المهمة داخل file budget.

## 6. الملفات المتوقعة

- canonical protocol/events/handlers تحت `agent/lib/interfaces/` (4–5 ملفات)
- gateway command routing/subscription owner (1–2 ملف)
- اختبارات protocol/handler/replay/security (3 ملفات)
- أقرب `AGENTS.md`
- `docs/technical/communication_protocols.md`
- `docs/technical/agent_database_schema.md`
- `docs/qa_maintenance/plan54_background_tasks_matrix.md`
- ملف المهمة والخطة الأم

## 7. سيناريو النجاح

يشترك client من cursor 100، وينتج الأمر bytes جديدة أثناء replay. يستلم التاريخ
حتى cursor N ثم pending live bytes مرة واحدة. يرسل المستخدم secret sentinel في
secure mode؛ تصل للPTY ولا توجد في DB أو logs أو events أو history.

## 8. سجل التقدم

```text
Date:
Gate/status:
Files changed:
Verification:
Findings:
Next gate:
```
