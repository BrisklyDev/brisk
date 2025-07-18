import 'package:brisk/l10n/app_localizations.dart';
import 'package:brisk/provider/theme_provider.dart';
import 'package:brisk/theme/application_theme.dart';
import 'package:brisk/widget/base/outlined_text_field.dart';
import 'package:brisk/widget/base/rounded_outlined_button.dart';
import 'package:brisk/widget/base/scrollable_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher_string.dart';

class BrowserExtensionInstallationGuideDialog extends StatefulWidget {
  final String browserName;
  final String? downloadUrl;

  BrowserExtensionInstallationGuideDialog({
    super.key,
    required this.browserName,
    this.downloadUrl,
  });

  @override
  State<BrowserExtensionInstallationGuideDialog> createState() =>
      _BrowserExtensionInstallationGuideDialogState();
}

class _BrowserExtensionInstallationGuideDialogState
    extends State<BrowserExtensionInstallationGuideDialog> {
  bool videoGuide = false;
  late ApplicationTheme theme;
  late final AppLocalizations loc;

  @override
  Widget build(BuildContext context) {
    theme = Provider.of<ThemeProvider>(context).activeTheme;
    loc = AppLocalizations.of(context)!;
    return ScrollableDialog(
      width: 600,
      height: 380,
      buttons: [],
      scrollviewHeight: 300,
      backgroundColor: theme.alertDialogTheme.backgroundColor,
      scrollButtonVisible: false,
      title: Padding(
        padding: const EdgeInsets.all(15),
        child: Row(
          children: [
            Text(
              loc.installBrowserExtensionGuide_title,
              style: TextStyle(
                color: theme.textColor,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            const Spacer(),
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              splashRadius: 20,
              icon: Icon(
                Icons.close_rounded,
                color: theme.widgetTheme.iconColor,
              ),
            )
          ],
        ),
      ),
      content: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.browserName == "brave") warningBrave(),
            const SizedBox(height: 5),
            installationStep(
              step: 1,
              title: loc.downloadExtension,
              subtitles: [
                Text(
                  step1Subtitle(loc),
                  style: installationStepDescriptionStyle,
                ),
                const SizedBox(height: 5),
                RoundedOutlinedButton(
                  height: 30,
                  onPressed: () => launchUrlString(
                    widget.downloadUrl ??
                        "https://github.com/BrisklyDev/brisk-browser-extension/releases/tag/v1.2.2",
                  ),
                  text: loc.downloadExtension,
                  hoverBackgroundColor: Colors.blueAccent,
                  backgroundColor: Color.fromRGBO(53, 89, 143, 1),
                  icon: Icons.download,
                ),
              ],
            ),
            installationStep(
              step: 2,
              title: loc.installBrowserExtension_step2_title,
              subtitles: [
                Text(
                  loc.installBrowserExtension_step2_subtitle,
                  style: installationStepDescriptionStyle,
                ),
              ],
            ),
            installationStep(
              step: 3,
              title: step3Title(loc),
              subtitles: [
                Text(
                  step3Subtitle(loc),
                  style: installationStepDescriptionStyle,
                ),
              ],
            ),
            installationStep(
              step: 4,
              title: step4Title(loc),
              subtitles: [
                Text(
                  step4Subtitle(loc),
                  style: installationStepDescriptionStyle,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  TextStyle get installationStepDescriptionStyle {
    return TextStyle(
      color: theme.textHintColor,
      fontSize: 15,
    );
  }

  String step4Title(AppLocalizations loc) {
    return loc.installBrowserExtension_step4_title;
  }

  String step4Subtitle(AppLocalizations loc) {
    return loc.installBrowserExtension_step4_subtitle;
  }

  String step3Title(AppLocalizations loc) {
    return loc.installBrowserExtension_step3_title;
  }

  String step3Subtitle(AppLocalizations loc) {
    if (widget.browserName.toLowerCase() == "chrome" ||
        widget.browserName.toLowerCase() == "brave") {
      return loc.installBrowserExtension_chrome_step3_subtitle;
    } else if (widget.browserName.toLowerCase() == "edge") {
      return loc.installBrowserExtension_edge_step3_subtitle;
    } else if (widget.browserName.toLowerCase() == "opera") {
      return loc.installBrowserExtension_opera_step3_subtitle;
    }
    return "";
  }

  String step1Subtitle(AppLocalizations loc) {
    if (widget.browserName.toLowerCase() == "chrome" ||
        widget.browserName.toLowerCase() == "brave") {
      return loc.installBrowserExtension_chrome_step1_subtitle;
    } else if (widget.browserName.toLowerCase() == "edge") {
      return loc.installBrowserExtension_edge_step1_subtitle;
    } else if (widget.browserName.toLowerCase() == "opera") {
      return loc.installBrowserExtension_opera_step1_subtitle;
    }
    return "";
  }

  Widget warningBrave() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 30,
          child: Icon(
            Icons.warning_rounded,
            color: Colors.yellow,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                loc.installBrowserExtension_brave_warning_title,
                style: TextStyle(
                  fontSize: 15,
                  color: theme.textColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                loc.installBrowserExtension_brave_warning_subtitle,
                style: installationStepDescriptionStyle,
              ),
              const SizedBox(height: 5),
              braveFingerprintModeAddressTextField(),
              const SizedBox(height: 5),
            ],
          ),
        ),
      ],
    );
  }

  OutLinedTextField braveFingerprintModeAddressTextField() {
    return OutLinedTextField(
      controller: TextEditingController(
        text: "brave://flags/#brave-show-strict-fingerprinting-mode",
      ),
      readOnly: true,
      suffixIcon: IconButton(
        onPressed: () async {
          Clipboard.setData(
            ClipboardData(
                text: "brave://flags/#brave-show-strict-fingerprinting-mode"),
          );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Color.fromRGBO(38, 38, 38, 1.0),
              content: Text(
                loc.copiedToClipboard,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white),
              ),
              duration: Duration(seconds: 1),
            ),
          );
        },
        icon: Icon(
          Icons.copy_rounded,
          color: Colors.white60,
        ),
      ),
    );
  }

  Widget installationStep({
    required int step,
    required String title,
    required List<Widget> subtitles,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 30,
          child: Center(child: stepCircle(step)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  color: theme.textColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 5),
              ...subtitles,
              const SizedBox(height: 20),
            ],
          ),
        ),
      ],
    );
  }

  Widget stepCircle(int number) {
    return SizedBox(
      width: 25,
      height: 25,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: Color.fromRGBO(53, 89, 143, 1),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            number.toString(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              height: 1, // helps center vertically
            ),
          ),
        ),
      ),
    );
  }
}
