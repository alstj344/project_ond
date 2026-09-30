const test = require('node:test');
const assert = require('node:assert/strict');
const { makeUpdateMyProfile } = require('../controllers/profileUpdate');

test('production rejects synthetic medical data before accessing Firestore', async () => {
    const db = { collection() { throw new Error('must not access database'); } };
    const response = {
        statusCode: 200,
        status(value) { this.statusCode = value; return this; },
        json(value) { this.body = value; return this; }
    };
    await makeUpdateMyProfile(db, () => 0, 'production')(
        { user: { uid: 'test-user' }, body: { registerMedicalTestData: true } }, response
    );
    assert.equal(response.statusCode, 403);
    assert.equal(response.body.success, false);
});
