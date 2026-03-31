# Solapur Road Monitoring Backend Contract

This document is the shared contract between:

- the Flutter mobile app in this repository
- the separate admin dashboard being developed on another machine
- Firebase backend resources

The goal is to prevent schema drift, broken status transitions, and incompatible notification or AI payloads.

## Stability Scope

Treat the following as stable unless both sides agree to a coordinated change:

- Firestore collection names
- document field names
- report status names
- notification payload keys
- worker assignment fields
- AI API request/response shape

## Collections

The system currently uses these top-level Firestore collections:

- `users`
- `workers`
- `reports`
- `attendance`
- `notifications`
- `zones`
- `counters`

## Roles

Supported roles:

- `citizen`
- `worker`
- `admin`

Role is stored in Firestore under `users/{uid}.role`.

Security rules also expect custom auth token fields for workers:

- `role = "worker"`
- `worker_doc_id = "<workers document id>"`

## Report Status Pipeline

These exact status values are used by the app and must remain unchanged:

1. `Reported`
2. `Assigned`
3. `In Progress`
4. `Under Review`
5. `Fixed`

Rules:

- Workers can move reports through field workflow stages they are assigned to.
- Workers must not mark a report as final municipal resolution on their own.
- Admin-side verification should be the step that confirms the report as `Fixed`.

Do not introduce alternate spellings like `Resolved`, `Done`, `Closed`, or lowercase variants without updating both clients and rules.

## `users` Collection

Document ID:

- Firebase Auth UID

Current fields used across the app:

- `uid`
- `name`
- `phone`
- `email`
- `role`
- `avatar_emoji`
- `photo_url`
- `phone_visible`
- `notifications_enabled`
- `created_at`
- `fcm_tokens`
- `last_token_sync_at`
- `reports_approved`
- `reports_rejected`
- `accuracy_score`

Citizen profile setup depends on:

- `name`
- `avatar_emoji`

## `workers` Collection

Document ID:

- Worker document id

Current fields used:

- `worker_id`
- `name`
- `phone`
- `photo_url`
- `zone`
- `password`
- `credibility_score`
- `assigned_tasks`
- `completed_tasks`
- `pending_tasks`
- `fcm_tokens`
- `last_token_sync_at`
- `created_at`

Notes:

- Mobile worker UI reads this collection directly.
- Admin dashboard must not rename `worker_id` or `credibility_score`.

## `reports` Collection

Document ID:

- Firestore-generated report id

Required fields:

- `report_id`
- `category`
- `description`
- `image_url`
- `latitude`
- `longitude`
- `priority`
- `status`
- `reporter_id`
- `assigned_worker`
- `repair_image`
- `repair_image_url`
- `report_count`
- `assigned_at`
- `started_at`
- `under_review_at`
- `resolved_at`
- `completion_timestamp`
- `sla_breach_flag`
- `verify_fixed_count`
- `verify_not_fixed_count`
- `image_hash`
- `image_captured_at`
- `ai_severity`
- `ai_confidence`
- `ai_boxes`
- `timestamp`

### Field Notes

- `priority` values currently expected:
  - `low`
  - `medium`
  - `high`
  - `critical`
- `assigned_worker` should store the worker document id.
- `report_count` is incremented when duplicate reports are merged/support is added.
- `repair_image` and `repair_image_url` are both present for compatibility.
- `timestamp` is used for sort order and activity recency.

### Supported Categories

Use these exact category labels:

- `Pothole`
- `Road Surface Damage`
- `Incomplete Road Work`
- `Damaged Footpath`
- `Water Logging`
- `Open Manhole / Drain Cover Damage`
- `Garbage Dumping`
- `Street Light Not Working`

## `reports/{reportId}/report_events` Subcollection

Used for audit logging.

Fields:

- `actor_id`
- `actor_role`
- `previous_status`
- `new_status`
- `timestamp`

## Attendance Data

Attendance exists in two places:

- top-level collection: `attendance`
- per-report subcollection: `reports/{reportId}/attendance`

Attendance fields:

- `worker_id`
- `task_id`
- `report_id`
- `check_in_time`
- `latitude`
- `longitude`
- `selfie_image`

The admin dashboard should treat top-level `attendance` as the source for analytics and worker-level views.

## Notifications

Top-level collection:

- `notifications`

Fields currently used:

- `user_id`
- `title`
- `body`
- `report_id`
- `type`
- `read`
- `is_read`
- `created_at`
- `timestamp`

Payload keys that must remain stable for push/deep-link handling:

- `title`
- `body`
- `report_id`
- `type`

Supported notification types in current flows:

- `Report Status Updated`
- `Worker Assigned`
- `Repair Verified`

## Zones

Collection:

- `zones`

Fields expected for auto-assignment:

- `zone_id`
- `polygon_coordinates`
- `assigned_worker`

## AI Detection Contract

AI is integrated as an external HTTP service. The model itself is not part of this repository.

Expected endpoint:

- `POST /predict`

Request:

- multipart form upload with field name `image`

Expected response JSON:

```json
{
  "category": "pothole",
  "severity": "high",
  "confidence": 0.91,
  "boxes": [
    { "x": 120, "y": 80, "width": 200, "height": 140 }
  ]
}
```

Compatibility note:

- The mobile app currently also accepts `issue` as a fallback key for category if the API does not return `category`.

If AI fails:

- the app falls back to the user-selected category

## Security Rules Expectations

Current rule intent:

- citizens can create their own reports
- workers can update only assigned tasks
- workers can create attendance for their own tasks
- admins can manage workers, assignments, and verification flows

When changing admin features, verify compatibility with:

- [firestore.rules](/Users/ajaykowkuntla/Desktop/solapur_road_monitoring/firestore.rules)

## Required Firestore Indexes

Current indexes defined in:

- [firestore.indexes.json](/Users/ajaykowkuntla/Desktop/solapur_road_monitoring/firestore.indexes.json)

Existing composite indexes:

1. `reports`
   - `latitude ASC`
   - `timestamp DESC`

2. `notifications`
   - `user_id ASC`
   - `timestamp DESC`

3. `reports`
   - `reporter_id ASC`
   - `timestamp DESC`

If the admin dashboard adds new filtered analytics queries, update indexes in this repository too.

## Change Control

Before either laptop changes the backend contract:

1. update this document
2. update code on both sides
3. update Firestore rules if needed
4. update indexes if query shape changes
5. validate with local test/build flows before deploy

## Coordination Rule

If the admin dashboard needs a new field or status:

- add it in a backward-compatible way first
- do not rename or remove existing fields until both clients have been updated and deployed
