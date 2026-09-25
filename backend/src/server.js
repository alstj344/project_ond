import { applicationDefault, initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';
import { createApp } from './app.js';
import { userRepository } from './users.js';

const firebase = initializeApp({ projectId: process.env.GOOGLE_CLOUD_PROJECT || 'project-ond',
  credential: applicationDefault() });
const db = getFirestore(firebase, process.env.FIRESTORE_DATABASE_ID || 'ond-db');
const app = createApp({
  verifyToken: token => getAuth(firebase).verifyIdToken(token, true),
  users: userRepository(db)
});
// Verify server credentials before accepting requests.
await firebase.options.credential.getAccessToken();
const port = Number(process.env.PORT || 3000);
const server = app.listen(port, process.env.HOST || '127.0.0.1', () => {
  console.log(`OnD API listening on port ${port}`);
});
for (const signal of ['SIGINT', 'SIGTERM']) {
  process.once(signal, () => server.close(() => process.exit(0)));
}
