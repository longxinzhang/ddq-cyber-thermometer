import Foundation

public struct ReleaseAtomEntry {
    public var title: String
    public var contentHTML: String
    public var htmlURL: URL?

    public init(title: String = "", contentHTML: String = "", htmlURL: URL? = nil) {
        self.title = title
        self.contentHTML = contentHTML
        self.htmlURL = htmlURL
    }
}

public final class ReleaseAtomParser: NSObject, XMLParserDelegate {
    private var entries: [ReleaseAtomEntry] = []
    private var currentEntry: ReleaseAtomEntry?
    private var currentElement: String?
    private var buffer = ""

    public static func parseFirstEntry(from data: Data) -> ReleaseAtomEntry? {
        let parserDelegate = ReleaseAtomParser()
        let parser = XMLParser(data: data)
        parser.delegate = parserDelegate
        guard parser.parse() else { return nil }
        return parserDelegate.entries.first
    }

    public func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        if elementName == "entry" {
            currentEntry = ReleaseAtomEntry()
            return
        }

        guard currentEntry != nil else { return }

        if elementName == "title" || elementName == "content" {
            currentElement = elementName
            buffer = ""
        } else if elementName == "link",
                  attributeDict["rel"] == "alternate",
                  let href = attributeDict["href"],
                  let url = URL(string: href) {
            currentEntry?.htmlURL = url
        }
    }

    public func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard currentElement != nil else { return }
        buffer += string
    }

    public func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        guard currentEntry != nil else { return }

        if elementName == "title", currentElement == "title" {
            currentEntry?.title = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
            currentElement = nil
            buffer = ""
        } else if elementName == "content", currentElement == "content" {
            currentEntry?.contentHTML = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
            currentElement = nil
            buffer = ""
        } else if elementName == "entry", let entry = currentEntry {
            entries.append(entry)
            currentEntry = nil
        }
    }
}
