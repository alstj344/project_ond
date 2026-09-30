const test = require("node:test");
const assert = require("node:assert/strict");

const {
    makeCreateReservation,
    makeCancelReservation,
    makeListMyReservations
} = require("../controllers/reservationController");

const {
    makeAuthMiddleware
} = require("../middleware/authMiddleware");

test("creation returns the receipt timestamp saved with the reservation", async () => {
    const db = database();
    const res = response();
    await makeCreateReservation(db)({ user: { uid: "receipt-owner" }, body: { programId: "yoga" } }, res);
    assert.equal(res.code, 201);
    assert.equal(res.body.reservation.createdAt,
        db.documents.get("reservations/receipt-owner_yoga").createdAt.toDate().toISOString());
});

test("retired test programs are excluded for their reservation owner", async () => {
    const db = database();
    db.documents.get("programs/yoga").isTestData = true;
    db.documents.set("reservations/alice_yoga", { uid: "alice", programId: "yoga", status: "RESERVED" });
    const res = response();
    await makeListMyReservations(db)({ user: { uid: "alice" } }, res);
    assert.deepEqual(res.body.reservations, []);
});


// ======================================================
// Response Mock
// ======================================================

function response() {

    return {

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
}


// ======================================================
// Firestore Mock
// ======================================================

function database() {

    const documents = new Map([

        [
            "programs/yoga",

            {
                programId: "yoga",
                programName: "초보자 릴랙스 요가",
                facilityName: "테스트 체육센터",
                status: "OPEN",
                startAt: { toDate: () => new Date(Date.now() + 86400000) },
                endAt: { toDate: () => new Date(Date.now() + 90000000) },
                capacity: 5,
                reservedCount: 0,
                price: 0
            }
        ]
    ]);


    let queue =
        Promise.resolve();

    let reads = 0;


    const snapshot = key => ({

        id:
            key.split("/")[1],

        exists:
            documents.has(key),

        data: () =>
            documents.get(key)
    });


    const db = {

        documents,


        get reads() {
            return reads;
        },


        collection(name) {

            return {

                doc(id) {

                    const key =
                        `${name}/${id}`;

                    return {

                        key,

                        async get() {

                            return snapshot(
                                key
                            );
                        }
                    };
                },


                where(
                    field,
                    operator,
                    value
                ) {

                    assert.equal(
                        field,
                        "uid"
                    );

                    assert.equal(
                        operator,
                        "=="
                    );


                    return {

                        limit(number) {

                            assert.equal(
                                number,
                                100
                            );


                            return {

                                async get() {

                                    const docs =
                                        [
                                            ...documents.keys()
                                        ]

                                            .filter(
                                                key =>
                                                    key.startsWith(
                                                        `${name}/`
                                                    ) &&
                                                    documents.get(
                                                        key
                                                    ).uid ===
                                                        value
                                            )

                                            .map(
                                                snapshot
                                            )

                                            .slice(
                                                0,
                                                number
                                            );


                                    return {
                                        docs
                                    };
                                }
                            };
                        }
                    };
                }
            };
        },


        runTransaction(callback) {

            const run =
                queue.then(
                    async () => {

                        const writes = [];


                        await callback({

                            async get(ref) {

                                reads++;

                                return snapshot(
                                    ref.key
                                );
                            },


                            set(
                                ref,
                                value
                            ) {

                                writes.push(
                                    () =>
                                        documents.set(
                                            ref.key,
                                            value
                                        )
                                );
                            },


                            update(
                                ref,
                                value
                            ) {

                                writes.push(
                                    () =>
                                        documents.set(
                                            ref.key,
                                            {
                                                ...documents.get(
                                                    ref.key
                                                ),

                                                ...value
                                            }
                                        )
                                );
                            }
                        });


                        writes.forEach(
                            write =>
                                write()
                        );
                    }
                );


            queue =
                run.catch(
                    () => {}
                );


            return run;
        }
    };


    return db;
}


// ======================================================
// Helpers
// ======================================================

async function create(
    db,
    uid = "alice",
    body = {
        programId: "yoga"
    }
) {

    const res =
        response();


    await makeCreateReservation(db)(
        {
            user:
                uid
                    ? { uid }
                    : undefined,

            body
        },

        res
    );


    return res;
}


async function cancel(
    db,
    uid,
    reason
) {

    const res =
        response();


    await makeCancelReservation(db)(
        {
            user: {
                uid
            },

            params: {
                programId:
                    "yoga"
            },

            body:
                reason
                    ? { reason }
                    : {}
        },

        res
    );


    return res;
}

test("missing, closed, past, paid and invalid sessions cannot create bookings", async () => {
    for (const change of [
        { startAt: null }, { endAt: null }, { capacity: null },
        { reservedCount: -1 }, { price: null }, { price: 1000 },
        { status: "CLOSED" }, { startAt: { toDate: () => new Date(0) } }
    ]) {
        const db = database();
        Object.assign(db.documents.get("programs/yoga"), change);
        assert.equal((await create(db)).code, 409);
        assert.equal(db.documents.has("reservations/alice_yoga"), false);
    }
});

test("last seat is allocated once and restored once by cancellation", async () => {
    const db = database();
    db.documents.get("programs/yoga").capacity = 1;
    const results = await Promise.all([create(db, "alice"), create(db, "bob")]);
    assert.deepEqual(results.map(r => r.code).sort(), [201, 409]);
    assert.equal(db.documents.get("programs/yoga").reservedCount, 1);
    const winner = results[0].code === 201 ? "alice" : "bob";
    assert.equal((await cancel(db, winner)).code, 200);
    assert.equal(db.documents.get("programs/yoga").reservedCount, 0);
    assert.equal((await cancel(db, winner)).code, 404);
    assert.equal(db.documents.get("programs/yoga").reservedCount, 0);
});

test("legacy reservation cancellation does not decrement capacity", async () => {
    const db = database();
    db.documents.set("reservations/alice_yoga", { uid: "alice", programId: "yoga", status: "RESERVED" });
    assert.equal((await cancel(db, "alice")).code, 200);
    assert.equal(db.documents.get("programs/yoga").reservedCount, 0);
});


// ======================================================
// 인증 / programId 검증
// ======================================================

test(
    "authentication and invalid IDs cannot write",
    async () => {

        const db =
            database();


        assert.equal(
            (
                await create(
                    db,
                    null
                )
            ).code,
            401
        );


        assert.equal(
            (
                await create(
                    db,
                    "alice",
                    {
                        programId:
                            "../other"
                    }
                )
            ).code,
            400
        );


        assert.equal(
            db.reads,
            0
        );
    }
);


// ======================================================
// 존재하지 않는 프로그램
// ======================================================

test(
    "nonexistent program cannot be reserved",
    async () => {

        const db =
            database();


        const result =
            await create(
                db,
                "alice",
                {
                    programId:
                        "missing"
                }
            );


        assert.equal(
            result.code,
            404
        );


        assert.equal(
            db.documents.has(
                "reservations/alice_missing"
            ),
            false
        );
    }
);


// ======================================================
// 예약 생성 / UID 위조 방지
// ======================================================

test(
    "reservation uses authenticated uid and duplicate booking is rejected",
    async () => {

        const db =
            database();


        const result =
            await create(
                db,
                "alice",
                {
                    programId:
                        "yoga",

                    // 클라이언트에서 UID를 보내도
                    // 서버에서는 무시해야 함
                    uid:
                        "bob"
                }
            );


        assert.equal(
            result.code,
            201
        );


        assert.equal(
            result.body.reservation.programId,
            "yoga"
        );


        const reservation =
            db.documents.get(
                "reservations/alice_yoga"
            );


        assert.equal(
            reservation.uid,
            "alice"
        );


        assert.equal(
            reservation.programId,
            "yoga"
        );


        assert.equal(
            reservation.status,
            "RESERVED"
        );


        // 같은 사용자의 중복 예약
        const duplicate =
            await create(
                db,
                "alice"
            );


        assert.equal(
            duplicate.code,
            409
        );
    }
);


// ======================================================
// 서로 다른 사용자 예약
// ======================================================

test(
    "different users can reserve the same program",
    async () => {

        const db =
            database();


        const alice =
            await create(
                db,
                "alice"
            );


        const bob =
            await create(
                db,
                "bob"
            );


        assert.equal(
            alice.code,
            201
        );


        assert.equal(
            bob.code,
            201
        );


        assert.equal(
            db.documents.has(
                "reservations/alice_yoga"
            ),
            true
        );


        assert.equal(
            db.documents.has(
                "reservations/bob_yoga"
            ),
            true
        );
    }
);


// ======================================================
// 예약 취소 + 재예약
// ======================================================

test(
    "cancellation is owner scoped and rebooking works",
    async () => {

        const db =
            database();


        await create(
            db,
            "alice"
        );


        // 다른 사용자 취소 시도
        assert.equal(
            (
                await cancel(
                    db,
                    "bob"
                )
            ).code,
            404
        );


        assert.equal(
            db.documents.get(
                "reservations/alice_yoga"
            ).status,
            "RESERVED"
        );


        // 본인 취소
        assert.equal(
            (
                await cancel(
                    db,
                    "alice"
                )
            ).code,
            200
        );


        assert.equal(
            db.documents.get(
                "reservations/alice_yoga"
            ).status,
            "CANCELLED"
        );


        // 이미 취소한 예약 다시 취소
        assert.equal(
            (
                await cancel(
                    db,
                    "alice"
                )
            ).code,
            404
        );


        // 취소 후 재예약
        assert.equal(
            (
                await create(
                    db,
                    "alice"
                )
            ).code,
            201
        );


        assert.equal(
            db.documents.get(
                "reservations/alice_yoga"
            ).status,
            "RESERVED"
        );
    }
);


// ======================================================
// 내 예약 조회
// ======================================================

test(
    "list returns only authenticated user's reservations",
    async () => {

        const db =
            database();


        await create(
            db,
            "alice"
        );


        await create(
            db,
            "bob"
        );


        const res =
            response();


        await makeListMyReservations(db)(
            {
                user: {
                    uid:
                        "alice"
                }
            },

            res
        );


        assert.equal(
            res.code,
            200
        );


        assert.equal(
            res.body.reservations.length,
            1
        );


        const reservation =
            res.body.reservations[0];


        assert.equal(
            reservation.id,
            "alice_yoga"
        );


        assert.equal(
            reservation.programId,
            "yoga"
        );


        assert.equal(
            reservation.program.programId,
            "yoga"
        );


        assert.equal(
            reservation.program.programName,
            "초보자 릴랙스 요가"
        );


        assert.equal(
            reservation.program.facilityName,
            "테스트 체육센터"
        );
    }
);


// ======================================================
// 취소 사유
// ======================================================

test(
    "cancellation reason is validated and persisted",
    async () => {

        const db =
            database();


        await create(
            db,
            "alice"
        );


        const handler =
            makeCancelReservation(
                db
            );


        // 허용되지 않은 취소 사유
        const invalid =
            response();


        await handler(
            {
                user: {
                    uid:
                        "alice"
                },

                params: {
                    programId:
                        "yoga"
                },

                body: {
                    reason:
                        "unbounded arbitrary data"
                }
            },

            invalid
        );


        assert.equal(
            invalid.code,
            400
        );


        assert.equal(
            db.documents.get(
                "reservations/alice_yoga"
            ).status,
            "RESERVED"
        );


        // 정상 취소
        const valid =
            response();


        await handler(
            {
                user: {
                    uid:
                        "alice"
                },

                params: {
                    programId:
                        "yoga"
                },

                body: {
                    reason:
                        "기타"
                }
            },

            valid
        );


        assert.equal(
            valid.code,
            200
        );


        assert.equal(
            db.documents.get(
                "reservations/alice_yoga"
            ).cancellationReason,
            "기타"
        );


        assert.equal(
            db.documents.get(
                "reservations/alice_yoga"
            ).status,
            "CANCELLED"
        );
    }
);


// ======================================================
// Firebase Auth Middleware
// ======================================================

test(
    "auth requires a single bearer token and checks revocation",
    async () => {

        let calls = 0;


        const middleware =
            makeAuthMiddleware({

                async verifyIdToken(
                    token,
                    revoked
                ) {

                    calls++;

                    assert.equal(
                        token,
                        "valid"
                    );

                    assert.equal(
                        revoked,
                        true
                    );

                    return {
                        uid:
                            "alice"
                    };
                }
            });


        for (
            const authorization
            of [
                undefined,
                "Bearer ",
                "Bearer a b",
                "Basic valid"
            ]
        ) {

            const res =
                response();


            await middleware(
                {
                    headers: {
                        authorization
                    }
                },

                res,

                () =>
                    assert.fail(
                        "authorized invalid header"
                    )
            );


            assert.equal(
                res.code,
                401
            );
        }


        assert.equal(
            calls,
            0
        );


        const req = {

            headers: {
                authorization:
                    "Bearer valid"
            }
        };


        let nextCalled =
            false;


        await middleware(
            req,
            response(),

            () => {
                nextCalled =
                    true;
            }
        );


        assert.equal(
            req.user.uid,
            "alice"
        );


        assert.equal(
            nextCalled,
            true
        );


        const res =
            response();


        await makeAuthMiddleware({

            async verifyIdToken() {

                throw {
                    code:
                        "auth/id-token-revoked"
                };
            }

        })(
            req,
            res,

            () =>
                assert.fail()
        );


        assert.equal(
            res.code,
            401
        );
    }
);
