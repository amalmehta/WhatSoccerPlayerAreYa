import SwiftUI
import SoccerCore

@main
struct WhatSoccerPlayerAreYaApp: App {
    @State private var model = AppModel()
    @AppStorage(SettingsKey.appearance) private var appearance = Appearance.system.rawValue

    var body: some Scene {
        Window("What Soccer Player Are Ya", id: "main") {
            ContentView()
                .environment(model)
                .preferredColorScheme(Appearance(rawValue: appearance)?.colorScheme)
                .frame(minWidth: 900, idealWidth: 1200, minHeight: 620, idealHeight: 780)
        }
        .defaultSize(width: 1200, height: 780)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(after: .newItem) {
                Button("Import Players…") { model.showingImporter = true }
                    .keyboardShortcut("o")
            }
            CommandGroup(replacing: .help) {
                Button("Send Feedback…") { model.showingFeedback = true }
            }
        }

        Settings {
            SettingsView()
                .environment(model)
                .preferredColorScheme(Appearance(rawValue: appearance)?.colorScheme)
        }
    }
}

enum SettingsKey {
    static let askForName = "askForName"
    static let matchCount = "matchCount"
    static let minimumOverall = "minimumOverall"
    static let includeCurrent = "includeCurrent"
    static let includeLegends = "includeLegends"
    static let includeImported = "includeImported"
    static let useBundled = "useBundled"
    static let appearance = "appearance"
    /// "All", "Men" or "Women".
    static let gender = "gender"
}

/// The men's / women's choice shown in Settings, on the quiz start screen and on the Players page.
struct GenderPicker: View {
    @Binding var selection: String
    var label = "Players"

    var body: some View {
        Picker(label, selection: $selection) {
            Text("Men's & Women's").tag("All")
            ForEach(Gender.allCases) { Text($0.name).tag($0.rawValue) }
        }
    }
}

enum Appearance: String, CaseIterable, Identifiable {
    case system = "System", light = "Light", dark = "Dark"
    var id: String { rawValue }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}
