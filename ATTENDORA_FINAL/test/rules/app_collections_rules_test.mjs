import {
  initializeTestEnvironment, assertFails, assertSucceeds,
} from '@firebase/rules-unit-testing';
import { readFileSync } from 'node:fs';
import {
  doc, getDoc, setDoc, deleteDoc, collection, query, where, getDocs, serverTimestamp,
} from 'firebase/firestore';

let passed = 0, failed = 0; const results = [];
async function check(name, fn) {
  try { await fn(); passed++; results.push(`  PASS  ${name}`); }
  catch (e) { failed++; results.push(`  FAIL  ${name}\n          ${e.message.split('\n')[0]}`); }
}

const env = await initializeTestEnvironment({
  projectId: 'attendora-collections-test',
  firestore: { host: '127.0.0.1', port: 8181, rules: readFileSync('../../firestore.rules', 'utf8') },
});

await env.withSecurityRulesDisabled(async (ctx) => {
  const db = ctx.firestore();
  await setDoc(doc(db, 'users/teacher_1'), { role: 'teacher', approved: true, institutionCode: 'INST_A' });
  await setDoc(doc(db, 'users/teacher_2'), { role: 'teacher', approved: true, institutionCode: 'INST_A' });
  await setDoc(doc(db, 'users/student_1'), { role: 'student', institutionCode: 'INST_A' });
  await setDoc(doc(db, 'users/student_2'), { role: 'student', institutionCode: 'INST_A' });
  await setDoc(doc(db, 'users/admin_a'), { role: 'admin', admin: true, institutionCode: 'INST_A' });
  await setDoc(doc(db, 'users/admin_b'), { role: 'admin', admin: true, institutionCode: 'INST_B' });
  await setDoc(doc(db, 'users/super'), { role: 'admin', admin: true, isSuperAdmin: true });
  await setDoc(doc(db, 'detentions/d1'), {
    studentId: 'student_1', teacherUid: 'teacher_1', institutionCode: 'INST_A', subjectName: 'Maths',
  });
  await setDoc(doc(db, 'subject_catalog/c1'), { name: 'Maths', institutionCode: 'INST_A' });
  await setDoc(doc(db, 'global_notifications/g1'), { title: 'Hi', targetRole: 'all' });
});

const as = (uid) => env.authenticatedContext(uid).firestore();
const teacher1 = as('teacher_1'), teacher2 = as('teacher_2');
const student1 = as('student_1'), student2 = as('student_2');
const adminA = as('admin_a'), adminB = as('admin_b'), superA = as('super');

console.log('\n=== detentions (teacher "detain" action) ===');
await check('teacher can detain a student (create own detention)', () =>
  assertSucceeds(setDoc(doc(teacher1, 'detentions/d_new'), {
    studentId: 'student_2', teacherUid: 'teacher_1', institutionCode: 'INST_A', subjectName: 'Physics',
  })));
await check('teacher CANNOT file a detention in another teacher name', () =>
  assertFails(setDoc(doc(teacher1, 'detentions/d_spoof'), {
    studentId: 'student_2', teacherUid: 'teacher_2', institutionCode: 'INST_A',
  })));
await check('a student CANNOT detain anyone (incl. themselves, to forge records)', () =>
  assertFails(setDoc(doc(student1, 'detentions/d_self'), {
    studentId: 'student_2', teacherUid: 'student_1', institutionCode: 'INST_A',
  })));
await check('student can read their OWN detention (query by studentId)', async () => {
  const snap = await assertSucceeds(getDocs(query(collection(student1, 'detentions'), where('studentId', '==', 'student_1'))));
  if (snap.size !== 1) throw new Error(`expected 1 detention, got ${snap.size}`);
});
await check("student CANNOT read another student's detention", () =>
  assertFails(getDocs(query(collection(student2, 'detentions'), where('studentId', '==', 'student_1')))));
await check('issuing teacher can list their detentions (query by teacherUid)', () =>
  assertSucceeds(getDocs(query(collection(teacher1, 'detentions'), where('teacherUid', '==', 'teacher_1')))));
await check('another teacher CANNOT list the first teacher detentions', () =>
  assertFails(getDocs(query(collection(teacher2, 'detentions'), where('teacherUid', '==', 'teacher_1')))));
await check('issuing teacher can remove the detention', () =>
  assertSucceeds(deleteDoc(doc(teacher1, 'detentions/d1'))));
await check('a student CANNOT remove their own detention', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'detentions/d2'), { studentId: 'student_1', teacherUid: 'teacher_1', institutionCode: 'INST_A' });
  });
  await assertFails(deleteDoc(doc(student1, 'detentions/d2')));
});
await check('admin of another institution CANNOT remove it', () =>
  assertFails(deleteDoc(doc(adminB, 'detentions/d2'))));
await check('admin of the same institution CAN remove it', () =>
  assertSucceeds(deleteDoc(doc(adminA, 'detentions/d2'))));

console.log('\n=== detention notification to the student ===');
await check('teacher can send the "you are detained" notification', () =>
  assertSucceeds(setDoc(doc(teacher1, 'notifications/n1'), {
    recipientUid: 'student_1', senderUid: 'teacher_1', type: 'detained',
    title: 'You are detained', message: 'x', read: false, timestamp: serverTimestamp(),
  })));

console.log('\n=== subject_catalog ===');
await check('teacher can read the catalogue', () => assertSucceeds(getDoc(doc(teacher1, 'subject_catalog/c1'))));
await check('teacher CANNOT write the catalogue', () =>
  assertFails(setDoc(doc(teacher1, 'subject_catalog/c2'), { name: 'X', institutionCode: 'INST_A' })));
await check('institution admin can add to their own catalogue', () =>
  assertSucceeds(setDoc(doc(adminA, 'subject_catalog/c3'), { name: 'Chem', institutionCode: 'INST_A' })));
await check('institution admin CANNOT add to another institution catalogue', () =>
  assertFails(setDoc(doc(adminA, 'subject_catalog/c4'), { name: 'Chem', institutionCode: 'INST_B' })));
await check('institution admin can DELETE their own catalogue entry', () =>
  assertSucceeds(deleteDoc(doc(adminA, 'subject_catalog/c3'))));

console.log('\n=== global_notifications ===');
await check('any signed-in user can read broadcasts', () => assertSucceeds(getDoc(doc(student1, 'global_notifications/g1'))));
await check('only the super admin can publish a broadcast', async () => {
  await assertFails(setDoc(doc(adminA, 'global_notifications/g2'), { title: 'x', targetRole: 'all' }));
  await assertSucceeds(setDoc(doc(superA, 'global_notifications/g2'), { title: 'x', targetRole: 'all' }));
});

console.log('\n=== users/{uid}/notification_states ===');
await check('a user can write their OWN notification state', () =>
  assertSucceeds(setDoc(doc(student1, 'users/student_1/notification_states/n1'), { read: true })));
await check("a user CANNOT touch another user's notification state", () =>
  assertFails(setDoc(doc(student1, 'users/student_2/notification_states/n1'), { read: true })));

console.log(results.join('\n'));
console.log(`\n${passed} passed, ${failed} failed\n`);
await env.cleanup();
process.exit(failed === 0 ? 0 : 1);
