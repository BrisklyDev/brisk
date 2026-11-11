import 'dart:async';

import 'package:brisk/constants/speed_unit.dart';
import 'package:brisk/l10n/app_localizations.dart';
import 'package:brisk/provider/theme_provider.dart';
import 'package:brisk/widget/base/outlined_text_field.dart';
import 'package:brisk/widget/base/rounded_outlined_button.dart';
import 'package:brisk_download_engine/brisk_download_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

/// Changes the speed limit of a download running on the kasma engine while it is downloading.
/// The limit applies to this download only and takes precedence over the global limit set in
/// the settings, until "Use Global Limit" is pressed. Edits apply shortly after the user stops
/// typing; there is no apply button.
class SpeedLimitPanel extends StatefulWidget {
  final String uid;

  const SpeedLimitPanel({super.key, required this.uid});

  @override
  State<SpeedLimitPanel> createState() => _SpeedLimitPanelState();
}

class _SpeedLimitPanelState extends State<SpeedLimitPanel> {
  final controller = TextEditingController();
  SpeedUnit unit = SpeedUnit.kiloBytes;

  /// Edits are applied once the user stops typing for [_applyDelay].
  static const _applyDelay = Duration(milliseconds: 1500);
  Timer? _applyTimer;

  @override
  void initState() {
    super.initState();
    _fillFromCurrentLimit();
  }

  @override
  void dispose() {
    // Don't lose an edit made right before the panel was closed
    if (_applyTimer?.isActive ?? false) {
      _applyTimer!.cancel();
      KasmaDownloadEngine.setSpeedLimit(widget.uid, _enteredLimit);
    }
    controller.dispose();
    super.dispose();
  }

  void _fillFromCurrentLimit() {
    final limit = KasmaDownloadEngine.speedLimitOf(widget.uid);
    unit = SpeedUnit.forLimit(limit);
    controller.text = limit > 0 ? (limit ~/ unit.bytes).toString() : "";
  }

  /// The limit in the text field in bytes per second. An empty field means no limit.
  int get _enteredLimit =>
      (int.tryParse(controller.text.trim()) ?? 0) * unit.bytes;

  void _scheduleApply() {
    _applyTimer?.cancel();
    _applyTimer = Timer(_applyDelay, () {
      if (!mounted) return;
      setState(
        () => KasmaDownloadEngine.setSpeedLimit(widget.uid, _enteredLimit),
      );
    });
  }

  void _removeLimit() {
    _applyTimer?.cancel();
    setState(() {
      KasmaDownloadEngine.setSpeedLimit(widget.uid, 0);
      controller.text = "";
    });
  }

  void _useGlobalLimit() {
    _applyTimer?.cancel();
    setState(() {
      KasmaDownloadEngine.setSpeedLimit(widget.uid, null);
      _fillFromCurrentLimit();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context).activeTheme;
    final loc = AppLocalizations.of(context)!;
    final limit = KasmaDownloadEngine.speedLimitOf(widget.uid);
    final ownLimit = KasmaDownloadEngine.hasOwnSpeedLimit(widget.uid);
    // Where the limit comes from only matters when the settings set a global limit
    final hasGlobalLimit = KasmaDownloadEngine.globalSpeedLimit > 0;
    final buttonColor = theme.widgetTheme.showHideButtonColor;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            loc.speedLimit_current(
              limit > 0 ? SpeedUnit.format(limit) : loc.unlimited,
            ),
            style: TextStyle(
              color: theme.textColor,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          if (hasGlobalLimit) ...[
            const SizedBox(height: 4),
            Text(
              ownLimit
                  ? loc.speedLimit_source_download
                  : loc.speedLimit_source_global,
              style: TextStyle(color: theme.textColor, fontSize: 13),
            ),
          ],
          const SizedBox(height: 12),
          // Fixed height: a DropdownButton is 48px tall unless dense
          SizedBox(
            height: 40,
            child: Row(
              children: [
                SizedBox(
                  width: 140,
                  height: 40,
                  child: OutLinedTextField(
                    controller: controller,
                    hintText: loc.unlimited,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                    onChanged: (_) => _scheduleApply(),
                  ),
                ),
                const SizedBox(width: 10),
                DropdownButton<SpeedUnit>(
                  value: unit,
                  isDense: true,
                  iconEnabledColor: theme.widgetTheme.dropDownColor.iconColor,
                  dropdownColor:
                      theme.widgetTheme.dropDownColor.dropDownBackgroundColor,
                  items: SpeedUnit.values
                      .map(
                        (u) => DropdownMenuItem(
                          value: u,
                          child: Text(
                            u.label,
                            style: TextStyle(
                              color:
                                  theme.widgetTheme.dropDownColor.itemTextColor,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => unit = value);
                    if (controller.text.trim().isNotEmpty) _scheduleApply();
                  },
                ),
                const Spacer(),
                RoundedOutlinedButton(
                  onPressed: limit > 0 ? _removeLimit : null,
                  text: loc.btn_removeSpeedLimit,
                  backgroundColor: buttonColor.backgroundColor,
                  hoverBackgroundColor: buttonColor.hoverBackgroundColor,
                  hoverTextColor: buttonColor.hoverTextColor,
                  textColor: buttonColor.textColor,
                ),
                if (ownLimit && hasGlobalLimit) ...[
                  const SizedBox(width: 10),
                  RoundedOutlinedButton(
                    onPressed: _useGlobalLimit,
                    text: loc.btn_useGlobalSpeedLimit,
                    backgroundColor: buttonColor.backgroundColor,
                    hoverBackgroundColor: buttonColor.hoverBackgroundColor,
                    hoverTextColor: buttonColor.hoverTextColor,
                    textColor: buttonColor.textColor,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
