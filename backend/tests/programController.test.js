const test = require("node:test");
const assert = require("node:assert/strict");

const {
    publicProgram,
    makeListPrograms
} = require("../controllers/programController");


// ======================================================
// 테스트용 프로그램 데이터
//
// 실제 Firebase programs 구조와 동일
// ======================================================

const value = {
    programId: "prg_test_yoga_2026",
    programName: "초보자 릴랙스 요가",
    facilityName: "테스트 체육센터"
};


// ======================================================
// publicProgram
// ======================================================

test(
    "program returns only current public fields",
    () => {

        const result = publicProgram({
            id: "prg_test_yoga_2026",

            data: () => ({
                ...value,

                // 혹시 다른 필드가 있어도
                // API에서는 노출하지 않는지 확인
                privateNote: "secret"
            })
        });


        assert.deepEqual(
            result,
            {
                id: "prg_test_yoga_2026",
                programId: "prg_test_yoga_2026",
                programName: "초보자 릴랙스 요가",
                facilityName: "테스트 체육센터",
                bookingAvailable: false,
                bookingUnavailableReason: "예약 일정 준비 중"
            }
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
    "program requires programId, programName and facilityName",
    () => {

        const invalidPrograms = [

            {
                ...value,
                programId: ""
            },

            {
                ...value,
                programName: ""
            },

            {
                ...value,
                facilityName: ""
            },

            {
                ...value,
                programId: null
            },

            {
                ...value,
                programName: null
            },

            {
                ...value,
                facilityName: null
            }
        ];


        for (const invalid of invalidPrograms) {

            const result =
                publicProgram({
                    id: "bad",
                    data: () => invalid
                });


            assert.equal(
                result,
                null
            );
        }
    }
);


// ======================================================
// 프로그램 목록 페이지네이션
// ======================================================

test(
    "bounded paging returns 20 programs and cursor",
    async () => {

        const query = {

            orderBy(key) {

                assert.equal(
                    key,
                    "__name__"
                );

                return this;
            },


            limit(number) {

                assert.equal(
                    number,
                    21
                );

                return this;
            },


            async get() {

                return {

                    docs: Array.from(
                        { length: 21 },

                        (_, index) => ({

                            id:
                                `prg_test_${index}`,

                            data: () => ({

                                programId:
                                    `prg_test_${index}`,

                                programName:
                                    `프로그램 ${index}`,

                                facilityName:
                                    "테스트 체육센터"
                            })
                        })
                    )
                };
            }
        };


        const db = {

            collection(name) {

                assert.equal(
                    name,
                    "programs"
                );

                return query;
            }
        };


        const res = {

            json(body) {

                this.body = body;

                return this;
            }
        };


        await makeListPrograms(db)(
            {
                query: {}
            },
            res
        );


        assert.equal(
            res.body.success,
            true
        );


        assert.equal(
            res.body.programs.length,
            20
        );


        assert.equal(
            res.body.nextCursor,
            "prg_test_19"
        );
    }
);


// ======================================================
// 커서 적용
// ======================================================

test(
    "valid cursor is applied to program query",
    async () => {

        let receivedCursor = null;


        const query = {

            orderBy() {
                return this;
            },


            startAfter(cursor) {

                receivedCursor =
                    cursor;

                return this;
            },


            limit() {
                return this;
            },


            async get() {

                return {
                    docs: []
                };
            }
        };


        const db = {

            collection() {
                return query;
            }
        };


        const res = {

            json(body) {

                this.body = body;

                return this;
            }
        };


        await makeListPrograms(db)(
            {
                query: {
                    after:
                        "prg_test_19"
                }
            },
            res
        );


        assert.equal(
            receivedCursor,
            "prg_test_19"
        );


        assert.equal(
            res.body.success,
            true
        );


        assert.deepEqual(
            res.body.programs,
            []
        );
    }
);


// ======================================================
// 잘못된 커서 / DB 오류
// ======================================================

test(
    "invalid cursor and database error are safe",
    async () => {

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


        const handler =
            makeListPrograms({

                collection() {

                    throw Error(
                        "secret"
                    );
                }
            });


        // 잘못된 cursor
        await handler(
            {
                query: {
                    after: "../bad"
                }
            },
            res
        );


        assert.equal(
            res.code,
            400
        );


        // DB 오류
        await handler(
            {
                query: {}
            },
            res
        );


        assert.equal(
            res.code,
            503
        );


        // 내부 오류 메시지가
        // 사용자에게 노출되면 안 됨
        assert.equal(
            JSON.stringify(
                res.body
            ).includes("secret"),
            false
        );
    }
);

test("program pages are cached to avoid repeated Firestore reads", async () => {
    let reads = 0;
    const query = {
        orderBy() { return this; },
        limit(value) { assert.equal(value, 21); return this; },
        async get() {
            reads += 1;
            return { docs: [] };
        }
    };
    const handler = makeListPrograms({ collection() { return query; } });
    const response = () => ({ json(body) { this.body = body; return this; } });
    const first = response();
    const second = response();

    await handler({ query: {} }, first);
    await handler({ query: {} }, second);

    assert.equal(first.body.success, true);
    assert.equal(second.body.success, true);
    assert.equal(reads, 1);
});
