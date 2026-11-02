import 'package:url_launcher/url_launcher.dart';

import 'link_opener.dart';

/// [LinkOpener] using the phone's browser.
class BrowserLinkOpener implements LinkOpener {
  @override
  Future<bool> open(Uri url) async {
    try {
      return await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}
