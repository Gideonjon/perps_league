import 'package:flutter/foundation.dart';

/// An invite code that arrived in the web URL (`/?join=K7QX2M`).
///
/// It is read once at startup and survives the sign-up and wallet steps,
/// then the home screen takes it and opens the join screen pre-filled.
class PendingInvite {
  PendingInvite._();

  static final RegExp _code = RegExp(r'^[A-Z2-9]{6}$');

  static String? _pending = _read();

  static String? _read() {
    if (!kIsWeb) return null;
    final raw = Uri.base.queryParameters['join']?.trim().toUpperCase();
    if (raw == null || !_code.hasMatch(raw)) return null;
    return raw;
  }

  /// The code, without consuming it.
  static String? get peek => _pending;

  /// The code, consumed so it opens only once per page load.
  static String? take() {
    final c = _pending;
    _pending = null;
    return c;
  }
}
