import Foundation
import VernierCore

extension AppModel {
    var dailyOldestOffset: Int { -(retentionDays == 0 ? 3650 : max(0, retentionDays - 1)) }
    var selectedWorkDay: WorkDay {
        WorkDay(containing: Calendar.current.date(byAdding: .day, value: dailyDayOffset, to: Date()) ?? Date())
    }
    var dailyLoadKey: String {
        [selectedWorkDay.key, String(library.totalMessageCount), String(memoryEraseRevision), String(localInsightsEnabled), String(library.sessions.map { $0.updatedAt.timeIntervalSince1970 }.max() ?? 0), String(decisionRevisions.map { $0.createdAt.timeIntervalSince1970 }.max() ?? 0), String(Int(Date().timeIntervalSince1970 / 300))].joined(separator: ":")
    }
    func clearDailyParticipation() {
        dailyGeneration += 1; dailyReport = nil; dailyPreviousReport = nil; dailyLoadedKey = nil; dailyLoading = false; dailyError = nil
        dailyReflections = []; dailyReadings = []; dailyPreviousReadings = []; dailyFilter = nil; dailyHour = nil; dailyEvidenceRevision += 1; dailyConversationExpanded = false; dailyProjectsExpanded = false
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
            let readings = isolatedEnvironment ? decisionRevisions.filter { day.contains($0.createdAt) } : try await store?.decisionRevisionsCreated(in: day) ?? []
            let report = await Task.detached(priority: .utility) {
                DailyParticipation.make(day: day, input: input, sessions: snapshot.sessions, coverage: snapshot.memoryCoverage)
            }.value
            var previous: DailyParticipation?
            var previousReadings: [DecisionRevision] = []
            if dailyDayOffset == 0 && report.followUps < 3 {
                let yesterday = WorkDay(containing: Calendar.current.date(byAdding: .day, value: -1, to: day.start)!)
                let earlier = try await dayInput(day: yesterday, snapshot: snapshot)
                previousReadings = isolatedEnvironment ? decisionRevisions.filter { yesterday.contains($0.createdAt) } : try await store?.decisionRevisionsCreated(in: yesterday) ?? []
                previous = await Task.detached(priority: .utility) {
                    DailyParticipation.make(day: yesterday, input: earlier, sessions: snapshot.sessions, coverage: snapshot.memoryCoverage)
                }.value
            }
            guard !Task.isCancelled, generation == dailyGeneration, erased == memoryEraseRevision, key == dailyLoadKey else { return }
            dailyReport = report; dailyPreviousReport = previous; dailyReflections = reflections; dailyReadings = readings; dailyPreviousReadings = previousReadings; dailyLoadedKey = key
        } catch {
            guard generation == dailyGeneration, erased == memoryEraseRevision else { return }
            dailyReport = nil; dailyPreviousReport = nil; dailyReadings = []; dailyPreviousReadings = []; dailyError = "This day couldn’t be read. Your saved conversations are still here."
        }
    }
    func chooseDay(_ offset: Int) {
        dailyDayOffset = min(0, max(dailyOldestOffset, offset)); dailyReport = nil; dailyReadings = []; dailyFilter = nil; dailyHour = nil; dailyProjectsExpanded = false
        Task { await loadDailyParticipation() }
    }
    /// Every selection is a navigation event, including selecting the same category again.
    func selectDailyEvidence(action: DailyAction? = nil, hour: Date? = nil) {
        dailyFilter = action; dailyHour = hour; dailyEvidenceRevision += 1
    }
    var dailyMatchingMoments: [DailyMoment] { dailyReport?.matchingMoments(action: dailyFilter, hour: dailyHour) ?? [] }
    var dayInsights: [WorkDayInsight] {
        guard localInsightsEnabled, dailyLoadedKey == dailyLoadKey, let report = dailyReport else { return [] }
        return insights(for: report, revisions: dailyReadings)
    }
    var quickInsight: WorkDayInsight? {
        guard localInsightsEnabled, dailyLoadedKey == dailyLoadKey, let report = quickDailyReport else { return nil }
        let records = report.day == dailyReport?.day ? dailyReadings : dailyPreviousReadings
        return insights(for: report, revisions: records).first
    }
    private func insights(for report: DailyParticipation, revisions: [DecisionRevision]) -> [WorkDayInsight] {
        let historical = !report.day.contains(Date())
        let current = historical ? nil : Set(revisions.filter(isReadingCurrent).map(\.id))
        let versioned = revisions.filter { isShowcase || $0.engine.hasSuffix(" · " + DecisionGenerator.promptVersion) }
        return WorkDayInsight.make(day: report.day, activeSessionIDs: Set(report.activeSessionIDs), revisions: versioned, currentIDs: current)
    }
    func openDayInsight(_ insight: WorkDayInsight) {
        let revision = insight.revision
        guard localInsightsEnabled, library.sessions.contains(where: { $0.id == revision.sessionID }),
              dayInsights.contains(where: { $0.id == insight.id }) || quickInsight?.id == insight.id,
              insight.historical || isReadingCurrent(revision) else { return }
        if quickRecapIsPreviousDay { chooseDay(-1) }
        // Keep the exact historical target even when it is older than the normal 40-row history page.
        selectedDecisionSessionID = revision.sessionID
        if !decisionRevisions.contains(where: { $0.id == revision.id }) { decisionRevisions.append(revision) }
        selectedDecisionRevisionID = revision.id
        dailyConversationExpanded = true; workDetailExpanded = false
        dailyReadingFocusRevision += 1
        openStudio(.overview)
    }
    func dailyMomentTitle(_ moment: DailyMoment) -> String {
        guard let session = library.sessions.first(where: { $0.id == moment.sessionID }) else { return "Saved conversation" }
        return "Conversation · " + decisionTitle(session)
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
    var dailyReviewSessionID: String? {
        dailyRevisit?.sessionID ?? library.sessions.filter { dailyReport?.activeSessionIDs.contains($0.id) == true }.max { $0.updatedAt < $1.updatedAt }?.id
    }
}


extension AppModel {
    var pillRecap: DailyParticipation? {
        guard !paused, !systemSuspended, codexEnabled, conversationMemoryEnabled,
              connectionError == nil, storageError == nil else { return nil }
        return quickDailyReport
    }
    var pillTitle: String {
        guard let day = pillRecap else { return Brand.name }
        let label = day.day == WorkDay(containing: Date()) ? "Today" : day.day.start.formatted(.dateTime.month(.abbreviated).day())
        return Brand.name + " · " + label
    }
    var pillSummary: String {
        if directionToCheck != nil { return "A direction to check" }
        if pillRecap != nil {
            if let insight = quickInsight {
                switch insight.evidenceStatus {
                case .buildOnly: return "Check the original case"
                case .humanReported: return "A result you reported"
                case .agentReported: return "AI reports a test"
                case .noResult, .unknown: return "A checkpoint to revisit"
                }
            }
            return reviewingDecision ? "Reading saved work…" : "Saved exchange ready"
        }
        return capturePresenceLabel
    }
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
        // A fresh contextual result can make delegated work useful before a human follow-up exists.
        if let current, dailyLoadedKey == dailyLoadKey, !insights(for: current, revisions: dailyReadings).isEmpty { return current }
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
    func openQuickExchange(_ moment: DailyMoment) {
        guard let report = quickDailyReport, report.moments.contains(where: { $0.id == moment.id && $0.sessionID == moment.sessionID }) else { return }
        if quickRecapIsPreviousDay { chooseDay(-1) }
        openDailyMoment(moment)
    }
}
