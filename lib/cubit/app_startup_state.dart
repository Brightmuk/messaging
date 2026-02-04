part of 'app_startup_cubit.dart';

@immutable
sealed class AppStartupState {}

final class AppStartupLoading extends AppStartupState {}
final class AppStartupPermissionsDenied extends AppStartupState {}
final class AppStartupLoaded extends AppStartupState {}
