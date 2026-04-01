import 'dart:async';
import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:messaging/core/events.dart';
import 'package:messaging/core/user_defaults.dart';
import 'package:messaging/services/purchase_service.dart';

part 'payment_state.dart';

class PaymentCubit extends Cubit<PaymentState> {
  late StreamSubscription _paymetConfirmedSub;
  final PurchaseService _service = PurchaseService();
  StreamSubscription? _demoModeSubscription;
  PaymentCubit() : super(PaymentInitial()) {
    init();
  }
  String price = "Ksh.500";
  bool isNoAds = false;
  void init() async {
    loadProducts();
    isNoAds = await UserDefaults.getAdsRemoved();
    _paymetConfirmedSub = eventBus.on<PurchaseStatus>().listen((event) {
      _processPayment(event);
    });

    _demoModeSubscription = eventBus.on<DemoMode>().listen((event) {
      isNoAds = event.isActive;
      if (isNoAds) {
        emit(PaymentPaid(price: price));
      } else {
        emit(PaymentNotPaid());
      }
    });
    if (isNoAds) {
      emit(PaymentPaid(price: price));
    } else {
      emit(PaymentNotPaid());
    }
  }


  Timer? _pendingTimer;
  void _processPayment(PurchaseStatus event) async {
    switch (event) {
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
        _pendingTimer = Timer(const Duration(seconds: 45), () {
          if (state is PaymentProcessing) {
            emit(const PaymentFailed(
                message:
                    "Payment is taking too long. Please check your Play Store account."));
          }
        });
        emit(PaymentProcessing());
        break;

      case PurchaseStatus.canceled:
        emit(const PaymentFailed(message: "You canceled the payment!"));
        break;
    }
  }
  void loadProducts() async {
  
    List<ProductDetails> products = await _service.loadProducts();
    price = products.firstOrNull?.price ?? "Ksh.500";
    UserDefaults.setAdFreePrice(products.firstOrNull?.price);
    emit(PaymentPaid(price: price));
  }


  void startPurchase() async {
    emit(PaymentProcessing());

    await _service.buyAdFree();
  }

  void restorePurchase() async {
    emit(PaymentProcessing());
    _service.restorePurchases();
  }

  @override
  Future<void> close() {
    _paymetConfirmedSub.cancel();
    _pendingTimer?.cancel();
    _demoModeSubscription?.cancel();
    return super.close();
  }
}
