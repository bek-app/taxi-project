class BackendOrder {
  const BackendOrder({
    required this.id,
    required this.status,
    required this.finalPrice,
    required this.driverId,
    required this.driverLatitude,
    required this.driverLongitude,
    required this.canceledByRole,
    required this.canceledByUserId,
    required this.pickupLatitude,
    required this.pickupLongitude,
    required this.dropoffLatitude,
    required this.dropoffLongitude,
  });

  final String id;
  final String status;
  final double finalPrice;
  final String? driverId;
  final double? driverLatitude;
  final double? driverLongitude;
  final String? canceledByRole;
  final String? canceledByUserId;
  final double? pickupLatitude;
  final double? pickupLongitude;
  final double? dropoffLatitude;
  final double? dropoffLongitude;

  bool get canBeCanceled => status != 'COMPLETED' && status != 'CANCELED';

  factory BackendOrder.fromJson(Map<String, dynamic> json) {
    final dynamic rawPrice = json['finalPrice'];
    final double parsedPrice;
    if (rawPrice is num) {
      parsedPrice = rawPrice.toDouble();
    } else {
      parsedPrice = double.tryParse(rawPrice?.toString() ?? '0') ?? 0;
    }

    final dynamic rawDriverId = json['driverId'];
    final dynamic rawDriverLatitude = json['driverLatitude'];
    final dynamic rawDriverLongitude = json['driverLongitude'];
    final dynamic rawCanceledByRole = json['canceledByRole'];
    final dynamic rawCanceledByUserId = json['canceledByUserId'];

    double? toNullableDouble(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString());
    }

    return BackendOrder(
      id: (json['id'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      finalPrice: parsedPrice,
      driverId: rawDriverId?.toString(),
      driverLatitude: toNullableDouble(rawDriverLatitude),
      driverLongitude: toNullableDouble(rawDriverLongitude),
      canceledByRole: rawCanceledByRole?.toString(),
      canceledByUserId: rawCanceledByUserId?.toString(),
      pickupLatitude: toNullableDouble(json['pickupLatitude']),
      pickupLongitude: toNullableDouble(json['pickupLongitude']),
      dropoffLatitude: toNullableDouble(json['dropoffLatitude']),
      dropoffLongitude: toNullableDouble(json['dropoffLongitude']),
    );
  }
}
