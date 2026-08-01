---
title: "خطة تطهير بروتوكول الأجهزة وإزالة مصطلحات الوكلاء القديمة"
description: "خطة تنفيذ ومعايير قبول لتحويل بروتوكول الربط بين sanad-client وbackend وsanad-agent إلى نموذج Device-first، وإزالة agent_id وagent_type وthread_id وميراث sanadagent/openclaw."
prd: "docs/product/prd_sanad_agent.md"
---

# خطة تطهير بروتوكول الأجهزة وإزالة مصطلحات الوكلاء القديمة

هذه الخطة تكمل توجه **Sanad Agent** الموثق في [docs/product/prd_sanad_agent.md](../product/prd_sanad_agent.md). الهدف منها ليس تعديل ملفات بعينها فقط، بل تثبيت عقد تشغيلي جديد بين المشاريع الثلاثة:

- `backend`
- `sanad-client`
- `sanad-agent`، وهو الاسم المستهدف للمشروع الحالي `sanadagent-local`

القاعدة الأساسية: الكيان المتصل عبر البوابة هو **Device** فقط. أما مفهوم **Logical Agent** فسيضاف لاحقا داخل `sanad-agent` ككيان جديد ونظيف، ولا يجب أن يرث أي بقايا من مصطلحات الربط القديمة.

---

## الهدف العام

تحويل المنظومة من نموذج "أنواع وكلاء متعددة" إلى نموذج "أجهزة مسجلة تشغل `sanad-agent`"، بحيث يصبح `backend` بوابة تسجيل وتمرير Socket.IO بين `sanad-client` و`sanad-agent` دون Python workers ودون OpenClaw ودون Redis routing للأوامر العادية.

---

## الأهداف

1. توحيد مصطلح الكيان المتصل عبر المشاريع الثلاثة ليكون `device` فقط.
2. حذف مفاتيح الربط القديمة `agent_id`, `agent_type`, `device_type`, و`thread_id` من بروتوكول الاتصال بين `sanad-client`, `backend`, و`sanad-agent`.
3. تثبيت `device_id` كمعرف التوجيه الوحيد للأجهزة المسجلة.
4. تثبيت `session_id` كمعرف الجلسات الوحيد بدل أي `thread_id`.
5. جعل `online` يعني أن `sanad-agent` متصل وقابل للوصول، وليس أن `sanad-client` مفتوح.
6. جعل إنشاء سجل `device` في backend يحدث فقط عند اتصال أو تسجيل `sanad-agent`، وليس عند اتصال `sanad-client`.
7. تثبيت `hardwareId` في مصدر حقيقة مشترك بين `sanad-client` و`sanad-agent`، بحيث يقرأه المشروعان أو ينشئانه بنفس الطريقة والقيمة.
8. دعم مصادقة `sanad-agent` بطريقتين تلقائيا: user access token من `auth.json` أولا، ثم device pairing token كـ fallback.
9. إزالة Redis من مسار توجيه أوامر الأجهزة، مع إبقاء Redis الخاص بـ `tool_result lifecycle` خارج نطاق هذه الدفعة.
10. إعادة تسمية `sanadagent-local`, `SanadAgent`, و`sanadagent daemon` إلى `sanad-agent`, `Sanad Agent`, و`sanad daemon`.

---

## قرارات العقد الجديد

### الجهاز هو محور التوجيه

- كل أوامر التحكم في الجهاز تمر باستخدام `device_id`.
- لا توجد حاجة لأي `agent_type` أو `device_type` لاختيار مسار التوجيه، لأن نوع runtime المتصل واحد في هذا العقد: `sanad-agent`.
- لا يتم استخدام `type.isSanadAgent` أو أي تصنيف مشابه لتحديد الاتصال المحلي.

### حالة الاتصال مملوكة للديمون

- `online = true` تعني وجود اتصال حي من `sanad-agent`.
- اتصال `sanad-client` وحده لا ينشئ جهازا ولا يجعل الجهاز online.
- إغلاق `sanad-client` لا يجعل الجهاز offline إذا كان `sanad-agent` ما زال متصلا.

### مصدر حقيقة `hardwareId`

- يقرأ كل من `sanad-client` و`sanad-agent` نفس قيمة `hardwareId` من مصدر محلي مشترك.
- إذا لم تكن القيمة موجودة، ينشئها المشروع الذي يبدأ أولا ويحفظها في نفس المصدر.
- يستخدم `sanad-client` هذه القيمة فقط لمعرفة إن كان الجهاز المحدد هو نفس الجهاز المحلي.
- لا ينشئ `backend` سجلا في `devices` بسبب `hardwareId` قادم من `sanad-client` وحده.

### المصادقة والربط

- عند تسجيل `sanad-agent` في `backend`:
  - يحاول backend التحقق من `token` كـ user JWT access token.
  - إذا فشل، يجربه كـ device pairing token.
- عند نجاح JWT، ينشئ backend جهازا أو يعيد استخدام جهاز موجود حسب `hardware_id`.
- عند نجاح device token، يربط التوكن بالجهاز المسجل، ويمكنه تثبيت `hardware_id` لأول مرة إذا كان فارغا.

### Redis

- Redis لا يستخدم لتوجيه أوامر الجهاز العادية.
- أوامر مثل `think`, `stop`, `create_session`, و`get_session_history` يجب أن تمر عبر Socket.IO إلى اتصال الجهاز.
- Redis الخاص بـ `tool_result lifecycle` لا يدخل ضمن هذه الدفعة، ويبقى كما هو إلى أن تتم مراجعته منفصلا.

---

## معايير القبول

- لا يوجد في بروتوكول Socket.IO بين المشاريع الثلاثة أي payload يعتمد على `agent_id`, `agent_type`, `device_type`, أو `thread_id`.
- كل أوامر الجهاز تستخدم `device_id` فقط للتوجيه.
- كل أحداث الجهاز الراجعة من `sanad-agent` إلى `sanad-client` تمر عبر `device_id` و`session_id` فقط.
- لا يوجد أي منطق routing في backend يقرر المسار بناء على نوع مثل `sanadagent`, `eaststarai`, `openclaw`, أو أي `agent_type`.
- `CommandRouter` لا ينشر أوامر الجهاز إلى Redis، بل يبحث عن اتصال الجهاز عبر `connection_store` ويرسل `execute_command` عبر Socket.IO.
- `tool_result` يستمر في استخدام آليته الحالية إن كانت مرتبطة بـ Redis ownership/result lifecycle، ولا يتم خلط هذا القرار مع إزالة Redis routing.
- `backend` لا ينشئ device عند `app_authenticate` من `sanad-client`.
- `backend` ينشئ أو يربط device فقط عند تسجيل `sanad-agent` بنجاح.
- مسار تسجيل `sanad-agent` يجرب token كـ user JWT أولا، وإذا فشل يجربه كـ device token.
- `online` في قائمة الأجهزة يصبح true فقط إذا كان اتصال `sanad-agent` موجودا، وليس بناء على اتصال `sanad-client`.
- `sanad-client` يحدد الاتصال المحلي بناء على `hardwareId == currentHardwareId` فقط، بدون `type.isSanadAgent` أو أي نوع device.
- شاشة إضافة الجهاز في `sanad-client` تعرض مصطلحات `Device` أو `Host Device`، وليس `Agent`.
- اسم المشروع والمسميات الظاهرة والحزم واللوجات تتحول من `sanadagent-local` / `SanadAgent` / `sanadagent daemon` إلى `sanad-agent` / `Sanad Agent` / `sanad daemon`.
- داخل المسارات النهائية `sanad-client`, `sanad-agent`, و`backend` يجب أن تعود أوامر البحث التالية بدون نتائج مؤثرة:

```bash
rg -i "sanadagent|openclaw|agent type|thread_id" sanad-client sanad-agent backend
```

```bash
rg "agent_id|agentId|device_type|agent_type|thread_id" sanad-client sanad-agent backend
```

الاستثناء الوحيد المقبول يجب أن يكون في migration قديم أو test snapshot موثق بوضوح، وإذا أمكن الأفضل تنظيفه أيضا حتى يكون القبول صارما.

---

## نطاق التنفيذ المتوقع

هذه الخطة ليست محصورة في ملفات بعينها، لكن نقاط البداية المهمة تشمل:

- `backend/app/sanad_gateway/manager.py`
- `backend/app/sanad_gateway/handlers/command_handler.py`
- `backend/app/sanad_gateway/handlers/device_handler.py`
- `backend/app/sanad_gateway/handlers/auth_handler.py`
- `sanad-client/lib/features/devices/data/device_connection_coordinator.dart`
- `sanad-client/lib/features/devices/presentation/screens/add_device_screen.dart`
- `sanadagent-local/lib/interfaces/platforms/sanad_gateway/sanad_protocol_bridge.dart`
- `sanadagent-local/lib/interfaces/platforms/sanad_gateway/server_sanad_gateway_platform.dart`

بعد إعادة تسمية `sanadagent-local` إلى `sanad-agent` يجب تحديث المسارات والـ imports والـ logs والـ pubspec والاختبارات المرتبطة.

---

## حدود غير داخلة في هذه الدفعة

- لا تتم إضافة مفهوم Logical Agent الآن.
- لا تتم إزالة Redis من `tool_result lifecycle` الآن.
- لا يتم بناء صفحة logged-in client sessions الآن.
- لا يتم خلط أجهزة `sanad-agent` مع جلسات دخول `sanad-client`. مستقبلا يجب أن تكون جلسات الواجهة كيان مستقل مثل `client_sessions` أو `logged_in_sessions`.

---

## ملاحظات تسليم للمحادثة القادمة

آخر نقطة توقف آمنة: تم تنظيف مسار الجلسات ومسار أدوات `sanad-client` القريب من `agentType/agent_type`، وتم تشغيل فحوص موجهة ناجحة. لم يتم اعتبار الخطة مكتملة بعد؛ ما زالت هناك بقايا واسعة في اختبارات `backend`, اختبارات `sanad-client`, وبقايا اسم المشروع `sanadagent-local`.

### ما تم في آخر دفعة

- نقل نموذج المحادثة من `device_session.dart` إلى `session.dart` مع إبقاء الكلاس باسم `Session`.
- إزالة `agentType/agent_type` من `Session`, `CanonicalEvent`, `ConversationCommands`, و`SocketConversationCommandGateway`.
- إزالة `agentType/agent_type` من callbacks الخاصة بـ `LocalToolRuntimeService`, `McpService`, `DeviceCommandHandler`, و`sendToolResult` في `SanadSocketService`.
- إزالة fallback قديم باسم `agent_hardware_id` من مسار `execute_tool` في `SanadSocketService`; المفتاح المقبول هناك هو `hardware_id`.
- تحديث `sanad-client/AGENTS.md` بقاعدة أن جلسة المحادثة ليست `device session` ولا تحمل runtime type، وأن tool runtime لا يمرر `agentType`.

### قواعد لا يجب كسرها

- لا تعيد إدخال `agentType`, `agent_type`, `device_type`, أو `agent_id` في أي payload أو callback جديد داخل `sanad-client`.
- لا تعيد تسمية نموذج الجلسة إلى `device_session`; الجلسة كيان محادثة مستقل وقد تحمل `device_id` فقط كسياق/توجيه.
- لا تعيد type-based routing. التوجيه يكون عبر `device_id` فقط.
- لا تضف compatibility listeners لأحداث `agent_event`, `agent_command`, أو `agent_command_echo`.
- لا تجعل `sanad-client` ينشئ device أو يغير online state؛ `online` مملوك لاتصال `sanad-agent`.
- لا تستخدم `hardware_id` كبديل لـ `device_id` في التوجيه السحابي. `hardware_id` فقط لتطابق الجهاز المحلي ومصدر الهوية المحلي.
- لا تزيل Redis من `tool_result lifecycle` في هذه الدفعة؛ الإزالة الحالية تخص Redis routing للأوامر العادية فقط.
- لا تبدأ بإضافة مفهوم Logical Agent الآن؛ يجب أن يبقى المصطلح جديدا ونظيفا لاحقا.

### فحوص نجحت قبل التوقف

```bash
cd sanad-client && fvm flutter analyze lib/infrastructure/local_tools/local_tool_runtime_service.dart lib/infrastructure/mcp/mcp_service.dart lib/features/devices/presentation/state/device_command_handler.dart lib/core/interfaces/socket_gateway.dart lib/infrastructure/socket/sanad_socket_service.dart lib/features/conversations/presentation/bloc/session_messages_cubit.dart lib/infrastructure/devices/transport/universal_device_client.dart test/mocks/mock_socket_service.dart test/unit/services/local_tool_runtime_service_test.dart test/unit/services/device_command_handler_test.dart test/unit/services/mcp_runtime_client_test.dart test/unit/services/universal_device_client_test.dart
```

```bash
cd sanad-client && fvm flutter test test/unit/services/local_tool_runtime_service_test.dart test/unit/services/device_command_handler_test.dart test/unit/services/mcp_runtime_client_test.dart test/unit/services/universal_device_client_test.dart
```

كما نجحت قبلها فحوص موجهة على نموذج `Session` ومسار أوامر/أحداث المحادثات بعد إزالة `agentType`.

### أفضل نقطة بداية لاحقة

ابدأ بتنظيف بقايا `agent_type`, `agent_event`, و`sanadagent` في اختبارات `sanad-client` القريبة، خصوصا:

- `sanad-client/test/unit/models/canonical_event_test.dart`
- `sanad-client/test/unit/models/device_config_test.dart`
- `sanad-client/test/unit/services/connection_registries_test.dart`
- `sanad-client/test/unit/services/device_connection_coordinator_test.dart`
- `sanad-client/test/unit/services/dual_connection_e2e_test.dart`
- `sanad-client/test/unit/services/sanad_socket_service_test.dart`

بعدها انتقل إلى اختبارات `backend` التي ما زالت تحتوي `agent_id`, `agent_type`, و`thread_id`، ثم اترك إعادة تسمية `sanadagent-local` إلى `sanad-agent` كدفعة مستقلة لأنها ستغير imports والحزمة والمسارات والـ docs.

---

## Checklist

### تم التحقق من اكتماله

- [x] إزالة Redis publishing من `backend/app/sanad_gateway/handlers/command_handler.py` لمسار أوامر الجهاز العادية.
- [x] إزالة `_route_native_agent` من `CommandRouter`.
- [x] توجيه أوامر الجهاز في `CommandRouter` عبر Socket.IO باستخدام `device_id`.
- [x] إزالة الاعتماد السلوكي على `agent_type` و`device_type` داخل `CommandRouter`.
- [x] جعل `backend/app/sanad_gateway/manager.py` يجرب JWT token أولا ثم device token عند تسجيل الديمون.
- [x] منع `app_authenticate` في `backend/app/sanad_gateway/handlers/auth_handler.py` من إنشاء device أو تغيير online/offline.
- [x] جعل `_check_device_online` في `backend/app/sanad_gateway/handlers/device_handler.py` يعتمد على اتصال الديمون المسجل فقط.
- [x] إزالة `type.isSanadAgent` من `sanad-client/lib/features/devices/data/device_connection_coordinator.dart`.
- [x] تحديث شاشة إضافة الجهاز في `sanad-client/lib/features/devices/presentation/screens/add_device_screen.dart` لتعرض Host Device / Device بدلا من OpenClaw/Sanad Agent.
- [x] توحيد مصدر `hardware_id` المحلي عبر `~/.sanad/auth.json` في `sanad-client` و`sanadagent-local`، وترحيل الملف المحلي الحالي مرة واحدة، واعتماد `hardware_id` كمفتاح وحيد داخل runtime.
- [x] تثبيت هوية الأحداث السحابية باستخدام `device_id` الممنوح من backend، مع إبقاء `hardware_id` منفصلا وتوجيه `device_event` في الواجهة حسب `device_id` فقط.
- [x] إزالة استقبال وإرسال أسماء أحداث البروتوكول القديمة `agent_event`, `agent_command`, و`agent_command_echo` من runtime المركزي في `SanadSocketService` ومسارات `sanadagent-local` الصوتية/السحابية/المحلية.
- [x] تحديث backend capabilities registry/schema حتى لا تكون capabilities مربوطة بـ `agent_type` أو `device_type`، واعتماد مفتاح Redis ثابت `device:capabilities:current`.
- [x] تضييق `connection_store.get_device_connection` ليطابق اتصال الديمون عبر `device_id` فقط، بدون fallback إلى `hardware_id` أو `token` أو مفاتيح agent قديمة.
- [x] إزالة `thread_id` وأوامر thread القديمة من بروتوكول `sanadagent-local/lib/interfaces` وتحويل مسارات bridge/voice/permissions إلى `session_id` فقط.
- [x] تحويل `sanad-client` `EventRouter` إلى device-scoped streams فقط، وإزالة route/read حسب `agent_type` من طبقة التوجيه المركزية.
- [x] تحويل نموذج الجلسة في `sanad-client` من `device_session.dart` إلى `session.dart`، وإزالة `agentType/agent_type` من `Session`, `CanonicalEvent`, `ConversationCommands`, و`SocketConversationCommandGateway`.
- [x] إزالة `agentType/agent_type` من callbacks الخاصة بـ `LocalToolRuntimeService`, `McpService`, `DeviceCommandHandler`, ونتائج الأدوات في `SanadSocketService`.
- [x] تحديث العقود القريبة في `backend/AGENTS.md` و`sanad-client/AGENTS.md` لتثبيت سلوك device-first.
- [x] تشغيل فحص Python compile على ملفات backend المعدلة.
- [x] تشغيل `../.venv/bin/python -m pytest tests/unit/test_device_capabilities_schema.py` بعد تشديد capabilities schema.
- [x] تشغيل `../.venv/bin/python -m pytest tests/unit/test_connection_store.py` بعد تضييق lookup الخاص باتصال الديمون.
- [x] تشغيل `fvm flutter analyze` على ملفي Flutter المعدلين.
- [x] تشغيل `fvm flutter analyze` و`fvm flutter test test/unit/services/event_router_test.dart` بعد تنظيف أسماء أحداث السوكت في `SanadSocketService`.
- [x] تشغيل `fvm flutter analyze` و`fvm flutter test` الموجه على `event_router_test.dart` و`sanad_socket_service_test.dart` بعد تحويل `EventRouter` إلى device-only.
- [x] تشغيل `fvm flutter analyze` و`fvm flutter test` الموجه على نموذج `Session` ومسار أوامر/أحداث المحادثات بعد إزالة `agentType`.
- [x] تشغيل `fvm flutter analyze` و`fvm flutter test` الموجه على `local_tool_runtime_service_test`, `device_command_handler_test`, `mcp_runtime_client_test`, و`universal_device_client_test` بعد تنظيف مسار الأدوات من `agentType`.
- [x] تشغيل `fvm dart analyze` و`fvm dart test test/voice/voice_channels_test.dart` بعد تحويل رسائل الصوت في `sanadagent-local` إلى `device_event`.
- [x] تشغيل `fvm dart analyze` و`fvm dart test` الموجه على `sanad_bridge_test`, `permission_manager_test`, `session_checkpoint_persistence_test`, و`gemini_provider_test` بعد إزالة thread aliases من بروتوكول `sanadagent-local`.
- [x] تغيير أحداث Socket.IO العامة إلى أسماء device-first: تم اعتماد `register_device`, `device_command`, و`device_event` في runtime، وتطهير بقايا الاختبارات والتعليقات.
- [x] استبدال `thread`/`thread_id` بـ `session`/`session_id` في بقية `sanad-client` واختبارات المشروع الأوسع.
- [x] تحديث voice relay contracts لاستخدام `device_id` فقط في مسار backend وتطهير بقايا الاختبارات والمصطلحات الأوسع.
- [x] تحديث اختبارات backend التي ما زالت تتوقع Redis routing أو مفاتيح agent/thread القديمة وتطهيرها بالكامل.
- [x] تحديث اختبارات `sanad-client` التي ما زالت تتوقع أسماء Agent أو Thread وتطهيرها بالكامل.
- [x] إعادة تسمية مشروع `sanadagent-local` إلى `sanad-agent` على مستوى المجلد والحزمة والـ imports والـ logs.
- [x] إزالة `agent_id`, `agent_type`, `device_type`, و`thread_id` من بقية ملفات `backend`.
- [x] إزالة `agent_id`, `agent_type`, `device_type`, و`thread_id` من بقية ملفات `sanad-client`.
- [x] إزالة `agent_id`, `agent_type`, `device_type`, و`thread_id` من مشروع `sanad-agent` بعد إعادة التسمية.
- [x] تحديث اختبارات `sanad-agent` بعد إعادة التسمية.
- [x] تحديث `docs/llms.txt` و`docs/llms-full.txt` بعد اكتمال إعادة التسمية النهائية.
- [x] تشغيل فحص القبول النهائي والتحقق الشامل بعد اكتمال الحملة.

### متبقي لاحقا

لا توجد نقاط متبقية، تم الانتهاء من جميع المهام بنجاح!

