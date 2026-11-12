import AppKit
import SnowCore
import SwiftUI

@MainActor
final class ReleaseNotesProvider: ObservableObject {
    @Published private(set) var releases: [ReleaseNote]
    @Published private(set) var isLoading = false
    @Published private(set) var lastError: String?

    private static let cacheKey = "app.snowy.cachedReleaseNotes"
    private static let githubAPIURL = URL(string: "https://api.github.com/repos/soloiaros/snowy-mac/releases?per_page=30")!

    init(initialReleases: [ReleaseNote]? = nil) {
        if let initialReleases {
            self.releases = initialReleases
        } else if let cached = Self.loadCachedReleases(), !cached.isEmpty {
            self.releases = cached
        } else {
            self.releases = ReleaseNote.bundledReleases
        }
    }

    func fetchLatestReleases() async {
        guard !isLoading else { return }
        isLoading = true
        lastError = nil
        defer { isLoading = false }

        do {
            var request = URLRequest(url: Self.githubAPIURL)
            request.timeoutInterval = 10
            request.setValue("Snowy-macOS", forHTTPHeaderField: "User-Agent")
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return
            }

            let decoder = JSONDecoder()
            let rawReleases = try decoder.decode([GitHubRelease].self, from: data)
            let parsed = rawReleases.compactMap { ReleaseNotesParser.parse(release: $0) }
            if !parsed.isEmpty {
                self.releases = parsed
                Self.saveCachedReleases(parsed)
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    private static func loadCachedReleases() -> [ReleaseNote]? {
        guard let data = UserDefaults.standard.data(forKey: cacheKey) else { return nil }
        return try? JSONDecoder().decode([ReleaseNote].self, from: data)
    }

    private static func saveCachedReleases(_ releases: [ReleaseNote]) {
        guard let data = try? JSONEncoder().encode(releases) else { return }
        UserDefaults.standard.set(data, forKey: cacheKey)
    }
}

struct ReleaseNotesSheetView: View {
    @ObservedObject var provider: ReleaseNotesProvider
    let currentVersion: String
    let availableVersion: String?
    var onUpdate: (() -> Void)?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            if let availableVersion {
                updateBanner(version: availableVersion)
                Divider()
            }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    ForEach(provider.releases) { release in
                        releaseCard(release)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }

            Divider()
            footer
        }
        .frame(width: 540, height: 500)
        .background(Color(nsColor: .windowBackgroundColor))
        .task {
            await provider.fetchLatestReleases()
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Color.accentColor)

            VStack(alignment: .leading, spacing: 2) {
                Text("Release Notes")
                    .font(.title3.weight(.bold))
                Text("What's new in Snowy")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Done") {
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
            .keyboardShortcut(.cancelAction)
            .controlSize(.regular)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private func updateBanner(version: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 20))
                .foregroundStyle(Color.accentColor)

            VStack(alignment: .leading, spacing: 2) {
                Text("Snowy \(version) is available")
                    .font(.system(size: 13, weight: .semibold))
                Text("You are currently on version \(cleanVersion(currentVersion))")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let onUpdate {
                Button("Update Now") {
                    dismiss()
                    onUpdate()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.accentColor.opacity(0.12))
    }

    private func releaseCard(_ release: ReleaseNote) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(release.version.hasPrefix("v") ? release.version : "v\(release.version)")
                    .font(.system(size: 15, weight: .bold))

                let isCurrent = isMatchingVersion(release.version, currentVersion)
                let isUpdate = availableVersion != nil && isMatchingVersion(release.version, availableVersion!)

                if isUpdate {
                    Text("Update Available")
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor, in: Capsule())
                        .foregroundStyle(.white)
                } else if isCurrent {
                    Text("Current")
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.2), in: Capsule())
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let date = release.publishedAt {
                    Text(date, style: .date)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(release.highlights.enumerated()), id: \.offset) { _, highlight in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.accentColor)
                        Text(LocalizedStringKey(highlight))
                            .font(.system(size: 12))
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            if let url = release.htmlURL {
                HStack {
                    Spacer()
                    Link(destination: url) {
                        HStack(spacing: 4) {
                            Text("View on GitHub")
                            Image(systemName: "arrow.up.right")
                        }
                        .font(.system(size: 11, weight: .medium))
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(14)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.6), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color(nsColor: .separatorColor).opacity(0.6), lineWidth: 1)
        }
    }

    private var footer: some View {
        HStack {
            if provider.isLoading {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text("Checking GitHub…")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Link("All Releases on GitHub",
                 destination: URL(string: "https://github.com/soloiaros/snowy-mac/releases")!)
                .font(.system(size: 11))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    private func cleanVersion(_ v: String) -> String {
        v.hasPrefix("v") || v.hasPrefix("V") ? String(v.dropFirst()) : v
    }

    private func isMatchingVersion(_ a: String, _ b: String) -> Bool {
        cleanVersion(a) == cleanVersion(b)
    }
}
