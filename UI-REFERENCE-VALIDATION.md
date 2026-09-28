# UI Reference Pass - 2026-09-28

Status: implemented source changes; not visually verified or release approved.

References: six user-provided PNG files under `/Users/iminseo/Documents/ondimage`.
The duplicated cards outside the mobile frames are canvas overflow, not app UI.

## Changes

- Home: guest signup card, lighter review banner, outline tab symbols,
  horizontally scrolling server program cards, compact progress controls.
- Home: upcoming server reservations and the current week's calendar replace
  the fixed September calendar. Returning to Home or cancelling a reservation
  refreshes the data. Guest calendar example is explicitly labelled and is not saved.
- Discovery: restored NavigationStack for detail navigation; compact filter
  chips, rounded header, program cards, schedule-text fallback, category,
  group and actual straight-line distance labels; fixed institution filter.
- Discovery: removed the simulator-only program-loading compile guard.
  Release still requires a configured HTTPS API origin.
- Program detail: reference-style back arrow, time-label spacing and unboxed
  review rows. Existing uploaded photos, details and reservation calls remain.

## Verification

- Swift syntax parse: passed. This is NOT a full type check or link test.
- Git whitespace check: passed.
- Active server unit tests: 42 passed, without writing production data.
- Xcode Debug build attempted: failed during dependency resolution because
  Xcode/SwiftPM caches are not writable in this session. CoreSimulator access
  also failed. No simulator screenshots were produced.
- Endpoint test attempted: blocked by Clang ModuleCache permissions.
- GitHub push attempted: HTTPS password authentication unavailable.

## Required Before Release

- Debug and Release builds, then actual simulator checks at narrow and large
  iPhone sizes, Dynamic Type, scrolling, keyboard, login/logout and cancellation.
- Compare all six reference states against rendered screenshots. Pixel equality
  has NOT been confirmed. Real names, counts and schedules must remain real data.
- Home attendance/progress/review-writing still use the existing local store;
  these are not yet a verified end-to-end server attendance workflow.
- Search currently filters the loaded program page. Search completeness and
  nearby program discovery require server integration and regression coverage.
- The separate server's search/nearby handlers currently read all programs;
  replace unbounded reads before production to avoid quota exhaustion.
- Program review counts and walking times are not fabricated when the API does
  not supply them. Complete those contracts before claiming reference parity.
- Resolve all remaining items in PREDEPLOY-CHECKLIST.md, including operational
  data, Firestore rules, credentials rotation and deployment origin.
- Authenticate GitHub locally, push and verify the remote commit. Do not share
  passwords or tokens in chat and do not force-push independent server history.
