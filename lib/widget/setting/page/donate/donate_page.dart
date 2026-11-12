import 'package:brisk/constants/donation_links.dart';
import 'package:brisk/l10n/app_localizations.dart';
import 'package:brisk/provider/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:brisk/util/url_launcher_util.dart';

/// Settings tab with the donation options. Colors are tints of fixed brand colors over the
/// theme's group background, so the page looks right in every theme.
class DonatePage extends StatelessWidget {
  const DonatePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context).activeTheme;
    final textColor = theme.settingTheme.pageTheme.titleTextColor;
    final size = MediaQuery.of(context).size;
    return SingleChildScrollView(
      // No settings group around the card: the card is the page's only container.
      // Same width as the settings groups on the other pages.
      child: SizedBox(
        width: size.width < 809 ? size.width * 0.85 : 650,
        child: _Header(
          textColor: textColor,
          child: Row(
            children: [
              Expanded(
                child: _DonationOption(
                  name: 'Buy Me a Coffee',
                  link: 'buymeacoffee.com/aminbhst',
                  url: buyMeACoffeeUrl,
                  background: buyMeACoffeeColor,
                  hoverBackground: const Color.fromRGBO(240, 207, 0, 1),
                  foreground: Colors.black,
                  borderColor: const Color.fromRGBO(230, 199, 0, 1),
                  icon: const Icon(
                    Icons.coffee_rounded,
                    size: 22,
                    color: Colors.black,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _DonationOption(
                  name: 'GitHub Sponsors',
                  link: 'github.com/sponsors/AminBhst',
                  url: githubSponsorsUrl,
                  // GitHub's dark button colors
                  background: const Color(0xFF24292F),
                  hoverBackground: const Color(0xFF32383F),
                  foreground: Colors.white,
                  borderColor: const Color(0xFF3D444D),
                  icon: SvgPicture.asset(
                    'assets/icons/github.svg',
                    width: 22,
                    height: 22,
                    colorFilter: const ColorFilter.mode(
                      Colors.white,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final Color textColor;

  /// Shown below the title, inside the card.
  final Widget child;

  const _Header({required this.textColor, required this.child});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            donationAccentColor.withValues(alpha: 0.22),
            donationAccentColor.withValues(alpha: 0.04),
          ],
        ),
        border: Border.all(
          color: donationAccentColor.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: donationAccentColor.withValues(alpha: 0.2),
                ),
                child: const Icon(
                  Icons.favorite_rounded,
                  color: donationAccentColor,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loc.donationPrompt_title,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      loc.donationPrompt_description,
                      style: TextStyle(
                        color: textColor.withValues(alpha: 0.85),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

/// A clickable card for one donation platform, filled with the platform's brand color like
/// its official buttons. Solid brand colors don't depend on the theme, so the cards look the
/// same in every theme.
class _DonationOption extends StatefulWidget {
  final String name;
  final String link;
  final String url;
  final Widget icon;
  final Color background;
  final Color hoverBackground;
  final Color foreground;
  final Color borderColor;

  const _DonationOption({
    required this.name,
    required this.link,
    required this.url,
    required this.icon,
    required this.background,
    required this.hoverBackground,
    required this.foreground,
    required this.borderColor,
  });

  @override
  State<_DonationOption> createState() => _DonationOptionState();
}

class _DonationOptionState extends State<_DonationOption> {
  bool hovered = false;

  @override
  Widget build(BuildContext context) {
    final foreground = widget.foreground;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => openUrl(widget.url),
        onHover: (value) => setState(() => hovered = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: hovered ? widget.hoverBackground : widget.background,
            border: Border.all(color: widget.borderColor, width: 1.2),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: foreground.withValues(alpha: 0.12),
                ),
                child: widget.icon,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.name,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: foreground,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.link,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: foreground.withValues(alpha: 0.7),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.open_in_new_rounded,
                size: 18,
                color: foreground.withValues(alpha: hovered ? 1 : 0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
