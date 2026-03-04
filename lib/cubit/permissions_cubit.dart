import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';
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

class PermissionsCubit extends Cubit<AppLifecycleStatus> {
  PermissionsCubit() : super(AppLifecycleStatus.initial) {
    initialize();
  }
  final List<Permission> requiredPermissions = [
    Permission.notification,
  ];

  Future<void> initialize() async {
    final onboarded = await UserDefaults.hasOnboarded();
    if (!onboarded) {
      emit(AppLifecycleStatus.onboarding);
    } else {
      emit(AppLifecycleStatus.authenticated);
    }
  }

  Future<void> completeOnboarding() async {
    await UserDefaults.setHasOnboarded();
    checkStatus();
  }

  Future<void> requestDefaultAndCheck() async {
    await SmsService.requestDefaultSmsRole();
    await checkStatus();
  }

  Timer? _defaultAppTimer;
  int _count = 0;
  Future<void> checkStatus() async {
    final isDefault = await SmsService.isDefaultSmsApp();
    if (isDefault) {
      emit(AppLifecycleStatus.authenticated);
    } else {
      _defaultAppTimer?.cancel();
      _defaultAppTimer =
          Timer.periodic(const Duration(seconds: 1), (timer) async {
        _count++;
        final isDefault = await SmsService.isDefaultSmsApp();
        if (isDefault) {
          debugPrint("App is now default SMS app");
          timer.cancel();
          goToHome();
        } else {
          debugPrint("Still waiting for default role... (${_count}s)");
        }
        if (_count >= 10) {
          timer.cancel();
        }
      });
      emit(AppLifecycleStatus.promptPermissions);
    }
  }

  void goToHome() {
    emit(AppLifecycleStatus.authenticated);
  }

  @override
  Future<void> close() {
    _defaultAppTimer?.cancel();
    return super.close();
  }
}
