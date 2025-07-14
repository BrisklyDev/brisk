import 'package:brisk/provider/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final sideMenuTheme =
        Provider.of<ThemeProvider>(context).activeTheme.sideMenuTheme;
    return Container(
      width: 110,
      color: widget.active
          ? sideMenuTheme.activeTabBackgroundColor
          : Colors.transparent,
      child: ExpansionTile(
        tilePadding: EdgeInsetsDirectional.only(end: 5),
        showTrailingIcon: true,
        shape: Border.all(color: Colors.transparent),
        backgroundColor: sideMenuTheme.expansionTileExpandedColor,
        title: InkWell(
          onTap: widget.onTap,
          child: SizedBox(
            height: 50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Padding(
                  padding: EdgeInsetsDirectional.only(start: 38),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: widget.icon,
                  ),
                ),
              ],
            ),
          ),
        ),
        children: widget.children,
      ),
    );
  }
}
