import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:messaging/services/ads/native_ads_service.dart';
import 'package:messaging/services/mask_service.dart';

class ChatAdBubble extends StatefulWidget {
  final String address;
  const ChatAdBubble({super.key, required this.address});

  @override
  State<ChatAdBubble> createState() => _ChatAdBubbleState();
}

class _ChatAdBubbleState extends State<ChatAdBubble> {
  NativeAd? _myLoadedNativeAd;
  bool _isLoaded = false;

  void _loadNativeAd() async {

    await NativeAdService.loadInChatNativeAd(
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isLoaded) {
      _loadNativeAd();
    }
  }

  @override
  void dispose() {
    _myLoadedNativeAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if  (!MaskService.isMonitored(widget.address) ||  !_isLoaded || _myLoadedNativeAd == null) return const SizedBox.shrink();

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8, left: 12, right: 50),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        
        ),
        decoration: BoxDecoration(
          // Mimic the "Received Message" style from your code
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(10),
            topRight: Radius.circular(10),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(20),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The actual Ad
            SizedBox(
              height: 100, 
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),),
                child: AdWidget(ad: _myLoadedNativeAd!)
                ),
            ),
            // "Sponsored" label where the time usually goes
            Padding(
              padding: const EdgeInsets.only(left: 14, bottom: 8, top: 4),
              child: Text(
                "Sponsored",
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 10,
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}