import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../../features/pilgrim/models/explore_place.dart';
import '../utils/app_logger.dart';
import 'explore_brand_logo.dart';
import 'explore_geo.dart';

/// Mapbox Geocoding (POI) for Explore; **satellite Static Images** only for
/// landmark thumbnails (billable per Mapbox pricing).
///
/// Search is scoped to a **bbox around the user** (not a fixed city).
/// https://docs.mapbox.com/api/search/geocoding/
/// https://docs.mapbox.com/api/maps/static-images/
class MapboxExploreService {
  MapboxExploreService._();

  static String? get _token {
    final t = dotenv.env['MAPBOX_ACCESS_TOKEN']?.trim();
    if (t == null || t.isEmpty) return null;
    return t;
  }

  static bool get isConfigured => _token != null;

  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 20),
    ),
  );

  /// Satellite snapshot centered on [lon],[lat] (landmark cards only).
  static String? satelliteThumbnailUrl(
    double lon,
    double lat, {
    int zoom = 17,
    int width = 400,
    int height = 280,
  }) {
    final token = _token;
    if (token == null) return null;
    final path =
        '/styles/v1/mapbox/satellite-v9/static/$lon,$lat,$zoom/${width}x$height@2x';
    return Uri.https('api.mapbox.com', path, <String, String>{
      'access_token': token,
    }).toString();
  }

  static String _categoryKey(String? category, String? maki) {
    final c = '${category ?? ''},${maki ?? ''}'.toLowerCase();
    if (c.contains('pharmacy') || c.contains('hospital')) return 'pharmacy';
    if (c.contains('restaurant') ||
        c.contains('food') ||
        c.contains('cafe') ||
        c.contains('bakery') ||
        c.contains('fast_food')) {
      return 'food';
    }
    if (c.contains('shop') ||
        c.contains('store') ||
        c.contains('mall') ||
        c.contains('supermarket') ||
        c.contains('market')) {
      return 'shopping';
    }
    return 'landmarks';
  }

  static ExplorePlace? _featureToPlace(Map<String, dynamic> f) {
    final props = f['properties'];
    if (props is! Map) return null;
    final p = Map<String, dynamic>.from(props);
    final geom = f['geometry'];
    if (geom is! Map) return null;
    final g = Map<String, dynamic>.from(geom);
    if (g['type'] != 'Point') return null;
    final coords = g['coordinates'] as List<dynamic>?;
    if (coords == null || coords.length < 2) return null;
    final lon = (coords[0] as num).toDouble();
    final lat = (coords[1] as num).toDouble();
    final name = (p['name'] as String?)?.trim() ??
        (p['text'] as String?)?.trim() ??
        '';
    if (name.isEmpty) return null;
    final id = f['id']?.toString() ?? p['mapbox_id']?.toString() ?? 'poi';
    final cat = _categoryKey(
      p['category'] as String?,
      p['maki'] as String?,
    );
    final brandRaw = (p['brand'] as String?)?.trim();
    final opRaw = (p['operator'] as String?)?.trim();
    final brandName = (brandRaw != null && brandRaw.isNotEmpty)
        ? brandRaw
        : opRaw;
    final String? cardUrl = cat == 'landmarks'
        ? satelliteThumbnailUrl(lon, lat)
        : ExploreBrandLogo.chainLogoUrl(brand: brandName, venueName: name);
    return ExplorePlace(
      sourceRef: 'mapbox/$id',
      name: name,
      categoryKey: cat,
      latitude: lat,
      longitude: lon,
      brandName: brandName,
      cardImageUrl: cardUrl,
    );
  }

  static Future<List<Map<String, dynamic>>> _forwardPoi(
    String query, {
    required String proximity,
    required String bbox,
  }) async {
    final token = _token;
    if (token == null) return [];

    final encoded = Uri.encodeComponent(query);
    final uri = Uri.https(
      'api.mapbox.com',
      '/geocoding/v5/mapbox.places/$encoded.json',
      <String, String>{
        'access_token': token,
        'bbox': bbox,
        'types': 'poi',
        'limit': '12',
        'proximity': proximity,
      },
    );

    final resp = await _dio.get<String>(
      uri.toString(),
      options: Options(responseType: ResponseType.plain),
    );
    final body = resp.data;
    if (body == null || body.isEmpty) return [];
    final map = jsonDecode(body) as Map<String, dynamic>;
    final features = map['features'] as List<dynamic>? ?? [];
    final out = <Map<String, dynamic>>[];
    for (final e in features) {
      if (e is Map) out.add(Map<String, dynamic>.from(e));
    }
    return out;
  }

  /// POI queries merged + deduped, biased to [centerLat],[centerLng].
  static Future<List<ExplorePlace>> fetchNearbyPlaces({
    required double centerLat,
    required double centerLng,
  }) async {
    if (!isConfigured) return [];

    final bbox = ExploreGeo.mapboxBbox(
      centerLat,
      centerLng,
      ExploreGeo.defaultRadiusKm,
    );
    final proximity = '$centerLng,$centerLat';

    const queries = [
      'restaurant',
      'cafe',
      'pharmacy',
      'supermarket',
      'mosque',
      'shopping mall',
    ];

    final merged = <Map<String, dynamic>>[];
    for (final q in queries) {
      try {
        final batch = await _forwardPoi(
          q,
          proximity: proximity,
          bbox: bbox,
        );
        merged.addAll(batch);
        await Future<void>.delayed(const Duration(milliseconds: 120));
      } catch (e, st) {
        AppLogger.w('MapboxExploreService query "$q" failed: $e');
        AppLogger.d('$st');
      }
    }

    final out = <ExplorePlace>[];
    final seen = <String>{};
    for (final f in merged) {
      final p = _featureToPlace(f);
      if (p == null) continue;
      final key =
          '${p.latitude.toStringAsFixed(5)}_${p.longitude.toStringAsFixed(5)}_${p.name}';
      if (seen.add(key)) out.add(p);
    }
    return out;
  }

  static Future<List<ExplorePlace>> searchNearby(
    String q, {
    required double centerLat,
    required double centerLng,
  }) async {
    if (!isConfigured) return [];
    final query = q.trim();
    if (query.length < 2) return [];

    final bbox = ExploreGeo.mapboxBbox(
      centerLat,
      centerLng,
      ExploreGeo.searchRadiusKm,
    );
    final proximity = '$centerLng,$centerLat';

    try {
      final features = await _forwardPoi(
        query,
        proximity: proximity,
        bbox: bbox,
      );
      final out = <ExplorePlace>[];
      final seen = <String>{};
      for (final f in features) {
        final p = _featureToPlace(f);
        if (p == null) continue;
        if (seen.add(p.sourceRef)) out.add(p);
      }
      return out;
    } catch (e, st) {
      AppLogger.e('MapboxExploreService.searchNearby', e, st);
      rethrow;
    }
  }
}
