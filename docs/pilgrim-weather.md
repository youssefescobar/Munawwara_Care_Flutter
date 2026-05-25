# Pilgrim dashboard weather

## Purpose

The home-tab weather card shows local temperature, condition, and Hajj-relevant
tips (hydration, sun, rain, dust, etc.) for the pilgrim's **current device
location**.

## Data source

- API: [Open-Meteo](https://open-meteo.com/) (`/v1/forecast`)
- Fields: `temperature_2m`, `weather_code` (WMO), `is_day`
- Implementation: `PilgrimDashboardScreen._loadWeatherAlert` in
  `lib/features/pilgrim/screens/pilgrim_dashboard_screen.dart`

## Location rules

1. Weather always uses GPS coordinates from the device (explicit fix,
   `_myLatLng`, or a one-shot `Geolocator.getCurrentPosition`).
2. **No city fallback** (e.g. Mecca) — showing another city's weather is
   misleading; the card stays in loading until a fix is available.
3. Refresh is skipped only when the last fetch was within 5 minutes **and**
   the device moved less than ~1.5 km.
4. Dashboard warmup **awaits** `_initLocation()` before the first weather fetch
   so startup does not race ahead of the first GPS fix.

## UI

- Card: `WeatherCard` in `lib/features/pilgrim/widgets/home_tab/home_cards.dart`
- Detail sheet: `showWeatherDetailBottomSheet`
- Errors use `SelectableText.rich` styling in the detail sheet; the card shows
  a short unavailable message.
