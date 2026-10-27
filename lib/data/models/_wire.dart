/// Null-safe readers for the server's JSON, shared by the models that read
/// themselves off the wire.
///
/// The same rules as the mappers: a field the server stops sending degrades a
/// screen rather than crashing it, money arrives as a number or a numeric
/// string, and an enum is matched by name, tolerantly, falling back to a safe
/// value when the server has grown a state this build does not know.
library;

double money(Object? value) => switch (value) {
  num n => n.toDouble(),
  String s => double.tryParse(s) ?? 0,
  _ => 0,
};

int integer(Object? value, [int fallback = 0]) => switch (value) {
  num n => n.toInt(),
  String s => int.tryParse(s) ?? fallback,
  _ => fallback,
};

bool boolean(Object? value, [bool fallback = false]) =>
    value is bool ? value : fallback;

String str(Object? value, [String fallback = '']) =>
    value is String ? value : fallback;

DateTime date(Object? value) {
  if (value is String) {
    final parsed = DateTime.tryParse(value);
    if (parsed != null) return parsed.toLocal();
  }
  return DateTime.now();
}

DateTime? dateOrNull(Object? value) =>
    value is String ? DateTime.tryParse(value)?.toLocal() : null;

T wireEnum<T extends Enum>(Object? value, List<T> values, T fallback) {
  if (value is! String) return fallback;
  final wanted = value.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toLowerCase();
  for (final candidate in values) {
    if (candidate.name.toLowerCase() == wanted) return candidate;
  }
  return fallback;
}

Map<String, dynamic> obj(Object? value) =>
    value is Map ? value.cast<String, dynamic>() : const {};

List<Map<String, dynamic>> list(Object? value) => value is List
    ? value.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList()
    : const [];

/// The server's enum names — `BANK_TRANSFER` — from a Dart one —
/// `bankTransfer`.
String toWire(Enum value) => value.name
    .replaceAllMapped(RegExp(r'[A-Z]'), (m) => '_${m[0]}')
    .toUpperCase();
