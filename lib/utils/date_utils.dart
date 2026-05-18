DateTime? parseDateSafe(dynamic raw) {
  if (raw == null) return null;
  if (raw is DateTime) return raw;
  if (raw is int) return DateTime.fromMillisecondsSinceEpoch(raw);
  final s = raw.toString();
  final dt = DateTime.tryParse(s);
  if (dt != null) return dt;
  final i = int.tryParse(s);
  if (i != null) return DateTime.fromMillisecondsSinceEpoch(i);
  return null;
}
