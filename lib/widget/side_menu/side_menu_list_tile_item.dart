import 'package:brisk/provider/theme_provider.dart';
import 'package:brisk/widget/side_menu/side_menu_item.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Horizontal padding of the group that holds expansion tile children.
const double sideMenuGroupPadding = 4;

/// An item nested inside a [SideMenuExpansionTile].
class SideMenuListTileItem extends StatelessWidget {
  final String text;
  final Widget? icon;
  final double size;
  final VoidCallback onTap;
  final bool active;

  const SideMenuListTileItem({
    super.key,
    required this.text,
    this.icon,
    this.size = 25,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final sideMenuTheme =
        Provider.of<ThemeProvider>(context).activeTheme.sideMenuTheme;
    return SideMenuTile(
      onTap: onTap,
      leading: SizedBox(width: size, height: size, child: icon),
      title: text,
      tooltip: text,
      active: active,
      height: 40,
      fontSize: 13.5,
      margin: sideMenuGroupPadding,
      inset: sideMenuTileMargin + sideMenuGroupPadding,
      activeColor: sideMenuTheme.expansionTileItemActiveColor,
      hoverColor: sideMenuTheme.expansionTileItemHoverColor,
      textColor: sideMenuTheme.tabIconColor,
    );
  }
}
