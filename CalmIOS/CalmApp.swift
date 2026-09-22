import SwiftUI

@main
struct CalmApp: App {
    init() { AppTypography.register() }
    @AppStorage("calm.onboardingCompleted") private var onboardingCompleted = false
    var body: some Scene {
        WindowGroup {
            Group {
                if onboardingCompleted { HomeView() }
                else { LaunchGate() }
            }
                .tint(Theme.accent)
                .preferredColorScheme(.light)
    }
}

}

private struct LaunchGate: View {
    @State private var finished = false
    var body: some View {
        Group { if finished { WelcomeView() } else { SplashView() } }
            .task {
                try? await Task.sleep(nanoseconds: 900_000_000)
                withAnimation(.easeInOut(duration: 0.25)) { finished = true }
            }
    }
}

private struct SplashView: View {
    var body: some View {
        Image("Splash").resizable().scaledToFill()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.background).ignoresSafeArea()
    }
}

enum Theme {
    static let background = Color(red: 248 / 255, green: 247 / 255, blue: 245 / 255)
    static let surface = Color(red: 244 / 255, green: 241 / 255, blue: 236 / 255)
    static let mint = Color(red: 188 / 255, green: 238 / 255, blue: 211 / 255)
    static let accent = Color(red: 37 / 255, green: 83 / 255, blue: 63 / 255)
    static let ink = Color(red: 28 / 255, green: 28 / 255, blue: 24 / 255)
}

enum AuthMode: String, Identifiable {
    case signup, login
    var id: Self { self }
    var title: String { self == .signup ? "회원가입" : "로그인" }
}

struct WelcomeView: View {
    @State private var authMode: AuthMode?
    @ScaledMetric(relativeTo: .body) private var buttonHeight = 52.0

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                Spacer()
                Image("WelcomeIllustration").resizable().scaledToFit().frame(width: 210, height: 150)
                VStack(spacing: 10) {
                    Text("내 일상에 맞는\n운동을 찾아보세요.").font(AppTypography.font(22, weight: .bold)).multilineTextAlignment(.center)
                    Text("나에게 맞는 운동 프로그램을 추천하고\n부담 없이 시작할 수 있도록 함께할게요.")
                        .font(AppTypography.font(12)).foregroundStyle(Color.secondary).multilineTextAlignment(.center)
                }.padding(.top, 18)
                Spacer()
                Button { authMode = .signup } label: {
                    Text("시작하기").font(AppTypography.font(14, weight: .medium)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 56).background(Theme.accent, in: Capsule())
                }.buttonStyle(.plain)
                Button("천천히 둘러보기") { }.font(AppTypography.font(12)).foregroundStyle(Color.secondary).frame(minHeight: 48)
            }.padding(.horizontal, 24).padding(.bottom, 16).frame(maxWidth: 402).frame(maxWidth: .infinity).frame(minHeight: geometry.size.height)
                .background(Theme.background.ignoresSafeArea())
        }
        .fullScreenCover(item: $authMode) { mode in
            if mode == .signup { SignupView() } else { AuthView(mode: mode) }
        }
    }

    private var accountPrompt: some View {
        Group {
            Text("이미 계정이 있나요?")
                .foregroundStyle(Color(red: 65 / 255, green: 73 / 255, blue: 68 / 255))
            Button { authMode = .login } label: {
                Text("로그인").underline().frame(minHeight: 44)
            }
        }
    }

    private var illustration: some View {
        ZStack {
            Circle()
                .fill(Theme.mint.opacity(0.5))
                .frame(width: 176, height: 176)
                .blur(radius: 20)
            Circle()
                .fill(Theme.surface)
                .frame(width: 96, height: 96)
                .shadow(color: .black.opacity(0.05), radius: 1, y: 1)
            Capsule()
                .fill(Theme.mint)
                .frame(width: 64, height: 30)
            Image("Leaf")
                .resizable()
                .scaledToFit()
                .frame(width: 29.925, height: 30)
        }
        .frame(height: 96)
        .accessibilityHidden(true)
    }
}

private struct SignupView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showAgreement = false
    @State private var showLogin = false
    var body: some View {
        VStack(spacing: 0) {
            HStack { Button { dismiss() } label: { Image(systemName: "arrow.left") }; Spacer() }.padding(.top, 18)
            VStack(alignment: .leading, spacing: 8) {
                Text("나에게 맞는 운동,\nOnD에서 시작해볼까요?").font(AppTypography.font(22, weight: .bold))
                Text("내게 맞는 운동을 찾고, 부담 없이 이어가보세요.").font(AppTypography.font(12)).foregroundStyle(Color.secondary)
            }.frame(maxWidth: .infinity, alignment: .leading).padding(.top, 34)
            Spacer()
            Image("SignupIllustration").resizable().scaledToFit().frame(maxWidth: .infinity).frame(height: 260)
            Spacer()
            Button { showAgreement = true } label: {
                Text("회원가입").font(AppTypography.font(14, weight: .medium)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 56).background(Theme.accent, in: Capsule())
            }.buttonStyle(.plain)
            HStack(spacing: 4) { Text("이미 계정이 있나요?").foregroundStyle(Color.secondary); Button("로그인") { showLogin = true }.underline() }
                .font(AppTypography.font(12)).frame(minHeight: 48)
        }.padding(.horizontal, 24).background(Theme.background.ignoresSafeArea())
            .fullScreenCover(isPresented: $showAgreement) { AgreementView() }
            .fullScreenCover(isPresented: $showLogin) { AuthView(mode: .login) }
    }
}

struct AuthView: View {
    let mode: AuthMode
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var password = ""
    @State private var showResult = false
    @State private var revealPassword = false

    private var validInput: Bool {
        let value = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = value.split(separator: "@", omittingEmptySubsequences: false)
        return parts.count == 2 && !parts[0].isEmpty
            && parts[1].contains(".") && !value.contains(where: \.isWhitespace)
            && password.count >= (mode == .signup ? 8 : 1)
    }

    var body: some View {
        GeometryReader { geometry in
            let top = geometry.safeAreaInsets.top
            ZStack(alignment: .topLeading) {
                Theme.background.ignoresSafeArea()
                HStack {
                    Button { dismiss() } label: { Image(systemName: "arrow.left").font(.system(size: 25, weight: .medium)) }
                    Spacer()
                    Text("로그인").font(AppTypography.font(14))
                    Spacer()
                    Color.clear.frame(width: 25)
                }.foregroundStyle(Theme.accent).frame(width: geometry.size.width - 48)
                    .position(x: geometry.size.width / 2, y: top - 55)
                VStack(alignment: .leading, spacing: 8) {
                    Text("오늘도 운동을 이어가볼까요?").font(AppTypography.font(22, weight: .bold))
                    Text("로그인하고 나에게 맞는 운동을 이어가보세요.").font(AppTypography.font(12)).foregroundStyle(Color.secondary)
                }.frame(width: geometry.size.width - 48, alignment: .leading)
                    .position(x: geometry.size.width / 2, y: top + 40)
                VStack(spacing: 12) {
                    TextField("아이디 입력", text: $email).textContentType(.username).textInputAutocapitalization(.never).autocorrectionDisabled()
                        .padding(.horizontal, 16).frame(height: 56).background(Theme.surface, in: RoundedRectangle(cornerRadius: 16))
                    HStack {
                        if revealPassword { TextField("비밀번호 입력", text: $password) } else { SecureField("비밀번호 입력", text: $password) }
                        Button { revealPassword.toggle() } label: { Image(systemName: revealPassword ? "eye.slash" : "eye").foregroundStyle(Color.secondary) }
                    }.padding(.horizontal, 16).frame(height: 56).background(Theme.surface, in: RoundedRectangle(cornerRadius: 16))
                }.font(AppTypography.font(13)).frame(width: geometry.size.width - 48)
                    .position(x: geometry.size.width / 2, y: top + 250)
                Button("로그인") { password = ""; showResult = true }.font(AppTypography.font(14, weight: .medium)).foregroundStyle(.white)
                    .frame(width: geometry.size.width - 48, height: 56).background(Theme.accent, in: Capsule())
                    .disabled(!validInput).opacity(validInput ? 1 : 0.55)
                    .position(x: geometry.size.width / 2, y: top + 403)
                HStack(spacing: 4) { Text("아직 계정이 없나요?").foregroundStyle(Color.secondary); Button("회원가입") { dismiss() }.underline() }
                    .font(AppTypography.font(12)).position(x: geometry.size.width / 2, y: top + 468)
                Image("LoginIllustration").resizable().scaledToFit().frame(width: 58, height: 58)
                    .position(x: geometry.size.width / 2, y: geometry.size.height - 64)
            }
            .alert("입력 형식 확인 완료", isPresented: $showResult) {
                Button("확인", role: .cancel) {}
            } message: {
                Text("실제 계정 생성 및 로그인에는 인증 서버 연결이 필요합니다.")
            }
        }
    }
}

struct WelcomeView_Previews: PreviewProvider {
    static var previews: some View {
        WelcomeView().tint(Theme.accent).preferredColorScheme(.light)
    }
}

enum AgreementTerm: String, CaseIterable, Identifiable {
    case service, privacy, personalization, notifications
    var id: Self { self }
    var required: Bool { self == .service || self == .privacy }
    var title: String {
        switch self {
        case .service: return "서비스 이용약관"
        case .privacy: return "개인정보 수집 및 이용 동의"
        case .personalization: return "맞춤 추천을 위한 정보 이용"
        case .notifications: return "알림 수신"
        }
    }
    var label: String { title + (required ? "(필수)" : "(선택)") }
}

struct AgreementSelection {
    private(set) var accepted: Set<AgreementTerm> = []
    var allAccepted: Bool { accepted.count == AgreementTerm.allCases.count }
    var canContinue: Bool {
        AgreementTerm.allCases.filter(\.required).allSatisfy { accepted.contains($0) }
    }
    mutating func set(_ term: AgreementTerm, accepted value: Bool) {
        if value { accepted.insert(term) } else { accepted.remove(term) }
    }
    mutating func setAll(_ value: Bool) {
        accepted = value ? Set(AgreementTerm.allCases) : []
    }
}

struct AgreementView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selection = AgreementSelection()
    @State private var detail: AgreementTerm?
    @State private var showSignup = false
    @ScaledMetric(relativeTo: .title2) private var headingSize = 24.0
    @ScaledMetric(relativeTo: .footnote) private var rowFontSize = 13.0
    private let secondary = Color(red: 113 / 255, green: 121 / 255, blue: 115 / 255)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("서비스 이용을 위해\n몇 가지 동의가 필요해요")
                            .font(.system(size: headingSize, weight: .bold))
                            .lineSpacing(4)
                            .foregroundStyle(Theme.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("필수 항목 동의 후, 서비스를 시작해보세요.")
                            .font(.subheadline)
                            .foregroundStyle(secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 32)
                    .padding(.bottom, 48)

                    Toggle(isOn: Binding(
                        get: { selection.allAccepted },
                        set: { selection.setAll($0) }
                    )) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("전체 동의하기")
                                .font(.headline)
                                .foregroundStyle(Theme.ink)
                            Text("선택 항목을 포함한 모든 약관에 동의합니다")
                                .font(.system(size: rowFontSize))
                                .foregroundStyle(secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .toggleStyle(AgreementToggleStyle())
                    Divider().padding(.vertical, 24)

                    VStack(spacing: 0) {
                        ForEach(AgreementTerm.allCases) { term in
                            HStack(spacing: 0) {
                                Toggle(isOn: Binding(
                                    get: { selection.accepted.contains(term) },
                                    set: { selection.set(term, accepted: $0) }
                                )) {
                                    Text(term.label)
                                        .font(.system(size: rowFontSize))
                                        .foregroundStyle(secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .toggleStyle(AgreementToggleStyle())
                                Button { detail = term } label: {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundStyle(secondary)
                                        .frame(width: 44, height: 44)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(term.title + " 상세 보기")
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
                .frame(maxWidth: 480)
                .frame(maxWidth: .infinity)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("서비스 이용 동의")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Image(systemName: "arrow.left") }
                        .accessibilityLabel("뒤로 가기")
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 10) {
                    Button { showSignup = true } label: {
                        Text("동의하고 계속하기")
                            .font(.body.weight(.medium))
                            .foregroundStyle(selection.canContinue ? Color.white : secondary)
                            .frame(maxWidth: .infinity, minHeight: 56)
                            .background(selection.canContinue ? Theme.accent : Theme.surface, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(!selection.canContinue)
                    .accessibilityHint("필수 약관 두 항목에 동의하면 계속할 수 있습니다")
                    Text("데모에서는 개인정보를 저장하거나 전송하지 않습니다")
                        .font(.caption2)
                        .foregroundStyle(secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 12)
                .frame(maxWidth: 480)
                .frame(maxWidth: .infinity)
                .background(Theme.background)
            }
            .sheet(item: $detail) { term in
                AgreementDetailView(term: term)
            }
            .fullScreenCover(isPresented: $showSignup) {
                OnboardingView()
            }
        }
    }
}

private struct AgreementToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button { configuration.isOn.toggle() } label: {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(configuration.isOn ? Theme.accent : Color.clear)
                    Circle()
                        .strokeBorder(configuration.isOn ? Theme.accent : Color(red: 235 / 255, green: 232 / 255, blue: 226 / 255), lineWidth: 1)
                    if configuration.isOn {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: 24, height: 24)
                configuration.label
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(configuration.isOn ? "동의함" : "동의하지 않음")
        .accessibilityAddTraits(configuration.isOn ? .isSelected : [])
    }
}

private struct AgreementDetailView: View {
    let term: AgreementTerm
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(term.title).font(.title2.bold())
                    Text(term.required ? "필수 동의 항목" : "선택 동의 항목")
                        .font(.subheadline).foregroundStyle(Theme.accent)
                    Text("약관 본문이 아직 제공되지 않았습니다. 이 화면은 동작 확인용이며 실제 서비스 약관 동의를 받지 않습니다.")
                    if !term.required {
                        Text("이 항목에 동의하지 않아도 다음 단계로 진행할 수 있습니다.")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(24)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("약관 상세")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                        .accessibilityLabel("닫기")
                }
            }
        }
    }
}

struct AgreementView_Previews: PreviewProvider {
    static var previews: some View {
        AgreementView().tint(Theme.accent).preferredColorScheme(.light)
    }
}
