part of 'app_startup_cubit.dart';

@immutable
sealed class AppStartupState extends Equatable {
  const AppStartupState();

  @override
  List<Object> get props => [];
}

final class AppStartupLoading extends AppStartupState {}
final class AppStartupNotOnboarded extends AppStartupState {}
final class AppStartupGrantPermissions extends AppStartupState {}
final class AppStartupLoaded extends AppStartupState {}
