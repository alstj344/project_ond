import SwiftUI
import FirebaseAuth

enum Attendance: String, Codable {
    case reserved, checkedIn, checkedOut
    var title: String {
        switch self {
        case .reserved: return "진행 예정"
        case .checkedIn: return "체크인"
        case .checkedOut: return "퇴실"
        }
    }
}

struct WellnessBooking: Identifiable, Codable {
    let id: String
    let title: String
    let venue: String
    let day: Int
    let time: String
    var attendance: Attendance = .reserved
    var review = ""
    var rating = 0
    var program: DiscoveryProgram?
    var reflection: ExerciseReflection?
    var reservedAt: Date?
    var reviewedAt: Date?
    var participatedAt: Date?
    var cancelledAt: Date?
    var cancellationReason: String?
    var isCancelled: Bool { cancelledAt != nil }
    var dateLabel: String { program?.date ?? "9월 \(day)일(\(["일", "월", "화", "수", "목", "금", "토"][(day - 1) % 7]))" }
    var displayProgram: DiscoveryProgram {
        program ?? DiscoveryProgram(id: id, venue: venue, title: title, date: dateLabel, day: day,
            time: time, category: id == "yoga" ? "요가" : id == "walk" ? "걷기" : "스트레칭",
            minutes: 0, kilometers: 0, smallGroup: false, reviews: rating > 0 ? 1 : 0, price: 0)
    }
}

final class WellnessStore: ObservableObject {
    @Published private(set) var bookings: [WellnessBooking]
    @Published private(set) var schedulesEnabled = false
    private let defaults: UserDefaults
    private let ownerID: String?
    private let key: String

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let uid = Auth.auth().currentUser?.uid
        ownerID = uid
        key = "calm.bookings.v2.\(uid ?? "guest")"
        bookings = []
    }

    func setMedicalRegistration(_ registered: Bool) {
        let enabled = registered && ownerID != nil && ownerID == Auth.auth().currentUser?.uid
        guard schedulesEnabled != enabled else { return }
        schedulesEnabled = enabled
        // Preserve account-owned records on disk, but never import the old shared demo cache.
        guard enabled else { bookings = []; return }
        if let data = defaults.data(forKey: key),
           let saved = try? JSONDecoder().decode([WellnessBooking].self, from: data) {
            bookings = saved
        } else {
            bookings = []
        }
    }

    func booking(_ id: String) -> WellnessBooking? { bookings.first { $0.id == id } }

    @discardableResult
    func transition(_ id: String, to next: Attendance) -> Bool {
        guard let index = bookings.firstIndex(where: { $0.id == id }) else { return false }
        let current = bookings[index].attendance
        guard !bookings[index].isCancelled else { return false }
        guard (current == .reserved && next == .checkedIn) || (current == .checkedIn && next == .checkedOut) else { return false }
        bookings[index].attendance = next
        if next == .checkedOut { bookings[index].participatedAt = Date() }
        save()
        return true
    }

    func reserve(_ program: DiscoveryProgram) {
        guard schedulesEnabled, ownerID == Auth.auth().currentUser?.uid else { return }
        if let index = bookings.firstIndex(where: { $0.id == program.id }) {
            guard bookings[index].isCancelled else { return }
            bookings[index].cancelledAt = nil
            bookings[index].cancellationReason = nil
            bookings[index].reservedAt = Date()
            save()
            return
        }
        bookings.append(WellnessBooking(id: program.id, title: program.title, venue: program.venue,
            day: program.day, time: program.time, program: program, reservedAt: Date()))
        save()
    }

    @discardableResult
    func cancel(_ id: String, reason: CancellationReason) -> Bool {
        guard let index = bookings.firstIndex(where: { $0.id == id }),
              !bookings[index].isCancelled, bookings[index].attendance == .reserved else { return false }
        bookings[index].cancelledAt = Date()
        bookings[index].cancellationReason = reason.rawValue
        save()
        return true
    }

    func saveReview(_ id: String, text: String, rating: Int, reflection: ExerciseReflection? = nil) {
        guard let index = bookings.firstIndex(where: { $0.id == id }),
              !bookings[index].isCancelled, bookings[index].attendance == .checkedOut, (1...5).contains(rating) else { return }
        guard reflection == nil || reflection?.complete == true else { return }
        bookings[index].review = String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1000))
        bookings[index].rating = rating
        bookings[index].reflection = reflection
        bookings[index].reviewedAt = Date()
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(bookings) { defaults.set(data, forKey: key) }
    }
}

private enum HomeTab: String { case explore, home, bookings, profile }

struct HomeView: View {
    var isBrowsing = false
    @State private var showLogin = false
    @State private var confirmMedicalTest = false
    @State private var registeringMedical = false
    @State private var medicalError: String?
    @StateObject private var store = WellnessStore()
    @StateObject private var profile = ProfileStore()
    @State private var tab: HomeTab = .home
    @State private var selectedDay = 2
    @State private var query = ""
    @State private var navigationIdentity = UUID()
    @State private var attendanceSheet: AttendanceSheet?
    @State private var attendanceBookingID: String?
    @State private var pendingReview = false
    private let secondary = Color(red: 113 / 255, green: 121 / 255, blue: 115 / 255)

    var body: some View {
        TabView(selection: $tab) {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        VStack(alignment: .leading, spacing: 24) {
                            Image("HomeBrand").resizable().scaledToFit().frame(width: 50, height: 31)
                                .foregroundStyle(Theme.accent).accessibilityLabel("마음걸음")
                            VStack(alignment: .leading, spacing: 0) {
                                if isBrowsing {
                                    Button { showLogin = true } label: {
                                        Text("로그인").underline()
                                    }.buttonStyle(.plain)
                                    Text("오늘도 운동을 시작해볼까요?")
                                } else {
                                    Text(profile.name.isEmpty ? "오늘도 운동을 시작해볼까요?" : "\(profile.name)님,\n오늘도 운동을 시작해볼까요?")
                                }
                            }
                                .font(AppTypography.font(20, weight: .semibold))
                                .fixedSize(horizontal: false, vertical: true)
                            if let booking = store.bookings.first(where: { $0.attendance != .checkedOut && !$0.isCancelled }) {
                                reservationCard(booking)
                            } else {
                                Text("예정된 운동이 없어요.").padding(20)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(.white, in: RoundedRectangle(cornerRadius: 24))
                            }
                        }.padding(24).frame(maxWidth: 600).frame(maxWidth: .infinity)
                            .background(Color(red: 147/255, green: 207/255, blue: 174/255))
                        VStack(spacing: 24) {
                            if !isBrowsing && profile.medicalLoaded {
                                VStack(alignment: .leading, spacing: 12) {
                                    if profile.hasMedicalTestData {
                                        Label("의료 데이터 등록됨 · 테스트용", systemImage: "checkmark.circle")
                                            .font(AppTypography.font(16, weight: .medium))
                                        Text(profile.medicalTestData?.institution ?? "").font(AppTypography.font(13))
                                        Text(profile.medicalTestData?.memo ?? "").font(AppTypography.font(12)).foregroundStyle(.secondary)
                                    } else {
                                        Text("의료 데이터를 등록해주세요").font(AppTypography.font(16, weight: .medium))
                                        Button(registeringMedical ? "등록 중…" : "테스트 의료 데이터 등록") {
                                            confirmMedicalTest = true
                                        }.disabled(registeringMedical)
                                    }
                                }.frame(maxWidth: .infinity, alignment: .leading).padding(20)
                                    .background(Theme.background, in: RoundedRectangle(cornerRadius: 8))
                            }
                            monthlyProgress
                            schedule
                            if store.bookings.contains(where: { !$0.isCancelled && $0.attendance == .checkedOut }) {
                                reviewBanner
                            }
                        }.padding(24).frame(maxWidth: 600).frame(maxWidth: .infinity)
                        Divider().padding(.vertical, 16)
                        VStack(spacing: 16) {
                            Button { tab = .explore } label: {
                                HStack {
                                    Text("추천 운동").font(AppTypography.font(18, weight: .bold))
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                }
                            }.buttonStyle(.plain).padding(.horizontal, 24)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(DiscoveryProgram.samples) { program in
                                        NavigationLink { ProgramDetailView(program: program, store: store).toolbar(.visible, for: .navigationBar) } label: {
                                            ProgramCard(program: program).frame(width: 290)
                                        }.buttonStyle(.plain)
                                    }
                                }.padding(.horizontal, 24)
                            }
                        }
                        .padding(.bottom, 24)
                    }.font(AppTypography.font(13)).foregroundStyle(Theme.ink)
                }
                .background(.white)
                .background(Color(red: 147/255, green: 207/255, blue: 174/255).ignoresSafeArea(edges: .top))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(for: String.self) { ReservationSummaryView(bookingID: $0, store: store).toolbar(.visible, for: .navigationBar) }
                .sheet(item: $attendanceSheet, onDismiss: {
                    if pendingReview { pendingReview = false; attendanceSheet = .review }
                }) { sheet in
                    if let id = attendanceBookingID, let booking = store.booking(id) {
                        if sheet == .review {
                            ExerciseReviewView(booking: booking, onSave: { rating, reflection in
                                store.saveReview(id, text: reflection.summary, rating: rating, reflection: reflection)
                                attendanceSheet = nil
                            }, onSkip: { attendanceSheet = nil })
                        } else {
                            AttendanceResultView(booking: booking, isCheckout: sheet == .checkOut,
                                onConfirm: { attendanceSheet = nil },
                                onReview: { pendingReview = true; attendanceSheet = nil })
                        }
                    }
                }
            }
            .tabItem { Label("홈", systemImage: "house") }.tag(HomeTab.home)
            DiscoveryView(store: store).tabItem { Label("탐색", systemImage: "location.magnifyingglass") }.tag(HomeTab.explore)
            ReservationsView(store: store)
            .tabItem { Label("예약", systemImage: "hand.tap") }.tag(HomeTab.bookings)
            MyPageView(store: store, profile: profile)
            .tabItem { Label("마이페이지", systemImage: "person") }.tag(HomeTab.profile)
        }
        .tint(Theme.accent)
        .task { if !isBrowsing { await profile.refresh() } }
        .onChange(of: profile.hasMedicalTestData) { registered in
            store.setMedicalRegistration(!isBrowsing && registered)
        }
        .confirmationDialog("테스트 의료 데이터를 등록할까요?", isPresented: $confirmMedicalTest, titleVisibility: .visible) {
            Button("테스트 데이터 등록") {
                registeringMedical = true
                Task { @MainActor in
                    defer { registeringMedical = false }
                    do { try await profile.registerMedicalExample() }
                    catch { medicalError = "등록하지 못했어요. 연결을 확인한 뒤 다시 시도해 주세요." }
                }
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("현재 로그인 계정에 가상 의료기관과 임시 메모를 저장합니다. 실제 진료정보가 아니며 운동 추천이나 진료 판단에 사용하지 않습니다.")
        }
        .alert("의료 데이터 등록", isPresented: Binding(get: { medicalError != nil }, set: { if !$0 { medicalError = nil } })) {
            Button("확인", role: .cancel) { medicalError = nil }
        } message: { Text(medicalError ?? "") }
        .id(navigationIdentity)
        .environment(\.returnHome, { tab = .home; navigationIdentity = UUID() })
        .environment(\.showBookings, { tab = .bookings })
        .fullScreenCover(isPresented: $showLogin) { AuthView(mode: .login) }
    }

    private var monthlyProgress: some View {
        VStack(spacing: 16) {
            HStack {
                Text("이번 달 운동").font(.footnote.bold()).foregroundStyle(Theme.accent)
                Spacer()
                Text("\(monthlyCount)회 참여").font(.caption2).foregroundStyle(secondary)
            }
            HStack(spacing: 0) {
                ForEach(0..<4) { index in
                    Image(systemName: index < monthlyCount ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 24))
                        .foregroundStyle(index < monthlyCount ? Theme.accent : Color(red: 235/255, green: 232/255, blue: 226/255))
                    if index < 3 { Rectangle().fill(index < monthlyCount - 1 ? Theme.accent : Color.black.opacity(0.05)).frame(height: 4) }
                }
            }
            .accessibilityElement(children: .ignore).accessibilityLabel("이번 달 운동 목표 4회 중 \(monthlyCount)회 참여")
            NavigationLink { MyExerciseView(store: store, profile: profile) } label: {
                Text("나의 운동").font(AppTypography.font(14, weight: .medium))
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .foregroundStyle(.white).background(Theme.accent, in: Capsule())
            }
        }
        .padding(16).background(Theme.surface, in: RoundedRectangle(cornerRadius: 24))
    }

    private var monthlyCount: Int {
        store.bookings.filter {
            !$0.isCancelled && $0.attendance == .checkedOut &&
            $0.participatedAt.map { Calendar.current.isDate($0, equalTo: Date(), toGranularity: .month) } == true
        }.count
    }

    private func reservationCard(_ booking: WellnessBooking) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            bookingLabel(booking)
            HStack(spacing: 12) {
                attendanceButton("조용히 체크인", booking: booking, next: .checkedIn, enabled: booking.attendance == .reserved)
                attendanceButton("조용히 나가기", booking: booking, next: .checkedOut, enabled: booking.attendance == .checkedIn)
            }
        }
        .padding(16).background(.white, in: RoundedRectangle(cornerRadius: 24))
    }

    private func attendanceButton(_ title: String, booking: WellnessBooking, next: Attendance, enabled: Bool) -> some View {
        Button {
            if store.transition(booking.id, to: next) {
                attendanceBookingID = booking.id
                attendanceSheet = next == .checkedIn ? .checkIn : .checkOut
            }
        } label: {
            Text(title).font(AppTypography.font(12, weight: .medium))
                .frame(maxWidth: .infinity, minHeight: 44)
                .foregroundStyle(enabled ? Theme.accent : secondary.opacity(0.6))
                .background(Theme.background, in: Capsule())
        }.buttonStyle(.plain).disabled(!enabled)
    }

    private var reviewBanner: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                Text("지난 운동은 어떠셨나요?").font(AppTypography.font(16, weight: .bold))
                Text("남겨주신 경험을 바탕으로\n다음 운동을 찾아볼게요.")
                    .font(AppTypography.font(11)).foregroundStyle(secondary)
                NavigationLink { MyReviewsView(store: store).toolbar(.visible, for: .navigationBar) } label: {
                    Text("리뷰 남기기").font(AppTypography.font(11))
                        .padding(.horizontal, 16).frame(minHeight: 36)
                        .foregroundStyle(.white).background(Theme.accent, in: Capsule())
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
            Image("HomeReview").resizable().scaledToFit().frame(width: 100, height: 120).accessibilityHidden(true)
        }.padding(20).background(Theme.mint, in: RoundedRectangle(cornerRadius: 24))
    }

    private var schedule: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("나의 일정").font(.headline)
                Text("9월 \(selectedDay)일").font(.caption2).foregroundStyle(secondary)
            }
            HStack(spacing: 2) {
                ForEach(1...7, id: \.self) { day in
                    Button { selectedDay = day } label: {
                        VStack(spacing: 8) {
                            Text(["일", "월", "화", "수", "목", "금", "토"][day - 1]).font(.caption2)
                            Text("\(day)").font(.footnote.weight(.semibold))
                            Image(systemName: "figure.mind.and.body").font(.system(size: 15))
                                .opacity(store.bookings.contains { $0.day == day && !$0.isCancelled } ? 1 : 0)
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                        .foregroundStyle(selectedDay == day ? Color.white : secondary)
                        .background(selectedDay == day ? Theme.accent : .clear, in: Capsule())
                    }
                    .buttonStyle(.plain).accessibilityLabel("9월 \(day)일")
                    .accessibilityAddTraits(day == selectedDay ? .isSelected : [])
                }
            }
            let daily = store.bookings.filter { $0.day == selectedDay && !$0.isCancelled }
            if daily.isEmpty { Text("예정된 일정이 없어요.").font(.footnote).foregroundStyle(secondary).padding(.vertical, 12) }
            ForEach(daily) { booking in
                NavigationLink(value: booking.id) {
                    ViewThatFits(in: .horizontal) {
                        HStack { Text(booking.title).font(.footnote); Spacer(); Text(booking.time).font(.caption2) }
                        VStack(alignment: .leading) { Text(booking.title).font(.footnote); Text(booking.time).font(.caption2) }
                    }
                    .foregroundStyle(Theme.ink).padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.white, in: RoundedRectangle(cornerRadius: 14))
                }
            }
        }
        .padding(16).background(Theme.surface, in: RoundedRectangle(cornerRadius: 24))
    }

    private func bookingLabel(_ booking: WellnessBooking) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                Text(booking.title).font(.headline)
                Spacer(minLength: 8)
                AttendanceBadge(status: booking.attendance)
            }
            Text("\(booking.dateLabel) \(booking.time)").font(.footnote).foregroundStyle(secondary)
            Text(booking.venue).font(.footnote).foregroundStyle(secondary)
        }
    }

    private func catalog(searchable: Bool) -> some View {
        NavigationStack {
            List {
                ForEach(store.bookings.filter { !searchable || query.isEmpty || ($0.title + $0.venue).localizedCaseInsensitiveContains(query) }) { booking in
                    NavigationLink(value: booking.id) { bookingLabel(booking) }
                }
            }
            .navigationTitle(searchable ? "탐색" : "프로그램")
            .searchable(text: $query, prompt: "프로그램 또는 장소 검색")
            .navigationDestination(for: String.self) { ReservationSummaryView(bookingID: $0, store: store) }
        }
    }
}

private enum AttendanceSheet: String, Identifiable { case checkIn, checkOut, review; var id: Self { self } }

struct BookingDetailView: View {
    let bookingID: String
    @ObservedObject var store: WellnessStore
    @State private var sheet: AttendanceSheet?
    @State private var openReviewAfterDismiss = false
    @State private var silentMode = true
    @State private var returnHomeAfterDismiss = false
    @Environment(\.returnHome) private var returnHome

    var body: some View {
        Group {
            if let booking = store.booking(bookingID) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack { Label("9월 일정 달성률", systemImage: "chart.bar"); Spacer(); Text("\(Int(progress * 100))%") }
                                .font(.headline).foregroundStyle(Theme.accent)
                            ProgressView(value: progress).tint(Theme.accent)
                            Text("이번 달 총 일정 \(store.bookings.count)건").font(.caption).foregroundStyle(.secondary)
                        }.padding(20).background(Theme.surface, in: RoundedRectangle(cornerRadius: 24))
                        Text("나의 일정").font(.title2.bold())
                        Text(booking.dateLabel).font(.headline)
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(alignment: .top) { Text(booking.title).font(.headline); Spacer(); AttendanceBadge(status: booking.attendance) }
                            Text(booking.venue).font(.subheadline).foregroundStyle(.secondary)
                            Text("\(booking.dateLabel) · \(booking.time)").font(.subheadline).foregroundStyle(.secondary)
                        }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
                            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 24))
                        Text("오늘은 잠시 쉬어가고 싶으신가요?").font(.headline)
                        Text("이유를 설명하지 않아도 괜찮아요. 지금의 컨디션에 맞춰 편하게 쉬어가세요.").font(.subheadline).foregroundStyle(.secondary)
                        if booking.attendance == .reserved {
                            primary("조용히 체크인") {
                                if store.transition(bookingID, to: .checkedIn) { sheet = .checkIn }
                            }
                        } else if booking.attendance == .checkedIn {
                            primary("조용히 퇴실하기") {
                                if store.transition(bookingID, to: .checkedOut) { sheet = .checkOut }
                            }
                        } else {
                            primary(booking.rating == 0 ? "후기작성" : "후기 수정") { sheet = .review }
                        }
                        Toggle("침묵 모드 유지", isOn: $silentMode).tint(Theme.accent)
                        Text("말하지 않아도 버튼 한 번으로 출석을 확인해요").font(.subheadline)
                        Text("데모 체크인은 이 기기에만 기록되며 강사에게 알림을 보내지 않습니다.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }.padding(24).frame(maxWidth: 480).frame(maxWidth: .infinity)
                }
                .sheet(item: $sheet, onDismiss: {
                    if returnHomeAfterDismiss { returnHomeAfterDismiss = false; returnHome() }
                    else if openReviewAfterDismiss { openReviewAfterDismiss = false; sheet = .review }
                }) { value in
                    if value == .review {
                        ExerciseReviewView(booking: booking, onSave: { rating, reflection in
                            store.saveReview(bookingID, text: reflection.summary, rating: rating, reflection: reflection)
                            returnHomeAfterDismiss = true
                            sheet = nil
                        }, onSkip: { returnHomeAfterDismiss = true; sheet = nil })
                    } else {
                        AttendanceResultView(booking: booking, isCheckout: value == .checkOut,
                            onConfirm: { sheet = nil },
                            onReview: { openReviewAfterDismiss = true; sheet = nil })
                    }
                }
            } else { Text("예약 정보를 찾을 수 없어요.") }
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("예약 확인").navigationBarTitleDisplayMode(.inline)
    }

    private var progress: Double { Double(store.bookings.filter { $0.attendance == .checkedOut }.count) / Double(max(store.bookings.count, 1)) }

    private func primary(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.body.weight(.medium)).frame(maxWidth: .infinity, minHeight: 52)
                .foregroundStyle(.white).background(Theme.accent, in: Capsule())
        }.buttonStyle(.plain)
    }
}

private struct AttendanceBadge: View {
    let status: Attendance
    var body: some View {
        Text(status.title).font(.caption2).fixedSize()
            .foregroundStyle(status == .reserved ? Color.secondary : Color(red: 153/255, green: 70/255, blue: 42/255))
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(status == .reserved ? Theme.surface : Color(red: 254/255, green: 149/255, blue: 114/255).opacity(0.2), in: Capsule())
    }
}

struct AttendanceResultView: View {
    let booking: WellnessBooking
    let isCheckout: Bool
    let onConfirm: () -> Void
    let onReview: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                VStack(spacing: 8) {
                    Text(isCheckout ? "조용히 퇴실하기" : "조용히 체크인 완료").font(.title2.bold())
                    Text(isCheckout ? "오늘은 여기까지 해도 괜찮아요." : "체크인이 완료되었어요.\n천천히 준비해도 괜찮아요.")
                        .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center).lineSpacing(4)
                }
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(booking.title).font(.body.weight(.medium))
                        Text(booking.venue).font(.footnote).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    AttendanceBadge(status: isCheckout ? .checkedOut : .checkedIn)
                }
                .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.background, in: RoundedRectangle(cornerRadius: 16))
                HStack(spacing: 12) {
                    Button(action: onConfirm) {
                        Text("확인").frame(maxWidth: .infinity, minHeight: 52)
                            .foregroundStyle(isCheckout ? Theme.accent : .white)
                            .background(isCheckout ? Theme.surface : Theme.accent, in: Capsule())
                    }
                    if isCheckout {
                        Button(action: onReview) {
                            Text("후기작성").frame(maxWidth: .infinity, minHeight: 52)
                                .foregroundStyle(.white).background(Theme.accent, in: Capsule())
                        }
                    }
                }.buttonStyle(.plain).padding(.top, 16)
            }.padding(.horizontal, 24).padding(.top, 42).padding(.bottom, 24)
        }
        .presentationDetents([.height(isCheckout ? 370 : 400), .large])
        .presentationDragIndicator(.visible)
    }
}


struct HomeView_Previews: PreviewProvider {
    static var previews: some View { HomeView().preferredColorScheme(.light) }
}
