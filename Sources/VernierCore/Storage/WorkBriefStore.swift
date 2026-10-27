import Foundation
import CSQLite

extension SessionStore {
    public func loadWorkBriefs() throws -> [WorkBrief] {
        let values: [WorkBrief?] = try rows("SELECT payload FROM work_briefs") { row in
            try? JSONDecoder().decode(WorkBrief.self, from: Data(string(row, 0).utf8))
        }
        return values.compactMap { $0 }
    }
    @discardableResult public func dismissWorkBriefMoment(sessionID: String, momentID: String, token: Int) throws -> Bool {
        var saved = false
        _ = try gate.capture(token) { contentAllowed in
            guard contentAllowed, var brief = try loadWorkBriefs().first(where: { $0.sessionID == sessionID }),
                  let index = brief.moments.firstIndex(where: { $0.id == momentID }) else { return }
            brief.moments[index].dismissed = true
            let payload = String(decoding: try JSONEncoder().encode(brief), as: UTF8.self)
            try write("UPDATE work_briefs SET payload=? WHERE session_id=?", values: [payload, sessionID])
            saved = true
        }
        return saved
    }
    @discardableResult public func saveWorkBrief(_ brief: WorkBrief, token: Int) throws -> Bool {
        var saved = false
        _ = try gate.captureBrief(token) {
            var updated = brief
            let dismissed = Set(try loadWorkBriefs().first { $0.sessionID == brief.sessionID }?.moments.filter(\.dismissed).map(\.id) ?? [])
            for index in updated.moments.indices where dismissed.contains(updated.moments[index].id) { updated.moments[index].dismissed = true }
            let data = try JSONEncoder().encode(updated)
            guard data.count <= 64_000 else { throw StoreFailure.unavailable }
            try write("INSERT INTO work_briefs VALUES(?,?) ON CONFLICT(session_id) DO UPDATE SET payload=excluded.payload",
                      values: [brief.sessionID, String(decoding: data, as: UTF8.self)])
            saved = true
        }
        return saved
    }
}
