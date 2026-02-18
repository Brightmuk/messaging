import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:messaging/models/sim_card_state.dart';
import 'package:messaging/services/sms_service.dart';

part 'sim_card_state.dart';

class SimCardCubit extends Cubit<SimCardState> {
  SimCardCubit() : super(SimCardInitial()){
      init();
  }

  init() async {
    try{
      AppSimCardState state = await SmsService().getSimState();
      emit(SimCardLoaded(state: state));
    } catch (e) {
      emit(SimCardError(message: e.toString()));
    }
  }
  Future<void> setAsDefaultApp() async {
    await SmsService.requestDefaultSmsRole();
  }
  Future<void> setDefaultSim(int sim) async {
    try {
      await SmsService().setDefaultSim(sim);
      AppSimCardState newState = await SmsService().getSimState();
      emit(SimCardLoaded(state: newState));
    } catch (e) {
      emit(SimCardError(message: e.toString()));
    }
  }
}
