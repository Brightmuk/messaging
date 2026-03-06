part of 'permissions_cubit.dart';


class PermissionsState {
  final Map<Permission, PermissionStatus> statuses;
  final AppLifecycleStatus status;
  final Permission? lastDeniedPermission;

  PermissionsState({
    required this.statuses,
    this.status = AppLifecycleStatus.initial,
    this.lastDeniedPermission,
  });

  PermissionsState copyWith({
    Map<Permission, PermissionStatus>? statuses,
    AppLifecycleStatus? status,
    Permission? lastDeniedPermission,
    bool clearDenied = false,
  }) {
    return PermissionsState(
      statuses: statuses ?? this.statuses,
      status: status ?? this.status,
      lastDeniedPermission: clearDenied ? null : (lastDeniedPermission ?? this.lastDeniedPermission),
    );
  }
}