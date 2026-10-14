// Seeds a small, realistic class so the teacher "detain" flow can be driven
// end to end. Admin SDK bypasses rules, so the real rules stay loaded.
process.env.FIRESTORE_EMULATOR_HOST = '127.0.0.1:8180';
process.env.FIREBASE_AUTH_EMULATOR_HOST = '127.0.0.1:9099';
import { initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore, Timestamp } from 'firebase-admin/firestore';

// Auth emulator is single-project (the CLI --project); Firestore is keyed by
// the app's real project id.
const auth = getAuth(initializeApp({ projectId: 'attendora-local' }, 'a'));
const db = getFirestore(initializeApp({ projectId: 'attendora-a0fc5' }, 'f'));
const INST = 'DEMO';

async function user(email, idNumber, displayName, role, extra = {}) {
  let uid;
  try { uid = (await auth.getUserByEmail(email)).uid; }
  catch { uid = (await auth.createUser({ email, password: 'password123', emailVerified: true })).uid; }
  await db.collection('users').doc(uid).set({
    email, idNumber, displayName, role, admin: false, approved: true,
    institutionCode: INST, loginEnabled: true, isSuperAdmin: false,
    createdAt: new Date().toISOString(), ...extra,
  }, { merge: true });
  return uid;
}

await db.collection('institutions').doc(INST).set({ code: INST, name: 'Demo Institute', active: true, domain: 'demo.edu' });
await db.collection('class_groups').doc('G1').set({
  name: 'G1', type: 'Lecture', institutionCode: INST, teacherUids: [], studentUids: [], subjectIds: [],
  createdAt: Timestamp.now(),
});

const teacher = await user('teacher@demo.edu', 'TEACH001', 'Demo Teacher', 'teacher');
const good = await user('good@demo.edu', 'STU001', 'Asha Good (100%)', 'student', { lectureGroup: 'G1' });
const mid = await user('mid@demo.edu', 'STU002', 'Bikash Mid (50%)', 'student', { lectureGroup: 'G1' });
const zero = await user('zero@demo.edu', 'STU003', 'Chitra Zero (0%)', 'student', { lectureGroup: 'G1' });

await db.collection('subjects').doc('maths').set({
  name: 'Maths', group: 'G1', type: 'Lecture', teacherUid: teacher, institutionCode: INST,
  isArchived: false, code: 'MTH101',
});

// four held sessions; good attends all, mid attends two, zero attends none
const plan = [[good, mid], [good, mid], [good], [good]];
for (let i = 0; i < plan.length; i++) {
  const sid = `s${i + 1}`;
  const when = Timestamp.fromDate(new Date(Date.now() - (10 - i) * 86400000));
  await db.collection('sessions').doc(sid).set({
    teacherUid: teacher, institutionCode: INST, subject: 'Maths', group: 'G1', active: false,
    createdAt: when, expiresAt: when, latitude: 0, longitude: 0, radiusMeters: 50, attendeeUids: plan[i],
  });
  for (const uid of plan[i]) {
    await db.collection('sessions').doc(sid).collection('attendance').doc(uid).set({
      uid, sessionId: sid, status: 'present', subject: 'Maths', institutionCode: INST, timestamp: when,
    });
  }
}
console.log('seeded: TEACH001 / STU001 (100%) / STU002 (50%) / STU003 (0%), password123');
process.exit(0);
