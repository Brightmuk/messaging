part of 'global_search_cubit.dart';

sealed class GlobalSearchState extends Equatable {
  const GlobalSearchState();

  @override
  List<Object> get props => [];
}

final class GlobalSearchInitial extends GlobalSearchState {}
final class GlobalSearchLoading extends GlobalSearchState {}
final class GlobalSearchLoaded extends GlobalSearchState {
  final List<AppSmsMessage> results;
  final String query;

  const GlobalSearchLoaded({required this.results, required this.query});
}
final class GlobalSearchError extends GlobalSearchState {
  final String error;

  const GlobalSearchError({required this.error});
  
}
