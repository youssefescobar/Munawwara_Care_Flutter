/// A point of interest on the pilgrim Explore screen (near the user’s location).
///
/// [cardImageUrl]: Mapbox **satellite** thumbnail for [landmarks] only; for other
/// categories a **chain favicon** URL (from [brandName] and/or venue [name]).
class ExplorePlace {
  final String sourceRef;
  final String name;
  final String categoryKey;
  final double latitude;
  final double longitude;

  /// Chain / operator label from Mapbox or OSM `brand` / `operator` tags.
  final String? brandName;

  /// Network image for the card header, or null → gradient + category icon.
  final String? cardImageUrl;

  const ExplorePlace({
    required this.sourceRef,
    required this.name,
    required this.categoryKey,
    required this.latitude,
    required this.longitude,
    this.brandName,
    this.cardImageUrl,
  });
}
