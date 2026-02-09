import 'package:bloc/bloc.dart';
import 'package:messaging/services/sms_service.dart';
import 'package:permission_handler/permission_handler.dart';

part 'permissions_state.dart';

class PermissionsCubit extends Cubit<PermissionsState> {
  PermissionsCubit() : super(PermissionsState(statuses: {}, isDefaultApp: false));

  final List<Permission> requiredPermissions = [
    Permission.sms,
    // Permission.phone,
    Permission.contacts,
    Permission.notification,
  ];

  Future<void> checkAll() async {
    Map<Permission, PermissionStatus> newStatuses = {};
    for (var p in requiredPermissions) {
      newStatuses[p] = await p.status;
    }
    final isDefault = await SmsService.isDefaultSmsApp();
    emit(PermissionsState(statuses: newStatuses, isDefaultApp: isDefault));
  }

  Future<void> request(Permission p) async {
    await p.request();
    await checkAll();
  }
  Future<void> openAppSettings() async {
  await openAppSettings();
  await checkAll(); 
}

  Future<void> requestDefaultRole() async {
    await SmsService.requestDefaultSmsRole();
    await checkAll();
  }
}
