const express = require("express");

const db = require("../config/firebase");
const authMiddleware = require("../middleware/authMiddleware");

const {
    makeCreateReservation,
    makeListMyReservations,
    makeCancelReservation
} = require("../controllers/reservationController");

const router = express.Router();


// 예약 생성
// POST /api/reservations
router.post(
    "/",
    authMiddleware,
    makeCreateReservation(db)
);


// 내 예약 조회
// GET /api/reservations/me
router.get(
    "/me",
    authMiddleware,
    makeListMyReservations(db)
);


// 예약 취소
// DELETE /api/reservations/:programId
router.delete(
    "/:programId",
    authMiddleware,
    makeCancelReservation(db)
);


module.exports = router;
