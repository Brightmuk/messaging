import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/foundation.dart';


class InterstitialAdService{
  
  InterstitialAdService();

  InterstitialAd? _interstitialAd;

  final testAdUnitId = Platform.isAndroid
      ? 'ca-app-pub-3940256099942544/1033173712'
      : 'ca-app-pub-3940256099942544/4411468910';
  final prodAdUnitId = Platform.isAndroid
      ? 'ca-app-pub-4276933186583420/3786250348'
      : 'ca-app-pub-4276933186583420/7734174220';

    
  void loadAd({VoidCallback? onLoaded, Function(String)? onError}) {

    InterstitialAd.load(
      adUnitId: kDebugMode? testAdUnitId:prodAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdShowedFullScreenContent: (_) {
             
            },
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _interstitialAd = null;
              loadAd();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _interstitialAd = null;
              onError?.call(error.message);
            },
            onAdClicked: (_) {},
            onAdImpression: (_) {},
          );
          _interstitialAd = ad;
          onLoaded?.call();
        },
        onAdFailedToLoad: (error) {
          _interstitialAd = null;
          onError?.call(error.message);
         
          debugPrint(error.message);
        },
      ),
    );
    
  }

  void showAd() {
    if (_interstitialAd != null) {
      _interstitialAd!.show();
    }
  }

  bool get isAdLoaded => _interstitialAd != null;
}
