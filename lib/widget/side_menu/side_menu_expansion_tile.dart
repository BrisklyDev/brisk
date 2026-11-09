import 'package:brisk/provider/theme_provider.dart';
import 'package:brisk/widget/side_menu/side_menu_item.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// A side menu tile with collapsible children.
///
/// Tapping the tile calls [onTap]. Tapping the chevron toggles the children.
class SideMenuExpansionTile extends StatefulWidget {
  final List<Widget> children;
  final String title;
  final Widget icon;
  final VoidCallback? onTap;
  final bool active;

  const SideMenuExpansionTile({
    super.key,
    required this.title,
    required this.icon,
    required this.children,
    required this.onTap,
    this.active = false,
  });

  @override
  State<SideMenuExpansionTile> createState() => _SideMenuExpansionTileState();
}

class _SideMenuExpansionTileState extends State<SideMenuExpansionTile> {
  bool expanded = false;

  @override
  Widget build(BuildContext context) {
    final sideMenuTheme =
        Provider.of<ThemeProvider>(context).activeTheme.sideMenuTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SideMenuTile(
          onTap: widget.onTap,
          leading: widget.icon,
          title: widget.title,
          tooltip: widget.title,
          active: widget.active,
          activeColor: sideMenuTheme.activeTabBackgroundColor,
          hoverColor: sideMenuTheme.tabHoverColor,
          textColor: sideMenuTheme.tabIconColor,
          trailing: _chevron(sideMenuTheme.tabIconColor, 22, 30),
          minimizedTrailing: _chevron(sideMenuTheme.tabIconColor, 16, 18),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: expanded
              ? Container(
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(
                    horizontal: sideMenuTileMargin,
                    vertical: 2,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  decoration: BoxDecoration(
                    color: sideMenuTheme.expansionTileExpandedColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: widget.children,
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }

  Widget _chevron(Color color, double iconSize, double hitSize) {
    return InkWell(
      onTap: () => setState(() => expanded = !expanded),
      borderRadius: BorderRadius.circular(hitSize / 2),
      child: SizedBox(
        width: hitSize,
        height: hitSize,
        child: AnimatedRotation(
          turns: expanded ? 0.5 : 0,
          duration: const Duration(milliseconds: 200),
          child: Icon(
            Icons.keyboard_arrow_down_rounded,
            size: iconSize,
            color: color.withAlpha(180),
          ),
        ),
      ),
    );
  }
}
