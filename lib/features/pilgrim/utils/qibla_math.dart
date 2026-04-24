import 'dart:math' as math;

/// All maths needed to compute the Qibla direction and related values.
class QiblaMath {
  // Precise Kaaba geocentric centroid.
  static const double kaabaLat = 21.422487;
  static const double kaabaLng = 39.826206;

  // ── Bearing ─────────────────────────────────────────────────────────────

  /// True-north great-circle bearing [0, 360) from the given position to the Kaaba.
  ///
  /// Forward azimuth formula:
  ///   dLon = lon2 - lon1
  ///   theta = atan2(sin(dLon)·cos(lat2),
  ///                 cos(lat1)·sin(lat2) − sin(lat1)·cos(lat2)·cos(dLon))
  static double bearingToKaaba(double lat, double lng) {
    final lat1 = _toRad(lat);
    final lat2 = _toRad(kaabaLat);
    final dLon = _toRad(kaabaLng - lng);

    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);

    return normalize360(_toDeg(math.atan2(y, x)));
  }

  // ── Distance ────────────────────────────────────────────────────────────

  /// Haversine distance in kilometres from the given position to the Kaaba.
  static double distanceToKaabaKm(double lat, double lng) {
    const earthRadiusKm = 6371.0;
    final dLat = _toRad(kaabaLat - lat);
    final dLon = _toRad(kaabaLng - lng);
    final lat1 = _toRad(lat);
    final lat2 = _toRad(kaabaLat);

    final a = _sq(math.sin(dLat / 2)) +
        math.cos(lat1) * math.cos(lat2) * _sq(math.sin(dLon / 2));
    return earthRadiusKm * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  // ── Angle helpers ────────────────────────────────────────────────────────

  /// Maps any angle into [0, 360).
  static double normalize360(double angle) {
    final n = angle % 360.0;
    return n < 0 ? n + 360.0 : n;
  }

  /// Signed shortest arc from [from] to [to] in degrees, range [-180, 180].
  /// Positive = clockwise, negative = counter-clockwise.
  static double shortestDelta(double from, double to) =>
      (to - from + 540.0) % 360.0 - 180.0;

  /// Circular low-pass filter. [alpha] ∈ (0, 1]: higher = snappier.
  /// Handles the 0°/360° discontinuity correctly.
  static double smoothAngle(double current, double target, double alpha) {
    final delta = shortestDelta(current, target);
    return normalize360(current + alpha * delta);
  }

  /// Adaptive alpha for compass smoothing.
  /// Large movements snap faster; small jitter is filtered heavily.
  static double adaptiveAlpha(double absDelta) {
    if (absDelta > 45) return 0.40;
    if (absDelta > 20) return 0.28;
    if (absDelta > 8) return 0.18;
    return 0.10;
  }

  // ── Screen-space angles ──────────────────────────────────────────────────

  /// Clockwise angle from screen-up at which the Qibla needle should be drawn.
  ///
  /// When heading == qiblaBearing the result is 0° (needle points straight up),
  /// meaning the phone is aimed directly at the Kaaba.
  static double qiblaScreenAngle(double qiblaBearing, double phoneHeading) =>
      normalize360(qiblaBearing - phoneHeading);

  /// Rotation to apply to the compass dial so N/E/S/W labels stay in their
  /// real-world positions as the phone rotates.
  static double dialRotation(double phoneHeading) => -phoneHeading;

  // ── Text helpers ─────────────────────────────────────────────────────────

  /// 8-point cardinal abbreviation for [deg].
  static String cardinal(double deg) {
    const dirs = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    return dirs[((normalize360(deg) / 45).round()) % 8];
  }

  // ── Private ──────────────────────────────────────────────────────────────

  static double _toRad(double deg) => deg * math.pi / 180.0;
  static double _toDeg(double rad) => rad * 180.0 / math.pi;
  static double _sq(double x) => x * x;
}
