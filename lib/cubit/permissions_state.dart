part of 'permissions_cubit.dart';


class PermissionsState {
  final Map<Permission, PermissionStatus> statuses;
  final bool isDefaultApp;
  final AppLifecycleStatus status;

  PermissionsState({
    required this.statuses, 
    required this.isDefaultApp,
    this.status = AppLifecycleStatus.initial,
  });

  bool get allGranted => 
     statuses.isNotEmpty && statuses.values.every((s) => s.isGranted);

  PermissionsState copyWith({
    Map<Permission, PermissionStatus>? statuses,
    bool? isDefaultApp,
    AppLifecycleStatus? status,
  }) {
    return PermissionsState(
      statuses: statuses ?? this.statuses,
      isDefaultApp: isDefaultApp ?? this.isDefaultApp,
      status: status ?? this.status,
    );
  }
}