import 'package:flutter/cupertino.dart';

class SearchBarNotifierProvider with ChangeNotifier {
  bool showSearchBar = false;

  void toggleShow() {
    showSearchBar = !showSearchBar;
    notifyListeners();
  }

}
