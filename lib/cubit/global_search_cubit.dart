import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:messaging/models/app_message.dart';
import 'package:messaging/services/sms_service.dart';

part 'global_search_state.dart';

class GlobalSearchCubit extends Cubit<GlobalSearchState> {
  final SmsService _smsService = SmsService();

  GlobalSearchCubit(): super(GlobalSearchInitial());
  

  void search(String query) async {
    if (query.isEmpty) {
      emit(GlobalSearchInitial());
      return;
    }
    emit(GlobalSearchLoading());
    try {
      final results = await _smsService.searchGlobal(query);
      emit(GlobalSearchLoaded(results: results, query: query));
    } catch (e) {
      emit(const GlobalSearchError(error: "Search failed"));
    }
  }
}