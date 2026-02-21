import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../core/colors.dart';

class MapBackdrop extends StatefulWidget {
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
  State<MapBackdrop> createState() => _MapBackdropState();
}

class _MapBackdropState extends State<MapBackdrop> {
  final _mapController = MapController();
  static final Map<String, List<LatLng>> _routeCache = <String, List<LatLng>>{};
  static const Duration _requestTimeout = Duration(seconds: 8);

  List<LatLng>? _roadPolylinePoints;

  @override
  void initState() {
    super.initState();
    _refreshRoute();
  }

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

    final oldKey = _routeKey(_buildRouteWaypoints(oldWidget));
    final newKey = _routeKey(_buildRouteWaypoints(widget));
    if (oldKey != newKey) {
      _refreshRoute();
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _refreshRoute() async {
    final waypoints = _buildRouteWaypoints(widget);
    if (waypoints.length < 2) {
      if (mounted) {
        setState(() {
          _roadPolylinePoints = null;
        });
      }
      return;
    }

    final cacheKey = _routeKey(waypoints);
    final cached = _routeCache[cacheKey];
    if (cached != null) {
      if (mounted) {
        setState(() {
          _roadPolylinePoints = cached;
        });
      }
      return;
    }

    try {
      final route = await _fetchRoadRoute(waypoints);
      if (!mounted) {
        return;
      }
      _routeCache[cacheKey] = route;
      setState(() {
        _roadPolylinePoints = route;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _roadPolylinePoints = waypoints;
      });
    }
  }

  List<LatLng> _buildRouteWaypoints(MapBackdrop data) {
    if (data.driverPoint != null &&
        data.pickupPoint != null &&
        data.dropoffPoint != null) {
      return <LatLng>[data.driverPoint!, data.pickupPoint!, data.dropoffPoint!];
    }
    if (data.pickupPoint != null && data.dropoffPoint != null) {
      return <LatLng>[data.pickupPoint!, data.dropoffPoint!];
    }
    return const <LatLng>[];
  }

  String _routeKey(List<LatLng> points) {
    return points
        .map(
          (point) =>
              '${point.latitude.toStringAsFixed(5)},${point.longitude.toStringAsFixed(5)}',
        )
        .join('|');
  }

  Future<List<LatLng>> _fetchRoadRoute(List<LatLng> points) async {
    final coordinates = points
        .map(
          (point) =>
              '${point.longitude.toStringAsFixed(6)},${point.latitude.toStringAsFixed(6)}',
        )
        .join(';');

    final uri = Uri.https(
      'router.project-osrm.org',
      '/route/v1/driving/$coordinates',
      const <String, String>{
        'alternatives': 'false',
        'overview': 'full',
        'geometries': 'geojson',
        'steps': 'false',
      },
    );

    final response = await http.get(uri).timeout(_requestTimeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Route API ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Invalid route response');
    }

    final routes = decoded['routes'];
    if (routes is! List || routes.isEmpty) {
      throw Exception('No routes');
    }

    final first = routes.first;
    if (first is! Map<String, dynamic>) {
      throw Exception('Invalid route object');
    }

    final geometry = first['geometry'];
    if (geometry is! Map<String, dynamic>) {
      throw Exception('Missing geometry');
    }

    final coordinatesList = geometry['coordinates'];
    if (coordinatesList is! List || coordinatesList.length < 2) {
      throw Exception('Route too short');
    }

    final path = <LatLng>[];
    for (final item in coordinatesList) {
      if (item is List && item.length >= 2) {
        final lon = (item[0] as num?)?.toDouble();
        final lat = (item[1] as num?)?.toDouble();
        if (lat != null && lon != null) {
          path.add(LatLng(lat, lon));
        }
      }
    }

    if (path.length < 2) {
      throw Exception('Invalid route path');
    }

    return path;
  }

  @override
  Widget build(BuildContext context) {
    final center = widget.currentLocation ??
        widget.pickupPoint ??
        widget.dropoffPoint ??
        widget.driverPoint ??
        MapBackdrop._fallbackCenter;

    final routePoints = <LatLng>[
      if (widget.pickupPoint != null) widget.pickupPoint!,
      if (widget.driverPoint != null) widget.driverPoint!,
      if (widget.dropoffPoint != null) widget.dropoffPoint!,
    ];
    final polylinePoints = _roadPolylinePoints ?? routePoints;

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
