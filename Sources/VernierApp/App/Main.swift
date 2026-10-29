import AppKit

@main struct VernierMain {
    @MainActor static func main() {
        let app = NSApplication.shared
        let coordinator = AppCoordinator(smokeTest: (CommandLine.arguments.contains("--smoke-test") || CommandLine.arguments.contains("--model-smoke-test")) || CommandLine.arguments.contains("--brief-model-probe") || CommandLine.arguments.contains("--decision-model-probe") || CommandLine.arguments.contains("--work-model-probe"), showcase: CommandLine.arguments.contains("--showcase"))
        app.delegate = coordinator
        withExtendedLifetime(coordinator) { app.run() }
    }
}
