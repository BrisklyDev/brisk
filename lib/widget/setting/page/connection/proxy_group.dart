import 'package:brisk/l10n/app_localizations.dart';
import 'package:brisk/provider/theme_provider.dart';
import 'package:brisk/util/settings_cache.dart';
import 'package:brisk/widget/setting/base/settings_group.dart';
import 'package:brisk/widget/setting/base/switch_setting.dart';
import 'package:brisk/widget/setting/base/text_field_setting.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

class ProxyGroup extends StatefulWidget {
  const ProxyGroup({super.key});

  @override
  State<ProxyGroup> createState() => _ProxyGroupState();
}

class _ProxyGroupState extends State<ProxyGroup> {
  TextEditingController addressController =
      TextEditingController(text: SettingsCache.proxyAddress);
  TextEditingController portController =
      TextEditingController(text: SettingsCache.proxyPort);
  TextEditingController usernameController =
      TextEditingController(text: SettingsCache.proxyUsername);
  TextEditingController passwordController =
      TextEditingController(text: SettingsCache.proxyPassword);


  @override
  void dispose() {
    addressController.dispose();
    portController.dispose();
    usernameController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final loc = AppLocalizations.of(context)!;
    return SettingsGroup(
      title: loc.settings_proxy,
      children: [
        SwitchSetting(
          text: loc.settings_proxy_enabled,
          switchValue: SettingsCache.proxyEnabled,
          onChanged: (value) => setState(
            () => SettingsCache.proxyEnabled = value,
          ),
        ),
        const SizedBox(height: 10),
        TextFieldSetting(
          onChanged: (value) => setState(
            () => SettingsCache.proxyAddress = value,
          ),
          textWidth: resolveTextWidth(size),
          width: resolveTextFieldWidth(size),
          text: loc.settings_proxy_address,
          txtController: addressController,
        ),
        const SizedBox(height: 10),
        TextFieldSetting(
          keyboardType: TextInputType.number,
          onChanged: (value) => setState(
            () => SettingsCache.proxyPort = value,
          ),
          textWidth: resolveTextWidth(size),
          width: resolveTextFieldWidth(size),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^[0-9]*$')),
          ],
          text: loc.port,
          txtController: portController,
        ),
        const SizedBox(height: 10),
        TextFieldSetting(
          onChanged: (value) => setState(
            () => SettingsCache.proxyUsername = value,
          ),
          textWidth: resolveTextWidth(size),
          width: resolveTextFieldWidth(size),
          text: loc.username,
          txtController: usernameController,
        ),
        const SizedBox(height: 10),
        TextFieldSetting(
          obscureText: true,
          onChanged: (value) => setState(
            () => SettingsCache.proxyPassword = value,
          ),
          textWidth: resolveTextWidth(size),
          width: resolveTextFieldWidth(size),
          text: loc.password,
          txtController: passwordController,
        )
      ],
    );
  }

  double resolveTextFieldWidth(Size size) {
    double width = 300;
    if (size.width < 827) {
      width = size.width * 0.4;
    }
    if (size.width < 775) {
      width = size.width * 0.35;
    }
    if (size.width < 690) {
      width = size.width * 0.25;
    }
    return width;
  }

  double resolveTextWidth(Size size) {
    double width = 150;
    if (size.width < 950) {
      width = 100;
    }
    if (size.width < 950) {
      width = 80;
    }
    return width;
  }
}
