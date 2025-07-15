import 'package:brisk/l10n/app_localizations.dart';
import 'package:brisk/model/download_queue.dart';
import 'package:brisk/provider/queue_provider.dart';
import 'package:brisk/provider/theme_provider.dart';
import 'package:brisk/theme/application_theme.dart';
import 'package:brisk/util/date_util.dart';
import 'package:brisk/widget/base/outlined_text_field.dart';
import 'package:brisk/widget/base/rounded_outlined_button.dart';
import 'package:brisk/widget/base/scrollable_dialog.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/material.dart';
import 'package:number_inc_dec/number_inc_dec.dart';
import 'package:omni_datetime_picker/omni_datetime_picker.dart';
import 'package:provider/provider.dart';

class ScheduleDialog extends StatefulWidget {
  final DownloadQueue queue;
  final void Function({
    required bool shutdownAfterCompletion,
    required int simultaneousDownloads,
    DateTime? scheduledStart,
    DateTime? scheduledEnd,
  }) onAcceptClicked;

  ScheduleDialog({
    super.key,
    required this.queue,
    required this.onAcceptClicked,
  });

  @override
  State<ScheduleDialog> createState() => _ScheduleDialogState();
}

class _ScheduleDialogState extends State<ScheduleDialog> {
  late TextEditingController startDateController;
  late TextEditingController endDateController;
  late TextEditingController simultaneousDownloadController;
  late int selectedQueueId;
  late ApplicationTheme theme;
  bool startDateEnabled = false;
  bool endDateEnabled = false;
  bool shutdownEnabled = false;
  DateTime? startDate;
  DateTime? endDate;

  final FocusNode _startDateFocusNode = FocusNode();
  final FocusNode _endDateFocusNode = FocusNode();

  @override
  void dispose() {
    startDateController.dispose();
    endDateController.dispose();
    simultaneousDownloadController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    startDateController = TextEditingController(
      text: formatDate(widget.queue.scheduledStart),
    );
    endDateController = TextEditingController(
      text: formatDate(widget.queue.scheduledEnd),
    );
    if (widget.queue.scheduledStart != null) {
      startDateEnabled = true;
    }
    if (widget.queue.scheduledEnd != null) {
      endDateEnabled = true;
    }
    simultaneousDownloadController = TextEditingController(
      text: widget.queue.simultaneousDownloads.toString(),
    );
    shutdownEnabled = widget.queue.shutdownAfterCompletion;
    _startDateFocusNode.addListener(
      () => _showDateTimePicker(
        _startDateFocusNode,
        startDateController,
        true,
      ),
    );
    _endDateFocusNode.addListener(
      () => _showDateTimePicker(
        _endDateFocusNode,
        endDateController,
        false,
      ),
    );
  }

  Future<void> _showDateTimePicker(
    FocusNode focusNode,
    TextEditingController controller,
    bool isStartDate,
  ) async {
    if (focusNode.hasFocus) {
      final dateTime = await showOmniDateTimePicker(
        context: context,
        is24HourMode: true,
        constraints: BoxConstraints(maxWidth: 400, maxHeight: 580),
        type: OmniDateTimePickerType.dateAndTime,
      );
      if (dateTime != null) {
        setState(() => controller.text = formatDate(dateTime)!);
      }
      if (isStartDate) {
        startDate = dateTime;
      } else {
        endDate = dateTime;
      }
      focusNode.unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    theme = Provider.of<ThemeProvider>(context, listen: false).activeTheme;
    selectedQueueId =
        Provider.of<QueueProvider>(context, listen: false).selectedQueueId!;
    final size = MediaQuery.of(context).size;
    final loc = AppLocalizations.of(context)!;
    return ScrollableDialog(
      title: Padding(
        padding: const EdgeInsets.all(15),
        child: Text(
          loc.scheduleDownload,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: theme.textColor,
          ),
        ),
      ),
      height: 400,
      scrollviewHeight: 300,
      backgroundColor: theme.alertDialogTheme.backgroundColor,
      borderRadius: 10,
      width: 400,
      content: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDateRow(
              label: loc.startDownloadAt,
              enabled: startDateEnabled,
              controller: startDateController,
              focusNode: _startDateFocusNode,
              onChanged: (value) => setState(() => startDateEnabled = value!),
            ),
            SizedBox(height: 20),
            _buildDateRow(
              label: loc.stopDownloadAt,
              enabled: endDateEnabled,
              controller: endDateController,
              focusNode: _endDateFocusNode,
              onChanged: (value) => setState(() => endDateEnabled = value!),
            ),
            SizedBox(height: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loc.simultaneousDownloads,
                  style: TextStyle(color: theme.textColor),
                ),
                const SizedBox(height: 5),
                SizedBox(
                  width: 100,
                  child: NumberInputWithIncrementDecrement(
                    initialValue: 1,
                    style: TextStyle(color: theme.textColor),
                    decIconColor: theme.widgetTheme.iconColor,
                    incDecBgColor: theme.widgetTheme.iconColor,
                    incIconColor: theme.widgetTheme.iconColor,
                    widgetContainerDecoration: BoxDecoration(),
                    controller: simultaneousDownloadController,
                    min: 1,
                  ),
                )
              ],
            ),
            SizedBox(height: 20),
            Row(
              children: [
                Checkbox(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(2.0),
                  ),
                  side: WidgetStateBorderSide.resolveWith(
                    (states) => BorderSide(width: 1.0, color: Colors.grey),
                  ),
                  activeColor: Colors.blueGrey,
                  value: shutdownEnabled,
                  onChanged: (value) =>
                      setState(() => shutdownEnabled = value!),
                ),
                Text(
                  loc.shutdownAfterCompletion,
                  style: TextStyle(color: theme.textColor),
                )
              ],
            ),
          ],
        ),
      ),
      buttons: [
        RoundedOutlinedButton.fromButtonColor(
          theme.alertDialogTheme.declineButtonColor,
          text: loc.btn_cancel,
          onPressed: () => Navigator.of(context).pop(),
        ),
        const SizedBox(width: 10),
        RoundedOutlinedButton.fromButtonColor(
          theme.alertDialogTheme.acceptButtonColor,
          text: startDateEnabled ? loc.btn_schedule : loc.btn_startNow,
          onPressed: () {
            widget.onAcceptClicked(
              shutdownAfterCompletion: shutdownEnabled,
              simultaneousDownloads:
                  simultaneousDownloadController.text.toInt(),
              scheduledStart: startDateEnabled ? startDate : null,
              scheduledEnd: endDateEnabled ? endDate : null,
            );
            Navigator.of(context).pop();
          },
        )
      ],
      scrollButtonVisible: size.height < 550,
    );
  }

  Widget _buildDateRow({
    required String label,
    required bool enabled,
    required TextEditingController controller,
    required FocusNode focusNode,
    required ValueChanged<bool?> onChanged,
  }) {
    return Column(
      children: [
        Row(
          children: [
            Checkbox(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(2.0),
                ),
                side: WidgetStateBorderSide.resolveWith(
                  (states) => BorderSide(width: 1.0, color: Colors.grey),
                ),
                activeColor: Colors.blueGrey,
                value: enabled,
                onChanged: onChanged),
            Text(
              label,
              style: TextStyle(color: theme.textColor),
            ),
          ],
        ),
        SizedBox(height: 5),
        SizedBox(
          width: 450,
          height: 50,
          child: OutLinedTextField(
            hintText: "YYYY-MM-DD --:--",
            enabled: enabled,
            controller: controller,
            focusNode: focusNode,
          ),
        ),
      ],
    );
  }
}
