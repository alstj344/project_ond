import { readFile } from 'node:fs/promises';
import { before, after, beforeEach, test } from 'node:test';
import { initializeTestEnvironment, assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import { doc, collection, getDocs, getDoc, setDoc, updateDoc, deleteDoc, runTransaction, serverTimestamp, Timestamp, deleteField } from 'firebase/firestore';

let env;
before(async () => {
  if (process.env.FIRESTORE_EMULATOR_HOST !== '127.0.0.1:8187') throw new Error('Only the local emulator is allowed');
  env = await initializeTestEnvironment({ projectId: 'demo-ond-rules', firestore: {
    host: '127.0.0.1', port: 8187,
    rules: await readFile(process.env.RULES_FILE || '../firestore.rules', 'utf8')
  } });
});
after(async () => { await env?.cleanup(); });
beforeEach(async () => { await env.clearFirestore(); });
const db = (uid = 'alice', email = `${uid}@example.invalid`) => env.authenticatedContext(uid, { email }).firestore();
const initial = () => ({ email: 'alice@example.invalid', createdAt: serverTimestamp(), updatedAt: serverTimestamp() });
async function seed() {
  await env.withSecurityRulesDisabled(async context => {
    await setDoc(doc(context.firestore(), 'users/alice'), { email: 'alice@example.invalid',
      createdAt: Timestamp.now(), updatedAt: Timestamp.now(), name: 'Test',
      preferences: { preferredExercises: ['WALKING'] }, medicalTestData: { isSynthetic: true } });
  });
}
test('owner transaction can create a missing bootstrap profile and read it again', async () => {
  const database = db(); const ref = doc(database, 'users/alice');
  for (let i = 0; i < 2; i++) await assertSucceeds(runTransaction(database, async transaction => {
    const snapshot = await transaction.get(ref);
    if (!snapshot.exists()) transaction.set(ref, initial());
  }));
  await assertSucceeds(getDoc(ref));
});
test('anonymous and other accounts cannot read, query, create, update or delete private profiles', async () => {
  await seed();
  for (const database of [env.unauthenticatedContext().firestore(), db('bob')]) {
    const ref = doc(database, 'users/alice');
    await assertFails(getDoc(ref)); await assertFails(getDocs(collection(database, 'users')));
    await assertFails(updateDoc(ref, { name: 'intruder' })); await assertFails(deleteDoc(ref));
    await assertFails(setDoc(doc(database, 'users/victim'), initial()));
  }
});
test('enriched profile cannot be overwritten, modified, truncated or deleted even by owner', async () => {
  await seed(); const ref = doc(db(), 'users/alice');
  await assertSucceeds(getDoc(ref));
  await assertFails(setDoc(ref, initial()));
  await assertFails(updateDoc(ref, { preferences: deleteField() }));
  await assertFails(updateDoc(ref, { isAdmin: true }));
  await assertFails(updateDoc(ref, { email: 'other@example.invalid' }));
  await assertFails(updateDoc(ref, { updatedAt: serverTimestamp() }));
  await assertFails(deleteDoc(ref));
});
test('bootstrap rejects injected roles, extra fields, missing fields and wrong types', async () => {
  const ref = doc(db(), 'users/alice');
  for (const invalid of [{ ...initial(), role: 'admin' }, { ...initial(), uid: 'bob' },
    { ...initial(), name: 'Test' }, { email: 'alice@example.invalid' },
    { ...initial(), email: 42 }, { ...initial(), createdAt: 'today' },
    { ...initial(), updatedAt: null }, { ...initial(), email: '' }]) await assertFails(setDoc(ref, invalid));
});
test('bootstrap rejects forged email, oversized email and forged timestamps', async () => {
  await assertFails(setDoc(doc(db(), 'users/alice'), { ...initial(), email: 'bob@example.invalid' }));
  const long = 'a'.repeat(255);
  await assertFails(setDoc(doc(db('alice', long), 'users/alice'), { ...initial(), email: long }));
  for (const seconds of [1, 4102444800]) await assertFails(setDoc(doc(db(), 'users/alice'), {
    ...initial(), createdAt: new Timestamp(seconds, 0), updatedAt: new Timestamp(seconds, 0)
  }));
});
test('no direct access to bookings, counters, facilities or nested profile paths', async () => {
  for (const path of ['reservations/alice_yoga', 'reviews/one', 'programs/yoga', 'facilities/one', 'users/alice/private/info']) {
    const ref = doc(db(), path);
    await assertFails(setDoc(ref, { uid: 'alice', reservedCount: 99 }));
    await assertFails(getDoc(ref));
  }
});
