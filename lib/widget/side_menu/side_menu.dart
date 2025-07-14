import 'package:brisk/constants/file_type.dart';
import 'package:brisk/l10n/app_localizations.dart';
import 'package:brisk/provider/pluto_grid_util.dart';
import 'package:brisk/provider/settings_provider.dart';
import 'package:brisk/provider/theme_provider.dart';
import 'package:brisk/util/ui_util.dart';
import 'package:brisk/widget/base/default_tooltip.dart';
import 'package:brisk/widget/setting/setting_dialog.dart';
import 'package:brisk/widget/side_menu/side_menu_expansion_tile.dart';
import 'package:brisk/widget/side_menu/side_menu_item.dart';
import 'package:brisk/widget/side_menu/side_menu_list_tile_item.dart';
import 'package:brisk_download_engine/brisk_download_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';

import '../../provider/queue_provider.dart';

class SideMenu extends StatefulWidget {
  SideMenu({Key? key}) : super(key: key);

  @override
  State<SideMenu> createState() => _SideMenuState();
}

class _SideMenuState extends State<SideMenu> {
  int selectedTab = 0;
  int? selectedExpansionTileItemTab;

  @override
  Widget build(BuildContext context) {
    final queueProvider = Provider.of<QueueProvider>(context);
    final sideMenuTheme =
        Provider.of<ThemeProvider>(context).activeTheme.sideMenuTheme;
    final size = MediaQuery.of(context).size;
    final loc = AppLocalizations.of(context)!;
    return Container(
      width: minimizedSideMenuWidth,
      height: double.infinity,
      color: sideMenuTheme.backgroundColor,
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 10, top: 30),
              child: SvgPicture.asset(
                "assets/icons/logo-basic.svg",
                height: 25,
                width: 25,
                colorFilter: ColorFilter.mode(
                  sideMenuTheme.briskLogoColor,
                  BlendMode.srcIn,
                ),
              ),
            ),
            const SizedBox(height: 26),
            SideMenuExpansionTile(
              title: 'Downloads',
              active: selectedTab == 0,
              icon: DefaultTooltip(
                message: loc.allDownloads,
                child: const Icon(
                  Icons.download_rounded,
                  color: Colors.white,
                ),
              ),
              onTap: () => onDownloadsPressed(queueProvider),
              children: [
                SideMenuListTileItem(
                  text: 'Archive',
                  icon: SvgPicture.asset(
                    'assets/icons/archive.svg',
                    colorFilter:
                    ColorFilter.mode(Colors.lightBlue, BlendMode.srcIn),
                  ),
                  size: 32,
                  onTap: () => setGridFileTypeFilter(DLFileType.compressed),
                  active: selectedExpansionTileItemTab == 4,
                ),
                SideMenuListTileItem(
                  text: 'Videos',
                  size: 34,
                  icon: SvgPicture.asset(
                    'assets/icons/video_2.svg',
                    colorFilter:
                    ColorFilter.mode(Colors.pinkAccent, BlendMode.srcIn),
                  ),
                  onTap: () => setGridFileTypeFilter(DLFileType.video),
                  active: selectedExpansionTileItemTab == 1,
                ),
                SideMenuListTileItem(
                  text: 'Programs',
                  icon: SvgPicture.asset(
                    'assets/icons/program.svg',
                    colorFilter: ColorFilter.mode(
                        Colors.indigoAccent, BlendMode.srcIn),
                  ),
                  size: 30,
                  onTap: () => setGridFileTypeFilter(DLFileType.program),
                  active: selectedExpansionTileItemTab == 3,
                ),
                SideMenuListTileItem(
                  text: 'Documents',
                  icon: SvgPicture.asset(
                    'assets/icons/document.svg',
                    colorFilter:
                        ColorFilter.mode(const Color(0xFF4CAF50), BlendMode.srcIn),
                  ),
                  onTap: () => setGridFileTypeFilter(DLFileType.documents),
                  active: selectedExpansionTileItemTab == 2,
                ),
                SideMenuListTileItem(
                  text: 'Music',
                  icon: SvgPicture.asset(
                    'assets/icons/music.svg',
                    colorFilter:
                    ColorFilter.mode(Colors.cyanAccent, BlendMode.srcIn),
                  ),
                  onTap: () => setGridFileTypeFilter(DLFileType.music),
                  active: selectedExpansionTileItemTab == 0,
                )
              ],
            ),
            SideMenuItem(
              onTap: () => setUnfinishedGridFilter(queueProvider),
              leading: DefaultTooltip(
                message: loc.unfinishedDownloads,
                child: SvgPicture.asset(
                  'assets/icons/unfinished.svg',
                  colorFilter: ColorFilter.mode(Colors.white, BlendMode.srcIn),
                ),
              ),
              title: "Unfinished",
              active: selectedTab == 1,
            ),
            SideMenuItem(
              onTap: () => setFinishedFilter(queueProvider),
              leading: DefaultTooltip(
                message: loc.finishedDownloads,
                child: const Icon(
                  Icons.download_done_rounded,
                  color: Colors.white,
                ),
              ),
              title: "Finished",
              active: selectedTab == 2,
            ),
            SideMenuItem(
              onTap: () => onQueueTabPressed(queueProvider),
              leading: DefaultTooltip(
                message: loc.downloadQueues,
                child: Icon(
                  Icons.queue,
                  color: Colors.white,
                ),
              ),
              title: "Queues",
              active: selectedTab == 3,
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: IconButton(
                  iconSize: 30,
                  onPressed: () => onSettingPressed(context),
                  icon: const Icon(
                    Icons.settings,
                    color: Colors.white,
                  )),
            ),
          ],
        ),
      ),
    );
  }

  void onDownloadsPressed(QueueProvider queueProvider) {
    PlutoGridUtil.removeFilters();
    PlutoGridUtil.cachedRows.clear();
    queueProvider.setQueueTopMenu(false);
    queueProvider.setSelectedQueue(null);
    queueProvider.setQueueTabSelected(false);
    queueProvider.setDownloadQueueTopMenu(false);
    setState(() {
      selectedTab = 0;
      selectedExpansionTileItemTab = null;
    });
  }

  void onQueueTabPressed(QueueProvider queueProvider) {
    PlutoGridUtil.plutoStateManager?.removeAllRows();
    PlutoGridUtil.cachedRows.clear();
    queueProvider.setQueueTopMenu(true);
    queueProvider.setQueueTabSelected(true);
    queueProvider.setSelectedQueue(null);
    setState(() {
      selectedTab = 3;
      selectedExpansionTileItemTab = null;
    });
  }

  void onSettingPressed(BuildContext context) {
    Provider.of<SettingsProvider>(context, listen: false).selectedTabId = 0;
    showDialog(
      context: context,
      builder: (context) => const SettingsDialog(),
      barrierDismissible: false,
    );
  }

  void setGridFileTypeFilter(DLFileType fileType) {
    PlutoGridUtil.setFilter("file_type", fileType.name);
    int? selected;
    switch (fileType) {
      case DLFileType.music:
        selected = 0;
        break;
      case DLFileType.video:
        selected = 1;
        break;
      case DLFileType.documents:
        selected = 2;
        break;
      case DLFileType.program:
        selected = 3;
        break;
      case DLFileType.compressed:
        selected = 4;
        break;
      default:
        break;
    }
    setState(() => selectedExpansionTileItemTab = selected);
  }

  void setUnfinishedGridFilter(QueueProvider queueProvider) {
    PlutoGridUtil.setFilter(
      "status",
      DownloadStatus.assembleComplete,
      negate: true,
    );
    setState(() {
      selectedTab = 1;
      selectedExpansionTileItemTab = null;
    });
    queueProvider.setQueueTopMenu(false);
    queueProvider.setQueueTabSelected(false);
    queueProvider.setSelectedQueue(null);
  }

  void setFinishedFilter(QueueProvider queueProvider) {
    PlutoGridUtil.setFilter("status", DownloadStatus.assembleComplete);
    setState(() {
      selectedTab = 2;
      selectedExpansionTileItemTab = null;
    });
    queueProvider.setQueueTopMenu(false);
    queueProvider.setQueueTabSelected(false);
    queueProvider.setSelectedQueue(null);
  }
}
