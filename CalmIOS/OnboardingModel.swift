import Foundation

struct ExerciseConditionsPayload: Codable {
    var preferredExercises: [String]?
    var availableTimes: [String]?
    var availableDays: [String]?

    static let timeCodes = ["새벽(6~9시)": "EARLY", "오전(9~12시)": "MORNING", "오후(12~3시)": "MIDDAY", "오후(3~6시)": "AFTERNOON", "저녁(6~9시)": "EVENING"]
    static let dayCodes = ["월": "MON", "화": "TUE", "수": "WED", "목": "THU", "금": "FRI", "토": "SAT", "일": "SUN"]
    static let typeCodes = ["걷기": "WALKING", "요가": "YOGA", "필라테스": "PILATES", "스트레칭": "STRETCHING", "수영": "SWIMMING", "헬스": "GYM", "생활체육": "SPORTS", "기타": "OTHER"]

    static func decodeResponse(_ data: Data) throws -> Self {
        struct Response: Decodable { let user: ExerciseConditionsPayload }
        return try JSONDecoder().decode(Response.self, from: data).user
    }
}

struct OnboardingPreferences: Codable {
    var exerciseFrequency: String?
    var preferredExercises: [String]?
    var participationTypes: [String]?
    var onboardingCompleted: Bool?

    static let frequencies = ["주1~2회": "WEEKLY_1_2", "주3~4회": "WEEKLY_3_4", "월2~3회": "MONTHLY_2_3", "거의 하지 않음": "RARELY"]
    static let formats = ["혼자": "SOLO", "1:1 코칭": "ONE_ON_ONE", "소그룹": "SMALL_GROUP"]
    static let activities: [ExerciseActivity: String] = [.walking: "WALKING", .yoga: "YOGA", .pilates: "PILATES", .stretching: "STRETCHING", .swimming: "SWIMMING", .gym: "GYM", .sports: "SPORTS", .other: "OTHER"]

    init(profile: OnboardingProfile) {
        exerciseFrequency = Self.frequencies[profile.experience]
        preferredExercises = ExerciseActivity.allCases.filter { profile.activities.contains($0) }.compactMap { Self.activities[$0] }
        participationTypes = Self.formats[profile.format].map { [$0] }
        onboardingCompleted = true
    }

    func apply(to profile: inout OnboardingProfile) {
        if let frequency = Self.frequencies.first(where: { $0.value == exerciseFrequency }) { profile.experience = frequency.key }
        if let preferredExercises {
            profile.activities = Set(Self.activities.filter { preferredExercises.contains($0.value) }.map(\.key))
        }
        if let format = Self.formats.first(where: { participationTypes?.contains($0.value) == true }) { profile.format = format.key }
    }

    static func decodeResponse(_ data: Data) throws -> Self {
        struct Response: Decodable { let user: OnboardingPreferences }
        return try JSONDecoder().decode(Response.self, from: data).user
    }
}

enum OnboardingStep: String, Hashable, CaseIterable {
    case profile, environment, experience, activities, format
    case medicalLink, medicalQuestion, medicalInfo, summary, analysis

    var title: String {
        switch self {
        case .profile: return "개인정보 입력"
        case .environment: return "운동 환경"
        case .experience: return "운동 경험"
        case .activities: return "선호 운동"
        case .format: return "운동 인원"
        case .medicalLink, .medicalQuestion, .medicalInfo: return "의료기관 연계"
        case .summary: return "추천 조건 확인"
        case .analysis: return ""
        }
    }

    var figmaNode: String {
        switch self {
        case .profile: return "1:848"
        case .environment: return "1:1579"
        case .experience: return "1:1125"
        case .activities: return "1:1294"
        case .format: return "18:310"
        case .medicalLink: return "1:1758"
        case .medicalQuestion: return "1:1866"
        case .medicalInfo: return "1:1988"
        case .summary: return "1:2113"
        case .analysis: return "18:18"
        }
    }
}

enum ExerciseActivity: String, CaseIterable, Identifiable {
    case walking = "걷기 / 산책", yoga = "요가", pilates = "필라테스"
    case stretching = "스트레칭", swimming = "수영", gym = "헬스"
    case sports = "생활체육", other = "기타"
    var id: Self { self }
    var symbol: String {
        switch self {
        case .walking: return "figure.walk"
        case .yoga: return "figure.mind.and.body"
        case .pilates: return "figure.pilates"
        case .stretching: return "figure.flexibility"
        case .swimming: return "figure.pool.swim"
        case .gym: return "dumbbell.fill"
        case .sports: return "tennis.racket"
        case .other: return "ellipsis"
        }
    }
}

enum MedicalAnswer: String, CaseIterable {
    case yes, no, unsure
}

struct OnboardingProfile {
    static let ageOptions = ["20대", "30대", "40대", "50대", "60대 이상"]
    static let timeOptions = ["평일 오전", "평일 오후", "평일 저녁", "주말", "상관없어요"]
    static let distanceOptions = ["10분 이내", "20분 이내", "30분 이내", "거리 상관없어요"]
    static let experienceOptions = ["주1~2회", "주3~4회", "월2~3회", "거의 하지 않음"]
    static let formatOptions = ["혼자", "1:1 코칭", "소그룹"]

    var age = "20대"
    var address = ""
    var times: Set<String> = ["평일 저녁", "주말"]
    var distance = "20분 이내"
    var experience = "거의 하지 않음"
    var activities: Set<ExerciseActivity> = [.walking, .yoga, .stretching]
    var format = "소그룹"
    var linkMedical = false
    var medicalAnswer: MedicalAnswer?

    var profileValid: Bool {
        !address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !times.isEmpty
    }
    var activitySummary: String {
        ExerciseActivity.allCases.filter { activities.contains($0) }.map(\.rawValue).joined(separator: " · ")
    }
    var timeSummary: String {
        Self.timeOptions.filter { times.contains($0) }.joined(separator: " · ")
    }
    var hasMedicalExample: Bool { linkMedical && medicalAnswer == .yes }

    mutating func toggleTime(_ value: String) {
        if times.contains(value) { times.remove(value); return }
        if value == "상관없어요" { times = [value] }
        else { times.remove("상관없어요"); times.insert(value) }
    }
    mutating func toggleActivity(_ value: ExerciseActivity) {
        if activities.contains(value) { activities.remove(value) }
        else { activities.insert(value) }
    }
    mutating func setMedicalLink(_ value: Bool) {
        linkMedical = value
        if !value { medicalAnswer = nil }
    }
    func next(after step: OnboardingStep) -> OnboardingStep? {
        switch step {
        case .profile: return profileValid ? .environment : nil
        case .environment: return .experience
        case .experience: return .activities
        case .activities: return activities.isEmpty ? nil : .format
        case .format: return .medicalLink
        case .medicalLink: return linkMedical ? .medicalQuestion : .summary
        case .medicalQuestion:
            guard let medicalAnswer else { return nil }
            return medicalAnswer == .yes ? .medicalInfo : .summary
        case .medicalInfo: return .summary
        case .summary: return .analysis
        case .analysis: return nil
        }
    }
}
