const { getAuth } = require("firebase-admin/auth");

const makeAuthMiddleware = (auth = getAuth()) => async (req, res, next) => {
    try {
        // SwiftUI가 보내준 Authorization 헤더
        const authHeader = req.headers.authorization;

        // 토큰이 없는 경우
        if (typeof authHeader !== "string" || !/^Bearer [^\s]+$/.test(authHeader)) {
            return res.status(401).json({
                success: false,
                message: "로그인이 필요합니다."
            });
        }
        const idToken = authHeader.split("Bearer ")[1];
        const decodedToken = await auth.verifyIdToken(idToken, true);
        req.user = decodedToken;

        next();

    } catch (error) {
        console.error("인증 실패:", error.code || "INVALID_TOKEN");

        return res.status(401).json({
            success: false,
            message: "유효하지 않은 로그인 정보입니다."
        });
    }
};

module.exports = (req, res, next) => makeAuthMiddleware()(req, res, next);
module.exports.makeAuthMiddleware = makeAuthMiddleware;
