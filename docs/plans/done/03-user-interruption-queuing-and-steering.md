---
title: "المرحلة الثالثة: معالجة المقاطعة، جدولة الرسائل وتوجيه الوكيل (Queue & Steer)"
description: "تطبيق سلوك جدولة الرسائل الواردة (FIFO Queue) والتوجيه الحي (Steer) عندما يكون الوكيل مشغولاً بتنفيذ دورة عمل نشطة."
phase: 3
prd: "docs/product/prd_sanad_agent.md"
---
<div dir="rtl" style="direction: rtl; text-align: right;">

# خطة التنفيذ — معالجة المقاطعة، جدولة الرسائل وتوجيه الوكيل (Queue & Steer)

تهدف هذه الخطة إلى تطبيق سلوك جدولة الرسائل الواردة (FIFO Queue) والتوجيه الحي (Steer) عندما يكون الوكيل مشغولاً بتنفيذ دورة عمل نشطة، مما يمنع حدوث عمليات معالجة متوازية وتداخل البيانات. سيتم تمثيل الرسائل المجدولة في الواجهة بلوحة منفصلة عائمة فوق مدخل الكتابة، مع إمكانية توجيهها (Steer) صراحة في سياق دورة العمل الحالية.

---

## معايير القبول (Acceptance Criteria)

قبل اعتبار ميزة جدولة وتوجيه الرسائل جاهزة ومكتملة، يجب تحقيق المعايير التالية:

1. **منع المعالجة المتوازية:** عند إرسال رسالة جديدة أثناء انشغال الوكيل في نفس المحادثة، يجب ألا تبدأ دورة عمل متوازية، ويتم وضع الرسالة تلقائياً في قائمة الانتظار (Queue) افتراضياً.
2. **عرض منفصل للرسائل المعلقة:** الرسائل الموجودة في قائمة الانتظار لا تظهر في سجل المحادثة الرئيسي مباشرة. بدلاً من ذلك، تظهر في لوحة عائمة أنيقة بتصميم زجاجي (Glassmorphism) فوق حقل الإدخال.
3. **لوحة التحكم بالانتظار:** يجب أن تعرض اللوحة العائمة كافة الرسائل المجدولة للجلسة، وبجوار كل رسالة زر توجيه "Steer" مميز (بأيقونة بوصلة أو استكشاف).
4. **مفاتيح الاختصار للارسال (Keyboard Shortcuts):**
   - الضغط على `Enter` أثناء انشغال الوكيل يُدرج الرسالة تلقائياً في طابور الانتظار (`Queue`).
   - الضغط على `Cmd + Enter` (على الماك) أو `Ctrl + Enter` (على الويندوز) أثناء انشغال الوكيل يُرسل الرسالة كتوجيه مباشر وعاجل خارج النطاق (`Steer`).
5. **التوجيه اليدوي من الطابور:** عند النقر على زر "Steer" بجوار رسالة معلقة في اللوحة العائمة، يتم سحبها من الطابور وحقنها فوراً كتوجيه حي في الدورة النشطة.
6. **سلامة سياق المحادثة (Context Safety):** لا يتم حقن رسائل التوجيه في وسط معالجة الأدوات، بل يتم تخزينها مؤقتاً وحقنها فقط بعد انتهاء تنفيذ دفعة الأدوات (Tool Calls) وقبل الاستدعاء التالي للـ LLM مباشرة، مدمجة بشكل منسق داخل آخر رسالة أداة لتجنب كسر التناوب بين أدوار المستخدم والمساعد (Role Alternation).
7. **إدارة نطاق الجلسات (Session Scoping):** ترتبط قائمة الانتظار بـ `sessionId` على مستوى العميل والخادم. يتم تحميل قائمة الرسائل المعلقة وحفظها عند الانتقال بين الجلسات وتطهيرها تلقائياً للمحاورات غير النشطة.
8. **الإلغاء والتنظيف الفوري (Cancellation/Stop):** يؤدي النقر على زر "Stop" إلى إلغاء الدورة النشطة فوراً وتطهير كافة الرسائل المعلقة في قائمة الانتظار لهذه الجلسة على مستوى الواجهة والخادم على حد سواء.

---

## المكونات والتعديلات المقترحة

### ١. خادم الوكيل المحلي (`sanad-agent`)

#### [تعديل] [gateway_manager.dart](../../../agent/lib/interfaces/gateway_manager.dart)
- **إضافة حقول التتبع:**
  - `final Map<String, List<GatewayEvent>> _pendingEvents = {};` (لتخزين الأحداث المعلقة لكل جلسة).
  - `final Set<String> _busySessions = {};` (لتتبع الجلسات النشطة حالياً).
- **تحديث دالة `_handleEvent(platform, event)`:**
  - **إذا كان الحدث من نوع `stop`:**
    - تفريغ قائمة الرسائل المعلقة للجلسة: `_pendingEvents.remove(event.sessionId);`.
    - إذا كانت الجلسة مشغولة، يتم إضافة الجلسة إلى قائمة الإيقاف: `_activeStoppedSessions.add(event.sessionId);`.
    - إلغاء الاشتراك النشط في البث `runSubscription` وإرسال تأكيد الإيقاف الفوري.
  - **إذا كان الحدث من نوع `steer`:**
    - التحقق مما إذا كانت الجلسة مشغولة (`_busySessions.contains(event.sessionId)`):
      - **إذا كانت مشغولة:**
        - حذف الحدث المقابل من قائمة الانتظار إن وجد (بناءً على `request_id`).
        - استدعاء دالة التوجيه للوكيل: `agentRunner.steer(event.message.content)`.
        - إرسال صدى رسالة المستخدم فورا للواجهة (بدون حقول الانتظار) ليتم نقلها للدردشة النشطة.
      - **إذا لم تكن مشغولة:** يتم تحويلها تلقائياً لمعالجة عادية كرسالة جديدة (`think`).
  - **إذا كان الحدث رسالة عادية (`think`):**
    - التحقق مما إذا كانت الجلسة مشغولة (`_busySessions.contains(event.sessionId)`):
      - **إذا كانت مشغولة:**
        - إدراج الرسالة في الطابور: `_pendingEvents.putIfAbsent(event.sessionId, () => []).add(event);`.
        - إرسال استجابة صدى سريعة للواجهة تحتوي على البيانات الوصفية `'queued': true` و `request_id` لتعريف الرسالة كمعلقة في الواجهة.
      - **إذا لم تكن مشغولة:** قفل الجلسة `_busySessions.add(event.sessionId)` والبدء بالمعالجة.
  - **تأمين دورة التنفيذ:**
    - تغليف كود تشغيل الدورة، تحديث القياسات، وتوليد العنوان الذكي في كتلة `try-finally`:
      - في كتلة `finally`:
        - إلغاء قفل الجلسة: `_busySessions.remove(event.sessionId);`.
        - سحب الرسالة التالية من الطابور وتمريرها للدوران:
          ```dart
          final queue = _pendingEvents[event.sessionId];
          if (queue != null && queue.isNotEmpty) {
            final nextEvent = queue.removeAt(0);
            if (queue.isEmpty) {
              _pendingEvents.remove(event.sessionId);
            }
            Future.microtask(() => _handleEvent(platform, nextEvent));
          }
          ```
- **ملكية القرار والصدى:** منصتا Sanad المحلية والسحابية تطلبان صدى رسائل المستخدم من `GatewayManager`. يظل الوكيل هو الجهة الوحيدة التي تصنف رسالة `think` كرسالة عادية أو معلقة، ويحمل الصدى المعتمد `request_id` الأصلي في الحالتين.

#### [تعديل] [agent_runner.dart](../../../agent/lib/engine/agent_runner.dart)
- **إضافة حقول التوجيه المعلق:**
  - `String? _pendingSteer;` (لتخزين نصوص التوجيه المتراكمة).
- **إضافة دالة `steer(String text)`:**
  - استقبال نص التوجيه مع `request_id` ووقت الاستلام وتخزين الرسائل بالترتيب في قائمة مؤقتة.
- **إضافة دالة التصفية والحقن `_drainPreApiSteer()` و `_applyPendingSteerToToolResults(int numToolCalls)`:**
  - فور انتهاء تشغيل دفعة الأدوات (Tool Calls) وقبل بناء طلب الـ LLM الجديد:
    - البحث عن آخر رسالة من دور الأداة (`MessageRole.tool`) في تاريخ المحادثة (`history`).
    - تذييل نص التوجيه المعلق بداخلها بداخل محددات واضحة:
      ```text
      [OUT-OF-BAND USER MESSAGE — a direct message from the user, delivered mid-turn; not tool output]
      <نص التوجيه>
      [/OUT-OF-BAND USER MESSAGE]
      ```
    - تفريغ قائمة رسائل التوجيه المعلقة وحفظ التاريخ المحدث بعد تسليمها.
- **استدعاء `_drainPreApiSteer()`:** في بداية دالة `_streamNextResponse` ودالة `_getNextResponse` لضمان حقنه قبل تجميع السياق الموجه للنموذج.
- **التوجيه المتأخر:** إذا وصل `steer` أثناء الاستجابة النهائية بعد آخر حد آمن للأدوات، تُعلَّم الاستجابة السابقة بأنها مستبدلة، ثم تضاف رسالة التوجيه كمتابعة مستخدم ويستمر استدعاء النموذج داخل نفس تشغيل الجلسة. تبقى الاستجابة المستبدلة ضمن سياق النموذج ولا تُعرض عند إعادة تحميل المحادثة.
- **حفظ الترتيب:** تحتفظ رسالة الأداة ببيانات `steer_messages` المنظمة وبالناتج المرئي الأصلي، ويعيد سجل الجلسة بناء رسالة المستخدم بعد نتيجة الأداة دون إظهار علامات الحقن الداخلية.
- **إضافة تعليمات توجيه المستخدم (`STEER_CHANNEL_NOTE`)** داخل الـ stable guidance للـ Context Assembler لكي يثق النموذج في رسائل التوجيه.

#### [تعديل] [canonical_to_agent.dart](../../../agent/lib/interfaces/platforms/sanad_gateway/translators/canonical_to_agent.dart)
- دعم ترجمة أمر الكلاينت `steer` أو حقل `mode == 'steer'` ليصبح `GatewayEvent` بنوع `steer`.

#### [تعديل] [di.dart](../../../agent/lib/core/di.dart)
- تسجيل `GatewayManager` كـ Lazy Singleton لتسهيل الوصول إليه واستدعاء الرسائل المعلقة منه.

#### [تعديل] [sanad_protocol_bridge.dart](../../../agent/lib/interfaces/platforms/sanad_gateway/sanad_protocol_bridge.dart)
- تضمين الرسائل المعلقة التابعة للجلسة من `GatewayManager` داخل مصفوفة `queued_messages` عند طلب جلب تاريخ الجلسة (`_buildHistoryEnvelope`) لدعم إظهارها عند التنقل بين الجلسات.

---

### ٢. واجهة المستخدم الفلاتر (`sanad-client`)

#### [تعديل] [device_conversation_store.dart](../../../client/lib/features/conversations/domain/stores/device_conversation_store.dart)
- إضافة قائمة تتبع الرسائل المعلقة للجلسة النشطة: `final List<CanonicalEvent> _queuedMessages = [];`.
- إضافة دوال تحديث الطابور:
  - `setQueuedMessages(List<CanonicalEvent> events)`: لتحديث الطابور عند جلب تاريخ الجلسة.
  - `removeQueuedMessagesForSession(String? sessionId)`: لتطهير الطابور عند التوقف.
- لا تنشئ الواجهة رسالة مستخدم متفائلة في سجل المحادثة أو قائمة الانتظار؛ كلاهما يُحدّث فقط من صدى الوكيل المعتمد.
- تحديث دالة `apply(event)`:
  - إذا كان الحدث معلماً بـ `'queued': true` في البيانات الوصفية: يتم إضافته/تحديثه في قائمة `_queuedMessages`.
  - إذا كان حدثاً عادياً: يتم التحقق مما إذا كان يطابق رسالة معلقة بـ `request_id` وحذفها من الطابور، وتمرير الرسالة لـ `_conversation.apply` الرئيسية.

#### [تعديل] [conversation_event_handler.dart](../../../client/lib/features/conversations/data/transport/conversation_event_handler.dart)
- استدعاء `_conversationStore.removeQueuedMessagesForSession(...)` عند استلام أحداث `stopped` أو `error` لتطهير قائمة الرسائل المعلقة.

#### [تعديل] [conversation_commands.dart](../../../client/lib/features/conversations/data/transport/conversation_commands.dart)
- دعم حقل `mode` في دالة `sendMessage` للتوجيه الصريح فقط. الإرسال العادي يبقى أمر `think` بلا استنتاج محلي لحالة `queue`، ويترك التصنيف للوكيل.
- إضافة دالة `steerMessage(message, {requestId, sessionId})` لإرسال أمر توجيه مباشر للخادم.

#### [تعديل] [conversation_input_composer.dart](../../../client/lib/features/conversations/presentation/widgets/conversation_input/conversation_input_composer.dart)
- تفعيل مفاتيح الاختصار الكيبورد:
  - مفتاح `Enter` العادي: يرسل `think` عاديًا، والوكيل يجدوله تلقائيًا إذا كانت الجلسة مشغولة.
  - اختصار `Command+Enter` (أو `Control+Enter` في الويندوز): يستدعي التوجيه المباشر `onSteerAttempt`.

#### [جديد] [لوحة الرسائل المعلقة العائمة]
- بناء لوحة عائمة أنيقة بتصميم زجاجي عالي الجودة (Glassmorphism) فوق مدخل الكتابة في `ConversationInputPanel`.
- يظهر كل سطر رسالة معلقة ومجاوره زر التوجيه "Steer" (أيقونة Explore/Compass مميزة). النقر عليه ينقل الرسالة المعلقة من الطابور ويحقنها فوراً كتوجيه حي للوكيل.

---

## خطة التحقق والتدقيق

### الاختبارات المؤتمتة
- كتابة سيناريو فحص متكامل في `interfaces_test.dart` يحاكي:
  1. إرسال الرسالة الأولى وتأخير الرد محاكاة للعمل الطويل.
  2. إرسال الرسالة الثانية وتأكيد استلام صدى معلق بـ `queued: true`.
  3. التحقق من بقائها في طابور `_pendingEvents`.
  4. استدعاء أمر توجيه `steer` على الرسالة الثانية والتأكد من إزالتها من الطابور واستدعاء دالة التوجيه وحقنها بعد انتهاء الأداة مباشرة.
  5. التأكد من تطهير الطابور بنجاح عند استدعاء `stop`.

</div>
