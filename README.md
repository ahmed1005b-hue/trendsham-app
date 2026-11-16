# TrendSham Flutter

Flutter mobile app for the TrendSham multi-vendor marketplace. The app connects to the Laravel API configured in `lib/config/api_config.dart`.

## Requirements and startup

- Flutter SDK compatible with Dart 3.3 or newer
- Android emulator/device, or Xcode for iOS

```sh
flutter pub get
flutter run
```

For the Android emulator, the default API URL uses `10.0.2.2`. For a physical device, set the API host to an address reachable on your local network.

## Localization and appearance

The interface supports Arabic, English, and Turkish. Arabic uses Flutter's locale-driven right-to-left layout; English and Turkish use left-to-right layout. Language and appearance selections are saved on the device and restored on startup. Appearance can be set to Light, Dark, or Follow device. Change both preferences from **Profile > Language and Appearance**.

Flutter's Material, Widgets, and Cupertino localization delegates are enabled for localized platform controls and RTL behavior. Screen labels, form copy, and recognized app/API messages are translated through `lib/l10n/app_localizations.dart`. The legal pages include translated English and Turkish sections in `lib/l10n/legal_translations.dart`, alongside the Arabic source in `lib/config/legal_content.dart`. Arbitrary API-provided text that is not in the app's known-message catalog remains in the server's language; dynamic names and content are intentionally not translated.

## Project layout

- `lib/screens/` - customer, seller, administrator, and authentication screens
- `lib/widgets/` - shared interface components
- `lib/providers/` - app state, including persisted preferences
- `lib/services/` - API access
- `lib/config/` - API configuration and theme
- `test/` - widget and unit tests

Sellers can update their storefront logo, banner, name, and description from the seller dashboard. These details appear on the public store page.

## Validation

```sh
flutter analyze
flutter test
```
