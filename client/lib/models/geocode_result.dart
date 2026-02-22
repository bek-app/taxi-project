class GeocodeSuggestionResult {
  const GeocodeSuggestionResult({
    required this.displayName,
    required this.latitude,
    required this.longitude,
  });

  final String displayName;
  final double latitude;
  final double longitude;

  factory GeocodeSuggestionResult.fromJson(Map<String, dynamic> json) {
    double toDouble(dynamic value, [double fallback = 0]) {
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString() ?? '') ?? fallback;
    }

    return GeocodeSuggestionResult(
      displayName: (json['displayName'] ?? '').toString(),
      latitude: toDouble(json['latitude']),
      longitude: toDouble(json['longitude']),
    );
  }
}

class ReverseGeocodeResult {
  const ReverseGeocodeResult({
    required this.displayName,
    required this.shortAddress,
    this.cityName,
    this.cityId,
    this.cityViewBox,
    this.countryCode,
  });

  final String displayName;
  final String shortAddress;
  final String? cityName;
  final String? cityId;
  final String? cityViewBox;
  final String? countryCode;

  factory ReverseGeocodeResult.fromJson(Map<String, dynamic> json) {
    return ReverseGeocodeResult(
      displayName: (json['displayName'] ?? '').toString(),
      shortAddress: (json['shortAddress'] ?? '').toString(),
      cityName: (json['cityName'] ?? '').toString().trim().isEmpty
          ? null
          : (json['cityName'] ?? '').toString().trim(),
      cityId: (json['cityId'] ?? '').toString().trim().isEmpty
          ? null
          : (json['cityId'] ?? '').toString().trim(),
      cityViewBox: (json['cityViewBox'] ?? '').toString().trim().isEmpty
          ? null
          : (json['cityViewBox'] ?? '').toString().trim(),
      countryCode: (json['countryCode'] ?? '').toString().trim().isEmpty
          ? null
          : (json['countryCode'] ?? '').toString().trim().toLowerCase(),
    );
  }
}
