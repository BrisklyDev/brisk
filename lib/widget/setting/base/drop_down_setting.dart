import 'package:brisk/provider/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class DropDownSetting extends StatelessWidget {
  final List<String> items;
  final String text;
  final String value;
  final double? textWidth;
  final double? dropDownWidth;
  final double? dropDownItemTextWidth;
  final String? tooltipMessage;
  final Function(String? value) onChanged;

  const DropDownSetting({
    super.key,
    required this.items,
    required this.text,
    required this.value,
    required this.onChanged,
    this.textWidth,
    this.dropDownWidth,
    this.dropDownItemTextWidth,
    this.tooltipMessage,
  });

  @override
  Widget build(BuildContext context) {
    final theme =
        Provider.of<ThemeProvider>(context).activeTheme.settingTheme.pageTheme;
    final size = MediaQuery.of(context).size;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              text,
              style: TextStyle(
                color: theme.titleTextColor,
                fontSize: 14,
              ),
            ),
            if (tooltipMessage != null)
              Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: Tooltip(
                  message: tooltipMessage!,
                  child: const Icon(Icons.info, color: Colors.grey),
                  decoration: BoxDecoration(
                    color: Color.fromRGBO(33, 33, 33, 1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  textStyle: const TextStyle(color: Colors.white),
                ),
              ),
          ],
        ),
        SizedBox(
          width: dropDownWidth,
          child: DropdownButton<String>(
            value: value,
            dropdownColor:
                theme.widgetColor.dropDownColor.dropDownBackgroundColor,
            items: items.map((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: SizedBox(
                  width: dropDownItemTextWidth,
                  child: Text(
                    value,
                    style: TextStyle(
                      color: theme.widgetColor.dropDownColor.ItemTextColor,
                    ),
                  ),
                ),
              );
            }).toList(),
            onChanged: onChanged,
          ),
        )
      ],
    );
  }
}
