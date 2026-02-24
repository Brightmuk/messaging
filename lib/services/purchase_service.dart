import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:messaging/core/events.dart';
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

  void _handlePurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (var purchase in purchases) {
        
      if (purchase.status == PurchaseStatus.purchased || purchase.status == PurchaseStatus.restored) {
        //Do early enough
        await UserDefaults.setAdsRemoved();
        eventBus.fire(purchase.status);
        if (purchase.pendingCompletePurchase) {
          await _iap.completePurchase(purchase);
        }
      } else {
        eventBus.fire(purchase.status);
      }
    }
  }

  Future<void> buyAdFree() async {
    // 1. Check if store is available
    final bool available = await _iap.isAvailable();
    if (!available) return;

    // 2. Query your specific product ID
    const Set<String> _kIds = {'m_ficha_lifetime_no_ads'};
    final ProductDetailsResponse response =
        await _iap.queryProductDetails(_kIds);

    if (response.notFoundIDs.isNotEmpty) {
      // Product not found in Play Console
      return;
    }

    // 3. Launch the Google Pay / Play Store overlay
    final PurchaseParam purchaseParam =
        PurchaseParam(productDetails: response.productDetails.first);

    _iap.buyNonConsumable(purchaseParam: purchaseParam);
  }

  Future<void> restorePurchases() async {
    await _iap.restorePurchases();
  }
}
