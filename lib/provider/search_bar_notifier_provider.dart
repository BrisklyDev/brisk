import 'package:brisk/provider/pluto_grid_util.dart';
import 'package:flutter/cupertino.dart';

class SearchBarNotifierProvider with ChangeNotifier {
  static final SearchBarNotifierProvider instance =
      SearchBarNotifierProvider._internal();

  SearchBarNotifierProvider._internal();

  factory SearchBarNotifierProvider() => instance;

  bool showSearchBar = false;

  void toggleShow() {
    PlutoGridUtil.isCtrlKeyDown = false;
    showSearchBar = !showSearchBar;
    notifyListeners();
  }
}
