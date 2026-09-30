require("dotenv").config();

const express = require("express");

const db = require("./config/firebase");

const userRoutes = require("./routes/userRoutes");

const {
    makeListFacilities
} = require("./controllers/facilityController");

const {
    makeListPrograms,
    makeSearchPrograms,
    makeNearbyPrograms
} = require("./controllers/programController");

const reservationRoutes = require("./routes/reservationRoutes");

// 리뷰 라우터
const reviewRoutes = require("./routes/reviewRoutes");


const app = express();

const PORT = Number(process.env.PORT || 3000);
const HOST = process.env.HOST || "127.0.0.1";


// ======================================================
// Middleware
// ======================================================

app.disable("x-powered-by");

app.use(
    express.json({
        limit: "32kb"
    })
);

app.use((req, res, next) => {
    res.setHeader(
        "Cache-Control",
        "no-store"
    );

    res.setHeader(
        "X-Content-Type-Options",
        "nosniff"
    );

    next();
});


// ======================================================
// API Routes
// ======================================================


// ------------------------------------------------------
// 사용자 관련 API
//
// GET    /api/users/me
// PATCH  /api/users/me
// DELETE /api/users/me
// ------------------------------------------------------

app.use(
    "/api/users",
    userRoutes
);


// ------------------------------------------------------
// 시설 검색 API
//
// GET /api/facilities
// ------------------------------------------------------

app.get(
    "/api/facilities",
    makeListFacilities(db)
);


app.get(
    "/api/programs/search",
    makeSearchPrograms(db)
);

app.get(
    "/api/programs/nearby",
    makeNearbyPrograms(db)
);

app.get(
    "/api/programs",
    makeListPrograms(db)
);


// ------------------------------------------------------
// 프로그램 리뷰 API
//
// GET /api/programs/:programId/reviews
// ------------------------------------------------------

app.use(
    "/api",
    reviewRoutes(db)
);


// ------------------------------------------------------
// 예약 관련 API
// ------------------------------------------------------

app.use(
    "/api/reservations",
    reservationRoutes
);


// ======================================================
// 서버 상태 확인
//
// Firestore를 사용하지 않음
// ======================================================

app.get("/", (req, res) => {

    res.status(200).json({
        success: true,
        message: "Backend server is running!"
    });

});


// ======================================================
// 404 처리
// ======================================================

app.use((req, res) => {

    res.status(404).json({
        success: false,
        message: "존재하지 않는 API입니다."
    });

});


// ======================================================
// Error Handler
// ======================================================

app.use((error, req, res, next) => {

    if (res.headersSent) {
        return next(error);
    }

    const status =
        error.type === "entity.too.large"
            ? 413
            : error.type === "entity.parse.failed"
                ? 400
                : 500;

    res.status(status).json({
        success: false,
        message: "요청을 처리하지 못했습니다."
    });

});


// ======================================================
// 서버 실행
// ======================================================

const server = app.listen(
    PORT,
    HOST,
    () => {
        console.log(
            `Server running on port ${PORT}`
        );
    }
);


// ======================================================
// 서버 종료 처리
// ======================================================

process.on("SIGTERM", () => {

    server.close(() => {
        process.exit(0);
    });

    setTimeout(() => {
        process.exit(1);
    }, 10000).unref();

});
