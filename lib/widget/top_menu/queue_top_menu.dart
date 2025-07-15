import 'package:brisk/l10n/app_localizations.dart';
import 'package:brisk/provider/theme_provider.dart';
import 'package:brisk/util/ui_util.dart';
import 'package:brisk/widget/queue/create_queue_window.dart';
import 'package:brisk/widget/top_menu/top_menu_button.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../provider/download_request_provider.dart';

class QueueTopMenu extends StatelessWidget {
  late DownloadRequestProvider provider;

  @override
  Widget build(BuildContext context) {
    provider = Provider.of<DownloadRequestProvider>(context, listen: false);
    final topMenuTheme =
        Provider.of<ThemeProvider>(context).activeTheme.topMenuTheme;
    final loc = AppLocalizations.of(context)!;
    final size = MediaQuery.of(context).size;
    return Container(
      width: resolveWindowWidth(size),
      height: topMenuHeight,
      color: topMenuTheme.backgroundColor,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 20),
            child: TopMenuButton(
              onTap: () => onCreateQueuePressed(context),
              title: loc.btn_createQueue,
              fontSize: 14,
              icon: Icon(
                size: 28,
                Icons.add_rounded,
                color: topMenuTheme.createQueueColor.iconColor,
              ),
              onHoverColor: topMenuTheme.createQueueColor.hoverBackgroundColor,
              isEnabled: true,
            ),
          ),
        ],
      ),
    );
  }

  void onCreateQueuePressed(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => CreateQueueWindow(),
    );
  }
}
