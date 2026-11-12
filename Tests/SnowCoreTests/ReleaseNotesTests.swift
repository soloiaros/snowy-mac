import XCTest
@testable import SnowCore

final class ReleaseNotesTests: XCTestCase {
    func testParsingReleaseWithBulletsFiltersBoilerplate() {
        let body = """
        Snowy brings interactive snow to window edges, desktop widgets, Spotlight, and a bottom-positioned Dock.

        - Fixes an issue where the ChatGPT desktop companion overlay could block snow.
        - **Open Snowy…** brings up Wallpapers, Decorations, and a Guide with a replayable walkthrough.

        Open the DMG and drag **Snowy.app** onto **Applications**.
        Requires Apple Silicon and macOS 14 or later.
        SHA-256 checksums are attached beside the DMG and ZIP files.
        This beta uses local code signing.
        """

        let release = GitHubRelease(
            tagName: "v0.10.1",
            name: "Snowy v0.10.1",
            body: body,
            publishedAt: "2026-11-10T23:59:45Z",
            draft: false,
            prerelease: false,
            htmlUrl: "https://github.com/soloiaros/snowy-mac/releases/tag/v0.10.1"
        )

        let parsed = ReleaseNotesParser.parse(release: release)
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.id, "v0.10.1")
        XCTAssertEqual(parsed?.version, "0.10.1")
        XCTAssertEqual(parsed?.title, "Snowy v0.10.1")
        XCTAssertEqual(parsed?.highlights.count, 2)
        XCTAssertEqual(parsed?.highlights[0], "Fixes an issue where the ChatGPT desktop companion overlay could block snow.")
        XCTAssertEqual(parsed?.highlights[1], "**Open Snowy…** brings up Wallpapers, Decorations, and a Guide with a replayable walkthrough.")
    }

    func testWindowsReleasesAreIgnored() {
        let release = GitHubRelease(
            tagName: "windows-v0.1.4.0",
            name: "Snowy 0.1.4 Windows Beta",
            body: "Windows release notes",
            publishedAt: "2026-11-08T19:04:18Z"
        )
        let parsed = ReleaseNotesParser.parse(release: release)
        XCTAssertNil(parsed)
    }

    func testDraftReleasesAreIgnored() {
        let release = GitHubRelease(
            tagName: "v0.11.0",
            name: "Draft Release",
            body: "- New stuff",
            publishedAt: "2026-11-12T00:00:00Z",
            draft: true
        )
        let parsed = ReleaseNotesParser.parse(release: release)
        XCTAssertNil(parsed)
    }

    func testParagraphWithoutBulletsIsExtracted() {
        let body = """
        Snowy brings interactive snow to window edges, desktop widgets, Spotlight, and a bottom-positioned Dock.

        The first-launch walkthrough now uses a standard macOS window with a framed preview.

        Open the DMG and drag **Snowy.app** onto **Applications**.
        """

        let release = GitHubRelease(
            tagName: "v0.9.2",
            name: "Snowy 0.9.2",
            body: body,
            publishedAt: "2026-11-05T08:00:32Z"
        )

        let parsed = ReleaseNotesParser.parse(release: release)
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.highlights, ["The first-launch walkthrough now uses a standard macOS window with a framed preview."])
    }

    func testBundledReleasesArePopulated() {
        XCTAssertFalse(ReleaseNote.bundledReleases.isEmpty)
        XCTAssertEqual(ReleaseNote.bundledReleases.first?.version, "0.11.0")
    }
}
