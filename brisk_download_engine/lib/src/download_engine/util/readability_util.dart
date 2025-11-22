String convertPercentageNumberToReadableStr(double percentage) {
  return percentage >= 99.99
      ? "${percentage.toStringAsFixed(0)}%"
      : "${percentage.toStringAsFixed(2)}%";
}

String convertByteToReadableStr(int length) {
  if (length < 1024) {
    return '$length Bytes';
  } else if (length >= 1099511627776) {
    return '${(length / 1099511627776).toStringAsFixed(2)} TB';
  } else if (length >= 1073741824) {
    return '${(length / 1073741824).toStringAsFixed(2)} GB';
  } else if (length >= 1048576) {
    return '${(length / 1048576).toStringAsFixed(2)} MB';
  } else if (length > 1024) {
    return '${(length / 1024).toStringAsFixed(2)} KB';
  } else {
    return length.toString();
  }
}

String convertByteTransferRateToReadableStr(double bytesTransferRate) {
  final speedInMegaBytes = bytesTransferRate / 1000000;
  final speedInKiloBytes = bytesTransferRate / 1000;

  if (speedInMegaBytes > 1) {
    return '${speedInMegaBytes.toStringAsFixed(2)} MB/s';
  } else if (speedInKiloBytes > 1) {
    return '${speedInKiloBytes.toStringAsFixed(2)} KB/s';
  } else {
    return '${bytesTransferRate.toStringAsFixed(2)} B/s';
  }
}

String durationSecondsToReadableStr(int seconds) {
  int hours = seconds ~/ 3600;
  int minutes = (seconds % 3600) ~/ 60;
  int remainingSeconds = seconds % 60;
  String twoDigits(int n) => n.toString().padLeft(2, '0');
  if (hours > 0) {
    return '${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(remainingSeconds)}';
  } else {
    return '${twoDigits(minutes)}:${twoDigits(remainingSeconds)}';
  }
}

String? fpsToReadableStr(String? str) {
  if (str == null) return null;
  final double? fps = double.tryParse(str);
  if (fps == null) return "Invalid";
  return "${fps.toStringAsFixed(fps.truncateToDouble() == fps ? 0 : 2)}fps";
}
