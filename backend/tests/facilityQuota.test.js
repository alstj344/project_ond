const test = require("node:test");
const assert = require("node:assert/strict");
const { makeListFacilities, publicFacility } = require("../controllers/facilityController");
function fixture(count = 650) {
    const docs = Array.from({ length: count }, (_, i) => ({ id: String(i).padStart(4, "0"), exists: true,
        data: () => ({ name: `기관 ${String(i).padStart(4, "0")}`, address: "서울 강남구", province: "서울특별시",
            source: { snapshot: "202607" }, sourceOperationStatus: "정상운영", facilityType: "헬스",
            latitude: 37.5, longitude: 127, nearbyTransit: [{ name: "역", mode: "지하철", distanceMeters: 12.5 }] }) }));
    const reads = [];
    const db = { collection: () => ({ doc: id => id }), async getAll(...ids) {
        reads.push(ids); return ids.map(id => docs.find(d => d.id === id));
    } };
    return { docs, db, reads, options: { loadCatalogue: async () => docs.map(publicFacility) } };
}
async function call(handler, query = {}) {
    const r = { code: 200, status(code) { this.code = code; return this; }, set() {}, json(body) { this.body = body; return this; } };
    await handler({ query }, r); return r;
}
test("every page reads at most 30 documents, stable pagination and real categories", async () => {
    const f = fixture(); const h = makeListFacilities(f.db, f.options);
    const a = await call(h), b = await call(h, { page: "1" }), c = await call(h, { page: "20" });
    assert.equal(a.body.total, 650); assert.deepEqual(a.body.categories, ["헬스"]);
    assert.equal(b.body.facilities[0].id, "0030"); assert.equal(c.body.facilities[0].id, "0600");
    assert.deepEqual(f.reads.map(r => r.length), [30, 30, 30]);
    await call(h); assert.equal(f.reads.length, 3);
});
test("search beyond first 300, retain enriched transit and empty result costs zero reads", async () => {
    const f = fixture(); const h = makeListFacilities(f.db, f.options);
    const r = await call(h, { q: "0649" });
    assert.equal(r.body.facilities[0].id, "0649");
    assert.equal(r.body.facilities[0].nearbyTransit[0].type, "지하철");
    assert.equal(r.body.facilities[0].nearbyTransit[0].distanceMeters, 13);
    await call(h, { q: "없음" }); assert.equal(f.reads.length, 1);
});
test("quota cooldown prevents repeated reads and response never leaks errors", async () => {
    const f = fixture(); let attempts = 0, clock = 100;
    f.db.getAll = async () => { attempts++; throw Object.assign(Error("private credentials"), { code: 8 }); };
    const h = makeListFacilities(f.db, { ...f.options, now: () => clock });
    assert.equal((await call(h)).code, 503); assert.equal((await call(h)).code, 503);
    assert.equal(attempts, 1); clock += 61000; await call(h); assert.equal(attempts, 2);
});
test("invalid input never reads Firestore and concurrent calls share one read", async () => {
    const f = fixture(); const h = makeListFacilities(f.db, f.options);
    for (const q of [{page:"-1"},{page:""},{lat:"37.5"},{q:[]},{radius:"NaN"}]) assert.equal((await call(h,q)).code,400);
    assert.equal(f.reads.length,0);
    await Promise.all([call(h),call(h)]); assert.equal(f.reads.length,1);
    const nearby = await call(h, {lat:"37.5",lon:"127",radius:"1"});
    assert.equal(nearby.body.total,650); assert.equal(nearby.body.facilities[0].distanceKm,0);
});
