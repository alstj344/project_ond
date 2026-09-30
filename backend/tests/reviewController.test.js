const test = require("node:test");
const assert = require("node:assert/strict");

const {
    publicReview,
    makeListProgramReviews,
    makeListReviewCounts
} = require("../controllers/reviewController");


// ======================================================
// Firestore Timestamp Mock
// ======================================================

function timestamp(dateString) {
    return {
        toDate() {
            return new Date(dateString);
        }
    };
}


// ======================================================
// 테스트용 리뷰
// ======================================================

const reviewValue = {
    content: "처음 참여했는데 천천히 알려주셔서 좋았어요.",

    createdAt: timestamp(
        "2026-05-07T08:19:00.000Z"
    ),

    facilityName: "테스트 체육센터",

    isSample: true,

    programId: "prg_test_yoga_2026",

    programName: "초보자 릴랙스 요가",

    rating: 5,

    reservationId: "rsv_test_00001",

    updatedAt: null,

    userId: "테스트사용자"
};

test("review paging is bounded and continues from the last raw document", async () => {
    let cursor;
    const query = {
        where() { return this; },
        orderBy(key) { assert.equal(key, "__name__"); return this; },
        startAfter(value) { cursor = value; return this; },
        limit(value) { assert.equal(value, 21); return this; },
        async get() { return { docs: Array.from({ length: 21 }, (_, i) => ({
            id: "r_" + i, data: () => ({ ...reviewValue, content: i === 0 ? "" : "review" })
        })) }; }
    };
    const res = { json(body) { this.body = body; } };
    await makeListProgramReviews({ collection() { return query; } })(
        { params: { programId: "program" }, query: { after: "previous" } }, res);
    assert.equal(cursor, "previous");
    assert.equal(res.body.nextCursor, "r_19");
    assert.equal(res.body.reviews.length, 19);
    assert.equal(res.body.summaryScope, "page");
});

test("invalid review cursor is rejected before a database read", async () => {
    const res = { status(code) { this.code = code; return this; }, json(body) { this.body = body; } };
    await makeListProgramReviews({ collection() { throw new Error("must not read"); } })(
        { params: { programId: "program" }, query: { after: ["invalid"] } }, res);
    assert.equal(res.code, 400);
});


// ======================================================
// publicReview 정상 변환
// ======================================================

test(
    "review returns only public review fields",
    () => {

        const result = publicReview({

            id: "review_1",

            data: () => ({
                ...reviewValue,

                // API에 노출되면 안 되는 임의 필드
                privateNote: "secret"
            })
        });


        assert.equal(
            result.id,
            "review_1"
        );

        assert.equal(
            result.content,
            reviewValue.content
        );

        assert.equal(
            result.facilityName,
            "테스트 체육센터"
        );

        assert.equal(
            result.programId,
            "prg_test_yoga_2026"
        );

        assert.equal(
            result.programName,
            "초보자 릴랙스 요가"
        );

        assert.equal(
            result.rating,
            5
        );

        assert.equal(
            result.reservationId,
            undefined
        );

        assert.equal(
            result.userId,
            undefined
        );

        assert.equal(
            result.isSample,
            true
        );

        assert.equal(
            result.createdAt,
            "2026-05-07T08:19:00.000Z"
        );

        assert.equal(
            result.updatedAt,
            null
        );

        assert.equal(
            result.privateNote,
            undefined
        );
    }
);


// ======================================================
// 필수 필드 검증
// ======================================================

test(
    "review requires content, programId, programName and valid rating",
    () => {

        const invalidReviews = [

            {
                ...reviewValue,
                content: ""
            },

            {
                ...reviewValue,
                programId: ""
            },

            {
                ...reviewValue,
                programName: ""
            },

            {
                ...reviewValue,
                rating: 0
            },

            {
                ...reviewValue,
                rating: 6
            },

            {
                ...reviewValue,
                rating: 4.5
            },

            {
                ...reviewValue,
                rating: "invalid"
            }
        ];


        for (const value of invalidReviews) {

            const result = publicReview({

                id: "invalid",

                data: () => value
            });


            assert.equal(
                result,
                null
            );
        }
    }
);


// ======================================================
// 프로그램별 리뷰 조회
// ======================================================

test(
    "program reviews are returned with average rating",
    async () => {

        const documents = [

            {
                id: "review_1",

                data: () => ({
                    ...reviewValue,

                    rating: 5,

                    createdAt: timestamp(
                        "2026-05-07T08:19:00.000Z"
                    )
                })
            },

            {
                id: "review_2",

                data: () => ({
                    ...reviewValue,

                    content: "편안하게 참여할 수 있었어요.",

                    rating: 4,

                    createdAt: timestamp(
                        "2026-05-08T08:19:00.000Z"
                    )
                })
            }
        ];


        const db = {

            collection(name) {

                assert.equal(
                    name,
                    "reviews"
                );


                return {

                    where(
                        field,
                        operator,
                        value
                    ) {

                        assert.equal(
                            field,
                            "programId"
                        );

                        assert.equal(
                            operator,
                            "=="
                        );

                        assert.equal(
                            value,
                            "prg_test_yoga_2026"
                        );


                        return {

                            orderBy() { return this; },
                            limit(count) { assert.equal(count, 21); return this; },
                            async get() {

                                return {
                                    docs: documents
                                };
                            }
                        };
                    }
                };
            }
        };


        const res = {

            code: 200,

            status(code) {

                this.code = code;

                return this;
            },

            json(body) {

                this.body = body;

                return this;
            }
        };


        await makeListProgramReviews(db)(
            {
                params: {
                    programId:
                        "prg_test_yoga_2026"
                }
            },

            res
        );


        assert.equal(
            res.body.success,
            true
        );

        assert.equal(
            res.body.reviews.length,
            2
        );

        assert.equal(
            res.body.reviewCount,
            2
        );

        // (5 + 4) / 2
        assert.equal(
            res.body.averageRating,
            4.5
        );


        // 최신 리뷰가 먼저
        assert.equal(
            res.body.reviews[0].id,
            "review_2"
        );

        assert.equal(
            res.body.reviews[1].id,
            "review_1"
        );
    }
);


// ======================================================
// 리뷰가 없는 경우
// ======================================================

test(
    "empty review list returns zero count and rating",
    async () => {

        const db = {

            collection() {

                return {

                    where() {

                        return {

                            orderBy() { return this; },
                            limit(count) { assert.equal(count, 21); return this; },
                            async get() {

                                return {
                                    docs: []
                                };
                            }
                        };
                    }
                };
            }
        };


        const res = {

            json(body) {

                this.body = body;

                return this;
            }
        };


        await makeListProgramReviews(db)(
            {
                params: {
                    programId:
                        "prg_test_yoga_2026"
                }
            },

            res
        );


        assert.equal(
            res.body.success,
            true
        );

        assert.deepEqual(
            res.body.reviews,
            []
        );

        assert.equal(
            res.body.reviewCount,
            0
        );

        assert.equal(
            res.body.averageRating,
            0
        );
    }
);


// ======================================================
// 잘못된 programId
// ======================================================

test(
    "invalid programId is rejected before Firestore read",
    async () => {

        let reads = 0;


        const db = {

            collection() {

                reads++;

                throw new Error(
                    "Firestore should not be called"
                );
            }
        };


        const res = {

            status(code) {

                this.code = code;

                return this;
            },

            json(body) {

                this.body = body;

                return this;
            }
        };


        await makeListProgramReviews(db)(
            {
                params: {
                    programId:
                        "../invalid"
                }
            },

            res
        );


        assert.equal(
            res.code,
            400
        );

        assert.equal(
            res.body.success,
            false
        );

        assert.equal(
            reads,
            0
        );
    }
);


// ======================================================
// Firestore 오류가 내부 정보를 노출하지 않는지 확인
// ======================================================

test(
    "database error returns safe response",
    async () => {

        const db = {

            collection() {

                return {

                    where() {

                        return {

                            orderBy() { return this; },
                            limit(count) { assert.equal(count, 21); return this; },
                            async get() {

                                throw new Error(
                                    "secret database error"
                                );
                            }
                        };
                    }
                };
            }
        };


        const res = {

            status(code) {

                this.code = code;

                return this;
            },

            json(body) {

                this.body = body;

                return this;
            }
        };


        await makeListProgramReviews(db)(
            {
                params: {
                    programId:
                        "prg_test_yoga_2026"
                }
            },

            res
        );


        assert.equal(
            res.code,
            503
        );

        assert.equal(
            res.body.success,
            false
        );

        assert.equal(
            JSON.stringify(
                res.body
            ).includes(
                "secret database error"
            ),
            false
        );
    }
);

test("review counts are loaded once and exclude sample reviews", async () => {
    let reads = 0;
    const documents = [
        { id: "r1", data: () => ({ ...reviewValue, isSample: false, programId: "program-a" }) },
        { id: "r2", data: () => ({ ...reviewValue, isSample: false, programId: "program-a" }) },
        { id: "r3", data: () => ({ ...reviewValue, isSample: true, programId: "program-b" }) }
    ];
    const db = {
        collection(name) {
            assert.equal(name, "reviews");
            return { async get() { reads += 1; return { docs: documents }; } };
        }
    };
    const handler = makeListReviewCounts(db);
    const response = () => ({ json(body) { this.body = body; return this; } });
    const first = response();
    const second = response();

    await handler({}, first);
    await handler({}, second);

    assert.deepEqual(first.body.counts, { "program-a": 2 });
    assert.deepEqual(second.body.counts, { "program-a": 2 });
    assert.equal(reads, 1);
});
