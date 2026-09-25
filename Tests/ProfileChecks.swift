import Foundation
import Combine
import Security

final class Auth {
    struct User { let uid: String; let email: String? }
    static let shared = Auth()
    static func auth() -> Auth { shared }
    var currentUser: User? = User(uid: "test-a", email: "a@example.invalid")
}
enum APIError: Error { case notLoggedIn, invalidResponse, serverUnavailable }

let suite = "CalmProfileChecks-" + UUID().uuidString
let defaults = UserDefaults(suiteName: suite)!
defer { defaults.removePersistentDomain(forName: suite) }
let profile = ProfileStore(defaults: defaults)
let original = profile.details
var draft = original
draft.name = "새 이름"
assert(profile.details == original, "Editing a draft must not update the saved profile")
draft.phone = "010-12-3456"
assert(draft.validationMessage != nil)
assert(profile.details == original)
draft.phone = "010-1234-5678"
draft.email = "invalid@"
assert(draft.validationMessage != nil)
draft.email = "test@example.com"
draft.name = "   "
assert(draft.validationMessage != nil)
draft.name = "  새 이름  "
assert(draft.validationMessage == nil)
let restored = ProfileStore(defaults: defaults)
assert(restored.name.isEmpty && restored.phone.isEmpty)
assert(restored.email == "a@example.invalid")
assert(restored.availableTimes.isEmpty && restored.availableDays.isEmpty && restored.exerciseTypes.isEmpty)
profile.availableTimes = ["새벽(6~9시)"]
profile.availableDays = ["토", "일"]
profile.exerciseTypes = ["수영"]
profile.healthNote = String(repeating: "한", count: 510)
assert(profile.healthNote.count == 500)
let conditions = ProfileStore(defaults: defaults)
assert(conditions.availableTimes == ["새벽(6~9시)"])
assert(conditions.availableDays == Set(["토", "일"]))
assert(conditions.exerciseTypes == ["수영"])
assert(conditions.healthNote.count == 500)
Auth.shared.currentUser = Auth.User(uid: "test-b", email: "b@example.invalid")
let otherUser = ProfileStore(defaults: defaults)
assert(otherUser.email == "b@example.invalid" && otherUser.name.isEmpty)
assert(otherUser.availableTimes.isEmpty && otherUser.healthNote.isEmpty)
Auth.shared.currentUser = Auth.User(uid: "test-a", email: "a@example.invalid")
profile.availableTimes = []
profile.availableDays = []
profile.exerciseTypes = []
profile.healthNote = ""
let cleared = ProfileStore(defaults: defaults)
assert(cleared.availableTimes.isEmpty && cleared.availableDays.isEmpty && cleared.exerciseTypes.isEmpty)
assert(cleared.healthNote.isEmpty)
assert(PasswordRules.message(new: "short1!", confirmation: "short1!") != nil)
assert(PasswordRules.message(new: "abcdefgh", confirmation: "abcdefgh") != nil)
assert(PasswordRules.message(new: "abcdefgh1", confirmation: "abcdefgh1") != nil)
assert(PasswordRules.message(new: "abcd 123!", confirmation: "abcd 123!") != nil)
assert(PasswordRules.message(new: "Valid123!", confirmation: "different") != nil)
assert(PasswordRules.message(new: "Valid123!", confirmation: "Valid123!") == nil)
assert(PasswordRules.message(new: "VeryLongPassword123!", confirmation: "VeryLongPassword123!") != nil)
print("PASS: draft validation, account identity, no fabricated defaults, condition isolation/persistence, password rules and 500-character limit")
