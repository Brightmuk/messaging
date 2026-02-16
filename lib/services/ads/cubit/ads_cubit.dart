import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:messaging/services/ads/interstitial_ads_service.dart';

import 'ads_state.dart';

class AdsCubit extends Cubit<AdsState> {
  final InterstitialAdService _interstitialAdService = InterstitialAdService();

  AdsCubit() : super(AdsInitial()) {
    _loadInterstitialAd();
 
  }

  bool _showAdThisTime = false;

  void _loadInterstitialAd() {
    debugPrint('\nLoading interstitial ad\n');
    _interstitialAdService.loadAd(
      onLoaded: () {
        emit(AdsLoaded());
      },
      onError: (err) {
        emit(AdsFailed(err));
      },
    );
  }


  void showInterstitialAd() {
    if (_showAdThisTime) {
      debugPrint('\n\nShowing ad this time\n ');
      if (_interstitialAdService.isAdLoaded) {
        _interstitialAdService.showAd();
        
      } else {
        emit(const AdsFailed('Ad not loaded'));
      }
    } else {
      debugPrint('\n\nNot showing ad this time\n ');
    }
    _showAdThisTime = !_showAdThisTime;
  }


}
