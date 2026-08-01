import 'package:uuid/uuid.dart';

String generateConversationRequestId() => 'req_${const Uuid().v4()}';
