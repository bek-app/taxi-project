import 'package:latlong2/latlong.dart';

class RouteSnapshot {
  const RouteSnapshot({
    required this.distanceKm,
    required this.durationMinutes,
    required this.geometry,
    required this.fromCache,
  });

  final double distanceKm;
  final double durationMinutes;
  final List<LatLng> geometry;
  final bool fromCache;

  factory RouteSnapshot.fromJson(Map<String, dynamic> json) {
    double toDouble(dynamic value, [double fallback = 0]) {
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString() ?? '') ?? fallback;
    }

    double? toNullableDouble(dynamic value) {
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString() ?? '');
    }

    bool toBool(dynamic value, [bool fallback = false]) {
      if (value is bool) return value;
      if (value is String) return value.toLowerCase() == 'true';
      return fallback;
    }

    final geometryRaw = json['geometry'];
    final points = <LatLng>[];
    if (geometryRaw is List) {
      for (final item in geometryRaw) {
        if (item is! Map) continue;
        final lat = toNullableDouble(item['lat']);
        final lng = toNullableDouble(item['lng']);
        if (lat == null || lng == null) {
          continue;
        }
        points.add(LatLng(lat, lng));
      }
    }

    return RouteSnapshot(
      distanceKm: toDouble(json['distanceKm']),
      durationMinutes: toDouble(json['durationMinutes']),
      geometry: points,
      fromCache: toBool(json['fromCache']),
    );
  }
}
