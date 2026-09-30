function publicReview(doc) {
    const value = doc.data();

    const content =
        typeof value.content === "string"
            ? value.content.trim()
            : "";

    const facilityName =
        typeof value.facilityName === "string"
            ? value.facilityName.trim()
            : "";

    const programId =
        typeof value.programId === "string"
            ? value.programId.trim()
            : "";

    const programName =
        typeof value.programName === "string"
            ? value.programName.trim()
            : "";

    const reservationId =
        typeof value.reservationId === "string"
            ? value.reservationId.trim()
            : "";

    const userId =
        typeof value.userId === "string"
            ? value.userId.trim()
            : "";

    const rating = Number(value.rating);

    // createdAt은 Firestore Timestamp일 수도 있고
    // 테스트 데이터에서는 Date/string일 수도 있으므로 안전하게 처리
    let createdAt = null;

    if (value.createdAt?.toDate) {
        createdAt = value.createdAt.toDate().toISOString();
    } else if (value.createdAt instanceof Date) {
        createdAt = value.createdAt.toISOString();
    } else if (
        typeof value.createdAt === "string" &&
        !Number.isNaN(Date.parse(value.createdAt))
    ) {
        createdAt = new Date(value.createdAt).toISOString();
    }

    let updatedAt = null;

    if (value.updatedAt?.toDate) {
        updatedAt = value.updatedAt.toDate().toISOString();
    } else if (value.updatedAt instanceof Date) {
        updatedAt = value.updatedAt.toISOString();
    } else if (
        typeof value.updatedAt === "string" &&
        !Number.isNaN(Date.parse(value.updatedAt))
    ) {
        updatedAt = new Date(value.updatedAt).toISOString();
    }

    // 리뷰로 사용하기 위한 최소 필드
    if (
        !content ||
        !programId ||
        !programName ||
        !Number.isInteger(rating) ||
        rating < 1 ||
        rating > 5
    ) {
        return null;
    }

    return {
        id: doc.id,
        content,
        createdAt,
        facilityName,
        isSample: value.isSample === true,
        programId,
        programName,
        rating,
        updatedAt,
    };
}


function makeListProgramReviews(db) {
    return async (req, res) => {
        const after = req.query?.after;
        if (after !== undefined && (typeof after !== "string" || !/^[A-Za-z0-9_-]{1,128}$/.test(after))) {
            return res.status(400).json({ success: false, message: "목록 위치를 확인해 주세요." });
        }
        const programId =
            typeof req.params.programId === "string"
                ? req.params.programId.trim()
                : "";

        if (
            !programId ||
            !/^[A-Za-z0-9_-]{1,128}$/.test(programId)
        ) {
            return res.status(400).json({
                success: false,
                message: "프로그램 정보를 확인해 주세요."
            });
        }

        try {
            let query = db
                .collection("reviews")
                .where("programId", "==", programId)
                .orderBy("__name__");
            if (after) query = query.startAfter(after);
            const snapshot = await query.limit(21).get();
            const page = snapshot.docs.slice(0, 20);

            const reviews = page
                .map(doc => publicReview(doc))
                .filter(Boolean)
                .sort((a, b) => {
                    if (!a.createdAt && !b.createdAt) return 0;
                    if (!a.createdAt) return 1;
                    if (!b.createdAt) return -1;

                    return (
                        new Date(b.createdAt) -
                        new Date(a.createdAt)
                    );
                });

            const averageRating =
                reviews.length > 0
                    ? reviews.reduce(
                        (sum, review) => sum + review.rating,
                        0
                    ) / reviews.length
                    : 0;

            return res.json({
                success: true,
                reviews,
                reviewCount: reviews.length,
                averageRating: Number(
                    averageRating.toFixed(1)
                ),
                summaryScope: "page",
                nextCursor: snapshot.docs.length > 20 ? page[page.length - 1].id : null
            });

        } catch (error) {
            console.error(
                "리뷰 목록 조회 오류:",
                error
            );

            return res.status(503).json({
                success: false,
                message: "리뷰를 불러오지 못했어요."
            });
        }
    };
}

const reviewCountCache = {
    expiresAt: 0,
    counts: null,
    pending: null
};

function makeListReviewCounts(db) {
    return async (_req, res) => {
        const now = Date.now();
        if (reviewCountCache.counts && reviewCountCache.expiresAt > now) {
            return res.json({ success: true, counts: reviewCountCache.counts });
        }

        try {
            if (!reviewCountCache.pending) {
                reviewCountCache.pending = db.collection("reviews").get().then((snapshot) => {
                    const counts = {};
                    for (const doc of snapshot.docs) {
                        const review = publicReview(doc);
                        if (!review || review.isSample) continue;
                        counts[review.programId] = (counts[review.programId] || 0) + 1;
                    }
                    reviewCountCache.counts = counts;
                    reviewCountCache.expiresAt = Date.now() + 10 * 60 * 1000;
                    return counts;
                }).finally(() => {
                    reviewCountCache.pending = null;
                });
            }

            const counts = await reviewCountCache.pending;
            return res.json({ success: true, counts });
        } catch (error) {
            if (reviewCountCache.counts) {
                return res.json({ success: true, counts: reviewCountCache.counts, stale: true });
            }
            console.error("리뷰 수 조회 오류:", error);
            return res.status(503).json({
                success: false,
                message: "리뷰 수를 불러오지 못했어요."
            });
        }
    };
}


module.exports = {
    publicReview,
    makeListProgramReviews,
    makeListReviewCounts
};
