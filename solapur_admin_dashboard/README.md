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
