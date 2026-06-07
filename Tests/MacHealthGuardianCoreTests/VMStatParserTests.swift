import XCTest
@testable import MacHealthGuardianCore

final class VMStatParserTests: XCTestCase {
    func testParsesPageSizeAndPages() {
        let output = """
        Mach Virtual Memory Statistics: (page size of 16384 bytes)
        Pages free:                               1234.
        Pages active:                             567.
        Pages speculative:                        89.
        Pages occupied by compressor:             42.
        """

        let pages = VMStatParser.pages(from: output)

        XCTAssertEqual(VMStatParser.pageSize(from: output), 16_384)
        XCTAssertEqual(pages["Pages free"], 1_234)
        XCTAssertEqual(pages["Pages active"], 567)
        XCTAssertEqual(pages["Pages speculative"], 89)
        XCTAssertEqual(pages["Pages occupied by compressor"], 42)
    }
}
