const express = require("express");
const {
    makeListProgramReviews,
    makeListReviewCounts
} = require("../controllers/reviewController");

function makeReviewRouter(db) {
    const router = express.Router();

    router.get(
        "/programs/review-counts",
        makeListReviewCounts(db)
    );

    // GET /api/programs/:programId/reviews
    router.get(
        "/programs/:programId/reviews",
        makeListProgramReviews(db)
    );

    return router;
}

module.exports = makeReviewRouter;
