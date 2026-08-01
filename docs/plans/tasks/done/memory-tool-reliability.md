---
title: "Task: Memory Tool Reliability and Bounded Results"
description: "جعل تعديلات USER.md وMEMORY.md ذرية وقابلة للتصحيح، مع batch محدود ونتائج نجاح مختصرة لا تعيد الذاكرة كاملة."
status: "completed"
current_gate: "completed"
priority: "high"
depends_on: "File-backed memory and frozen session snapshot contract"
file_budget: 17
reference_grounding: "required"
evidence_id: "memory-file-reliability-v1"
design_contract: "docs/technical/agent_runtime.md"
---

# Task: Memory Tool Reliability and Bounded Results

## 1. الهدف

جعل أداة `memory` قابلة للاستخدام من أول استدعاء أو من محاولة تصحيح واحدة، ومنعها من إعادة محتوى الذاكرة كاملًا بعد نجاح الكتابة، مع حماية `USER.md` و`MEMORY.md` من الكتابة الجزئية أو فقد المحتوى المعدل يدويًا.

## Gate R0 — External Reference Grounding

- [x] حل `evidence_id` والتحقق من أن الحزمة `ready`.
- [x] قراءة implementations والاختبارات الإلزامية وتسجيل مصفوفة `Adopt / Adapt / Reject` محلية.
- [x] تحويل القرارات المقبولة إلى invariants واختبارات لهذه المهمة.
- [x] تثبيت fingerprint للحزمة في سجل التأصيل المحلي.

### R0 Exit

- [x] سجل التأصيل يحدد الملفات والرموز والاختبارات التي تمت مراجعتها.
- [x] لا يحتوي هذا الملف المتتبع هوية المصدر الخارجي أو مساراته.

## 2. بوابة الدخول A0 — تثبيت عقد الأداة والتخزين

- [x] تثبيت شكل نجاح مختصر يحمل `success`, `done`, `target`, `usage`, `entry_count`, ورسالة قصيرة فقط.
- [x] منع نجاح mutations من إعادة entries كاملة أو absolute host path.
- [x] تثبيت أخطاء قابلة للتصحيح لغياب `old_text` وعدم التطابق والتطابق المتعدد والامتلاء.
- [x] تثبيت `operations` كـbatch على target واحد، all-or-nothing، مع فحص الحد على الحالة النهائية.
- [x] تحديد retry budget لكل turn ومصدر reset دون إدخال durable cache جديد.
- [x] تثبيت atomic write وexternal-drift refusal وbackup/remediation.
- [x] الحفاظ على frozen snapshot وعلى تنسيق `§` والملفين الحاليين.

### A0 Exit

- [x] العقد لا يعتمد على provider-specific schema combinators.
- [x] `read` صريح ومحدود، بينما mutation success مختصر ونهائي.
- [x] فشل الذاكرة لا يستطيع حبس tool loop أو منع إجابة المستخدم.

## 3. Gate A1 — Atomic storage وdrift safety

- [x] استبدال direct truncate/write بملف مؤقت في المجلد نفسه ثم flush وatomic replace.
- [x] تنظيف temp artifacts عند الفشل وإرجاع typed tool failure دون الادعاء بالنجاح.
- [x] إبقاء lock + reload-under-lock لكل target.
- [x] كشف الملفات التي لا تعود byte-equivalent بعد parse/render قبل replace/remove/batch.
- [x] رفض destructive rewrite عند drift مع إبقاء المصدر كما هو وإنشاء backup قابل للاستعادة عند الإمكان.
- [x] تطبيق السلوك نفسه على `USER.md` و`MEMORY.md`.

### A1 Exit

- [x] القارئ يرى النسخة القديمة الكاملة أو الجديدة الكاملة فقط.
- [x] فشل الكتابة لا يزيل النسخة السابقة ولا يترك temp file.
- [x] التعديل اليدوي غير المتوافق لا يُفقد بصمت.

## 4. Gate A2 — Tool recovery وbounded results

- [x] إضافة batch schema وتنفيذ atomic final-budget operations.
- [x] جعل exact duplicate add نجاحًا idempotent مختصرًا.
- [x] إرجاع current entries أو bounded previews فقط عند الحاجة للتصحيح.
- [x] إزالة absolute path من model-facing responses العادية.
- [x] جعل mutation success terminal دون echo للذاكرة.
- [x] إضافة bounded consecutive-failure counter scoped إلى session turn، مع reset بعد النجاح وبداية turn جديدة.
- [x] تحسين guidance لتفضيل durable declarative facts وتصحيحات المستخدم، ورفض progress والتعليمات الإجرائية المؤقتة.

### A2 Exit

- [x] الذاكرة الممتلئة تُدمج وتُحدّث في batch واحد.
- [x] call ناقصة تستطيع التصحيح من استجابة واحدة محدودة.
- [x] المحاولات المتكررة تنتهي بنتيجة `done` وتسمح بإكمال جواب المستخدم.

## 5. Gate A3 — Content safety

- [x] نقل فحص المحتوى إلى boundary مشتركة مملوكة لسند بدل قائمة substrings داخل store.
- [x] فحص الكتابة الجديدة وstartup snapshot بالمصدر نفسه.
- [x] إبقاء المحتوى المحظور على القرص قابلًا للفحص والحذف مع منعه من دخول prompt snapshot.
- [x] تغطية injection وexfiltration وsecret-like material وhidden Unicode.
- [x] إضافة false-positive regressions لعبارات المستخدم والتفضيلات الطبيعية.

### A3 Exit

- [x] نتائج الفحص تحمل finding ids ثابتة وقابلة للاختبار.
- [x] لا تمنع العبارات الطبيعية بسبب pattern واسع غير مضبوط.

## 6. Gate A4 — التحقق والتوثيق

- [x] اختبارات store: atomic commit، cleanup failure، concurrent writers/readers، reload، وكلا targetين.
- [x] اختبارات drift: source preservation، backup/remediation، وفشل backup.
- [x] اختبارات tool: compact success، missing/no/ambiguous match، batch atomicity، final capacity، retry cap/reset، وpath redaction.
- [x] اختبارات schema وsecurity positive/negative corpus.
- [x] daemon-backed coverage بمزود E2E الحتمي للاستمرار بعد restart وfrozen snapshot.
- [x] تحديث `docs/technical/agent_runtime.md` ووثيقة QA وfeature guidance.
- [x] تشغيل analyzer والاختبارات المركزة و`graphify update .` ومراجعة file budget.

### A4 Exit / Definition of Done

- [x] mutation صحيحة تنجح باستدعاء واحد وتعيد نتيجة مختصرة نهائية.
- [x] invalid call قابلة للتعافي تعطي context محدودًا يكفي لمحاولة مصححة واحدة.
- [x] batch لا يكتب شيئًا عند فشل أي operation.
- [x] repeated failures لا تحبس الجولة.
- [x] readers لا يرون ملفًا جزئيًا، وفشل الكتابة يحافظ على النسخة السابقة.
- [x] destructive operations لا تفقد manual/concurrent edits بصمت.
- [x] frozen session snapshot لا تتغير بسبب mid-session writes.
- [x] Reference parity audit يثبت تحقيق كل قرار Adopt/Adapt أو يسجل deviation قبل الإغلاق.

## 7. خارج النطاق

- external أو semantic memory providers.
- vector search أو automatic fact extraction.
- silent compaction أو eviction أو حذف تلقائي.
- client approval/review UI وبروتوكول permissions جديد.
- mid-session prompt refresh.

## 8. الملفات المتوقعة

- `agent/lib/evolution/memory/file_memory_store.dart`
- scanner مشترك تحت owner مناسب في `agent/lib/`
- `agent/lib/capabilities/tools/memory_tool.dart`
- `agent/lib/engine/agent_runner.dart` عند الحاجة إلى turn reset فقط
- عقود `AGENTS.md` الأقرب عند تغير invariant دائم
- اختبارات evolution/capabilities/engine المركزة
- `agent/e2e_test/local_memory_tool_e2e_test.dart`
- `docs/technical/agent_runtime.md`
- `docs/qa_maintenance/memory_tool_reliability.md`
- `docs/product/features.md`

## 9. سيناريو نجاح

تكون `USER.md` قريبة من الحد وتحتوي مدخلتين قديمتين. يرسل النموذج batch واحدة تزيل القديمة وتضيف preference جديدة. تُطبق العمليات كلها بكتابة ذرية واحدة وتعود نتيجة مختصرة بلا entries أو path. إذا كان الملف معدّلًا يدويًا بتنسيق غير قابل للحفظ، تُرفض العملية ويبقى الملف كما هو مع recovery backup. وإذا كرر النموذج calls غير قابلة للتطبيق، تتوقف الصيانة bounded ويكمل جواب المستخدم.

## 10. سجل التقدم

```text
Date: 2026-07-29
Gate/status: A4 completed
Files changed: 17
Verification: analyzer clean; focused memory/tool/runner tests pass; deterministic daemon-backed restart E2E passes; full fast suite passes with inherited gateway overrides removed; docs lint passes.
Findings: Normal mutation results are compact and terminal; atomic batches, drift refusal, durable replacement, bounded retries, and shared content scanning are implemented.
Next gate: Review and PR delivery.
```
