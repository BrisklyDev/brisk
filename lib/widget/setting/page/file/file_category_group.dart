import 'package:brisk/l10n/app_localizations.dart';
import 'package:brisk/util/parse_util.dart';
import 'package:brisk/widget/setting/base/settings_group.dart';
import 'package:brisk/widget/setting/base/switch_setting.dart';
import 'package:brisk/widget/setting/base/text_field_setting.dart';
import 'package:flutter/material.dart';

import '../../../../setting/settings_cache.dart';

class FileCategoryGroup extends StatefulWidget {
  const FileCategoryGroup({super.key});

  @override
  State<FileCategoryGroup> createState() => _FileCategoryGroupState();
}

class _FileCategoryGroupState extends State<FileCategoryGroup> {
  final videoController = TextEditingController(
    text: parseListToCsv(SettingsCache.videoFormats),
  );
  final musicController = TextEditingController(
    text: parseListToCsv(SettingsCache.musicFormats),
  );
  final archiveController = TextEditingController(
    text: parseListToCsv(SettingsCache.compressedFormats),
  );
  final programController = TextEditingController(
    text: parseListToCsv(SettingsCache.programFormats),
  );
  final documentController = TextEditingController(
    text: parseListToCsv(SettingsCache.documentFormats),
  );

  @override
  void dispose() {
    videoController.dispose();
    musicController.dispose();
    archiveController.dispose();
    programController.dispose();
    documentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final loc = AppLocalizations.of(context)!;
    return SettingsGroup(
      title: loc.settings_fileCategory,
      children: [
        SwitchSetting(
          text: loc.settings_automaticFileSavePathCategorization,
          switchValue: SettingsCache.automaticFileSavePathCategorization,
          onChanged: (value) => setState(
            () => SettingsCache.automaticFileSavePathCategorization = value,
          ),
        ),
        marginSizedBox,
        TextFieldSetting(
          text: loc.settings_fileCategory_video,
          width: resolveTextFieldWidth(size),
          textWidth: resolveTextWidth(size),
          txtController: videoController,
          onChanged: (val) => setCachedFormats(
            val,
            (formats) => SettingsCache.videoFormats = formats,
          ),
        ),
        marginSizedBox,
        TextFieldSetting(
          text: loc.settings_fileCategory_music,
          width: resolveTextFieldWidth(size),
          textWidth: resolveTextWidth(size),
          txtController: musicController,
          onChanged: (val) => setCachedFormats(
            val,
            (formats) => SettingsCache.musicFormats = formats,
          ),
        ),
        marginSizedBox,
        TextFieldSetting(
          text: loc.settings_fileCategory_archive,
          width: resolveTextFieldWidth(size),
          textWidth: resolveTextWidth(size),
          txtController: archiveController,
          onChanged: (val) => setCachedFormats(
            val,
            (formats) => SettingsCache.compressedFormats = formats,
          ),
        ),
        marginSizedBox,
        TextFieldSetting(
          text: loc.settings_fileCategory_program,
          width: resolveTextFieldWidth(size),
          textWidth: resolveTextWidth(size),
          txtController: programController,
          onChanged: (val) => setCachedFormats(
            val,
            (formats) => SettingsCache.programFormats = formats,
          ),
        ),
        marginSizedBox,
        TextFieldSetting(
          text: loc.settings_fileCategory_document,
          width: resolveTextFieldWidth(size),
          textWidth: resolveTextWidth(size),
          txtController: documentController,
          onChanged: (val) => setCachedFormats(
            val,
            (formats) => SettingsCache.documentFormats = formats,
          ),
        ),
      ],
    );
  }

  double resolveTextFieldWidth(Size size) {
    double width = 400;
    if (size.width < 950) {
      width = size.width * 0.4;
    }
    if (size.width < 860) {
      width = size.width * 0.38;
    }
    if (size.width < 762) {
      width = size.width * 0.3;
    }
    if (size.width < 640) {
      width = size.width * 0.25;
    }
    return width;
  }

  double resolveTextWidth(Size size) {
    double width = 150;
    if (size.width < 950) {
      width = 90;
    }
    return width;
  }

  void setCachedFormats(
    String value,
    Function(List<String> formats) setCache,
  ) async {
    if (value.isEmpty) {
      setCache([]);
      return;
    }
    if (value.endsWith(",")) {
      return;
    }

    value = value
        .replaceAll('\n', '')
        .replaceAll('\t', '')
        .replaceAll('\r', '')
        .replaceAll(' ', '')
        .replaceAll('\u2009', '');

    setCache(parseCsvToList(value));
  }

  Widget get marginSizedBox => const SizedBox(height: 10);
}
