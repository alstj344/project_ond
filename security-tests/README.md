# Local Security Rules Checks

No production data is used or changed by these tests.

Run from this directory with Node, Java 21+ and Firebase CLI available:

```sh
firebase emulators:exec --only firestore --project demo-ond-rules --config firebase.json 'npm test'
```

The emulator configuration loads rules.candidate at startup; the test suite then
loads ../firestore.rules by default. RULES_FILE can select a candidate instead.
The current candidate and final rule source have both passed all 6 tests.

Coverage: owner bootstrap transaction/read, anonymous and cross-user CRUD/list,
enriched-profile overwrite/deletion, role injection, missing keys, wrong types,
oversized email, forged timestamps and direct access to reviews/programs/
reservations/facilities/subcollections. API updates use Admin SDK and require
separate authorization tests.

The local emulator starts in Standard edition. The deployed ond-db is Enterprise
Native; these results are not a production integration test or certification.
No Firebase rules were deployed.

I've set up prototype Security Rules to keep the data in Firestore safe. They are designed to be secure for owner-only profile reads, strictly validated initial profile creation, and blocking direct client modification of server-managed data. However, you should review and verify them before broadly sharing your app. If you'd like, I can help you harden these rules.
