const test = require("node:test");
const assert = require("node:assert/strict");
const { validateProfile, makeUpdateMyProfile } = require("../controllers/profileUpdate");
const valid = { exerciseFrequency: "RARELY", preferredExercises: ["YOGA"], participationTypes: ["SMALL_GROUP"], onboardingCompleted: true };
test("accepts only complete allowed preferences", () => {
    assert.deepEqual(validateProfile(valid), valid);
    for (const body of [null, {}, { ...valid, uid: "other" }, { ...valid, email: "spoof" },
        { ...valid, preferredExercises: [] }, { ...valid, preferredExercises: ["YOGA", "YOGA"] },
        { ...valid, onboardingCompleted: "true" }, { ...valid, exerciseFrequency: "invalid" }]) {
        assert.equal(validateProfile(body), null);
    }
});
test("writes only authenticated UID and approved fields", async () => {
    let written;
    const db = { collection: name => { assert.equal(name, "users"); return { doc: uid => {
        assert.equal(uid, "owner"); return { update: async data => { written = data; } };
    } }; } };
    const res = { status(code) { this.code = code; return this; }, json(body) { this.body = body; return this; } };
    const handler = makeUpdateMyProfile(db, () => "server-time");
    await handler({ user: { uid: "owner" }, body: valid }, res);
    assert.equal(res.code, 200);
    assert.deepEqual(written, { ...valid, updatedAt: "server-time" });
    await handler({ body: valid }, res);
    assert.equal(res.code, 401);
});
test("partial conditions preserve onboarding fields and reject unknown input", () => {
    const conditions = { availableDays: ["MON", "SAT"], availableTimes: ["EVENING"], preferredExercises: ["PILATES"] };
    assert.deepEqual(validateProfile(conditions), conditions);
    for (const invalid of [{ availableDays: [] }, { availableDays: ["MON", "MON"] },
        { availableTimes: ["NIGHT"] }, { healthNote: "private" }, { onboardingCompleted: true },
        { ...conditions, createdAt: "spoof" }, { preferredExercises: null }]) {
        assert.equal(validateProfile(invalid), null);
    }
});
test("storage errors return safe failures and never success", async () => {
    for (const code of [5, 14]) {
        const db = { collection: () => ({ doc: () => ({
            update: async () => { throw { code, message: "secret" }; },
            get: async () => { throw { code, message: "secret" }; }
        }) }) };
        const res = { status(value) { this.code = value; return this; }, json(body) { this.body = body; } };
        await makeUpdateMyProfile(db, () => "time")({ user: { uid: "owner" }, body: valid }, res);
        assert.equal(res.code, code === 5 ? 404 : 503);
        assert.equal(res.body.success, false);
        assert.equal(JSON.stringify(res.body).includes("secret"), false);
    }
});
test("initializes a missing profile using the authenticated identity before saving preferences", async () => {
    let stored;
    const ref = {
        get: async () => ({ exists: !!stored, data: () => stored }),
        create: async fields => { stored = fields; },
        update: async fields => {
            if (!stored) throw { code: 5 };
            stored = { ...stored, ...fields };
        }
    };
    const db = { collection: name => {
        assert.equal(name, "users");
        return { doc: uid => { assert.equal(uid, "owner"); return ref; } };
    } };
    const res = { status(code) { this.code = code; return this; }, json(body) { this.body = body; } };
    await makeUpdateMyProfile(db, () => "time")({ user: { uid: "owner", email: "owner@example.test" }, body: valid }, res);
    assert.equal(res.code, 200);
    assert.equal(stored.email, "owner@example.test");
    assert.equal(stored.createdAt, "time");
    assert.equal(stored.onboardingCompleted, true);
});
test("personal data validates and cannot change authentication identity", () => {
    assert.deepEqual(validateProfile({ name: " 테스트 하나 ", phone: "" }), { name: "테스트 하나", phone: "" });
    for (const value of [{ name: "" }, { name: "x".repeat(51) }, { phone: "invalid" },
        { name: "name", email: "other@example.com" }, { userId: "other" }, { role: "admin" }]) {
        assert.equal(validateProfile(value), null);
    }
});
test("medical test registration is opt-in and server-generated", async () => {
    assert.equal(validateProfile({ medicalTestData: { status: "REGISTERED" } }), null);
    assert.equal(validateProfile({ registerMedicalTestData: "true" }), null);
    assert.equal(validateProfile({ registerMedicalTestData: false }), null);
    let written;
    const db = { collection: () => ({ doc: uid => {
        assert.equal(uid, "owner");
        return { update: async data => { written = data; } };
    } }) };
    const res = { status(code) { this.code = code; return this; }, json(body) { this.body = body; } };
    await makeUpdateMyProfile(db, () => "server-time")({ user: { uid: "owner" }, body: { registerMedicalTestData: true } }, res);
    assert.equal(written.medicalTestData.isSynthetic, true);
    assert.equal(written.medicalTestData.status, "TEST_REGISTERED");
    assert.equal(written.registerMedicalTestData, undefined);
    assert.equal(written.medicalData, undefined);
    assert.equal(res.body.success, true);
});
