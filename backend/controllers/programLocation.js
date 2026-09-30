const fs = require('node:fs/promises');
const path = require('node:path');
const normalize = value => typeof value === 'string' ? value.normalize('NFKC').replace(/\s+/g, '').toLowerCase() : '';
const located = value => Number.isFinite(value.latitude) && Number.isFinite(value.longitude)
    && Math.abs(value.latitude) <= 90 && Math.abs(value.longitude) <= 180;

function makeLocationResolver(rows) {
    const ids = new Map(), names = new Map();
    for (const row of rows) {
        if (!located(row) || row.sourceOperationStatus !== '정상운영') continue;
        ids.set(row.id, row);
        const key = normalize(row.name);
        if (key) names.set(key, names.has(key) ? null : row);
    }
    return program => {
        if (located(program)) return program;
        const facility = program.facilityId ? ids.get(program.facilityId) : names.get(normalize(program.facilityName));
        if (!facility) return program;
        return { ...program, latitude: facility.latitude, longitude: facility.longitude,
            locationSource: 'facility-catalogue', locationSnapshot: '202607' };
    };
}

let cached;
async function resolveProgramLocations(programs) {
    if (!cached) {
        cached = fs.readFile(process.env.FACILITY_CATALOGUE_PATH || path.join(__dirname, '../data/facilities-seoul-202607.jsonl'), 'utf8')
            .then(raw => makeLocationResolver(raw.split(/\r?\n/).filter(Boolean).map(line => JSON.parse(line))))
            .catch(error => { cached = undefined; throw error; });
    }
    const resolve = await cached;
    return programs.map(resolve);
}
module.exports = { makeLocationResolver, resolveProgramLocations };
