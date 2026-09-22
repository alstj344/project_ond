import Foundation

enum OnboardingStep: String, Hashable, CaseIterable {
    case profile, environment, experience, activities, format
    case medicalLink, medicalQuestion, medicalInfo, summary, analysis

    var title: String {
        switch self {
        case .profile: return "개인정보 입력"
        case .environment: return "운동 환경"
        case .experience: return "운동 경험"
        case .activities, .format: return "선호 운동"
        case .medicalLink, .medicalQuestion, .medicalInfo: return "의료기관 연계"
        case .summary: return "추천 조건 확인"
        case .analysis: return ""
        }
    }

    var figmaNode: String {
        switch self {
        case .profile: return "1:848"
        case .environment: return "1:1578"
        case .experience: return "1:1124"
        case .activities: return "1:1294"
        case .format: return "18:310"
        case .medicalLink: return "1:1757"
        case .medicalQuestion: return "1:1866"
        case .medicalInfo: return "1:1988"
        case .summary: return "1:2112"
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
