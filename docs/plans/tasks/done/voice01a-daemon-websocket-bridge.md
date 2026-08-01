---
title: "بناء واجهة وخدمة مزودي الصوت المباشر في الديمون (Realtime Provider Abstraction & Plugins)"
description: "تصميم وتنفيذ بنية قنوات نقل الصوت، تجريد موفري الخدمة الصوتية (RealtimeVoiceProvider)، وتطبيق إضافة Gemini Live الأولى في sanadagent-local."
---

# بناء واجهة وخدمة مزودي الصوت المباشر في الديمون (Realtime Provider Abstraction & Plugins)

<div dir="rtl" style="text-align: right; direction: rtl;">

* **معرف المهمة (Task ID):** `voice01a`
* **المكونات المتأثرة (Component Tags):** `sanadagent-local`
* **الحالة (Status):** 📝 تمت صياغة البدء
* **الوقت المتوقع (Estimated Effort):** 10 ساعات (10 Hours)

---

## الوضع الحالي (Current State)
* لا يوجد حالياً دعم لنقل البث الصوتي المباشر (Audio Streaming) في الديمون المحلي `sanadagent-local`.
* البنية التحتية القديمة كانت تعتمد على LiveKit وسيرفر خارجي مخصص لتشغيل الصوت، وهو ما تمت إزالته لتبسيط المتطلبات وجعل التطبيق محلياً بالكامل.

---

## الوضع المستهدف / الهدف (Target State)

### 1. قنوات الاتصال والتحويل الصوتي (Transport Channels)
* **بناء واجهة تجريد `VoiceTransportChannel`** لاستقبال وإرسال الصوت بشكل موحد بغض النظر عن طريقة الاتصال (محلياً أو سحابياً):
  * **`LocalWebSocketTransportChannel`**: يدير اتصالات المقبس المحلي المباشر (`ws://localhost:4500/api/v1/voice/stream`).
  * **`CloudSocketIoTransportChannel`**: يدير الاتصال القادم عبر خادم Socket.IO السحابي (FastAPI Backend).

### 2. واجهة تجريد مزودي الخدمة (RealtimeVoiceProvider Abstraction)
* **تصميم واجهة `RealtimeVoiceProvider`** لتمكين إضافة أي مزود صوتي مباشر في المستقبل (مثل OpenAI Realtime أو محرك محلي):
  ```dart
  abstract class RealtimeVoiceProvider {
    Future<void> connect(Map<String, dynamic> sessionConfig);
    Future<void> close();
    void handleInputAudio(List<int> pcmChunk16kHz);
    void handleControlEvent(String eventName, Map<String, dynamic> payload);
    Stream<RealtimeVoiceEvent> get outputEvents;
  }
  ```

### 3. دعم وضعين للاتصال الصوتي بالديمون:
* **وضع الإملاء الصوتي (Live Dictation Mode):**
  * يستقبل دفق الصوت للمايكروفون (16kHz).
  * يوجهه إلى خدمة الترجمة الصوتية (STT).
  * يرجع الترجمة الفورية للنصوص أولاً بأول (Partial transcripts) لكي تدرجها الواجهة في حقل النص.
* **وضع المحادثة الثنائية التفاعلية (Duplex Voice Mode):**
  * موزع الأحداث المشترك يوجه الصوت والصوت المسترجع من موفر الخدمة (Gemini/OpenAI).
  * يدعم فك ترميز المخرجات الصامتة لـ 24kHz وإمرارها للواجهة.

### 4. مزامنة وحفظ الرسائل في قاعدة البيانات (Persistence):
* عند نهاية كل نوبة كلام في وضع المحادثة الصوتية:
  * يقوم الديمون بكتابة وحفظ رسالة المستخدم (الترجمة النصية) في قاعدة بيانات الجلسة النشطة (`Thread`).
  * عند اكتمال رد الوكيل الصوتي، يقوم الديمون بكتابة وحفظ رد الوكيل النصي كاملاً في نفس الـ `Thread` بقاعدة البيانات لتوحيد السجل.

---

## حالات الاختبار (Test Cases)

### اختبار الواجهات والتجريد (Abstraction & Routing):
* **حالة 1**: التحقق من تبديل موفري الخدمة وسلاسة المخرجات الصوتية بمعدل 24kHz Mono 16-bit.
* **حالة 2**: التأكد من نجاح حفظ وحقن رسائل الحوار الصوتي في قاعدة البيانات وإظهارها في تاريخ الجلسة بعد إنهاء المكالمة.

### اختبار اتصال ومقابس Gemini Live:
* **حالة 3**: محاكاة اتصال بالبث المباشر لـ Gemini والتحقق من إرسال رسالة الـ `setup` وتلقي استجابة الترحيب بنجاح.
* **حالة 4**: التحقق من إرسال حدث المقاطعة (Barge-in Cancel) بنجاح فور استلام إشارة المقاطعة من العميل.

</div>
