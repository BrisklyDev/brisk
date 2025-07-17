import 'package:brisk/provider/settings_provider.dart';
import 'package:brisk/provider/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SettingsSideMenuItem extends StatefulWidget {
  final int tabId;
  final String title;
  final IconData icon;

  const SettingsSideMenuItem({
    super.key,
    required this.tabId,
    required this.title,
    required this.icon,
  });

  @override
  State<SettingsSideMenuItem> createState() => _SettingsSideMenuItemState();
}

class _SettingsSideMenuItemState extends State<SettingsSideMenuItem> {
  late SettingsProvider provider;

  @override
  Widget build(BuildContext context) {
    provider = Provider.of<SettingsProvider>(context);
    final theme = Provider.of<ThemeProvider>(context).activeTheme;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        hoverColor:
            theme.settingTheme.sideMenuTheme.tabHoverBackgroundColor,
        onTap: () => provider.setSelectedSettingsTab(widget.tabId),
        child: Container(
          height: 40,
          width: 160,
          decoration: BoxDecoration(
            color: isTabSelected
                ? theme.settingTheme.sideMenuTheme.activeTabBackgroundColor
                : Colors.transparent,
          ),
          child: Padding(
            padding: EdgeInsetsDirectional.only(start: 10),
            child: Row(
              children: [
                Icon(
                  widget.icon,
                  color: isTabSelected
                      ? theme.settingTheme.sideMenuTheme.activeTabIconColor
                      : theme.settingTheme.sideMenuTheme.inactiveTabIconColor,
                ),
                SizedBox(width: 10),
                Text(
                  widget.title,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: theme.fontWeight,
                    color: theme.settingTheme.sideMenuTheme.tabTextColor,
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool get isTabSelected => provider.selectedTabId == widget.tabId;

  bool minimizedSideMenu(Size size) => size.width < 1400;
}
