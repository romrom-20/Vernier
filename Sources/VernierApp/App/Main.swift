import AppKit

@main struct VernierMain {
    @MainActor static func main() {
        let app = NSApplication.shared
        let coordinator = AppCoordinator(smokeTest: CommandLine.arguments.contains("--smoke-test"), showcase: CommandLine.arguments.contains("--showcase"))
        app.delegate = coordinator
        withExtendedLifetime(coordinator) { app.run() }
    }
}
