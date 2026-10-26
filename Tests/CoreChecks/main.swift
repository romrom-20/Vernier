import Foundation
import VernierChecks
import VernierCore

var failures = 0
for (name, check) in CoreChecks.cases {
    do { try check(); print("PASS: \(name)") }
    catch { failures += 1; print("FAIL: \(name): \(error)") }
}
for (name, check) in SessionChecks.cases + MemoryChecks.cases {
    do { try await check(); print("PASS: \(name)") }
    catch { failures += 1; print("FAIL: \(name): \(error)") }
}
if CommandLine.arguments.contains("--codex-live") {
    do {
        let root = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("conductor/workspaces")
        let snapshot = try await CodexMetadataConnector().fetch(root: root, salt: "ephemeral-verification-\(UUID().uuidString)")
        print("REAL CODEX READ-ONLY CHECK: \(snapshot.sessions.count) Conductor-workspace sessions, \(snapshot.turns.count) recorded turns; truncated=\(snapshot.truncated)")
        guard !snapshot.sessions.isEmpty else { throw CoreCheckFailure(description: "No real session metadata returned") }
    } catch { failures += 1; print("FAIL: Real Codex metadata: \(error)") }
}
let count = CoreChecks.cases.count + SessionChecks.cases.count + MemoryChecks.cases.count
print("\(count - min(count, failures))/\(count) check groups passed")
exit(failures == 0 ? 0 : 1)
