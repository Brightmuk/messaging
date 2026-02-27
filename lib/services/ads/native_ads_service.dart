import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:messaging/core/user_defaults.dart';

class NativeAdService {

   static Future<NativeAd?> loadChatsNativeAd(BuildContext context, {required Function(NativeAd) onAdLoaded}) async{
    final theme = Theme.of(context);
    if(await UserDefaults.getAdsRemoved()) return null;
    return NativeAd(
      adUnitId: kDebugMode
          ? 'ca-app-pub-3940256099942544/2247696110'
          : "ca-app-pub-4276933186583420/6191538941",
      listener: NativeAdListener(
        onAdLoaded: (ad) => onAdLoaded(ad as NativeAd),
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          print('Ad failed to load: $error');
        },
      ),
      request: const AdRequest(),
      nativeTemplateStyle: NativeTemplateStyle(
       
        templateType: TemplateType.small,
        mainBackgroundColor: theme.cardColor,
        cornerRadius: 20.0,
        callToActionTextStyle: NativeTemplateTextStyle(
          textColor: theme.colorScheme.onPrimary,
          backgroundColor: theme.colorScheme.primary,
          style: NativeTemplateFontStyle.bold,
          size: 16.0,
        ),
        primaryTextStyle: NativeTemplateTextStyle(
          textColor: theme.textTheme.bodyMedium!.color,
          style: NativeTemplateFontStyle.normal,
          size: 16.0,
        ),
        secondaryTextStyle: NativeTemplateTextStyle(
          textColor: theme.textTheme.bodySmall!.color,
          style: NativeTemplateFontStyle.normal,
          size: 14.0,
        ),
        tertiaryTextStyle: NativeTemplateTextStyle(
          textColor: theme.textTheme.bodySmall!.color,
          style: NativeTemplateFontStyle.normal,
          size: 14.0,
        ),
      ),
    )..load();
  }
    static Future<NativeAd?> loadInChatNativeAd(BuildContext context, {required Function(NativeAd) onAdLoaded}) async{
    final theme = Theme.of(context);
    if(await UserDefaults.getAdsRemoved()) return null;
    return NativeAd(
      adUnitId: kDebugMode
          ? 'ca-app-pub-3940256099942544/2247696110'
          : "ca-app-pub-4276933186583420/9810664843",
      listener: NativeAdListener(
        onAdLoaded: (ad) => onAdLoaded(ad as NativeAd),
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          print('Ad failed to load: $error');
        },
      ),
      request: const AdRequest(),
      nativeTemplateStyle: NativeTemplateStyle(
       
        templateType: TemplateType.small,
        mainBackgroundColor: theme.cardColor,
        cornerRadius: 20.0,
        callToActionTextStyle: NativeTemplateTextStyle(
          textColor: theme.colorScheme.onPrimary,
          backgroundColor: theme.colorScheme.primary,
          style: NativeTemplateFontStyle.bold,
          size: 16.0,
        ),
        primaryTextStyle: NativeTemplateTextStyle(
          textColor: theme.textTheme.bodyMedium!.color,
          style: NativeTemplateFontStyle.normal,
          size: 16.0,
        ),
        secondaryTextStyle: NativeTemplateTextStyle(
          textColor: theme.textTheme.bodySmall!.color,
          style: NativeTemplateFontStyle.normal,
          size: 14.0,
        ),
        tertiaryTextStyle: NativeTemplateTextStyle(
          textColor: theme.textTheme.bodySmall!.color,
          style: NativeTemplateFontStyle.normal,
          size: 14.0,
        ),
      ),
    )..load();
  }
}
