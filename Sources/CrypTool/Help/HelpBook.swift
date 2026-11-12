import Foundation

/// One entry of the table of contents (cryptool.hhc). Groups have `children`, pages a `file`.
struct HelpTOCNode: Identifiable, Hashable {
    let id: Int
    let title: String
    let file: String?
    var children: [HelpTOCNode]?
}

/// One hit of the full-text search.
struct HelpSearchResult: Identifiable, Hashable {
    var id: String { file }
    let file: String
    let title: String
    let hits: Int
}

/// Access to the converted CT1 help files (Resources/Help/de, UTF-8).
enum HelpBook {
    static let startPage = "hidd_tipps_and_tricks.html"
    static let indexPage = "main_index.html"
    static let scenariosPage = "hid_hilfe_szenarien.html"

    /// Folder containing the help pages, or nil if the help is not bundled.
    static var rootURL: URL? { Resources.url("Help/de") }

    static func url(for file: String) -> URL? {
        guard let root = rootURL, !file.isEmpty else { return nil }
        let (path, fragment) = splitFragment(file)
        let u = root.appendingPathComponent(path)
        guard FileManager.default.fileExists(atPath: u.path) else { return nil }
        guard let fragment, var c = URLComponents(url: u, resolvingAgainstBaseURL: false) else { return u }
        c.fragment = fragment
        return c.url ?? u
    }

    /// File name (relative to the help root) of a file URL inside the help, else nil.
    static func file(for url: URL) -> String? {
        guard url.isFileURL, let root = rootURL?.standardizedFileURL.path else { return nil }
        let p = url.standardizedFileURL.path
        guard p.hasPrefix(root + "/") else { return nil }
        return String(p.dropFirst(root.count + 1))
    }

    private static func splitFragment(_ s: String) -> (String, String?) {
        guard let i = s.firstIndex(of: "#") else { return (s, nil) }
        return (String(s[..<i]), String(s[s.index(after: i)...]))
    }

    // MARK: - Table of contents

    /// Parses the HTML Help sitemap (nested <UL>/<LI>/<OBJECT type="text/sitemap"> lists).
    static func loadTOC() -> [HelpTOCNode] {
        guard let root = rootURL,
              let text = try? String(contentsOf: root.appendingPathComponent("cryptool.hhc"), encoding: .utf8)
        else { return [] }
        return parseSitemap(text)
    }

    static func parseSitemap(_ text: String) -> [HelpTOCNode] {
        final class Builder {
            let title: String, file: String?
            var children: [Builder] = []
            var hasList = false
            init(title: String, file: String?) { self.title = title; self.file = file }
        }
        let tag = try! NSRegularExpression(pattern: "<(/?)(ul|object|param)\\b([^>]*)>", options: [.caseInsensitive])
        let ns = text as NSString
        var levels: [[Builder]] = [[]]
        var owners: [Builder?] = []
        var inObject = false
        var name: String?, local: String?

        for m in tag.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
            let closing = ns.substring(with: m.range(at: 1)) == "/"
            let kind = ns.substring(with: m.range(at: 2)).lowercased()
            let attrs = ns.substring(with: m.range(at: 3))
            switch (kind, closing) {
            case ("ul", false):
                owners.append(levels[levels.count - 1].last)
                levels.append([])
            case ("ul", true):
                guard levels.count > 1 else { continue }
                let items = levels.removeLast()
                if let owner = owners.removeLast() {
                    owner.children.append(contentsOf: items)
                    owner.hasList = true
                } else {
                    levels[levels.count - 1].append(contentsOf: items)
                }
            case ("object", false):
                inObject = attribute("type", in: attrs)?.lowercased() == "text/sitemap"
                name = nil; local = nil
            case ("object", true):
                if inObject, let n = name {
                    levels[levels.count - 1].append(Builder(title: n, file: local))
                }
                inObject = false
            case ("param", false) where inObject:
                switch attribute("name", in: attrs)?.lowercased() {
                case "name": name = attribute("value", in: attrs).map(decodeEntities)
                case "local": local = attribute("value", in: attrs)
                default: break
                }
            default:
                break
            }
        }
        while levels.count > 1 { let items = levels.removeLast(); levels[levels.count - 1].append(contentsOf: items) }

        var nextID = 0
        func convert(_ b: Builder) -> HelpTOCNode {
            nextID += 1
            let id = nextID
            let kids = b.hasList || !b.children.isEmpty ? b.children.map(convert) : nil
            return HelpTOCNode(id: id, title: b.title, file: b.file, children: kids)
        }
        return levels[0].map(convert)
    }

    private static func attribute(_ name: String, in attrs: String) -> String? {
        let re = try! NSRegularExpression(pattern: "\\b\(name)\\s*=\\s*(?:\"([^\"]*)\"|'([^']*)'|([^\\s>]+))",
                                          options: [.caseInsensitive])
        let ns = attrs as NSString
        guard let m = re.firstMatch(in: attrs, range: NSRange(location: 0, length: ns.length)) else { return nil }
        for i in 1...3 where m.range(at: i).location != NSNotFound {
            return ns.substring(with: m.range(at: i))
        }
        return nil
    }

    // MARK: - Text extraction

    private static let namedEntities: [String: String] = [
        "nbsp": " ", "amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'",
        "auml": "ä", "ouml": "ö", "uuml": "ü", "Auml": "Ä", "Ouml": "Ö", "Uuml": "Ü", "szlig": "ß",
        "aring": "å", "eacute": "é", "egrave": "è", "agrave": "à", "acute": "´",
        "reg": "®", "copy": "©", "sect": "§", "deg": "°", "middot": "·", "times": "×", "divide": "÷",
        "ndash": "–", "mdash": "—", "hellip": "…", "bdquo": "„", "ldquo": "“", "rdquo": "”",
        "lsquo": "‘", "rsquo": "’", "laquo": "«", "raquo": "»", "frac14": "¼", "frac12": "½",
        "rarr": "→", "larr": "←", "le": "≤", "ge": "≥", "ne": "≠", "equiv": "≡", "cong": "≅",
        "isin": "∈", "Phi": "Φ", "phi": "φ", "euro": "€",
    ]

    /// Decodes named and numeric character references (numeric 128–159 as Windows-1252, like browsers).
    static func decodeEntities(_ s: String) -> String {
        guard s.contains("&") else { return s }
        var out = ""
        out.reserveCapacity(s.count)
        var i = s.startIndex
        while i < s.endIndex {
            let c = s[i]
            if c == "&", let semi = s[i...].prefix(12).firstIndex(of: ";") {
                let body = s[s.index(after: i)..<semi]
                var replacement: String?
                if body.hasPrefix("#") {
                    let num = body.dropFirst()
                    let value = num.hasPrefix("x") || num.hasPrefix("X") ? UInt32(num.dropFirst(), radix: 16) : UInt32(num)
                    if let v = value {
                        if (128...159).contains(v), let ch = String(bytes: [UInt8(v)], encoding: .windowsCP1252) {
                            replacement = ch
                        } else if let scalar = Unicode.Scalar(v) {
                            replacement = String(Character(scalar))
                        }
                    }
                } else {
                    replacement = namedEntities[String(body)]
                }
                if let r = replacement {
                    out += r
                    i = s.index(after: semi)
                    continue
                }
            }
            out.append(c)
            i = s.index(after: i)
        }
        return out
    }

    private static let titleRegex = try! NSRegularExpression(pattern: "<title[^>]*>(.*?)</title>", options: [.caseInsensitive, .dotMatchesLineSeparators])
    private static let headingRegex = try! NSRegularExpression(pattern: "<h[1-4][^>]*>(.*?)</h[1-4]>", options: [.caseInsensitive, .dotMatchesLineSeparators])
    private static let dropRegex = try! NSRegularExpression(pattern: "<!--.*?-->|<(script|style|head)\\b.*?</\\1\\s*>", options: [.caseInsensitive, .dotMatchesLineSeparators])
    private static let tagRegex = try! NSRegularExpression(pattern: "<[^>]*>", options: [])
    private static let spaceRegex = try! NSRegularExpression(pattern: "\\s+", options: [])

    private static func replace(_ re: NSRegularExpression, in s: String, with t: String) -> String {
        re.stringByReplacingMatches(in: s, range: NSRange(location: 0, length: (s as NSString).length), withTemplate: t)
    }

    private static func firstGroup(_ re: NSRegularExpression, in s: String) -> String? {
        let ns = s as NSString
        guard let m = re.firstMatch(in: s, range: NSRange(location: 0, length: ns.length)) else { return nil }
        return ns.substring(with: m.range(at: 1))
    }

    /// Plain text of an HTML fragment (tags stripped, entities decoded, whitespace collapsed).
    static func plainText(_ html: String) -> String {
        var s = replace(dropRegex, in: html, with: " ")
        s = replace(tagRegex, in: s, with: " ")
        s = decodeEntities(s)
        return replace(spaceRegex, in: s, with: " ").trimmingCharacters(in: .whitespaces)
    }

    static func title(ofHTML html: String) -> String? {
        for re in [titleRegex, headingRegex] {
            if let t = firstGroup(re, in: html) {
                let p = plainText(t)
                if !p.isEmpty { return p }
            }
        }
        return nil
    }
}

/// Simple in-memory full-text index over all help pages (built lazily off the main thread).
final class HelpSearchIndex: @unchecked Sendable {
    struct Page {
        let file: String
        let title: String
        let titleLower: String
        let text: String   // lower-cased plain text incl. title and keywords
    }

    private let lock = NSLock()
    private var pages: [Page]?

    private func loadPages() -> [Page] {
        lock.lock(); defer { lock.unlock() }
        if let pages { return pages }
        var result: [Page] = []
        if let root = HelpBook.rootURL,
           let names = try? FileManager.default.contentsOfDirectory(atPath: root.path) {
            let keywordRegex = try! NSRegularExpression(pattern: "<meta\\s+name=\"keywords\"\\s+content=\"([^\"]*)\"", options: [.caseInsensitive])
            for name in names.sorted() where name.hasSuffix(".html") || name.hasSuffix(".htm") {
                if name == "template.html" { continue }
                guard let html = try? String(contentsOf: root.appendingPathComponent(name), encoding: .utf8) else { continue }
                let title = HelpBook.title(ofHTML: html) ?? name
                let ns = html as NSString
                let keywords = keywordRegex.firstMatch(in: html, range: NSRange(location: 0, length: ns.length))
                    .map { HelpBook.decodeEntities(ns.substring(with: $0.range(at: 1))) } ?? ""
                let text = "\(title) \(keywords) \(HelpBook.plainText(html))".lowercased()
                result.append(Page(file: name, title: title, titleLower: title.lowercased(), text: text))
            }
        }
        pages = result
        return result
    }

    /// Case-insensitive search for all words of `query`; ranked by total hit count
    /// (title hits weigh more). Pages must contain every word.
    func search(_ query: String, limit: Int = 200) -> [HelpSearchResult] {
        let words = query.lowercased()
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)
            .filter { !$0.isEmpty }
        guard !words.isEmpty else { return [] }
        var results: [HelpSearchResult] = []
        for page in loadPages() {
            var total = 0
            var all = true
            for w in words {
                let n = Self.count(w, in: page.text)
                if n == 0 { all = false; break }
                total += n + 10 * Self.count(w, in: page.titleLower)
            }
            if all { results.append(HelpSearchResult(file: page.file, title: page.title, hits: total)) }
        }
        results.sort { $0.hits != $1.hits ? $0.hits > $1.hits : $0.title.localizedCompare($1.title) == .orderedAscending }
        return Array(results.prefix(limit))
    }

    private static func count(_ needle: String, in haystack: String) -> Int {
        var n = 0
        var range = haystack.startIndex..<haystack.endIndex
        while let r = haystack.range(of: needle, options: [.literal], range: range) {
            n += 1
            range = r.upperBound..<haystack.endIndex
        }
        return n
    }
}
