# Deployment Readiness

Prepared locally only. No hosting resources or billing were enabled.

## Local Checks

- `npm test` runs fake-database unit tests without writing real user data.
- `npm start` listens on `127.0.0.1:3000` by default.
- Restart the existing server to load controller changes.
- The current iOS source supports an HTTPS `ONDAPIBaseURL` Info.plist value in all builds. Only DEBUG simulator builds default to localhost. Release build execution remains unverified.

## Hosting Configuration

- Use Node 22, `npm ci --omit=dev`, and `npm start`.
- Set `NODE_ENV=production`, `HOST=0.0.0.0`, and the hosting platform's `PORT`.
- Set `FIREBASE_PROJECT_ID=project-ond`, `FIRESTORE_DATABASE_ID=ond-db`.
- Assign a least-privilege service identity with Firestore data access and Firebase Auth token-revocation lookup permission. Use Application Default Credentials; do not upload the local service account private key.
- Include `data/facilities-seoul-202607.jsonl` in the build, or set `FACILITY_CATALOGUE_PATH` to the deployed catalogue.
- Configure HTTPS, request-rate limits at the gateway, budget alerts, error monitoring, backups, and staging before public launch.
- Use `/` as a process-health check; it intentionally does not query Firestore.

## Release Blockers

- Verify SwiftUI in Xcode and supply a reviewed HTTPS `ONDAPIBaseURL` value for the release build.
- Run Firestore Emulator integration tests for concurrent transactions and security rules; fake transaction tests do not prove actual Firestore contention behavior.
- The updated app repository rules deny direct profile updates and deletes. Review the deployed rules separately; local rules have not been deployed.
- Confirm programmes, prices, instructors, consent, cancellation deadlines, and medical integration with the operator. Medical data currently remains synthetic test data, not an actual clinic integration.
- Paid reservations are intentionally blocked until payment processing is implemented.
- Reviews, check-in/out, and home calendar still have local/demo flows; do not advertise them as fully server synchronized.
- Verify account deletion includes reservation cleanup and retention requirements before enabling it.
- Rotate any previously shared credentials and confirm the repository/container does not contain private keys.
- Synthetic medical-data creation is rejected when `NODE_ENV=production`. Do not omit this environment setting.

## Rollback

Keep a tagged release and deploy immutable builds. Roll back application code separately from database changes. Do not restore an entire production database solely to undo UI changes.
