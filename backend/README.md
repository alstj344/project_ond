# OnD Express API

## Final Project Entry Point (2026-09-30)

Run `npm ci`, `npm test`, then `npm start` in this directory. The current entry
point is `server.js`; the following older `src/` prototype notes are historical.
The latest controllers, routes, tests and public facility catalogue are included.

Use Application Default Credentials for project `project-ond`, database `ond-db`.
Set `GOOGLE_APPLICATION_CREDENTIALS` to an existing key outside the repository,
or use an authorized `gcloud auth application-default login`. No key is included.
The default address is `127.0.0.1:3000`; the process health check is `GET /`.

Profiles absent after Firebase signup are initialized using the verified token.
Existing profile fields are preserved. Reservation ownership uses the existing
`reservations.uid` field. Database errors are never treated as successful saves.
Program pages use a five-minute cache; actual non-sample review counts are
aggregated by programId with a ten-minute cache, not separately for every card.

Programs marked `isTestData` are excluded from listings and reservation responses,
and cannot be newly booked. There is no test-program seeder in runtime startup.
Existing Firestore documents were not deleted while packaging this project.
See `DEPLOYMENT.md` and the parent `PREDEPLOY-CHECKLIST.md` before release.

## Historical Profile-Only Prototype

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
