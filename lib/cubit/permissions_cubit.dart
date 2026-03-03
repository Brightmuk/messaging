import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:messaging/services/sms_service.dart';
import 'package:permission_handler/permission_handler.dart';

part 'permissions_state.dart';

class PermissionsCubit extends Cubit<PermissionsState> {
  PermissionsCubit()
      : super(PermissionsState(statuses: {}, isDefaultApp: false, isDefaultRequested: false));

  final List<Permission> requiredPermissions = [
    Permission.sms,
    Permission.phone,
    Permission.contacts,
    Permission.notification,
  ];

  bool _isDefaultRequested = false;

  Future<void> checkAll() async {
  // Check default status first
  final isDefault = await SmsService.isDefaultSmsApp();
  
  Map<Permission, PermissionStatus> newStatuses = {};
  
  if (_isDefaultRequested) {
    for (var p in requiredPermissions) {
      newStatuses[p] = await p.status;
    }
  }
  
  emit(PermissionsState(statuses: newStatuses, isDefaultApp: isDefault, isDefaultRequested: _isDefaultRequested));
}

  Future<void> request(Permission p) async {
    await p.request();
    await checkAll();
  }

  Future<void> openAppSettings() async {
    await openAppSettings();
    await checkAll();
  }

  Timer? _timer;
  int _count = 0;
  Future<void> requestDefaultRole() async {
    _isDefaultRequested = true;
    await SmsService.requestDefaultSmsRole();
    await checkAll();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      _count++;
      final isDefault = await SmsService.isDefaultSmsApp();
      if (isDefault) {
        print("App is now default SMS app");
        timer.cancel();
        await checkAll();
      }else{
        print("Still waiting for default role... (${_count}s)");
      }
      if (_count >= 10) {
        timer.cancel();
      }
    });
  }
  void stopTImer(){
    _timer?.cancel();
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}
