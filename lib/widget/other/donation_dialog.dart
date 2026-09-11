import 'package:brisk/l10n/app_localizations.dart';
import 'package:brisk/provider/theme_provider.dart';
import 'package:brisk/widget/base/rounded_outlined_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher_string.dart';

enum DonationDialogAction {
  remindLater,
  neverShowAgain,
}

class DonationDialog extends StatefulWidget {
  const DonationDialog({super.key});

  @override
  State<DonationDialog> createState() => _DonationDialogState();
}

class _DonationDialogState extends State<DonationDialog> {
  static const _buyMeACoffeeUrl = 'https://buymeacoffee.com/aminbhst';
  static const _githubSponsorsUrl = 'https://github.com/sponsors/AminBhst';

  bool neverShowAgain = false;

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>().activeTheme;
    final loc = AppLocalizations.of(context)!;
    return AlertDialog(
      backgroundColor: theme.alertDialogTheme.backgroundColor,
      title: Text(
        loc.donationPrompt_title,
        style: TextStyle(color: theme.textColor),
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              loc.donationPrompt_description,
              style: TextStyle(color: theme.textColor),
            ),
            const SizedBox(height: 20),
            RoundedOutlinedButton(
              width: double.infinity,
              height: 40,
              text: 'Buy Me a Coffee',
              backgroundColor: const Color.fromRGBO(255, 221, 0, 1),
              textColor: Colors.black,
              hoverBackgroundColor: const Color.fromRGBO(230, 199, 0, 1),
              hoverTextColor: Colors.black,
              customIcon: Icon(
                Icons.coffee_rounded,
                size: 20,
                color: Colors.black,
              ),
              onPressed: () => launchUrlString(_buyMeACoffeeUrl),
            ),
            const SizedBox(height: 10),
            RoundedOutlinedButton.fromButtonColor(
              theme.alertDialogTheme.secondaryMiscButtonColor,
              width: double.infinity,
              height: 40,
              text: 'GitHub Sponsors',
              customIcon: SvgPicture.asset(
                'assets/icons/github.svg',
                width: 20,
                height: 20,
                colorFilter: ColorFilter.mode(
                  theme.alertDialogTheme.secondaryMiscButtonColor.textColor,
                  BlendMode.srcIn,
                ),
              ),
              onPressed: () => launchUrlString(_githubSponsorsUrl),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () => setState(() => neverShowAgain = !neverShowAgain),
              child: Row(
                children: [
                  Checkbox(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(2),
                    ),
                    side: WidgetStateBorderSide.resolveWith(
                      (_) => BorderSide(
                        color: theme.alertDialogTheme.checkBoxColor.borderColor,
                      ),
                    ),
                    activeColor:
                        theme.alertDialogTheme.checkBoxColor.activeColor,
                    value: neverShowAgain,
                    onChanged: (value) => setState(
                      () => neverShowAgain = value ?? false,
                    ),
                  ),
                  Text(
                    loc.donationPrompt_neverShowAgain,
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.textColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        RoundedOutlinedButton.fromButtonColor(
          theme.alertDialogTheme.cancelColor,
          text: loc.btn_cancel,
          onPressed: () => Navigator.pop(
            context,
            neverShowAgain
                ? DonationDialogAction.neverShowAgain
                : DonationDialogAction.remindLater,
          ),
        ),
      ],
    );
  }
}
