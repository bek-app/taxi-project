import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/app_role.dart';
import '../models/auth_session.dart';
import '../models/backend_order.dart';
import '../models/geocode_result.dart';
import '../models/nearby_driver.dart';
import '../models/route_snapshot.dart';
import '../models/user_profile.dart';

class TaxiApiClient {
  TaxiApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  String? _accessToken;

  String get baseUrl {
    const String fromEnv =
        String.fromEnvironment('API_BASE_URL', defaultValue: '');
    if (fromEnv.isNotEmpty) {
      return fromEnv;
    }

    if (kIsWeb) {
      return 'http://127.0.0.1:3000/api';
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3000/api';
    }

    return 'http://127.0.0.1:3000/api';
  }

  Future<AuthSession> login(String email, String password) async {
    final response = await _post(
      '/auth/login',
      body: {
        'email': email,
        'password': password,
      },
      includeAuth: false,
    );

    return _parseAuthSession(_decodeAsMap(response), errorLabel: 'login');
  }

  Future<AuthSession> register(
      String email, String password, AppRole role) async {
    final response = await _post(
      '/auth/register',
      body: {
        'email': email,
        'password': password,
        'role': role.backendValue,
      },
      includeAuth: false,
    );

    return _parseAuthSession(_decodeAsMap(response), errorLabel: 'register');
  }

  void setToken(String token) {
    _accessToken = token;
  }

  void clearAuth() {
    _accessToken = null;
  }

  Future<UserProfile> getMyProfile() async {
    final response = await _get('/auth/me');
    return UserProfile.fromJson(_decodeAsMap(response));
  }

  Future<UserProfile> updateMyProfile({
    required String email,
    String? currentPassword,
    String? newPassword,
  }) async {
    final body = <String, dynamic>{
      'email': email.trim(),
    };
    if (currentPassword != null && currentPassword.isNotEmpty) {
      body['currentPassword'] = currentPassword;
    }
    if (newPassword != null && newPassword.isNotEmpty) {
      body['newPassword'] = newPassword;
    }

    final response = await _patch('/auth/me', body: body);
    return UserProfile.fromJson(_decodeAsMap(response));
  }

  Future<void> setDriverAvailability(bool online) async {
    await _patch(
      '/drivers/me/availability',
      body: {'online': online},
    );
  }

  Future<void> updateDriverLocation({
    required double latitude,
    required double longitude,
  }) async {
    await _patch(
      '/drivers/me/location',
      body: {
        'latitude': latitude,
        'longitude': longitude,
      },
    );
  }

  Future<List<BackendOrder>> listOrders() async {
    final response = await _get('/orders');
    final decoded = _decodeAsList(response);
    return decoded.map(BackendOrder.fromJson).toList(growable: false);
  }

  Future<BackendOrder> createOrder({
    required String passengerId,
    String? cityId,
    required double pickupLatitude,
    required double pickupLongitude,
    required double dropoffLatitude,
    required double dropoffLongitude,
    required double distanceKm,
    required double durationMinutes,
    required double surgeMultiplier,
  }) async {
    final body = <String, dynamic>{
      'passengerId': passengerId,
      'pickupLatitude': pickupLatitude,
      'pickupLongitude': pickupLongitude,
      'dropoffLatitude': dropoffLatitude,
      'dropoffLongitude': dropoffLongitude,
      'distanceKm': distanceKm,
      'durationMinutes': durationMinutes,
      'surgeMultiplier': surgeMultiplier,
    };
    if (cityId != null && cityId.trim().isNotEmpty) {
      body['cityId'] = cityId.trim();
    }

    final response = await _post(
      '/orders',
      body: body,
    );
    return BackendOrder.fromJson(_decodeAsMap(response));
  }

  Future<RouteSnapshot> getRoute({
    required List<String> coordinates,
  }) async {
    if (coordinates.length < 2) {
      throw Exception('At least 2 coordinates are required');
    }

    final encoded = Uri.encodeQueryComponent(coordinates.join(';'));
    final response = await _get('/routing/route?coordinates=$encoded');
    return RouteSnapshot.fromJson(_decodeAsMap(response));
  }

  Future<List<GeocodeSuggestionResult>> searchGeocode({
    required String query,
    int limit = 5,
    String? lang,
    String? countryCode,
    String? viewBox,
  }) async {
    final params = <String, String>{
      'q': query,
      'limit': limit.toString(),
    };
    if (lang != null && lang.trim().isNotEmpty) {
      params['lang'] = lang.trim();
    }
    if (countryCode != null && countryCode.trim().isNotEmpty) {
      params['countryCode'] = countryCode.trim().toLowerCase();
    }
    if (viewBox != null && viewBox.trim().isNotEmpty) {
      params['viewBox'] = viewBox.trim();
    }

    final uri = Uri.parse('$baseUrl/routing/geocode/search').replace(
      queryParameters: params,
    );
    final response = await _client.get(
      uri,
      headers: _headers(includeAuth: false),
    );
    final decoded = _decodeAsList(response);
    return decoded
        .map(GeocodeSuggestionResult.fromJson)
        .toList(growable: false);
  }

  Future<ReverseGeocodeResult?> reverseGeocode({
    required double latitude,
    required double longitude,
    String? lang,
  }) async {
    final params = <String, String>{
      'latitude': latitude.toStringAsFixed(6),
      'longitude': longitude.toStringAsFixed(6),
    };
    if (lang != null && lang.trim().isNotEmpty) {
      params['lang'] = lang.trim();
    }

    final uri = Uri.parse('$baseUrl/routing/geocode/reverse').replace(
      queryParameters: params,
    );
    final response = await _client.get(
      uri,
      headers: _headers(includeAuth: false),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('API ${response.statusCode}: ${response.body}');
    }

    final raw = response.body.trim();
    if (raw == 'null' || raw.isEmpty) {
      return null;
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Unexpected reverse geocode response: ${response.body}');
    }

    return ReverseGeocodeResult.fromJson(decoded);
  }

  Future<BackendOrder> searchDriver(String orderId) async {
    final response = await _post('/orders/$orderId/search-driver');
    return BackendOrder.fromJson(_decodeAsMap(response));
  }

  Future<BackendOrder> getOrder(String orderId) async {
    final response = await _get('/orders/$orderId');
    return BackendOrder.fromJson(_decodeAsMap(response));
  }

  Future<List<NearbyDriver>> listNearbyDrivers({
    required double latitude,
    required double longitude,
    double radiusKm = 5,
    int limit = 20,
  }) async {
    final uri = Uri.parse('$baseUrl/drivers/nearby').replace(
      queryParameters: <String, String>{
        'latitude': latitude.toStringAsFixed(6),
        'longitude': longitude.toStringAsFixed(6),
        'radiusKm': radiusKm.toStringAsFixed(2),
        'limit': limit.toString(),
      },
    );
    final response = await _client.get(
      uri,
      headers: _headers(includeAuth: true),
    );
    final decoded = _decodeAsList(response);
    return decoded.map(NearbyDriver.fromJson).toList(growable: false);
  }

  Future<BackendOrder> updateOrderStatus(String orderId, String status) async {
    final response = await _patch(
      '/orders/$orderId/status',
      body: {'status': status},
    );
    return BackendOrder.fromJson(_decodeAsMap(response));
  }

  AuthSession _parseAuthSession(
    Map<String, dynamic> decoded, {
    required String errorLabel,
  }) {
    final token = (decoded['accessToken'] ?? '').toString();
    final userMap = (decoded['user'] as Map?)?.cast<String, dynamic>() ??
        <String, dynamic>{};

    if (token.isEmpty || userMap.isEmpty) {
      throw Exception('Invalid $errorLabel response');
    }

    final session = AuthSession(
      token: token,
      userId: (userMap['id'] ?? '').toString(),
      email: (userMap['email'] ?? '').toString(),
      role: AppRoleX.fromBackend((userMap['role'] ?? 'CLIENT').toString()),
    );

    _accessToken = token;
    return session;
  }

  Future<http.Response> _get(String path, {bool includeAuth = true}) {
    return _client.get(
      Uri.parse('$baseUrl$path'),
      headers: _headers(includeAuth: includeAuth),
    );
  }

  Future<http.Response> _post(String path,
      {Map<String, dynamic>? body, bool includeAuth = true}) {
    return _client.post(
      Uri.parse('$baseUrl$path'),
      headers: _headers(includeAuth: includeAuth),
      body: body == null ? null : jsonEncode(body),
    );
  }

  Future<http.Response> _patch(String path,
      {Map<String, dynamic>? body, bool includeAuth = true}) {
    return _client.patch(
      Uri.parse('$baseUrl$path'),
      headers: _headers(includeAuth: includeAuth),
      body: body == null ? null : jsonEncode(body),
    );
  }

  Map<String, String> _headers({required bool includeAuth}) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };

    if (includeAuth && _accessToken != null && _accessToken!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_accessToken';
    }

    return headers;
  }

  Map<String, dynamic> _decodeAsMap(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('API ${response.statusCode}: ${response.body}');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Unexpected API response: ${response.body}');
    }

    return decoded;
  }

  List<Map<String, dynamic>> _decodeAsList(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('API ${response.statusCode}: ${response.body}');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw Exception('Unexpected API list response: ${response.body}');
    }

    return decoded
        .whereType<Map>()
        .map(
            (item) => item.map((key, value) => MapEntry(key.toString(), value)))
        .toList(growable: false);
  }
}
