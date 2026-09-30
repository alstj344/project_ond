const fs = require("node:fs/promises");
const path = require("node:path");
const text = v => typeof v === "string" ? v.trim() : "";
const normalize = v => text(v).normalize("NFKC").toLowerCase();

function makeSearch(db, { publicFacility, distance, loadCatalogue, now = Date.now }) {
    let cataloguePromise;
    async function catalogue() {
        if (loadCatalogue) return loadCatalogue();
        if (!cataloguePromise) cataloguePromise = fs.readFile(process.env.FACILITY_CATALOGUE_PATH ||
            path.join(__dirname, "../data/facilities-seoul-202607.jsonl"), "utf8").then(contents => {
            const seen = new Set();
            const all = contents.split(/\r?\n/).filter(Boolean).map(line => {
                const d = JSON.parse(line);
                if (!/^ks_[a-f0-9]{32}$/.test(d.id) || seen.has(d.id)) throw Error("Invalid catalogue");
                seen.add(d.id);
                return publicFacility({ id: d.id, data: () => d });
            }).filter(Boolean);
            if (!all.length) throw Error("Empty catalogue");
            return all;
        }).catch(error => { cataloguePromise = undefined; throw error; });
        return cataloguePromise;
    }
    const cache = new Map(), pending = new Map();
    let quotaUntil = 0;
    async function details(ids) {
        if (!ids.length) return [];
        const key = ids.join(","), hit = cache.get(key);
        if (hit && hit.expires > now()) return hit.value;
        if (now() < quotaUntil) throw Object.assign(Error("Quota cooldown"), { code: 8 });
        if (pending.has(key)) return pending.get(key);
        const request = (async () => {
            try {
                // Resolve only the selected page. Never scan Firestore to perform search.
                const snapshots = await db.getAll(...ids.map(id => db.collection("facilities").doc(id)));
                const docs = new Map(snapshots.map(d => [d.id, d.exists === false ? null : publicFacility(d)]));
                const value = ids.map(id => docs.get(id)).filter(Boolean);
                if (cache.size >= 200) cache.delete(cache.keys().next().value);
                cache.set(key, { expires: now() + 300000, value });
                return value;
            } catch (error) {
                if (error.code === 8) quotaUntil = now() + 60000;
                throw error;
            }
        })().finally(() => pending.delete(key));
        pending.set(key, request);
        return request;
    }
    return async (req, res) => {
        const q = req.query || {};
        if (Object.keys(q).some(k => !["q", "category", "page", "lat", "lon", "radius"].includes(k)) ||
            Object.values(q).some(v => typeof v !== "string")) {
            return res.status(400).json({ success: false, error: "Invalid query" });
        }
        const search = normalize(q.q), category = text(q.category), page = Number(q.page ?? 0);
        const nearby = q.lat !== undefined || q.lon !== undefined || q.radius !== undefined;
        const lat = Number(q.lat), lon = Number(q.lon), radius = Number(q.radius ?? 3);
        if (search.length > 100 || category.length > 60 ||
            (q.page !== undefined && !/^\d+$/.test(q.page)) || !Number.isInteger(page) || page < 0 || page > 500 ||
            (nearby && (!text(q.lat) || !text(q.lon) || !Number.isFinite(lat) || !Number.isFinite(lon) ||
                lat < 33 || lat > 39 || lon < 124 || lon > 132 || !Number.isFinite(radius) || radius < 0.5 || radius > 10))) {
            return res.status(400).json({ success: false, error: "Invalid query" });
        }
        try {
            const all = await catalogue();
            const categories = [...new Set(all.map(f => f.facilityType).filter(Boolean))].sort();
            const matched = all.filter(f => (!category || f.facilityType === category) &&
                (!search || normalize(`${f.name} ${f.address} ${f.district} ${f.facilityType}`).includes(search)))
                .map(f => ({ ...f, distanceKm: nearby && f.latitude !== null ? distance(lat, lon, f) : null }))
                .filter(f => !nearby || (f.distanceKm !== null && f.distanceKm <= radius))
                .sort((a, b) => (nearby ? a.distanceKm - b.distanceKm : 0) || a.name.localeCompare(b.name, "ko") || a.id.localeCompare(b.id));
            const start = page * 30, selected = matched.slice(start, start + 30);
            const current = await details(selected.map(f => f.id));
            const distances = new Map(selected.map(f => [f.id, f.distanceKm]));
            return res.json({ success: true, facilities: current.map(f => ({ ...f, distanceKm: distances.get(f.id) ?? null })),
                total: matched.length, nextPage: start + 30 < matched.length ? page + 1 : null,
                categories, catalogueSnapshot: "202607" });
        } catch (error) {
            if (error.code === 8) {
                res.set?.("Retry-After", "60");
                return res.status(503).json({ success: false, error: "Firestore quota exceeded" });
            }
            return res.status(503).json({ success: false, error: "Facilities temporarily unavailable" });
        }
    };
}
module.exports = { makeSearch };
