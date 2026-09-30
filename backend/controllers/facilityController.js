const text = value =>
    typeof value === "string" ? value.trim() : "";


// ======================================================
// Firestore document -> API response
// ======================================================

function publicFacility(doc) {

    const d = doc.data();

    // 서울 + 2026년 7월 + 정상운영 시설만 사용
    if (
        d.province !== "서울특별시" ||
        d.source?.snapshot !== "202607" ||
        d.sourceOperationStatus !== "정상운영"
    ) {
        return null;
    }

    if (!text(d.name) || !text(d.address)) {
        return null;
    }

    const located =
        Number.isFinite(d.latitude) &&
        Number.isFinite(d.longitude) &&
        d.latitude >= 33 &&
        d.latitude <= 39 &&
        d.longitude >= 124 &&
        d.longitude <= 132;


    // --------------------------------------------------
    // 주변 대중교통
    // --------------------------------------------------

    const nearbyTransit = (
        Array.isArray(d.nearbyTransit)
            ? d.nearbyTransit
            : []
    )
        .slice(0, 5)
        .map(stop => ({

            name: text(stop.name),

            type: text(stop.type) || text(stop.mode),

            distanceMeters:
                Number.isFinite(stop.distanceMeters) && stop.distanceMeters >= 0
                    ? Math.round(stop.distanceMeters)
                    : null,

            distanceType:
                text(stop.distanceType) || null,

            latitude:
                Number.isFinite(stop.latitude)
                    ? stop.latitude
                    : null,

            longitude:
                Number.isFinite(stop.longitude)
                    ? stop.longitude
                    : null,

            walkingTimeMinutes:
                Number.isFinite(stop.walkingTimeMinutes) && stop.walkingTimeMinutes >= 0
                    ? Math.round(stop.walkingTimeMinutes)
                    : null

        }))
        .filter(stop => stop.name);


    return {

        id: doc.id,

        name: text(d.name),

        address: text(d.address),

        addressDetail: text(d.addressDetail),

        category: text(d.category),

        facilityType: text(d.facilityType),

        district: text(d.district),

        latitude: located
            ? d.latitude
            : null,

        longitude: located
            ? d.longitude
            : null,

        phone: text(d.phone),

        bookingEnabled: false,

        sourceSnapshot: "202607",

        nearbyTransit
    };
}


// ======================================================
// 거리 계산
// ======================================================

function distance(lat, lon, facility) {

    const rad = value =>
        value * Math.PI / 180;

    const a =
        Math.sin(
            rad(facility.latitude - lat) / 2
        ) ** 2 +

        Math.cos(rad(lat)) *
        Math.cos(rad(facility.latitude)) *

        Math.sin(
            rad(facility.longitude - lon) / 2
        ) ** 2;

    return (
        6371 *
        2 *
        Math.asin(
            Math.sqrt(
                Math.min(1, a)
            )
        )
    );
}


// ======================================================
// 문자열 정규화
// ======================================================

function normalize(value) {

    return text(value)
        .normalize("NFKC")
        .toLocaleLowerCase();
}


// ======================================================
// API
// ======================================================

function makeListFacilities(db, options = {}) {
    return require("./facilitySearch").makeSearch(db, { ...options, publicFacility, distance });
}


// ======================================================
// exports
// ======================================================

module.exports = {

    makeListFacilities,

    publicFacility,

    distance
};
