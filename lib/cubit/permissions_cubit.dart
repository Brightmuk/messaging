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
  PermissionsCubit() : super(PermissionsState(statuses: {})) {
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
    if (!onboarded) {
      emit(state.copyWith(status: AppLifecycleStatus.onboarding));
    } else {
      await checkStatus();
    }
  }

  Future<void> completeOnboarding() async {
    await UserDefaults.setHasOnboarded();
    await SmsService.requestDefaultSmsRole();
    await checkStatus();
  }

  Future<void> checkStatus() async {
    Map<Permission, PermissionStatus> newStatuses = {};
    for (var p in _requiredPermissions) {
      newStatuses[p] = await p.status;
    }

   bool allEssentialGranted = newStatuses.entries
      .where((e) => e.key != Permission.notification) 
      .every((e) => e.value.isGranted);

  emit(state.copyWith(
    statuses: newStatuses,
    status: allEssentialGranted 
        ? AppLifecycleStatus.authenticated 
        : AppLifecycleStatus.promptPermissions,
  ));
  }

  Future<void> requestAllRemaining() async {

    // 2. Request each one
    for (var p in _requiredPermissions) {
      await p.request();
    }

    // 3. Check what happened
    Map<Permission, PermissionStatus> finalStatuses = {};
    Permission? firstDenied;

    for (var p in _requiredPermissions) {
      final status = await p.status;
      finalStatuses[p] = status;
      if (!status.isGranted && firstDenied == null && p != Permission.notification) {
        firstDenied = p;
      }
    }

    if (firstDenied != null) {
      emit(state.copyWith(
        statuses: finalStatuses,
        lastDeniedPermission: firstDenied,
      ));
    } else {
      await checkStatus();
    }
  }

  void resetDeniedTrigger() {
    emit(state.copyWith(clearDenied: true));
  }
}
