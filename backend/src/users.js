import { FieldValue } from 'firebase-admin/firestore';

export function userRepository(db) {
  function present(uid, data) {
    return { uid, email: data.email,
      createdAt: data.createdAt?.toDate().toISOString() ?? null };
  }
  return {
    async get({ uid }) {
      const snapshot = await db.collection('users').doc(uid).get();
      return snapshot.exists ? present(uid, snapshot.data()) : null;
    },
    async ensure({ uid, email }) {
      const ref = db.collection('users').doc(uid);
      await db.runTransaction(async transaction => {
        const snapshot = await transaction.get(ref);
        if (!snapshot.exists) {
          transaction.create(ref, { email, createdAt: FieldValue.serverTimestamp(),
            updatedAt: FieldValue.serverTimestamp() });
        }
      });
      return present(uid, (await ref.get()).data());
    }
  };
}
