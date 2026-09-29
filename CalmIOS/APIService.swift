//
//  APIService.swift
//  CalmIOS
//
//  Created by 이민서 on 9/24/26.
//

import Foundation
import FirebaseAuth

// MARK: - Endpoint Configuration

enum APIEndpoint {
    enum ConfigurationError: Error { case missingOrInvalidURL }

    static func resolve(configured: String?, fallback: String?, path: String) throws -> URL {
        let value = configured?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let raw = value.isEmpty ? (fallback ?? "") : value
        guard var parts = URLComponents(string: raw),
              let host = parts.host, !host.isEmpty,
              parts.user == nil, parts.password == nil,
              parts.query == nil, parts.fragment == nil,
              parts.path.isEmpty || parts.path == "/",
              path.hasPrefix("/api/"), !path.contains("?"), !path.contains("#"),
              !path.contains(".."), !path.contains("%") else {
            throw ConfigurationError.missingOrInvalidURL
        }
        let loopback = ["localhost", "127.0.0.1", "[::1]", "::1"].contains(host.lowercased())
        guard (parts.scheme == "https" && !loopback) ||
                (fallback != nil && loopback && parts.scheme == "http") else {
            throw ConfigurationError.missingOrInvalidURL
        }
        parts.path = path
        guard let url = parts.url else { throw ConfigurationError.missingOrInvalidURL }
        return url
    }
}

// MARK: - Program

struct RemoteProgram: Decodable, Identifiable, Hashable {
    let id: String
    let programId: String
    let programName: String
    let facilityName: String
    let instructorName: String
    let scheduleText: String
    let durationMinutes: Int?
    let instructorBio: String
    let instructorSpecialty: String
    let participationGuide: [String]
    let amenities: [String]
    let isTestData: Bool
    let bookingAvailable: Bool
    let bookingUnavailableReason: String?
    var title: String { programName }
    let description: String
    let exerciseType: String
    let difficulty: String
    let participationType: String
    let facilityId: String
    let instructorId: String
    let startAt: String
    let endAt: String
    let price: Int?
    let capacity: Int?
    let reservedCount: Int?
    let reviewCount: Int?
    let imageURL: String?
    let latitude: Double?
    let longitude: Double?
    private enum CodingKeys: String, CodingKey {
        case instructorName, participationGuide, amenities, isTestData
        case scheduleText, durationMinutes, instructorBio, instructorSpecialty
        case bookingAvailable, bookingUnavailableReason
        case id, programId, programName, title, facilityName, description, exerciseType, difficulty, participationType, facilityId, instructorId, startAt, endAt, price, capacity, reservedCount, reviewCount, imageURL, latitude, longitude
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decodeIfPresent(String.self, forKey: .id)
            ?? values.decode(String.self, forKey: .programId)
        programId = try values.decodeIfPresent(String.self, forKey: .programId) ?? id
        programName = try values.decodeIfPresent(String.self, forKey: .programName)
            ?? values.decode(String.self, forKey: .title)
        facilityName = try values.decodeIfPresent(String.self, forKey: .facilityName) ?? ""
        instructorName = try values.decodeIfPresent(String.self, forKey: .instructorName) ?? ""
        scheduleText = try values.decodeIfPresent(String.self, forKey: .scheduleText) ?? ""
        durationMinutes = try values.decodeIfPresent(Int.self, forKey: .durationMinutes)
        instructorBio = try values.decodeIfPresent(String.self, forKey: .instructorBio) ?? ""
        instructorSpecialty = try values.decodeIfPresent(String.self, forKey: .instructorSpecialty) ?? ""
        participationGuide = try values.decodeIfPresent([String].self, forKey: .participationGuide) ?? []
        amenities = try values.decodeIfPresent([String].self, forKey: .amenities) ?? []
        isTestData = try values.decodeIfPresent(Bool.self, forKey: .isTestData) ?? false
        bookingAvailable = try values.decodeIfPresent(Bool.self, forKey: .bookingAvailable) ?? false
        bookingUnavailableReason = try values.decodeIfPresent(String.self, forKey: .bookingUnavailableReason)
        description = try values.decodeIfPresent(String.self, forKey: .description) ?? ""
        exerciseType = try values.decodeIfPresent(String.self, forKey: .exerciseType) ?? ""
        difficulty = try values.decodeIfPresent(String.self, forKey: .difficulty) ?? ""
        participationType = try values.decodeIfPresent(String.self, forKey: .participationType) ?? ""
        facilityId = try values.decodeIfPresent(String.self, forKey: .facilityId) ?? ""
        instructorId = try values.decodeIfPresent(String.self, forKey: .instructorId) ?? ""
        startAt = try values.decodeIfPresent(String.self, forKey: .startAt) ?? ""
        endAt = try values.decodeIfPresent(String.self, forKey: .endAt) ?? ""
        price = try values.decodeIfPresent(Int.self, forKey: .price)
        capacity = try values.decodeIfPresent(Int.self, forKey: .capacity)
        reservedCount = try values.decodeIfPresent(Int.self, forKey: .reservedCount)
        reviewCount = try values.decodeIfPresent(Int.self, forKey: .reviewCount)
        imageURL = try values.decodeIfPresent(String.self, forKey: .imageURL)
        latitude = try values.decodeIfPresent(Double.self, forKey: .latitude)
        longitude = try values.decodeIfPresent(Double.self, forKey: .longitude)
    }

    var priceLabel: String {
        guard let price else { return "요금 정보 없음" }
        return price == 0 ? "무료" : "\(price.formatted())원"
    }
    var location: ProgramLocation? {
        guard let latitude, let longitude,
              (-90...90).contains(latitude), (-180...180).contains(longitude) else { return nil }
        return ProgramLocation(latitude: latitude, longitude: longitude)
    }
    func matchScore(preferences: OnboardingPreferences?, conditions: ExerciseConditionsPayload?) -> Int {
        var score = 0
        if (conditions?.preferredExercises ?? preferences?.preferredExercises)?.contains(exerciseType) == true { score += 4 }
        if preferences?.participationTypes?.contains(participationType) == true { score += 2 }
        if let date = startDate {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
            let day = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"][calendar.component(.weekday, from: date) - 1]
            if conditions?.availableDays?.contains(day) == true { score += 1 }
            let hour = calendar.component(.hour, from: date)
            let slot: String?
            switch hour {
            case 6..<9: slot = "EARLY"
            case 9..<12: slot = "MORNING"
            case 12..<15: slot = "MIDDAY"
            case 15..<18: slot = "AFTERNOON"
            case 18..<21: slot = "EVENING"
            default: slot = nil
            }
            if let slot, conditions?.availableTimes?.contains(slot) == true { score += 1 }
        }
        return score
    }
    var category: String {
        ExerciseConditionsPayload.typeCodes.first { $0.value == exerciseType }?.key ?? exerciseType
    }
    var startDate: Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: startAt) ?? ISO8601DateFormatter().date(from: startAt)
    }
    var endDate: Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: endAt) ?? ISO8601DateFormatter().date(from: endAt)
    }
}

struct ProgramPage: Decodable {
    let success: Bool
    let programs: [RemoteProgram]
    let nextCursor: String?
}

struct NearbyProgramResponse: Decodable {
    let success: Bool
    let radius: Double
    let count: Int
    let programs: [RemoteProgram]
}


// MARK: - Review

struct RemoteReview: Decodable, Identifiable, Hashable {
    let id: String
    let content: String
    let createdAt: String?
    let facilityName: String
    let isSample: Bool
    let programId: String
    let programName: String
    let rating: Int
    let reservationId: String?
    let updatedAt: String?
    let userId: String?
    var date: Date? {
        guard let createdAt else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: createdAt) ?? ISO8601DateFormatter().date(from: createdAt)
    }
}

struct ReviewListResponse: Decodable {
    let success: Bool
    let reviews: [RemoteReview]
    let reviewCount: Int
    let averageRating: Double
    let nextCursor: String?
}


// MARK: - Reservation

struct RemoteReservation: Decodable, Identifiable, Hashable {
    let id: String
    let programId: String
    let status: String
    let createdAt: String?
    let cancelledAt: String?
    let program: RemoteProgram?
}

struct ReservationListResponse: Decodable {
    let success: Bool
    let reservations: [RemoteReservation]
}

struct ReservationCreateResponse: Decodable {
    let success: Bool
    let message: String?
    let reservation: RemoteReservation?
}

struct ReservationActionResponse: Decodable {
    let success: Bool
    let message: String?
}

private struct ReservationCreatePayload: Encodable {
    let programId: String
}


// MARK: - Facility

struct RemoteFacility: Decodable, Identifiable, Hashable {

    struct Transit: Decodable, Hashable {
        let name: String
        let type: String
        let distanceMeters: Int?
        let distanceType: String?
        let latitude: Double?
        let longitude: Double?
        let walkingTimeMinutes: Int?
    }

    let id: String
    let name: String
    let address: String
    let addressDetail: String
    let category: String
    let facilityType: String
    let district: String
    let latitude: Double?
    let longitude: Double?
    let phone: String
    let sourceSnapshot: String
    let distanceKm: Double?
    let nearbyTransit: [Transit]

    var location: ProgramLocation? {
        guard
            let latitude,
            let longitude,
            (33...39).contains(latitude),
            (124...132).contains(longitude)
        else {
            return nil
        }

        return ProgramLocation(
            latitude: latitude,
            longitude: longitude
        )
    }
}

struct FacilityPage: Decodable {
    let success: Bool
    let facilities: [RemoteFacility]
    let total: Int
    let nextPage: Int?
    let categories: [String]
}


private final class ProfileRedirectBlocker: NSObject, URLSessionTaskDelegate {

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }
}


// MARK: - API Service

final class APIService {

    static let shared = APIService()

    private func endpoint(_ path: String) throws -> URL {
        let configured = Bundle.main.object(forInfoDictionaryKey: "ONDAPIBaseURL") as? String
        #if DEBUG && targetEnvironment(simulator)
        let fallback: String? = "http://localhost:3000"
        #else
        let fallback: String? = nil
        #endif
        return try APIEndpoint.resolve(configured: configured, fallback: fallback, path: path)
    }

    private init() {}


    // MARK: Reservation

    func createReservation(
        programId: String
    ) async throws -> RemoteReservation {

        guard programId.range(
            of: "^[A-Za-z0-9_-]{1,128}$",
            options: .regularExpression
        ) != nil else {
            throw APIError.invalidURL
        }

        let body = try JSONEncoder().encode(
            ReservationCreatePayload(
                programId: programId
            )
        )

        let data = try await reservationRequest(
            path: "/api/reservations",
            method: "POST",
            body: body
        )

        let result = try JSONDecoder().decode(
            ReservationCreateResponse.self,
            from: data
        )

        guard
            result.success,
            let reservation = result.reservation,
            reservation.programId == programId,
            reservation.status == "RESERVED"
        else {
            throw APIError.invalidResponse
        }

        return reservation
    }


    func getMyReservations() async throws -> [RemoteReservation] {

        let data = try await reservationRequest(
            path: "/api/reservations/me",
            method: "GET"
        )

        let result = try JSONDecoder().decode(
            ReservationListResponse.self,
            from: data
        )

        guard result.success else {
            throw APIError.invalidResponse
        }

        return result.reservations.filter { $0.program?.isTestData != true }
    }


    func cancelReservation(
        programId: String,
        reason: String? = nil
    ) async throws {

        guard programId.range(
            of: "^[A-Za-z0-9_-]{1,128}$",
            options: .regularExpression
        ) != nil else {
            throw APIError.invalidURL
        }

        let body = try reason.map {
            try JSONEncoder().encode(
                ["reason": $0]
            )
        }

        let data = try await reservationRequest(
            path: "/api/reservations/\(programId)",
            method: "DELETE",
            body: body
        )

        let result = try JSONDecoder().decode(
            ReservationActionResponse.self,
            from: data
        )

        guard result.success else {
            throw APIError.invalidResponse
        }
    }


    private func reservationRequest(
        path: String,
        method: String,
        body: Data? = nil
    ) async throws -> Data {

        guard let user = Auth.auth().currentUser else {
            throw APIError.notLoggedIn
        }

        let url = try endpoint(path)

        let session = URLSession(
            configuration: .ephemeral,
            delegate: ProfileRedirectBlocker(),
            delegateQueue: nil
        )

        defer {
            session.invalidateAndCancel()
        }

        for attempt in 0...1 {

            let token = try await user.getIDToken(
                forcingRefresh: attempt == 1
            )

            var request = URLRequest(url: url)

            request.httpMethod = method
            request.httpBody = body

            request.setValue(
                "application/json",
                forHTTPHeaderField: "Accept"
            )

            if body != nil {
                request.setValue(
                    "application/json",
                    forHTTPHeaderField: "Content-Type"
                )
            }

            request.timeoutInterval = 15

            request.setValue(
                "Bearer \(token)",
                forHTTPHeaderField: "Authorization"
            )

            let (data, response) = try await session.data(
                for: request
            )

            guard Auth.auth().currentUser?.uid == user.uid else {
                throw APIError.notLoggedIn
            }

            guard let http = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }

            if http.statusCode == 401 && attempt == 0 {
                continue
            }

            if http.statusCode == 401 {
                throw APIError.notLoggedIn
            }

            if http.statusCode == 404 {
                throw APIError.reservationMissing
            }

            if http.statusCode == 409 {
                throw APIError.reservationUnavailable
            }

            let expectedStatus =
                method == "POST" ? 201 : 200

            guard http.statusCode == expectedStatus else {
                throw APIError.serverUnavailable
            }

            return data
        }

        throw APIError.notLoggedIn
    }


    // MARK: Facility

    func getFacilities(
        search: String,
        category: String,
        center: ProgramLocation?,
        radius: Double,
        page: Int
    ) async throws -> FacilityPage {

        guard var components = URLComponents(url: try endpoint("/api/facilities"), resolvingAgainstBaseURL: false) else {
            throw APIError.invalidURL
        }

        var items = [
            URLQueryItem(
                name: "q",
                value: search
            ),
            URLQueryItem(
                name: "category",
                value: category
            ),
            URLQueryItem(
                name: "page",
                value: String(page)
            )
        ]

        if let center {

            items += [
                URLQueryItem(
                    name: "lat",
                    value: String(center.latitude)
                ),
                URLQueryItem(
                    name: "lon",
                    value: String(center.longitude)
                ),
                URLQueryItem(
                    name: "radius",
                    value: String(radius)
                )
            ]
        }

        components.queryItems = items

        guard let url = components.url else {
            throw APIError.invalidURL
        }

        let session = URLSession(
            configuration: .ephemeral,
            delegate: ProfileRedirectBlocker(),
            delegateQueue: nil
        )

        defer {
            session.invalidateAndCancel()
        }

        var request = URLRequest(url: url)

        request.timeoutInterval = 30

        request.setValue(
            "application/json",
            forHTTPHeaderField: "Accept"
        )

        let (data, response) = try await session.data(
            for: request
        )

        guard
            let http = response as? HTTPURLResponse,
            http.statusCode == 200
        else {
            throw APIError.serverUnavailable
        }

        let result = try JSONDecoder().decode(
            FacilityPage.self,
            from: data
        )

        guard result.success else {
            throw APIError.invalidResponse
        }

        return result
    }


    // MARK: Program

    func getPrograms(
        after: String? = nil
    ) async throws -> ProgramPage {

        guard var components = URLComponents(url: try endpoint("/api/programs"), resolvingAgainstBaseURL: false) else {
            throw APIError.invalidURL
        }

        if let after {
            components.queryItems = [
                URLQueryItem(
                    name: "after",
                    value: after
                )
            ]
        }

        guard let url = components.url else {
            throw APIError.invalidURL
        }

        let session = URLSession(
            configuration: .ephemeral,
            delegate: ProfileRedirectBlocker(),
            delegateQueue: nil
        )

        defer {
            session.invalidateAndCancel()
        }

        var request = URLRequest(url: url)

        request.timeoutInterval = 15

        request.setValue(
            "application/json",
            forHTTPHeaderField: "Accept"
        )

        let (data, response) = try await session.data(
            for: request
        )

        guard
            let http = response as? HTTPURLResponse,
            http.statusCode == 200
        else {
            throw APIError.serverUnavailable
        }

        let page = try JSONDecoder().decode(
            ProgramPage.self,
            from: data
        )

        guard page.success else {
            throw APIError.invalidResponse
        }

        return ProgramPage(success: page.success,
                           programs: page.programs.filter { !$0.isTestData },
                           nextCursor: page.nextCursor)
    }
    func getNearbyPrograms(
        center: ProgramLocation,
        radius: Double
    ) async throws -> [RemoteProgram] {

        guard (0.5...10).contains(radius) else {
            throw APIError.invalidURL
        }

        guard var components = URLComponents(
            url: try endpoint("/api/programs/nearby"),
            resolvingAgainstBaseURL: false
        ) else {
            throw APIError.invalidURL
        }

        components.queryItems = [
            URLQueryItem(
                name: "lat",
                value: String(center.latitude)
            ),
            URLQueryItem(
                name: "lon",
                value: String(center.longitude)
            ),
            URLQueryItem(
                name: "radius",
                value: String(radius)
            )
        ]

        guard let url = components.url else {
            throw APIError.invalidURL
        }

        let session = URLSession(
            configuration: .ephemeral,
            delegate: ProfileRedirectBlocker(),
            delegateQueue: nil
        )

        defer {
            session.invalidateAndCancel()
        }

        var request = URLRequest(url: url)

        request.timeoutInterval = 30

        request.setValue(
            "application/json",
            forHTTPHeaderField: "Accept"
        )

        let (data, response) = try await session.data(
            for: request
        )

        guard
            let http = response as? HTTPURLResponse,
            http.statusCode == 200
        else {
            throw APIError.serverUnavailable
        }

        let result = try JSONDecoder().decode(
            NearbyProgramResponse.self,
            from: data
        )

        guard result.success else {
            throw APIError.invalidResponse
        }

        return result.programs.filter { !$0.isTestData }
    }

    func searchPrograms(
        query: String
    ) async throws -> [RemoteProgram] {

        let keyword = query.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !keyword.isEmpty else {
            return []
        }

        guard var components = URLComponents(
            url: try endpoint("/api/programs/search"),
            resolvingAgainstBaseURL: false
        ) else {
            throw APIError.invalidURL
        }

        components.queryItems = [
            URLQueryItem(
                name: "q",
                value: keyword
            )
        ]

        guard let url = components.url else {
            throw APIError.invalidURL
        }

        let session = URLSession(
            configuration: .ephemeral,
            delegate: ProfileRedirectBlocker(),
            delegateQueue: nil
        )

        defer {
            session.invalidateAndCancel()
        }

        var request = URLRequest(url: url)

        request.timeoutInterval = 15

        request.setValue(
            "application/json",
            forHTTPHeaderField: "Accept"
        )

        let (data, response) = try await session.data(
            for: request
        )

        guard
            let http = response as? HTTPURLResponse,
            http.statusCode == 200
        else {
            throw APIError.serverUnavailable
        }

        let result = try JSONDecoder().decode(
            ProgramSearchResponse.self,
            from: data
        )

        guard result.success else {
            throw APIError.invalidResponse
        }

        return result.programs.filter { !$0.isTestData }
    }


    struct ProgramSearchResponse: Decodable {
        let success: Bool
        let query: String
        let count: Int
        let programs: [RemoteProgram]
    }



    // MARK: Review

    func getProgramReviews(
        programId: String, after: String? = nil
    ) async throws -> ReviewListResponse {

        guard programId.range(
            of: "^[A-Za-z0-9_-]{1,128}$",
            options: .regularExpression
        ) != nil else {
            throw APIError.invalidURL
        }

        var components = URLComponents(url: try endpoint("/api/programs/\(programId)/reviews"), resolvingAgainstBaseURL: false)
        if let after { components?.queryItems = [URLQueryItem(name: "after", value: after)] }
        guard let url = components?.url else {
            throw APIError.invalidURL
        }

        let session = URLSession(
            configuration: .ephemeral,
            delegate: ProfileRedirectBlocker(),
            delegateQueue: nil
        )

        defer {
            session.invalidateAndCancel()
        }

        var request = URLRequest(url: url)

        request.httpMethod = "GET"
        request.timeoutInterval = 15

        request.setValue(
            "application/json",
            forHTTPHeaderField: "Accept"
        )

        let (data, response) = try await session.data(
            for: request
        )

        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard http.statusCode == 200 else {
            throw APIError.serverUnavailable
        }

        let result = try JSONDecoder().decode(
            ReviewListResponse.self,
            from: data
        )

        guard result.success else {
            throw APIError.invalidResponse
        }

        return result
    }


    // MARK: Profile

    private struct ProfileResponse: Decodable {

        struct Profile: Decodable {
            let id: String
        }

        let success: Bool
        let user: Profile
    }


    func getMyProfile() async throws -> Data {
        try await requestProfile(
            method: "GET"
        )
    }


    func saveOnboarding(
        _ profile: OnboardingProfile
    ) async throws {

        let payload = OnboardingPreferences(
            profile: profile
        )

        _ = try await requestProfile(
            method: "PATCH",
            body: JSONEncoder().encode(payload)
        )
    }


    func saveConditions(
        _ conditions: ExerciseConditionsPayload
    ) async throws {

        _ = try await requestProfile(
            method: "PATCH",
            body: JSONEncoder().encode(
                conditions
            )
        )
    }


    func savePersonalDetails(
        name: String,
        phone: String
    ) async throws {

        struct Payload: Encodable {
            let name: String
            let phone: String
        }

        let payload = Payload(
            name: name,
            phone: phone
        )

        _ = try await requestProfile(
            method: "PATCH",
            body: JSONEncoder().encode(payload)
        )
    }


    func registerMedicalTestData() async throws {

        _ = try await requestProfile(
            method: "PATCH",
            body: JSONEncoder().encode(
                ["registerMedicalTestData": true]
            )
        )
    }


    private func requestProfile(
        method: String,
        body: Data? = nil
    ) async throws -> Data {

        guard let user = Auth.auth().currentUser else {
            throw APIError.notLoggedIn
        }

        let url = try endpoint("/api/users/me")

        let session = URLSession(
            configuration: .ephemeral,
            delegate: ProfileRedirectBlocker(),
            delegateQueue: nil
        )

        defer {
            session.invalidateAndCancel()
        }

        for attempt in 0...1 {

            let token = try await user.getIDToken(
                forcingRefresh: attempt == 1
            )

            var request = URLRequest(url: url)

            request.httpMethod = method
            request.httpBody = body

            if body != nil {
                request.setValue(
                    "application/json",
                    forHTTPHeaderField: "Content-Type"
                )
            }

            request.timeoutInterval = 15

            request.setValue(
                "Bearer \(token)",
                forHTTPHeaderField: "Authorization"
            )

            request.setValue(
                "application/json",
                forHTTPHeaderField: "Accept"
            )

            let (data, response) = try await session.data(
                for: request
            )

            guard let httpResponse =
                    response as? HTTPURLResponse
            else {
                throw APIError.invalidResponse
            }

            print(
                "Express \(method) /api/users/me HTTP Status: \(httpResponse.statusCode)"
            )

            switch httpResponse.statusCode {

            case 200:

                guard
                    let profile = try? JSONDecoder().decode(
                        ProfileResponse.self,
                        from: data
                    ),
                    profile.success,
                    profile.user.id == user.uid,
                    Auth.auth().currentUser?.uid == user.uid
                else {
                    throw APIError.invalidResponse
                }

                return data

            case 401:

                if attempt == 0 {
                    continue
                }

                throw APIError.notLoggedIn

            case 404:
                throw APIError.profileMissing

            default:
                throw APIError.serverUnavailable
            }
        }

        throw APIError.notLoggedIn
    }
}


// MARK: - API Error

enum APIError: Error {

    case notLoggedIn
    case invalidURL
    case invalidResponse
    case profileMissing
    case serverUnavailable
    case reservationMissing
    case reservationUnavailable

    var userMessage: String {

        switch self {

        case .notLoggedIn:
            return "다시 로그인해주세요."

        case .profileMissing:
            return "회원정보를 찾을 수 없어요."

        case .invalidURL, .invalidResponse:
            return "요청을 처리하지 못했어요. 다시 시도해주세요."

        case .serverUnavailable:
            return "서버에 연결하지 못했어요. 잠시 후 다시 시도해주세요."

        case .reservationMissing:
            return "프로그램 또는 예약 내역을 찾을 수 없어요. 목록을 새로고침해 주세요."

        case .reservationUnavailable:
            return "이미 예약했거나 예약이 마감된 프로그램이에요. 예약 내역을 확인해 주세요."
        }
    }
}
