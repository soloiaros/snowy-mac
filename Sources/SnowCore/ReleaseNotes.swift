import Foundation

public struct ReleaseNote: Identifiable, Equatable, Sendable, Codable {
    public let id: String
    public let version: String
    public let title: String
    public let publishedAt: Date?
    public let highlights: [String]
    public let htmlURL: URL?

    public init(id: String, version: String, title: String, publishedAt: Date?, highlights: [String], htmlURL: URL?) {
        self.id = id
        self.version = version
        self.title = title
        self.publishedAt = publishedAt
        self.highlights = highlights
        self.htmlURL = htmlURL
    }
}

public struct GitHubRelease: Decodable, Sendable {
    public let tagName: String
    public let name: String?
    public let body: String?
    public let publishedAt: String?
    public let draft: Bool?
    public let prerelease: Bool?
    public let htmlUrl: String?

    public init(tagName: String, name: String? = nil, body: String? = nil, publishedAt: String? = nil,
                draft: Bool? = nil, prerelease: Bool? = nil, htmlUrl: String? = nil) {
        self.tagName = tagName
        self.name = name
        self.body = body
        self.publishedAt = publishedAt
        self.draft = draft
        self.prerelease = prerelease
        self.htmlUrl = htmlUrl
    }

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case body
        case publishedAt = "published_at"
        case draft
        case prerelease
        case htmlUrl = "html_url"
    }
}

public enum ReleaseNotesParser {
    public static let boilerplatePrefixes: [String] = [
        "snowy brings interactive snow",
        "open the dmg",
        "download the dmg",
        "requires apple silicon",
        "requires macos",
        "sha-256",
        "this beta uses local",
        "if macos blocks",
        "going forward",
        "if finder icon anchors",
        "open its snowflake menu",
        "eject the disk image",
        "quit an older copy"
    ]

    public static func parse(release: GitHubRelease) -> ReleaseNote? {
        let tag = release.tagName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !tag.isEmpty else { return nil }
        if tag.lowercased().contains("windows") { return nil }
        if release.draft == true { return nil }

        let version = tag.hasPrefix("v") || tag.hasPrefix("V") ? String(tag.dropFirst()) : tag
        let title = (release.name?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
            ? release.name!
            : "Snowy \(tag)"

        let publishedAt: Date?
        if let pubStr = release.publishedAt {
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = iso.date(from: pubStr) {
                publishedAt = date
            } else {
                iso.formatOptions = [.withInternetDateTime]
                publishedAt = iso.date(from: pubStr)
            }
        } else {
            publishedAt = nil
        }

        let body = release.body ?? ""
        let highlights = extractHighlights(from: body)

        let htmlURL = release.htmlUrl.flatMap { URL(string: $0) }
            ?? URL(string: "https://github.com/soloiaros/snowy-mac/releases/tag/\(tag)")

        return ReleaseNote(
            id: tag,
            version: version,
            title: title,
            publishedAt: publishedAt,
            highlights: highlights,
            htmlURL: htmlURL
        )
    }

    public static func extractHighlights(from body: String) -> [String] {
        let lines = body.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        var bullets: [String] = []
        var paragraphs: [String] = []

        for line in lines {
            let lower = line.lowercased()
            if boilerplatePrefixes.contains(where: { lower.hasPrefix($0) }) {
                continue
            }

            if line.hasPrefix("- ") {
                bullets.append(String(line.dropFirst(2)).trimmingCharacters(in: .whitespaces))
            } else if line.hasPrefix("* ") {
                bullets.append(String(line.dropFirst(2)).trimmingCharacters(in: .whitespaces))
            } else if line.hasPrefix("• ") {
                bullets.append(String(line.dropFirst(2)).trimmingCharacters(in: .whitespaces))
            } else if bullets.isEmpty {
                paragraphs.append(line)
            }
        }

        if !bullets.isEmpty {
            return bullets
        } else if !paragraphs.isEmpty {
            return [paragraphs.joined(separator: " ")]
        } else {
            return ["Initial release of Snowy for macOS."]
        }
    }
}

extension ReleaseNote {
    public static let bundledReleases: [ReleaseNote] = [
        ReleaseNote(
            id: "v0.11.0",
            version: "0.11.0",
            title: "Snowy v0.11.0",
            publishedAt: ISO8601DateFormatter().date(from: "2026-11-12T00:00:00Z"),
            highlights: [
                "Adds in-app release notes viewer and update buttons in the Snowy settings window.",
                "Adds Stage Manager support: snow now accumulates and slides along the tilted 3D perspective edges of strip thumbnails.",
                "Aligns snow accumulation contours with window borders and the bottom Dock without clipping.",
                "Maintains consistent Stage Manager thumbnail tilts across all MacBook and external display resolutions."
            ],
            htmlURL: URL(string: "https://github.com/soloiaros/snowy-mac/releases/tag/v0.11.0")
        ),
        ReleaseNote(
            id: "v0.10.1",
            version: "0.10.1",
            title: "Snowy v0.10.1",
            publishedAt: ISO8601DateFormatter().date(from: "2026-11-10T23:59:45Z"),
            highlights: [
                "Fixes an issue where the ChatGPT desktop companion overlay could block snow from falling on the right side of the screen.",
                "**Open Snowy…** brings up Wallpapers, Decorations, and a Guide with a replayable walkthrough.",
                "Import wallpapers in batches and apply them to one or all displays. Two original winter wallpapers are included.",
                "Pick a pixel-art preset or build a custom scene. Props catch snow, snap to the desktop edge or Dock, and can slide when swept.",
                "Hang string lights from display edges, widgets, or supported Finder icons. Lights respond to wind and cursor crossings. Finder icon anchors use optional Accessibility access."
            ],
            htmlURL: URL(string: "https://github.com/soloiaros/snowy-mac/releases/tag/v0.10.1")
        ),
        ReleaseNote(
            id: "v0.10.0",
            version: "0.10.0",
            title: "Snowy 0.10.0 Beta",
            publishedAt: ISO8601DateFormatter().date(from: "2026-11-05T18:11:30Z"),
            highlights: [
                "**Open Snowy…** brings up Wallpapers, Decorations, and a Guide with a replayable walkthrough.",
                "Import wallpapers in batches and apply them to one or all displays. Two original winter wallpapers are included.",
                "Pick a pixel-art preset or build a custom scene. Props catch snow, snap to the desktop edge or Dock, and can slide when swept.",
                "Hang string lights from display edges, widgets, or supported Finder icons. Lights respond to wind and cursor crossings. Finder icon anchors use optional Accessibility access."
            ],
            htmlURL: URL(string: "https://github.com/soloiaros/snowy-mac/releases/tag/v0.10.0")
        ),
        ReleaseNote(
            id: "v0.9.3",
            version: "0.9.3",
            title: "Snowy 0.9.3 Beta",
            publishedAt: ISO8601DateFormatter().date(from: "2026-11-05T12:50:17Z"),
            highlights: [
                "**Drop some coins** at the top of the snowflake menu opens Polar checkout with an editable $4.99 USD contribution.",
                "The website shows a short first-launch note when the DMG download starts."
            ],
            htmlURL: URL(string: "https://github.com/soloiaros/snowy-mac/releases/tag/v0.9.3")
        ),
        ReleaseNote(
            id: "v0.9.2",
            version: "0.9.2",
            title: "Snowy 0.9.2",
            publishedAt: ISO8601DateFormatter().date(from: "2026-11-05T08:00:32Z"),
            highlights: [
                "The first-launch walkthrough now uses a standard macOS window with a framed preview on the left and short instructions on the right. It covers settled snow, sweeping and wind, and the snowflake menu."
            ],
            htmlURL: URL(string: "https://github.com/soloiaros/snowy-mac/releases/tag/v0.9.2")
        ),
        ReleaseNote(
            id: "v0.9.1",
            version: "0.9.1",
            title: "Snowy 0.9.1",
            publishedAt: ISO8601DateFormatter().date(from: "2026-11-05T07:08:47Z"),
            highlights: [
                "The redesigned installer includes a winter background and a clear drag-to-Applications layout. A short welcome window on first launch shows how to sweep snow, adjust the wind, and use the snowflake menu. Closing or skipping it marks it seen, and users with saved Snowy settings skip it."
            ],
            htmlURL: URL(string: "https://github.com/soloiaros/snowy-mac/releases/tag/v0.9.1")
        ),
        ReleaseNote(
            id: "v0.9.0",
            version: "0.9.0",
            title: "Snowy 0.9.0",
            publishedAt: ISO8601DateFormatter().date(from: "2026-11-04T21:35:20Z"),
            highlights: [
                "Initial release of Snowy for macOS."
            ],
            htmlURL: URL(string: "https://github.com/soloiaros/snowy-mac/releases/tag/v0.9.0")
        )
    ]
}
