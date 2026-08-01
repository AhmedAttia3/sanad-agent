import 'package:flutter_bloc/flutter_bloc.dart';

class AppErrorCubit extends Cubit<String?> {
  AppErrorCubit() : super(null);

  void setError(String? message) => emit(message);

  void clear() => emit(null);
}
