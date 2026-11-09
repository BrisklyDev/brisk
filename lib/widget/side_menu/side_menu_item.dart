import 'package:brisk/provider/theme_provider.dart';
import 'package:brisk/util/ui_util.dart';
import 'package:brisk/widget/base/default_tooltip.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Horizontal gap between the side menu edge and a tile's highlight.
const double sideMenuTileMargin = 10;

/// Base tile used by every side menu entry.
///
/// The leading widget is always centered inside a fixed-width slot whose
/// center lines up with the center of the minimized side menu. This keeps
/// all icons in the same column whether the menu is minimized or expanded.
class SideMenuTile extends StatelessWidget {
  final Widget leading;
  final String title;
  final String? tooltip;
  final VoidCallback? onTap;
  final bool active;
  final Color activeColor;
  final Color hoverColor;
  final Color textColor;
  final double height;
  final double fontSize;

  /// Padding around this tile's highlight.
  final double margin;

  /// Distance from the side menu edge to the start of this tile's content.
  /// Must be at least [margin]; it is larger when the tile is nested.
  final double inset;

  /// Shown after the title when the menu is expanded.
  final Widget? trailing;

  /// Shown at the end edge of the tile when the menu is minimized.
  final Widget? minimizedTrailing;

  const SideMenuTile({
    super.key,
    required this.leading,
    required this.title,
    required this.activeColor,
    required this.hoverColor,
    required this.textColor,
    this.tooltip,
    this.onTap,
    this.active = false,
    this.height = 46,
    this.fontSize = 14,
    this.margin = sideMenuTileMargin,
    this.inset = sideMenuTileMargin,
    this.trailing,
    this.minimizedTrailing,
  });

  @override
  Widget build(BuildContext context) {
    final minimized = minimizedSideMenu(MediaQuery.sizeOf(context));
    final iconSlotWidth = minimizedSideMenuWidth - inset * 2;
    final borderRadius = BorderRadius.circular(10);
    final baseColor = active ? activeColor : Colors.transparent;
    Widget tile = Padding(
      padding: EdgeInsets.symmetric(horizontal: margin, vertical: 2),
      // The hover color is pre-blended into a single background color instead
      // of being painted as a separate layer. Stacking two anti-aliased
      // rounded layers lets the active color leak through at the corners.
      child: _HoverBuilder(
        builder: (hovered) => Material(
          color: hovered ? Color.alphaBlend(hoverColor, baseColor) : baseColor,
          borderRadius: borderRadius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            hoverColor: Colors.transparent,
            borderRadius: borderRadius,
            child: SizedBox(
              height: height,
              child: Stack(
                children: [
                  Row(
                    children: [
                      SizedBox(
                        width: iconSlotWidth,
                        child: Center(child: leading),
                      ),
                      if (!minimized) ...[
                        // Nested tiles have a narrower icon slot; pad so all
                        // labels start at the same x position.
                        SizedBox(width: inset - sideMenuTileMargin),
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: textColor,
                              fontSize: fontSize,
                              fontWeight:
                                  active ? FontWeight.w600 : FontWeight.w500,
                            ),
                          ),
                        ),
                        if (trailing != null) trailing!,
                        const SizedBox(width: 8),
                      ],
                    ],
                  ),
                  if (minimized && minimizedTrailing != null)
                    PositionedDirectional(
                      end: 0,
                      top: 0,
                      bottom: 0,
                      child: Center(child: minimizedTrailing),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (minimized && tooltip != null) {
      tile = DefaultTooltip(message: tooltip!, child: tile);
    }
    return tile;
  }
}

class SideMenuItem extends StatelessWidget {
  final VoidCallback onTap;
  final Widget leading;
  final String title;
  final bool active;

  const SideMenuItem({
    super.key,
    required this.onTap,
    required this.leading,
    required this.title,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final sideMenuTheme =
        Provider.of<ThemeProvider>(context).activeTheme.sideMenuTheme;
    return SideMenuTile(
      onTap: onTap,
      leading: leading,
      title: title,
      tooltip: title,
      active: active,
      activeColor: sideMenuTheme.activeTabBackgroundColor,
      hoverColor: sideMenuTheme.tabHoverColor,
      textColor: sideMenuTheme.tabIconColor,
    );
  }
}

class _HoverBuilder extends StatefulWidget {
  final Widget Function(bool hovered) builder;

  const _HoverBuilder({required this.builder});

  @override
  State<_HoverBuilder> createState() => _HoverBuilderState();
}

class _HoverBuilderState extends State<_HoverBuilder> {
  bool hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => hovered = true),
      onExit: (_) => setState(() => hovered = false),
      child: widget.builder(hovered),
    );
  }
}
