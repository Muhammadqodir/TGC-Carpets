extension AmountExtension on double {
  String toCurrencyString() {
    final intPart = this.floor();
    final decimalPart = ((this - intPart) * 100).round();

    final intPartStr = intPart.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]} ');

    if (decimalPart > 0) {
      return '$intPartStr ${decimalPart.toString().padLeft(2, '0')}';
    } else {
      return intPartStr;
    }
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
