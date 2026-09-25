# Firebase setup

Project: `project-ond`. Apple app: `com.example.CalmIOS`.
Authentication: email/password. Database: `ond-db`, Seoul (`asia-northeast3`).

The initial Firestore schema is a private `users/{Firebase Auth UID}` document
with email, createdAt, and updatedAt. Passwords are handled by Firebase Auth and
are never stored in Firestore. Other collections are denied until their server
workflows are implemented. Existing exercise and booking screens still use local
demo data; this setup does not migrate those records to a shared server.

Rule review: unauthenticated access, other-user access, extra fields (including
roles), removed fields, wrong types, oversized email, forged email, and changed
creation timestamps are rejected by the owner check and shared validator.
No collections permit counter writes, subcollection writes, or public queries.
The client only gets its own user document by UID, and creates it if absent.
This is a static review, not an executed emulator attack test.

Rules are a prototype and require review and emulator tests before public launch.

## Verified setup (2026-09-24)

- Apple app registered: `1:78678730187:ios:a085cbbd90e7bebc6cc24e`.
- Email/password provider deployed successfully.
- `ond-db` created: Enterprise / Firestore Native, free tier, Seoul.
- Rules compiled on Firebase and deployed successfully.
- FirebaseCore, FirebaseAuth, FirebaseFirestore SDK 12.19.2 and `-ObjC` linked.
- GoogleService-Info.plist linked as an app resource.
- Signup and login use Firebase Auth and create/read the caller's Firestore user
  document. Logout calls Firebase Auth signOut. Signed-in state restores on launch.
- Signup continues to the existing agreement and onboarding screens. These screens
  and exercise/profile editing still store demo data locally. They are not yet
  synchronized to Firestore or isolated as production multi-account data.
- Firestore real-time updates are disabled; this implementation uses one-shot reads.
- Swift syntax parsing and project/plist validation passed. Full Xcode dependency
  resolution failed because sandbox-exec is unavailable in this agent environment.
  Launch and real signup/login have not been verified in the simulator.
- Rules emulator tests could not run because this machine has no Java runtime.

Open `CalmIOS.xcodeproj` in Xcode, allow package resolution, and run on an iPhone
simulator. Test creating a new email/password account, verify its UID in Firebase
Authentication and `ond-db/users`, then log out and log in again. An incorrect
password must show an error. Existing local demo passwords are not Firebase accounts.

The same authentication source changes and SDK setup were applied to the Desktop
CalmIOS copy. Backend deployment files are maintained in this project_ond directory.
