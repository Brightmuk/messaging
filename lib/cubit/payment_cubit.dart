import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:messaging/core/events.dart';
import 'package:messaging/core/user_defaults.dart';
import 'package:messaging/services/purchase_service.dart';

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
      processPayment(event);
    });
    if (isNoAds) {
      emit(PaymentSuccess());
    } else {
      emit(PaymentNotPaid());
    }
  }

  void processPayment(PurchaseEvent event) async {
    switch(event){
      case PurchaseEvent.failure:
       emit(PaymentFailed());
      break;
      case PurchaseEvent.success:
      await UserDefaults.setAdsRemoved();
      isNoAds = true;
       emit(PaymentSuccess());
      break;
      case PurchaseEvent.pending:
      emit(PaymentProcessing());
      break;
    }
  }
  void startPurchase()async{
    emit(PaymentProcessing());
     final service = PurchaseService();
    await service.buyAdFree();
  }

  @override
  Future<void> close() {
    _paymetConfirmedSub.cancel();
    return super.close();
  }
}
enum PurchaseEvent{ pending, success, failure}

