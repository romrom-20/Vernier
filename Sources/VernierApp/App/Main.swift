import AppKit

@main struct VernierMain {
    @MainActor static func main() {
        let probes: Set<String> = ["--brief-model-probe", "--decision-model-probe", "--work-model-probe", "--contribution-model-probe"]
        if CommandLine.arguments.contains(where: { $0.hasSuffix("-model-probe") && !probes.contains($0) }) {
            fputs("Unknown model probe; normal app launch refused.\n", stderr)
            exit(2)
        }
        let app = NSApplication.shared
        let coordinator = AppCoordinator(smokeTest: CommandLine.arguments.contains("--smoke-test") || CommandLine.arguments.contains("--model-smoke-test") || CommandLine.arguments.contains(where: { probes.contains($0) }), showcase: CommandLine.arguments.contains("--showcase"))
        app.delegate = coordinator
        withExtendedLifetime(coordinator) { app.run() }
    }
}
