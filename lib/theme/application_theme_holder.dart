import 'package:brisk/theme/application_theme.dart';
import 'package:brisk/setting/settings_cache.dart';
import 'package:brisk/theme/application_themes/catppuccin_mocha_theme.dart';
import 'package:brisk/theme/application_themes/catpuccin_frappe_theme.dart';
import 'package:brisk/theme/application_themes/catpuccin_latte_theme.dart';
import 'package:brisk/theme/application_themes/tokyo_night_theme.dart';

import 'application_themes/catpuccin_macchiato_theme.dart';
import 'application_themes/celestial_dark_theme.dart';
import 'application_themes/light_theme.dart';
import 'application_themes/signature_blue_theme.dart';

class ApplicationThemeHolder {
  static final List<ApplicationTheme> themes = [
    celestialDark,
    signatureBlue,
    light,
    tokyoNight,
    catppuccinLatte,
    catppuccinFrappe,
    catppuccinMacchiato,
    catppuccinMocha,
  ];

  static late ApplicationTheme activeTheme = celestialDark;

  static void setActiveTheme() {
    activeTheme = themes
        .where((t) => t.themeId == SettingsCache.applicationThemeId)
        .first;
  }
}
