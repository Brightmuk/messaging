import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class RewardedAdService {
   static final RewardedAdService _instance = RewardedAdService._internal();
  factory RewardedAdService() => _instance;
  RewardedAdService._internal();

  RewardedAd? _rewardedAd;

  final testAdUnitId = 'ca-app-pub-3940256099942544/5224354917';
  final prodAdUnitId =  'ca-app-pub-4276933186583420/5175092246';

  void loadAd({VoidCallback? onLoaded, Function(String)? onError}) {
    RewardedAd.load(
      adUnitId: kDebugMode ? testAdUnitId : prodAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint("Rewarded Ad Loaded Successfully");
          _rewardedAd = ad;
          
          // Set up listeners for the ad lifecycle
          _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _rewardedAd = null;
              loadAd(); // Preload the next one immediately 
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _rewardedAd = null;
              onError?.call(error.message);
            },
          );
          
          onLoaded?.call();
        },
        onAdFailedToLoad: (error) {
          _rewardedAd = null;
          onError?.call(error.message);
          debugPrint("Failed to load rewarded ad: ${error.message}");
        },
      ),
    );
  }

  /// Shows the ad and executes [onRewardEarned] only if the user finishes the ad.
  void showAd({required Function(RewardItem reward) onRewardEarned}) {
    if (_rewardedAd != null) {
      _rewardedAd!.show(
        onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
          // This is where you remove the watermark!
          onRewardEarned(reward);
        },

      );
    } else {
      debugPrint("Warning: Tried to show rewarded ad before it was loaded.");
    }
  }

  bool get isAdLoaded => _rewardedAd != null;
}