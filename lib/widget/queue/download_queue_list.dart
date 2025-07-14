import 'package:brisk/db/hive_util.dart';
import 'package:brisk/provider/theme_provider.dart';
import 'package:brisk/util/ui_util.dart';
import 'package:brisk/widget/queue/queue_list_item.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class DownloadQueueList extends StatelessWidget {
  DownloadQueueList({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final gridTheme =
        Provider.of<ThemeProvider>(context).activeTheme.downloadGridTheme;
    final size = MediaQuery.of(context).size;
    return Material(
      type: MaterialType.transparency,
      child: Container(
        height: size.height - topMenuHeight,
        width: resolveWindowWidth(size),
        color: gridTheme.backgroundColor,
        child: Column(
          children: buildQueues(context),
        ),
      ),
    );
  }

  List<Widget> buildQueues(BuildContext context) {
    return HiveUtil.instance.downloadQueueBox.values.map((e) {
      return QueueListItem(queue: e);
    }).toList();
  }
}
