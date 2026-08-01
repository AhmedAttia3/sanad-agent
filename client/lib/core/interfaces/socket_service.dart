import 'dart:async';

abstract class ISocketService {
  bool get isConnected;
  Stream<Map<String, dynamic>> get onAuthSuccess;
  Stream<Map<String, dynamic>> get events;
  Future<void> connect();
  void disconnect();
  void setAccessToken(String? token);
  void emit(String event, dynamic data);
}
