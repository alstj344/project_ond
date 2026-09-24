import Foundation
import Combine

let suite = "CalmReservationChecks-" + UUID().uuidString
let defaults = UserDefaults(suiteName: suite)!
defer { defaults.removePersistentDomain(forName: suite) }
let legacy = #"[{"id":"legacy","title":"Saved","venue":"Original","day":2,"time":"10:00","attendance":"checkedOut","review":"Keep this","rating":5}]"#
defaults.set(Data(legacy.utf8), forKey: "calm.demoBookings.v1")
let store = WellnessStore(defaults: defaults)
assert(store.bookings.count == 1)
assert(store.booking("legacy")?.review == "Keep this")
assert(store.booking("legacy")?.cancelledAt == nil)
assert(!store.cancel("legacy", reason: .other))
assert(!store.cancel("missing", reason: .other))

let program = DiscoveryProgram.samples[0]
store.reserve(program)
store.reserve(program)
assert(store.bookings.count == 2)
assert(store.booking(program.id)?.reservedAt != nil)
assert(store.cancel(program.id, reason: .change))
assert(!store.cancel(program.id, reason: .health))
assert(!store.transition(program.id, to: .checkedIn))
assert(!store.transition(program.id, to: .checkedOut))
let restored = WellnessStore(defaults: defaults)
assert(restored.booking(program.id)?.isCancelled == true)
assert(restored.booking(program.id)?.cancellationReason == CancellationReason.change.rawValue)
assert(restored.bookings.filter { !$0.isCancelled }.count == 1)
restored.reserve(program)
assert(restored.bookings.count == 2)
assert(restored.booking(program.id)?.isCancelled == false)
assert(restored.booking(program.id)?.cancellationReason == nil)
assert(!restored.transition(program.id, to: .checkedOut))
assert(restored.transition(program.id, to: .checkedIn))
assert(!restored.cancel(program.id, reason: .schedule))
assert(!restored.transition(program.id, to: .checkedIn))
assert(restored.transition(program.id, to: .checkedOut))
assert(!restored.cancel(program.id, reason: .health))
assert(restored.bookings.filter { $0.attendance == .checkedOut && $0.rating == 0 }.count == 1)
restored.saveReview(program.id, text: "invalid", rating: 4, reflection: ExerciseReflection())
assert(restored.booking(program.id)?.rating == 0)
let reflection = ExerciseReflection(feeling: "Comfortable", intensity: "Good", atmosphere: ["Quiet"], nextActivity: "Again")
restored.saveReview(program.id, text: reflection.summary, rating: 4, reflection: reflection)
let finalStore = WellnessStore(defaults: defaults)
assert(finalStore.booking(program.id)?.reflection == reflection)
assert(finalStore.booking(program.id)?.reviewedAt != nil)
assert(finalStore.bookings.filter { $0.attendance == .checkedOut && $0.rating > 0 }.count == 2)
assert(finalStore.booking("legacy")?.review == "Keep this")

var query = DiscoveryQuery()
query.filter = .nearby
query.radius = 0.5
assert(query.results(DiscoveryProgram.samples).isEmpty)
query.radius = 1.5
assert(query.results(DiscoveryProgram.samples).count == 3)
query.filter = .paid
assert(query.results(DiscoveryProgram.samples).isEmpty)
query.filter = .category
query.category = "걷기"
assert(query.results(DiscoveryProgram.samples).map(\.id) == ["discovery-walk"])
query.filter = .group
query.smallGroupOnly = true
assert(query.results(DiscoveryProgram.samples).allSatisfy(\.smallGroup))
assert(query.results(DiscoveryProgram.samples).count == DiscoveryProgram.samples.filter(\.smallGroup).count)
query.smallGroupOnly = false
assert(query.results(DiscoveryProgram.samples).count == DiscoveryProgram.samples.count)
defaults.set(Data("[]".utf8), forKey: "calm.demoBookings.v1")
assert(WellnessStore(defaults: defaults).bookings.isEmpty)
var nearby = DiscoveryQuery()
nearby.center = DiscoveryProgram.samples[2].location!
nearby.filter = .nearby
nearby.radius = 0.01
assert(nearby.results(DiscoveryProgram.samples).map(\.id) == ["discovery-swim"])
nearby.radius = 3
assert(nearby.results(DiscoveryProgram.samples).count == 3)
assert(nearby.results(DiscoveryProgram.samples).first?.id == "discovery-swim")
nearby.filter = .category
nearby.category = "걷기"
assert(nearby.results(DiscoveryProgram.samples).map(\.id) == ["discovery-walk"])
nearby.center = ProgramLocation(latitude: 35.1796, longitude: 129.0756)
nearby.radius = 10
assert(nearby.results(DiscoveryProgram.samples).isEmpty)
var missingLocation = DiscoveryProgram.samples[0]
missingLocation.location = nil
nearby.center = DiscoveryProgram.samples[0].location!
nearby.filter = .recommended
assert(nearby.results([missingLocation]).isEmpty)
print("PASS: reservation persistence, reviews, regional radius, distance sorting, category intersection and missing coordinates")
