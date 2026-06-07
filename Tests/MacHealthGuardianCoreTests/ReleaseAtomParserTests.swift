import XCTest
@testable import MacHealthGuardianCore

final class ReleaseAtomParserTests: XCTestCase {
    func testParsesFirstReleaseEntry() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <feed>
          <entry>
            <title>DDQ's Cyber Thermometer v1.2.3</title>
            <link rel="alternate" href="https://github.com/owner/repo/releases/tag/v1.2.3" />
            <content type="html">&lt;p&gt;Fixed update checks&lt;/p&gt;</content>
          </entry>
        </feed>
        """

        let entry = try XCTUnwrap(ReleaseAtomParser.parseFirstEntry(from: Data(xml.utf8)))

        XCTAssertEqual(entry.title, "DDQ's Cyber Thermometer v1.2.3")
        XCTAssertEqual(entry.htmlURL?.absoluteString, "https://github.com/owner/repo/releases/tag/v1.2.3")
        XCTAssertTrue(entry.contentHTML.contains("Fixed update checks"))
    }
}
