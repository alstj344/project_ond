import SwiftUI
import Security

struct PersonalDetails: Codable, Equatable {
    var name = "이지은"
    var phone = "010-0000-0000"
    var email = "ji8219@gmail.com"

    var validationMessage: String? {
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "이름을 입력해주세요." }
        let parts = phone.split(separator: "-", omittingEmptySubsequences: false)
        if parts.count != 3 || parts[0].count != 3 || !(3...4).contains(parts[1].count) ||
            parts[2].count != 4 || !parts.allSatisfy({ $0.allSatisfy(\.isNumber) }) {
            return "전화번호를 확인해주세요."
        }
        let emailParts = email.split(separator: "@", omittingEmptySubsequences: false)
        if emailParts.count != 2 || emailParts[0].isEmpty || !emailParts[1].contains(".") ||
            email.contains(where: \.isWhitespace) || emailParts[1].hasPrefix(".") || emailParts[1].hasSuffix(".") {
            return "이메일 주소를 확인해주세요."
        }
        return nil
    }
}

enum PasswordRules {
    static func message(new: String, confirmation: String) -> String? {
        guard (8...16).contains(new.count),
              new.range(of: "[A-Za-z]", options: .regularExpression) != nil,
              new.range(of: "[0-9]", options: .regularExpression) != nil,
              new.range(of: "[^A-Za-z0-9\\s]", options: .regularExpression) != nil,
              !new.contains(where: \.isWhitespace) else {
            return "8~16자의 영문, 숫자, 특수문자를 조합해주세요."
        }
        return new == confirmation ? nil : "새로운 비밀번호가 일치하지 않아요."
    }
}

// Credentials stay in the device Keychain, never in UserDefaults.
struct DevicePasswordVault {
    private let service = "com.example.CalmIOS.profile-password"
    private var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service, kSecAttrAccount as String: "local-profile"]
    }
    func read() throws -> [String] {
        var request = query
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(request as CFDictionary, &result)
        if status == errSecItemNotFound { return [] }
        guard status == errSecSuccess, let data = result as? Data else { throw VaultError.unavailable }
        return try JSONDecoder().decode([String].self, from: data)
    }
    func write(_ history: [String]) throws {
        let data = try JSONEncoder().encode(history)
        let status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var request = query
            request[kSecValueData as String] = data
            request[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            guard SecItemAdd(request as CFDictionary, nil) == errSecSuccess else { throw VaultError.unavailable }
        } else if status != errSecSuccess { throw VaultError.unavailable }
    }
    enum VaultError: Error { case unavailable }
}

final class ProfileStore: ObservableObject {
    @Published private(set) var details: PersonalDetails
    let userID = "ji8219"
    @Published var availableTimes: Set<String> = ["오후(3~6시)", "저녁(6~9시)"] { didSet { saveSet(availableTimes, key: "calm.conditions.times") } }
    @Published var availableDays: Set<String> = ["월", "화", "수", "목", "금"] { didSet { saveSet(availableDays, key: "calm.conditions.days") } }
    @Published var exerciseTypes: Set<String> = ["걷기", "필라테스/요가"] { didSet { saveSet(exerciseTypes, key: "calm.conditions.types") } }
    @Published var healthNote = "" {
        didSet {
            if healthNote.count > 500 { healthNote = String(healthNote.prefix(500)) }
            defaults.set(healthNote, forKey: "calm.conditions.note")
        }
    }
    private let defaults: UserDefaults
    private let key = "calm.personalDetails.v1"
    var name: String { details.name }
    var phone: String { details.phone }
    var email: String { details.email }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        details = defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(PersonalDetails.self, from: $0) } ?? PersonalDetails()
        if let values = loadSet("calm.conditions.times") { availableTimes = values }
        if let values = loadSet("calm.conditions.days") { availableDays = values }
        if let values = loadSet("calm.conditions.types") { exerciseTypes = values }
        healthNote = String((defaults.string(forKey: "calm.conditions.note") ?? "").prefix(500))
    }
    private func saveConditions() {
        saveSet(availableTimes, key: "calm.conditions.times")
        saveSet(availableDays, key: "calm.conditions.days")
        saveSet(exerciseTypes, key: "calm.conditions.types")
        defaults.set(healthNote, forKey: "calm.conditions.note")
    }
    private func saveSet(_ value: Set<String>, key: String) {
        if let data = try? JSONEncoder().encode(Array(value).sorted()) { defaults.set(data, forKey: key) }
    }
    private func loadSet(_ key: String) -> Set<String>? {
        guard let data = defaults.data(forKey: key), let values = try? JSONDecoder().decode([String].self, from: data) else { return nil }
        return Set(values)
    }
    @discardableResult
    func save(_ draft: PersonalDetails) -> Bool {
        guard draft.validationMessage == nil else { return false }
        var clean = draft
        clean.name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = try? JSONEncoder().encode(clean) else { return false }
        defaults.set(data, forKey: key)
        defaults.set(clean.name, forKey: "calm.profileName")
        details = clean
        return true
    }
}

private enum ProfileStyle {
    static let ink = Color(red: 28/255, green: 28/255, blue: 24/255)
    static let accent = Color(red: 37/255, green: 83/255, blue: 63/255)
    static let surface = Color(red: 244/255, green: 241/255, blue: 236/255)
    static let background = Color(red: 248/255, green: 247/255, blue: 245/255)
    static let mint = Color(red: 188/255, green: 238/255, blue: 211/255)
    static let muted = Color(red: 113/255, green: 121/255, blue: 115/255)
    static let pale = Color(red: 177/255, green: 185/255, blue: 180/255)
    static let separator = Color(red: 244/255, green: 244/255, blue: 242/255)
}

private struct ShowBookingsKey: EnvironmentKey { static let defaultValue: () -> Void = {} }
extension EnvironmentValues {
    var showBookings: () -> Void {
        get { self[ShowBookingsKey.self] }
        set { self[ShowBookingsKey.self] = newValue }
    }
}

private struct ProfilePageChrome: ViewModifier {
    let title: String
    var detail = true
    func body(content: Content) -> some View {
        content.font(AppTypography.font(13))
            .foregroundStyle(ProfileStyle.ink)
            .background(ProfileStyle.background.ignoresSafeArea())
            .navigationTitle(title).navigationBarTitleDisplayMode(.inline)
            .toolbar(.visible, for: .navigationBar)
            .toolbarRole(.editor)
            .toolbarBackground(.white, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar(detail ? .hidden : .visible, for: .tabBar)
    }
}

private struct ProfileArrow: View {
    var body: some View {
        Image("NextIcon").resizable().scaledToFit().frame(width: 12, height: 18).accessibilityHidden(true)
    }
}

struct MyPageView: View {
    @Environment(\.showBookings) private var showBookings
    @ObservedObject var store: WellnessStore
    @ObservedObject var profile: ProfileStore
    @State private var notice = ""
    @State private var showNotice = false
    @State private var actionSheet: ProfileAction?
    @State private var deletionCompleted = false
    @AppStorage("calm.onboardingCompleted") private var onboardingCompleted = false
    private var completed: [WellnessBooking] { store.bookings.filter { !$0.isCancelled && $0.attendance == .checkedOut } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    NavigationLink { InfoSummaryView(profile: profile) } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(profile.name).font(AppTypography.font(16, weight: .bold))
                                Text("회복 여정 38일째").font(AppTypography.font(11)).foregroundStyle(ProfileStyle.accent)
                            }
                            Spacer()
                            ProfileArrow()
                        }.padding(16).frame(minHeight: 74).background(.white, in: RoundedRectangle(cornerRadius: 16))
                    }.buttonStyle(.plain)
                    stats
                    Text("의료 연계 및 안심 설정")
                        .font(AppTypography.font(16, weight: .bold)).padding(.horizontal, 8).padding(.top, 16)
                    medical
                    support
                    HStack(spacing: 8) {
                        Button("로그아웃") { actionSheet = .logout }
                        Text("·")
                        Button("회원탈퇴") { actionSheet = .deleteAccount }
                    }.font(AppTypography.font(12)).foregroundStyle(ProfileStyle.pale)
                        .frame(maxWidth: .infinity, minHeight: 44).padding(.top, 4)
                }.padding(.horizontal, 24).padding(.top, 32).padding(.bottom, 16)
                    .frame(maxWidth: 600).frame(maxWidth: .infinity)
            }.modifier(ProfilePageChrome(title: "마이페이지", detail: false))
                .alert("안내", isPresented: $showNotice) { Button("확인", role: .cancel) {} } message: { Text(notice) }
                .sheet(item: $actionSheet) { action in
                    ProfileActionSheet(action: action, onCancel: { actionSheet = nil }, onConfirm: {
                        if action == .logout {
                            onboardingCompleted = false
                            actionSheet = nil
                        } else {
                            actionSheet = nil
                            deletionCompleted = true
                        }
                    })
                }
                .fullScreenCover(isPresented: $deletionCompleted) {
                    AccountDeletionCompleteView {
                        deletionCompleted = false
                        onboardingCompleted = false
                    }
                }
        }
    }

    private var stats: some View {
        HStack(spacing: 0) {
            Button(action: showBookings) {
                stat("예약 내역", count: store.bookings.filter { !$0.isCancelled && $0.attendance != .checkedOut }.count, accent: true)
            }
            Rectangle().fill(ProfileStyle.separator).frame(width: 1, height: 38)
            NavigationLink { RecentParticipationView(store: store) } label: { stat("지난 참여", count: completed.count) }
            Rectangle().fill(ProfileStyle.separator).frame(width: 1, height: 38)
            NavigationLink { MyReviewsView(store: store, initiallyWritten: true) } label: {
                stat("작성한 후기", count: completed.filter { $0.rating > 0 }.count)
            }
        }.buttonStyle(.plain).padding(.vertical, 12).background(.white, in: RoundedRectangle(cornerRadius: 20))
    }

    private func stat(_ title: String, count: Int, accent: Bool = false) -> some View {
        VStack(spacing: 6) {
            Text(title).font(AppTypography.font(11)).foregroundStyle(ProfileStyle.muted)
            (Text("\(count)").font(AppTypography.font(20, weight: .medium)) + Text("건").font(AppTypography.font(11)))
                .foregroundStyle(accent ? ProfileStyle.accent : ProfileStyle.ink)
        }.frame(maxWidth: .infinity, minHeight: 48)
    }

    private var medical: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("서울마음편한정신의학과").font(AppTypography.font(16, weight: .medium))
                Text("김선우 전문의").foregroundStyle(ProfileStyle.muted)
                HStack {
                    Text("최근 데이터 동기화")
                    Spacer()
                    Text("2025.05.02")
                }.font(AppTypography.font(11)).foregroundStyle(ProfileStyle.pale).padding(.top, 6)
            }.padding(20).frame(maxWidth: .infinity, alignment: .leading).background(ProfileStyle.background, in: RoundedRectangle(cornerRadius: 16))
            Button { inform("의료기관 연결이 필요합니다. 현재 표시된 기관과 동기화 날짜는 디자인 예시이며, 실제 의료정보를 조회하거나 전송하지 않습니다.") } label: {
                HStack(spacing: 8) {
                    Image("ProfileSync").resizable().scaledToFit().frame(width: 14, height: 14)
                    Text("의료 권장 데이터 재동기화").font(AppTypography.font(13, weight: .medium))
                }.frame(maxWidth: .infinity, minHeight: 42).foregroundStyle(.white).background(ProfileStyle.accent, in: Capsule())
            }.buttonStyle(.plain)
            Text("운동에 필요한 정보만 안전하게 활용해요. 진료 기록 전체가 아닌, 운동에 필요한 안전 조건과 권장사항만 추천에 반영해요.")
                .font(AppTypography.font(10, relativeTo: .caption)).foregroundStyle(ProfileStyle.pale).lineSpacing(3).padding(.horizontal, 8)
        }.padding(16).background(.white, in: RoundedRectangle(cornerRadius: 32))
    }

    private var support: some View {
        VStack(spacing: 0) {
            NavigationLink { ProfileHelpView(kind: .faq) } label: { menuRow("자주 묻는 질문") }
            Divider().overlay(ProfileStyle.separator)
            Button { inform("상담센터 운영시간은 평일 09:00–18:00입니다. 연결할 전화번호가 아직 등록되지 않았습니다.") } label: { menuRow("상담센터 연결 (평일 09:00 - 18:00)") }
            Divider().overlay(ProfileStyle.separator)
            NavigationLink { ProfileHelpView(kind: .privacy) } label: { menuRow("개인정보 처리방침") }
        }.buttonStyle(.plain).background(.white, in: RoundedRectangle(cornerRadius: 20))
    }
    private func menuRow(_ title: String) -> some View {
        HStack { Text(title); Spacer(minLength: 8); ProfileArrow() }.padding(.horizontal, 16).frame(minHeight: 46)
    }
    private func inform(_ message: String) { notice = message; showNotice = true }
}

private enum ProfileAction: String, Identifiable {
    case logout, deleteAccount
    var id: String { rawValue }
}

private struct ProfileActionSheet: View {
    let action: ProfileAction
    let onCancel: () -> Void
    let onConfirm: () -> Void
    var body: some View {
        VStack(spacing: 24) {
            Capsule().fill(Color(red: 0.72, green: 0.75, blue: 0.73)).frame(width: 68, height: 4).padding(.top, 8)
            VStack(spacing: 8) {
                Text(action == .logout ? "로그아웃 하시겠어요?" : "계정을 탈퇴하시겠어요?")
                    .font(AppTypography.font(22, weight: .bold))
                Text(action == .logout
                     ? "잠시 쉬었다가 다시 이용하고 싶을 때\n편하게 찾아주세요."
                     : "그동안 이용해주셔서 감사합니다.\n탈퇴하면 계정과 서비스 이용 기록이 삭제됩니다.")
                    .font(AppTypography.font(12)).foregroundStyle(ProfileStyle.muted)
                    .multilineTextAlignment(.center)
            }
            if action == .logout {
                Text("로그아웃 후에도 예약 내역과 기록은 안전하게 보관됩니다.")
                    .font(AppTypography.font(11)).foregroundStyle(ProfileStyle.muted)
                    .frame(maxWidth: .infinity).padding(14).background(ProfileStyle.background, in: RoundedRectangle(cornerRadius: 14))
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text("• 프로필 및 계정 정보")
                    Text("• 예약 내역 및 운동 참여 기록")
                    Text("• 작성한 후기")
                }.font(AppTypography.font(11)).foregroundStyle(ProfileStyle.muted)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(16)
                    .background(ProfileStyle.background, in: RoundedRectangle(cornerRadius: 14))
            }
            HStack(spacing: 8) {
                Button("취소", action: onCancel)
                    .frame(maxWidth: .infinity, minHeight: 56).foregroundStyle(ProfileStyle.pale)
                    .background(ProfileStyle.background, in: Capsule())
                Button("확인", action: onConfirm)
                    .frame(maxWidth: .infinity, minHeight: 56).foregroundStyle(.white)
                    .background(ProfileStyle.accent, in: Capsule())
            }
        }.padding(.horizontal, 24).padding(.bottom, 22)
            .presentationDetents([.height(action == .logout ? 390 : 420)])
            .presentationDragIndicator(.hidden)
    }
}

private struct AccountDeletionCompleteView: View {
    let onConfirm: () -> Void
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            ZStack {
                Circle().fill(ProfileStyle.mint.opacity(0.55)).frame(width: 170, height: 170).blur(radius: 22)
                SuccessIcon()
            }
            VStack(spacing: 8) {
                Text("탈퇴가 완료되었습니다.").font(AppTypography.font(22, weight: .bold))
                Text("지금까지의 기록은 모두 안전하게 삭제되었습니다.\n언제든 다시 만나길 바래요.")
                    .font(AppTypography.font(12)).foregroundStyle(ProfileStyle.muted).multilineTextAlignment(.center)
            }.padding(.top, 32)
            Spacer()
            Button("확인", action: onConfirm)
                .font(AppTypography.font(14, weight: .medium))
                .frame(maxWidth: .infinity, minHeight: 56).foregroundStyle(.white)
                .background(ProfileStyle.accent, in: Capsule())
        }.padding(.horizontal, 24).padding(.vertical, 32)
            .background(ProfileStyle.background.ignoresSafeArea())
    }
}

struct InfoSummaryView: View {
    @ObservedObject var profile: ProfileStore
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                NavigationLink { PersonalEditView(profile: profile) } label: {
                    VStack(spacing: 12) {
                        heading("개인정보")
                        VStack(spacing: 0) {
                            row("이름", profile.name)
                            Divider().overlay(ProfileStyle.separator)
                            row("전화번호", profile.phone)
                            Divider().overlay(ProfileStyle.separator)
                            row("이메일", profile.email)
                        }.background(.white, in: RoundedRectangle(cornerRadius: 20))
                    }
                }.buttonStyle(.plain)
                NavigationLink { AccountEditView(profile: profile) } label: {
                    VStack(spacing: 12) {
                        heading("계정정보")
                        VStack(spacing: 0) {
                            row("아이디", profile.userID)
                            Divider().overlay(ProfileStyle.separator)
                            row("비밀번호", "************")
                        }.background(.white, in: RoundedRectangle(cornerRadius: 20))
                    }
                }.buttonStyle(.plain)
                NavigationLink("나의 운동 조건") { ExerciseConditionsView(profile: profile) }
                    .font(AppTypography.font(12)).foregroundStyle(ProfileStyle.muted).padding(.top, 12)
            }.padding(24).padding(.top, 12).frame(maxWidth: 600).frame(maxWidth: .infinity)
        }.modifier(ProfilePageChrome(title: "정보 수정"))
    }
    private func heading(_ title: String) -> some View {
        HStack { Text(title).font(AppTypography.font(16, weight: .bold)); Spacer(); ProfileArrow() }.padding(.horizontal, 8)
    }
    private func row(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(AppTypography.font(11)).foregroundStyle(ProfileStyle.muted)
            Text(value).font(AppTypography.font(13)).foregroundStyle(ProfileStyle.ink)
        }.padding(.horizontal, 16).padding(.vertical, 14).frame(maxWidth: .infinity, minHeight: 62, alignment: .leading)
    }
}

private struct ProfileEditActions: View {
    let enabled: Bool
    let cancel: () -> Void
    let save: () -> Void
    var body: some View {
        HStack(spacing: 8) {
            Button(action: cancel) {
                Text("취소").frame(maxWidth: .infinity, minHeight: 56)
                    .foregroundStyle(ProfileStyle.muted).background(ProfileStyle.surface, in: Capsule())
            }.frame(maxWidth: 110)
            Button(action: save) {
                Text("변경사항 저장").frame(maxWidth: .infinity, minHeight: 56)
                    .foregroundStyle(.white).background(ProfileStyle.accent.opacity(enabled ? 1 : 0.45), in: Capsule())
            }.disabled(!enabled)
        }.font(AppTypography.font(16, weight: .medium)).buttonStyle(.plain)
            .padding(.horizontal, 24).padding(.top, 12).padding(.bottom, 24).background(ProfileStyle.background)
    }
}

struct PersonalEditView: View {
    @ObservedObject var profile: ProfileStore
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var prefix: String
    @State private var middle: String
    @State private var last: String
    @State private var mailbox: String
    @State private var domain: String
    @State private var customDomain = false
    @State private var saved = false
    @State private var error = ""
    private let prefixes = ["010", "011", "016", "017", "018", "019"]
    private let domains = ["gmail.com", "naver.com", "daum.net", "hanmail.net", "icloud.com"]

    init(profile: ProfileStore) {
        self.profile = profile
        _name = State(initialValue: profile.name)
        let phone = profile.phone.components(separatedBy: "-")
        _prefix = State(initialValue: phone.first ?? "010")
        _middle = State(initialValue: phone.count > 1 ? phone[1] : "")
        _last = State(initialValue: phone.count > 2 ? phone[2] : "")
        let email = profile.email.components(separatedBy: "@")
        _mailbox = State(initialValue: email.first ?? "")
        _domain = State(initialValue: email.count > 1 ? email[1] : "gmail.com")
    }
    private var draft: PersonalDetails {
        PersonalDetails(name: name, phone: "\(prefix)-\(middle)-\(last)", email: "\(mailbox)@\(domain)")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                inputGroup("이름") { TextField("이름", text: $name).textContentType(.name).profileInput().accessibilityIdentifier("profile.name") }
                inputGroup("전화번호") {
                    HStack(spacing: 6) {
                        Menu {
                            ForEach(prefixes, id: \.self) { value in Button(value) { prefix = value } }
                        } label: { HStack { Text(prefix); Spacer(minLength: 0); Image(systemName: "chevron.down").font(.caption).foregroundStyle(ProfileStyle.pale) }.profileInput() }
                        Text("-")
                        TextField("0000", text: $middle).keyboardType(.numberPad).profileInput().accessibilityLabel("전화번호 가운데 자리")
                            .onChange(of: middle) { middle = String($0.filter(\.isNumber).prefix(4)) }
                        Text("-")
                        TextField("0000", text: $last).keyboardType(.numberPad).profileInput().accessibilityLabel("전화번호 마지막 자리")
                            .onChange(of: last) { last = String($0.filter(\.isNumber).prefix(4)) }
                    }
                }
                inputGroup("이메일") {
                    HStack(spacing: 4) {
                        TextField("이메일", text: $mailbox).textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.emailAddress).profileInput()
                        Text("@")
                        if customDomain {
                            TextField("도메인", text: $domain).textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL).profileInput()
                        } else {
                            Menu {
                                ForEach(domains, id: \.self) { value in Button(value) { domain = value } }
                                Button("직접 입력") { customDomain = true }
                            } label: {
                                HStack { Text(domain).lineLimit(1).minimumScaleFactor(0.75); Spacer(minLength: 0); Image(systemName: "chevron.down").font(.caption).foregroundStyle(ProfileStyle.pale) }.profileInput()
                            }
                        }
                    }
                }
                if !error.isEmpty { Text(error).foregroundStyle(.red).font(AppTypography.font(12)).accessibilityIdentifier("profile.error") }
            }.padding(24).padding(.top, 8).frame(maxWidth: 600).frame(maxWidth: .infinity)
        }.scrollDismissesKeyboard(.interactively).modifier(ProfilePageChrome(title: "개인정보 수정"))
            .safeAreaInset(edge: .bottom) {
                ProfileEditActions(enabled: true, cancel: { dismiss() }) {
                    error = draft.validationMessage ?? ""
                    if error.isEmpty && profile.save(draft) { saved = true }
                }
            }
            .fullScreenCover(isPresented: $saved, onDismiss: { dismiss() }) {
                SavedChangesView { saved = false }
            }
    }
    private func inputGroup<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(AppTypography.font(16, weight: .bold)).padding(.horizontal, 8)
            content()
        }
    }
}

struct AccountEditView: View {
    @ObservedObject var profile: ProfileStore
    @Environment(\.dismiss) private var dismiss
    @State private var current = ""
    @State private var password = ""
    @State private var confirmation = ""
    @State private var history: [String] = []
    @State private var loaded = false
    @State private var saved = false
    @State private var error = ""
    private let vault = DevicePasswordVault()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("아이디").font(AppTypography.font(16, weight: .bold)).padding(.horizontal, 8)
                    Text(profile.userID).foregroundStyle(ProfileStyle.muted).profileInput(background: .white)
                }
                VStack(alignment: .leading, spacing: 12) {
                    Text("비밀번호").font(AppTypography.font(16, weight: .bold)).padding(.horizontal, 8)
                    VStack(spacing: 0) {
                        ProfilePasswordRow(title: "현재 비밀번호", value: $current)
                        Divider().overlay(Color.black.opacity(0.04))
                        ProfilePasswordRow(title: "새로운 비밀번호", value: $password)
                        Divider().overlay(Color.black.opacity(0.04))
                        ProfilePasswordRow(title: "새로운 비밀번호 확인", value: $confirmation)
                    }.background(ProfileStyle.surface, in: RoundedRectangle(cornerRadius: 16))
                    VStack(alignment: .leading, spacing: 6) {
                        Text("비밀번호 변경 시 유의사항").fontWeight(.medium)
                        Text("8~16자의 영문, 숫자, 특수문자를 조합해주세요.\n이전에 사용한 비밀번호는 다시 사용할 수 없습니다.").lineSpacing(3)
                    }.font(AppTypography.font(13)).foregroundStyle(ProfileStyle.muted).padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading).background(ProfileStyle.surface, in: RoundedRectangle(cornerRadius: 12))
                    if loaded && history.isEmpty {
                        Text("이 기기에 저장된 비밀번호가 없습니다. 현재 비밀번호는 비워두고 새 비밀번호를 설정해주세요. 변경 내용은 이 기기에만 적용됩니다.")
                            .font(AppTypography.font(11)).foregroundStyle(ProfileStyle.muted)
                    }
                    if !error.isEmpty { Text(error).font(AppTypography.font(12)).foregroundStyle(.red) }
                }
            }.padding(24).padding(.top, 8).frame(maxWidth: 600).frame(maxWidth: .infinity)
        }.scrollDismissesKeyboard(.interactively).modifier(ProfilePageChrome(title: "계정정보 수정"))
            .safeAreaInset(edge: .bottom) { ProfileEditActions(enabled: loaded, cancel: { dismiss() }, save: save) }
            .onAppear {
                do { history = try vault.read(); loaded = true }
                catch { self.error = "기기의 비밀번호 저장소를 열 수 없습니다. 다시 시도해주세요."; loaded = false }
            }
            .fullScreenCover(isPresented: $saved, onDismiss: { dismiss() }) { SavedChangesView { saved = false } }
    }

    private func save() {
        error = ""
        if let existing = history.last, existing != current { error = "현재 비밀번호가 일치하지 않아요."; return }
        if history.isEmpty && !current.isEmpty { error = "최초 설정에서는 현재 비밀번호를 비워주세요."; return }
        if let message = PasswordRules.message(new: password, confirmation: confirmation) { error = message; return }
        if history.contains(password) { error = "이전에 사용한 비밀번호는 다시 사용할 수 없습니다."; return }
        do {
            try vault.write(history + [password])
            current = ""; password = ""; confirmation = ""
            saved = true
        } catch { self.error = "비밀번호를 저장하지 못했습니다. 다시 시도해주세요." }
    }
}

private struct ProfilePasswordRow: View {
    let title: String
    @Binding var value: String
    @State private var visible = false
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(AppTypography.font(11)).foregroundStyle(ProfileStyle.muted)
            HStack(spacing: 8) {
                Group {
                    if visible { TextField(title, text: $value) }
                    else { SecureField(title, text: $value) }
                }.textInputAutocapitalization(.never).autocorrectionDisabled().font(AppTypography.font(13))
                Button { visible.toggle() } label: {
                    Image(visible ? "PasswordHidden" : "PasswordVisible").resizable().scaledToFit()
                        .frame(width: 18, height: 14).frame(width: 44, height: 32)
                }.buttonStyle(.plain).accessibilityLabel(visible ? "\(title) 숨기기" : "\(title) 표시")
            }.frame(minHeight: 24)
        }.padding(.leading, 16).padding(.trailing, 4).padding(.vertical, 12)
    }
}

struct SavedChangesView: View {
    let onDone: () -> Void
    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 32) {
                    SuccessIcon().shadow(color: ProfileStyle.mint.opacity(0.9), radius: 30)
                        .frame(width: 146, height: 146).padding(.top, max(80, proxy.size.height * 0.26))
                    VStack(spacing: 10) {
                        Text("변경사항이 저장되었습니다.").font(AppTypography.font(24, weight: .bold, relativeTo: .title2))
                        Text("변경한 정보는 바로 반영되었어요.").font(AppTypography.font(13)).foregroundStyle(ProfileStyle.muted)
                    }.multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                }.frame(maxWidth: .infinity).padding(.horizontal, 24)
            }
        }.background(ProfileStyle.background.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) { FlowAction(title: "확인", action: onDone).padding(24).padding(.bottom, 20).background(ProfileStyle.background) }
            .interactiveDismissDisabled()
    }
}

struct RecentParticipationView: View {
    @ObservedObject var store: WellnessStore
    private var completed: [WellnessBooking] {
        store.bookings.filter { !$0.isCancelled && $0.attendance == .checkedOut }
            .sorted { ($0.participatedAt ?? .distantPast) > ($1.participatedAt ?? .distantPast) }
    }
    private var groups: [(String, [WellnessBooking])] {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy년 M월"
        var result: [(String, [WellnessBooking])] = []
        for booking in completed {
            let title = booking.participatedAt.map { formatter.string(from: $0) } ?? "이전 참여"
            if let index = result.firstIndex(where: { $0.0 == title }) { result[index].1.append(booking) }
            else { result.append((title, [booking])) }
        }
        return result
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 36) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("지금까지\n참여한 운동을 모아봤어요").font(AppTypography.font(24, weight: .bold, relativeTo: .title2)).lineSpacing(3)
                    Text("내가 참여한 운동과 경험을 한곳에서 확인해보세요.").font(AppTypography.font(13)).foregroundStyle(ProfileStyle.muted)
                }
                ForEach(groups, id: \.0) { title, bookings in
                    VStack(alignment: .leading, spacing: 12) {
                        Text(title).font(AppTypography.font(16, weight: .bold)).padding(.horizontal, 8).padding(.bottom, 4)
                        ForEach(bookings) { booking in
                            NavigationLink { ReservationSummaryView(bookingID: booking.id, store: store) } label: {
                                HStack(alignment: .top, spacing: 12) {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(booking.venue).font(AppTypography.font(11)).foregroundStyle(ProfileStyle.muted)
                                        Text(booking.title).font(AppTypography.font(16, weight: .medium))
                                        Text("\(booking.dateLabel) \(booking.time)").font(AppTypography.font(13)).foregroundStyle(ProfileStyle.muted)
                                    }
                                    Spacer(minLength: 0)
                                    ProfileArrow()
                                }.padding(20).frame(maxWidth: .infinity, minHeight: 102, alignment: .leading)
                                    .background(.white, in: RoundedRectangle(cornerRadius: 24))
                            }.buttonStyle(.plain)
                        }
                    }
                }
                if completed.isEmpty { Text("아직 참여한 운동이 없어요. 운동을 마치면 이곳에 기록됩니다.").foregroundStyle(ProfileStyle.muted).padding(.vertical, 40) }
            }.padding(24).padding(.top, 12).frame(maxWidth: 600).frame(maxWidth: .infinity)
        }.modifier(ProfilePageChrome(title: "최근 참여 운동"))
    }
}

private struct ProfileHelpView: View {
    enum Kind { case faq, privacy }
    let kind: Kind
    var body: some View {
        List {
            if kind == .faq {
                Section("자주 묻는 질문") {
                    DisclosureGroup("예약은 어디서 확인하나요?") { Text("마이페이지의 예약 내역 또는 하단 예약 탭에서 확인할 수 있어요.") }
                    DisclosureGroup("예약 취소는 어떻게 하나요?") { Text("예약 확인 화면에서 체크인 전에 취소할 수 있어요.") }
                    DisclosureGroup("후기는 언제 작성하나요?") { Text("퇴실을 완료한 운동은 리뷰 화면에서 작성할 수 있어요.") }
                }
            } else {
                Section("개인정보 처리방침") {
                    Text("서비스의 공식 개인정보 처리방침은 아직 등록되지 않았습니다.")
                    Text("현재 앱은 입력한 프로필과 예약을 이 기기에 저장합니다. 비밀번호는 기기의 키체인에 보관하며 의료기관 또는 외부 서버로 전송하지 않습니다.")
                }
            }
        }.modifier(ProfilePageChrome(title: kind == .faq ? "자주 묻는 질문" : "개인정보 처리방침"))
    }
}

private extension View {
    func profileInput(background: Color = ProfileStyle.surface) -> some View {
        self.font(AppTypography.font(14)).padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
            .background(background, in: RoundedRectangle(cornerRadius: 16))
    }
}

struct ExerciseConditionsView: View {
    @ObservedObject var profile: ProfileStore
    private let times = ["새벽(6~9시)", "오전(9~12시)", "오후(12~3시)", "오후(3~6시)", "저녁(6~9시)"]
    private let days = ["월", "화", "수", "목", "금", "토", "일"]
    private let types = ["걷기", "필라테스/요가", "스트레칭", "수영", "헬스", "기타"]
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                section("운동 시간", "운동 가능한 시간을 선택해주세요.") {
                    chips(times, selection: $profile.availableTimes, columns: 3)
                }
                section("운동 요일", "운동을 희망하는 요일을 선택해주세요.") {
                    chips(days, selection: $profile.availableDays, columns: 7)
                }
                section("운동 종류", "선호하는 운동 종류를 선택해주세요.") {
                    chips(types, selection: $profile.exerciseTypes, columns: 3)
                }
                section("운동 종류", "건강 상태나 특별히 고려해야 할 사항이 있다면 알려주세요.") {
                    VStack(alignment: .trailing, spacing: 8) {
                        TextField("예) 우울증 치료 중이라 과격한 운동은 피하고 싶어요.", text: $profile.healthNote, axis: .vertical)
                            .lineLimit(5...8).font(AppTypography.font(13))
                            .accessibilityLabel("건강 상태와 고려 사항")
                        Text("\(profile.healthNote.count)/500").font(AppTypography.font(11)).foregroundStyle(ProfileStyle.muted)
                    }.padding(16).background(.white, in: RoundedRectangle(cornerRadius: 20))
                }
                Text("입력하신 정보는 이 기기에만 저장됩니다.")
                    .font(AppTypography.font(11)).foregroundStyle(ProfileStyle.muted).padding(.top, -20)
            }.padding(.horizontal, 24).padding(.vertical, 32).frame(maxWidth: 600).frame(maxWidth: .infinity)
        }.modifier(ProfilePageChrome(title: "나의 운동 조건"))
    }
    private func section<Content: View>(_ title: String, _ subtitle: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(AppTypography.font(16, weight: .bold))
                Text(subtitle).font(AppTypography.font(11)).foregroundStyle(ProfileStyle.muted)
            }.padding(.horizontal, 8)
            content()
        }
    }
    private func chips(_ values: [String], selection: Binding<Set<String>>, columns: Int) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: columns), spacing: 8) {
            ForEach(values, id: \.self) { value in
                Button {
                    if selection.wrappedValue.contains(value) { selection.wrappedValue.remove(value) }
                    else { selection.wrappedValue.insert(value) }
                } label: {
                    Text(value).font(AppTypography.font(11)).multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .foregroundStyle(selection.wrappedValue.contains(value) ? ProfileStyle.accent : ProfileStyle.muted)
                        .background(selection.wrappedValue.contains(value) ? ProfileStyle.mint : ProfileStyle.background, in: RoundedRectangle(cornerRadius: 12))
                }.buttonStyle(.plain).accessibilityAddTraits(selection.wrappedValue.contains(value) ? .isSelected : [])
            }
        }.padding(12).background(.white, in: RoundedRectangle(cornerRadius: 20))
    }
}

struct MyExerciseView: View {
    @ObservedObject var store: WellnessStore
    @ObservedObject var profile: ProfileStore
    private var completed: [WellnessBooking] {
        store.bookings.filter { !$0.isCancelled && $0.attendance == .checkedOut }
            .sorted { ($0.participatedAt ?? .distantPast) > ($1.participatedAt ?? .distantPast) }
    }
    private let colors: [Color] = [ProfileStyle.accent, Color(red: 0.98, green: 0.67, blue: 0.62), Color(red: 0.69, green: 0.73, blue: 0.70), ProfileStyle.mint, .orange, .teal]
    private var categories: [(name: String, count: Int)] {
        let names = ["요가", "걷기", "필라테스", "수영", "스트레칭", "기타"]
        return names.map { name in
            (name, completed.filter { booking in
                let category = booking.displayProgram.category
                return name == "기타" ? !names.dropLast().contains(category) : category == name
            }.count)
        }.filter { ["요가", "걷기", "필라테스", "수영"].contains($0.0) || $0.1 > 0 }
    }
    private var conditionLabels: [String] {
        profile.availableDays.sorted().map { "#\($0)" } +
        profile.availableTimes.sorted().map { "#\($0)" } +
        profile.exerciseTypes.sorted().map { "#\($0)" }
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(spacing: 28) {
                    ZStack {
                        Circle().stroke(ProfileStyle.background, lineWidth: 20)
                        ForEach(categories.indices, id: \.self) { index in
                            let start = Double(categories.prefix(index).reduce(0) { $0 + $1.count }) / Double(max(completed.count, 1))
                            let size = Double(categories[index].count) / Double(max(completed.count, 1))
                            if size > 0 {
                                Circle().trim(from: start + min(0.015, size / 4), to: start + size - min(0.015, size / 4))
                                    .stroke(colors[index], style: StrokeStyle(lineWidth: 20, lineCap: .round))
                                    .rotationEffect(.degrees(-90))
                            }
                        }
                        VStack(spacing: 6) {
                            Text("총 참여횟수").font(AppTypography.font(11)).foregroundStyle(ProfileStyle.muted)
                            Text("\(completed.count)회").font(AppTypography.font(24, weight: .bold)).foregroundStyle(ProfileStyle.accent)
                        }
                    }.frame(width: 146, height: 146).padding(.top, 8)
                        .accessibilityElement(children: .ignore).accessibilityLabel("총 참여횟수 \(completed.count)회")
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        ForEach(categories.indices, id: \.self) { index in
                            HStack(spacing: 6) {
                                Circle().fill(colors[index]).frame(width: 8, height: 8)
                                Text(categories[index].name)
                                Spacer(minLength: 2)
                                Text("\(completed.isEmpty ? 0 : Int((Double(categories[index].count) / Double(completed.count) * 100).rounded()))%")
                            }.font(AppTypography.font(11)).foregroundStyle(ProfileStyle.muted)
                        }
                    }.padding(16).background(ProfileStyle.background, in: RoundedRectangle(cornerRadius: 20))
                }.padding(24).frame(maxWidth: .infinity).background(.white, in: RoundedRectangle(cornerRadius: 32))
                VStack(spacing: 16) {
                    NavigationLink { RecentParticipationView(store: store) } label: { heading("최근 참여 운동") }
                    if let booking = completed.first {
                        NavigationLink { ReservationSummaryView(bookingID: booking.id, store: store) } label: {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(booking.venue).font(AppTypography.font(11)).foregroundStyle(ProfileStyle.muted)
                                    Text(booking.title).font(AppTypography.font(16, weight: .medium))
                                    Text("\(booking.dateLabel) \(booking.time)").font(AppTypography.font(12)).foregroundStyle(ProfileStyle.muted)
                                }
                                Spacer(minLength: 0)
                                ProfileArrow()
                            }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
                                .background(.white, in: RoundedRectangle(cornerRadius: 24))
                        }
                    } else {
                        Text("아직 참여한 운동이 없어요.").foregroundStyle(ProfileStyle.muted)
                            .frame(maxWidth: .infinity, minHeight: 100).background(.white, in: RoundedRectangle(cornerRadius: 24))
                    }
                }
                NavigationLink { ExerciseConditionsView(profile: profile) } label: {
                    VStack(spacing: 16) {
                        heading("나의 운동 조건")
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], alignment: .leading, spacing: 8) {
                            ForEach(conditionLabels, id: \.self) { label in
                                Text(label).font(AppTypography.font(11)).foregroundStyle(ProfileStyle.muted)
                                    .padding(10).frame(maxWidth: .infinity).background(ProfileStyle.background, in: Capsule())
                            }
                            if conditionLabels.isEmpty { Text("운동 조건을 선택해주세요.").font(AppTypography.font(12)) }
                        }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
                            .background(.white, in: RoundedRectangle(cornerRadius: 24))
                    }
                }
            }.buttonStyle(.plain).padding(24).padding(.top, 8).frame(maxWidth: 600).frame(maxWidth: .infinity)
        }.modifier(ProfilePageChrome(title: "나의 운동"))
    }
    private func heading(_ title: String) -> some View {
        HStack { Text(title).font(AppTypography.font(16, weight: .bold)); Spacer(); ProfileArrow() }.padding(.horizontal, 8)
    }
}
