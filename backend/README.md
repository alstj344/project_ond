# OnD Express API

Node 22+, Firebase project `project-ond`, Enterprise Native database `ond-db`.

Run `npm ci`, then `npm test`. Tests use an injected token verifier and repository;
they do not create Firebase accounts or write production data.

The server requires Application Default Credentials with Firebase Authentication
read access (revoked/disabled token checks) and Firestore data access. Firebase CLI
login is not Application Default Credentials. On a developer machine with Google
Cloud CLI installed, run `gcloud auth application-default login` using an authorized
account, then `npm start`. On Google Cloud use an attached service identity. Never
bundle service-account credentials into the iOS application or this repository.

Default listen address: `127.0.0.1:3000`. `/health` is a liveness check only.
`HOST` and `PORT` can be configured for a hosting environment; expose it with HTTPS.
If a reverse proxy is used, configure trust proxy for that known topology before
production use; the current limiter is a single-process IP limiter.

Both routes require `Authorization: Bearer <Firebase ID token>`:

- `GET /api/users/me`: return the current user's profile; 404 if absent.
- `POST /api/users/me`: initialize the profile transactionally if absent, then
  return it. Repeated calls preserve the existing creation timestamp and fields.

The server verifies signature, project, expiration, revocation, and disabled-user
status with Firebase Admin. UID/email come from the verified token, never a body or
query. Responses expose only UID, email and creation date. Admin bypasses Firestore
Security Rules, so ownership is enforced in the middleware and repository.

SwiftUI still uses the existing Firebase-to-Firestore path. Token forwarding to
Express is pending approval of the exact API destination. No deployed API URL or
server credentials have been provided, so a live end-to-end test has not run.
