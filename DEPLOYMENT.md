# Firebase Deployment Guide

This project uses Firebase for Authentication, Firestore, Storage, and Cloud Messaging.

## 1. Install Firebase CLI

```bash
npm install -g firebase-tools
```

## 2. Login to Firebase

```bash
firebase login
```

## 3. Select the Correct Project

```bash
firebase use <your-firebase-project-id>
```

Use the existing project used by this app. Do not create a new Firebase project.

## 4. Deploy Firestore Security Rules

```bash
firebase deploy --only firestore:rules
```

What this does:
- Publishes `firestore.rules` to Firebase
- Enforces role-based access control in production
- Protects report/task/attendance data from unauthorized writes

## 5. Deploy Firestore Composite Indexes

```bash
firebase deploy --only firestore:indexes
```

What this does:
- Publishes `firestore.indexes.json`
- Enables optimized compound queries for maps, notifications, and reporting lists
- Prevents runtime `FAILED_PRECONDITION` index errors

## 6. Deploy Firebase Storage Rules

```bash
firebase deploy --only storage:rules
```

What this does:
- Publishes `storage.rules`
- Restricts upload/download access for report, repair, and attendance images

## 7. Optional Full Deploy

```bash
firebase deploy
```

Use this only when you want to deploy all configured Firebase resources together.

## 8. Verify Deployment

After deployment:
- Open Firebase Console
- Confirm latest publish timestamp for Rules/Indexes
- Test user flows (citizen report, worker attendance, admin status update)
