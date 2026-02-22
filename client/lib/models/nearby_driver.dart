class NearbyDriver {
  const NearbyDriver({
    required this.driverId,
    required this.latitude,
    required this.longitude,
    required this.distanceKm,
  });

  final String driverId;
  final double latitude;
  final double longitude;
  final double distanceKm;

  factory NearbyDriver.fromJson(Map<String, dynamic> json) {
    double toDouble(dynamic value, [double fallback = 0]) {
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString() ?? '') ?? fallback;
    }

    return NearbyDriver(
      driverId: (json['driverId'] ?? '').toString(),
      latitude: toDouble(json['latitude']),
      longitude: toDouble(json['longitude']),
      distanceKm: toDouble(json['distanceKm']),
    );
  }
}
