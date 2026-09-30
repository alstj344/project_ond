const express = require("express");

const authMiddleware = require("../middleware/authMiddleware");
const {
    getMyProfile,
    deleteMyAccount
} = require("../controllers/userController");

const router = express.Router();
const db = require("../config/firebase");
const { FieldValue } = require("firebase-admin/firestore");
const { makeUpdateMyProfile } = require("../controllers/profileUpdate");


// 내 정보 조회
router.get(
    "/me",
    authMiddleware,
    getMyProfile
);


// 내 정보 수정
router.patch(
    "/me",
    authMiddleware,
    makeUpdateMyProfile(
        db,
        () => FieldValue.serverTimestamp()
    )
);


// 회원탈퇴
router.delete(
    "/me",
    authMiddleware,
    deleteMyAccount
);


module.exports = router;
