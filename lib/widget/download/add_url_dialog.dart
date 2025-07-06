import 'package:brisk/l10n/app_localizations.dart';
import 'package:brisk/provider/theme_provider.dart';
import 'package:brisk/util/download_addition_ui_util.dart';
import 'package:brisk/widget/base/outlined_text_field.dart';
import 'package:brisk/widget/base/rounded_outlined_button.dart';
import 'package:brisk/widget/base/scrollable_dialog.dart';
import 'package:brisk/widget/loader/file_info_loader.dart';
import 'package:clipboard/clipboard.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/material.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:provider/provider.dart';

class AddUrlDialog extends StatefulWidget {
  final bool updateDialog;
  final int? downloadId;
  final Map<String, String> headers;

  const AddUrlDialog({
    super.key,
    this.updateDialog = false,
    this.downloadId,
    this.headers = const {},
  });

  @override
  State<AddUrlDialog> createState() => _AddUrlDialogState();
}

class _AddUrlDialogState extends State<AddUrlDialog> {
  TextEditingController txtController = TextEditingController();
  bool showAdvancedOptions = false;
  bool saveHeadersForFutureRequests = false;
  Map<TextEditingController, TextEditingController> headerControllers = {
    TextEditingController(): TextEditingController(),
  };
  int minLines = 1;

  @override
  void dispose() {
    headerControllers.forEach((key, value) {
      key.dispose();
      value.dispose();
    });
    txtController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    if (DownloadAdditionUiUtil.savedHeaderControllers.isNotEmpty) {
      headerControllers = DownloadAdditionUiUtil.savedHeaderControllers;
    }
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final theme =
        Provider.of<ThemeProvider>(context).activeTheme.alertDialogTheme;
    final loc = AppLocalizations.of(context)!;
    return LoaderOverlay(
      overlayWidgetBuilder: (progress) => FileInfoLoader(
        onCancelPressed: () => DownloadAdditionUiUtil.cancelRequest(context),
      ),
      child: ScrollableDialog(
        backgroundColor: theme.backgroundColor,
        width: 450,
        height: resolveHeight(),
        scrollviewHeight: resolveHeight() - 50,
        scrollButtonVisible: false,
        title: Padding(
          padding: const EdgeInsets.all(15.0),
          child: Text(
            widget.updateDialog
                ? loc.updateDownloadUrl
                : loc.add_a_download_url,
            style: TextStyle(color: theme.textColor),
          ),
        ),
        content: Padding(
          padding: const EdgeInsets.all(15.0),
          child: SizedBox(
            height: resolveHeight() - 30,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 100,
                  child: Row(
                    children: [
                      SizedBox(
                        width: 420,
                        child: OutLinedTextField(
                          controller: txtController,
                          onChanged: _handleTextFieldExpansion,
                          hintText: widget.updateDialog
                              ? "https://..."
                              : "https://... supports multiple URLs separated by newline",
                          maxLines: widget.updateDialog ? 1 : null,
                          // Allow multiple lines
                          minLines: minLines,
                          suffixIcon: IconButton(
                            onPressed: () async {
                              String url = await FlutterClipboard.paste();
                              setState(() => txtController.text = url);
                            },
                            icon: Icon(
                              Icons.paste_rounded,
                              color: Colors.white60,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 5),
                RoundedOutlinedButton(
                  onPressed: () {
                    setState(() {
                      showAdvancedOptions = !showAdvancedOptions;
                    });
                  },
                  backgroundColor: theme.itemContainerBackgroundColor,
                  borderColor: Colors.transparent,
                  textColor: Colors.white,
                  text: showAdvancedOptions
                      ? loc.btn_hideAdvancedOptions
                      : loc.btn_showAdvancedOptions,
                  icon: Icon(
                    showAdvancedOptions
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 10),
                Visibility(
                  visible: showAdvancedOptions,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Headers",
                        style: TextStyle(color: theme.textColor),
                      ),
                      const SizedBox(height: 5),
                      SizedBox(
                        height: 100,
                        width: 450,
                        child: ListView(
                          children: headerControllers.keys
                              .map(headerTextField)
                              .toList(),
                        ),
                      ),
                      Container(
                        width: 30,
                        height: 30,
                        padding: EdgeInsets.zero,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: Colors.green,
                        ),
                        child: IconButton(
                            padding: EdgeInsets.zero,
                            color: Colors.white,
                            onPressed: () => setState(
                                  () => headerControllers.addAll({
                                    TextEditingController():
                                        TextEditingController(),
                                  }),
                                ),
                            icon: Icon(Icons.add_rounded)),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Checkbox(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(2.0),
                            ),
                            side: WidgetStateBorderSide.resolveWith(
                              (states) =>
                                  BorderSide(width: 1.0, color: Colors.grey),
                            ),
                            activeColor: Colors.blueGrey,
                            value: saveHeadersForFutureRequests,
                            onChanged: (val) {
                              setState(
                                () => saveHeadersForFutureRequests = val!,
                              );
                            },
                          ),
                          Text(
                            "Save headers for future requests",
                            style:
                                TextStyle(fontSize: 14, color: Colors.white70),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        buttons: [
          RoundedOutlinedButton.fromButtonColor(
            theme.cancelButtonColor,
            text: loc.btn_cancel,
            onPressed: () => _onCancelPressed(context),
          ),
          const SizedBox(width: 10),
          RoundedOutlinedButton.fromButtonColor(
            theme.addButtonColor,
            text: widget.updateDialog ? loc.btn_updateUrl : loc.btn_addUrl,
            onPressed: () => _onAddPressed(context),
          ),
        ],
      ),
    );
  }

  void _handleTextFieldExpansion(String value) {
    print(widget.updateDialog);
    if (widget.updateDialog) return;
    if (value.contains("\n")) {
      setState(() => minLines = 3);
    } else {
      setState(() => minLines = 1);
    }
  }

  Widget headerTextField(TextEditingController keyController) {
    final valueController = headerControllers[keyController]!;
    return SizedBox(
      height: 45,
      child: Padding(
        padding: const EdgeInsets.only(top: 10.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              flex: 2,
              child: OutLinedTextField(
                contentPadding: EdgeInsets.only(left: 10),
                controller: keyController,
                hintText: "Header Name",
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 3,
              child: OutLinedTextField(
                contentPadding: EdgeInsets.only(left: 10),
                controller: valueController,
                hintText: "Header Value",
              ),
            ),
            const SizedBox(width: 10),
            IconButton(
              splashRadius: 20,
              onPressed: () {
                setState(
                  () => headerControllers.remove(keyController),
                );
              },
              icon: Icon(
                Icons.delete_rounded,
                color: Colors.red,
              ),
            ),
          ],
        ),
      ),
    );
  }

  double resolveHeight() {
    if (showAdvancedOptions) return 375;
    return 180;
  }

  void _onCancelPressed(BuildContext context) {
    txtController.text = '';
    Navigator.of(context).pop();
  }

  void _onAddPressed(BuildContext context) {
    final url = txtController.text;
    Map<String, String> headers = headerControllers.map(
      (keyController, valueController) => MapEntry(
        keyController.text,
        valueController.text,
      ),
    );
    headers.removeWhere((key, value) => key.isBlank || value.isBlank);
    if (saveHeadersForFutureRequests) {
      DownloadAdditionUiUtil.savedHeaderControllers = headerControllers;
    }
    DownloadAdditionUiUtil.handleDownloadAddition(
      context,
      url,
      updateDialog: widget.updateDialog,
      downloadId: widget.downloadId,
      additionalPop: true,
      headers: headers,
    );
  }
}
