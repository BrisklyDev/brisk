import 'package:flutter/cupertino.dart';

void safePop(BuildContext context) {
  if (Navigator.of(context).canPop()) {
    Navigator.of(context).pop();
  }
}

const double topMenuHeight = 80;

double minimizedSideMenuWidth = 110;

double resolveWindowWidth(Size size) {
  return size.width - minimizedSideMenuWidth;
}

bool minimizedSideMenu(Size size) => true;

