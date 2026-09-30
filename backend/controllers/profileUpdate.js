const frequencies = ["WEEKLY_1_2", "WEEKLY_3_4", "MONTHLY_2_3", "RARELY"];
const { ensureUserProfile } = require("./userProfile");
const exercises = ["WALKING", "YOGA", "PILATES", "STRETCHING", "SWIMMING", "GYM", "SPORTS", "OTHER"];
const formats = ["SOLO", "ONE_ON_ONE", "SMALL_GROUP"];

function validateProfile(body) {
    const keys = ["exerciseFrequency", "preferredExercises", "participationTypes", "onboardingCompleted", "availableTimes", "availableDays", "name", "phone", "registerMedicalTestData"];
    const validArray = (value, options) => Array.isArray(value) && value.length > 0 &&
        value.length <= options.length && new Set(value).size === value.length &&
        value.every(item => options.includes(item));
    if (!body || typeof body !== "object" || Array.isArray(body) ||
        Object.keys(body).length === 0 || Object.keys(body).some(key => !keys.includes(key))) return null;
    if ("exerciseFrequency" in body && !frequencies.includes(body.exerciseFrequency)) return null;
    if ("registerMedicalTestData" in body && body.registerMedicalTestData !== true) return null;
    if ("name" in body && (typeof body.name !== "string" || body.name.trim().length < 1 || body.name.trim().length > 50 || /[\u0000-\u001f]/.test(body.name))) return null;
    if ("phone" in body && (typeof body.phone !== "string" || (body.phone !== "" && !/^01[016789]-[0-9]{3,4}-[0-9]{4}$/.test(body.phone)))) return null;
    if ("preferredExercises" in body && !validArray(body.preferredExercises, exercises)) return null;
    if ("participationTypes" in body && !validArray(body.participationTypes, formats)) return null;
    if ("availableTimes" in body && !validArray(body.availableTimes, ["EARLY", "MORNING", "MIDDAY", "AFTERNOON", "EVENING"])) return null;
    if ("availableDays" in body && !validArray(body.availableDays, ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"])) return null;
    if ("onboardingCompleted" in body && (body.onboardingCompleted !== true ||
        !["exerciseFrequency", "preferredExercises", "participationTypes"].every(key => key in body))) return null;
    return Object.fromEntries(Object.keys(body).map(key => [key, key === "name" ? body[key].trim() : body[key]]));
}

function makeUpdateMyProfile(db, timestamp, environment = process.env.NODE_ENV) {
    return async (req, res) => {
        if (!req.user?.uid) return res.status(401).json({ success: false });
        const fields = validateProfile(req.body);
        if (!fields) return res.status(400).json({ success: false, message: "운동 조건을 확인해 주세요." });
        if (fields.registerMedicalTestData && environment === "production") {
            return res.status(403).json({ success: false, message: "사용할 수 없는 기능입니다." });
        }
        try {
            if (fields.registerMedicalTestData) {
                delete fields.registerMedicalTestData;
                fields.medicalTestData = {
                    isSynthetic: true, status: "TEST_REGISTERED", institution: "테스트 의료기관 (가상)",
                    memo: "화면 표시 확인용 임시 데이터입니다. 실제 진료정보나 운동 처방이 아닙니다.",
                    registeredAt: timestamp()
                };
            }
            const ref = db.collection("users").doc(req.user.uid);
            const update = { ...fields, updatedAt: timestamp() };
            try {
                await ref.update(update);
            } catch (error) {
                if (error.code !== 5) throw error;
                await ensureUserProfile(db, req.user, timestamp);
                await ref.update(update);
            }
            return res.status(200).json({ success: true, user: { id: req.user.uid, ...fields } });
        } catch (error) {
            const status = error.code === 5 ? 404 : 503;
            return res.status(status).json({ success: false, message: "회원정보를 저장하지 못했어요." });
        }
    };
}
module.exports = { validateProfile, makeUpdateMyProfile };
