part of 'permissions_cubit.dart';

class PermissionsState {
  final Map<Permission, PermissionStatus> statuses;
  final bool isDefaultApp;
  final bool isDefaultRequested;

  PermissionsState({required this.statuses, required this.isDefaultApp, required this.isDefaultRequested});

  bool get allGranted => 
    statuses.isNotEmpty && statuses.values.every((s) => s.isGranted);
}