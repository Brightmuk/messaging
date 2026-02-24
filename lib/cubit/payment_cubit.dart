import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
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
    _paymetConfirmedSub = eventBus.on<PurchaseStatus>().listen((event) {
      processPayment(event);
    });
    if (isNoAds) {
      emit(PaymentPaid());
    } else {
      emit(PaymentNotPaid());
    }
  }

  void processPayment(PurchaseStatus event) async {
    print("New event: $event");
    switch(event){
      case PurchaseStatus.error:
       emit(const PaymentFailed(message: "Payment failed, please try again!"));
      break;

      case PurchaseStatus.purchased:
      case PurchaseStatus.restored:
      await UserDefaults.setAdsRemoved();
      isNoAds = true;
       emit(PaymentSuccess(isRestored: event == PurchaseStatus.restored));
      break;

      case PurchaseStatus.pending:
      emit(PaymentProcessing());
      break;

      case PurchaseStatus.canceled:
      emit(const PaymentFailed(message: "You canceled the payment!"));
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


