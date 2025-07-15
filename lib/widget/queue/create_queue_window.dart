import 'package:brisk/db/hive_util.dart';
import 'package:brisk/l10n/app_localizations.dart';
import 'package:brisk/provider/queue_provider.dart';
import 'package:brisk/provider/theme_provider.dart';
import 'package:brisk/widget/base/closable_window.dart';
import 'package:brisk/widget/base/error_dialog.dart';
import 'package:brisk/widget/base/outlined_text_field.dart';
import 'package:brisk/widget/base/rounded_outlined_button.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../model/download_queue.dart';

class CreateQueueWindow extends StatefulWidget {
  const CreateQueueWindow({Key? key}) : super(key: key);

  @override
  State<CreateQueueWindow> createState() => _CreateQueueWindowState();
}

class _CreateQueueWindowState extends State<CreateQueueWindow> {
  TextEditingController txtController = TextEditingController();

  @override
  void dispose() {
    txtController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme =
        Provider.of<ThemeProvider>(context).activeTheme.alertDialogTheme;
    return AlertDialog(
      backgroundColor: theme.backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      title: Text(
        loc.createNewQueue,
        style: TextStyle(
            color: theme.textColor, fontWeight: FontWeight.bold, fontSize: 20),
      ),
      content: SizedBox(
        width: 400,
        height: 90,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Text(loc.queueName),
            const SizedBox(height: 10),
            SizedBox(
              width: 400,
              child: OutLinedTextField(controller: txtController),
            ),
          ],
        ),
      ),
      actions: [
        RoundedOutlinedButton.fromButtonColor(
          theme.declineButtonColor,
          text: loc.btn_cancel,
          onPressed: () => Navigator.of(context).pop(),
        ),
        RoundedOutlinedButton.fromButtonColor(
          theme.acceptButtonColor,
          text: loc.btn_createQueue,
          onPressed: () => onCreatePressed(context),
        ),
      ],
    );
  }

  void onCreatePressed(BuildContext context) async {
    final provider = Provider.of<QueueProvider>(context, listen: false);
    final box = HiveUtil.instance.downloadQueueBox;
    final duplicateQueueName = box.values
        .where((queue) => queue.name == txtController.value.text)
        .isNotEmpty;
    if (duplicateQueueName) {
      showDialog(
        context: context,
        builder: (context) => ErrorDialog(
          title: "Queue with this name already exists!",
          height: 50,
          width: 450,
        ),
      );
    } else {
      final queue = DownloadQueue(name: txtController.value.text);
      await provider.saveQueue(queue);
      Navigator.of(context).pop();
    }
  }
}
