import 'package:brisk/l10n/app_localizations.dart';
import 'package:brisk/provider/settings_provider.dart';
import 'package:brisk/util/ffmpeg.dart';
import 'package:brisk/setting/settings_cache.dart';
import 'package:brisk/widget/base/error_dialog.dart';
import 'package:brisk/widget/base/info_dialog.dart';
import 'package:brisk/widget/setting/base/external_link_setting.dart';
import 'package:brisk/widget/setting/base/settings_group.dart';
import 'package:brisk/widget/setting/base/text_field_setting.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class FFmpegSettingsGroup extends StatefulWidget {
  const FFmpegSettingsGroup({super.key});

  @override
  State<FFmpegSettingsGroup> createState() => _FFmpegSettingsGroupState();
}

class _FFmpegSettingsGroupState extends State<FFmpegSettingsGroup> {
  TextEditingController ffmpegPathController = TextEditingController(
    text: SettingsCache.ffmpegPath,
  );
  late AppLocalizations loc;

  @override
  void dispose() {
    ffmpegPathController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final provider = Provider.of<SettingsProvider>(context);
    loc = AppLocalizations.of(context)!;
    return SettingsGroup(
      title: "FFmpeg",
      tooltipMessage:
          "FFmpeg is used to soft-sub the available subtitles to the downloaded video stream file",
      children: [
        TextFieldSetting(
          text: loc.settings_ffmpegPath,
          width: resolveTextFieldWidth(size),
          txtController: ffmpegPathController,
          onChanged: (value) {
            provider.ffmpegPath = value;
            SettingsCache.ffmpegPath = value;
          },
          suffixIcon: IconButton(
            onPressed: () async {
              final newPath = await FilePicker.platform.getDirectoryPath();
              if (newPath == null) return;
              ffmpegPathController.text = newPath;
              provider.ffmpegPath = newPath;
            },
            icon: Icon(
              Icons.folder,
              color: Colors.white60,
            ),
          ),
        ),
        const SizedBox(height: 10),
        ExternalLinkSetting(
          title: loc.settings_testFFmpeg,
          tooltipMessage: loc.settings_ffmpeg_tooltip,
          titleWidth: 100,
          customIcon: Icon(
            Icons.build_circle_rounded,
            color: Colors.white70,
            size: 28,
          ),
          linkText: "",
          onLinkPressed: testFFmpeg,
        ),
        const SizedBox(height: 10),
        ExternalLinkSetting(
          title: loc.settings_ffmpeg_installAutomatically,
          titleWidth: 250,
          customIcon: Icon(
            Icons.install_desktop_rounded,
            color: Colors.white70,
            size: 28,
          ),
          linkText: "",
          onLinkPressed: () => installFFmpeg(context),
        )
      ],
    );
  }

  void installFFmpeg(BuildContext context) async {
    if (await FFmpeg.isInstalled()) {
      showDialog(
        context: context,
        builder: (context) => InfoDialog(
          titleText: loc.ffmpeg_alreadyInstalled,
          titleIcon: Icon(Icons.done),
          titleIconBackgroundColor: Colors.lightGreen,
        ),
      );
      return;
    }
    await FFmpeg.install(context);
  }

  void testFFmpeg() async {
    final isInstalled = await FFmpeg.isInstalled();
    if (isInstalled) {
      showDialog(
        context: context,
        builder: (context) => InfoDialog(
          titleText: loc.ffmpeg_integrationSuccess,
          titleIcon: Icon(Icons.done),
          titleIconBackgroundColor: Colors.lightGreen,
        ),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (context) => ErrorDialog(
        width: 400,
        height: 140,
        textHeight: 70,
        title: loc.ffmpeg_testFailed_title,
        description: loc.ffmpeg_testFailed_description,
        descriptionHint: loc.ffmpeg_testFailed_descriptionHint,
      ),
    );
  }

  double resolveTextFieldWidth(Size size) {
    double width = 300;
    if (size.width < 913) {
      width = size.width * 0.3;
    }
    if (size.width < 860) {
      width = size.width * 0.28;
    }
    if (size.width < 827) {
      width = size.width * 0.25;
    }
    if (size.width < 782) {
      width = size.width * 0.21;
    }
    if (size.width < 645) {
      width = size.width * 0.16;
    }
    return width;
  }
}
