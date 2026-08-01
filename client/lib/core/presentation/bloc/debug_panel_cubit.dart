import 'package:flutter_bloc/flutter_bloc.dart';

class DebugPanelCubit extends Cubit<bool> {
  DebugPanelCubit() : super(false);

  void toggle() => emit(!state);

  void open() => emit(true);

  void hidePanel() => emit(false);
}
