import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:messaging/core/user_defaults.dart';

part 'user_preference_state.dart';



class UserPreferenceCubit extends Cubit<UserPreferenceState> {
  UserPreferenceCubit() : super(UserPreferenceState.initial()) {
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final themeIndex = await UserDefaults.getThemeMode();
    final savedMode = ThemeMode.values[themeIndex];
    emit(UserPreferenceState(themeMode: savedMode));
  }

  Future<void> updateThemeMode(ThemeMode mode) async {
    await UserDefaults.setThemeMode(mode.index);
    emit(UserPreferenceState(themeMode: mode));
  }
}
