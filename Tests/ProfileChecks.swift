import Foundation
import Combine
import Security

let suite = "CalmProfileChecks-" + UUID().uuidString
let defaults = UserDefaults(suiteName: suite)!
defer { defaults.removePersistentDomain(forName: suite) }
let profile = ProfileStore(defaults: defaults)
let original = profile.details
var draft = original
draft.name = "새 이름"
assert(profile.details == original, "Editing a draft must not update the saved profile")
draft.phone = "010-12-3456"
assert(!profile.save(draft))
assert(profile.details == original)
draft.phone = "010-1234-5678"
draft.email = "invalid@"
assert(!profile.save(draft))
draft.email = "test@example.com"
draft.name = "   "
assert(!profile.save(draft))
draft.name = "  새 이름  "
assert(profile.save(draft))
let restored = ProfileStore(defaults: defaults)
assert(restored.name == "새 이름")
assert(restored.phone == "010-1234-5678")
assert(restored.email == "test@example.com")
assert(defaults.string(forKey: "calm.profileName") == restored.name)
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
print("PASS: draft isolation, invalid-save rejection, profile persistence, name propagation, password validation, exercise conditions persistence and clearing, 500-character limit")
