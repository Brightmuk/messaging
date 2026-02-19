import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:messaging/core/user_defaults.dart';
import 'package:meta/meta.dart';
import 'package:permission_handler/permission_handler.dart';

part 'app_startup_state.dart';

class AppStartupCubit extends Cubit<AppStartupState> {
  AppStartupCubit() : super(AppStartupLoading()){
    _initialize();
  }

  Future<bool> _checkStartupPermissions() async {
    var smsStatus = await Permission.sms.status;
    var contactsStatus = await Permission.contacts.status;
    var notificationStatus = await Permission.notification.status;
    var phoneStatus = await Permission.phone.status;
    

    return smsStatus.isGranted &&
        contactsStatus.isGranted &&
        phoneStatus.isGranted &&
        notificationStatus.isGranted;
  }
 
  void _initialize() async {
    emit(AppStartupLoading());
    final granted = await _checkStartupPermissions();
    final hasOnboarded = await UserDefaults.hasOnboarded();
    if (!hasOnboarded) {
      emit(AppStartupNotOnboarded());
      return;
    }
    if (granted) {
      emit(AppStartupLoaded());
    } else {
      emit(AppStartupGrantPermissions());
    }
  }
  Future<void> viewOnboarding() async {
    await UserDefaults.setHasOnboarded();
    emit(AppStartupGrantPermissions());
  }
}
