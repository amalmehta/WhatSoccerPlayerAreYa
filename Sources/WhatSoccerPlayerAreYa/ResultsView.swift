import Charts
import SoccerCore
import SwiftUI

/// Summary of every saved response.
struct ResultsView: View {
    @Environment(AppModel.self) private var model
    @State private var selection = Set<QuizResponse.ID>()
    @State private var confirmClear = false
    @State private var sortOrder = [KeyPathComparator(\QuizResponse.date, order: .reverse)]

    var body: some View {
        let responses = model.responses
        if responses.isEmpty {
            EmptyPitch(emoji: "📋", title: "No one's kicked off yet",
                       message: "Every finished quiz lands here, with a matchday report on who everyone plays like.",
                       button: "Take the Quiz") { model.section = .quiz }
        } else {
            let summary = ResponseSummary(responses)
            VSplitView {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Matchday report").font(Theme.display(30)).foregroundStyle(.white)
                            tiles(summary)
                        }
                        .padding(24)
                        .background(PitchBackground())
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        HStack(alignment: .top, spacing: 24) {
                            topPlayersChart(summary)
                            VStack(alignment: .leading, spacing: 24) {
                                traitsChart(summary)
                                positionsChart(summary)
                            }
                        }
                    }
                    .padding(24)
                }
                .frame(minHeight: 260)
                table(responses)
                    .frame(minHeight: 160)
            }
            .toolbar {
                ToolbarItemGroup {
                    Button("Export CSV…", systemImage: "tablecells") { model.exportResponses() }
                        .help("Save every response as a spreadsheet")
                    Button("Clear All…", systemImage: "trash") { confirmClear = true }
                        .help("Delete every saved response")
                }
            }
            .confirmationDialog("Delete all \(responses.count) responses?", isPresented: $confirmClear) {
                Button("Delete All", role: .destructive) { model.clearResponses() }
            } message: {
                Text("This can't be undone. Export a CSV first if you want a copy.")
            }
        }
    }

    private func tiles(_ s: ResponseSummary) -> some View {
        HStack(spacing: 16) {
            tile("🙋", "Players scouted", s.total.formatted())
            tile("⭐️", "Most common match", s.topPlayers.first.map { "\($0.name) (\($0.count))" } ?? "—")
            let topGroup = s.positions.max { $0.value < $1.value }?.key
            tile("📍", "Most common position", topGroup?.name ?? "—")
        }
    }

    private func tile(_ emoji: String, _ title: String, _ value: String) -> some View {
        HStack(spacing: 12) {
            Text(emoji).font(.system(size: 26))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(Theme.display(13, .semibold)).foregroundStyle(.white.opacity(0.8))
                Text(value).font(Theme.display(22)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.6)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func topPlayersChart(_ s: ResponseSummary) -> some View {
        VStack(alignment: .leading) {
            Text("Top matches").font(Theme.display(18))
            Chart(s.topPlayers.prefix(10)) { item in
                BarMark(x: .value("People", item.count), y: .value("Player", item.name))
                    .foregroundStyle(Theme.grass.gradient)
                    .annotation(position: .trailing) { Text("\(item.count)").font(.caption).foregroundStyle(.secondary) }
            }
            .chartXAxis(.hidden)
            .frame(height: CGFloat(max(3, min(10, s.topPlayers.count))) * 30)
        }
        .frame(maxWidth: .infinity)
    }

    private func traitsChart(_ s: ResponseSummary) -> some View {
        VStack(alignment: .leading) {
            Text("Average style").font(Theme.display(18))
            Chart(Trait.allCases) { trait in
                BarMark(x: .value("Average", s.averageTraits[trait.rawValue] * 100), y: .value("Trait", trait.name))
                    .foregroundStyle(Palette.color(trait: trait))
            }
            .chartXScale(domain: 0...100)
            .chartXAxis(.hidden)
            .frame(height: 170)
        }
        .frame(maxWidth: .infinity)
    }

    private func positionsChart(_ s: ResponseSummary) -> some View {
        VStack(alignment: .leading) {
            Text("Where people play").font(Theme.display(18))
            Chart(PositionGroup.allCases) { group in
                BarMark(x: .value("People", s.positions[group] ?? 0), y: .value("Position", group.name))
                    .foregroundStyle(Palette.color(group: group))
                    .annotation(position: .trailing) { Text("\(s.positions[group] ?? 0)").font(.caption).foregroundStyle(.secondary) }
            }
            .chartXAxis(.hidden)
            .frame(height: 120)
        }
        .frame(maxWidth: .infinity)
    }

    private func table(_ responses: [QuizResponse]) -> some View {
        Table(responses.sorted(using: sortOrder), selection: $selection, sortOrder: $sortOrder) {
            TableColumn("Date", value: \.date) { Text($0.date.formatted(date: .abbreviated, time: .shortened)) }
                .width(min: 120, ideal: 150)
            TableColumn("Name", value: \.displayName)
            TableColumn("Top Match") { r in Text(r.topMatch?.name ?? "—") }
            TableColumn("Positions") { r in PositionChips(positions: Array(r.topMatch?.positions.prefix(2) ?? [])) }
            TableColumn("Score") { r in Text(r.topMatch.map { "\($0.score)%" } ?? "—").monospacedDigit() }
                .width(60)
            TableColumn("Plays as") { r in Chip(text: r.profile.topPosition.name, color: Palette.color(group: r.profile.topPosition)) }
        }
        .contextMenu(forSelectionType: QuizResponse.ID.self) { ids in
            Button("Delete", role: .destructive) { model.deleteResponses(ids) }
        }
        .onDeleteCommand { model.deleteResponses(selection) }
    }
}
