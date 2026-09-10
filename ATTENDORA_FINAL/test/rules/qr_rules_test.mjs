import {
  initializeTestEnvironment, assertFails, assertSucceeds,
} from '@firebase/rules-unit-testing';
import { readFileSync } from 'node:fs';
import { doc, setDoc, getDoc, serverTimestamp, Timestamp } from 'firebase/firestore';

const PROJECT = 'attendora-qr-test';
let passed = 0, failed = 0; const results = [];
async function check(name, fn) {
  try { await fn(); passed++; results.push(`  PASS  ${name}`); }
  catch (e) { failed++; results.push(`  FAIL  ${name}\n          ${e.message.split('\n')[0]}`); }
}

const env = await initializeTestEnvironment({
  projectId: PROJECT,
  firestore: { host: '127.0.0.1', port: 8181, rules: readFileSync('../../firestore.rules', 'utf8') },
});

const future = Timestamp.fromDate(new Date(Date.now() + 60 * 60 * 1000));
const CURRENT = 'CURRENT_SECRET_TOKEN_aaaaaaaaaaaaaaaa';
const PREV    = 'PREVIOUS_SECRET_TOKEN_bbbbbbbbbbbbbbb';

await env.withSecurityRulesDisabled(async (ctx) => {
  const db = ctx.firestore();
  // A session created by the NEW app: signed codes required.
  await setDoc(doc(db, 'sessions/secure_session'), {
    teacherUid: 'teacher_1', institutionCode: 'INST_A', active: true,
    expiresAt: future, latitude: 0, longitude: 0, radiusMeters: 100,
    bypassLocation: true, requireSignedQr: true, subject: 'Maths',
  });
  await setDoc(doc(db, 'sessions/secure_session/secure/qr'), {
    token: CURRENT, prevToken: PREV, slot: 1, rotatedAt: serverTimestamp(),
  });
  // A session created by an OLD app: no flag, grace period applies.
  await setDoc(doc(db, 'sessions/legacy_session'), {
    teacherUid: 'teacher_1', institutionCode: 'INST_A', active: true,
    expiresAt: future, latitude: 0, longitude: 0, radiusMeters: 100,
    bypassLocation: true, subject: 'Physics',
  });
  await setDoc(doc(db, 'users/student_1'), { role: 'student', institutionCode: 'INST_A' });
  await setDoc(doc(db, 'users/teacher_1'), { role: 'teacher', approved: true, institutionCode: 'INST_A' });
});

const student = env.authenticatedContext('student_1').firestore();
const teacher = env.authenticatedContext('teacher_1').firestore();

const record = (extra) => ({
  uid: 'student_1', sessionId: 'secure_session', status: 'present',
  distanceMeters: 5, timestamp: serverTimestamp(), ...extra,
});

console.log('\n=== QR replay / forgery resistance ===');

await check('student CANNOT read the rotating secret', () =>
  assertFails(getDoc(doc(student, 'sessions/secure_session/secure/qr'))));

await check('attendance WITHOUT a token is rejected on a secured session', () =>
  assertFails(setDoc(doc(student, 'sessions/secure_session/attendance/student_1'),
    record({}))));

await check('attendance with a GUESSED/forged token is rejected', () =>
  assertFails(setDoc(doc(student, 'sessions/secure_session/attendance/student_1'),
    record({ qrToken: 'made-up-token' }))));

await check('attendance with a STALE (two rotations old) token is rejected', () =>
  assertFails(setDoc(doc(student, 'sessions/secure_session/attendance/student_1'),
    record({ qrToken: 'OLD_SECRET_TOKEN_from_two_rotations_ago' }))));

await check('attendance with the CURRENT token succeeds', () =>
  assertSucceeds(setDoc(doc(student, 'sessions/secure_session/attendance/student_1'),
    record({ qrToken: CURRENT }))));

await check('attendance with the PREVIOUS token succeeds (flip tolerance)', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'users/student_2'), { role: 'student', institutionCode: 'INST_A' });
  });
  const s2 = env.authenticatedContext('student_2').firestore();
  await assertSucceeds(setDoc(doc(s2, 'sessions/secure_session/attendance/student_2'),
    { ...record({ qrToken: PREV }), uid: 'student_2' }));
});

console.log('\n=== grace period for not-yet-updated clients ===');

await check('legacy session still accepts an unsigned write', () =>
  assertSucceeds(setDoc(doc(student, 'sessions/legacy_session/attendance/student_1'),
    { uid: 'student_1', sessionId: 'legacy_session', status: 'present',
      distanceMeters: 5, timestamp: serverTimestamp() })));

console.log('\n=== secret publication is teacher-only ===');

await check('student CANNOT publish a QR secret (which would let them mint codes)', () =>
  assertFails(setDoc(doc(student, 'sessions/secure_session/secure/qr'),
    { token: 'attacker-chosen', rotatedAt: serverTimestamp() })));

await check('owning teacher CAN rotate the secret', () =>
  assertSucceeds(setDoc(doc(teacher, 'sessions/secure_session/secure/qr'),
    { token: 'next-token', prevToken: CURRENT, slot: 2, rotatedAt: serverTimestamp() })));

console.log(results.join('\n'));
console.log(`\n${passed} passed, ${failed} failed\n`);
await env.cleanup();
process.exit(failed === 0 ? 0 : 1);
