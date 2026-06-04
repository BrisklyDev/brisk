import 'package:brisk_download_engine/src/download_engine/model/download_item_model.dart';

class TerminatedMessage {
  final DownloadItemModel downloadItem;
  final bool enginePanic;
  final bool networkError;

  TerminatedMessage({
    required this.downloadItem,
    this.enginePanic = false,
    this.networkError = false,
  });
}
