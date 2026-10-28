/// Exact rational arithmetic. Floating point is used only by the chart.
class Exact implements Comparable<Exact> {
  final BigInt numerator;
  final BigInt denominator;

  factory Exact(BigInt numerator, [BigInt? denominator]) {
    var d = denominator ?? BigInt.one;
    if (d == BigInt.zero) throw const FormatException('Деление на ноль.');
    if (d.isNegative) {
      numerator = -numerator;
      d = -d;
    }
    final gcd = numerator.gcd(d);
    return Exact._(numerator ~/ gcd, d ~/ gcd);
  }
  const Exact._(this.numerator, this.denominator);
  factory Exact.integer(int value) => Exact(BigInt.from(value));
  factory Exact.parse(String value) {
    if (!RegExp(r'^\d+(\.\d+)?$').hasMatch(value) || value.length > 100) {
      throw const FormatException('Некорректное число.');
    }
    final parts = value.split('.');
    return Exact(
      BigInt.parse(parts.join()),
      BigInt.from(10).pow(parts.length == 1 ? 0 : parts[1].length),
    );
  }
  Exact operator +(Exact b) => Exact(
    numerator * b.denominator + b.numerator * denominator,
    denominator * b.denominator,
  );
  Exact operator -(Exact b) => Exact(
    numerator * b.denominator - b.numerator * denominator,
    denominator * b.denominator,
  );
  Exact operator *(Exact b) =>
      Exact(numerator * b.numerator, denominator * b.denominator);
  Exact operator /(Exact b) =>
      Exact(numerator * b.denominator, denominator * b.numerator);
  bool get isPositive => numerator > BigInt.zero;
  bool get isZero => numerator == BigInt.zero;
  @override
  int compareTo(Exact other) =>
      (numerator * other.denominator).compareTo(other.numerator * denominator);
  String fixed(int digits) {
    final scale = BigInt.from(10).pow(digits);
    final scaled = numerator.abs() * scale;
    var rounded = scaled ~/ denominator;
    if ((scaled % denominator) * BigInt.two >= denominator) {
      rounded += BigInt.one;
    }
    var raw = rounded.toString().padLeft(digits + 1, '0');
    if (digits > 0) {
      raw =
          '${raw.substring(0, raw.length - digits)}.${raw.substring(raw.length - digits)}';
    }
    return numerator.isNegative && rounded != BigInt.zero ? '-$raw' : raw;
  }

  String get storage => '$numerator/$denominator';
  factory Exact.restore(String value) {
    if (!RegExp(r'^\d{1,100}/[1-9]\d{0,99}$').hasMatch(value)) {
      throw const FormatException('Повреждённое число.');
    }
    final parts = value.split('/');
    return Exact(BigInt.parse(parts[0]), BigInt.parse(parts[1]));
  }
  double get chartValue => numerator.toDouble() / denominator.toDouble();
}

Exact validateAmount(String text) {
  final value = text.trim();
  if (!RegExp(r'^\d+([.,]\d{1,4})?$').hasMatch(value)) {
    throw const FormatException(
      'Введите положительную сумму: до 4 знаков после точки или запятой.',
    );
  }
  final amount = Exact.parse(value.replaceAll(',', '.'));
  if (!amount.isPositive ||
      amount.compareTo(Exact.integer(1000000000000)) > 0) {
    throw const FormatException(
      'Сумма должна быть больше нуля и не больше 1 000 000 000 000.',
    );
  }
  return amount;
}
