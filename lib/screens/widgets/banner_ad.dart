import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:messaging/core/user_defaults.dart';
import 'package:messaging/services/ads/banner_ads.dart';

class MfichaBannerAd extends StatefulWidget {
  final AdType adType;
  const MfichaBannerAd({super.key, this.adType = AdType.home});

  @override
  State<MfichaBannerAd> createState() => _MfichaBannerAdState();
}

class _MfichaBannerAdState extends State<MfichaBannerAd> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() async {
    if (await UserDefaults.getAdsRemoved()) return;
    _bannerAd = BannerAdService.createBannerAd(
      type: widget.adType,
      onAdLoaded: (ad) {
        setState(() => _isLoaded = true);
      },
      onAdFailedToLoad: (ad, error) {
        ad.dispose();
        debugPrint('Banner Ad failed to load: $error');
      },
    );
    _bannerAd!.load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoaded && _bannerAd != null) {
     return Container(
            alignment: Alignment.center,
            width: _bannerAd!.size.width.toDouble(),
            height: _bannerAd!.size.height.toDouble(),
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: AdWidget(ad: _bannerAd!),
          );
    }
    return const SizedBox.shrink();
  }
}
