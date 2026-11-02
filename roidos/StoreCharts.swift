// SPDX-License-Identifier: GPL-2.0-or-later
// Added for RoidOS: Google Play's top charts, so the Store shows every app and game by category rather
// than a fixed shelf, and a plain word before a paid app is attempted.
import SwiftUI

// MARK: - the charts, from Play

extension PlayAPI {
    struct ChartCategory: Identifiable, Hashable {
        let id: String        // Play's category ID
        let title: String
        let symbol: String
    }

    enum ChartKind: String, CaseIterable, Identifiable {
        case free = "apps_topselling_free"
        case paid = "apps_topselling_paid"
        case grossing = "apps_topgrossing"
        case trending = "apps_movers_shakers"
        var id: String { rawValue }
        var title: String {
            switch self {
            case .free: return "Top Free"
            case .paid: return "Top Paid"
            case .grossing: return "Top Grossing"
            case .trending: return "Trending"
            }
        }
    }

    static let chartCategories: [ChartCategory] = [
        ChartCategory(id: "GAME", title: "All Games", symbol: "gamecontroller.fill"),
        ChartCategory(id: "APPLICATION", title: "All Apps", symbol: "square.grid.2x2.fill"),
        ChartCategory(id: "GAME_ACTION", title: "Action", symbol: "bolt.fill"),
        ChartCategory(id: "GAME_ADVENTURE", title: "Adventure", symbol: "map.fill"),
        ChartCategory(id: "GAME_ARCADE", title: "Arcade", symbol: "flame.fill"),
        ChartCategory(id: "GAME_RACING", title: "Racing", symbol: "car.fill"),
        ChartCategory(id: "GAME_SPORTS", title: "Sports", symbol: "sportscourt.fill"),
        ChartCategory(id: "GAME_STRATEGY", title: "Strategy", symbol: "flag.fill"),
        ChartCategory(id: "GAME_SIMULATION", title: "Simulation", symbol: "building.2.fill"),
        ChartCategory(id: "GAME_ROLE_PLAYING", title: "Role Playing", symbol: "shield.fill"),
        ChartCategory(id: "GAME_PUZZLE", title: "Puzzle", symbol: "puzzlepiece.fill"),
        ChartCategory(id: "GAME_CASUAL", title: "Casual", symbol: "face.smiling"),
        ChartCategory(id: "GAME_SHOOTER", title: "Shooter", symbol: "scope"),
        ChartCategory(id: "GAME_CARD", title: "Card", symbol: "suit.spade.fill"),
        ChartCategory(id: "GAME_BOARD", title: "Board", symbol: "checkerboard.rectangle"),
        ChartCategory(id: "GAME_MUSIC", title: "Music Games", symbol: "music.note"),
        ChartCategory(id: "GAME_WORD", title: "Word", symbol: "textformat.abc"),
        ChartCategory(id: "GAME_TRIVIA", title: "Trivia", symbol: "questionmark.circle.fill"),
        ChartCategory(id: "GAME_EDUCATIONAL", title: "Educational Games", symbol: "graduationcap.fill"),
        ChartCategory(id: "GAME_CASINO", title: "Casino", symbol: "dice.fill"),
        ChartCategory(id: "COMMUNICATION", title: "Communication", symbol: "bubble.left.and.bubble.right.fill"),
        ChartCategory(id: "SOCIAL", title: "Social", symbol: "person.2.fill"),
        ChartCategory(id: "VIDEO_PLAYERS", title: "Video Players", symbol: "play.rectangle.fill"),
        ChartCategory(id: "MUSIC_AND_AUDIO", title: "Music & Audio", symbol: "headphones"),
        ChartCategory(id: "PHOTOGRAPHY", title: "Photography", symbol: "camera.fill"),
        ChartCategory(id: "ENTERTAINMENT", title: "Entertainment", symbol: "tv.fill"),
        ChartCategory(id: "TOOLS", title: "Tools", symbol: "wrench.and.screwdriver.fill"),
        ChartCategory(id: "PRODUCTIVITY", title: "Productivity", symbol: "checkmark.circle.fill"),
        ChartCategory(id: "EDUCATION", title: "Education", symbol: "book.fill"),
        ChartCategory(id: "BOOKS_AND_REFERENCE", title: "Books & Reference", symbol: "books.vertical.fill"),
        ChartCategory(id: "NEWS_AND_MAGAZINES", title: "News", symbol: "newspaper.fill"),
        ChartCategory(id: "SHOPPING", title: "Shopping", symbol: "bag.fill"),
        ChartCategory(id: "FINANCE", title: "Finance", symbol: "creditcard.fill"),
        ChartCategory(id: "TRAVEL_AND_LOCAL", title: "Travel", symbol: "airplane"),
        ChartCategory(id: "MAPS_AND_NAVIGATION", title: "Maps", symbol: "map"),
        ChartCategory(id: "HEALTH_AND_FITNESS", title: "Health & Fitness", symbol: "heart.fill"),
        ChartCategory(id: "LIFESTYLE", title: "Lifestyle", symbol: "leaf.fill"),
        ChartCategory(id: "FOOD_AND_DRINK", title: "Food & Drink", symbol: "fork.knife"),
        ChartCategory(id: "PERSONALIZATION", title: "Personalization", symbol: "paintpalette.fill"),
        ChartCategory(id: "WEATHER", title: "Weather", symbol: "cloud.sun.fill"),
        ChartCategory(id: "BUSINESS", title: "Business", symbol: "briefcase.fill"),
        ChartCategory(id: "ART_AND_DESIGN", title: "Art & Design", symbol: "paintbrush.fill"),
        ChartCategory(id: "COMICS", title: "Comics", symbol: "book.closed.fill"),
        ChartCategory(id: "SPORTS", title: "Sports Apps", symbol: "figure.walk"),
        ChartCategory(id: "MEDICAL", title: "Medical", symbol: "cross.case.fill"),
        ChartCategory(id: "AUTO_AND_VEHICLES", title: "Auto & Vehicles", symbol: "car.2.fill"),
        ChartCategory(id: "HOUSE_AND_HOME", title: "House & Home", symbol: "house.fill"),
        ChartCategory(id: "PARENTING", title: "Parenting", symbol: "person.3.fill"),
        ChartCategory(id: "DATING", title: "Dating", symbol: "heart.circle.fill"),
        ChartCategory(id: "BEAUTY", title: "Beauty", symbol: "sparkles"),
        ChartCategory(id: "EVENTS", title: "Events", symbol: "calendar"),
        ChartCategory(id: "LIBRARIES_AND_DEMO", title: "Libraries & Demo", symbol: "shippingbox.fill"),
    ]

    /// A chart of Play's: the ranked package names from Play's own list, then each app's page, the way search does it.
    /// When the list endpoint gives nothing, the public category page on play.google.com supplies the names.
    static func topChart(category: String, kind: ChartKind, session: PlaySession) async throws -> [PlayApp] {
        var ids: [String] = []
        func add(_ id: String) { if PlayApp.isValidPackageName(id), !ids.contains(id) { ids.append(id) } }

        let q: [(String, String)] = [("c", "3"), ("stcid", kind.rawValue), ("scat", category)]
        if let payload = try? await fdfeCall("listTopChartItems", session: session, query: q) {
            for app in PlayApp.parseApps(from: payload) { add(app.id) }
        }

        if ids.count < 8 {
            var comps = URLComponents(string: "https://play.google.com/store/apps/category/\(category)")!
            comps.queryItems = [URLQueryItem(name: "hl", value: "en"), URLQueryItem(name: "gl", value: PlayDevice.country)]
            if let url = comps.url {
                var req = URLRequest(url: url)
                req.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
                             forHTTPHeaderField: "User-Agent")
                if let (data, resp) = try? await URLSession.shared.data(for: req),
                   (resp as? HTTPURLResponse)?.statusCode == 200,
                   let html = String(data: data, encoding: .utf8),
                   let regex = try? NSRegularExpression(pattern: "/store/apps/details\\?id=([a-zA-Z][a-zA-Z0-9_]*(?:\\.[a-zA-Z][a-zA-Z0-9_]+)+)") {
                    for m in regex.matches(in: html, range: NSRange(html.startIndex..., in: html)) {
                        if m.numberOfRanges > 1, let r = Range(m.range(at: 1), in: html) { add(String(html[r])) }
                        if ids.count >= 40 { break }
                    }
                }
            }
        }

        let top = Array(ids.prefix(30))
        if top.isEmpty { return [] }

        var apps: [PlayApp] = []
        await withTaskGroup(of: PlayApp?.self) { group in
            for pkg in top {
                group.addTask { try? await details(packageName: pkg, session: session) }
            }
            for await app in group {
                if let app { apps.append(app) }
            }
        }
        apps.sort { a, b in (top.firstIndex(of: a.id) ?? 999) < (top.firstIndex(of: b.id) ?? 999) }
        return apps
    }
}

// MARK: - paid apps

extension PlayStoreManager {
    private static var paidNoticed = Set<String>()

    /// A paid app this session has not been told about yet: say so first. A second tap goes through, for an
    /// account that already owns the app (Play then delivers it); otherwise Play refuses and the Store says why.
    func needsPurchase(_ app: PlayAPI.PlayApp) -> Bool {
        if app.isFree || Self.paidNoticed.contains(app.id) { return false }
        Self.paidNoticed.insert(app.id)
        return true
    }

    nonisolated static func paidMessage(for app: PlayAPI.PlayApp) -> String {
        "\(app.title) is a paid app (\(app.formattedPrice)). RoidOS cannot buy apps: buy it on Google Play with the "
        + "same Google account you use here, then come back. If this account already owns it, tap \(app.formattedPrice) again to install."
    }
}

// MARK: - the Store's way in

/// One button per category on the Store's front page.
struct StoreChartsEntry: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Top Charts").font(.system(size: 20, weight: .bold)).foregroundStyle(Console.text)
            Text("Every app and game on Google Play, by category.")
                .font(.system(size: 13)).foregroundStyle(Console.textDim)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(PlayAPI.chartCategories) { category in
                        NavigationLink {
                            StoreChartsView(category: category)
                        } label: {
                            Label(category.title, systemImage: category.symbol)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Console.text)
                                .padding(.horizontal, 14)
                                .frame(height: 38)
                                .background(Console.card, in: Capsule())
                                .overlay(Capsule().stroke(Console.outline, lineWidth: 0.5))
                        }
                        .buttonStyle(CardButtonStyle())
                    }
                }
            }
        }
    }
}

/// A category's charts: Top Free, Top Paid, Top Grossing and Trending, ranked, with the same row and button as search.
struct StoreChartsView: View {
    let category: PlayAPI.ChartCategory
    @ObservedObject private var manager = PlayStoreManager.shared
    @State private var kind: PlayAPI.ChartKind = .free
    @State private var apps: [PlayAPI.PlayApp] = []
    @State private var loading = false
    @State private var failed = false
    @State private var selected: PlayAPI.PlayApp?
    @State private var notice: String?

    var body: some View {
        HuskPageList {
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(PlayAPI.ChartKind.allCases) { k in
                            ConsoleChip(title: k.title, selected: kind == k) { kind = k }
                        }
                    }
                }
                .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
                .listRowBackground(Color.clear)
            }
            Section {
                if loading && apps.isEmpty {
                    HStack {
                        Spacer()
                        ProgressView("Loading…")
                        Spacer()
                    }
                    .padding(.vertical, 12)
                } else if apps.isEmpty {
                    Text(failed ? "Google Play did not answer. Pull down to try again." : "Nothing here right now.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textDim)
                        .padding(.vertical, 8)
                } else {
                    ForEach(Array(apps.enumerated()), id: \.element.id) { index, app in
                        ChartRow(rank: index + 1, app: app, open: { selected = app }, paid: { notice = $0 })
                    }
                }
            } header: {
                Text("\(kind.title) · \(category.title)")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(category.title)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: kind) { await load() }
        .refreshable { await load() }
        .sheet(item: $selected) { app in PlayAppDetailSheet(app: app) }
        .alert("Google Play", isPresented: Binding(get: { notice != nil }, set: { if !$0 { notice = nil } })) {
            Button("OK", role: .cancel) { notice = nil }
        } message: {
            Text(notice ?? "")
        }
    }

    @MainActor
    private func load() async {
        guard let session = manager.session else {
            failed = true
            loading = false
            return
        }
        let wanted = kind
        loading = true
        failed = false
        apps = []
        let list = (try? await PlayAPI.topChart(category: category.id, kind: wanted, session: session)) ?? []
        guard wanted == kind else { return }
        apps = list
        failed = list.isEmpty
        loading = false
    }
}

private struct ChartRow: View {
    let rank: Int
    let app: PlayAPI.PlayApp
    let open: () -> Void
    let paid: (String) -> Void
    @ObservedObject private var manager = PlayStoreManager.shared
    @ObservedObject private var compat = CompatibilityStore.shared

    var body: some View {
        HStack(spacing: 12) {
            Text("\(rank)")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.textDim)
                .frame(width: 24, alignment: .trailing)
            Button(action: open) {
                HStack(spacing: 12) {
                    AsyncImage(url: URL(string: app.iconURL ?? "")) { phase in
                        if let image = phase.image { image.resizable().scaledToFill() } else { Color(uiColor: .tertiarySystemFill) }
                    }
                    .frame(width: 52, height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(app.title)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Theme.text)
                            .lineLimit(1)
                        Text(app.developer.isEmpty ? app.id : app.developer)
                            .font(.caption)
                            .foregroundStyle(Theme.textDim)
                            .lineLimit(1)
                        if let status = compat.entry(app.id)?.status { CompatBadge(status: status) }
                        HStack(spacing: 3) {
                            if app.rating > 0 {
                                Image(systemName: "star.fill").font(.system(size: 10)).foregroundStyle(.yellow)
                                Text(String(format: "%.1f", app.rating))
                            }
                            if app.rating > 0, !app.installs.isEmpty { Text("·") }
                            if !app.installs.isEmpty { Text(app.installs) }
                        }
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(Theme.textDim)
                    }
                }
            }
            .buttonStyle(.plain)
            Spacer(minLength: 8)
            ChartInstallButton(app: app, paid: paid)
        }
        .padding(.vertical, 4)
    }
}

private struct ChartInstallButton: View {
    let app: PlayAPI.PlayApp
    let paid: (String) -> Void
    @ObservedObject private var manager = PlayStoreManager.shared

    var body: some View {
        let progress = manager.downloadProgress[app.id]
        let downloading = manager.installingPackages.contains(app.id) || progress != nil
        return Group {
            if downloading {
                Button {
                    manager.cancelDownload(app.id)
                } label: {
                    ZStack {
                        Circle().stroke(Color(uiColor: .tertiarySystemFill), lineWidth: 3)
                        Circle()
                            .trim(from: 0, to: progress ?? 0.05)
                            .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        Image(systemName: "stop.fill").font(.system(size: 10)).foregroundStyle(Color.accentColor)
                    }
                    .frame(width: 32, height: 32)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Stop Download")
            } else {
                Button {
                    if manager.needsPurchase(app) {
                        paid(PlayStoreManager.paidMessage(for: app))
                    } else {
                        manager.downloadAndInstall(app: app)
                    }
                } label: {
                    Text(app.isFree ? "GET" : app.formattedPrice)
                        .font(.subheadline.weight(.bold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
            }
        }
    }
}
