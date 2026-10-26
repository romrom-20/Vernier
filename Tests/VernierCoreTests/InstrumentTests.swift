import XCTest
import VernierChecks

final class InstrumentTests: XCTestCase {
    func testCoreInvariants() {
        for (name, check) in CoreChecks.cases {
            do { try check() } catch { XCTFail("\(name): \(error)") }
        }
    }
    func testSessionMetadataAndPrivacy() async {
        for (name, check) in SessionChecks.cases + MemoryChecks.cases {
            do { try await check() } catch { XCTFail("\(name): \(error)") }
        }
    }
}
