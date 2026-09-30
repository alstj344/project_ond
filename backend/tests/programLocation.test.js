const test = require('node:test');
const assert = require('node:assert/strict');
const { makeLocationResolver } = require('../controllers/programLocation');
const row = { id: 'one', name: '서울 센터', latitude: 37.5, longitude: 127, sourceOperationStatus: '정상운영' };
test('exact normalized facility name resolves missing coordinates', () => {
    const p = makeLocationResolver([row])({ facilityName: '서울센터' });
    assert.equal(p.latitude, 37.5);
});
test('ambiguous names, unknown IDs and partial names never invent coordinates', () => {
    const resolve = makeLocationResolver([row, {...row, id:'two'}]);
    for (const p of [{facilityName:'서울 센터'}, {facilityName:'서울'}, {facilityName:'서울센터', facilityId:'missing'}]) {
        assert.equal(resolve(p).latitude, undefined);
    }
    assert.equal(resolve({facilityId:'one'}).longitude, 127);
});
test('explicit program coordinates take priority', () => {
    assert.equal(makeLocationResolver([row])({facilityName:row.name, latitude:36, longitude:128}).latitude, 36);
});
