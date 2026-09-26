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
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach([DiscoveryProgram.yoga] + DiscoveryProgram.samples) { program in
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
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if let value = program.imageURL, let url = URL(string: value), url.scheme == "https" {
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Theme.surface.overlay(Image(systemName: "figure.mind.and.body").foregroundStyle(Theme.accent))
                    }.frame(height: 222).clipped()
                        .overlay(alignment: .bottomLeading) {
                            HStack(spacing: 4) {
                                detailTag(program.category)
                                detailTag(program.price == 0 ? "무료" : "\(program.price.formatted())원")
                            }.padding(24)
                        }
                }
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .top, spacing: 12) {
                            Text(program.title).font(AppTypography.font(20, weight: .bold))
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Label("\(program.reservedCount)/\(program.capacity)", systemImage: "person.fill")
                                .font(AppTypography.font(11, weight: .semibold)).foregroundStyle(Theme.accent)
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .background(Theme.mint.opacity(0.6), in: Capsule())
                        }
                        if let date = program.startDate {
                            HStack(alignment: .top, spacing: 12) {
                                Text("시간").foregroundStyle(.secondary)
                                Text(date, format: .dateTime.year().month().day().hour().minute())
                            }.font(AppTypography.font(11))
                        }
                        HStack(spacing: 12) {
                            Text("참가비").foregroundStyle(.secondary)
                            Text(program.price == 0 ? "무료" : "\(program.price.formatted())원")
                        }.font(AppTypography.font(11))
                    }.padding(.horizontal, 8)
                    ProgramInfoPanel(title: "운동정보") {
                        HStack(spacing: 0) {
                            remoteMetric("종목", value: program.category, icon: "figure.mind.and.body")
                            Divider().frame(height: 36)
                            remoteMetric("난이도", value: difficultyLabel, icon: "chart.bar.fill")
                            Divider().frame(height: 36)
                            remoteMetric("참여 형태", value: participationLabel, icon: "person.3.fill")
                        }
                    }
                    if !program.description.isEmpty {
                        ProgramInfoPanel(title: "참여안내") {
                            Text(program.description).font(AppTypography.font(11)).lineSpacing(5)
                                .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }.padding(24)
            }.frame(maxWidth: 600).frame(maxWidth: .infinity)
        }.background(Color.white.ignoresSafeArea())
            .navigationTitle("프로그램 상세").navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden()
            .toolbarBackground(.white, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar { ToolbarItem(placement: .topBarLeading) {
                Button { dismiss() } label: { Image(systemName: "chevron.left") }
                    .tint(Theme.accent).accessibilityLabel("뒤로 가기")
            } }
            .toolbar(.hidden, for: .tabBar)
            .safeAreaInset(edge: .bottom) {
                Text("예약 기능 준비 중").font(AppTypography.font(16, weight: .medium))
                    .foregroundStyle(.white).frame(maxWidth: .infinity, minHeight: 56)
                    .background(Theme.accent.opacity(0.5), in: Capsule())
                    .padding(24).background(.white)
            }
    }
    private var difficultyLabel: String {
        ["BEGINNER": "초보자", "INTERMEDIATE": "중급", "ADVANCED": "고급"][program.difficulty.uppercased()] ?? program.difficulty
    }
    private var participationLabel: String {
        ["SMALL_GROUP": "소모임", "GROUP": "그룹", "INDIVIDUAL": "개인", "ONE_ON_ONE": "일대일"][program.participationType.uppercased()] ?? program.participationType
    }
    private func detailTag(_ title: String) -> some View {
        Text(title).font(AppTypography.font(11, weight: .medium)).foregroundStyle(.secondary)
            .padding(.horizontal, 12).padding(.vertical, 4).background(.white, in: Capsule())
    }
    private func remoteMetric(_ title: String, value: String, icon: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 28)).frame(height: 40)
                .foregroundStyle(Color(red: 80/255, green: 115/255, blue: 99/255))
            Text(title).font(AppTypography.font(11)).foregroundStyle(.secondary)
            Text(value.isEmpty ? "미등록" : value).font(AppTypography.font(9, weight: .medium))
                .foregroundStyle(Theme.accent).padding(.horizontal, 10).padding(.vertical, 2)
                .background(Theme.mint.opacity(0.6), in: Capsule())
        }.multilineTextAlignment(.center).frame(maxWidth: .infinity)
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
    private var existing: WellnessBooking? { store.booking(program.id) }
    private var active: Bool { existing != nil && existing?.isCancelled == false }
    private var reviews: [WellnessBooking] {
        let values = store.bookings.filter { $0.id == program.id && $0.rating > 0 }
        return newest ? Array(values.reversed()) : values
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

struct RemoteReservationDetailView: View {
    let reservation: RemoteReservation
    let onChanged: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var isCancelling = false
    @State private var showCancelConfirmation = false
    @State private var showError = false
    @State private var errorMessage = ""

    private var program: RemoteProgram? {
        reservation.program
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                statusCard

                VStack(alignment: .leading, spacing: 10) {
                    Text(program?.title ?? "프로그램")
                        .font(AppTypography.font(22, weight: .bold, relativeTo: .title2))

                    if let category = program?.category {
                        Text(category)
                            .font(AppTypography.font(12, weight: .medium))
                            .foregroundStyle(Theme.accent)
                    }
                }

                VStack(alignment: .leading, spacing: 16) {
                    if let startDate = program?.startDate {
                        detailRow(
                            title: "일시",
                            value: startDate.formatted(
                                .dateTime
                                    .year()
                                    .month()
                                    .day()
                                    .hour()
                                    .minute()
                            )
                        )
                    }

                    if let program {
                        detailRow(
                            title: "참여 형태",
                            value: program.participationType
                        )

                        detailRow(
                            title: "난이도",
                            value: program.difficulty
                        )

                        detailRow(
                            title: "가격",
                            value: program.price == 0
                                ? "무료"
                                : "\(program.price.formatted())원"
                        )
                    }

                    detailRow(
                        title: "예약 상태",
                        value: reservation.status == "RESERVED"
                            ? "예약 확정"
                            : "예약 취소"
                    )
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    .white,
                    in: RoundedRectangle(cornerRadius: 20)
                )
            }
            .padding(24)
            .frame(maxWidth: 600)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("예약 확인")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            if reservation.status == "RESERVED" {
                FlowAction(
                    title: isCancelling ? "취소 중..." : "예약 취소"
                ) {
                    showCancelConfirmation = true
                }
                .disabled(isCancelling)
                .opacity(isCancelling ? 0.6 : 1)
                .padding(24)
                .background(Theme.background)
            }
        }
        .confirmationDialog(
            "예약을 취소하시겠어요?",
            isPresented: $showCancelConfirmation,
            titleVisibility: .visible
        ) {
            Button("예약 취소", role: .destructive) {
                Task {
                    await cancelReservation()
                }
            }

            Button("닫기", role: .cancel) {}
        } message: {
            Text("취소하면 해당 프로그램의 예약이 취소됩니다.")
        }
        .alert("예약 취소 실패", isPresented: $showError) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    private var statusCard: some View {
        HStack {
            Image(
                systemName:
                    reservation.status == "RESERVED"
                    ? "checkmark.circle.fill"
                    : "xmark.circle.fill"
            )
            .foregroundStyle(
                reservation.status == "RESERVED"
                ? Theme.accent
                : .secondary
            )

            Text(
                reservation.status == "RESERVED"
                ? "예약이 확정되었습니다."
                : "예약이 취소되었습니다."
            )
            .font(AppTypography.font(14, weight: .semibold))

            Spacer()
        }
        .padding(16)
        .background(
            Theme.mint.opacity(0.5),
            in: RoundedRectangle(cornerRadius: 16)
        )
    }

    private func detailRow(title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Text(title)
                .font(AppTypography.font(13, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .leading)

            Text(value.isEmpty ? "-" : value)
                .font(AppTypography.font(13))
                .foregroundStyle(.primary)

            Spacer()
        }
    }

    @MainActor
    private func cancelReservation() async {
        guard !isCancelling else {
            return
        }

        isCancelling = true

        defer {
            isCancelling = false
        }

        do {
            try await APIService.shared.cancelReservation(
                programId: reservation.programId
            )

            onChanged()
            dismiss()
        } catch let error as APIError {
            errorMessage = error.userMessage
            showError = true
        } catch {
            errorMessage = "예약을 취소하지 못했어요."
            showError = true
        }
    }
}
