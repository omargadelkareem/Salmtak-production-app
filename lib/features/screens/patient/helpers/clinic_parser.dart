List<Map<String, dynamic>> extractClinics(dynamic rawClinics) {
  if (rawClinics == null) return <Map<String, dynamic>>[];

  if (rawClinics is List) {
    return rawClinics
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  if (rawClinics is Map) {
    return rawClinics.values
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  return <Map<String, dynamic>>[];
}
