const crypto = require('crypto');
const admin = require('firebase-admin');
const {onDocumentCreated} = require('firebase-functions/v2/firestore');
const {onCall, HttpsError} = require('firebase-functions/v2/https');

admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();

function hashWorkerPassword(workerId, password) {
  return crypto
      .createHash('sha256')
      .update(`${workerId.trim().toUpperCase()}::${password}`)
      .digest('hex');
}

async function ensureAdmin(context) {
  if (!context.auth) {
    throw new HttpsError('unauthenticated', 'Sign in required.');
  }

  if (context.auth.token.role === 'admin') {
    return;
  }

  const userDoc = await db.collection('users').doc(context.auth.uid).get();
  const role = String(userDoc.data()?.role || '').toLowerCase();
  if (role !== 'admin') {
    throw new HttpsError('permission-denied', 'Admin access required.');
  }
}

async function nextWorkerId() {
  const counterRef = db.collection('counters').doc('workers');
  return db.runTransaction(async (tx) => {
    const snap = await tx.get(counterRef);
    const current = Number(snap.data()?.last_worker_seq || 1000);
    const next = current + 1;
    tx.set(counterRef, {last_worker_seq: next}, {merge: true});
    return `WRK${next}`;
  });
}

function pointInPolygon(point, polygon) {
  let inside = false;
  for (let i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
    const xi = polygon[i].lat;
    const yi = polygon[i].lng;
    const xj = polygon[j].lat;
    const yj = polygon[j].lng;

    const intersect = ((yi > point.lng) !== (yj > point.lng)) &&
      (point.lat < ((xj - xi) * (point.lng - yi)) / ((yj - yi) + 0.0000001) + xi);
    if (intersect) {
      inside = !inside;
    }
  }
  return inside;
}

exports.createWorkerAccount = onCall(async (request) => {
  await ensureAdmin(request);

  const data = request.data || {};
  const name = String(data.name || '').trim();
  const phone = String(data.phone || '').trim();
  const zone = String(data.zone || '').trim();
  const password = String(data.password || '').trim();
  const photoUrl = String(data.photo_url || '').trim();

  if (!name || !phone || !zone || !password) {
    throw new HttpsError('invalid-argument', 'name, phone, zone and password are required.');
  }

  const workerId = await nextWorkerId();
  const passwordHash = hashWorkerPassword(workerId, password);
  const workerRef = db.collection('workers').doc();

  await workerRef.set({
    worker_id: workerId,
    name,
    phone,
    zone,
    photo_url: photoUrl,
    role: 'worker',
    password_hash: passwordHash,
    credibility_score: 100,
    completed_tasks: 0,
    pending_tasks: 0,
    failed_attempts: 0,
    lockout_until: null,
    fcm_tokens: [],
    created_at: admin.firestore.FieldValue.serverTimestamp(),
  });

  return {doc_id: workerRef.id, worker_id: workerId};
});

exports.workerLogin = onCall(async (request) => {
  const data = request.data || {};
  const workerId = String(data.workerId || '').trim().toUpperCase();
  const password = String(data.password || '').trim();

  if (!workerId || !password) {
    throw new HttpsError('invalid-argument', 'workerId and password are required.');
  }

  const query = await db
      .collection('workers')
      .where('worker_id', '==', workerId)
      .limit(1)
      .get();

  if (query.empty) {
    throw new HttpsError('not-found', 'Worker not found.');
  }

  const doc = query.docs[0];
  const worker = doc.data();
  const lockoutUntil = worker.lockout_until?.toDate ? worker.lockout_until.toDate() : null;
  if (lockoutUntil && lockoutUntil.getTime() > Date.now()) {
    throw new HttpsError('resource-exhausted', 'Too many failed attempts. Try again later.');
  }

  const expected = String(worker.password_hash || '');
  const provided = hashWorkerPassword(workerId, password);

  if (!expected || expected !== provided) {
    const nextFailed = Number(worker.failed_attempts || 0) + 1;
    const updates = {failed_attempts: nextFailed};
    if (nextFailed >= 5) {
      updates.lockout_until = admin.firestore.Timestamp.fromDate(
          new Date(Date.now() + (15 * 60 * 1000)),
      );
      updates.failed_attempts = 0;
    }
    await doc.ref.set(updates, {merge: true});
    throw new HttpsError('permission-denied', 'Invalid worker credentials.');
  }

  await doc.ref.set({
    failed_attempts: 0,
    lockout_until: null,
    last_login_at: admin.firestore.FieldValue.serverTimestamp(),
  }, {merge: true});

  const authUid = `worker_${doc.id}`;
  try {
    await admin.auth().getUser(authUid);
  } catch (error) {
    await admin.auth().createUser({uid: authUid, displayName: worker.name || workerId});
  }

  await admin.auth().setCustomUserClaims(authUid, {
    role: 'worker',
    worker_doc_id: doc.id,
    worker_id: workerId,
  });

  const token = await admin.auth().createCustomToken(authUid, {
    role: 'worker',
    worker_doc_id: doc.id,
    worker_id: workerId,
  });

  return {
    token,
    worker: {
      doc_id: doc.id,
      worker_id: workerId,
      name: worker.name || '',
      phone: worker.phone || '',
      zone: worker.zone || '',
      email: worker.email || null,
    },
  };
});

exports.sendPushForNotification = onDocumentCreated('notifications/{notificationId}', async (event) => {
  const notification = event.data?.data();
  if (!notification) {
    return;
  }

  const userId = String(notification.user_id || '').trim();
  if (!userId) {
    return;
  }

  const usersDoc = await db.collection('users').doc(userId).get();
  const workersDoc = await db.collection('workers').doc(userId).get();

  const userTokens = Array.isArray(usersDoc.data()?.fcm_tokens) ? usersDoc.data().fcm_tokens : [];
  const workerTokens = Array.isArray(workersDoc.data()?.fcm_tokens) ? workersDoc.data().fcm_tokens : [];
  const tokens = [...new Set([...userTokens, ...workerTokens].filter(Boolean))];

  if (tokens.length === 0) {
    return;
  }

  const response = await messaging.sendEachForMulticast({
    tokens,
    notification: {
      title: String(notification.title || 'Solapur Road Monitoring'),
      body: String(notification.body || ''),
    },
    data: {
      report_id: String(notification.report_id || ''),
      type: 'report_update',
    },
  });

  const invalidTokens = [];
  response.responses.forEach((r, i) => {
    if (!r.success) {
      const code = r.error?.code || '';
      if (
        code.includes('registration-token-not-registered') ||
        code.includes('invalid-argument')
      ) {
        invalidTokens.push(tokens[i]);
      }
    }
  });

  if (invalidTokens.length > 0) {
    await Promise.all([
      db.collection('users').doc(userId).set({
        fcm_tokens: admin.firestore.FieldValue.arrayRemove(...invalidTokens),
      }, {merge: true}),
      db.collection('workers').doc(userId).set({
        fcm_tokens: admin.firestore.FieldValue.arrayRemove(...invalidTokens),
      }, {merge: true}),
    ]);
  }
});

exports.autoAssignReportByZone = onDocumentCreated('reports/{reportId}', async (event) => {
  const report = event.data?.data();
  if (!report) {
    return;
  }

  const latitude = Number(report.latitude || 0);
  const longitude = Number(report.longitude || 0);
  const reportId = event.params.reportId;
  if (!latitude || !longitude) {
    return;
  }

  const zones = await db.collection('zones').get();
  for (const zoneDoc of zones.docs) {
    const zone = zoneDoc.data();
    const assignedWorker = String(zone.assigned_worker || '').trim();
    const polygon = Array.isArray(zone.polygon_coordinates) ? zone.polygon_coordinates : [];
    if (!assignedWorker || polygon.length < 3) {
      continue;
    }

    const points = polygon
        .filter((p) => p && typeof p.lat === 'number' && typeof p.lng === 'number')
        .map((p) => ({lat: Number(p.lat), lng: Number(p.lng)}));
    if (points.length < 3) {
      continue;
    }

    if (!pointInPolygon({lat: latitude, lng: longitude}, points)) {
      continue;
    }

    await db.collection('reports').doc(reportId).set({
      assigned_worker: assignedWorker,
      status: 'Assigned',
      assigned_at: admin.firestore.FieldValue.serverTimestamp(),
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    }, {merge: true});

    await db.collection('workers').doc(assignedWorker).set({
      pending_tasks: admin.firestore.FieldValue.increment(1),
    }, {merge: true});

    const reporterId = String(report.reporter_id || '').trim();
    if (reporterId) {
      await db.collection('notifications').add({
        user_id: reporterId,
        title: 'Issue Assigned',
        body: 'Your reported issue has been assigned to a worker.',
        report_id: reportId,
        read: false,
        is_read: false,
        created_at: admin.firestore.FieldValue.serverTimestamp(),
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    await db.collection('notifications').add({
      user_id: assignedWorker,
      title: 'New Task Assigned',
      body: 'A new issue has been assigned to you.',
      report_id: reportId,
      read: false,
      is_read: false,
      created_at: admin.firestore.FieldValue.serverTimestamp(),
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });
    return;
  }
});
