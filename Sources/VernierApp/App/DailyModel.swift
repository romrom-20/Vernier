import Foundation
import VernierCore

extension AppModel {
    var dailyOldestOffset: Int { -(retentionDays == 0 ? 3650 : max(0, retentionDays - 1)) }
    var selectedWorkDay: WorkDay {
        WorkDay(containing: Calendar.current.date(byAdding: .day, value: dailyDayOffset, to: Date()) ?? Date())
    }
    var dailyLoadKey: String {
        [selectedWorkDay.key, String(library.totalMessageCount), String(memoryEraseRevision), String(localInsightsEnabled), String(library.sessions.map { $0.updatedAt.timeIntervalSince1970 }.max() ?? 0), String(Int(Date().timeIntervalSince1970 / 300))].joined(separator: ":")
    }
    func clearDailyParticipation() {
        dailyGeneration += 1; dailyReport = nil; dailyPreviousReport = nil; dailyLoadedKey = nil; dailyLoading = false; dailyError = nil
        dailyReflections = []; dailyFilter = nil; dailyConversationExpanded = false
    }
    func loadDailyParticipation() async {
        let key = dailyLoadKey
        guard key != dailyLoadedKey else { return }
        dailyGeneration += 1
        let generation = dailyGeneration, erased = memoryEraseRevision, day = selectedWorkDay, snapshot = library
        guard isolatedEnvironment || localInsightsEnabled else { dailyReport = nil; dailyPreviousReport = nil; return }
        dailyLoading = true; dailyError = nil
        defer { if generation == dailyGeneration { dailyLoading = false } }
        do {
            let input = try await dayInput(day: day, snapshot: snapshot)
            let reflections = isolatedEnvironment ? [] : try await store?.dailyReflections() ?? []
            let report = await Task.detached(priority: .utility) {
                DailyParticipation.make(day: day, input: input, sessions: snapshot.sessions, coverage: snapshot.memoryCoverage)
            }.value
            var previous: DailyParticipation?
            if dailyDayOffset == 0 && report.followUps < 3 {
                let yesterday = WorkDay(containing: Calendar.current.date(byAdding: .day, value: -1, to: day.start)!)
                let earlier = try await dayInput(day: yesterday, snapshot: snapshot)
                previous = await Task.detached(priority: .utility) {
                    DailyParticipation.make(day: yesterday, input: earlier, sessions: snapshot.sessions, coverage: snapshot.memoryCoverage)
                }.value
            }
            guard !Task.isCancelled, generation == dailyGeneration, erased == memoryEraseRevision, key == dailyLoadKey else { return }
            dailyReport = report; dailyPreviousReport = previous; dailyReflections = reflections; dailyLoadedKey = key
        } catch {
            guard generation == dailyGeneration, erased == memoryEraseRevision else { return }
            dailyReport = nil; dailyPreviousReport = nil; dailyError = "This day couldn’t be read. Your saved conversations are still here."
        }
    }
    func chooseDay(_ offset: Int) {
        dailyDayOffset = min(0, max(dailyOldestOffset, offset)); dailyReport = nil; dailyFilter = nil
        Task { await loadDailyParticipation() }
    }
    var dailyReflection: DailyReflection? { dailyReflections.first { $0.dayKey == selectedWorkDay.key } }
    func saveDailyCheckIn(day: WorkDay, clarity: DailyReflection.Clarity?, energy: DailyReflection.Energy?, note: String) async -> Bool {
        guard !isolatedEnvironment, let store, note.count <= 500 else { return false }
        let erased = memoryEraseRevision
        do {
            let epoch = await store.dailyReflectionGeneration()
            guard erased == memoryEraseRevision else { return false }
            try await store.saveDailyReflection(.init(day: day, clarity: clarity, energy: energy, note: note.trimmingCharacters(in: .whitespacesAndNewlines)), expectedGeneration: epoch)
            let saved = try await store.dailyReflections()
            guard erased == memoryEraseRevision else { return false }
            dailyReflections = saved
            return true
        } catch { guard erased == memoryEraseRevision else { return false }; dailyError = "Your check-in couldn’t be saved."; return false }
    }
    func openDailyMoment(_ moment: DailyMoment) {
        dailyConversationExpanded = false
        selectDecisionSession(moment.sessionID)
        selectedDecisionRevisionID = decisionRevisions.first { $0.sessionID == moment.sessionID && $0.anchorMessageID == moment.id && $0.reading != nil }?.id
        briefSessionID = moment.sessionID; storyFocusID = moment.id; storyFocusRevision += 1
        workDetailExpanded = true; openStudio(.overview)
    }
    func dailyProjectTitle(_ project: DailyProject) -> String {
        let session = project.sessionIDs.compactMap { id in library.sessions.first { $0.id == id } }.first
        return session.map { decisionTitle($0) } ?? "Saved work"
    }
    var dailyRevisit: DailyMoment? {
        guard let report = dailyReport else { return nil }
        if report.longestContinuation.count >= 3 { return report.longestContinuation.last }
        if report.repairRequests.count >= 2 { return report.repairRequests.last }
        if let checked = report.moments.last(where: { $0.action == .checked }) { return checked }
        return report.moments.last { $0.action == .continued } ?? report.moments.last
    }
}


extension AppModel {
    private func dayInput(day: WorkDay, snapshot: SessionLibrary) async throws -> DailyInput {
        if !isolatedEnvironment {
            guard let store else { return DailyInput(messages: [], datedTotal: 0, undatedTotal: 0) }
            return try await store.dailyInput(day: day)
        }
        let values = snapshot.messages.filter { $0.sourceAt.map(day.contains) == true }
        let preceding = Dictionary(grouping: snapshot.messages.filter { ($0.sourceAt ?? .distantFuture) < day.start }, by: \.sessionID).values.compactMap { $0.max { ($0.sourceAt ?? .distantPast) < ($1.sourceAt ?? .distantPast) } }
        return DailyInput(messages: values, datedTotal: values.count, undatedTotal: snapshot.messages.filter { $0.sourceAt == nil }.count, precedingContext: preceding)
    }
    var quickDailyReport: DailyParticipation? {
        guard localInsightsEnabled else { return nil }
        let current = dailyReport.flatMap { $0.day == selectedWorkDay ? $0 : nil }
        let yesterday = WorkDay(containing: Calendar.current.date(byAdding: .day, value: -1, to: Date())!)
        let previous = dailyPreviousReport.flatMap { $0.day == yesterday && $0.followUps > 0 ? $0 : nil }
        if dailyDayOffset == 0, let previous, (current?.followUps ?? 0) == 0 || ((current?.followUps ?? 0) < 3 && previous.followUps >= 3) { return previous }
        return current.flatMap { $0.followUps > 0 ? $0 : nil }
    }
    var quickRecapIsPreviousDay: Bool { dailyDayOffset == 0 && quickDailyReport?.day != nil && quickDailyReport?.day != selectedWorkDay }
    var quickRecapButtonTitle: String {
        if !codexEnabled && library.totalMessageCount == 0 { return "Connect Codex" }
        if !conversationMemoryEnabled && library.totalMessageCount == 0 { return "Connect saved chats" }
        if !localInsightsEnabled { return "Open review settings" }
        if directionToCheck != nil { return "Look at this choice" }
        if quickRecapIsPreviousDay || dailyDayOffset == -1 { return "Open yesterday’s recap" }
        return dailyDayOffset == 0 ? "Open today’s recap" : "Open this recap"
    }
    func openQuickRecap() {
        if !codexEnabled && library.totalMessageCount == 0 { openStudio(.connections); return }
        if !conversationMemoryEnabled && library.totalMessageCount == 0 { openStudio(.connections); return }
        if directionToCheck != nil { openDirectionCheck(); return }
        if quickRecapIsPreviousDay { chooseDay(-1) }
        if !localInsightsEnabled { dailyConversationExpanded = true }
        openStudio(.overview)
    }
}
