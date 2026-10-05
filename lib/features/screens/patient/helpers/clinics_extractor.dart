List<Map<String, dynamic>> extractClinics(dynamic rawClinics) {
  final out = <Map<String, dynamic>>[];
  if (rawClinics == null) return out;

  if (rawClinics is List) {
    for (final item in rawClinics) {
      if (item is Map) out.add(Map<String, dynamic>.from(item));
    }
    return out;
  }

  if (rawClinics is Map) {
    final m = Map<Object?, Object?>.from(rawClinics);
    for (final entry in m.entries) {
      final v = entry.value;
      if (v is Map) out.add(Map<String, dynamic>.from(v));
    }
    return out;
  }

  return out;
}
