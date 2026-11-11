/// Units the user can enter speed limits in. Base 1000, matching how speeds are displayed.
enum SpeedUnit {
  kiloBytes("KB/s", 1000),
  megaBytes("MB/s", 1000000);

  final String label;
  final int bytes;

  const SpeedUnit(this.label, this.bytes);

  /// The unit a limit is best shown in: MB/s when it is a whole number of megabytes.
  static SpeedUnit forLimit(int bytesPerSec) {
    return bytesPerSec > 0 && bytesPerSec % megaBytes.bytes == 0
        ? megaBytes
        : kiloBytes;
  }

  /// Formats a limit in the unit it was entered in, e.g. 3000000 -> "3 MB/s".
  /// Not using the readability utils on purpose: they divide by 1024, so a 3 MB/s limit would
  /// show as 2.86 MB/s.
  static String format(int bytesPerSec) {
    final unit = forLimit(bytesPerSec);
    final value = bytesPerSec / unit.bytes;
    final text = value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toStringAsFixed(2);
    return "$text ${unit.label}";
  }
}
