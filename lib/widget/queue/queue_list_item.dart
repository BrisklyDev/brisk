import 'package:brisk/db/hive_util.dart';
import 'package:brisk/l10n/app_localizations.dart';
import 'package:brisk/model/download_queue.dart';
import 'package:brisk/provider/pluto_grid_util.dart';
import 'package:brisk/provider/theme_provider.dart';
import 'package:brisk/widget/base/delete_confirmation_dialog.dart';
import 'package:brisk/widget/queue/queue_details_window.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:brisk/provider/queue_provider.dart';

class QueueListItem extends StatelessWidget {
  QueueListItem({super.key, required this.queue});

  DownloadQueue queue;

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context).activeTheme;
    final loc = AppLocalizations.of(context)!;
    return Material(
      type: MaterialType.transparency,
      child: ListTile(
        hoverColor: theme.queuePageTheme.queueItemHoverColor,
        onTap: () => onQueueTap(context),
        leading: Padding(
          padding: EdgeInsets.only(left: 10),
          child: Icon(
            Icons.queue_rounded,
            color: theme.widgetTheme.iconColor,
          ),
        ),
        title: Text(
          queue.name == "Main" ? loc.mainQueue : queue.name,
          style: TextStyle(
            color: theme.queuePageTheme.queueItemTitleTextColor,
            fontWeight: theme.fontWeight,
          ),
        ),
        subtitle: Text(
          loc.downloadsInQueue(
            queue.downloadItemsIds == null ? 0 : queue.downloadItemsIds!.length,
          ),
          style: TextStyle(
            color: theme.queuePageTheme.queueItemTitleDetailsTextColor,
          ),
        ),
        trailing: SizedBox(
          width: 100,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              IconButton(
                icon: Icon(
                  Icons.more_vert_rounded,
                  color: theme.widgetTheme.iconColor,
                ),
                onPressed: () => onDetailsTap(context),
              ),
              queue.name == "Main"
                  ? SizedBox(width: 40)
                  : IconButton(
                      icon: Icon(Icons.delete, color: Colors.red),
                      onPressed: () => onDeleteTap(context),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  void onDeleteTap(BuildContext context) {
    final provider = Provider.of<QueueProvider>(context, listen: false);
    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (context) => DeleteConfirmationDialog(
        onConfirmPressed: () async => await provider.deleteQueue(queue),
        title:
            AppLocalizations.of(context)!.deleteQueueConfirmation(queue.name),
      ),
    );
  }

  void onQueueTap(BuildContext context) {
    final provider = Provider.of<QueueProvider>(context, listen: false);
    PlutoGridUtil.removeFilters();
    provider.setQueueTopMenu(false);
    provider.setDownloadQueueTopMenu(true);
    provider.setQueueTabSelected(false);
    provider.setSelectedQueue(queue.key);
  }

  void onDetailsTap(BuildContext context) {
    queue = HiveUtil.instance.downloadQueueBox.get(queue.key)!;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => QueueDetailsWindow(queue: queue),
    );
  }
}
