import 'package:brisk/l10n/app_localizations.dart';
import 'package:brisk/provider/theme_provider.dart';
import 'package:brisk/util/github_star_handler.dart';
import 'package:brisk/widget/base/rounded_outlined_button.dart';
import 'package:brisk/widget/base/scrollable_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher_string.dart';

class GithubStarDialog extends StatelessWidget {
  const GithubStarDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context).activeTheme;
    final loc = AppLocalizations.of(context)!;
    return ScrollableDialog(
      width: 450,
      height: 130,
      scrollviewHeight: 200,
      backgroundColor: theme.alertDialogTheme.backgroundColor,
      scrollButtonVisible: false,
      title: Padding(
        padding: const EdgeInsets.all(15),
        child: Row(
          children: [
            SvgPicture.asset(
              "assets/icons/github.svg",
              height: 35,
              width: 35,
              colorFilter: ColorFilter.mode(
                Colors.white60,
                BlendMode.srcIn,
              ),
            ),
            SizedBox(width: 10),
            Text(
              "Enjoying Brisk?",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const Spacer(),
            IconButton(
              onPressed: () {
                GitHubStarHandler.timer?.cancel();
                GitHubStarHandler.timer = null;
                Navigator.of(context).pop();
                GitHubStarHandler.setNeverShowAgain();
              },
              splashRadius: 20,
              icon: Icon(
                Icons.close_rounded,
                color: Colors.white60,
              ),
            )
          ],
        ),
      ),
      content: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "If you enjoy the project, giving it a star on GitHub helps it grow and encourages continued development.",
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 10),
            Text(
              "Brisk is, and always will be, completely free and open source",
              style: TextStyle(color: Colors.white54),
            )
          ],
        ),
      ),
      buttons: [
        // RoundedOutlinedButton.fromButtonColor(
        //   theme.alertDialogTheme.declineButtonColor,
        //   onPressed: () {
        //     GitHubStarHandler.setNeverShowAgain();
        //     Navigator.of(context).pop();
        //   },
        //   text: "Never show again",
        // ),
        const SizedBox(width: 10),
        RoundedOutlinedButton.fromButtonColor(
          theme.alertDialogTheme.acceptButtonColor,
          onPressed: () =>
              launchUrlString("https://github.com/BrisklyDev/brisk"),
          text: "Take me there",
        ),
      ],
    );
  }
}
