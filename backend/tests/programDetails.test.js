const test = require('node:test');
const assert = require('node:assert/strict');
const { publicProgram } = require('../controllers/programController');
const basic = { programId: 'yoga', programName: 'Yoga', facilityName: 'Studio' };

test('uploaded Korean schema maps to the iOS detail contract without inventing a bookable session', () => {
    const result = publicProgram({ id: 'uploaded', data: () => ({
        ...basic, programDescription: '설명', category: '생활체육', level: '중급',
        notice: '준비운동\n물 준비', scheduleText: '토 09:00', durationMinutes: 60,
        instructorName: '테스트 강사', instructorBio: '소개', instructorSpecialty: '전문 분야'
    }) });
    assert.equal(result.description, '설명');
    assert.equal(result.exerciseType, '생활체육');
    assert.equal(result.difficulty, '중급');
    assert.deepEqual(result.participationGuide, ['준비운동', '물 준비']);
    assert.equal(result.scheduleText, '토 09:00');
    assert.equal(result.durationMinutes, 60);
    assert.equal(result.instructorBio, '소개');
    assert.equal(result.bookingAvailable, false);
    assert.equal(result.startAt, undefined);
});

test('registered schedule and filter fields reach iOS without exposing private fields', () => {
    const result = publicProgram({ id: 'yoga', data: () => ({
        ...basic, exerciseType: 'YOGA', facilityId: 'studio', price: 0,
        capacity: 5, reservedCount: 0, status: 'OPEN',
        latitude: 37.5, longitude: 127,
        startAt: { toDate: () => new Date('2099-01-01T01:00:00Z') },
        endAt: { toDate: () => new Date('2099-01-01T02:00:00Z') },
        privateNote: 'secret', userId: 'private', imageURL: 'https://example.com/yoga.png',
        instructorName: 'Test instructor', participationGuide: [' Bring water ', null],
        amenities: ['Lounge']
    }) });
    assert.equal(result.bookingAvailable, true);
    assert.equal(result.exerciseType, 'YOGA');
    assert.equal(result.startAt, '2099-01-01T01:00:00.000Z');
    assert.equal(result.latitude, 37.5);
    assert.equal(result.privateNote, undefined);
    assert.equal(result.userId, undefined);
    assert.equal(result.instructorName, 'Test instructor');
    assert.deepEqual(result.participationGuide, ['Bring water']);
    assert.deepEqual(result.amenities, ['Lounge']);
    assert.equal(result.isTestData, undefined);
});

test('retired test programs are excluded from public data and cannot be booked', () => {
    assert.equal(publicProgram({ id: 'retired', data: () => ({ ...basic, isTestData: true }) }), null);
    const { bookingAvailability } = require('../controllers/bookingAvailability');
    assert.equal(bookingAvailability({ isTestData: true }).available, false);
});

test('missing or invalid fields are not fabricated', () => {
    const result = publicProgram({ id: 'yoga', data: () => ({
        ...basic, price: -1, latitude: 999, longitude: 127,
        startAt: { toDate: () => new Date('invalid') }, imageURL: 'http://example.com/image.png'
    }) });
    assert.equal(result.bookingAvailable, false);
    for (const key of ['price', 'latitude', 'longitude', 'startAt', 'imageURL']) {
        assert.equal(result[key], undefined);
    }
});
