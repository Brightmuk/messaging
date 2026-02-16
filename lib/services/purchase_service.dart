import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:messaging/core/user_defaults.dart';

class PurchaseService {
  final InAppPurchase _iap = InAppPurchase.instance;

  void initializeIAP() {
    // Listen to every update from Google
    final Stream<List<PurchaseDetails>> purchaseUpdated = _iap.purchaseStream;

    purchaseUpdated.listen((purchaseDetailsList) {
      _handlePurchaseUpdates(purchaseDetailsList);
    }, onDone: () {
      debugPrint("Purchase stream closed");
    }, onError: (error) {
      debugPrint("Purchase stream error: $error");
    });
  }

  void _handlePurchaseUpdates(List<PurchaseDetails> purchaseDetailsList) {
    for (var purchase in purchaseDetailsList) {
      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        if (purchase.productID == 'm_ficha_lifetime_no_ads') {
          UserDefaults.setAdsRemoved();
        }

        // Crucial: Tell Google you received the "product" so they don't refund it
        if (purchase.pendingCompletePurchase) {
          _iap.completePurchase(purchase);
        }
      }
    }
  }

  Future<void> restorePurchases() async {
    await _iap.restorePurchases();
  }
}
