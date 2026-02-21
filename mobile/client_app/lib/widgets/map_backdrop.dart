import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../core/colors.dart';

class MapBackdrop extends StatefulWidget {
  const MapBackdrop({
    this.currentLocation,
    this.pickupPoint,
    this.dropoffPoint,
    this.driverPoint,
    this.routePolylinePoints,
    this.onMapTap,
    super.key,
  });

  static const LatLng _fallbackCenter = LatLng(43.245260, 76.910645);

  final LatLng? currentLocation;
  final LatLng? pickupPoint;
  final LatLng? dropoffPoint;
  final LatLng? driverPoint;
  final List<LatLng>? routePolylinePoints;
  final ValueChanged<LatLng>? onMapTap;

  @override
  State<MapBackdrop> createState() => _MapBackdropState();
}

class _MapBackdropState extends State<MapBackdrop> {
  final _mapController = MapController();

  @override
  void didUpdateWidget(MapBackdrop oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newCenter = widget.currentLocation;
    if (newCenter != null && newCenter != oldWidget.currentLocation) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          try {
            _mapController.move(newCenter, 14.5);
          } catch (_) {}
        }
      });
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  List<LatLng> _fallbackPolylinePoints() {
    if (widget.driverPoint != null &&
        widget.pickupPoint != null &&
        widget.dropoffPoint != null) {
      return <LatLng>[
        widget.driverPoint!,
        widget.pickupPoint!,
        widget.dropoffPoint!
      ];
    }
    if (widget.pickupPoint != null && widget.dropoffPoint != null) {
      return <LatLng>[widget.pickupPoint!, widget.dropoffPoint!];
    }
    return const <LatLng>[];
  }

  @override
  Widget build(BuildContext context) {
    final center = widget.currentLocation ??
        widget.pickupPoint ??
        widget.dropoffPoint ??
        widget.driverPoint ??
        MapBackdrop._fallbackCenter;

    final fromBackend = widget.routePolylinePoints;
    final polylinePoints = fromBackend != null && fromBackend.length >= 2
        ? fromBackend
        : _fallbackPolylinePoints();

    final markers = <Marker>[
      if (widget.currentLocation != null)
        Marker(
          point: widget.currentLocation!,
          width: 42,
          height: 42,
          child: const MapPin(
            icon: Icons.my_location_rounded,
            color: Color(0xFF0EA5E9),
          ),
        ),
      if (widget.pickupPoint != null)
        Marker(
          point: widget.pickupPoint!,
          width: 42,
          height: 42,
          child: const MapPin(
            icon: Icons.trip_origin,
            color: Color(0xFF0284C7),
          ),
        ),
      if (widget.driverPoint != null)
        Marker(
          point: widget.driverPoint!,
          width: 42,
          height: 42,
          child: const MapPin(
            icon: Icons.local_taxi,
            color: UiKitColors.primary,
          ),
        ),
      if (widget.dropoffPoint != null)
        Marker(
          point: widget.dropoffPoint!,
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
          mapController: _mapController,
          options: MapOptions(
            initialCenter: center,
            initialZoom: widget.currentLocation == null ? 12.0 : 14.5,
            onTap: (tapPosition, point) => widget.onMapTap?.call(point),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'kz.taxi.project',
            ),
            if (polylinePoints.length >= 2)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: polylinePoints,
                    color: UiKitColors.primary,
                    strokeWidth: 6,
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
