import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../core/colors.dart';

class MapBackdrop extends StatelessWidget {
  const MapBackdrop({
    this.currentLocation,
    this.pickupPoint,
    this.dropoffPoint,
    this.driverPoint,
    super.key,
  });

  static const LatLng _fallbackCenter = LatLng(43.245260, 76.910645);

  final LatLng? currentLocation;
  final LatLng? pickupPoint;
  final LatLng? dropoffPoint;
  final LatLng? driverPoint;

  @override
  Widget build(BuildContext context) {
    final center = currentLocation ??
        pickupPoint ??
        dropoffPoint ??
        driverPoint ??
        _fallbackCenter;

    final routePoints = <LatLng>[
      if (pickupPoint != null) pickupPoint!,
      if (driverPoint != null) driverPoint!,
      if (dropoffPoint != null) dropoffPoint!,
    ];

    final markers = <Marker>[
      if (currentLocation != null)
        Marker(
          point: currentLocation!,
          width: 42,
          height: 42,
          child: const MapPin(
            icon: Icons.my_location_rounded,
            color: Color(0xFF0EA5E9),
          ),
        ),
      if (pickupPoint != null)
        Marker(
          point: pickupPoint!,
          width: 42,
          height: 42,
          child: const MapPin(
            icon: Icons.trip_origin,
            color: Color(0xFF0284C7),
          ),
        ),
      if (driverPoint != null)
        Marker(
          point: driverPoint!,
          width: 42,
          height: 42,
          child: const MapPin(
            icon: Icons.local_taxi,
            color: UiKitColors.primary,
          ),
        ),
      if (dropoffPoint != null)
        Marker(
          point: dropoffPoint!,
          width: 42,
          height: 42,
          child: const MapPin(
            icon: Icons.flag_rounded,
            color: UiKitColors.success,
          ),
        ),
    ];

    return Stack(
      children: [
        FlutterMap(
          options: MapOptions(
            initialCenter: center,
            initialZoom: currentLocation == null ? 12.8 : 14.2,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'kz.taxi.project',
            ),
            if (routePoints.length >= 2)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: routePoints,
                    color: UiKitColors.primary,
                    strokeWidth: 5,
                  ),
                ],
              ),
            if (markers.isNotEmpty) MarkerLayer(markers: markers),
          ],
        ),
        const Positioned(
          right: 8,
          bottom: 8,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Color(0xE6FFFFFF),
              borderRadius: BorderRadius.all(Radius.circular(8)),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text(
                '© OpenStreetMap contributors',
                style: TextStyle(
                  fontSize: 10,
                  color: Color(0xFF374151),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class MapPin extends StatelessWidget {
  const MapPin({
    required this.icon,
    required this.color,
    super.key,
  });

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }
}
