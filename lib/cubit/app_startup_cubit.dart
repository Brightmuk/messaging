import 'package:bloc/bloc.dart';
import 'package:meta/meta.dart';
import 'package:permission_handler/permission_handler.dart';

part 'app_startup_state.dart';

class AppStartupCubit extends Cubit<AppStartupState> {
  AppStartupCubit() : super(AppStartupLoading()){
    _initialize();
  }

  Future<bool> _checkStartupPermissions() async {
    final statuses = await [
      Permission.sms,
      Permission.phone,
      Permission.contacts,
      Permission.notification,
    ].request();

    return statuses.values.every((s) => s.isGranted);
  }
  void _initialize() async {
    emit(AppStartupLoading());
    await Future.delayed(const Duration(seconds: 2));
    final granted = await _checkStartupPermissions();
    if (granted) {
      emit(AppStartupLoaded());
    } else {
      emit(AppStartupPermissionsDenied());
    }
  }
}
