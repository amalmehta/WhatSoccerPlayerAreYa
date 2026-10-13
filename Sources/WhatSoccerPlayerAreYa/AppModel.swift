import AppKit
import Observation
import SoccerCore
import SwiftUI

/// Shared app state: the player pool, saved responses, imports and feedback.
@MainActor @Observable
final class AppModel {
    enum Section: String, CaseIterable, Identifiable {
        case quiz = "Take the Quiz", results = "Results", players = "Players"
        var id: String { rawValue }
        var icon: String {
            switch self {
            case .quiz: "soccerball"
            case .results: "chart.bar.xaxis"
            case .players: "person.3"
            }
        }
    }

    var section: Section = .quiz
    let bundled: [Player]
    private(set) var imported: [Player]
    private(set) var responses: [QuizResponse]
    var showingImporter = false
    var showingFeedback = false
    var banner: String?
    var alert: String?

    let dataDirectory: URL
    private let responseStore: ResponseStore
    private var importedURL: URL { dataDirectory.appendingPathComponent("Imported Players.json") }
    var feedbackURL: URL { dataDirectory.appendingPathComponent("Feedback.json") }

    init() {
        UserDefaults.standard.register(defaults: [
            SettingsKey.askForName: true,
            SettingsKey.matchCount: 5,
            SettingsKey.minimumOverall: 75,
            SettingsKey.includeCurrent: true,
            SettingsKey.includeLegends: true,
            SettingsKey.includeImported: true,
            SettingsKey.useBundled: true,
        ])
        if let override = ProcessInfo.processInfo.environment["WSPAY_DATA_DIR"] {
            dataDirectory = URL(fileURLWithPath: override)
        } else {
            dataDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("What Soccer Player Are Ya")
        }
        bundled = BundledPlayers.load()
        responseStore = ResponseStore(url: dataDirectory.appendingPathComponent("Responses.json"))
        responses = responseStore.responses
        // Screenshot helper: `-startSection results` opens on that section.
        if let start = UserDefaults.standard.string(forKey: "startSection"),
           let match = Section.allCases.first(where: { "\($0)" == start }) {
            section = match
        }
        imported = (try? JSONDecoder().decode([Player].self, from: Data(contentsOf: dataDirectory.appendingPathComponent("Imported Players.json")))) ?? []
    }

    // MARK: Player pool

    var allPlayers: [Player] {
        (UserDefaults.standard.bool(forKey: SettingsKey.useBundled) ? bundled : []) + imported
    }

    var filter: MatchFilter {
        let d = UserDefaults.standard
        var eras: Set<Era> = []
        if d.bool(forKey: SettingsKey.includeCurrent) { eras.insert(.current) }
        if d.bool(forKey: SettingsKey.includeLegends) { eras.insert(.legend) }
        if d.bool(forKey: SettingsKey.includeImported) { eras.insert(.imported) }
        return MatchFilter(minimumOverall: d.integer(forKey: SettingsKey.minimumOverall), eras: eras)
    }

    var eligibleCount: Int {
        let f = filter
        return allPlayers.filter { $0.overall >= f.minimumOverall && f.eras.contains($0.era) }.count
    }

    func rank(_ profile: Profile) -> [Match] {
        let count = max(1, UserDefaults.standard.integer(forKey: SettingsKey.matchCount))
        return Matcher.rank(profile, against: allPlayers, filter: filter, limit: count)
    }

    // MARK: Responses

    func save(_ response: QuizResponse) {
        do {
            try responseStore.add(response)
        } catch {
            alert = "Couldn't save this response: \(error.localizedDescription)"
        }
        responses = responseStore.responses
    }

    func deleteResponses(_ ids: Set<UUID>) {
        try? responseStore.delete(ids: ids)
        responses = responseStore.responses
    }

    func clearResponses() {
        try? responseStore.removeAll()
        responses = responseStore.responses
    }

    func exportResponses() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "Soccer Player Quiz Responses.csv"
        panel.allowedContentTypes = [.commaSeparatedText]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try ResponseExporter.csv(responses).write(to: url, atomically: true, encoding: .utf8)
            banner = "Exported \(responses.count) responses."
        } catch {
            alert = "Couldn't export: \(error.localizedDescription)"
        }
    }

    // MARK: Importing players

    func importFiles(_ urls: [URL]) {
        let csvs = urls.filter { ["csv", "txt", "tsv"].contains($0.pathExtension.lowercased()) || $0.pathExtension.isEmpty }
        guard !csvs.isEmpty else {
            alert = "Drop a .csv file of players (FIFA / EA FC exports work)."
            return
        }
        for url in csvs {
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            do {
                merge(try PlayerImporter.load(url: url), from: url.lastPathComponent)
            } catch {
                alert = "Couldn't import \(url.lastPathComponent): \(error.localizedDescription)"
            }
        }
    }

    func importText(_ text: String) {
        do {
            merge(try PlayerImporter.load(csv: text), from: "pasted text")
        } catch {
            alert = "The pasted text isn't a player CSV: \(error.localizedDescription)"
        }
    }

    private func merge(_ result: ImportResult, from source: String) {
        var byID = Dictionary(imported.map { ($0.id, $0) }, uniquingKeysWith: { _, new in new })
        for p in result.players { byID[p.id] = p }
        imported = byID.values.sorted { $0.overall != $1.overall ? $0.overall > $1.overall : $0.name < $1.name }
        persistImported()
        var message = "Imported \(result.players.count.formatted()) players from \(source)."
        if result.skippedRows > 0 { message += " Skipped \(result.skippedRows.formatted()) incomplete rows." }
        banner = message
        section = .players
    }

    func clearImported() {
        imported = []
        persistImported()
    }

    private func persistImported() {
        do {
            try FileManager.default.createDirectory(at: dataDirectory, withIntermediateDirectories: true)
            try JSONEncoder().encode(imported).write(to: importedURL, options: .atomic)
        } catch {
            alert = "Couldn't save imported players: \(error.localizedDescription)"
        }
    }

    /// ⌘V anywhere outside a text field: import copied CSV files or CSV text.
    func pasteFromClipboard() -> Bool {
        let pb = NSPasteboard.general
        if let urls = pb.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL], !urls.isEmpty {
            importFiles(urls)
            return true
        }
        if let text = pb.string(forType: .string), text.contains(","), text.contains("\n") {
            importText(text)
            return true
        }
        return false
    }

    // MARK: Feedback

    struct Feedback: Codable {
        var date: Date
        var kind: String
        var message: String
    }

    func saveFeedback(kind: String, message: String) throws {
        var all = (try? JSONDecoder().decode([Feedback].self, from: Data(contentsOf: feedbackURL))) ?? []
        all.append(Feedback(date: Date(), kind: kind, message: message))
        try FileManager.default.createDirectory(at: dataDirectory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(all).write(to: feedbackURL, options: .atomic)
    }
}
