import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:messaging/core/user_defaults.dart';
import 'package:messaging/services/sms_service.dart';
import 'package:permission_handler/permission_handler.dart';

part 'permissions_state.dart';

enum AppLifecycleStatus {
  initial,
  onboarding,
  promptPermissions,
  authenticated
}

class PermissionsCubit extends Cubit<PermissionsState> {
  PermissionsCubit()
      : super(PermissionsState(statuses: {}, isDefaultApp: false)) {
    initialize();
  }

  final List<Permission> _requiredPermissions = [
    Permission.sms,
    Permission.contacts,
    Permission.phone,
    Permission.notification,
  ];

  Future<void> initialize() async {
    final onboarded = await UserDefaults.hasOnboarded();
    final bool isDefault = await SmsService.isDefaultSmsApp();
    if (!onboarded) {
      emit(state.copyWith(
          status: AppLifecycleStatus.onboarding, isDefaultApp: isDefault));
    } else {
      await checkStatus();
    }
  }

  Timer? _authTimer;

  Future<void> completeOnboarding() async {
    await UserDefaults.setHasOnboarded();

    await SmsService.requestDefaultSmsRole();

    int secondsPassed = 0;
    _authTimer?.cancel();

    _authTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      secondsPassed++;

      await checkStatus();

      if (state.isDefaultApp || secondsPassed >= 15) {
        timer.cancel();
      }
    });
  }

  Future<void> checkStatus() async {
    final bool isDefault = await SmsService.isDefaultSmsApp();
    final bool hasViewedPermissions = await UserDefaults.hasViewedPermissions();
    if (isDefault && hasViewedPermissions) {
      emit(state.copyWith(
        isDefaultApp: isDefault,
        statuses: {},
        status: AppLifecycleStatus.authenticated,
      ));
    }

    final activePermissions = isDefault
        ? _requiredPermissions // [SMS, Contacts, Phone, Notifications]
        : _requiredPermissions
            .where((p) => p == Permission.sms || p == Permission.notification)
            .toList();

    Map<Permission, PermissionStatus> newStatuses = {};
    for (var p in activePermissions) {
      newStatuses[p] = await p.status;
    }

    bool allEssentialGranted = newStatuses.entries
        .where((e) => e.key != Permission.notification)
        .every((e) => e.value.isGranted);

    emit(state.copyWith(
      isDefaultApp: isDefault,
      statuses: newStatuses,
      status: allEssentialGranted
          ? AppLifecycleStatus.authenticated
          : AppLifecycleStatus.promptPermissions,
    ));
  }

  Future<void> requestAllRemaining() async {
    UserDefaults.setHasViewedPermissions();
    final bool isDefault = state.isDefaultApp;

    final permissionsToRequest = isDefault
        ? _requiredPermissions
        : _requiredPermissions
            .where((p) => p == Permission.sms || p == Permission.notification)
            .toList();

    for (var p in permissionsToRequest) {
      await p.request();
      await Future.delayed(const Duration(milliseconds: 100));
    }

    Map<Permission, PermissionStatus> finalStatuses = {};
    Permission? firstDenied;

    for (var p in permissionsToRequest) {
      final status = await p.status;
      if (status.isGranted) continue;
      finalStatuses[p] = status;

      if (!status.isGranted &&
          firstDenied == null &&
          p != Permission.notification) {
        firstDenied = p;
      }
    }

    if (firstDenied != null) {
      emit(state.copyWith(
        statuses: finalStatuses,
        isDefaultApp: isDefault,
        lastDeniedPermission: firstDenied,
      ));
    } else {
      await checkStatus();
    }
  }

  void resetDeniedTrigger() {
    emit(state.copyWith(clearDenied: true));
  }

  @override
  Future<void> close() {
    _authTimer?.cancel();
    return super.close();
  }
}
