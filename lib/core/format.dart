import 'dart:math' as math;

/// Converts an indexer decimal string of raw integer units to a double.
///
/// The dreamDEX indexer returns every quantity as a raw integer string:
/// sizes in raw base units, prices in raw quote units per whole base,
/// PnL in raw collateral units. Divide by 10^decimals to get human values.
double fromRaw(Object? raw, int decimals) {
  if (raw == null) return 0;
  final s = raw.toString();
  if (s.isEmpty) return 0;
  final value = BigInt.tryParse(s);
  if (value == null) return double.tryParse(s) ?? 0;
  return value / BigInt.from(10).pow(decimals);
}

int toInt(Object? v, [int fallback = 0]) {
  if (v == null) return fallback;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString()) ?? fallback;
}

String? toStr(Object? v) => v?.toString();

String shortAddress(String address) {
  if (address.length < 12) return address;
  return '${address.substring(0, 6)}…${address.substring(address.length - 4)}';
}

String _group(String digits) {
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
    buf.write(digits[i]);
  }
  return buf.toString();
}

String _fixed(double v, int places) {
  final parts = v.abs().toStringAsFixed(places).split('.');
  final whole = _group(parts[0]);
  return parts.length > 1 ? '$whole.${parts[1]}' : whole;
}

/// Price with precision that adapts to magnitude (BTC vs PEPE).
String formatPrice(double v) {
  if (v == 0) return '0';
  final a = v.abs();
  int places;
  if (a >= 1000) {
    places = 2;
  } else if (a >= 1) {
    places = 3;
  } else {
    places = math.min(10, (-math.log(a) / math.ln10).ceil() + 3);
  }
  return '${v < 0 ? '-' : ''}${_fixed(v, places)}';
}

/// USDso amount, e.g. `+1,204.50` or `-37.10`.
String formatUsd(double v, {bool signed = false}) {
  final sign = v < 0 ? '-' : (signed && v > 0 ? '+' : '');
  return '$sign${_fixed(v, 2)}';
}

String formatCompact(double v) {
  final a = v.abs();
  final sign = v < 0 ? '-' : '';
  if (a >= 1e9) return '$sign${(a / 1e9).toStringAsFixed(2)}B';
  if (a >= 1e6) return '$sign${(a / 1e6).toStringAsFixed(2)}M';
  if (a >= 1e3) return '$sign${(a / 1e3).toStringAsFixed(1)}K';
  return '$sign${a.toStringAsFixed(a >= 100 ? 0 : 2)}';
}

String formatSize(double v) {
  final a = v.abs();
  if (a >= 1000) return _fixed(v, 0);
  if (a >= 1) return _fixed(v, 3);
  return v.abs().toStringAsPrecision(3);
}

String formatPercent(double v, {int places = 2, bool signed = true}) {
  final sign = v < 0 ? '-' : (signed && v > 0 ? '+' : '');
  return '$sign${v.abs().toStringAsFixed(places)}%';
}

String timeAgo(DateTime t, [DateTime? now]) {
  final d = (now ?? DateTime.now()).difference(t);
  if (d.inSeconds < 60) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes}m ago';
  if (d.inHours < 24) return '${d.inHours}h ago';
  if (d.inDays < 7) return '${d.inDays}d ago';
  return '${t.day}/${t.month}/${t.year}';
}

String formatDuration(Duration d) {
  if (d.isNegative) return '0m';
  if (d.inDays >= 1) return '${d.inDays}d ${d.inHours % 24}h';
  if (d.inHours >= 1) return '${d.inHours}h ${d.inMinutes % 60}m';
  return '${math.max(1, d.inMinutes)}m';
}

String formatDate(DateTime t) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final hh = t.hour.toString().padLeft(2, '0');
  final mm = t.minute.toString().padLeft(2, '0');
  return '${t.day} ${months[t.month - 1]}, $hh:$mm';
}

final RegExp walletPattern = RegExp(r'^0x[a-fA-F0-9]{40}$');

bool isValidWallet(String s) => walletPattern.hasMatch(s.trim());
