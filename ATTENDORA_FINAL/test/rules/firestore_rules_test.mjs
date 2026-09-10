import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} from '@firebase/rules-unit-testing';
import { readFileSync } from 'node:fs';
import {
  doc, getDoc, setDoc, updateDoc, deleteDoc, serverTimestamp,
} from 'firebase/firestore';

const PROJECT = 'attendora-rules-test';
let passed = 0, failed = 0;
const results = [];

async function check(name, fn) {
  try {
    await fn();
    passed++; results.push(`  PASS  ${name}`);
  } catch (e) {
    failed++; results.push(`  FAIL  ${name}\n          ${e.message.split('\n')[0]}`);
  }
}

const env = await initializeTestEnvironment({
  projectId: PROJECT,
  firestore: {
    host: '127.0.0.1',
    port: 8181,
    rules: readFileSync('../../firestore.rules', 'utf8'),
  },
});

// ---- seed data, bypassing rules ------------------------------------------
await env.withSecurityRulesDisabled(async (ctx) => {
  const db = ctx.firestore();
  await setDoc(doc(db, 'users/admin_a'), {
    role: 'admin', admin: true, institutionCode: 'INST_A',
    email: 'admin@a.edu', displayName: 'Admin A',
  });
  await setDoc(doc(db, 'users/admin_b'), {
    role: 'admin', admin: true, institutionCode: 'INST_B',
    email: 'admin@b.edu', displayName: 'Admin B',
  });
  await setDoc(doc(db, 'users/teacher_pending'), {
    role: 'teacher', approved: false, institutionCode: 'INST_A',
    email: 't1@a.edu', displayName: 'Pending Teacher',
  });
  // Legacy doc with NO institutionCode - the case that used to hard-fail.
  await setDoc(doc(db, 'users/teacher_legacy'), {
    role: 'teacher', approved: false,
    email: 't2@a.edu', displayName: 'Legacy Teacher',
  });
  await setDoc(doc(db, 'users/student_1'), {
    role: 'student', approved: true, institutionCode: 'INST_A',
    idNumber: '101', email: 's1@a.edu', registeredDeviceId: 'device-abc',
  });
  await setDoc(doc(db, 'users/student_2'), {
    role: 'student', approved: true, institutionCode: 'INST_A',
    idNumber: '102', email: 's2@a.edu',
  });
  await setDoc(doc(db, 'id_index/101'), { uid: 'student_1', institutionCode: 'INST_A' });
});

const adminA = env.authenticatedContext('admin_a', { email: 'admin@a.edu' }).firestore();
const adminB = env.authenticatedContext('admin_b', { email: 'admin@b.edu' }).firestore();
const pendingT = env.authenticatedContext('teacher_pending', { email: 't1@a.edu' }).firestore();
const student1 = env.authenticatedContext('student_1', { email: 's1@a.edu' }).firestore();
const student2 = env.authenticatedContext('student_2', { email: 's2@a.edu' }).firestore();

console.log('\n=== ISSUE 1: admin can approve faculty ===');

await check('admin approves a teacher in their own institution', () =>
  assertSucceeds(setDoc(doc(adminA, 'users/teacher_pending'),
    { approved: true, approvedAt: serverTimestamp(), approvedBy: 'admin_a' },
    { merge: true })));

await check('admin approves a LEGACY teacher with no institutionCode, stamping their own', () =>
  assertSucceeds(setDoc(doc(adminA, 'users/teacher_legacy'),
    { approved: true, institutionCode: 'INST_A', approvedAt: serverTimestamp() },
    { merge: true })));

await check('admin can DELETE (reject) a teacher in their institution', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'users/teacher_reject'), {
      role: 'teacher', approved: false, institutionCode: 'INST_A',
    });
  });
  await assertSucceeds(deleteDoc(doc(adminA, 'users/teacher_reject')));
});

await check('admin can revoke approval', () =>
  assertSucceeds(setDoc(doc(adminA, 'users/teacher_pending'),
    { approved: false, revokedAt: serverTimestamp() }, { merge: true })));

console.log('\n=== TENANT ISOLATION ===');

await check('admin from another institution CANNOT approve', () =>
  assertFails(setDoc(doc(adminB, 'users/teacher_pending'),
    { approved: true }, { merge: true })));

await check('admin from another institution CANNOT delete', () =>
  assertFails(deleteDoc(doc(adminB, 'users/teacher_pending'))));

console.log('\n=== PRIVILEGE ESCALATION (previously possible) ===');

await check('teacher CANNOT self-approve', () =>
  assertFails(setDoc(doc(pendingT, 'users/teacher_pending'),
    { approved: true }, { merge: true })));

await check('teacher CANNOT make themselves admin', () =>
  assertFails(updateDoc(doc(pendingT, 'users/teacher_pending'),
    { admin: true, role: 'admin' })));

await check('student CANNOT make themselves super admin', () =>
  assertFails(updateDoc(doc(student1, 'users/student_1'),
    { isSuperAdmin: true })));

await check('student CANNOT change their own institutionCode', () =>
  assertFails(updateDoc(doc(student1, 'users/student_1'),
    { institutionCode: 'INST_B' })));

await check('student CANNOT reset an existing device lock', () =>
  assertFails(updateDoc(doc(student1, 'users/student_1'),
    { registeredDeviceId: 'device-new' })));

await check('student CAN bind a device when none is registered', () =>
  assertSucceeds(updateDoc(doc(student2, 'users/student_2'),
    { registeredDeviceId: 'device-xyz' })));

await check('user CAN still edit their own displayName/photoUrl', () =>
  assertSucceeds(updateDoc(doc(student1, 'users/student_1'),
    { displayName: 'New Name', photoUrl: 'https://x/y.png' })));

await check('self-signup CANNOT create an admin account', () =>
  assertFails(setDoc(doc(
    env.authenticatedContext('evil_1').firestore(), 'users/evil_1'),
    { role: 'admin', admin: true, institutionCode: 'INST_A' })));

await check('self-signup CANNOT create a pre-approved teacher', () =>
  assertFails(setDoc(doc(
    env.authenticatedContext('evil_2').firestore(), 'users/evil_2'),
    { role: 'teacher', approved: true, institutionCode: 'INST_A' })));

await check('legitimate teacher self-signup (unapproved) succeeds', () =>
  assertSucceeds(setDoc(doc(
    env.authenticatedContext('newteacher').firestore(), 'users/newteacher'),
    { role: 'teacher', approved: false, admin: false, institutionCode: 'INST_A',
      email: 'new@a.edu', idNumber: '999' })));

console.log('\n=== id_index uniqueness lock ===');

await check('another user CANNOT steal an existing roll-number index entry', () =>
  assertFails(setDoc(doc(student2, 'id_index/101'), { uid: 'student_2' })));

await check('user CAN claim a free roll number for themselves', () =>
  assertSucceeds(setDoc(doc(student2, 'id_index/555'),
    { uid: 'student_2', institutionCode: 'INST_A' })));

await check('user CANNOT claim a roll number in someone else name', () =>
  assertFails(setDoc(doc(student2, 'id_index/556'), { uid: 'student_1' })));

await check('owner CAN release their own index entry', () =>
  assertSucceeds(deleteDoc(doc(student1, 'id_index/101'))));

console.log(results.join('\n'));
console.log(`\n${passed} passed, ${failed} failed\n`);
await env.cleanup();
process.exit(failed === 0 ? 0 : 1);
