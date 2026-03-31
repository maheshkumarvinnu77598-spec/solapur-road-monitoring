<<<<<<< HEAD
# Solapur Admin Dashboard

Separate Flutter Web admin dashboard for the **Solapur Road Monitoring** backend.

## Stack
- Flutter Web
- Firebase Auth
- Cloud Firestore
- Google Maps (Flutter Web)

## Setup
1. Install dependencies:
   ```bash
   flutter pub get
   ```
2. Login Firebase CLI:
   ```bash
   firebase login --no-localhost
   ```
3. Generate real FlutterFire config for web:
   ```bash
   flutterfire configure --project=solapur-road-monitoring --platforms=web
   ```
4. Replace Google Maps key in `web/index.html`:
   - `REPLACE_WITH_GOOGLE_MAPS_WEB_API_KEY`
5. Run:
   ```bash
   flutter run -d chrome
   ```

## Access control
Only users with `role = "admin"` in `users/{uid}` can access the dashboard.
=======
# solapur_admin_dashboard

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
>>>>>>> 0957bededdaab9cc21b7e75c4984775a3603902c
