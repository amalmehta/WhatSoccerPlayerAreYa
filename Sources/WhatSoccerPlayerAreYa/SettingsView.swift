import AppKit
import SoccerCore
import SwiftUI

/// Every preference in one place (⌘,).
struct SettingsView: View {
    var body: some View {
        TabView {
            QuizSettings().tabItem { Label("Quiz", systemImage: "soccerball") }
            PlayerSettings().tabItem { Label("Players", systemImage: "person.3") }
            DataSettings().tabItem { Label("Data", systemImage: "externaldrive") }
        }
        .frame(width: 480)
        .padding(.vertical, 8)
    }
}

private struct QuizSettings: View {
    @AppStorage(SettingsKey.askForName) private var askForName = true
    @AppStorage(SettingsKey.matchCount) private var matchCount = 5
    @AppStorage(SettingsKey.appearance) private var appearance = Appearance.system.rawValue

    var body: some View {
        Form {
            Toggle("Ask for a name before the quiz", isOn: $askForName)
            Stepper("Show \(matchCount) matches per result", value: $matchCount, in: 1...10)
            Picker("Appearance", selection: $appearance) {
                ForEach(Appearance.allCases) { Text($0.rawValue).tag($0.rawValue) }
            }
        }
        .formStyle(.grouped)
    }
}

private struct PlayerSettings: View {
    @Environment(AppModel.self) private var model
    @AppStorage(SettingsKey.useBundled) private var useBundled = true
    @AppStorage(SettingsKey.minimumOverall) private var minimumOverall = 75
    @AppStorage(SettingsKey.includeCurrent) private var includeCurrent = true
    @AppStorage(SettingsKey.includeLegends) private var includeLegends = true
    @AppStorage(SettingsKey.includeImported) private var includeImported = true

    var body: some View {
        Form {
            Section("Match against") {
                Toggle("Current players", isOn: $includeCurrent)
                Toggle("Legends", isOn: $includeLegends)
                Toggle("Imported players", isOn: $includeImported)
                VStack(alignment: .leading) {
                    Text("Minimum overall rating: \(minimumOverall)")
                    Slider(value: Binding(get: { Double(minimumOverall) }, set: { minimumOverall = Int($0) }), in: 40...90, step: 1)
                }
                let _ = (useBundled, minimumOverall, includeCurrent, includeLegends, includeImported)
                Text("\(model.eligibleCount.formatted()) players are eligible. A higher minimum keeps matches to well-known names.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Player pool") {
                Toggle("Use the \(model.bundled.count) bundled players", isOn: $useBundled)
                LabeledContent("Imported players", value: model.imported.count.formatted())
                HStack {
                    Button("Upload Players…") { model.showingImporter = true }
                    Button("Remove Imported", role: .destructive) { model.clearImported() }
                        .disabled(model.imported.isEmpty)
                }
            }
        }
        .formStyle(.grouped)
    }
}

private struct DataSettings: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Form {
            LabeledContent("Saved responses", value: model.responses.count.formatted())
            LabeledContent("Data folder") {
                Text(model.dataDirectory.path).font(.caption).textSelection(.enabled).lineLimit(2)
            }
            HStack {
                Button("Show in Finder") {
                    try? FileManager.default.createDirectory(at: model.dataDirectory, withIntermediateDirectories: true)
                    NSWorkspace.shared.open(model.dataDirectory)
                }
                Button("Export Responses…") { model.exportResponses() }
                    .disabled(model.responses.isEmpty)
            }
        }
        .formStyle(.grouped)
    }
}
