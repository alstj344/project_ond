const db = require("../config/firebase");
const { getAuth } = require("firebase-admin/auth");
const { FieldValue } = require("firebase-admin/firestore");
const { ensureUserProfile } = require("./userProfile");


// ======================================================
// 내 정보 조회
// GET /api/users/me
// ======================================================

const getMyProfile = async (req, res) => {
    try {
        const uid = req.user?.uid;

        if (!uid) {
            return res.status(401).json({
                success: false,
                message: "로그인이 필요합니다."
            });
        }

        const profile = await ensureUserProfile(db, req.user, () => FieldValue.serverTimestamp());

        return res.status(200).json({
            success: true,
            user: {
                ...profile,
                id: uid,
                email: req.user.email || ""
            }
        });

    } catch (error) {
        console.error("회원 조회 오류:", error);

        return res.status(500).json({
            success: false,
            message: "회원 정보를 불러오는 중 오류가 발생했습니다."
        });
    }
};


// ======================================================
// 회원탈퇴
// DELETE /api/users/me
// ======================================================

const deleteMyAccount = async (req, res) => {
    const uid = req.user?.uid;

    if (!uid) {
        return res.status(401).json({
            success: false,
            message: "로그인이 필요합니다."
        });
    }

    try {
        // ==================================================
        // 1. 사용자의 예약 내역 조회
        // ==================================================

        const reservationSnapshot = await db
            .collection("reservations")
            .where("uid", "==", uid)
            .get();


        // ==================================================
        // 2. 예약 데이터 정리
        // ==================================================

        for (const reservationDoc of reservationSnapshot.docs) {
            const reservation = reservationDoc.data();

            // 현재 활성화된 예약인 경우
            if (
                reservation.status === "RESERVED" &&
                typeof reservation.programId === "string" &&
                reservation.programId.length > 0
            ) {
                const programRef = db
                    .collection("programs")
                    .doc(reservation.programId);

                await db.runTransaction(async transaction => {
                    const programDoc =
                        await transaction.get(programRef);

                    // 프로그램이 아직 존재하는 경우
                    if (programDoc.exists) {
                        const program = programDoc.data();

                        const reservedCount =
                            Number.isInteger(program.reservedCount)
                                ? program.reservedCount
                                : 0;

                        // 예약 인원 1명 감소
                        transaction.update(programRef, {
                            reservedCount: Math.max(
                                0,
                                reservedCount - 1
                            )
                        });
                    }

                    // 예약 문서 삭제
                    transaction.delete(reservationDoc.ref);
                });

            } else {
                // 이미 취소된 예약 등도 개인정보 삭제
                await reservationDoc.ref.delete();
            }
        }


        // ==================================================
        // 3. Firestore 사용자 프로필 삭제
        // ==================================================

        await db
            .collection("users")
            .doc(uid)
            .delete();


        // ==================================================
        // 4. Firebase Authentication 계정 삭제
        // ==================================================

        await getAuth().deleteUser(uid);


        console.log(`[Account Delete] 완료: ${uid}`);


        // ==================================================
        // 5. 성공 응답
        // ==================================================

        return res.status(200).json({
            success: true,
            message: "회원탈퇴가 완료되었습니다."
        });

    } catch (error) {
        console.error("회원탈퇴 오류:", error);

        return res.status(500).json({
            success: false,
            message: "회원탈퇴 처리 중 오류가 발생했습니다."
        });
    }
};


// ======================================================
// Export
// ======================================================

module.exports = {
    getMyProfile,
    deleteMyAccount
};
