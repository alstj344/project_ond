//
//  APIService.swift
//  CalmIOS
//
//  Created by 이민서 on 9/24/26.
//


import Foundation
import FirebaseAuth

struct RemoteProgram: Decodable, Identifiable, Hashable {
    let id: String
    let title: String
    let description: String
    let exerciseType: String
    let difficulty: String
    let participationType: String
    let facilityId: String
    let instructorId: String
    let startAt: String
    let endAt: String
    let price: Int
    let capacity: Int
    let reservedCount: Int
    let imageURL: String?
    let latitude: Double?
    let longitude: Double?

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
}

struct ProgramPage: Decodable {
    let success: Bool
    let programs: [RemoteProgram]
    let nextCursor: String?
}

struct RemoteFacility: Decodable, Identifiable, Hashable {
    struct Transit: Decodable, Hashable { let name: String; let mode: String }
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
        guard let latitude, let longitude, (33...39).contains(latitude), (124...132).contains(longitude) else { return nil }
        return ProgramLocation(latitude: latitude, longitude: longitude)
    }
}

struct FacilityPage: Decodable {
    let success: Bool
    let facilities: [RemoteFacility]
    let total: Int
    let nextPage: Int?
    let categories: [String]
}

#if DEBUG && targetEnvironment(simulator)
private final class ProfileRedirectBlocker: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}

final class APIService {

    static let shared = APIService()

    private let baseURL = "http://localhost:3000"

    private init() {}

    func getFacilities(search: String, category: String, center: ProgramLocation?, radius: Double, page: Int) async throws -> FacilityPage {
        var components = URLComponents(string: "\(baseURL)/api/facilities")!
        var items = [URLQueryItem(name: "q", value: search), URLQueryItem(name: "category", value: category),
                     URLQueryItem(name: "page", value: String(page))]
        if let center {
            items += [URLQueryItem(name: "lat", value: String(center.latitude)),
                      URLQueryItem(name: "lon", value: String(center.longitude)),
                      URLQueryItem(name: "radius", value: String(radius))]
        }
        components.queryItems = items
        guard let url = components.url else { throw APIError.invalidURL }
        let session = URLSession(configuration: .ephemeral, delegate: ProfileRedirectBlocker(), delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { throw APIError.serverUnavailable }
        let result = try JSONDecoder().decode(FacilityPage.self, from: data)
        guard result.success else { throw APIError.invalidResponse }
        return result
    }

    func getPrograms(after: String? = nil) async throws -> ProgramPage {
        var components = URLComponents(string: "\(baseURL)/api/programs")!
        if let after { components.queryItems = [URLQueryItem(name: "after", value: after)] }
        guard let url = components.url else { throw APIError.invalidURL }
        let session = URLSession(configuration: .ephemeral,
                                 delegate: ProfileRedirectBlocker(), delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw APIError.serverUnavailable
        }
        let page = try JSONDecoder().decode(ProgramPage.self, from: data)
        guard page.success else { throw APIError.invalidResponse }
        return page
    }

    private struct ProfileResponse: Decodable {
        struct Profile: Decodable { let id: String }
        let success: Bool
        let user: Profile
    }

    func getMyProfile() async throws -> Data {
        try await requestProfile(method: "GET")
    }

    func saveOnboarding(_ profile: OnboardingProfile) async throws {
        let payload = OnboardingPreferences(profile: profile)
        _ = try await requestProfile(method: "PATCH", body: JSONEncoder().encode(payload))
    }

    func saveConditions(_ conditions: ExerciseConditionsPayload) async throws {
        _ = try await requestProfile(method: "PATCH", body: JSONEncoder().encode(conditions))
    }

    func savePersonalDetails(name: String, phone: String) async throws {
        struct Payload: Encodable { let name: String; let phone: String }
        _ = try await requestProfile(method: "PATCH", body: JSONEncoder().encode(Payload(name: name, phone: phone)))
    }

    func registerMedicalTestData() async throws {
        _ = try await requestProfile(method: "PATCH", body: JSONEncoder().encode(["registerMedicalTestData": true]))
    }

    private func requestProfile(method: String, body: Data? = nil) async throws -> Data {

        guard let user = Auth.auth().currentUser else {
            throw APIError.notLoggedIn
        }

        guard let url = URL(
            string: "\(baseURL)/api/users/me"
        ) else {
            throw APIError.invalidURL
        }

        let session = URLSession(configuration: .ephemeral,
                                 delegate: ProfileRedirectBlocker(), delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        for attempt in 0...1 {
            let token = try await user.getIDToken(forcingRefresh: attempt == 1)
            var request = URLRequest(url: url)
            request.httpMethod = method
            request.httpBody = body
            if body != nil { request.setValue("application/json", forHTTPHeaderField: "Content-Type") }
            request.timeoutInterval = 15
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            print("Express \(method) /api/users/me HTTP Status: \(httpResponse.statusCode)")
            switch httpResponse.statusCode {
            case 200:
                guard let profile = try? JSONDecoder().decode(ProfileResponse.self, from: data),
                      profile.success, profile.user.id == user.uid,
                      Auth.auth().currentUser?.uid == user.uid else {
                    throw APIError.invalidResponse
                }
                return data
            case 401:
                if attempt == 0 { continue }
                throw APIError.notLoggedIn
            case 404: throw APIError.profileMissing
            default: throw APIError.serverUnavailable
            }
        }
        throw APIError.notLoggedIn
    }
}
#endif

enum APIError: Error {
    case notLoggedIn
    case invalidURL
    case invalidResponse
    case profileMissing
    case serverUnavailable
}
