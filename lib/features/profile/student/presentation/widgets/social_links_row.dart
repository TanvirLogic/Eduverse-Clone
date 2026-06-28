import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/entities/user_profile_entity.dart';

/// Displays a horizontally scrollable row of tappable social link icons.
///
/// Each icon opens the corresponding [SocialLink.url] in a browser.
/// Icons are sourced from `assets/images/social_icons/` (SVG only).
class SocialLinksRow extends StatelessWidget {
  final List<SocialLink> socialLinks;

  const SocialLinksRow({super.key, required this.socialLinks});

  static const String _basePath = 'assets/images/social_icons/';

  /// Maps a platform name to its SVG asset under [_basePath].
  static String _assetFor(String platform) {
    switch (platform.toLowerCase()) {
      case 'github':
        return '${_basePath}git.svg';
      case 'linkedin':
        return '${_basePath}lnd.svg';
      case 'twitter':
      case 'x':
        return '${_basePath}tt.svg';
      case 'youtube':
        return '${_basePath}yt.svg';
      case 'facebook':
        return '${_basePath}fb.svg';
      case 'instagram':
        return '${_basePath}ig.svg';
      case 'website':
        return '${_basePath}website.svg';
      default:
        return '${_basePath}website.svg';
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && uri.hasScheme && uri.hasAuthority) {
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {
        // Silently recover
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (socialLinks.isEmpty) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: socialLinks.asMap().entries.expand((entry) {
          final widgets = <Widget>[];
          if (entry.key > 0) widgets.add(const SizedBox(width: 12));
          widgets.add(
            GestureDetector(
              onTap: () => _launchUrl(entry.value.url),
              child: SizedBox(
                width: 40,
                height: 40,
                child: SvgPicture.asset(
                  _assetFor(entry.value.platform),
                  fit: BoxFit.scaleDown,
                ),
              ),
            ),
          );
          return widgets;
        }).toList(),
      ),
    );
  }
}
