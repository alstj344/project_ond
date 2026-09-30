const LIMIT = 30;

const text = value =>
  typeof value === "string"
    ? value.trim()
    : "";


// ======================================================
// Firestore 시설 데이터를 앱에 전달할 형태로 변환
// ======================================================

function publicFacility(doc) {
  const d = doc.data();

  // 서울 + 202607 데이터 + 정상운영 시설만 사용
  if (
    d.province !== "서울특별시" ||
    d.source?.snapshot !== "202607" ||
    d.sourceOperationStatus !== "정상운영"
  ) {
    return null;
  }

  // 이름이나 주소가 없는 시설 제외
  if (
    !text(d.name) ||
    !text(d.address)
  ) {
    return null;
  }


  // ====================================================
  // 시설 좌표 확인
  // ====================================================

  const located =
    Number.isFinite(d.latitude) &&
    Number.isFinite(d.longitude) &&
    d.latitude >= 33 &&
    d.latitude <= 39 &&
    d.longitude >= 124 &&
    d.longitude <= 132;


  // ====================================================
  // 주변 대중교통
  // ====================================================

  const nearbyTransit = (
    Array.isArray(d.nearbyTransit)
      ? d.nearbyTransit
      : []
  )
    .slice(0, 5)

    .map(s => ({
      name: text(s.name),

      type: text(s.type),

      distanceMeters:
        Number.isFinite(s.distanceMeters)
          ? s.distanceMeters
          : null,

      distanceType:
        text(s.distanceType) || null,

      latitude:
        Number.isFinite(s.latitude)
          ? s.latitude
          : null,

      longitude:
        Number.isFinite(s.longitude)
          ? s.longitude
          : null,

      walkingTimeMinutes:
        Number.isFinite(s.walkingTimeMinutes)
          ? s.walkingTimeMinutes
          : null
    }))

    // 이름 없는 정류장 제외
    .filter(s => s.name);


  // ====================================================
  // 앱에 전달할 시설 데이터
  // ====================================================

  return {
    id: doc.id,

    name: text(d.name),

    address: text(d.address),

    addressDetail:
      text(d.addressDetail),

    category:
      text(d.category),

    facilityType:
      text(d.facilityType),

    district:
      text(d.district),

    latitude:
      located
        ? d.latitude
        : null,

    longitude:
      located
        ? d.longitude
        : null,

    phone:
      text(d.phone),

    bookingEnabled: false,

    sourceSnapshot: "202607",

    nearbyTransit
  };
}


// ======================================================
// 두 좌표 사이 거리 계산 (km)
// ======================================================

function distance(
  lat,
  lon,
  facility
) {

  const rad =
    x => x * Math.PI / 180;


  const a =
    Math.sin(
      rad(
        facility.latitude - lat
      ) / 2
    ) ** 2 +

    Math.cos(
      rad(lat)
    ) *

    Math.cos(
      rad(facility.latitude)
    ) *

    Math.sin(
      rad(
        facility.longitude - lon
      ) / 2
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
// 시설 목록 API
// ======================================================

function makeListFacilities(
  db,
  now = Date.now
) {

  let cached;
  let expires = 0;
  let pending;


  // ====================================================
  // Firestore 시설 목록 로드
  // ====================================================

  async function catalogue() {

    // 캐시가 아직 유효하면 재사용
    if (
      cached &&
      now() < expires
    ) {
      return cached;
    }


    if (!pending) {

      pending = (
        async () => {

          const snap =
            await db
              .collection("facilities")

              .where(
                "province",
                "==",
                "서울특별시"
              )

              .select(
                "name",
                "address",
                "addressDetail",
                "category",
                "facilityType",
                "district",
                "province",
                "latitude",
                "longitude",
                "phone",

                // 주변 대중교통
                "nearbyTransit",

                "source",
                "sourceOperationStatus"
              )

              .limit(15001)

              .get();


          if (
            snap.docs.length > 15000
          ) {
            throw Error(
              "Catalogue exceeds configured bound"
            );
          }


          cached =
            snap.docs
              .map(publicFacility)
              .filter(Boolean);


          // 1시간 캐시
          expires =
            now() +
            60 * 60 * 1000;


          return cached;

        }
      )()

        .finally(() => {
          pending = undefined;
        });
    }


    return pending;
  }


  // ====================================================
  // 실제 API 요청 처리
  // ====================================================

  return async (req, res) => {

    const q =
      req.query || {};


    const allowed = [
      "q",
      "category",
      "page",
      "lat",
      "lon",
      "radius"
    ];


    // 허용하지 않은 query parameter 검사
    if (
      Object
        .keys(q)
        .some(
          k =>
            !allowed.includes(k)
        ) ||

      Object
        .values(q)
        .some(
          v =>
            typeof v !== "string"
        )
    ) {

      return res
        .status(400)
        .json({
          success: false,
          error: "Invalid query"
        });
    }


    // ==================================================
    // 검색 조건
    // ==================================================

    const search =
      text(q.q)
        .normalize("NFKC")
        .toLocaleLowerCase();


    const category =
      text(q.category);


    const page =
      Number(
        q.page ?? 0
      );


    const nearby =
      q.lat !== undefined ||
      q.lon !== undefined ||
      q.radius !== undefined;


    const lat =
      Number(q.lat);


    const lon =
      Number(q.lon);


    const radius =
      Number(
        q.radius ?? 3
      );


    // ==================================================
    // 요청값 검증
    // ==================================================

    if (
      search.length > 100 ||

      category.length > 60 ||

      !Number.isInteger(page) ||

      page < 0 ||

      page > 500 ||

      (
        nearby &&
        (
          !q.lat ||
          !q.lon ||

          !Number.isFinite(lat) ||
          !Number.isFinite(lon) ||

          lat < 33 ||
          lat > 39 ||

          lon < 124 ||
          lon > 132 ||

          !Number.isFinite(radius) ||

          radius < 0.5 ||
          radius > 10
        )
      )
    ) {

      return res
        .status(400)
        .json({
          success: false,
          error: "Invalid query"
        });
    }


    // ==================================================
    // 시설 검색
    // ==================================================

    try {

      const all =
        await catalogue();


      // 시설 유형 목록
      const categories = [
        ...new Set(
          all
            .map(
              f =>
                f.facilityType
            )
            .filter(Boolean)
        )
      ].sort();


      // =================================================
      // 검색 + 카테고리 필터
      // =================================================

      const matched =
        all

          .filter(
            f =>

              (
                !category ||
                f.facilityType === category
              ) &&

              (
                !search ||

                `${f.name} ${f.address} ${f.district} ${f.facilityType}`

                  .normalize("NFKC")

                  .toLocaleLowerCase()

                  .includes(search)
              )
          )


          // 현재 위치와의 거리 계산
          .map(
            f => ({
              ...f,

              distanceKm:
                nearby &&
                f.latitude !== null

                  ? distance(
                      lat,
                      lon,
                      f
                    )

                  : null
            })
          )


          // 반경 필터
          .filter(
            f =>
              !nearby ||

              (
                f.distanceKm !== null &&
                f.distanceKm <= radius
              )
          )


          // 정렬
          .sort(
            (a, b) =>

              (
                nearby
                  ? a.distanceKm -
                    b.distanceKm
                  : 0
              ) ||

              a.name.localeCompare(
                b.name,
                "ko"
              ) ||

              a.id.localeCompare(
                b.id
              )
          );


      // =================================================
      // 페이지네이션
      // =================================================

      const start =
        page * LIMIT;


      // =================================================
      // 응답
      // =================================================

      res.json({

        success: true,

        facilities:
          matched.slice(
            start,
            start + LIMIT
          ),

        total:
          matched.length,

        nextPage:
          start + LIMIT <
          matched.length

            ? page + 1
            : null,

        categories
      });


    } catch (error) {

      console.error(
        "시설 목록 조회 오류:",
        error
      );


      res
        .status(503)
        .json({
          success: false,
          error:
            "Facilities temporarily unavailable"
        });
    }
  };
}


// ======================================================
// export
// ======================================================

module.exports = {
  makeListFacilities,
  publicFacility,
  distance
};