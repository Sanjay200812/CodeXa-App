import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Secure CodeXa In-App Browser handler for external links (YouTube, Instagram, Docs, Web)
class CxBrowser {
  static Future<bool> open(BuildContext context, String url) async {
    final cleanUrl = url.trim();
    if (cleanUrl.isEmpty) return false;

    final uri = Uri.tryParse(cleanUrl);
    if (uri == null || (!uri.isScheme('http') && !uri.isScheme('https'))) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Invalid link URL')));
      return false;
    }

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.inAppBrowserView,
        browserConfiguration: const BrowserConfiguration(showTitle: true),
      );
      if (launched) return true;
    } catch (_) {}

    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open link in browser')),
        );
      }
      return false;
    }
  }
}
