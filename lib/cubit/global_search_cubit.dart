import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:messaging/models/app_message.dart';
import 'package:messaging/services/sms_service.dart';
part 'global_search_state.dart';

class GlobalSearchCubit extends Cubit<GlobalSearchState> {
  final SmsService _smsService = SmsService();

  GlobalSearchCubit() : super(GlobalSearchInitial());

  Timer? _debounce;
  void search(String query) {
    _debounce?.cancel();
    if (query.isEmpty) {
      emit(GlobalSearchInitial());
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      emit(GlobalSearchLoading());
      try {
        final results = await _smsService.searchGlobal(query);
        emit(GlobalSearchLoaded(results: results, query: query));
      } catch (_) {
        emit(const GlobalSearchError(error: "Search failed"));
      }
    });
  }

  @override
  Future<void> close() {
    _debounce?.cancel();
    return super.close();
  }
}
