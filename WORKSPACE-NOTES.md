# Workspace Layout

- `CalmIOS/`: iOS application source and assets.
- `CalmIOS.xcodeproj/`: shared project configuration and resolved packages.
- `Tests/`: focused Swift model checks.
- `security-tests/`: endpoint and Firestore rule checks.
- `data-import/`: facility import tools.
- `backend/`: earlier backend implementation; not the currently running server.

The active server checkout is `/Users/iminseo/Desktop/backend`. Its Git history
differs from this app checkout. Server changes are published separately on
`codex/backend-cleanup-20260928`; do not force-push that history onto app `main`.

Finder metadata, Xcode user state, local environment files and service-account
credentials must stay outside version control. Removing their Git tracking does
not remove local copies.

## Verification On 2026-09-28

- All application Swift files passed syntax parsing.
- Active backend: 42 tests passed.
- Git whitespace checks passed for both checkouts.
- Endpoint execution test could not compile because the sandbox denied access
  to the Clang module cache. Full Xcode build and simulator verification remain
  required; syntax parsing alone does not confirm a successful application build.
- Kakao map search integration was removed. Address entry still uses the separate
  postcode service; location search uses MapKit.
