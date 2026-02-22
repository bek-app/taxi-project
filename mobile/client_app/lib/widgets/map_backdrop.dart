import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_dragmarker/flutter_map_dragmarker.dart';
import 'package:latlong2/latlong.dart';

import '../core/colors.dart';

class MapBackdrop extends StatefulWidget {
  const MapBackdrop({
    this.currentLocation,
    this.pickupPoint,
    this.dropoffPoint,
    this.driverPoint,
    this.driverTrailPolylinePoints,
    this.routePolylinePoints,
    this.animateRoute = false,
    this.nearbyDriverPoints,
    this.onMapTap,
    this.onPickupDragEnd,
    this.onPickupTap,
    this.onCurrentLocationTap,
    this.pickupDraggable = false,
    super.key,
  });

  static const LatLng _fallbackCenter = LatLng(43.245260, 76.910645);

  final LatLng? currentLocation;
  final LatLng? pickupPoint;
  final LatLng? dropoffPoint;
  final LatLng? driverPoint;
  final List<LatLng>? driverTrailPolylinePoints;
  final List<LatLng>? routePolylinePoints;
  final bool animateRoute;
  final List<LatLng>? nearbyDriverPoints;
  final ValueChanged<LatLng>? onMapTap;
  final ValueChanged<LatLng>? onPickupDragEnd;
  final ValueChanged<LatLng>? onPickupTap;
  final ValueChanged<LatLng>? onCurrentLocationTap;
  final bool pickupDraggable;

  @override
  State<MapBackdrop> createState() => _MapBackdropState();
}

class _MapBackdropState extends State<MapBackdrop>
    with SingleTickerProviderStateMixin {
  final _mapController = MapController();
  late final AnimationController _routeAnimationController =
      AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );

  @override
  void initState() {
    super.initState();
    _syncRouteAnimationLoop();
  }

  @override
  void didUpdateWidget(MapBackdrop oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncRouteAnimationLoop();
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
    _routeAnimationController.dispose();
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

  void _syncRouteAnimationLoop() {
    final shouldAnimate = widget.animateRoute;
    if (shouldAnimate) {
      if (!_routeAnimationController.isAnimating) {
        _routeAnimationController.repeat();
      }
      return;
    }
    if (_routeAnimationController.isAnimating) {
      _routeAnimationController.stop();
    }
  }

  List<LatLng> _routeSlice(
    List<LatLng> points,
    double startFraction,
    double endFraction,
  ) {
    if (points.length < 2) {
      return const <LatLng>[];
    }

    final segmentCount = points.length - 1;
    final clampedStart = startFraction.clamp(0.0, 1.0);
    final clampedEnd = endFraction.clamp(0.0, 1.0);
    if (clampedEnd <= clampedStart) {
      return const <LatLng>[];
    }

    int startIndex = (clampedStart * segmentCount).floor();
    int endIndex = (clampedEnd * segmentCount).ceil();
    startIndex = startIndex.clamp(0, points.length - 2);
    endIndex = endIndex.clamp(startIndex + 1, points.length - 1);

    final slice = points.sublist(startIndex, endIndex + 1);
    return slice.length >= 2 ? slice : const <LatLng>[];
  }

  List<Polyline> _animatedRoutePolylines(List<LatLng> points) {
    if (points.length < 2) {
      return const <Polyline>[];
    }

    const span = 0.22;
    final start = _routeAnimationController.value % 1.0;
    final end = (start + span) % 1.0;

    final segments = <List<LatLng>>[];
    if (start < end) {
      segments.add(_routeSlice(points, start, end));
    } else {
      segments.add(_routeSlice(points, start, 1.0));
      segments.add(_routeSlice(points, 0.0, end));
    }

    final pulse = Curves.easeInOut.transform(
      (_routeAnimationController.value * 2) % 1.0,
    );
    final alpha = 0.7 + (pulse * 0.25);

    return segments
        .where((segment) => segment.length >= 2)
        .map(
          (segment) => Polyline(
            points: segment,
            color: UiKitColors.primary.withValues(alpha: alpha),
            strokeWidth: 8,
          ),
        )
        .toList(growable: false);
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
    final useAnimatedRoute = widget.animateRoute && polylinePoints.length >= 2;
    final driverTrail =
        widget.driverTrailPolylinePoints?.whereType<LatLng>().toList() ??
            const <LatLng>[];

    final usePickupDragMarker =
        widget.pickupPoint != null && widget.pickupDraggable && !kIsWeb;

    final dragMarkers = <DragMarker>[
      if (usePickupDragMarker)
        DragMarker(
          point: widget.pickupPoint!,
          size: const Size(42, 42),
          useLongPress: false,
          onTap: (point) => widget.onPickupTap?.call(point),
          onDragEnd: (details, point) => widget.onPickupDragEnd?.call(point),
          builder: (context, point, isDragging) {
            return Opacity(
              opacity: isDragging ? 0.85 : 1.0,
              child: const MapPin(
                icon: Icons.trip_origin,
                color: Color(0xFF0284C7),
              ),
            );
          },
        ),
    ];

    final markers = <Marker>[
      if (widget.currentLocation != null)
        Marker(
          point: widget.currentLocation!,
          width: 42,
          height: 42,
          child: GestureDetector(
            onTap: () =>
                widget.onCurrentLocationTap?.call(widget.currentLocation!),
            child: const MapPin(
              icon: Icons.my_location_rounded,
              color: Color(0xFF0EA5E9),
            ),
          ),
        ),
      if (widget.pickupPoint != null && !usePickupDragMarker)
        Marker(
          point: widget.pickupPoint!,
          width: 42,
          height: 42,
          child: GestureDetector(
            onTap: () => widget.onPickupTap?.call(widget.pickupPoint!),
            child: const MapPin(
              icon: Icons.trip_origin,
              color: Color(0xFF0284C7),
            ),
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
      ...?widget.nearbyDriverPoints?.map(
        (point) => Marker(
          point: point,
          width: 34,
          height: 34,
          child: const MapPin(
            icon: Icons.local_taxi_outlined,
            color: Color(0xFFF59E0B),
          ),
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
                    color: useAnimatedRoute
                        ? UiKitColors.primary.withValues(alpha: 0.22)
                        : UiKitColors.primary,
                    strokeWidth: useAnimatedRoute ? 5 : 6,
                  ),
                ],
              ),
            if (driverTrail.length >= 2)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: driverTrail,
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.9),
                    strokeWidth: 7,
                  ),
                ],
              ),
            if (useAnimatedRoute)
              AnimatedBuilder(
                animation: _routeAnimationController,
                builder: (context, _) {
                  final animatedPolylines =
                      _animatedRoutePolylines(polylinePoints);
                  if (animatedPolylines.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return PolylineLayer(polylines: animatedPolylines);
                },
              ),
            if (markers.isNotEmpty) MarkerLayer(markers: markers),
            if (dragMarkers.isNotEmpty) DragMarkers(markers: dragMarkers),
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
