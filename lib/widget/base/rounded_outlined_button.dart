import 'package:brisk/provider/theme_provider.dart';
import 'package:brisk/theme/application_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class RoundedOutlinedButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final Color borderColor;
  final Color textColor;
  final String? text;
  final Color backgroundColor;
  final double? width;
  final double? height;
  Color? hoverBackgroundColor;
  Color? hoverTextColor;
  final double borderRadius;
  final IconData? icon;
  final Widget? customIcon;
  final Color? iconColor;
  final Color? iconHoverColor;
  final MainAxisAlignment mainAxisAlignment;
  final MainAxisSize mainAxisSize;
  EdgeInsetsGeometry? contentPadding;

  RoundedOutlinedButton({
    Key? key,
    required this.onPressed,
    this.textColor = Colors.white,
    required this.text,
    this.borderColor = Colors.transparent,
    this.backgroundColor = Colors.black38,
    this.width,
    this.height = 35,
    this.hoverBackgroundColor,
    this.hoverTextColor,
    this.borderRadius = 8.0,
    this.customIcon = null,
    this.icon = null,
    this.mainAxisAlignment = MainAxisAlignment.center,
    this.mainAxisSize = MainAxisSize.min,
    this.contentPadding,
    this.iconColor,
    this.iconHoverColor,
  }) : super(key: key);

  factory RoundedOutlinedButton.fromButtonColor(
    ButtonColor buttonColor, {
    Key? key,
    required VoidCallback? onPressed,
    required String text,
    double? width,
    double? height = 35,
    double borderRadius = 8.0,
    IconData? icon = null,
    Widget? customIcon = null,
    mainAxisAlignment = MainAxisAlignment.center,
    mainAxisSize = MainAxisSize.min,
    EdgeInsetsGeometry? contentPadding,
  }) {
    return RoundedOutlinedButton(
      text: text,
      width: width,
      height: height,
      borderColor: buttonColor.borderColor,
      hoverTextColor: buttonColor.hoverTextColor,
      backgroundColor: buttonColor.backgroundColor,
      hoverBackgroundColor: buttonColor.hoverBackgroundColor,
      textColor: buttonColor.textColor,
      mainAxisSize: mainAxisSize,
      onPressed: onPressed,
      contentPadding: contentPadding,
      customIcon: customIcon,
      icon: icon,
      iconColor: buttonColor.iconColor,
      mainAxisAlignment: mainAxisAlignment,
      borderRadius: borderRadius,
    );
  }

  @override
  State<RoundedOutlinedButton> createState() => _RoundedOutlinedButtonState();
}

class _RoundedOutlinedButtonState extends State<RoundedOutlinedButton> {
  bool hover = false;

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context).activeTheme;
    Widget button = OutlinedButton(
      onPressed: widget.onPressed,
      onHover: (val) => setState(() => hover = val),
      style: ButtonStyle(
        backgroundColor: WidgetStatePropertyAll(
          widget.hoverBackgroundColor == null
              ? (hover ? widget.borderColor : widget.backgroundColor)
              : (hover ? widget.hoverBackgroundColor : widget.backgroundColor),
        ),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(widget.borderRadius),
          ),
        ),
        side: WidgetStateProperty.all(BorderSide(color: widget.borderColor)),
        padding: WidgetStateProperty.all(
          EdgeInsets.symmetric(
            horizontal: widget.icon == null ? 12 : 10,
            vertical: 0,
          ),
        ),
      ),
      child: Padding(
        padding: widget.contentPadding ?? EdgeInsets.zero,
        child: Row(
          mainAxisSize: widget.mainAxisSize,
          mainAxisAlignment: widget.mainAxisAlignment,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (widget.icon != null)
              Icon(
                widget.icon!,
                color: hover ? widget.iconHoverColor : widget.iconColor,
              ),
            if (widget.customIcon != null) widget.customIcon!,
            if (widget.customIcon != null && widget.text != null) SizedBox(width: 5),
            if (widget.icon != null && widget.text != null) SizedBox(width: 5),
            if (widget.text != null)
              Text(
                widget.text!,
                // textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
                style: TextStyle(
                  color: widget.hoverTextColor == null
                      ? (hover ? Colors.white : widget.textColor)
                      : (hover ? widget.hoverTextColor : widget.textColor),
                ),
              ),
          ],
        ),
      ),
    );

    if (widget.width != null || widget.height != null) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: button,
      );
    }

    return button;
  }
}
