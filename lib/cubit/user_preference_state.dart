part of 'user_preference_cubit.dart';

class UserPreferenceState  extends Equatable {
  final ThemeMode themeMode;

  const UserPreferenceState({required this.themeMode});

  factory UserPreferenceState.initial() => 
      const UserPreferenceState(themeMode: ThemeMode.system);
      
        @override
        List<Object?> get props => [themeMode];
}