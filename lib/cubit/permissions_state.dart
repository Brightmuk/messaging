part of 'permissions_cubit.dart';

class PermissionsState {
  final Map<Permission, PermissionStatus> statuses;
  final bool isDefaultApp;

  PermissionsState({required this.statuses, required this.isDefaultApp});

  bool get allGranted => 
    statuses.values.every((s) => s.isGranted) && isDefaultApp;
}