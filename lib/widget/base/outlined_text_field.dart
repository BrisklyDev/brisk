import 'package:brisk/provider/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

class OutLinedTextField extends StatelessWidget {
  final TextEditingController controller;
  final Color? fillColor;
  final Color textColor;
  final bool readOnly;
  final Function(String value)? onChanged;
  final TextInputType keyboardType;
  final List<TextInputFormatter> inputFormatters;
  final bool obscureText;
  final FocusNode? focusNode;
  final bool enabled;
  final String? hintText;
  final EdgeInsetsGeometry? contentPadding;
  final Widget? suffixIcon;
  final int? maxLines;
  final int? minLines;
  final Color cursorColor;

  const OutLinedTextField({
    super.key,
    required this.controller,
    this.cursorColor = Colors.white,
    this.fillColor,
    this.textColor = Colors.white,
    this.readOnly = false,
    this.keyboardType = TextInputType.text,
    this.inputFormatters = const [],
    this.onChanged,
    this.obscureText = false,
    this.focusNode,
    this.enabled = true,
    this.hintText,
    this.contentPadding,
    this.suffixIcon,
    this.maxLines = 1,
    this.minLines,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context)
        .activeTheme
        .widgetTheme
        .textFieldColor;
    return TextField(
      enabled: enabled,
      focusNode: focusNode,
      obscureText: obscureText,
      readOnly: readOnly,
      keyboardType: keyboardType,
      maxLines: maxLines,
      minLines: minLines,
      inputFormatters: inputFormatters,
      cursorColor: theme.cursorColor,
      controller: controller,
      onChanged: onChanged,
      textAlign: TextAlign.left,
      textDirection: TextDirection.ltr,
      style: TextStyle(color: theme.textColor, fontSize: 13),
      decoration: InputDecoration(
        suffixIcon: suffixIcon != null
            ? ClipOval(
                child: Material(
                  color: Colors.transparent,
                  child: suffixIcon,
                ),
              )
            : null,
        contentPadding: contentPadding,
        focusColor: Colors.white38,
        fillColor: fillColor ?? theme.fillColor,
        hoverColor: theme.hoverColor,
        hintText: hintText,
        hintStyle: TextStyle(
          color: theme.hintTextColor,
          fontStyle: FontStyle.italic,
        ),
        border: OutlineInputBorder(
          borderSide: BorderSide(color: theme.borderColor, width: 0.5),
          borderRadius: BorderRadius.circular(10),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: theme.borderColor, width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: theme.focusBorderColor, width: 1.0),
          borderRadius: BorderRadius.circular(10.0),
        ),
        filled: true,
        // iconColor: Colors.red,
      ),
    );
  }
}
