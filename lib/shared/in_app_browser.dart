import "package:flutter/material.dart";
import "package:url_launcher/url_launcher.dart";
import "widgets.dart";

Future<void> openInAppBrowser(BuildContext context, String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null || !uri.hasScheme) {
    showMessage(context, "Invalid link");
    return;
  }

  final opened = await launchUrl(uri, mode: LaunchMode.inAppWebView);
  if (!opened) {
    final fallbackOpened =
        await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
    if (!fallbackOpened && context.mounted) {
      showMessage(context, "Unable to open link");
    }
  }
}
