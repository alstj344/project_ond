const { FieldValue, Timestamp } = require("firebase-admin/firestore");

const { publicProgram } = require("./programController");
const { bookingAvailability } = require("./bookingAvailability");


// ======================================================
// 공통
// ======================================================

function isValidProgramId(programId) {
    return (
        typeof programId === "string" &&
        /^[A-Za-z0-9_-]{1,128}$/.test(programId)
    );
}


// ======================================================
// 예약 생성
//
// POST /api/reservations
// body: { programId: "..." }
// ======================================================

function makeCreateReservation(db) {

    return async (req, res) => {

        const uid = req.user?.uid;
        const { programId } = req.body || {};
        const createdAt = Timestamp.now();

        if (!uid) {
            return res.status(401).json({
                success: false,
                message: "로그인이 필요합니다."
            });
        }

        if (!isValidProgramId(programId)) {
            return res.status(400).json({
                success: false,
                message: "프로그램 정보를 확인해 주세요."
            });
        }


        // 사용자 1명 + 프로그램 1개 = 예약 문서 1개
        const reservationId = `${uid}_${programId}`;

        const programRef = db
            .collection("programs")
            .doc(programId);

        const reservationRef = db
            .collection("reservations")
            .doc(reservationId);


        try {

            await db.runTransaction(async transaction => {

                const programDoc =
                    await transaction.get(programRef);

                const reservationDoc =
                    await transaction.get(reservationRef);


                // 프로그램 존재 확인
                if (!programDoc.exists) {

                    const error =
                        new Error("PROGRAM_NOT_FOUND");

                    error.code =
                        "PROGRAM_NOT_FOUND";

                    throw error;
                }


                const program =
                    publicProgram(programDoc);


                // 프로그램 문서 구조 확인
                //
                // Firebase programs 문서는
                // programId
                // programName
                // facilityName
                // 3개 필드를 사용함
                if (!program) {

                    const error =
                        new Error("INVALID_PROGRAM");

                    error.code =
                        "INVALID_PROGRAM";

                    throw error;
                }


                // 이미 예약되어 있는지 확인
                if (reservationDoc.exists) {

                    const existing =
                        reservationDoc.data();

                    if (
                        existing.status === "RESERVED"
                    ) {

                        const error =
                            new Error("ALREADY_RESERVED");

                        error.code =
                            "ALREADY_RESERVED";

                        throw error;
                    }
                }


                const availability = bookingAvailability(programDoc.data());
                if (!availability.available) {
                    const error = new Error("BOOKING_UNAVAILABLE");
                    error.code = "BOOKING_UNAVAILABLE";
                    error.userMessage = availability.reason;
                    throw error;
                }
                transaction.update(programRef, {
                    reservedCount: programDoc.data().reservedCount + 1
                });

                // 예약 생성 또는 취소된 예약 재활성화
                transaction.set(
                    reservationRef,
                    {
                        uid,
                        programId,

                        status: "RESERVED",
                        capacityTracked: true,

                        createdAt,

                        updatedAt:
                            FieldValue.serverTimestamp(),

                        cancelledAt: null,

                        cancellationReason: null
                    }
                );

            });


            return res.status(201).json({
                success: true,
                message: "예약이 완료되었습니다.",

                reservation: {
                    id: reservationId,
                    programId,
                    createdAt: createdAt.toDate().toISOString(),
                    status: "RESERVED"
                }
            });


        } catch (error) {

            if (error.code === "BOOKING_UNAVAILABLE") {
                return res.status(409).json({ success: false, message: error.userMessage });
            }

            console.error(
                "예약 생성 오류:",
                error
            );


            if (
                error.code ===
                "PROGRAM_NOT_FOUND"
            ) {

                return res.status(404).json({
                    success: false,
                    message:
                        "프로그램을 찾을 수 없습니다."
                });
            }


            if (
                error.code ===
                "INVALID_PROGRAM"
            ) {

                return res.status(409).json({
                    success: false,
                    message:
                        "프로그램 정보가 올바르지 않습니다."
                });
            }


            if (
                error.code ===
                "ALREADY_RESERVED"
            ) {

                return res.status(409).json({
                    success: false,
                    message:
                        "이미 예약한 프로그램입니다."
                });
            }


            return res.status(503).json({
                success: false,
                message:
                    "예약을 처리하지 못했습니다."
            });
        }
    };
}


// ======================================================
// 내 예약 조회
//
// GET /api/reservations/me
// ======================================================

function makeListMyReservations(db) {

    return async (req, res) => {

        const uid = req.user?.uid;


        if (!uid) {

            return res.status(401).json({
                success: false,
                message: "로그인이 필요합니다."
            });
        }


        try {

            const snapshot = await db
                .collection("reservations")
                .where("uid", "==", uid)
                .limit(100)
                .get();


            const rawReservations =
                snapshot.docs.map(doc => {

                    const data =
                        doc.data();

                    return {

                        id: doc.id,

                        programId:
                            data.programId || "",

                        status:
                            data.status || "",

                        createdAt:
                            data.createdAt
                                ?.toDate?.()
                                ?.toISOString()
                            || null,

                        cancelledAt:
                            data.cancelledAt
                                ?.toDate?.()
                                ?.toISOString()
                            || null,

                        cancellationReason:
                            data.cancellationReason
                            || null
                    };
                });


            const programIds = [
                ...new Set(
                    rawReservations
                        .map(
                            item =>
                                item.programId
                        )
                        .filter(Boolean)
                )
            ];


            const programEntries =
                await Promise.all(

                    programIds.map(
                        async programId => {

                            const programDoc =
                                await db
                                    .collection(
                                        "programs"
                                    )
                                    .doc(programId)
                                    .get();


                            if (!programDoc.exists) {

                                return [
                                    programId,
                                    null
                                ];
                            }

                            if (programDoc.data().isTestData === true) return [programId, null, true];


                            const program =
                                publicProgram(
                                    programDoc
                                );


                            return [
                                programId,
                                program
                            ];
                        }
                    )
                );


            const programMap =
                new Map(programEntries);
            const hiddenProgramIDs = new Set(programEntries.filter(entry => entry[2]).map(entry => entry[0]));


            const reservations =
                rawReservations

                    .filter(reservation => !hiddenProgramIDs.has(reservation.programId))

                    .map(
                        reservation => ({
                            ...reservation,

                            program:
                                programMap.get(
                                    reservation.programId
                                ) || null
                        })
                    )

                    .sort((a, b) => {

                        const aTime =
                            a.createdAt
                                ? new Date(
                                    a.createdAt
                                ).getTime()
                                : 0;

                        const bTime =
                            b.createdAt
                                ? new Date(
                                    b.createdAt
                                ).getTime()
                                : 0;

                        return bTime - aTime;
                    });


            return res.status(200).json({
                success: true,
                reservations
            });


        } catch (error) {

            console.error(
                "예약 조회 오류:",
                error
            );


            return res.status(503).json({
                success: false,
                message:
                    "예약 내역을 불러오지 못했습니다."
            });
        }
    };
}


// ======================================================
// 예약 취소
//
// DELETE /api/reservations/:programId
// ======================================================

function makeCancelReservation(db) {

    return async (req, res) => {

        const uid =
            req.user?.uid;

        const { programId } =
            req.params;

        const reason =
            req.body?.reason;


        const reasons = [
            "개인 일정이 생겼어요.",
            "건강상의 이유로 참여가 어려워요.",
            "다른 프로그램으로 변경했어요.",
            "기타"
        ];


        if (!uid) {

            return res.status(401).json({
                success: false,
                message:
                    "로그인이 필요합니다."
            });
        }


        if (
            !isValidProgramId(programId) ||
            (
                reason !== undefined &&
                !reasons.includes(reason)
            )
        ) {

            return res.status(400).json({
                success: false,
                message:
                    "프로그램 정보를 확인해 주세요."
            });
        }


        const reservationId =
            `${uid}_${programId}`;


        const reservationRef =
            db
                .collection("reservations")
                .doc(reservationId);


        try {

            await db.runTransaction(
                async transaction => {

                    const reservationDoc =
                        await transaction.get(
                            reservationRef
                        );


                    if (
                        !reservationDoc.exists
                    ) {

                        const error =
                            new Error(
                                "NOT_RESERVED"
                            );

                        error.code =
                            "NOT_RESERVED";

                        throw error;
                    }


                    const reservation =
                        reservationDoc.data();


                    // 다른 사용자의 예약 접근 방지
                    if (
                        reservation.uid !== uid ||
                        reservation.programId !==
                            programId
                    ) {

                        const error =
                            new Error(
                                "NOT_RESERVED"
                            );

                        error.code =
                            "NOT_RESERVED";

                        throw error;
                    }


                    // 이미 취소된 예약인지 확인
                    if (
                        reservation.status !==
                        "RESERVED"
                    ) {

                        const error =
                            new Error(
                                "NOT_RESERVED"
                            );

                        error.code =
                            "NOT_RESERVED";

                        throw error;
                    }


                    // Legacy reservations never consumed a seat.
                    if (reservation.capacityTracked === true) {
                        const programRef = db.collection("programs").doc(programId);
                        const programDoc = await transaction.get(programRef);
                        const count = programDoc.data()?.reservedCount;
                        if (!programDoc.exists || !Number.isSafeInteger(count) || count < 1) {
                            throw new Error("INVALID_CAPACITY");
                        }
                        transaction.update(programRef, { reservedCount: count - 1 });
                    }
                    transaction.update(
                        reservationRef,
                        {

                            status:
                                "CANCELLED",

                            cancelledAt:
                                FieldValue
                                    .serverTimestamp(),

                            cancellationReason:
                                reason || null,

                            updatedAt:
                                FieldValue
                                    .serverTimestamp()
                        }
                    );
                }
            );


            return res.status(200).json({
                success: true,
                message:
                    "예약이 취소되었습니다."
            });


        } catch (error) {

            console.error(
                "예약 취소 오류:",
                error
            );


            if (
                error.code ===
                "NOT_RESERVED"
            ) {

                return res.status(404).json({
                    success: false,
                    message:
                        "예약 내역을 찾을 수 없습니다."
                });
            }


            return res.status(503).json({
                success: false,
                message:
                    "예약을 취소하지 못했습니다."
            });
        }
    };
}


// ======================================================
// Export
// ======================================================

module.exports = {
    makeCreateReservation,
    makeListMyReservations,
    makeCancelReservation
};
