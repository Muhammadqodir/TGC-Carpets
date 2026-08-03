/// Builds a human-readable message from a Laravel error response body.
///
/// A 422 carries every failed field under `errors`, but `message` summarises
/// only the first one and counts the rest — "The code field is required. (and
/// 1 more error)". That is useless to a worker holding a carpet in front of a
/// scanner: the hidden error is often the one that explains the failure. This
/// returns every message instead, one per line, and falls back to `message`
/// for responses that carry no `errors` map (404s, 500s, aborts).
///
/// Returns null when [data] is not a decodable error body, so callers can fall
/// back to the transport-level message.
String? apiErrorMessage(dynamic data) {
  if (data is! Map) return null;

  final errors = data['errors'];
  if (errors is Map) {
    final messages = <String>[];

    for (final value in errors.values) {
      // Laravel nests one list per field; be tolerant of a bare string too,
      // since a hand-written abort() may not follow the same shape.
      if (value is List) {
        messages.addAll(value.map((m) => '$m').where((m) => m.isNotEmpty));
      } else if (value != null) {
        final text = '$value';
        if (text.isNotEmpty) messages.add(text);
      }
    }

    if (messages.isNotEmpty) {
      // Deduplicated: the same sentence can arrive under several field keys
      // (StoreShipmentRequest reports per-line and per-order-item violations),
      // and repeating it verbatim just pushes the useful one off screen.
      return messages.toSet().join('\n');
    }
  }

  final message = data['message'];
  return message is String && message.isNotEmpty ? message : null;
}
