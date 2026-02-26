import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:messaging/services/ads/native_ads_service.dart';

class ChatsNativeAd extends StatefulWidget {
  const ChatsNativeAd({super.key});

  @override
  State<ChatsNativeAd> createState() => _ChatsNativeAdState();
}

class _ChatsNativeAdState extends State<ChatsNativeAd> {
  NativeAd? _myLoadedNativeAd;
  bool _isLoaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isLoaded) {
      _loadNativeAd();
    }
  }

  void _loadNativeAd() async {
    await NativeAdService.loadChatsNativeAd(
      context,
      onAdLoaded: (loadedAd) {
        if (!mounted) {
          loadedAd.dispose();
          return;
        }
        setState(() {
          _isLoaded = true;
          _myLoadedNativeAd = loadedAd;
        });
      },
    );
  }

  @override
  void dispose() {
    _myLoadedNativeAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoaded || _myLoadedNativeAd == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      height: 100,
      child: AdWidget(ad: _myLoadedNativeAd!),
    );
  }
}
