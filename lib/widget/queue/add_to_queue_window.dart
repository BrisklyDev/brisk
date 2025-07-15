import 'package:brisk/db/hive_util.dart';
import 'package:brisk/l10n/app_localizations.dart';
import 'package:brisk/provider/pluto_grid_util.dart';
import 'package:brisk/provider/theme_provider.dart';
import 'package:brisk/widget/base/closable_window.dart';
import 'package:brisk/widget/base/rounded_outlined_button.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../model/download_queue.dart';

class AddToQueueWindow extends StatefulWidget {
  const AddToQueueWindow({Key? key}) : super(key: key);

  @override
  State<AddToQueueWindow> createState() => _AddToQueueWindowState();
}

class _AddToQueueWindowState extends State<AddToQueueWindow> {
  List<DownloadQueue>? downloadQueues = [];
  String? selectedValue;

  @override
  Widget build(BuildContext context) {
    setDownloadQueues();
    final theme = Provider.of<ThemeProvider>(context).activeTheme;
    final loc = AppLocalizations.of(context)!;
    return AlertDialog(
      backgroundColor: theme.alertDialogTheme.backgroundColor,
      title: Text(
        loc.addDownloadToQueue,
        style: TextStyle(
            color: theme.textColor, fontWeight: FontWeight.bold, fontSize: 20),
      ),
      content: SizedBox(
        width: 400,
        height: 90,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(loc.selectQueue),
            const SizedBox(height: 10),
            SizedBox(
              width: 400,
              child: DropdownButton<String>(
                value: selectedValue,
                menuMaxHeight: 200,
                menuWidth: 400,
                iconEnabledColor: theme.widgetTheme.dropDownColor.iconColor,
                dropdownColor:
                    theme.widgetTheme.dropDownColor.dropDownBackgroundColor,
                items: downloadQueues?.map((DownloadQueue value) {
                  return DropdownMenuItem<String>(
                    value: value.name,
                    child: SizedBox(
                      width: 376,
                      child: Text(
                        value.name,
                        style: TextStyle(
                          color: theme.widgetTheme.dropDownColor.itemTextColor,
                        ),
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (value) => setState(() => selectedValue = value),
              ),
            ),
          ],
        ),
      ),
      actions: [
        RoundedOutlinedButton.fromButtonColor(
          theme.alertDialogTheme.declineButtonColor,
          text: loc.btn_cancel,
          onPressed: () => Navigator.of(context).pop(),
        ),
        RoundedOutlinedButton.fromButtonColor(
          theme.alertDialogTheme.acceptButtonColor,
          text: loc.btn_addToQueue,
          onPressed: onAddPressed,
        ),
      ],
    );
  }

  void onAddPressed() async {
    final selectedQueue =
        downloadQueues?.where((queue) => queue.name == selectedValue).first;
    final selectedRows = PlutoGridUtil.plutoStateManager?.checkedRows;
    if (selectedQueue == null || selectedRows == null) return;
    final queue = HiveUtil.instance.downloadQueueBox.get(selectedQueue.key)!;
    for (var row in selectedRows) {
      final id = row.cells["id"]!.value;
      queue.downloadItemsIds ??= [];
      if (queue.downloadItemsIds!.any((item) => item == id)) continue;
      queue.downloadItemsIds = [...queue.downloadItemsIds!];
      queue.downloadItemsIds!.add(id);
      HiveUtil.instance.downloadQueueBox.put(queue.key, queue);
    }
    Navigator.of(context).pop();
  }

  void setDownloadQueues() {
    setState(() {
      downloadQueues = HiveUtil.instance.downloadQueueBox.values.toList();
    });
  }
}
