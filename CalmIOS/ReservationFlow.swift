import SwiftUI
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

extension DiscoveryProgram {
    static let yoga = DiscoveryProgram(id: "small-group-yoga", venue: "마음숲 웰니스 스페이스 3층",
        title: "초보자 소그룹 릴랙스 요가", date: "8월 31일(월)", day: 31, time: "19:00-19:50",
        category: "요가", minutes: 5, kilometers: 0.4, smallGroup: true, reviews: 2, price: 0)
    var isYoga: Bool { category == "요가" }
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
    @State private var programs: [RemoteProgram] = []
    @State private var loading = false
    @State private var loaded = false
    @State private var errorMessage: String?
    @State private var nextCursor: String?
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(programs) { program in
                        NavigationLink(value: program) {
                            HStack(spacing: 16) {
                                RemoteProgramImage(url: program.imageURL).frame(width: 80, height: 80).clipped()
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(program.title).font(AppTypography.font(16, weight: .medium))
                                    Text(program.category).font(AppTypography.font(12)).foregroundStyle(.secondary)
                                    if let date = program.startDate {
                                        Text(date, format: .dateTime.month().day().hour().minute())
                                            .font(AppTypography.font(12)).foregroundStyle(.secondary)
                                    }
                                    Text(program.price == 0 ? "무료" : "\(program.price.formatted())원")
                                        .font(AppTypography.font(13)).foregroundStyle(Theme.accent)
                                }.frame(maxWidth: .infinity, alignment: .leading)
                                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                            }.padding(16).background(.white, in: RoundedRectangle(cornerRadius: 8))
                        }.buttonStyle(.plain)
                    }
                    if loading { ProgressView().padding().accessibilityLabel("프로그램 불러오는 중") }
                    if let errorMessage {
                        Text(errorMessage).foregroundStyle(.secondary)
                        Button("다시 시도") { Task { await load(reset: programs.isEmpty) } }
                    } else if loaded && programs.isEmpty && nextCursor == nil {
                        Text("등록된 프로그램이 아직 없어요.").foregroundStyle(.secondary).padding(.vertical, 48)
                    }
                    if nextCursor != nil && !loading && errorMessage == nil {
                        Button("더 보기") { Task { await load(reset: false) } }
                    }
                }.padding(24).frame(maxWidth: 600).frame(maxWidth: .infinity)
            }.background(Theme.background.ignoresSafeArea())
                .navigationTitle("프로그램").navigationBarTitleDisplayMode(.inline)
                .navigationDestination(for: RemoteProgram.self) { RemoteProgramDetailView(program: $0) }
                .refreshable { await load(reset: true) }
                .task { if !loaded { await load(reset: true) } }
        }
    }

    @MainActor private func load(reset: Bool) async {
        guard !loading else { return }
        loading = true
        errorMessage = nil
        defer { loading = false }
        #if DEBUG && targetEnvironment(simulator)
        do {
            let page = try await APIService.shared.getPrograms(after: reset ? nil : nextCursor)
            try Task.checkCancellation()
            if reset { programs = page.programs }
            else {
                let ids = Set(programs.map(\.id))
                programs += page.programs.filter { !ids.contains($0.id) }
            }
            nextCursor = page.nextCursor
            loaded = true
        } catch is CancellationError {
        } catch {
            errorMessage = "프로그램을 불러오지 못했어요. 연결을 확인해 주세요."
        }
        #else
        errorMessage = "현재 환경에서는 프로그램 서버에 연결할 수 없어요."
        #endif
    }
}

private struct RemoteProgramImage: View {
    let url: String?
    var body: some View {
        AsyncImage(url: url.flatMap(URL.init(string:))) { image in
            image.resizable().scaledToFill()
        } placeholder: {
            ZStack {
                Theme.surface
                Image(systemName: "figure.mind.and.body").font(.title).foregroundStyle(Theme.accent)
            }
        }.accessibilityHidden(true)
    }
}

struct RemoteProgramDetailView: View {
    let program: RemoteProgram
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if program.imageURL != nil {
                    RemoteProgramImage(url: program.imageURL).frame(height: 220).clipped()
                }
                VStack(alignment: .leading, spacing: 16) {
                    Text(program.title).font(AppTypography.font(24, weight: .bold))
                    Text(program.category).foregroundStyle(Theme.accent)
                    if let date = program.startDate {
                        Label { Text(date, format: .dateTime.year().month().day().hour().minute()) } icon: {
                            Image(systemName: "calendar")
                        }
                    }
                    Text("예약 인원 \(program.reservedCount)/\(program.capacity)명")
                    Text(program.price == 0 ? "무료" : "\(program.price.formatted())원")
                    Text(program.description).fixedSize(horizontal: false, vertical: true)
                }.padding(.horizontal, 24)
            }.padding(.bottom, 24).frame(maxWidth: 600).frame(maxWidth: .infinity)
        }.background(Theme.background.ignoresSafeArea())
            .navigationTitle("프로그램 상세").navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                Text("예약 준비 중").font(AppTypography.font(16, weight: .medium))
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .foregroundStyle(.secondary).background(Theme.surface, in: Capsule()).padding(24)
                    .background(Theme.background)
            }
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
        }.foregroundStyle(.secondary).padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.background, in: RoundedRectangle(cornerRadius: 16))
    }
}

struct ProgramDetailView: View {
    let program: DiscoveryProgram
    @ObservedObject var store: WellnessStore
    @State private var completed = false
    @State private var newest = true
    @Environment(\.dismiss) private var dismiss
    private let muted = Color(red: 113/255, green: 121/255, blue: 115/255)
    private let iconTint = Color(red: 80/255, green: 115/255, blue: 99/255)
    private var active: Bool { store.booking(program.id).map { !$0.isCancelled } ?? false }
    private var isReferenceProgram: Bool { program.id == DiscoveryProgram.yoga.id }
    private var reviews: [WellnessBooking] {
        store.bookings.filter { $0.id == program.id && $0.rating > 0 }.sorted {
            let left = $0.reviewedAt ?? .distantPast
            let right = $1.reviewedAt ?? .distantPast
            return newest ? left > right : left < right
        }
    }
    private let sampleReview = "요가를 처음 해봐서 동작을 못 따라갈까 걱정했는데, 어려운 동작은 하지 않아도 된다고 먼저 안내해 주셔서 마음이 편했어요. 사람도 많지 않고 다른 참여자와 이야기할 일이 거의 없어서 제 동작에만 집중할 수 있었어요."

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if program.isYoga {
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
                                    if program.isYoga {
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
                        if program.isYoga {
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
                reservationAction.padding(.horizontal, 24).padding(.top, 56).padding(.bottom, 30)
            }.frame(maxWidth: 600).frame(maxWidth: .infinity)
        }
        .font(AppTypography.font(11, relativeTo: .caption))
        .foregroundStyle(Theme.ink)
        .background(Color(.systemBackground))
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .toolbarBackground(Color(.systemBackground), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("운동 후기").font(AppTypography.font(16, weight: .medium))
            }
            ToolbarItem(placement: .topBarLeading) {
                Button { dismiss() } label: {
                    asset("DetailContainer", width: 16, height: 16).frame(width: 44, height: 44)
                }.accessibilityLabel("뒤로 가기")
            }
        }
        .toolbar(.hidden, for: .tabBar)
        .navigationDestination(isPresented: $completed) {
            ReservationSuccessView(bookingID: program.id, store: store)
        }
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(program.title).font(AppTypography.font(20, weight: .bold, relativeTo: .title3))
                        .fixedSize(horizontal: false, vertical: true)
                    Text(isReferenceProgram ? "마을숲 웰니스 스페이스 3층 (역삼역 4번 출구 · 도보 5분)" : program.venue)
                        .foregroundStyle(muted).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                if isReferenceProgram {
                    HStack(spacing: 6) {
                        asset("DetailGroup44", width: 8.247, height: 10)
                        Text("3/5").font(AppTypography.font(11, weight: .semibold))
                    }.padding(.horizontal, 11).padding(.vertical, 4)
                        .background(Theme.mint.opacity(0.6), in: Capsule())
                        .foregroundStyle(Theme.accent).fixedSize().padding(.top, 3)
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                metadata("시간", isReferenceProgram ? "8월 31일(월) 오후 7:00 ~ 7:50 (50분)" : "\(program.date) \(program.time)")
                metadata("강사", program.isYoga ? "이지원 선생님" : "기관 문의")
            }
        }
    }

    private var reviewSection: some View {
        VStack(spacing: 24) {
            HStack(spacing: 6) {
                Text("리뷰").font(AppTypography.font(16, weight: .bold))
                Text("\(reviews.count + (isReferenceProgram ? 2 : 0))건")
                    .font(AppTypography.font(13)).foregroundStyle(Theme.accent)
                Spacer()
                Menu {
                    Button("최신순") { newest = true }
                    Button("오래된순") { newest = false }
                } label: {
                    HStack(spacing: 4) {
                        Text(newest ? "최신순" : "오래된순")
                        asset("DetailIcon", width: 8, height: 4.933)
                    }.foregroundStyle(muted).frame(minHeight: 44)
                }
            }.padding(.leading, 12).padding(.trailing, 8)
            VStack(spacing: 16) {
                if !newest { sampleReviews }
                ForEach(reviews) { review in
                    ReviewBody(rating: review.rating, text: review.review, date: review.reviewedAt)
                }
                if newest { sampleReviews }
                if reviews.isEmpty && !isReferenceProgram {
                    Text("아직 작성된 리뷰가 없어요.").foregroundStyle(muted)
                }
            }.padding(.horizontal, 8)
        }
    }

    @ViewBuilder private var sampleReviews: some View {
        if isReferenceProgram {
            ForEach(0..<2) { index in
                if index > 0 {
                    Image("DetailLine4").resizable().frame(maxWidth: .infinity).frame(height: 1)
                }
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 6) {
                        asset("DetailFrame90", width: 77, height: 13)
                        Text("4.0").font(AppTypography.font(11, weight: .semibold)).foregroundStyle(Theme.accent)
                        Spacer()
                        Text("작성일자 2026.8.15").font(AppTypography.font(9)).foregroundStyle(muted)
                    }
                    Text(sampleReview).foregroundStyle(muted).lineSpacing(5)
                        .fixedSize(horizontal: false, vertical: true)
                }.padding(.horizontal, 4).accessibilityHint("디자인 예시 후기")
            }
        }
    }

    private var reservationAction: some View {
        Group {
            if active {
                NavigationLink {
                    ReservationSummaryView(bookingID: program.id, store: store)
                } label: { reservationLabel("예약 확인") }
            } else {
                Button { store.reserve(program); completed = store.booking(program.id) != nil } label: {
                    reservationLabel(store.schedulesEnabled ? "예약" : "의료 데이터 등록 후 예약할 수 있어요")
                }.disabled(!store.schedulesEnabled)
            }
        }.buttonStyle(.plain)
    }

    private func reservationLabel(_ text: String) -> some View {
        Text(text).font(AppTypography.font(16, weight: .medium)).foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 56).background(Theme.accent, in: Capsule())
    }
    private func metadata(_ title: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Text(title).foregroundStyle(muted)
            Text(value).foregroundStyle(Theme.ink.opacity(0.8)).fixedSize(horizontal: false, vertical: true)
        }
    }
    private func badge(_ text: String) -> some View {
        Text(text).font(AppTypography.font(11, weight: .medium)).foregroundStyle(muted)
            .padding(.horizontal, 12).padding(.vertical, 4)
            .background(Color(.systemBackground).opacity(0.95), in: Capsule())
    }
    private func asset(_ name: String, width: CGFloat, height: CGFloat) -> some View {
        Image(name).resizable().scaledToFit().frame(width: width, height: height).accessibilityHidden(true)
    }
    private func separator(_ name: String) -> some View {
        Image(name).resizable().frame(width: 36, height: 1)
            .rotationEffect(.degrees(90)).frame(width: 1, height: 36).accessibilityHidden(true)
    }
    private func metric<Icon: View>(_ title: String, value: String, @ViewBuilder icon: () -> Icon) -> some View {
        VStack(spacing: 8) {
            icon().frame(height: 38)
            VStack(spacing: 2) {
                Text(title).foregroundStyle(muted)
                Text(value).font(AppTypography.font(9, weight: .medium)).foregroundStyle(Theme.accent.opacity(0.6))
                    .padding(.horizontal, 10).padding(.vertical, 2)
                    .background(Theme.mint.opacity(0.6), in: Capsule())
            }
        }.frame(maxWidth: .infinity)
    }
    private func facility(_ name: String, _ title: String, width: CGFloat, height: CGFloat) -> some View {
        VStack(spacing: 12) {
            asset(name, width: width, height: height).frame(height: 38, alignment: .bottom)
            Text(title).foregroundStyle(muted).fixedSize(horizontal: false, vertical: true)
        }.frame(maxWidth: .infinity)
    }
    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 5) {
            Text("•")
            Text(text).fixedSize(horizontal: false, vertical: true)
        }.foregroundStyle(muted)
    }
    private func infoSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(AppTypography.font(13, weight: .semibold)).padding(.horizontal, 4)
            content()
        }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.background, in: RoundedRectangle(cornerRadius: 24))
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
                            Text(booking.isCancelled ? "예약이 취소되었습니다." : booking.attendance == .checkedOut ? "참여가 완료되었습니다." : booking.attendance == .checkedIn ? "체크인되었습니다." : "예약이 확정되었습니다.")
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
                            Text(booking.displayProgram.isYoga ? "강사   이지원 선생님" : "강사   기관 문의")
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
    let booking: WellnessBooking
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
                    Text(booking.title).fontWeight(.semibold)
                    Text("\(booking.dateLabel) \(booking.time)").foregroundStyle(.secondary)
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
                HStack {
                    FlowAction(title: "취소", secondary: true) { dismiss() }.frame(maxWidth: 110)
                    FlowAction(title: "확인") { if let reason { onConfirm(reason) } }.disabled(reason == nil).opacity(reason == nil ? 0.4 : 1)
                        .accessibilityLabel("예약 취소 확정")
                }.padding(.top, 16)
            }.font(AppTypography.font(14)).padding(24).padding(.top, 24)
        }.presentationDetents([.large]).presentationDragIndicator(.visible)
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
