import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';
import 'package:hotkey_manager/hotkey_manager.dart';

class RecordHotKeyDialog extends StatefulWidget {
  const RecordHotKeyDialog({
    super.key,
    required this.onHotKeyRecorded,
  });

  final ValueChanged<HotKey> onHotKeyRecorded;

  @override
  State<RecordHotKeyDialog> createState() => _RecordHotKeyDialogState();
}

class _RecordHotKeyDialogState extends State<RecordHotKeyDialog> {
  HotKey? _hotKey;

  void _handleSetAsInappWideChanged(bool newValue) {
    if (_hotKey == null) {
      BotToast.showText(text: 'Please record a hotkey first.');
      return;
    }
    _hotKey = HotKey(
      key: _hotKey!.key,
      modifiers: _hotKey?.modifiers,
      scope: newValue ? HotKeyScope.inapp : HotKeyScope.system,
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      content: SingleChildScrollView(
        child: ListBody(
          children: <Widget>[
            const Text('The `HotKeyRecorder` widget will record your hotkey.'),
            Container(
              width: 100,
              height: 60,
              margin: const EdgeInsets.only(top: 20),
              decoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(context).primaryColor,
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  HotKeyRecorder(
                    onHotKeyRecorded: (hotKey) {
                      _hotKey = hotKey;
                      setState(() {});
                    },
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () {
                _handleSetAsInappWideChanged(
                  _hotKey?.scope != HotKeyScope.inapp,
                );
              },
              child: Row(
                children: [
                  Checkbox(
                    value: _hotKey?.scope == HotKeyScope.inapp,
                    onChanged: (newValue) {
                      _handleSetAsInappWideChanged(newValue!);
                    },
                  ),
                  const Text(
                    'Set as inapp-wide hotkey. (default is system-wide)',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          child: const Text('Cancel'),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        TextButton(
          onPressed: _hotKey == null
              ? null
              : () {
                  widget.onHotKeyRecorded(_hotKey!);
                  Navigator.of(context).pop();
                },
          child: const Text('OK'),
        ),
      ],
    );
  }
}
