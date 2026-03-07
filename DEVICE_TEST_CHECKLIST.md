# Real Device Test Checklist (Android)

Run this checklist on at least one real Android phone before production release.

## Build and Install

- Install release APK or internal app bundle build
- Verify first launch and login flows

## Camera Capture Test

- Open citizen report wizard
- Capture road image from camera
- Confirm preview appears and flow advances correctly

## GPS Accuracy Test

- Fetch current location in report flow
- Compare coordinates to Google Maps current location
- Confirm permission-denied and GPS-disabled messages are user-friendly

## Firebase Storage Upload Test

- Submit report with image
- Confirm image URL exists in Firestore report document
- Verify image opens from Firebase Storage URL

## Push Notification Test

- Assign worker to report
- Update report status
- Verify push notifications arrive on target device
- Confirm in-app notification inbox updates unread/read state

## Worker Attendance Selfie Test

- Worker opens assigned task
- Tap Start Work
- Capture selfie + GPS
- Verify attendance entry written in Firestore with:
  - worker_id
  - task_id
  - check_in_time
  - latitude
  - longitude
  - selfie_image

## Map and Filters Test

- Open map screen with multiple reports
- Verify marker colors by status
- Verify filters (All/Road/Drainage/Garbage/Utility) work case-insensitively
- Confirm clustering behavior when report count > 50

## Performance Test

- Scroll report lists rapidly for 30-60 seconds
- Pan/zoom map repeatedly
- Confirm smooth interactions and no visible frame drops on 60Hz/90Hz/120Hz devices

## Haptic Behavior Test

- Test taps and submit actions in Ring mode
- Test in Vibration mode
- Test in Silent mode
- Confirm app respects system vibration settings

## Stability Test

- Keep app running for 15+ minutes across screens
- Confirm no crashes, freezes, or stuck loading states

## Final QA Signoff

- `flutter analyze` clean
- `flutter test` passing
- release APK install/run verified
- release AAB generated successfully
