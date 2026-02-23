import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:messaging/core/events.dart';
import 'package:messaging/core/user_defaults.dart';

part 'payment_state.dart';

class PaymentCubit extends Cubit<PaymentState> {
  late StreamSubscription _paymetConfirmedSub;
  PaymentCubit() : super(PaymentInitial()) {
    init();
  }
  bool isNoAds = false;
  void init() async {
    isNoAds = await UserDefaults.getAdsRemoved();
    _paymetConfirmedSub = eventBus.on<PurchaseEvent>().listen((event) {
      refreshPayment(event.success);
    });
    if (isNoAds) {
      emit(PaymentSuccess());
    } else {
      emit(PaymentNotPaid());
    }
  }

  void refreshPayment(bool success) async {
    if (success) {
      await UserDefaults.setAdsRemoved();
      isNoAds = true;
      emit(PaymentSuccess());
    } else {
      emit(PaymentFailed());
    }
  }

  @override
  Future<void> close() {
    _paymetConfirmedSub.cancel();
    return super.close();
  }
}

class PurchaseEvent {
  final bool success;
  PurchaseEvent({required this.success});
}
