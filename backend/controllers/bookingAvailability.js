function bookingAvailability(value, now = Date.now()) {
    if (value.isTestData === true) return { available: false, reason: "종료된 프로그램" };
    const start = value.startAt?.toDate?.();
    const end = value.endAt?.toDate?.();
    if (!(start instanceof Date) || !Number.isFinite(start.getTime())
        || !(end instanceof Date) || !Number.isFinite(end.getTime()) || end <= start
        || !Number.isSafeInteger(value.capacity) || value.capacity < 1
        || !Number.isSafeInteger(value.reservedCount) || value.reservedCount < 0
        || !Number.isSafeInteger(value.price) || value.price < 0) {
        return { available: false, reason: "예약 일정 준비 중" };
    }
    if (value.status !== "OPEN") return { available: false, reason: "예약 마감" };
    if (start.getTime() <= now) return { available: false, reason: "종료된 일정" };
    if (value.reservedCount >= value.capacity) return { available: false, reason: "예약 마감" };
    if (value.price !== 0) return { available: false, reason: "유료 예약 준비 중" };
    return { available: true, reason: null };
}

module.exports = { bookingAvailability };
