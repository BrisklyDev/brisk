import 'package:flutter/cupertino.dart';

void safePop(BuildContext context) {
  if (Navigator.of(context).canPop()) {
    Navigator.of(context).pop();
  }
}

const double topMenuHeight = 62;

/// Width of the side menu when only icons are shown.
const double minimizedSideMenuWidth = 80;

/// Width of the side menu when icons and labels are shown.
const double expandedSideMenuWidth = 240;

/// Window width at which the side menu expands to show labels.
const double sideMenuExpandBreakpoint = 1300;

bool minimizedSideMenu(Size size) => size.width < sideMenuExpandBreakpoint;

double sideMenuWidth(Size size) =>
    minimizedSideMenu(size) ? minimizedSideMenuWidth : expandedSideMenuWidth;

double resolveWindowWidth(Size size) {
  return size.width - sideMenuWidth(size);
}
