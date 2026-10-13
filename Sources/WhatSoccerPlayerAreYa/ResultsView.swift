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
            ContentUnavailableView {
                Label("No responses yet", systemImage: "chart.bar.xaxis")
            } description: {
                Text("Each completed quiz is saved here with a summary of everyone's answers.")
            } actions: {
                Button("Take the Quiz") { model.section = .quiz }
            }
        } else {
            let summary = ResponseSummary(responses)
            VSplitView {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        tiles(summary)
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
            tile("Responses", s.total.formatted())
            tile("Most common match", s.topPlayers.first.map { "\($0.name) (\($0.count))" } ?? "—")
            let topGroup = s.positions.max { $0.value < $1.value }?.key
            tile("Most common position", topGroup?.name ?? "—")
        }
    }

    private func tile(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title2.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.6)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
    }

    private func topPlayersChart(_ s: ResponseSummary) -> some View {
        VStack(alignment: .leading) {
            Text("Top matches").font(.headline)
            Chart(s.topPlayers.prefix(10)) { item in
                BarMark(x: .value("People", item.count), y: .value("Player", item.name))
                    .foregroundStyle(Color.accentColor)
                    .annotation(position: .trailing) { Text("\(item.count)").font(.caption).foregroundStyle(.secondary) }
            }
            .chartXAxis(.hidden)
            .frame(height: CGFloat(max(3, min(10, s.topPlayers.count))) * 30)
        }
        .frame(maxWidth: .infinity)
    }

    private func traitsChart(_ s: ResponseSummary) -> some View {
        VStack(alignment: .leading) {
            Text("Average style").font(.headline)
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
            Text("Where people play").font(.headline)
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
