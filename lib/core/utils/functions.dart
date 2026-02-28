  import 'package:url_launcher/url_launcher.dart';

Future<void> openPlayStore() async {
  const String appId = "com.brimukon.messaging";
  final Uri marketUri = Uri.parse("market://details?id=$appId");
  final Uri webUri = Uri.parse("https://play.google.com/store/apps/details?id=$appId");

  try {
    if (await canLaunchUrl(marketUri)) {
      await launchUrl(marketUri);
    } else {
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
    }
  } catch (e) {
    await launchUrl(webUri);
  }
}