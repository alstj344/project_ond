const test = require("node:test");
const assert = require("node:assert/strict");
const { ensureUserProfile } = require("../controllers/userProfile");

test("profile initialization preserves existing fields after concurrent creation", async () => {
    const existing = { name: "Owner", createdAt: "original", onboardingCompleted: true };
    let reads = 0;
    const db = { collection: () => ({ doc: uid => {
        assert.equal(uid, "owner");
        return {
            get: async () => ({ exists: ++reads > 1, data: () => existing }),
            create: async () => { throw { code: 6 }; }
        };
    } }) };
    assert.deepEqual(await ensureUserProfile(db, { uid: "owner" }, () => "new"), existing);
});

test("quota failures propagate without claiming a saved profile", async () => {
    const db = { collection: () => ({ doc: () => ({ get: async () => { throw { code: 8 }; } }) }) };
    await assert.rejects(ensureUserProfile(db, { uid: "owner" }, () => "time"), error => error.code === 8);
});
