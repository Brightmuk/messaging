import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
enum AdType { home, inChat }
class BannerAdService {
  static String get homeAdId {
    if (kDebugMode) {
      return 'ca-app-pub-3940256099942544/6300978111';
    } else {
      return 'ca-app-pub-4276933186583420/7324175687'; 
    }
  }
  static String get inChatAdId {
    if (kDebugMode) {
      return 'ca-app-pub-3940256099942544/6300978111';
    } else {
      return 'ca-app-pub-4276933186583420/4879534615'; 
    }
  }


  static BannerAd? createBannerAd({
    required AdType type,
    required void Function(Ad) onAdLoaded,
    required void Function(Ad, LoadAdError) onAdFailedToLoad,
  }) {
    
    return BannerAd(
      adUnitId: type == AdType.home ? homeAdId : inChatAdId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: onAdLoaded,
        onAdFailedToLoad: onAdFailedToLoad,
      ),
    );
  }
}