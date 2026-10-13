import SoccerCore
import SwiftUI

/// Browse the player pool the quiz matches against.
struct PlayersView: View {
    @Environment(AppModel.self) private var model
    @AppStorage(SettingsKey.useBundled) private var useBundled = true
    @State private var search = ""
    @State private var group: PositionGroup?
    @State private var era: Era?
    @State private var sortOrder = [KeyPathComparator(\Player.overall, order: .reverse)]

    var body: some View {
        let _ = useBundled
        let players = model.allPlayers.filter { p in
            (group == nil || p.group == group)
                && (era == nil || p.era == era)
                && (search.isEmpty || p.name.localizedStandardContains(search)
                    || p.club.localizedStandardContains(search) || p.nationality.localizedStandardContains(search))
        }
        VStack(spacing: 0) {
            HStack {
                Picker("Position", selection: $group) {
                    Text("All positions").tag(PositionGroup?.none)
                    ForEach(PositionGroup.allCases) { Text($0.name + "s").tag(PositionGroup?.some($0)) }
                }
                .fixedSize()
                Picker("Era", selection: $era) {
                    Text("All eras").tag(Era?.none)
                    ForEach(Era.allCases, id: \.self) { Text($0.rawValue).tag(Era?.some($0)) }
                }
                .fixedSize()
                Spacer()
                Text("\(players.count.formatted()) players").foregroundStyle(.secondary)
            }
            .padding(10)
            if model.allPlayers.isEmpty {
                ContentUnavailableView {
                    Label("No players", systemImage: "person.3")
                } description: {
                    Text("Turn the bundled players back on in Settings, or upload a CSV. You can also drop a file anywhere on this window or paste it with ⌘V.")
                } actions: {
                    Button("Upload Players…") { model.showingImporter = true }
                }
            } else {
                Table(players.sorted(using: sortOrder), sortOrder: $sortOrder) {
                    TableColumn("Name", value: \.name) { Text($0.name).fontWeight(.medium) }
                        .width(min: 140, ideal: 170)
                    TableColumn("Positions") { PositionChips(positions: Array($0.positions.prefix(3))) }
                        .width(min: 90, ideal: 120)
                    TableColumn("Club", value: \.club)
                    TableColumn("Nation", value: \.nationality)
                    TableColumn("Era") { Chip(text: $0.era.rawValue, color: Palette.color(era: $0.era)) }
                        .width(70)
                    TableColumn("OVR", value: \.overall) { Text("\($0.overall)").monospacedDigit().fontWeight(.semibold) }
                        .width(40)
                    Group {
                    TableColumn("PAC") { traitCell($0, .pace) }.width(36)
                    TableColumn("SHO") { traitCell($0, .shooting) }.width(36)
                    TableColumn("PAS") { traitCell($0, .passing) }.width(36)
                    TableColumn("DRI") { traitCell($0, .dribbling) }.width(36)
                    TableColumn("DEF") { traitCell($0, .defending) }.width(36)
                    TableColumn("PHY") { traitCell($0, .physical) }.width(36)
                    }
                }
            }
        }
        .searchable(text: $search, prompt: "Name, club or nation")
        .toolbar {
            if !model.imported.isEmpty {
                ToolbarItem {
                    Text("\(model.imported.count.formatted()) imported").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    private func traitCell(_ p: Player, _ t: Trait) -> some View {
        Text("\(p.value(t))")
            .monospacedDigit()
            .foregroundStyle(p.value(t) >= 85 ? Palette.color(trait: t) : .primary)
            .help(p.traitName(t))
    }
}
