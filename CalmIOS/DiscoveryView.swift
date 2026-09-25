import SwiftUI
import FirebaseAuth
import MapKit

struct ExerciseReflection: Codable, Equatable {
    var feeling = ""
    var intensity = ""
    var atmosphere: Set<String> = []
    var nextActivity = ""
    var complete: Bool { !feeling.isEmpty && !intensity.isEmpty && !atmosphere.isEmpty && !nextActivity.isEmpty }
    var summary: String { ([feeling, intensity] + atmosphere.sorted() + [nextActivity]).filter { !$0.isEmpty }.joined(separator: " · ") }
}

struct ProgramLocation: Codable, Hashable {
    let latitude: Double
    let longitude: Double
    func kilometers(to other: Self) -> Double {
        CLLocation(latitude: latitude, longitude: longitude)
            .distance(from: CLLocation(latitude: other.latitude, longitude: other.longitude)) / 1000
    }
}

struct DiscoveryProgram: Identifiable, Codable, Hashable {
    let id: String
    let venue: String
    let title: String
    let date: String
    let day: Int
    let time: String
    let category: String
    let minutes: Int
    let kilometers: Double
    let smallGroup: Bool
    let reviews: Int
    let price: Int
    var location: ProgramLocation? = nil

    static let samples: [Self] = [
        .init(id: "discovery-stretch", venue: "늘푸른 복지관", title: "마음 이완 슬로우 스트레칭", date: "8월 12일(화)", day: 12, time: "14:00-14:50", category: "스트레칭", minutes: 8, kilometers: 0.6, smallGroup: false, reviews: 12, price: 0, location: ProgramLocation(latitude: 37.5728, longitude: 126.9768)),
        .init(id: "discovery-walk", venue: "희망근린공원 솔숲 데크길", title: "말없이 걷는 숲길 명상 보행", date: "8월 23일(토)", day: 23, time: "10:00-10:45", category: "걷기", minutes: 15, kilometers: 1.1, smallGroup: true, reviews: 4, price: 0, location: ProgramLocation(latitude: 37.5704, longitude: 126.9896)),
        .init(id: "discovery-swim", venue: "시민건강체육센터", title: "따뜻한 물에서 하는 아쿠아 릴랙스", date: "8월 29일(금)", day: 29, time: "11:00-12:00", category: "수영", minutes: 18, kilometers: 1.4, smallGroup: false, reviews: 6, price: 0, location: ProgramLocation(latitude: 37.5627, longitude: 126.9828))
    ]
}

enum DiscoveryFilter: String, CaseIterable { case recommended = "맞춤 추천", nearby = "주변 프로그램", category = "종목별", venue = "기관별", group = "인원", free = "무료", paid = "유료" }
enum ProgramSort: String, CaseIterable { case distance = "거리순", date = "일정순", reviews = "후기순" }

struct DiscoveryQuery {
    var text = ""
    var filter: DiscoveryFilter = .recommended
    var radius = 1.5
    var category = "전체"
    var venue = "전체"
    var smallGroupOnly = false
    var sort: ProgramSort = .date
    var center: ProgramLocation?

    func distance(to program: DiscoveryProgram) -> Double? {
        guard let center, let location = program.location else { return nil }
        return center.kilometers(to: location)
    }

    func results(_ programs: [DiscoveryProgram]) -> [DiscoveryProgram] {
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return programs.filter { item in
            let matches = query.isEmpty || (item.title + " " + item.venue + " " + item.category).localizedCaseInsensitiveContains(query)
            guard matches else { return false }
            if center != nil {
                guard let distance = distance(to: item), distance <= radius else { return false }
            }
            switch filter {
            case .recommended: return true
            case .nearby: return center != nil || radius >= 3 || item.kilometers <= radius
            case .category: return category == "전체" || category == item.category
            case .venue: return venue == "전체" || venue == item.venue
            case .group: return !smallGroupOnly || item.smallGroup
            case .free: return item.price == 0
            case .paid: return item.price > 0
            }
        }.sorted { lhs, rhs in
            switch sort {
            case .distance:
                let left = distance(to: lhs) ?? lhs.kilometers
                let right = distance(to: rhs) ?? rhs.kilometers
                return left == right ? lhs.id < rhs.id : left < right
            case .date: return lhs.day == rhs.day ? lhs.id < rhs.id : lhs.day < rhs.day
            case .reviews: return lhs.reviews == rhs.reviews ? lhs.id < rhs.id : lhs.reviews > rhs.reviews
            }
        }
    }
}

private struct ReturnHomeKey: EnvironmentKey { static let defaultValue: () -> Void = {} }
extension EnvironmentValues {
    var returnHome: () -> Void {
        get { self[ReturnHomeKey.self] }
        set { self[ReturnHomeKey.self] = newValue }
    }
}

struct DiscoveryView: View {
    @ObservedObject var store: WellnessStore
    @State private var showPrograms = false
    var body: some View {
        VStack(spacing: 0) {
            Picker("탐색 대상", selection: $showPrograms) {
                Text("기관").tag(false)
                Text("프로그램").tag(true)
            }.pickerStyle(.segmented).padding(.horizontal, 24).padding(.vertical, 8)
            if showPrograms { ProgramDiscoveryView(store: store) }
            else { FacilityDiscoveryView() }
        }
    }
}

private struct ProgramDiscoveryView: View {
    @ObservedObject var store: WellnessStore
    @State private var programs: [RemoteProgram] = []
    @State private var preferences: OnboardingPreferences?
    @State private var conditions: ExerciseConditionsPayload?
    @State private var loading = false
    @State private var loadError: String?
    @State private var nextCursor: String?
    @State private var query = DiscoveryQuery()
    @StateObject private var placeSearch = DiscoveryPlaceSearch()
    @FocusState private var searchFocused: Bool
    @State private var searchRevision = 0
    @State private var selectedArea = ""
    private var hasPlaceQuery: Bool { !query.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    private var results: [RemoteProgram] {
        programs.filter { program in
            if let center = query.center {
                guard let location = program.location, center.kilometers(to: location) <= query.radius else { return false }
            }
            switch query.filter {
            case .category: return query.category == "전체" || query.category == program.category
            case .venue: return query.venue == "전체" || query.venue == program.facilityId
            case .group: return !query.smallGroupOnly || program.participationType == "SMALL_GROUP"
            case .free: return program.price == 0
            case .paid: return program.price > 0
            default: return true
            }
        }.sorted { left, right in
            if query.filter == .recommended {
                let a = left.matchScore(preferences: preferences, conditions: conditions)
                let b = right.matchScore(preferences: preferences, conditions: conditions)
                if a != b { return a > b }
            }
            if query.sort == .distance, let center = query.center {
                let a = left.location.map { center.kilometers(to: $0) } ?? .infinity
                let b = right.location.map { center.kilometers(to: $0) } ?? .infinity
                if a != b { return a < b }
            }
            return left.startAt == right.startAt ? left.id < right.id : left.startAt < right.startAt
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(spacing: 16) {
                    HStack(spacing: 8) {
                        SafeAssetImage(name: "SearchIcon", fallback: "magnifyingglass").frame(width: 18, height: 18)
                        TextField("원하시는 지역을 검색해보세요.", text: $query.text)
                            .font(.subheadline).submitLabel(.search).accessibilityLabel("지역, 주소 또는 장소 검색")
                            .focused($searchFocused)
                            .onSubmit { searchFocused = false; searchRevision += 1 }
                        if !query.text.isEmpty {
                            Button { query.text = "" } label: { Image(systemName: "xmark.circle.fill") }
                                .accessibilityLabel("검색어 지우기")
                        }
                    }.padding(16).frame(minHeight: 56).background(Theme.background, in: RoundedRectangle(cornerRadius: 16))
                    if !hasPlaceQuery {
                    if query.center != nil {
                        HStack {
                            Button { query.text = selectedArea; searchFocused = true } label: {
                                Label(selectedArea, systemImage: "mappin.and.ellipse").lineLimit(2)
                            }.buttonStyle(.plain).foregroundStyle(Theme.accent)
                            Spacer()
                            Button { query.center = nil; selectedArea = ""; query.radius = 1.5; query.sort = .date } label: { Image(systemName: "xmark.circle.fill") }
                                .accessibilityLabel("선택 지역 해제")
                        }.font(.subheadline)
                    }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(DiscoveryFilter.allCases, id: \.self) { filter in
                                Button { query.filter = filter } label: {
                                    Text(filter.rawValue).font(.footnote).padding(.horizontal, 16).frame(minHeight: 40)
                                        .background(query.filter == filter ? Theme.mint.opacity(0.6) : Theme.background, in: Capsule())
                                        .overlay(Capsule().strokeBorder(query.filter == filter ? Theme.accent.opacity(0.5) : .clear))
                                }.buttonStyle(.plain).accessibilityAddTraits(query.filter == filter ? .isSelected : [])
                            }
                        }
                    }
                    if query.filter == .nearby || query.center != nil {
                        VStack(spacing: 12) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(query.center == nil ? "지역을 검색해 주세요" : "선택 지역 기준 거리").font(.headline)
                                Spacer()
                                Text(query.center == nil && query.radius >= 3 ? "3km+" : String(format: "%.1fkm", query.radius))
                                    .font(.footnote).foregroundStyle(Theme.accent)
                            }
                            Slider(value: $query.radius, in: 0.5...(query.center == nil ? 3 : 10), step: 0.1).tint(Theme.accent)
                                .accessibilityLabel("거리 범위").accessibilityValue(String(format: "%.1f 킬로미터", query.radius))
                            HStack { Text("500m"); Spacer(); Text(query.center == nil ? "1.5km" : "5km"); Spacer(); Text(query.center == nil ? "3km+" : "10km") }.font(.caption2).foregroundStyle(.secondary)
                            Text(query.center == nil ? "" : "등록된 위치 기준 · 직선거리")
                                .font(.caption2).foregroundStyle(.secondary)
                        }.padding(16).background(Theme.surface, in: RoundedRectangle(cornerRadius: 20))
                    }
                    if query.filter == .category {
                        Picker("종목", selection: $query.category) {
                            Text("전체").tag("전체")
                            ForEach(Array(Set(programs.map(\.category))).sorted(), id: \.self) { Text($0).tag($0) }
                        }.pickerStyle(.menu).frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if query.filter == .venue {
                        Picker("기관", selection: $query.venue) {
                            Text("전체").tag("전체")
                            ForEach(Array(Set(programs.map(\.facilityId))).filter { !$0.isEmpty }.sorted(), id: \.self) { Text($0).tag($0) }
                        }.pickerStyle(.menu).frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if query.filter == .group {
                        Picker("참여 인원", selection: $query.smallGroupOnly) {
                            Text("전체").tag(false)
                            Text("소그룹").tag(true)
                        }.pickerStyle(.segmented)
                    }
                    }
                }.padding(24).background(.white)
                if hasPlaceQuery {
                    DiscoveryMapResults(search: placeSearch, retry: { searchRevision += 1 }, select: { searchFocused = false }, usePlace: { place in
                        selectedArea = place.title
                        query.center = ProgramLocation(latitude: place.coordinate.latitude, longitude: place.coordinate.longitude)
                        query.filter = .nearby
                        query.sort = .distance
                        query.radius = 3
                        query.text = ""
                        searchFocused = false
                    })
                } else {
                ScrollView {
                    VStack(spacing: 12) {
                        HStack {
                            Text(query.center == nil ? "추천 운동" : "주변 프로그램").font(AppTypography.font(16, weight: .bold))
                            Text("\(results.count)건").font(.footnote).foregroundStyle(Theme.accent)
                            Spacer()
                            Picker("정렬", selection: $query.sort) {
                                Text("일정순").tag(ProgramSort.date)
                                if query.center != nil { Text("거리순").tag(ProgramSort.distance) }
                            }.pickerStyle(.menu).font(.caption)
                        }
                        ForEach(results) { program in
                            NavigationLink(value: program) {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text(program.title).font(AppTypography.font(16, weight: .medium))
                                    Text(program.category).font(AppTypography.font(12)).foregroundStyle(Theme.accent)
                                    if let date = program.startDate {
                                        Text(date, format: .dateTime.month().day().hour().minute()).font(AppTypography.font(12))
                                    }
                                    Text(program.price == 0 ? "무료" : "\(program.price.formatted())원").font(AppTypography.font(13))
                                }.frame(maxWidth: .infinity, alignment: .leading).padding(20)
                                    .background(.white, in: RoundedRectangle(cornerRadius: 8))
                            }.buttonStyle(.plain)
                        }
                        if loading { ProgressView().padding() }
                        if let loadError {
                            Text(loadError).foregroundStyle(.secondary)
                            Button("다시 시도") { Task { await loadPrograms(reset: true) } }
                        }
                        if nextCursor != nil && !loading {
                            Button("더 보기") { Task { await loadPrograms(reset: false) } }
                        }
                        if results.isEmpty && !loading && loadError == nil {
                            VStack(spacing: 12) {
                                Text(query.center == nil ? "조건에 맞는 활동이 없어요." : "선택한 지역과 거리 안에 등록된 프로그램이 없어요.")
                                    .foregroundStyle(.secondary).multilineTextAlignment(.center)
                                if query.center != nil {
                                    Button("다른 지역 검색") { query.text = selectedArea; searchFocused = true }
                                }
                                Button("필터 초기화") { let center = query.center; query = DiscoveryQuery(); query.center = center; if center != nil { query.radius = 3; query.filter = .nearby } }
                            }.padding(.vertical, 40)
                        }
                    }.padding(24)
                }.refreshable { await loadPrograms(reset: true) }
                }
            }
            .frame(maxWidth: 600).frame(maxWidth: .infinity)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("탐색").navigationBarTitleDisplayMode(.inline)
            .task { await loadPrograms(reset: true) }
            .onChange(of: query.text) { _ in placeSearch.cancel() }
            .task(id: "\(query.text)|\(searchRevision)") {
                let text = query.text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { placeSearch.reset(); return }
                do { try await Task.sleep(nanoseconds: 450_000_000) } catch { return }
                await placeSearch.search(text)
            }
            .onDisappear { placeSearch.cancel() }
            .navigationDestination(for: RemoteProgram.self) { RemoteProgramDetailView(program: $0) }
        }
    }

    @MainActor private func loadPrograms(reset: Bool) async {
        guard !loading else { return }
        loading = true
        loadError = nil
        defer { loading = false }
        #if DEBUG && targetEnvironment(simulator)
        do {
            if reset {
                preferences = nil
                conditions = nil
                if Auth.auth().currentUser != nil {
                    let data = try await APIService.shared.getMyProfile()
                    preferences = try OnboardingPreferences.decodeResponse(data)
                    conditions = try ExerciseConditionsPayload.decodeResponse(data)
                }
            }
            let page = try await APIService.shared.getPrograms(after: reset ? nil : nextCursor)
            try Task.checkCancellation()
            if reset { programs = page.programs }
            else {
                let ids = Set(programs.map(\.id))
                programs += page.programs.filter { !ids.contains($0.id) }
            }
            nextCursor = page.nextCursor
        } catch is CancellationError {
        } catch { loadError = "프로그램과 운동 조건을 불러오지 못했어요. 다시 시도해 주세요." }
        #else
        loadError = "현재 환경에서는 프로그램 서버에 연결할 수 없어요."
        #endif
    }
}

private struct FacilityDiscoveryView: View {
    @State private var search = ""
    @State private var category = ""
    @State private var facilities: [RemoteFacility] = []
    @State private var categories: [String] = []
    @State private var total = 0
    @State private var nextPage: Int?
    @State private var loading = false
    @State private var errorMessage: String?
    @State private var requestID = UUID()
    @State private var center: ProgramLocation?
    @State private var radius = 3.0
    @State private var selected: RemoteFacility?
    @State private var region = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 37.5665, longitude: 126.9780),
        span: MKCoordinateSpan(latitudeDelta: 0.15, longitudeDelta: 0.15))
    private var requestKey: String { "\(search)|\(category)|\(center?.latitude ?? 0)|\(center?.longitude ?? 0)|\(radius)" }
    private var pins: [RemoteFacility] { Array(facilities.filter { $0.location != nil }.prefix(100)) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                        TextField("지역 또는 기관명 검색", text: $search).submitLabel(.search)
                            .autocorrectionDisabled()
                        if !search.isEmpty {
                            Button { search = "" } label: { Image(systemName: "xmark.circle.fill") }
                                .accessibilityLabel("검색어 지우기")
                        }
                    }.padding(14).background(Theme.surface, in: RoundedRectangle(cornerRadius: 8))
                    HStack {
                        Text("서울 기관").font(.headline)
                        Spacer()
                        Picker("종목", selection: $category) {
                            Text("전체 종목").tag("")
                            ForEach(categories, id: \.self) { Text($0).tag($0) }
                        }.pickerStyle(.menu)
                    }
                    Map(coordinateRegion: $region, annotationItems: pins) { facility in
                        MapAnnotation(coordinate: CLLocationCoordinate2D(latitude: facility.latitude!, longitude: facility.longitude!)) {
                            Button { selected = facility } label: {
                                Image(systemName: "mappin.circle.fill").font(.system(size: 28))
                                    .foregroundStyle(Theme.accent).background(.white, in: Circle())
                                    .frame(width: 44, height: 44)
                            }.buttonStyle(.plain).accessibilityLabel(facility.name)
                        }
                    }.frame(height: 230).clipShape(RoundedRectangle(cornerRadius: 8))
                        .accessibilityLabel("기관 위치 지도")
                    HStack {
                        Button {
                            search = ""
                            center = ProgramLocation(latitude: region.center.latitude, longitude: region.center.longitude)
                        } label: { Label("이 지도 주변", systemImage: "scope") }
                        Spacer()
                        if center != nil {
                            Button("지역 해제") { center = nil }
                        }
                    }.font(.subheadline)
                    if center != nil {
                        HStack {
                            Text("반경 \(radius, specifier: "%.1f")km").font(.caption).frame(width: 88, alignment: .leading)
                            Slider(value: $radius, in: 0.5...10, step: 0.5).accessibilityLabel("검색 반경")
                        }
                    }
                    HStack {
                        Text("\(total)곳").font(.headline)
                        Spacer()
                        Text("지도 \(pins.count)곳 표시").font(.caption).foregroundStyle(.secondary)
                    }
                    if let errorMessage {
                        Text(errorMessage).foregroundStyle(.secondary)
                        Button("다시 시도") { Task { await load(page: 0, reset: true) } }
                    }
                    LazyVStack(spacing: 0) {
                        ForEach(facilities) { facility in
                            NavigationLink(value: facility) {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text(facility.name).font(AppTypography.font(16, weight: .medium))
                                        Spacer()
                                        Image(systemName: "chevron.right").font(.caption)
                                    }
                                    Text(facility.facilityType).font(.caption).foregroundStyle(Theme.accent)
                                    Text(facility.address).font(.subheadline).foregroundStyle(.secondary)
                                    if let distance = facility.distanceKm {
                                        Text("직선거리 \(distance, specifier: "%.1f")km").font(.caption).foregroundStyle(.secondary)
                                    }
                                    if facility.location == nil { Text("위치 정보 없음").font(.caption).foregroundStyle(.secondary) }
                                }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 16)
                            }.buttonStyle(.plain)
                            Divider()
                        }
                    }
                    if loading { ProgressView().frame(maxWidth: .infinity).padding() }
                    if !loading && errorMessage == nil && facilities.isEmpty {
                        Text("조건에 맞는 서울 기관이 없어요.").foregroundStyle(.secondary).padding(.vertical, 24)
                    }
                    if let nextPage, !loading && errorMessage == nil {
                        Button("더 보기") { Task { await load(page: nextPage, reset: false) } }
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                }.padding(24).frame(maxWidth: 600).frame(maxWidth: .infinity)
            }.scrollDismissesKeyboard(.interactively)
                .navigationTitle("탐색").navigationBarTitleDisplayMode(.inline)
                .background(Theme.background.ignoresSafeArea())
                .navigationDestination(for: RemoteFacility.self) { FacilityDetailView(facility: $0) }
                .sheet(item: $selected) { facility in
                    NavigationStack {
                        FacilityDetailView(facility: facility)
                            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("닫기") { selected = nil } } }
                    }
                }
                .task(id: requestKey) { await load(page: 0, reset: true, debounce: true) }
                .refreshable { await load(page: 0, reset: true) }
        }
    }

    @MainActor private func load(page: Int, reset: Bool, debounce: Bool = false) async {
        if !reset && loading { return }
        let token = UUID()
        requestID = token
        let key = requestKey
        loading = true
        errorMessage = nil
        if reset { facilities = []; total = 0; nextPage = nil }
        defer { if requestID == token { loading = false } }
        do {
            if debounce { try await Task.sleep(nanoseconds: 350_000_000) }
            #if DEBUG && targetEnvironment(simulator)
            let response = try await APIService.shared.getFacilities(search: search, category: category, center: center, radius: radius, page: page)
            try Task.checkCancellation()
            guard requestID == token, key == requestKey else { return }
            if reset { facilities = response.facilities }
            else {
                let ids = Set(facilities.map(\.id))
                facilities += response.facilities.filter { !ids.contains($0.id) }
            }
            total = response.total
            nextPage = response.nextPage
            categories = response.categories
            if reset && center == nil { fitMap() }
            #else
            throw APIError.serverUnavailable
            #endif
        } catch is CancellationError {
        } catch {
            guard requestID == token, key == requestKey, !Task.isCancelled else { return }
            errorMessage = "기관을 불러오지 못했어요. 서버 연결을 확인해주세요."
        }
    }

    private func fitMap() {
        let locations = pins.compactMap(\.location)
        guard let first = locations.first else { return }
        let minLat = locations.map(\.latitude).min() ?? first.latitude
        let maxLat = locations.map(\.latitude).max() ?? first.latitude
        let minLon = locations.map(\.longitude).min() ?? first.longitude
        let maxLon = locations.map(\.longitude).max() ?? first.longitude
        region = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2),
            span: MKCoordinateSpan(latitudeDelta: max(0.01, (maxLat - minLat) * 1.3), longitudeDelta: max(0.01, (maxLon - minLon) * 1.3)))
    }
}

private struct FacilityDetailView: View {
    let facility: RemoteFacility
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(facility.name).font(AppTypography.font(24, weight: .bold))
                Text(facility.facilityType).foregroundStyle(Theme.accent)
                Label(facility.address, systemImage: "mappin.and.ellipse")
                if !facility.addressDetail.isEmpty { Text(facility.addressDetail).foregroundStyle(.secondary) }
                if !facility.phone.isEmpty { Label(facility.phone, systemImage: "phone") }
                if let location = facility.location {
                    Button {
                        let item = MKMapItem(placemark: MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)))
                        item.name = facility.name
                        item.openInMaps(launchOptions: nil)
                    } label: { Label("지도 앱에서 보기", systemImage: "map") }
                }
                Divider()
                Text("주변 대중교통").font(.headline)
                if facility.nearbyTransit.isEmpty { Text("등록된 교통정보가 없어요.").foregroundStyle(.secondary) }
                ForEach(Array(facility.nearbyTransit.enumerated()), id: \.offset) { _, stop in
                    Label("\(stop.name) · \(stop.mode)", systemImage: stop.mode.contains("버스") ? "bus" : "tram")
                }
                Divider()
                Text("2026년 7월 기준 시설 정보입니다. 현재 운영 여부와 이용 요금은 기관에 확인해주세요.")
                    .font(.footnote).foregroundStyle(.secondary)
                Text("아직 예약 가능한 프로그램이 등록되지 않았어요.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }.padding(24).frame(maxWidth: 600).frame(maxWidth: .infinity, alignment: .leading)
        }.navigationTitle("기관 정보").navigationBarTitleDisplayMode(.inline)
            .background(Theme.background.ignoresSafeArea())
    }
}

private struct DiscoveryPlace: Identifiable {
    let id = UUID()
    let item: MKMapItem
    var coordinate: CLLocationCoordinate2D { item.placemark.coordinate }
    var title: String { item.name ?? "검색한 장소" }
    var address: String { item.placemark.title ?? "주소 정보 없음" }
}

@MainActor
private final class DiscoveryPlaceSearch: ObservableObject {
    @Published var region = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 37.5665, longitude: 126.9780), span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08))
    @Published private(set) var places: [DiscoveryPlace] = []
    @Published private(set) var loading = false
    @Published private(set) var finished = false
    @Published private(set) var error: String?
    @Published private(set) var selectedID: UUID?
    private var request: MKLocalSearch?
    private var generation = UUID()

    func cancel() {
        generation = UUID()
        request?.cancel()
        request = nil
        loading = false
        finished = false
        error = nil
        places = []
        selectedID = nil
    }
    func reset() { cancel() }

    func search(_ text: String) async {
        cancel()
        let token = generation
        loading = true
        let configuration = MKLocalSearch.Request()
        configuration.naturalLanguageQuery = text
        configuration.region = region
        configuration.resultTypes = [.address, .pointOfInterest]
        let operation = MKLocalSearch(request: configuration)
        request = operation
        do {
            let response = try await operation.start()
            guard generation == token, !Task.isCancelled else { return }
            places = response.mapItems.filter { CLLocationCoordinate2DIsValid($0.placemark.coordinate) }.map { DiscoveryPlace(item: $0) }
            if !places.isEmpty {
                selectedID = places.first?.id
                var bounds = response.boundingRegion
                bounds.span.latitudeDelta = max(bounds.span.latitudeDelta, 0.008)
                bounds.span.longitudeDelta = max(bounds.span.longitudeDelta, 0.008)
                region = bounds
            }
        } catch {
            guard generation == token, !Task.isCancelled else { return }
            if let mapError = error as? MKError, mapError.code == .placemarkNotFound {
                places = []
            } else {
                self.error = "장소를 검색하지 못했어요. 인터넷 연결을 확인하고 다시 시도해주세요."
            }
        }
        guard generation == token, !Task.isCancelled else { return }
        loading = false
        finished = true
        request = nil
    }

    func select(_ place: DiscoveryPlace) {
        selectedID = place.id
        region = MKCoordinateRegion(center: place.coordinate, span: MKCoordinateSpan(latitudeDelta: 0.008, longitudeDelta: 0.008))
    }
}

private struct DiscoveryMapResults: View {
    @ObservedObject var search: DiscoveryPlaceSearch
    let retry: () -> Void
    let select: () -> Void
    let usePlace: (DiscoveryPlace) -> Void
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                Map(coordinateRegion: $search.region, annotationItems: search.places) { place in
                    MapAnnotation(coordinate: place.coordinate) {
                        Button { select(); search.select(place) } label: {
                            Image(systemName: "mappin.circle.fill")
                                .font(.system(size: search.selectedID == place.id ? 38 : 30))
                                .foregroundStyle(search.selectedID == place.id ? Color.orange : Theme.accent)
                                .background(.white, in: Circle()).frame(width: 44, height: 44)
                        }.buttonStyle(.plain).accessibilityLabel(place.title)
                    }
                }.frame(height: max(160, min(300, geometry.size.height * 0.48)))
                    .accessibilityLabel("장소 검색 결과 지도")
                if search.loading || (!search.finished && search.error == nil) {
                    ProgressView("장소 검색 중…").frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = search.error {
                    VStack(spacing: 16) {
                        Text(error).multilineTextAlignment(.center).foregroundStyle(.secondary)
                        Button("다시 검색", action: retry)
                    }.padding(24).frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if search.places.isEmpty {
                    Text("검색 결과가 없어요. 다른 지역명이나 주소로 검색해주세요.")
                        .foregroundStyle(.secondary).multilineTextAlignment(.center).padding(24)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    HStack { Text("장소 검색 결과").font(.headline); Spacer(); Text("\(search.places.count)곳").foregroundStyle(Theme.accent) }.padding(16)
                    ScrollViewReader { proxy in
                        List(search.places) { place in
                            VStack(alignment: .leading, spacing: 8) {
                                Button { select(); search.select(place) } label: {
                                    HStack(alignment: .top) {
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text(place.title).font(.headline).foregroundStyle(Theme.ink)
                                            Text(place.address).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                                        }
                                        Spacer()
                                        if search.selectedID == place.id { Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.accent) }
                                    }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                                }.buttonStyle(.plain)
                                if search.selectedID == place.id {
                                    Button { place.item.openInMaps(launchOptions: nil) } label: { Label("지도 앱에서 열기", systemImage: "arrow.up.right.square") }
                                        .font(.footnote).buttonStyle(.borderless)
                                }
                            }.padding(.vertical, 6).id(place.id)
                        }.listStyle(.plain)
                            .onChange(of: search.selectedID) { id in
                                if let id { withAnimation { proxy.scrollTo(id, anchor: .top) } }
                            }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if let place = search.places.first(where: { $0.id == search.selectedID }) {
                    VStack(spacing: 8) {
                        Text(place.title).font(.subheadline).lineLimit(2)
                        FlowAction(title: "이 지역에서 프로그램 찾기") { usePlace(place) }
                    }.padding(16).background(.white)
                }
            }
        }
    }
}

struct ProgramCard: View {
    let program: DiscoveryProgram
    var distanceKilometers: Double? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(program.venue).font(AppTypography.font(11)).foregroundStyle(.secondary)
                    Text(program.title).font(AppTypography.font(14, weight: .medium)).foregroundStyle(Theme.ink)
                    Text("\(program.date) \(program.time)").font(AppTypography.font(11)).foregroundStyle(.secondary)
                }
                Spacer(minLength: 4)
                SafeAssetImage(name: "NextIcon", fallback: "chevron.right").frame(width: 19, height: 26).accessibilityHidden(true)
            }
            ViewThatFits(in: .horizontal) {
                HStack { tags; Spacer(minLength: 4); reviewCount }
                VStack(alignment: .leading, spacing: 8) { tags; reviewCount }
            }
        }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(.white, in: RoundedRectangle(cornerRadius: 20))
    }
    private var tags: some View {
        HStack(spacing: 6) {
            chip(program.category)
            if let distance = distanceKilometers { chip(String(format: "직선 %.1fkm", distance)) }
            else if program.minutes > 0 { chip("도보 \(program.minutes)분") }
            if program.smallGroup { chip("소그룹") }
        }
    }
    private func chip(_ title: String) -> some View {
        Text(title).font(.caption2).padding(.horizontal, 12).padding(.vertical, 6).background(Theme.surface, in: Capsule())
    }
    private var reviewCount: some View {
        HStack(spacing: 4) {
            SafeAssetImage(name: "ReviewIcon", fallback: "bubble.left").frame(width: 13, height: 13)
            Text("\(program.reviews)").font(.footnote)
        }.foregroundStyle(Theme.accent).accessibilityElement(children: .ignore).accessibilityLabel("후기 \(program.reviews)개")
    }
}

struct ReservationsView: View {
    @ObservedObject var store: WellnessStore
    @State private var previous = false
    @State private var newest = true
    private var items: [WellnessBooking] {
        let filtered = store.bookings.filter { !$0.isCancelled }.filter { previous ? $0.attendance == .checkedOut : $0.attendance != .checkedOut }
        return newest ? Array(filtered.reversed()) : filtered
    }
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    tab("예약 확정", value: false)
                    tab("이전 예약", value: true)
                }.background(.white)
                ScrollView {
                    VStack(spacing: 12) {
                        HStack {
                            Text("예약내역").font(.headline)
                            Text("\(items.count)건").font(.footnote).foregroundStyle(Theme.accent)
                            Spacer()
                            Menu {
                                Button("최신순") { newest = true }
                                Button("오래된순") { newest = false }
                            } label: { Label(newest ? "최신순" : "오래된순", systemImage: "chevron.down").font(.caption) }
                        }
                        ForEach(items) { booking in
                            NavigationLink(value: booking.id) { ProgramCard(program: booking.displayProgram) }.buttonStyle(.plain)
                        }
                        if items.isEmpty { Text(previous ? "이전 예약이 없어요." : "확정된 예약이 없어요.").foregroundStyle(.secondary).padding(.vertical, 40) }
                    }.padding(24)
                }
            }.frame(maxWidth: 600).frame(maxWidth: .infinity)
                .background(Theme.background.ignoresSafeArea())
                .navigationTitle("예약").navigationBarTitleDisplayMode(.inline)
                .navigationDestination(for: String.self) { ReservationSummaryView(bookingID: $0, store: store) }
        }
    }
    private func tab(_ title: String, value: Bool) -> some View {
        Button { previous = value } label: {
            Text(title).font(.body.weight(previous == value ? .semibold : .regular))
                .frame(maxWidth: .infinity, minHeight: 56)
                .foregroundStyle(previous == value ? Theme.accent : .secondary)
                .overlay(alignment: .bottom) { Rectangle().fill(previous == value ? Theme.accent : .clear).frame(height: 3) }
        }.buttonStyle(.plain).accessibilityAddTraits(previous == value ? .isSelected : [])
    }
}

struct ExerciseReviewView: View {
    let booking: WellnessBooking
    let onSave: (Int, ExerciseReflection) -> Void
    let onSkip: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var rating: Int
    @State private var reflection: ExerciseReflection

    init(booking: WellnessBooking, onSave: @escaping (Int, ExerciseReflection) -> Void, onSkip: @escaping () -> Void) {
        self.booking = booking; self.onSave = onSave; self.onSkip = onSkip
        _rating = State(initialValue: booking.rating > 0 ? booking.rating : 4)
        _reflection = State(initialValue: booking.reflection ?? ExerciseReflection())
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 28) {
                        Text("지은 님,\n오늘 운동도 잘 마쳤어요.").font(.title2.bold())
                        VStack(alignment: .leading, spacing: 8) {
                            Text(booking.title).font(.headline)
                            Text("\(booking.venue) · \(booking.dateLabel)").font(.footnote).foregroundStyle(.secondary)
                        }.padding(20).frame(maxWidth: .infinity, alignment: .leading).background(.white, in: RoundedRectangle(cornerRadius: 16))
                    }.padding(24).frame(maxWidth: .infinity, alignment: .leading).background(Theme.background)
                    HStack(spacing: 4) {
                        ForEach(1...5, id: \.self) { value in
                            Button { rating = value } label: {
                                Image(systemName: "star.fill").resizable().scaledToFit().frame(width: 30, height: 30)
                                    .foregroundStyle(value <= rating ? Theme.accent : Color.gray.opacity(0.3)).frame(minWidth: 40, minHeight: 48)
                            }.buttonStyle(.plain).accessibilityLabel("\(value)점").accessibilityAddTraits(rating == value ? .isSelected : [])
                        }
                        Text(String(format: "%.1f", Double(rating))).font(.title2.bold()).foregroundStyle(Theme.accent).padding(.leading, 10)
                    }.padding(.vertical, 20)
                    Rectangle().fill(Theme.background).frame(height: 7)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("운동 돌아보기").font(.headline)
                        VStack(alignment: .leading, spacing: 20) {
                            question("Q1. 운동 후 몸과 마음은 어떠셨어요?", options: ["편안해졌어요", "비슷했어요", "조금 버거웠어요"], selection: $reflection.feeling)
                            Divider()
                            question("Q2. 운동 강도는 어떠셨어요?", options: ["조금 가벼웠어요", "좋았어요", "조금 버거웠어요"], selection: $reflection.intensity)
                            Divider()
                            Text("Q3. 현장 분위기와 진행은 어떠셨어요?").font(.footnote)
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 130))], alignment: .leading, spacing: 8) {
                                ForEach(["조용하고 아늑함", "강사님 배려가 좋았음"], id: \.self) { value in
                                    choice(value, selected: reflection.atmosphere.contains(value)) {
                                        if reflection.atmosphere.contains(value) { reflection.atmosphere.remove(value) }
                                        else { reflection.atmosphere.insert(value) }
                                    }
                                }
                            }
                            Divider()
                            question("Q4. 다음에도 비슷한 활동을 해볼까요?", options: ["또 참여하고 싶어요", "다른 종목을 찾아볼래요"], selection: $reflection.nextActivity)
                        }.padding(20).background(Theme.background, in: RoundedRectangle(cornerRadius: 24))
                        Button { onSave(rating, reflection) } label: {
                            Text("작성하기").frame(maxWidth: .infinity, minHeight: 52).foregroundStyle(.white)
                                .background(Theme.accent.opacity(reflection.complete ? 1 : 0.4), in: Capsule())
                        }.buttonStyle(.plain).disabled(!reflection.complete).padding(.top, 36)
                        Button("기록 없이 바로 홈으로 건너뛰기", action: onSkip)
                            .font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, minHeight: 44)
                    }.padding(24)
                }.frame(maxWidth: 500).frame(maxWidth: .infinity)
            }.background(.white)
                .navigationTitle("운동 후기").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button { dismiss() } label: { Image(systemName: "arrow.left") }.accessibilityLabel("뒤로 가기") } }
        }
    }
    private func question(_ title: String, options: [String], selection: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.footnote)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 85))], alignment: .leading, spacing: 8) {
                ForEach(options, id: \.self) { option in choice(option, selected: selection.wrappedValue == option) { selection.wrappedValue = option } }
            }
        }
    }
    private func choice(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.caption).fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 10).frame(maxWidth: .infinity, minHeight: 40)
                .foregroundStyle(selected ? Theme.accent : .secondary)
                .background(selected ? Theme.mint.opacity(0.6) : .white, in: RoundedRectangle(cornerRadius: 12))
        }.buttonStyle(.plain).accessibilityAddTraits(selected ? .isSelected : [])
    }
}
