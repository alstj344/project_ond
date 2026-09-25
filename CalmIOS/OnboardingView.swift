import SwiftUI
import MapKit
import WebKit

struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var profile = OnboardingProfile()
    @State private var path: [OnboardingStep] = []
    @State private var editing = false
    @State private var showConsultation = false
    @State private var showAddress = false
    @State private var draftAddress = ""
    @ScaledMetric(relativeTo: .title2) private var headingSize = 24.0
    private let secondary = Color(red: 113 / 255, green: 121 / 255, blue: 115 / 255)

    var body: some View {
        NavigationStack(path: $path) {
            screen(.profile)
                .navigationDestination(for: OnboardingStep.self) { screen($0) }
        }
        .tint(Theme.accent)
        .task {
            #if DEBUG && targetEnvironment(simulator)
            do {
                let data = try await APIService.shared.getMyProfile()
                try OnboardingPreferences.decodeResponse(data).apply(to: &profile)
            } catch {
                // Keep the editable defaults when there are no saved preferences.
            }
            #endif
        }
        .sheet(isPresented: $showAddress) { addressEditor }
        .alert("의료진 상담 안내", isPresented: $showConsultation) {
            Button("확인", role: .cancel) {}
        } message: {
            Text("현재 화면은 예시이며 의료기관과 연결되어 있지 않습니다. 운동 관련 안내는 이용 중인 의료기관에 문의해 주세요.")
        }
    }

    @ViewBuilder
    private func screen(_ step: OnboardingStep) -> some View {
        if step == .analysis {
            AnalysisView(profile: profile) {
                if path.last == .analysis { path.removeLast() }
            }
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    content(step)
                }
                .padding(.horizontal, 24)
                .padding(.top, topPadding(step))
                .padding(.bottom, 24)
                .frame(maxWidth: 480)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle(step.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .safeAreaInset(edge: .top, spacing: 0) {
                ProgressView(value: Double((OnboardingStep.allCases.firstIndex(of: step) ?? 0) + 1), total: 9)
                    .tint(Theme.accent).accessibilityLabel("정보 입력 진행 단계")
            }
            .toolbar {
                if step == .profile {
                    ToolbarItem(placement: .cancellationAction) {
                        Button { dismiss() } label: { Image(systemName: "arrow.left") }
                            .accessibilityLabel("서비스 이용 동의로 돌아가기")
                    }
                }
            }
            .safeAreaInset(edge: .bottom) { footer(step) }
        }
    }

    private func topPadding(_ step: OnboardingStep) -> CGFloat {
        32
    }

    @ViewBuilder
    private func content(_ step: OnboardingStep) -> some View {
        switch step {
        case .profile: profileFields
        case .environment:
            heading("운동하기\n편한 환경을 알려주세요", subtitle: "이동 거리와 가능한 시간을 알려주시면\n나에게 맞는 운동 환경을 찾아볼게요.")
            choices(OnboardingProfile.distanceOptions,
                    subtitles: ["집 앞 산책처럼 가볍게", "가벼운 발걸음으로 도달", "대중교통이나 자전거", "좋은 곳이라면 어디든 갈 수 있어요"],
                    selection: $profile.distance)
        case .experience:
            heading("운동 경험을 알려주세요", subtitle: "현재 운동 습관을 바탕으로\n나에게 맞는 프로그램을 찾아볼게요.")
            choices(OnboardingProfile.experienceOptions, selection: $profile.experience)
        case .activities:
            question("어떤 운동을 해보고 싶나요?")
            activityGrid
        case .format:
            heading("운동 경험을 알려주세요", subtitle: "현재 운동 습관을 바탕으로\n나에게 맞는 프로그램을 찾아볼게요.")
            choices(OnboardingProfile.formatOptions,
                    subtitles: ["타인의 시선 없는 편안한 온실", "나만의 속도에 맞춘 밀착 케어", "서로의 침묵을 배려하는 아늑한 연대감"],
                    selection: $profile.format)
        case .medicalLink: medicalLinkContent
        case .medicalQuestion: medicalQuestionContent
        case .medicalInfo: medicalInformation
        case .summary: summary
        case .analysis: EmptyView()
        }
    }

    private var profileFields: some View {
        VStack(alignment: .leading, spacing: 28) {
            VStack(alignment: .leading, spacing: 4) {
                (Text("나에게 딱 맞는\n") + Text("프로그램").foregroundColor(Theme.accent) + Text("을 찾아볼게요"))
                    .font(.system(size: headingSize, weight: .bold))
                    .fixedSize(horizontal: false, vertical: true)
                Text("나에게 맞는 운동을 찾기 위해 필요한 정보를 알려주세요.")
                    .font(.subheadline).foregroundStyle(secondary)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("연령대").font(.headline)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))], spacing: 8) {
                    ForEach(OnboardingProfile.ageOptions, id: \.self) { age in
                        Button { profile.age = age } label: {
                            Text(age).font(.footnote)
                                .padding(.horizontal, 8).frame(maxWidth: .infinity, minHeight: 40)
                                .background(profile.age == age ? Theme.mint.opacity(0.6) : Theme.surface, in: Capsule())
                                .overlay(Capsule().strokeBorder(profile.age == age ? Theme.accent.opacity(0.6) : .clear))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(profile.age == age ? Theme.accent : secondary)
                        .accessibilityAddTraits(profile.age == age ? .isSelected : [])
                    }
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("거주지").font(.headline)
                HStack {
                    TextField("서울시 강남구 역삼동", text: $profile.address)
                        .font(.subheadline)
                        .textContentType(.addressCityAndState)
                        .submitLabel(.done)
                        .accessibilityLabel("거주지")
                    Button {
                        draftAddress = profile.address
                        showAddress = true
                    } label: {
                        Image(systemName: "mappin.and.ellipse")
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("거주지 입력")
                }
                .padding(.leading, 16).padding(.trailing, 4)
                .frame(minHeight: 56)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16))
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("운동 가능 시간").font(.headline)
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(OnboardingProfile.timeOptions, id: \.self) { time in
                        option(time, selected: profile.times.contains(time)) { profile.toggleTime(time) }
                    }
                }
            }
        }
    }

    private var columns: [GridItem] { [GridItem(.flexible()), GridItem(.flexible())] }

    private var activityGrid: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(ExerciseActivity.allCases) { activity in
                let selected = profile.activities.contains(activity)
                Button { profile.toggleActivity(activity) } label: {
                    VStack(spacing: 10) {
                        Image(systemName: activity.symbol)
                            .font(.system(size: 23))
                            .frame(width: 40, height: 40)
                            .foregroundStyle(selected ? Color.white : secondary)
                            .background(selected ? Theme.accent : Color.clear, in: Circle())
                        Text(activity.rawValue).font(.subheadline)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, minHeight: 98)
                    .background(selected ? Theme.mint.opacity(0.6) : Theme.surface, in: RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(selected ? Theme.accent.opacity(0.6) : .clear))
                }
                .buttonStyle(.plain)
                .foregroundStyle(selected ? Theme.accent : secondary)
                .accessibilityAddTraits(selected ? .isSelected : [])
                .accessibilityValue(selected ? "선택됨" : "선택 안 됨")
            }
        }
    }

    private var medicalLinkContent: some View {
        VStack(alignment: .leading, spacing: 32) {
            heading("운동 시작 전에\n확인할 사항이 있어요.", subtitle: "안전한 운동을 위해 의료기관에서 받은\n운동 관련 정보가 있는지 확인할게요.")
            VStack(spacing: 12) {
                option("의료정보를 연결할래요.", subtitle: "의료기관에서 안내받은 정보를 추천에 반영해요.", selected: profile.linkMedical) {
                    profile.setMedicalLink(true)
                }
                option("나중에 연결할게요", subtitle: "지금 연결하지 않아도 서비스를 이용할 수 있어요.", selected: !profile.linkMedical) {
                    profile.setMedicalLink(false)
                }
            }
        }
    }

    private var medicalQuestionContent: some View {
        VStack(alignment: .leading, spacing: 40) {
            heading("의료기관에서 운동과 관련해\n권장받은 사항이 있나요?")
            VStack(spacing: 12) {
                option("있어요", subtitle: "운동할 때 참고할 사항이 있어요.", selected: profile.medicalAnswer == .yes) { profile.medicalAnswer = .yes }
                option("없어요", subtitle: "특별히 안내받은 운동 관련 사항이 없어요.", selected: profile.medicalAnswer == .no) { profile.medicalAnswer = .no }
                Button {
                    profile.medicalAnswer = .unsure
                } label: {
                    Text("잘 모르겠어요.").underline().frame(maxWidth: .infinity, minHeight: 44)
                }
                .foregroundStyle(profile.medicalAnswer == .unsure ? Theme.accent : secondary)
                .accessibilityAddTraits(profile.medicalAnswer == .unsure ? .isSelected : [])
            }
        }
    }

    private var medicalInformation: some View {
        VStack(alignment: .leading, spacing: 24) {
            heading("운동 관련 정보를 확인했어요", subtitle: "연계 의료기관에서 회원님의 안전한 회복을 위해 전달해주신 권장 운동 기준입니다.")
            Text("예시 데이터 · 실제 의료기관 연동 없음")
                .font(.caption).foregroundStyle(Theme.accent)
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    Text("마음편한 정신건강의학과").font(.headline)
                    Spacer()
                    Text("예시").font(.caption2).padding(8)
                        .background(Theme.mint.opacity(0.6), in: Capsule())
                }
                Divider()
                medicalField("운동 가능 여부", value: "가능(정상 참여)")
                Divider()
                medicalField("권장 운동 종목", value: "가벼운 걷기 · 요가 · 스트레칭")
                Divider()
                medicalField("운동 시 주의 / 권장 휴식", value: "고강도 유산소 및 과도한 근력 운동 지양,\n충분한 휴식 보장")
                Divider()
                medicalField("담당의 전달 메모", value: "무리하지 않고 자신의 호흡 속도를 지키며\n편안하게 참여하도록 지도 바랍니다.")
            }
            .padding(24)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 24))
        }
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 24) {
            heading("나에게 맞는\n운동 조건을 확인해볼까요?", subtitle: "지금까지 입력한 정보를 바탕으로 운동 조건을 정리했어요.")
            VStack(spacing: 12) {
                summaryTile("운동 종목", value: profile.activitySummary, note: "선호 조합")
                LazyVGrid(columns: columns, spacing: 12) {
                    summaryTile("참여 형태", value: profile.format, note: profile.format == "소그룹" ? "3~5명 소규모" : "")
                    summaryTile("운동 시간", value: profile.timeSummary)
                    summaryTile("이동 거리", value: profile.distance, note: profile.address)
                    summaryTile("참여 비용", value: "무료", note: "디자인 예시 기준")
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("의료적 운동 조건").font(.caption).foregroundStyle(secondary)
                    Text(profile.hasMedicalExample ? "저강도 운동 권장 (예시)" : "의료기관 정보 미연결").font(.headline)
                    Text(profile.hasMedicalExample ? "의료기관 연동 전 예시이며 실제 운동 조건이 아닙니다." : "개인별 의료적 운동 조건은 아직 확인되지 않았습니다.")
                        .font(.footnote).foregroundStyle(secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading).padding(16)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    private func medicalField(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.footnote).foregroundStyle(secondary)
            Text(value).font(.subheadline).fixedSize(horizontal: false, vertical: true)
        }
    }

    private func summaryTile(_ label: String, value: String, note: String = "") -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).font(.footnote).foregroundStyle(secondary)
            Text(value).font(.headline).fixedSize(horizontal: false, vertical: true)
            if !note.isEmpty { Text(note).font(.caption).foregroundStyle(Theme.accent) }
        }
        .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
        .padding(16)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 20))
    }

    private func question(_ title: String) -> some View {
        Text(title).font(.title3).foregroundStyle(Theme.ink)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func heading(_ title: String, subtitle: String = "") -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(AppTypography.font(24, weight: .bold, relativeTo: .title2))
                .foregroundStyle(Theme.ink).fixedSize(horizontal: false, vertical: true)
            if !subtitle.isEmpty {
                Text(subtitle).font(AppTypography.font(14)).foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func choices(_ titles: [String], subtitles: [String] = [], selection: Binding<String>) -> some View {
        VStack(spacing: 12) {
            ForEach(Array(titles.enumerated()), id: \.element) { index, title in
                option(title, subtitle: subtitles.indices.contains(index) ? subtitles[index] : "", selected: selection.wrappedValue == title) {
                    selection.wrappedValue = title
                }
            }
        }
    }

    private func option(_ title: String, subtitle: String = "", selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(AppTypography.font(16, weight: .medium))
                    if !subtitle.isEmpty {
                        Text(subtitle).font(AppTypography.font(13)).opacity(0.75)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundStyle(selected ? Theme.accent : Color(red: 235/255, green: 232/255, blue: 226/255))
                    .accessibilityHidden(true)
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
            .background(selected ? Theme.mint.opacity(0.6) : Theme.surface, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(selected ? Theme.accent.opacity(0.6) : .clear))
        }
        .buttonStyle(.plain)
        .foregroundStyle(selected ? Theme.accent : secondary)
        .accessibilityValue(selected ? "선택됨" : "선택 안 됨")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func footer(_ step: OnboardingStep) -> some View {
        VStack(spacing: 8) {
            Button {
                guard let next = profile.next(after: step) else { return }
                path.append(next)
            } label: {
                Text(footerTitle(step)).font(.body.weight(.medium))
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .foregroundStyle(Color.white)
                    .background(Theme.accent.opacity(profile.next(after: step) == nil ? 0.4 : 1), in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(profile.next(after: step) == nil)
            if step == .summary {
                Button("수정하기") { editing = true; path.removeAll() }
                    .font(.footnote).underline().frame(minHeight: 32)
            } else if step == .medicalInfo {
                Button("조건에 대해 의료진 상담이 더 필요하신가요?") { showConsultation = true }
                    .font(.caption).underline().frame(minHeight: 44)
            } else if step == .medicalLink {
                Text("데모에서는 의료정보를 조회하거나 전송하지 않습니다.")
                    .font(.caption2).foregroundStyle(secondary)
            } else if step == .medicalQuestion {
                Text("본 서비스의 질문은 의학적 진단이 아니며, 회원님의 안전한 운동 참여를 돕기 위한 기본 확인 절차입니다.")
                    .font(.caption2).foregroundStyle(secondary)
            }
            if editing && step != .summary {
                Button("수정 완료") {
                    guard profile.profileValid && !profile.activities.isEmpty else { return }
                    editing = false
                    path = [.summary]
                }
                .font(.footnote).frame(minHeight: 32)
                .disabled(!profile.profileValid || profile.activities.isEmpty)
            }
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 24).padding(.top, 8).padding(.bottom, 12)
        .frame(maxWidth: 480).frame(maxWidth: .infinity)
        .background(Theme.background)
    }

    private func footerTitle(_ step: OnboardingStep) -> String {
        switch step {
        case .medicalQuestion: return "확인 완료"
        case .medicalInfo: return "내용 확인했어요"
        case .summary: return "시작"
        default: return "다음 단계"
        }
    }

    private var addressEditor: some View {
        KakaoPostcodePicker(address: $draftAddress) {
            profile.address = draftAddress.trimmingCharacters(in: .whitespacesAndNewlines)
            showAddress = false
        } onCancel: {
            showAddress = false
        }
    }
}

private struct KakaoPostcodePicker: View {
    @Binding var address: String
    let onApply: () -> Void
    let onCancel: () -> Void
    @State private var selectedResult: KakaoAddressResult?
    @State private var selectedCoordinate: CLLocationCoordinate2D?
    @State private var mapRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.498, longitude: 127.028),
        span: MKCoordinateSpan(latitudeDelta: 0.025, longitudeDelta: 0.025)
    )
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let selectedResult, let coordinate = selectedCoordinate {
                    Map(coordinateRegion: $mapRegion, annotationItems: [AddressPin(coordinate: coordinate)]) { item in
                        MapMarker(coordinate: item.coordinate, tint: Theme.accent)
                    }
                    .overlay(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("선택한 주소").font(.caption).foregroundStyle(.secondary)
                            Text(selectedResult.roadAddress.isEmpty ? selectedResult.address : selectedResult.roadAddress)
                                .font(.subheadline.weight(.medium))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                        .padding(16)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    Button {
                        address = selectedResult.roadAddress.isEmpty ? selectedResult.address : selectedResult.roadAddress
                        onApply()
                    } label: {
                        Label("이 위치 사용", systemImage: "mappin.and.ellipse")
                            .font(.body.weight(.medium))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 54)
                            .background(Theme.accent, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                } else {
                    KakaoPostcodeWebView { result in
                        address = result.roadAddress.isEmpty ? result.address : result.roadAddress
                        selectedResult = result
                        Task { @MainActor in
                            let geocoder = CLGeocoder()
                            do {
                                let marks = try await geocoder.geocodeAddressString(address)
                                if let coordinate = marks.first?.location?.coordinate {
                                    mapRegion.center = coordinate
                                    selectedCoordinate = coordinate
                                }
                            } catch {
                                // The address can still be applied even if geocoding is unavailable.
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    Button {
                        onApply()
                    } label: {
                        Text("선택한 주소 사용")
                            .font(.body.weight(.medium))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 54)
                            .background(Theme.accent, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .disabled(address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .opacity(address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.45 : 1)
                }
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("주소 검색")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: onCancel) {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("닫기")
                }
            }
        }
        .presentationDetents([.large])
    }
}

private struct AddressPin: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}

private struct KakaoAddressResult {
    let address: String
    let roadAddress: String
}

private struct KakaoPostcodeWebView: UIViewRepresentable {
    let onSelect: (KakaoAddressResult) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onSelect: onSelect) }

    func makeUIView(context: Context) -> WKWebView {
        let contentController = WKUserContentController()
        contentController.add(context.coordinator, name: "kakaoPostcode")
        let configuration = WKWebViewConfiguration()
        configuration.userContentController = contentController
        configuration.allowsInlineMediaPlayback = true
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.backgroundColor = UIColor(Theme.background)
        webView.isOpaque = false
        webView.loadHTMLString(Self.html, baseURL: URL(string: "https://postcode.map.daum.net/"))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        let onSelect: (KakaoAddressResult) -> Void

        init(onSelect: @escaping (KakaoAddressResult) -> Void) {
            self.onSelect = onSelect
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "kakaoPostcode",
                  let payload = message.body as? [String: Any] else { return }
            let address = payload["address"] as? String ?? ""
            let roadAddress = payload["roadAddress"] as? String ?? ""
            guard !address.isEmpty || !roadAddress.isEmpty else { return }
            onSelect(KakaoAddressResult(address: address, roadAddress: roadAddress))
        }
    }

    private static let html = """
    <!doctype html>
    <html lang="ko">
    <head>
      <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
      <style>
        html, body, #postcode { margin: 0; width: 100%; height: 100%; overflow: hidden; background: #f8f7f5; }
      </style>
      <script src="https://t1.kakaocdn.net/mapjsapi/bundle/postcode/prod/postcode.v2.js"></script>
    </head>
    <body>
      <div id="postcode"></div>
      <script>
        new kakao.Postcode({
          oncomplete: function(data) {
            window.webkit.messageHandlers.kakaoPostcode.postMessage({
              address: data.address || '',
              roadAddress: data.roadAddress || ''
            });
          },
          width: '100%',
          height: '100%',
          maxSuggestItems: 5
        }).embed(document.getElementById('postcode'));
      </script>
    </body>
    </html>
    """
}

private struct AnalysisView: View {
    let profile: OnboardingProfile
    let onReview: () -> Void
    @State private var saving = false
    @State private var saveError: String?
    @AppStorage("calm.onboardingCompleted") private var onboardingCompleted = false
    @State private var complete = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var breathing = false

    var body: some View {
        VStack(spacing: 48) {
            Spacer()
            Image("AnalysisIllustration").resizable().scaledToFit()
            .frame(width: 180, height: 180)
            .scaleEffect(breathing && !reduceMotion && !complete ? 1.06 : 1)
            .accessibilityHidden(true)
            VStack(spacing: 8) {
                Text(complete ? "운동 조건 확인이 완료되었어요" : "나에게 맞는 운동을 찾고 있어요")
                    .font(AppTypography.font(20, weight: .bold))
                Text(complete ? "실제 프로그램 추천은 서비스 연결 후 제공됩니다." : "운동 조건과 선호를 바탕으로\n편하게 참여할 수 있는 운동을 살펴보고 있어요.")
                    .font(AppTypography.font(14)).foregroundStyle(Theme.muted)
            }.multilineTextAlignment(.center)
            if complete {
                Button(saving ? "저장 중…" : "홈으로 이동") {
                    Task { await saveAndContinue() }
                }.buttonStyle(.borderedProminent).disabled(saving)
                Button("조건 다시 확인", action: onReview).buttonStyle(.plain)
                    .disabled(saving)
            } else {
                ProgressView().accessibilityLabel("조건 확인 중")
            }
            Spacer()
            Spacer().frame(height: 60)
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: 480).frame(maxWidth: .infinity)
        .background(Theme.background.ignoresSafeArea())
        .alert("저장 안내", isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })) {
            Button("확인", role: .cancel) { saveError = nil }
        } message: { Text(saveError ?? "") }
        .task {
            if !reduceMotion {
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) { breathing = true }
            }
            do { try await Task.sleep(nanoseconds: 1_800_000_000) }
            catch { return }
            complete = true
            breathing = false
        }
    }

    @MainActor private func saveAndContinue() async {
        guard !saving else { return }
        saving = true
        defer { saving = false }
        #if DEBUG && targetEnvironment(simulator)
        do {
            try await APIService.shared.saveOnboarding(profile)
            onboardingCompleted = true
        } catch {
            saveError = "운동 조건을 저장하지 못했어요. 연결을 확인한 뒤 다시 시도해 주세요."
        }
        #else
        saveError = "현재 환경에서는 저장 서버에 연결할 수 없어요."
        #endif
    }
}

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView().preferredColorScheme(.light)
    }
}
