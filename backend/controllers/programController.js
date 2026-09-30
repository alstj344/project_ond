const { bookingAvailability } = require("./bookingAvailability");
const { resolveProgramLocations } = require("./programLocation");

function publicProgram(doc) {
    const value = doc.data();
    if (value.isTestData === true) return null;

    // 현재 Firestore programs 문서 구조
    const programId =
        typeof value.programId === "string"
            ? value.programId.trim()
            : "";

    const programName =
        typeof value.programName === "string"
            ? value.programName.trim()
            : "";

    const facilityName =
        typeof value.facilityName === "string"
            ? value.facilityName.trim()
            : "";

    // 프로그램을 식별하고 화면에 표시하는 데 필요한 최소값
    if (!programId || !programName || !facilityName) {
        return null;
    }

    const availability = bookingAvailability(value);
    const details = {};
    const aliases = { description: "programDescription", exerciseType: "category", difficulty: "level" };
    for (const key of ["description", "exerciseType", "difficulty", "participationType", "facilityId", "instructorId", "instructorName"]) {
        if (typeof value[key] === "string" && value[key].trim()) details[key] = value[key].trim();
    }
    for (const [target, source] of Object.entries(aliases)) {
        if (!details[target] && typeof value[source] === "string" && value[source].trim()) {
            details[target] = value[source].trim().slice(0, 4000);
        }
    }
    for (const key of ["scheduleText", "instructorBio", "instructorSpecialty"]) {
        if (typeof value[key] === "string" && value[key].trim()) details[key] = value[key].trim().slice(0, 2000);
    }
    if (Number.isSafeInteger(value.durationMinutes) && value.durationMinutes > 0 && value.durationMinutes <= 1440) {
        details.durationMinutes = value.durationMinutes;
    }
    for (const key of ["participationGuide", "amenities"]) {
        if (Array.isArray(value[key])) details[key] = value[key].filter(item => typeof item === "string" && item.trim()).slice(0, 20).map(item => item.trim().slice(0, 500));
    }
    if (value.isTestData === true) details.isTestData = true;
    if (!details.participationGuide?.length && typeof value.notice === "string" && value.notice.trim()) {
        details.participationGuide = value.notice.split(/\r?\n/).map(line => line.trim()).filter(Boolean).slice(0, 20).map(line => line.slice(0, 500));
    }
    for (const key of ["price", "capacity", "reservedCount"]) {
        if (Number.isSafeInteger(value[key]) && value[key] >= 0) details[key] = value[key];
    }
    for (const key of ["startAt", "endAt"]) {
        const date = value[key]?.toDate?.();
        if (date instanceof Date && Number.isFinite(date.getTime())) details[key] = date.toISOString();
    }
    if (Number.isFinite(value.latitude) && Math.abs(value.latitude) <= 90 &&
        Number.isFinite(value.longitude) && Math.abs(value.longitude) <= 180) {
        details.latitude = value.latitude;
        details.longitude = value.longitude;
    }
    if (typeof value.imageURL === "string") {
        try {
            const url = new URL(value.imageURL);
            if (url.protocol === "https:" && !url.username && !url.password) details.imageURL = url.href;
        } catch { /* Invalid media URLs are omitted. */ }
    }
    return {
        id: doc.id,
        programId,
        programName,
        facilityName,
        ...details,
        bookingAvailable: availability.available,
        bookingUnavailableReason: availability.reason
    };
}


function makeListPrograms(db) {
    const pageCache = new Map();
    const cacheLifetimeMs = 5 * 60 * 1000;

    return async (req, res) => {
        const after = req.query.after;

        // 페이지네이션 cursor 검증
        if (
            after !== undefined &&
            (
                typeof after !== "string" ||
                !/^[A-Za-z0-9_-]{1,128}$/.test(after)
            )
        ) {
            return res.status(400).json({
                success: false,
                message: "목록 위치를 확인해 주세요."
            });
        }

        const cacheKey = after || "__first__";
        const cached = pageCache.get(cacheKey);
        if (cached && cached.expiresAt > Date.now()) {
            return res.json(cached.body);
        }

        try {
            // Firebase의 현재 programs 구조에는 status가 없으므로
            // where("status", "==", "OPEN")을 사용하지 않음
            let query = db
                .collection("programs")
                .orderBy("__name__");

            if (after) {
                query = query.startAfter(after);
            }

            // 20개 + 다음 페이지 존재 여부 확인용 1개
            const snapshot = await query
                .limit(21)
                .get();

            const page = snapshot.docs.slice(0, 20);

            const programs = await resolveProgramLocations(page
                .map(doc => publicProgram(doc))
                .filter(Boolean));

            const nextCursor =
                snapshot.docs.length > 20 && page.length > 0
                    ? page[page.length - 1].id
                    : null;

            const body = {
                success: true,
                programs,
                nextCursor
            };
            pageCache.set(cacheKey, {
                body,
                expiresAt: Date.now() + cacheLifetimeMs
            });
            return res.json(body);

        } catch (error) {
            if (cached) {
                return res.json({ ...cached.body, stale: true });
            }
            console.error(
                "프로그램 목록 조회 오류:",
                error
            );

            return res.status(503).json({
                success: false,
                message: "프로그램을 불러오지 못했어요."
            });
        }
    };
}

function makeSearchPrograms(db) {
    return async (req, res) => {
        const keyword =
            typeof req.query.q === "string"
                ? req.query.q.trim().toLowerCase()
                : "";

        if (!keyword) {
            return res.status(400).json({
                success: false,
                message: "검색어를 입력해 주세요."
            });
        }

        try {
            // 검색에서는 기존 목록 API의 20개 페이지 제한을 사용하지 않음
            const snapshot = await db
                .collection("programs")
                .get();

            const matchedDocs = snapshot.docs.filter((doc) => {
                const value = doc.data();

                const programName =
                    typeof value.programName === "string"
                        ? value.programName.toLowerCase()
                        : "";

                const facilityName =
                    typeof value.facilityName === "string"
                        ? value.facilityName.toLowerCase()
                        : "";

                const address =
                    typeof value.address === "string"
                        ? value.address.toLowerCase()
                        : "";

                const region =
                    typeof value.region === "string"
                        ? value.region.toLowerCase()
                        : "";

                const category =
                    typeof value.category === "string"
                        ? value.category.toLowerCase()
                        : "";

                return (
                    programName.includes(keyword) ||
                    facilityName.includes(keyword) ||
                    address.includes(keyword) ||
                    region.includes(keyword) ||
                    category.includes(keyword)
                );
            });

            // 기존 publicProgram()을 그대로 사용해서
            // iOS가 받고 있는 프로그램 데이터 구조를 유지
            const programs = await resolveProgramLocations(
                matchedDocs
                    .map((doc) => publicProgram(doc))
                    .filter(Boolean)
            );

            return res.json({
                success: true,
                query: req.query.q,
                count: programs.length,
                programs
            });

        } catch (error) {
            console.error(
                "프로그램 통합 검색 오류:",
                error
            );

            return res.status(503).json({
                success: false,
                message: "프로그램 검색 결과를 불러오지 못했어요."
            });
        }
    };
}
function makeNearbyPrograms(db) {
    return async (req, res) => {
        const latitude = Number(req.query.lat);
        const longitude = Number(req.query.lon);
        const radius = Number(req.query.radius ?? 3);

        // 좌표 / 반경 검증
        if (
            !Number.isFinite(latitude) ||
            !Number.isFinite(longitude) ||
            latitude < -90 ||
            latitude > 90 ||
            longitude < -180 ||
            longitude > 180
        ) {
            return res.status(400).json({
                success: false,
                message: "검색 위치를 확인해 주세요."
            });
        }

        if (
            !Number.isFinite(radius) ||
            radius < 0.5 ||
            radius > 10
        ) {
            return res.status(400).json({
                success: false,
                message: "검색 거리는 0.5km ~ 10km로 설정해 주세요."
            });
        }

        try {
            // 전체 프로그램 조회
            const snapshot = await db
                .collection("programs")
                .get();

            // 기존 iOS 데이터 구조 그대로 사용
            const allPrograms = await resolveProgramLocations(
                snapshot.docs
                    .map((doc) => publicProgram(doc))
                    .filter(Boolean)
            );
            console.log("전체 프로그램:", allPrograms.length);

            const locatedPrograms = allPrograms.filter(
                (program) => Number.isFinite(program.latitude) &&Number.isFinite(program.longitude));
                console.log("좌표 있는 프로그램:", locatedPrograms.length);
                console.log(
                    locatedPrograms.slice(0, 20).map((program) => ({
                        programName: program.programName,
                        facilityName: program.facilityName,
                        latitude: program.latitude,
                        longitude: program.longitude,
                        locationSource: program.locationSource
                    }))
                );

            // 두 좌표 사이 거리 계산 (km)
            const distanceInKilometers = (
                lat1,
                lon1,
                lat2,
                lon2
            ) => {
                const earthRadius = 6371;

                const toRadians = (degree) =>
                    degree * Math.PI / 180;

                const dLat = toRadians(lat2 - lat1);
                const dLon = toRadians(lon2 - lon1);

                const a =
                    Math.sin(dLat / 2) *
                        Math.sin(dLat / 2) +
                    Math.cos(toRadians(lat1)) *
                        Math.cos(toRadians(lat2)) *
                    Math.sin(dLon / 2) *
                        Math.sin(dLon / 2);

                const c =
                    2 * Math.atan2(
                        Math.sqrt(a),
                        Math.sqrt(1 - a)
                    );

                return earthRadius * c;
            };

            const programs = allPrograms
                .filter((program) => {
                    return (
                        Number.isFinite(program.latitude) &&
                        Number.isFinite(program.longitude)
                    );
                })
                .map((program) => {
                    const distance = distanceInKilometers(
                        latitude,
                        longitude,
                        program.latitude,
                        program.longitude
                    );

                    return {
                        ...program,
                        distance
                    };
                })
                .filter((program) => {
                    return program.distance <= radius;
                })
                .sort((a, b) => {
                    return a.distance - b.distance;
                });

            return res.json({
                success: true,
                center: {
                    latitude,
                    longitude
                },
                radius,
                count: programs.length,
                programs
            });

        } catch (error) {
            console.error(
                "주변 프로그램 조회 오류:",
                error
            );

            return res.status(503).json({
                success: false,
                message: "주변 프로그램을 불러오지 못했어요."
            });
        }
    };
}

module.exports = {
    publicProgram,
    makeListPrograms,
    makeSearchPrograms,
    makeNearbyPrograms
};
