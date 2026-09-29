import SwiftUI
import FirebaseAuth
import CoreText
import UIKit

struct SafeAssetImage: View {
    let name: String
    let fallback: String
    var body: some View {
        if UIImage(named: name) != nil { Image(name).resizable().scaledToFit() }
        else { Image(systemName: fallback).resizable().scaledToFit() }
    }
}

enum AppTypography {
    static func register() {
        guard let url = Bundle.main.url(forResource: "Inter", withExtension: "ttf") else { return }
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }
    static func font(_ size: CGFloat = 14, weight: Font.Weight = .regular, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom("Inter-Regular", size: size, relativeTo: style).weight(weight)
    }
}

enum CancellationReason: String, CaseIterable, Identifiable {
    case schedule = "개인 일정이 생겼어요."
    case health = "건강상의 이유로 참여가 어려워요."
    case change = "다른 프로그램으로 변경했어요."
    case other = "기타"
    var id: String { rawValue }
}

struct FlowAction: View {
    let title: String
    var secondary = false
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title).font(AppTypography.font(16, weight: .medium))
                .frame(maxWidth: .infinity, minHeight: 52)
                .foregroundStyle(secondary ? Theme.accent : .white)
                .background(secondary ? Theme.surface : Theme.accent, in: Capsule())
        }.buttonStyle(.plain)
    }
}

struct ProgramLibraryView: View {
    @ObservedObject var store: WellnessStore
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(DiscoveryProgram.samples) { program in
                        NavigationLink(value: program) { ProgramCard(program: program) }.buttonStyle(.plain)
                    }
                }.padding(24).frame(maxWidth: 600).frame(maxWidth: .infinity)
            }.background(Theme.background.ignoresSafeArea())
                .navigationTitle("프로그램").navigationBarTitleDisplayMode(.inline)
                .navigationDestination(for: DiscoveryProgram.self) { ProgramDetailView(program: $0, store: store) }
        }
    }
}

struct RemoteProgramDetailView: View {
    let program: RemoteProgram

    @Environment(\.dismiss) private var dismiss

    @State private var isReserving = false
    @State private var confirmReservation = false
    @State private var createdReservation: RemoteReservation?
    @State private var showReservation = false
    @State private var reservationError: String?
    @State private var reviews: [RemoteReview] = []
    @State private var reviewCursor: String?
    @State private var loadingReviews = false
    @State private var loadedReviews = false
    @State private var reviewError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                heroPhoto

                VStack(alignment: .leading, spacing: 24) {

                    detailSummary
                    VStack(spacing: 12) {
                        ProgramInfoPanel(title: "운동정보") {
                            HStack(spacing: 0) {
                                detailMetric("종목", value: program.category.isEmpty ? "미등록" : program.category, asset: "ExerciseTypeLatest")
                                Divider().frame(height: 36)
                                detailMetric("난이도", value: difficultyLabel, asset: "ExerciseDifficultyLatest")
                                Divider().frame(height: 36)
                                detailMetric("참여 형태", value: participationLabel, asset: "ExerciseGroupLatest")
                            }
                        }
                        ProgramInfoPanel(title: "참여안내") {
                            VStack(alignment: .leading, spacing: 3) {
                                if program.participationGuide.isEmpty {
                                    Text(program.description.isEmpty ? "등록된 참여 안내가 없어요." : program.description)
                                } else {
                                    ForEach(Array(program.participationGuide.enumerated()), id: \.offset) { _, text in
                                        HStack(alignment: .top, spacing: 5) { Text("•"); Text(text).frame(maxWidth: .infinity, alignment: .leading) }
                                    }
                                }
                            }.font(AppTypography.font(11)).foregroundStyle(.secondary).lineSpacing(4)
                        }
                        ProgramInfoPanel(title: "편의시설 및 서비스") {
                            if program.amenities.isEmpty {
                                Text("등록된 편의시설 정보가 없어요.").font(AppTypography.font(11)).foregroundStyle(.secondary)
                            } else {
                                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 16) {
                                    ForEach(Array(program.amenities.enumerated()), id: \.offset) { _, name in
                                        VStack(spacing: 12) {
                                            SafeAssetImage(name: amenityAsset(name), fallback: "building.2").frame(width: 29, height: 38)
                                            Text(name).font(AppTypography.font(11)).foregroundStyle(.secondary).multilineTextAlignment(.center)
                                        }.frame(maxWidth: .infinity)
                                    }
                                }
                            }
                        }
                    }

                }
                .padding(24)
                Theme.background.frame(height: 7).padding(.top, 32)
                reviewSection.padding(24)
            }
            .frame(maxWidth: 600)
            .frame(maxWidth: .infinity)
        }
        .background(
            Color.white.ignoresSafeArea()
        )
        .navigationTitle("운동 후기")
        .task(id: program.programId) { await loadReviews(reset: true) }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .toolbarBackground(
            .white,
            for: .navigationBar
        )
        .toolbarBackground(
            .visible,
            for: .navigationBar
        )
        .toolbar {
            ToolbarItem(
                placement: .topBarLeading
            ) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "arrow.left")
                }
                .tint(Theme.muted)
                .accessibilityLabel("뒤로 가기")
            }
        }
        .toolbar(.hidden, for: .tabBar)

        // MARK: 예약 버튼
        .safeAreaInset(edge: .bottom) {
            Button {
                if createdReservation != nil {
                    showReservation = true
                } else {
                    confirmReservation = true
                }
            } label: {
                HStack(spacing: 8) {

                    if isReserving {
                        ProgressView()
                            .tint(.white)
                    }

                    Text(
                        createdReservation != nil
                        ? "예약 확인"
                        : isReserving
                        ? "예약 중"
                        : program.bookingAvailable ? "예약" : program.bookingUnavailableReason ?? "예약 일정 준비 중"
                    )
                }
                .font(
                    AppTypography.font(
                        16,
                        weight: .medium
                    )
                )
                .foregroundStyle(.white)
                .frame(
                    maxWidth: .infinity,
                    minHeight: 56
                )
                .background(
                    Theme.accent,
                    in: Capsule()
                )
            }
            .buttonStyle(.plain)
            .disabled(isReserving || (createdReservation == nil && !program.bookingAvailable))
            .padding(24)
            .background(.white)
        }

        // MARK: 예약 확인 Alert
        .alert(
            "예약하시겠어요?",
            isPresented: $confirmReservation
        ) {
            Button(
                "취소",
                role: .cancel
            ) {}

            Button("예약") {
                Task {
                    await reserve()
                }
            }
        } message: {
            Text(program.programName)
        }

        // MARK: 오류 Alert
        .alert(
            "예약 안내",
            isPresented: Binding(
                get: {
                    reservationError != nil
                },
                set: {
                    if !$0 {
                        reservationError = nil
                    }
                }
            )
        ) {
            Button(
                "확인",
                role: .cancel
            ) {
                reservationError = nil
            }
        } message: {
            Text(
                reservationError ?? ""
            )
        }

        // MARK: 예약 상세 이동
        .navigationDestination(
            isPresented: $showReservation
        ) {
            if let createdReservation {
                RemoteReservationResultView(
                    reservation: createdReservation
                ) {}
            }
        }
    }


    private var difficultyLabel: String {
        ["BEGINNER": "초보자", "INTERMEDIATE": "중급", "ADVANCED": "고급"][program.difficulty]
            ?? (program.difficulty.isEmpty ? "미등록" : program.difficulty)
    }
    private var participationLabel: String {
        ["SMALL_GROUP": "소모임", "SOLO": "개인", "ONE_ON_ONE": "1:1"][program.participationType]
            ?? (program.participationType.isEmpty ? "미등록" : program.participationType)
    }
    private var heroPhoto: some View {
        Color.clear.frame(height: 222).overlay {
            GeometryReader { geometry in
                Group {
                    if let source = program.imageURL, let url = URL(string: source), url.scheme == "https" {
                        AsyncImage(url: url) { phase in
                            if let image = phase.image { image.resizable().scaledToFill() }
                            else { photoPlaceholder }
                        }
                    } else { photoPlaceholder }
                }.frame(width: geometry.size.width, height: 222).clipped()
            }
        }.overlay(alignment: .bottomLeading) {
            HStack(spacing: 4) {
                if !program.category.isEmpty { photoBadge(program.category) }
                if !program.difficulty.isEmpty { photoBadge(difficultyLabel) }
                if program.price != nil { photoBadge(program.priceLabel) }
            }.padding(.leading, 24).padding(.bottom, 16)
        }
    }
    @ViewBuilder private var photoPlaceholder: some View {
        if program.isTestData {
            Image("DetailFrame103").resizable().scaledToFill()
        } else {
            ZStack { Theme.surface; Image(systemName: "photo").foregroundStyle(Theme.accent) }
        }
    }
    private func photoBadge(_ text: String) -> some View {
        Text(text).font(AppTypography.font(11, weight: .medium)).foregroundStyle(.secondary)
            .padding(.horizontal, 12).padding(.vertical, 4).background(.white.opacity(0.95), in: Capsule())
    }
    private var detailSummary: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(program.programName).font(AppTypography.font(20, weight: .bold)).fixedSize(horizontal: false, vertical: true)
                    Text(program.facilityName).font(AppTypography.font(11)).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                if let count = program.reservedCount, let capacity = program.capacity {
                    HStack(spacing: 6) {
                        SafeAssetImage(name: "DetailGroup44", fallback: "person").frame(width: 8.247, height: 10)
                        Text("\(count)/\(capacity)").font(AppTypography.font(11, weight: .semibold))
                    }.foregroundStyle(Theme.accent).padding(.horizontal, 11).padding(.vertical, 4)
                        .background(Theme.mint.opacity(0.6), in: Capsule())
                }
            }
            if !scheduleLabel.isEmpty { infoRow(title: "시간", value: scheduleLabel) }
            if !program.instructorName.isEmpty { infoRow(title: "강사", value: program.instructorName) }
        }.padding(.leading, 8)
    }
    private func detailMetric(_ title: String, value: String, asset: String) -> some View {
        VStack(spacing: 8) {
            SafeAssetImage(name: asset, fallback: "figure.mind.and.body").frame(width: 35, height: 38)
            VStack(spacing: 2) {
                Text(title).font(AppTypography.font(11)).foregroundStyle(.secondary)
                Text(value).font(AppTypography.font(9, weight: .medium)).foregroundStyle(Theme.accent)
                    .padding(.horizontal, 10).padding(.vertical, 2).background(Theme.mint.opacity(0.6), in: Capsule())
            }
        }.frame(maxWidth: .infinity)
    }
    private var scheduleLabel: String {
        guard let start = program.startDate else {
            return program.scheduleText + (program.durationMinutes.map { " (\($0)분)" } ?? "")
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        formatter.dateFormat = "M월 d일(E) a h:mm"
        var text = formatter.string(from: start)
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let end = iso.date(from: program.endAt) ?? ISO8601DateFormatter().date(from: program.endAt), end > start {
            formatter.dateFormat = "h:mm"
            text += " ~ " + formatter.string(from: end) + " (\(Int(end.timeIntervalSince(start) / 60))분)"
        } else if let minutes = program.durationMinutes {
            text += " (\(minutes)분)"
        }
        return text
    }
    private func amenityAsset(_ name: String) -> String {
        if name.contains("키오스크") { return "DetailFrame46" }
        if name.contains("휴게") { return "DetailGroup46" }
        if name.contains("퇴실") { return "DetailGroup49" }
        if name.contains("화장실") { return "DetailGroup50" }
        return ""
    }

    // MARK: - Reservation

    @MainActor
    private func reserve() async {

        guard !isReserving, program.bookingAvailable, let uid = Auth.auth().currentUser?.uid else {
            return
        }

        isReserving = true

        defer {
            isReserving = false
        }

        do {
            let result =
                try await APIService.shared
                    .createReservation(
                        programId: program.programId
                    )

            guard Auth.auth().currentUser?.uid == uid else { return }
            createdReservation = RemoteReservation(
                id: result.id,
                programId: result.programId,
                status: result.status,
                createdAt: result.createdAt,
                cancelledAt: result.cancelledAt,
                program: program
            )

            var change: [String: Any] = ["uid": uid]
            if let date = program.startDate { change["date"] = date }
            NotificationCenter.default.post(name: .ondReservationsChanged, object: nil, userInfo: change)
            showReservation = true

        } catch let error as APIError {

            reservationError =
                error.userMessage

        } catch {

            reservationError =
                "예약 결과를 확인하지 못했어요. 다시 예약하기 전에 예약 내역을 확인해 주세요."
        }
    }


    // MARK: - UI Helpers

    private var reviewSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                Text("리뷰").font(AppTypography.font(16, weight: .semibold))
                Text("\(reviews.count)건").foregroundStyle(Theme.accent)
                Spacer()
            }
            ForEach(reviews) { review in
                ReviewBody(rating: review.rating, text: review.content,
                           date: review.date,
                           sample: review.isSample)
                Divider()
            }
            if loadingReviews { ProgressView().frame(maxWidth: .infinity) }
            if let reviewError {
                Text(reviewError).foregroundStyle(.secondary)
                Button("다시 시도") { Task { await loadReviews(reset: !loadedReviews) } }
            } else if loadedReviews && reviews.isEmpty {
                Text("아직 등록된 리뷰가 없어요.").foregroundStyle(.secondary)
            }
            if reviewCursor != nil && !loadingReviews && reviewError == nil {
                Button("리뷰 더 보기") { Task { await loadReviews(reset: false) } }
            }
        }.font(AppTypography.font(13))
    }

    @MainActor private func loadReviews(reset: Bool) async {
        guard !loadingReviews else { return }
        loadingReviews = true
        reviewError = nil
        defer { loadingReviews = false }
        do {
            let page = try await APIService.shared.getProgramReviews(
                programId: program.programId, after: reset ? nil : reviewCursor)
            if reset { reviews = [] }
            let existing = Set(reviews.map(\.id))
            reviews.append(contentsOf: page.reviews.filter { !existing.contains($0.id) })
            reviewCursor = page.nextCursor
            loadedReviews = true
        } catch is CancellationError {
        } catch {
            reviewError = "리뷰를 불러오지 못했어요. 다시 시도해주세요."
        }
    }

    private func infoRow(
        title: String,
        value: String
    ) -> some View {

        HStack(
            alignment: .top,
            spacing: 12
        ) {
            Text(title)
                .foregroundStyle(.secondary)
                .frame(
                    width: 24,
                    alignment: .leading
                )

            Text(value)
                .foregroundStyle(.primary)
                .frame(
                    maxWidth: .infinity,
                    alignment: .leading
                )
        }
        .font(
            AppTypography.font(11)
        )
    }
}
private struct ProgramInfoPanel<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title).font(AppTypography.font(13, weight: .semibold)).padding(.horizontal, 4)
            content
        }.padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.background, in: RoundedRectangle(cornerRadius: 24))
    }
}

struct ReviewBody: View {
    let rating: Int
    let text: String
    var date: Date?
    var sample = false
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 2) {
                    ForEach(1...5, id: \.self) { value in
                        Image(systemName: "star.fill").foregroundStyle(value <= rating ? Theme.accent : .gray.opacity(0.3))
                    }
                    Text(String(format: "%.1f", Double(rating))).padding(.leading, 4)
                }.font(AppTypography.font(12)).accessibilityElement(children: .ignore).accessibilityLabel("\(rating)점")
                Spacer(minLength: 6)
                if let date {
                    Text(date, format: .dateTime.year().month().day()).font(AppTypography.font(10, relativeTo: .caption))
                } else if sample {
                    Text("예시 · 2026.8.15").font(AppTypography.font(10, relativeTo: .caption))
                }
            }
            Text(text).font(AppTypography.font(12, relativeTo: .footnote)).lineSpacing(5).fixedSize(horizontal: false, vertical: true)
        }.foregroundStyle(.secondary).padding(.vertical, 8).frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ProgramDetailView: View {
    let program: DiscoveryProgram
    @ObservedObject var store: WellnessStore
    @State private var completed = false
    @State private var newest = true
    @Environment(\.dismiss) private var dismiss
    private var existing: WellnessBooking? { store.booking(program.id) }
    private var active: Bool { existing != nil && existing?.isCancelled == false }
    private var reviews: [WellnessBooking] {
        let values = store.bookings.filter { $0.id == program.id && $0.rating > 0 }
        return newest ? Array(values.reversed()) : values
    }
    private let sampleReview = "요가를 처음 해봐서 동작을 못 따라갈까 걱정했는데, 어려운 동작은 하지 않아도 된다고 먼저 안내해 주셔서 마음이 편했어요. 사람도 많지 않고 다른 참여자와 이야기할 일이 거의 없어서 제 동작에만 집중할 수 있었어요."
    private var isYoga: Bool { program.category == "요가" }
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if isYoga {
                    Color.clear.frame(height: 222)
                        .overlay {
                            GeometryReader { geometry in
                                Image("DetailFrame103").resizable().scaledToFill()
                                    .frame(width: geometry.size.width, height: 222).clipped()
                            }
                        }
                        .overlay(alignment: .bottomLeading) {
                            HStack(spacing: 4) {
                                badge(program.category); badge("초급")
                                badge(program.price == 0 ? "무료" : "\(program.price)원")
                            }.padding(.leading, 24).padding(.bottom, 16)
                        }
                        .accessibilityLabel("햇빛이 드는 요가 공간")
                }
                VStack(alignment: .leading, spacing: 24) {
                    summary.padding(.leading, 8)
                    VStack(spacing: 12) {
                        infoSection("운동정보") {
                            HStack(spacing: 0) {
                                metric("종목", value: program.category) {
                                    if isYoga {
                                        Image("DetailRectangle30").renderingMode(.template)
                                            .resizable().scaledToFit().foregroundStyle(iconTint)
                                            .frame(width: 35, height: 37.333)
                                    } else {
                                        Image("GymIcon").resizable().scaledToFit().frame(width: 35, height: 37)
                                    }
                                }
                                separator("DetailLine2")
                                metric("난이도", value: "초보자") {
                                    HStack(alignment: .bottom, spacing: 2) {
                                        RoundedRectangle(cornerRadius: 1).fill(iconTint).frame(width: 10, height: 17)
                                        RoundedRectangle(cornerRadius: 1).fill(Color(red: 226/255, green: 231/255, blue: 227/255)).frame(width: 10, height: 21)
                                        RoundedRectangle(cornerRadius: 1).fill(Color(red: 226/255, green: 231/255, blue: 227/255)).frame(width: 10, height: 30)
                                    }
                                }
                                separator("DetailLine3")
                                metric("참여 형태", value: program.smallGroup ? "소모임" : "일반 참여") {
                                    asset("DetailFrame58", width: 34, height: 36)
                                }
                            }.padding(.horizontal, 14)
                        }
                        infoSection("참여안내") {
                            VStack(alignment: .leading, spacing: 3) {
                                bullet("처음 참여하는 분도 부담 없이 참여할 수 있어요")
                                bullet("편한 복장과 물을 준비해주세요.")
                                bullet("당일 컨디션에 맞춰 쉬어가도 괜찮아요.")
                            }
                        }
                        if isYoga {
                            infoSection("편의시설 및 서비스") {
                                HStack(spacing: 0) {
                                    facility("DetailFrame46", "키오스크", width: 22.201, height: 37.935)
                                    separator("DetailLine2")
                                    facility("DetailGroup46", "휴게 공간", width: 29, height: 28.714)
                                    separator("DetailLine2")
                                    facility("DetailGroup49", "중도퇴실", width: 21, height: 28.358)
                                    separator("DetailLine2")
                                    facility("DetailGroup50", "화장실", width: 29, height: 26.441)
                                }.padding(.horizontal, 14)
                            }
                        }
                    }
                }.padding(.horizontal, 24).padding(.top, 24)
                Theme.background.frame(height: 7).padding(.top, 56)
                reviewSection.padding(.horizontal, 24).padding(.top, 24)
            }.frame(maxWidth: 600).frame(maxWidth: .infinity)
        }.font(AppTypography.font(12, relativeTo: .footnote))
            .background(Color.white).navigationTitle("운동 후기").navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden()
            .toolbarBackground(.white, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button { dismiss() } label: { Image(systemName: "chevron.left") }.accessibilityLabel("뒤로 가기") } }
            .toolbar(.hidden, for: .tabBar)
            .safeAreaInset(edge: .bottom) {
                Group {
                    if active {
                        NavigationLink { ReservationSummaryView(bookingID: program.id, store: store) } label: {
                            Text("예약 확인").font(AppTypography.font(16, weight: .medium)).frame(maxWidth: .infinity, minHeight: 56).foregroundStyle(.white).background(Theme.accent, in: Capsule())
                        }
                    } else {
                        FlowAction(title: "예약") { store.reserve(program); completed = store.booking(program.id) != nil }
                            .disabled(!store.schedulesEnabled)
                    }
                }.padding(24).background(.white)
            }
            .navigationDestination(isPresented: $completed) { ReservationSuccessView(bookingID: program.id, store: store) }
    }
    private func badge(_ title: String) -> some View {
        Text(title).font(AppTypography.font(11, weight: .medium)).foregroundStyle(.secondary)
            .padding(.horizontal, 12).padding(.vertical, 4).background(.white, in: Capsule())
    }
    private var iconTint: Color { Color(red: 80/255, green: 115/255, blue: 99/255) }
    private var summary: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(program.title).font(AppTypography.font(20, weight: .bold))
            Text(program.venue).font(AppTypography.font(11)).foregroundStyle(.secondary)
            HStack(alignment: .top, spacing: 12) {
                Text("시간").foregroundStyle(.secondary)
                Text("\(program.date) \(program.time)")
            }.font(AppTypography.font(11))
        }
    }
    private func asset(_ name: String, width: CGFloat, height: CGFloat) -> some View {
        SafeAssetImage(name: name, fallback: "figure.mind.and.body").frame(width: width, height: height)
    }
    private func separator(_ name: String) -> some View {
        Rectangle().fill(Theme.accent.opacity(0.15)).frame(width: 1, height: 36)
    }
    private func bullet(_ title: String) -> some View {
        HStack(alignment: .top, spacing: 6) { Text("•"); Text(title).fixedSize(horizontal: false, vertical: true) }
            .font(AppTypography.font(11)).lineSpacing(5)
    }
    private func facility(_ name: String, _ title: String, width: CGFloat, height: CGFloat) -> some View {
        VStack(spacing: 8) {
            asset(name, width: width, height: height).frame(height: 40)
            Text(title).font(AppTypography.font(11)).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity)
    }
    private func metric<Icon: View>(_ title: String, value: String, @ViewBuilder icon: () -> Icon) -> some View {
        VStack(spacing: 8) {
            icon().frame(height: 40)
            Text(title).font(AppTypography.font(11)).foregroundStyle(.secondary)
            Text(value).font(AppTypography.font(9, weight: .medium)).foregroundStyle(Theme.accent)
                .padding(.horizontal, 10).padding(.vertical, 2)
                .background(Theme.mint.opacity(0.6), in: Capsule())
        }.foregroundStyle(iconTint).frame(maxWidth: .infinity)
    }
    private var reviewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Text("리뷰").font(AppTypography.font(16, weight: .bold))
                Text("\(reviews.count)건").font(AppTypography.font(13)).foregroundStyle(Theme.accent)
                Spacer()
                if !reviews.isEmpty {
                    Button { newest.toggle() } label: {
                        HStack(spacing: 4) {
                            Text(newest ? "최신순" : "오래된순")
                            Image(systemName: "chevron.down")
                        }.font(AppTypography.font(11)).foregroundStyle(.secondary)
                    }.buttonStyle(.plain)
                }
            }
            if reviews.isEmpty { Text("아직 작성된 후기가 없어요.").foregroundStyle(.secondary) }
            ForEach(reviews) { booking in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 3) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: "star.fill")
                                .foregroundStyle(star <= booking.rating ? Theme.accent : Theme.accent.opacity(0.15))
                        }
                        Text(String(format: "%.1f", Double(booking.rating))).foregroundStyle(Theme.accent).padding(.leading, 4)
                    }.font(AppTypography.font(11))
                        .accessibilityElement(children: .ignore).accessibilityLabel("5점 중 \(booking.rating)점")
                    Text(booking.review).font(AppTypography.font(11)).foregroundStyle(.secondary).lineSpacing(5)
                    Divider().padding(.top, 12)
                }.padding(.horizontal, 4)
            }
        }.frame(maxWidth: .infinity, alignment: .leading).padding(.bottom, 24)
    }
    private func metric(_ icon: String, _ title: String, _ value: String) -> some View {
        VStack(spacing: 6) {
            SafeAssetImage(name: icon, fallback: "figure.mind.and.body").frame(width: 35, height: 38)
            Text(title).foregroundStyle(Color(red: 113/255, green: 121/255, blue: 115/255))
            if !value.isEmpty {
                Text(value).font(AppTypography.font(9)).padding(.horizontal, 10).padding(.vertical, 2)
                    .background(Theme.mint.opacity(0.6), in: Capsule())
            }
        }.font(AppTypography.font(11, relativeTo: .caption)).foregroundStyle(Theme.accent).multilineTextAlignment(.center).frame(maxWidth: .infinity)
    }
    private func infoSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        ProgramInfoPanel(title: title) {
            content().foregroundStyle(.secondary)
        }
    }
}

struct ReservationSuccessView: View {
    let bookingID: String
    @ObservedObject var store: WellnessStore
    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                SuccessIcon().padding(.top, 70)
                Text("예약이 완료되었어요.").font(AppTypography.font(24, weight: .bold, relativeTo: .title2)).foregroundStyle(Theme.accent)
                Text("편안한 마음으로 참여하실 수 있도록 준비했어요.").foregroundStyle(.secondary).multilineTextAlignment(.center)
                if let date = store.booking(bookingID)?.reservedAt {
                    Text(date, format: .dateTime.month().day().hour().minute()).padding(10).background(Theme.mint.opacity(0.45), in: Capsule())
                }
                VStack(alignment: .leading, spacing: 12) {
                    Text("수업에 전달되는 운동 안내").fontWeight(.medium)
                    Text("이 예약은 기기에 저장된 데모 예약입니다. 상담·진료 내역 및 운동 안내는 강사에게 전송되지 않습니다.")
                }.padding(20).background(.white, in: RoundedRectangle(cornerRadius: 20)).padding(.top, 36)
                VStack(alignment: .leading, spacing: 12) {
                    Text("당일 컨디션에 맞춰 편하게 참여하세요.")
                    Text("몸이나 마음이 무겁게 느껴진다면 무리하지 않아도 괜찮아요. 데모 예약은 체크인 전까지 취소할 수 있어요.")
                }.padding(20).background(Theme.mint.opacity(0.4), in: RoundedRectangle(cornerRadius: 20))
            }.font(AppTypography.font(13)).padding(24).frame(maxWidth: 550).frame(maxWidth: .infinity)
        }.background(Theme.background.ignoresSafeArea()).navigationBarBackButtonHidden()
            .toolbar(.hidden, for: .tabBar)
            .safeAreaInset(edge: .bottom) {
                NavigationLink { ReservationSummaryView(bookingID: bookingID, store: store) } label: {
                    Text("예약 확인하기").font(AppTypography.font(16, weight: .medium)).frame(maxWidth: .infinity, minHeight: 52)
                        .background(Theme.surface, in: Capsule())
                }.padding(24).background(Theme.background)
            }
    }
}

struct SuccessIcon: View {
    var body: some View {
        Image("SuccessMark").resizable().scaledToFit().frame(width: 48, height: 48)
            .frame(width: 100, height: 100).background(Theme.accent, in: Circle())
            .accessibilityHidden(true)
    }
}

struct ReservationSummaryView: View {
    let bookingID: String
    @ObservedObject var store: WellnessStore
    @Environment(\.returnHome) private var returnHome
    @State private var cancelling = false
    @State private var cancelledBooking: WellnessBooking?
    @State private var showCancelled = false
    @State private var message = ""
    @State private var showMessage = false
    var body: some View {
        Group {
            if let booking = store.booking(bookingID) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        HStack {
                            Text(statusTitle(for: booking))
                            Spacer()
                            if let date = booking.reservedAt { Text(date, format: .dateTime.year().month().day()).font(AppTypography.font(10)) }
                        }.padding(16).background(Theme.mint.opacity(0.5), in: RoundedRectangle(cornerRadius: 16))
                        NavigationLink { ProgramDetailView(program: booking.displayProgram, store: store) } label: {
                            HStack {
                                Text(booking.title).font(AppTypography.font(22, weight: .bold, relativeTo: .title2))
                                Spacer()
                                SafeAssetImage(name: "NextIcon", fallback: "chevron.right").frame(width: 16, height: 22)
                            }
                        }.buttonStyle(.plain)
                        HStack {
                            utility("PhoneIcon", "예약 문의") { inform("데모 프로그램에는 문의 전화번호가 등록되어 있지 않습니다.") }
                            utility("AddressIcon", "주소 복사") {
                                UIPasteboard.general.string = booking.venue
                                inform("장소명을 복사했어요. 상세 도로명 주소는 아직 등록되지 않았습니다.")
                            }
                            NavigationLink { MyReviewsView(store: store, initiallyWritten: true) } label: {
                                utilityLabel("ReviewIcon", "작성된 후기")
                            }.buttonStyle(.plain)
                        }.padding(16).background(.white, in: RoundedRectangle(cornerRadius: 20))
                        VStack(alignment: .leading, spacing: 16) {
                            Text("시간   \(booking.dateLabel) \(booking.time)")
                            Text("장소   \(booking.venue)")
                            Text(booking.displayProgram.category == "요가" ? "강사   이지원 선생님" : "강사   기관 문의")
                        }.padding(20).frame(maxWidth: .infinity, alignment: .leading).background(.white, in: RoundedRectangle(cornerRadius: 20))
                        Button("화장실 위치 · 안전시설 안내") { inform("시설의 상세 위치 정보는 아직 등록되지 않았습니다. 방문 시 현장 안내를 확인해주세요.") }
                            .foregroundStyle(.secondary).frame(maxWidth: .infinity)
                        if !booking.isCancelled {
                            NavigationLink { BookingDetailView(bookingID: bookingID, store: store) } label: {
                                Text(booking.attendance == .checkedOut ? "운동 후기 작성·수정" : "출석 확인").padding(.vertical, 16).frame(maxWidth: .infinity)
                            }
                        }
                    }.padding(24).frame(maxWidth: 600).frame(maxWidth: .infinity)
                }.safeAreaInset(edge: .bottom) {
                    HStack {
                        FlowAction(title: "홈", secondary: true, action: returnHome).frame(maxWidth: 110)
                        if !booking.isCancelled && booking.attendance == .reserved {
                            FlowAction(title: "예약 취소") { cancelling = true }
                        }
                    }.padding(24).background(Theme.background)
                }
                .sheet(isPresented: $cancelling, onDismiss: { if cancelledBooking != nil { showCancelled = true } }) {
                    CancelReservationView(booking: booking) { reason in
                        if store.cancel(bookingID, reason: reason) { cancelledBooking = booking }
                        cancelling = false
                    }
                }
            } else { Text("예약 정보를 찾을 수 없어요.") }
        }.font(AppTypography.font(13)).background(Theme.background.ignoresSafeArea())
            .navigationTitle("예약 확인").navigationBarTitleDisplayMode(.inline).toolbar(.hidden, for: .tabBar)
            .alert("안내", isPresented: $showMessage) { Button("확인", role: .cancel) {} } message: { Text(message) }
            .navigationDestination(isPresented: $showCancelled) {
                if let booking = cancelledBooking { CancellationSuccessView(booking: booking) }
            }
    }
    private func inform(_ value: String) { message = value; showMessage = true }
    private func statusTitle(for booking: WellnessBooking) -> String {
        if booking.isCancelled { return "예약이 취소되었습니다." }
        switch booking.attendance {
        case .checkedOut: return "참여가 완료되었습니다."
        case .checkedIn: return "체크인되었습니다."
        case .reserved: return "예약이 확정되었습니다."
        }
    }
    private func utility(_ icon: String, _ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { utilityLabel(icon, title) }.buttonStyle(.plain)
    }
    private func utilityLabel(_ icon: String, _ title: String) -> some View {
        VStack(spacing: 10) {
            SafeAssetImage(name: icon, fallback: "ellipsis.circle").frame(width: 28, height: 28)
            Text(title).font(AppTypography.font(11)).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, minHeight: 60)
    }
}

struct CancelReservationView: View {
    let title: String
    let detail: String
    var isSubmitting = false
    var errorMessage: String?

    init(booking: WellnessBooking, onConfirm: @escaping (CancellationReason) -> Void) {
        title = booking.title
        detail = "\(booking.dateLabel) \(booking.time)"
        self.onConfirm = onConfirm
    }

    init(title: String, detail: String, isSubmitting: Bool, errorMessage: String?, onConfirm: @escaping (CancellationReason) -> Void) {
        self.title = title
        self.detail = detail
        self.isSubmitting = isSubmitting
        self.errorMessage = errorMessage
        self.onConfirm = onConfirm
    }

    let onConfirm: (CancellationReason) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var reason: CancellationReason?
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(spacing: 12) {
                    Text("예약을 취소하시겠어요?").font(AppTypography.font(24, weight: .bold, relativeTo: .title2))
                    Text("취소하시면 해당 프로그램에 참여하실 수 없어요.").foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity).multilineTextAlignment(.center)
                VStack(alignment: .leading, spacing: 8) {
                    Text(title).fontWeight(.semibold)
                    Text(detail).foregroundStyle(.secondary)
                }.padding(20).frame(maxWidth: .infinity, alignment: .leading).background(Theme.background, in: RoundedRectangle(cornerRadius: 16))
                Text("취소사유 선택").font(AppTypography.font(16, weight: .bold))
                VStack(spacing: 8) {
                    ForEach(CancellationReason.allCases) { value in
                        Button { reason = value } label: {
                            HStack {
                                Text(value.rawValue).multilineTextAlignment(.leading)
                                Spacer()
                                Image(systemName: reason == value ? "checkmark.circle.fill" : "circle")
                            }.padding(16).frame(minHeight: 52)
                                .background(reason == value ? Theme.mint.opacity(0.5) : Theme.surface, in: RoundedRectangle(cornerRadius: 16))
                                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(reason == value ? Theme.accent : .clear))
                        }.buttonStyle(.plain).accessibilityAddTraits(reason == value ? .isSelected : [])
                    }
                }
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                }
                HStack {
                    FlowAction(title: "취소", secondary: true) { dismiss() }.frame(maxWidth: 110).disabled(isSubmitting)
                    FlowAction(title: isSubmitting ? "취소 중…" : "확인") { if let reason { onConfirm(reason) } }.disabled(reason == nil || isSubmitting).opacity(reason == nil ? 0.4 : 1)
                        .accessibilityLabel("예약 취소 확정")
                }.padding(.top, 16)
            }.font(AppTypography.font(14)).padding(24).padding(.top, 24)
        }.presentationDetents([.large]).presentationDragIndicator(.visible).interactiveDismissDisabled(isSubmitting)
    }
}

struct CancellationSuccessView: View {
    let booking: WellnessBooking
    @Environment(\.returnHome) private var returnHome
    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                SuccessIcon().padding(.top, 90).padding(.bottom, 40)
                Text("예약이 취소되었습니다.").font(AppTypography.font(24, weight: .bold, relativeTo: .title2))
                Text("변경한 정보는 바로 반영되었어요.").foregroundStyle(.secondary)
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(booking.title).fontWeight(.semibold)
                        Text("\(booking.dateLabel) \(booking.time)").foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("취소완료").font(AppTypography.font(11)).foregroundStyle(.orange).padding(10).background(Color.orange.opacity(0.1), in: Capsule())
                }.padding(20).background(.white, in: RoundedRectangle(cornerRadius: 20)).padding(.top, 36)
            }.padding(24).frame(maxWidth: 550).frame(maxWidth: .infinity)
        }.font(AppTypography.font(13)).background(Theme.background.ignoresSafeArea()).navigationBarBackButtonHidden()
            .toolbar(.hidden, for: .tabBar)
            .safeAreaInset(edge: .bottom) { FlowAction(title: "확인", action: returnHome).padding(24).background(Theme.background) }
    }
}

struct MyReviewsView: View {
    @ObservedObject var store: WellnessStore
    @State private var written: Bool
    @State private var newest = true
    @State private var editing: WellnessBooking?
    @State private var returningHome = false
    @Environment(\.returnHome) private var returnHome
    init(store: WellnessStore, initiallyWritten: Bool = false) {
        self.store = store
        _written = State(initialValue: initiallyWritten)
    }
    private var items: [WellnessBooking] {
        let filtered = store.bookings.filter { !$0.isCancelled && $0.attendance == .checkedOut && (written ? $0.rating > 0 : $0.rating == 0) }
        return filtered.sorted {
            let lhs = written ? $0.reviewedAt ?? .distantPast : $0.reservedAt ?? .distantPast
            let rhs = written ? $1.reviewedAt ?? .distantPast : $1.reservedAt ?? .distantPast
            return lhs == rhs ? $0.id < $1.id : (newest ? lhs > rhs : lhs < rhs)
        }
    }
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) { tab("작성 가능한 리뷰", value: false); tab("작성한 리뷰", value: true) }.background(.white)
            ScrollView {
                LazyVStack(spacing: 12) {
                    HStack {
                        Text("리뷰").fontWeight(.bold)
                        Text("\(items.count)건").foregroundStyle(Theme.accent)
                        Spacer()
                        Menu(newest ? "최신순" : "오래된순") {
                            Button("최신순") { newest = true }
                            Button("오래된순") { newest = false }
                        }.font(AppTypography.font(11))
                    }.padding(.vertical, 10)
                    ForEach(items) { booking in
                        VStack(alignment: .leading, spacing: 16) {
                            NavigationLink { ProgramDetailView(program: booking.displayProgram, store: store) } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(booking.venue).font(AppTypography.font(11)).foregroundStyle(.secondary)
                                        Text(booking.title).font(AppTypography.font(16, weight: .medium))
                                        Text("\(booking.dateLabel) \(booking.time)").foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    SafeAssetImage(name: "NextIcon", fallback: "chevron.right").frame(width: 16, height: 22)
                                }
                            }.buttonStyle(.plain)
                            if written {
                                ReviewBody(rating: booking.rating, text: booking.review, date: booking.reviewedAt)
                            } else {
                                FlowAction(title: "리뷰 작성하기") { editing = booking }
                            }
                        }.padding(20).background(.white, in: RoundedRectangle(cornerRadius: 24))
                    }
                    if items.isEmpty {
                        Text(written ? "작성한 리뷰가 없어요." : "운동을 마치면 리뷰를 작성할 수 있어요.").foregroundStyle(.secondary).padding(.vertical, 40)
                    }
                }.padding(24).frame(maxWidth: 600).frame(maxWidth: .infinity)
            }
        }.font(AppTypography.font(13)).background(Theme.background.ignoresSafeArea())
            .navigationTitle("리뷰").navigationBarTitleDisplayMode(.inline).toolbar(.hidden, for: .tabBar)
            .sheet(item: $editing, onDismiss: {
                if returningHome { returningHome = false; returnHome() }
            }) { booking in
                ExerciseReviewView(booking: booking, onSave: { rating, reflection in
                    store.saveReview(booking.id, text: reflection.summary, rating: rating, reflection: reflection)
                    editing = nil
                    written = true
                }, onSkip: { returningHome = true; editing = nil })
            }
    }
    private func tab(_ title: String, value: Bool) -> some View {
        Button { written = value } label: {
            Text(title).font(AppTypography.font(16, weight: written == value ? .semibold : .regular))
                .frame(maxWidth: .infinity, minHeight: 56).foregroundStyle(written == value ? Theme.accent : .secondary)
                .overlay(alignment: .bottom) { Rectangle().fill(written == value ? Theme.accent : .clear).frame(height: 3) }
        }.buttonStyle(.plain).accessibilityAddTraits(written == value ? .isSelected : [])
    }
}
// MARK: - Server Reservations

struct RemoteReservationsView: View {
    @State private var reservations: [RemoteReservation] = []
    @State private var showingPrevious = false
    @State private var isLoading = false
    @State private var hasLoaded = false
    @State private var errorMessage: String?

    private var activeReservations: [RemoteReservation] {
        reservations.filter { $0.status == "RESERVED" }
    }

    private var previousReservations: [RemoteReservation] {
        reservations.filter { $0.status != "RESERVED" }
    }

    private var displayedReservations: [RemoteReservation] {
        showingPrevious ? previousReservations : activeReservations
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                reservationTab("예약 확정", value: false)
                reservationTab("이전 예약", value: true)
            }
            .background(.white)

            Group {
                if isLoading && !hasLoaded {
                    Spacer()
                    ProgressView("예약 내역을 불러오는 중이에요.")
                    Spacer()
                } else if let errorMessage {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.circle")
                            .font(.system(size: 32))
                            .foregroundStyle(.secondary)

                        Text(errorMessage)
                            .font(AppTypography.font(14))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)

                        Button("다시 시도") {
                            Task {
                                await loadReservations()
                            }
                        }
                        .font(AppTypography.font(14, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                    }
                    .padding(24)
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            HStack {
                                Text("예약내역")
                                    .font(AppTypography.font(17, weight: .bold))

                                Text("\(displayedReservations.count)건")
                                    .font(AppTypography.font(12, weight: .medium))
                                    .foregroundStyle(Theme.accent)

                                Spacer()
                            }

                            if displayedReservations.isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: "calendar")
                                        .font(.system(size: 32))
                                        .foregroundStyle(.secondary)

                                    Text(
                                        showingPrevious
                                        ? "이전 예약이 없어요."
                                        : "확정된 예약이 없어요."
                                    )
                                    .font(AppTypography.font(14))
                                    .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 60)
                            } else {
                                ForEach(displayedReservations) { reservation in
                                    NavigationLink {
                                        RemoteReservationDetailView(
                                            reservation: reservation,
                                            onChanged: {
                                                Task {
                                                    await loadReservations()
                                                }
                                            }
                                        )
                                    } label: {
                                        RemoteReservationCard(
                                            reservation: reservation
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(24)
                        .frame(maxWidth: 600)
                        .frame(maxWidth: .infinity)
                    }
                    .refreshable {
                        await loadReservations()
                    }
                }
            }
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("예약")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if !hasLoaded {
                await loadReservations()
            }
        }
    }

    private func reservationTab(_ title: String, value: Bool) -> some View {
        Button {
            showingPrevious = value
        } label: {
            Text(title)
                .font(
                    AppTypography.font(
                        14,
                        weight: showingPrevious == value ? .semibold : .regular
                    )
                )
                .frame(maxWidth: .infinity, minHeight: 56)
                .foregroundStyle(
                    showingPrevious == value
                    ? Theme.accent
                    : .secondary
                )
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(
                            showingPrevious == value
                            ? Theme.accent
                            : .clear
                        )
                        .frame(height: 3)
                }
        }
        .buttonStyle(.plain)
    }

    @MainActor
    private func loadReservations() async {
        guard !isLoading else {
            return
        }

        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        do {
            reservations = try await APIService.shared.getMyReservations()
            hasLoaded = true
        } catch is CancellationError {
            return
        } catch let error as APIError {
            errorMessage = error.userMessage
        } catch {
            errorMessage = "예약 내역을 불러오지 못했어요."
        }
    }
}

private struct RemoteReservationCard: View {
    let reservation: RemoteReservation

    var body: some View {
        HStack(spacing: 16) {
            programImage

            VStack(alignment: .leading, spacing: 7) {
                Text(reservation.program?.category ?? "프로그램")
                    .font(AppTypography.font(11, weight: .medium))
                    .foregroundStyle(Theme.accent)

                Text(
                    reservation.program?.title
                    ?? "프로그램 정보를 확인할 수 없어요."
                )
                .font(AppTypography.font(15, weight: .semibold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)

                if let startDate = reservation.program?.startDate {
                    Text(
                        startDate,
                        format: .dateTime
                            .year()
                            .month()
                            .day()
                            .hour()
                            .minute()
                    )
                    .font(AppTypography.font(12))
                    .foregroundStyle(.secondary)
                }

                Text(
                    reservation.status == "RESERVED"
                    ? "예약 확정"
                    : "예약 취소"
                )
                .font(AppTypography.font(11, weight: .medium))
                .foregroundStyle(
                    reservation.status == "RESERVED"
                    ? Theme.accent
                    : .secondary
                )
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(
            .white,
            in: RoundedRectangle(cornerRadius: 20)
        )
    }

    @ViewBuilder
    private var programImage: some View {
        if let imageURL = reservation.program?.imageURL,
           let url = URL(string: imageURL) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                default:
                    imagePlaceholder
                }
            }
            .frame(width: 88, height: 88)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        } else {
            imagePlaceholder
                .frame(width: 88, height: 88)
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    private var imagePlaceholder: some View {
        ZStack {
            Theme.surface

            Image(systemName: "figure.mind.and.body")
                .foregroundStyle(Theme.accent)
        }
    }
}

extension Notification.Name {
    static let ondReservationsChanged = Notification.Name("ond.reservations.changed")
}

struct RemoteReservationDetailView: View {
    let reservation: RemoteReservation
    let onChanged: () -> Void
    @Environment(\.returnHome) private var returnHome
    @State private var cancelling = false
    @State private var cancelledReservation: RemoteReservation?
    @State private var notice = ""
    @State private var showNotice = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Label(reservation.status == "RESERVED" ? "예약이 확정되었습니다." : "예약이 취소되었습니다.",
                      systemImage: "checkmark.circle.fill")
                    .font(AppTypography.font(12)).foregroundStyle(Theme.accent)
                    .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.mint.opacity(0.4), in: RoundedRectangle(cornerRadius: 16))
                if let program = reservation.program {
                    VStack(spacing: 20) {
                        NavigationLink { RemoteProgramDetailView(program: program) } label: {
                            HStack {
                                Text(program.title).font(AppTypography.font(20, weight: .bold))
                                Spacer()
                                Image(systemName: "chevron.right").foregroundStyle(Theme.muted)
                            }
                        }.buttonStyle(.plain)
                        HStack {
                            Button { notice = "등록된 예약 문의 연락처가 없어요."; showNotice = true } label: {
                                confirmationAction("예약 문의", icon: "phone.fill")
                            }
                            Divider().frame(height: 36)
                            Button { notice = "등록된 주소가 없어요. 프로그램 상세의 장소 정보를 확인해 주세요."; showNotice = true } label: {
                                confirmationAction("주소 복사", icon: "mappin.circle.fill")
                            }
                            Divider().frame(height: 36)
                            NavigationLink { RemoteProgramDetailView(program: program) } label: {
                                confirmationAction("작성된 후기", icon: "bubble.left.fill")
                            }
                        }.buttonStyle(.plain).padding(16)
                            .background(Theme.background, in: RoundedRectangle(cornerRadius: 16))
                    }.padding(20).background(.white, in: RoundedRectangle(cornerRadius: 24))
                    VStack(alignment: .leading, spacing: 12) {
                        confirmationRow("시간", value: program.startDate?.formatted(.dateTime.month().day().hour().minute()) ?? program.scheduleText)
                        confirmationRow("장소", value: program.facilityName)
                        confirmationRow("강사", value: program.instructorName)
                    }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
                        .background(.white, in: RoundedRectangle(cornerRadius: 24))
                    Button {
                        notice = program.amenities.isEmpty ? "등록된 편의시설 및 안전시설 안내가 없어요." : program.amenities.joined(separator: " · ")
                        showNotice = true
                    } label: {
                        Text("화장실 위치 · 안전시설 안내").font(AppTypography.font(12))
                            .foregroundStyle(Theme.muted).frame(maxWidth: .infinity)
                    }
                } else {
                    Text("프로그램 정보를 불러올 수 없어요.").foregroundStyle(.secondary)
                }
                if reservation.status == "RESERVED" {
                    Button("예약 취소") { cancelling = true }
                        .font(AppTypography.font(13)).frame(maxWidth: .infinity)
                }
            }.padding(24).frame(maxWidth: 600).frame(maxWidth: .infinity)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("예약 확인").navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .safeAreaInset(edge: .bottom) {
            FlowAction(title: "확인", action: returnHome).padding(24).background(Theme.background)
        }
        .alert("안내", isPresented: $showNotice) { Button("확인", role: .cancel) {} } message: { Text(notice) }
        .sheet(isPresented: $cancelling, onDismiss: {
            // Present the result only after the cancellation sheet has closed.
        }) {
            RemoteReservationCancellationSheet(reservation: reservation) {
                cancelledReservation = RemoteReservation(id: reservation.id, programId: reservation.programId,
                    status: "CANCELLED", createdAt: reservation.createdAt, cancelledAt: nil, program: reservation.program)
                if let uid = Auth.auth().currentUser?.uid {
                    NotificationCenter.default.post(name: .ondReservationsChanged, object: nil,
                        userInfo: ["uid": uid, "cancelledID": reservation.id])
                }
                onChanged()
                cancelling = false
            }
        }
        .navigationDestination(isPresented: Binding(
            get: { cancelledReservation != nil && !cancelling },
            set: { if !$0 { cancelledReservation = nil } }
        )) {
            if let cancelledReservation {
                RemoteReservationResultView(reservation: cancelledReservation, onChanged: onChanged)
            }
        }
    }

    private func confirmationAction(_ title: String, icon: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 26)).foregroundStyle(Theme.accent)
            Text(title).font(AppTypography.font(10)).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, minHeight: 64)
    }
    private func confirmationRow(_ title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(title).foregroundStyle(.secondary)
            Text(value.isEmpty ? "등록된 정보가 없어요." : value)
        }.font(AppTypography.font(12))
    }
}

private struct RemoteReservationCancellationSheet: View {
    let reservation: RemoteReservation
    let onSuccess: () -> Void
    @State private var submitting = false
    @State private var errorMessage: String?
    var body: some View {
        CancelReservationView(title: reservation.program?.title ?? "예약한 프로그램",
            detail: reservation.program?.startDate?.formatted(.dateTime.month().day().hour().minute()) ?? reservation.program?.scheduleText ?? "",
            isSubmitting: submitting, errorMessage: errorMessage) { reason in
                Task { @MainActor in
                    guard !submitting, let uid = Auth.auth().currentUser?.uid else { return }
                    submitting = true
                    errorMessage = nil
                    defer { submitting = false }
                    do {
                        try await APIService.shared.cancelReservation(programId: reservation.programId, reason: reason.rawValue)
                        guard Auth.auth().currentUser?.uid == uid else { return }
                        onSuccess()
                    } catch let error as APIError { errorMessage = error.userMessage }
                    catch { errorMessage = "예약을 취소하지 못했어요. 다시 시도해 주세요." }
                }
            }.interactiveDismissDisabled(submitting)
    }
}

struct RemoteReservationResultView: View {
    let reservation: RemoteReservation
    let onChanged: () -> Void
    @Environment(\.returnHome) private var returnHome
    @State private var isCancelling = false
    @State private var showCancelConfirmation = false
    @State private var didCancel = false
    @State private var errorMessage: String?
    private var cancelled: Bool { didCancel || reservation.status == "CANCELLED" }
    private var program: RemoteProgram? { reservation.program }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                SuccessIcon().padding(.top, cancelled ? 100 : 64).padding(.bottom, 28)
                VStack(spacing: 12) {
                    Text(cancelled ? "예약이 취소되었습니다." : "예약이 완료되었어요.")
                        .font(AppTypography.font(24, weight: .bold))
                    Text(cancelled ? "변경한 정보는 바로 반영되었어요." : "편안한 마음으로 참여하실 수 있도록 준비했어요.")
                        .font(AppTypography.font(13)).foregroundStyle(Theme.muted)
                }.multilineTextAlignment(.center)
                if !cancelled, let date = receiptDate {
                    (Text(date, format: .dateTime.month().day().hour().minute()) + Text(" 접수"))
                        .font(AppTypography.font(11)).foregroundStyle(Theme.accent)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(Theme.mint.opacity(0.6), in: Capsule())
                        .accessibilityLabel("접수 시간 \(date.formatted())")
                }
                if cancelled {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(program?.title ?? "예약한 프로그램").font(AppTypography.font(16, weight: .semibold))
                            Spacer()
                            Text("취소완료").font(AppTypography.font(11))
                                .foregroundStyle(Color(red: 0.65, green: 0.28, blue: 0.16))
                                .padding(.horizontal, 14).padding(.vertical, 7)
                                .background(Color(red: 1, green: 0.92, blue: 0.89), in: Capsule())
                        }
                        Text(schedule).font(AppTypography.font(12)).foregroundStyle(.secondary)
                    }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
                        .background(.white, in: RoundedRectangle(cornerRadius: 18)).padding(.top, 24)
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("수업에 전달된 운동 안내").font(AppTypography.font(13, weight: .semibold))
                            Text("별도로 전달된 개인 운동 안내는 확인되지 않았어요. 아래 프로그램 참여 안내를 확인해 주세요.")
                                .font(AppTypography.font(12)).foregroundStyle(.secondary)
                            if let program {
                                ForEach(Array(program.participationGuide.enumerated()), id: \.offset) { _, text in
                                    Text(text).font(AppTypography.font(12)).foregroundStyle(.secondary)
                                }
                            }
                        }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
                            .background(.white, in: RoundedRectangle(cornerRadius: 18))
                        VStack(alignment: .leading, spacing: 8) {
                            Text("당일 컨디션에 맞춰 편하게 참여하세요.")
                                .font(AppTypography.font(13, weight: .semibold))
                            Text("당일 몸이나 마음이 무겁게 느껴진다면, 무리하지 않아도 괜찮아요. 취소 가능 여부는 프로그램의 예약 안내를 확인해 주세요.")
                                .font(AppTypography.font(12))
                        }.foregroundStyle(Theme.accent).padding(20)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Theme.mint.opacity(0.35), in: RoundedRectangle(cornerRadius: 18))
                    }.padding(.top, 24)
                }
            }.padding(24).frame(maxWidth: 600).frame(maxWidth: .infinity)
        }
        .background(Theme.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 8) {
                Button { finish() } label: {
                    Text("확인").font(AppTypography.font(16, weight: .medium))
                        .frame(maxWidth: cancelled ? .infinity : 110, minHeight: 56)
                        .foregroundStyle(cancelled ? .white : Theme.accent)
                        .background(cancelled ? Theme.accent : Theme.surface, in: Capsule())
                }
                if !cancelled && reservation.status == "RESERVED" {
                    Button { showCancelConfirmation = true } label: {
                        Text("예약 취소").font(AppTypography.font(16, weight: .medium))
                            .frame(maxWidth: .infinity, minHeight: 56)
                            .foregroundStyle(.white).background(Theme.accent, in: Capsule())
                    }.disabled(isCancelling)
                }
            }.buttonStyle(.plain).padding(24).background(Theme.background)
        }
        .sheet(isPresented: $showCancelConfirmation) {
            CancelReservationView(title: program?.title ?? "예약한 프로그램", detail: schedule,
                isSubmitting: isCancelling, errorMessage: errorMessage) { reason in
                    Task { await cancelReservation(reason: reason) }
                }
        }
    }

    private var receiptDate: Date? {
        guard let value = reservation.createdAt else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: value) ?? ISO8601DateFormatter().date(from: value)
    }

    private func finish() {
        if didCancel, let uid = Auth.auth().currentUser?.uid {
            NotificationCenter.default.post(name: .ondReservationsChanged, object: nil,
                userInfo: ["uid": uid, "cancelledID": reservation.id])
            onChanged()
        }
        returnHome()
    }

    private var schedule: String {
        program?.startDate?.formatted(.dateTime.year().month().day().hour().minute())
            ?? program?.scheduleText ?? "등록된 일정이 없어요."
    }

    @MainActor private func cancelReservation(reason: CancellationReason) async {
        guard !isCancelling, !cancelled, let uid = Auth.auth().currentUser?.uid else { return }
        isCancelling = true
        errorMessage = nil
        defer { isCancelling = false }
        do {
            try await APIService.shared.cancelReservation(programId: reservation.programId, reason: reason.rawValue)
            guard Auth.auth().currentUser?.uid == uid else { return }
            didCancel = true
            showCancelConfirmation = false
        } catch let error as APIError {
            errorMessage = error.userMessage
        } catch {
            errorMessage = "예약을 취소하지 못했어요. 다시 시도해 주세요."
        }
    }
}
