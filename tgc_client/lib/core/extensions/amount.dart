extension AmountExtension on double {
  String toCurrencyString() {
    final parts = toStringAsFixed(2).split('.');
    final intPartStr = parts[0].replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]} ');
    return '$intPartStr.${parts[1]}';
  }
  String toCurrencyShort() {
    if (this >= 1000000000) {
      return '${_compact(this / 1000000000)}B';
    } else if (this >= 1000000) {
      return '${_compact(this / 1000000)}M';
    } else if (this >= 1000) {
      return '${_compact(this / 1000)}K';
    }
    return toCurrencyString();
  }

  String _compact(double v) {
    final rounded = (v * 10).round() / 10;
    return rounded == rounded.truncate()
        ? rounded.toInt().toString()
        : rounded.toString();
  }
}
