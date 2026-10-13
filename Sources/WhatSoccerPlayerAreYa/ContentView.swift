import AppKit
import SoccerCore
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Environment(AppModel.self) private var model
    @State private var dropTargeted = false
    @State private var pasteMonitor: Any?

    var body: some View {
        @Bindable var model = model
        NavigationSplitView {
            List(selection: $model.section) {
                HStack(spacing: 10) {
                    Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 34, height: 34)
                    Text("What Soccer Player Are Ya").font(Theme.display(13, .heavy)).lineLimit(2)
                }
                .padding(.vertical, 6)
                .selectionDisabled()
                ForEach(AppModel.Section.allCases) { section in
                    Label(section.rawValue, systemImage: section.icon).tag(section)
                }
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
            .safeAreaInset(edge: .bottom) {
                Button {
                    model.showingFeedback = true
                } label: {
                    Label("Feedback", systemImage: "bubble.left")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .help("Send feedback about the app")
            }
        } detail: {
            switch model.section {
            case .quiz: QuizView()
            case .results: ResultsView()
            case .players: PlayersView()
            }
        }
        .navigationTitle(model.section.rawValue)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    model.showingImporter = true
                } label: {
                    Label("Upload", systemImage: "tray.and.arrow.down")
                        .labelStyle(.titleAndIcon)
                }
                .help("Import a CSV of players (FIFA / EA FC exports work). You can also drop or paste files.")
                SettingsLink {
                    Label("Settings", systemImage: "gearshape")
                }
                .help("Settings (⌘,)")
            }
        }
        .safeAreaInset(edge: .top) {
            if let banner = model.banner {
                HStack {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    Text(banner)
                    Spacer()
                    Button("Dismiss") { model.banner = nil }.buttonStyle(.borderless)
                }
                .padding(10)
                .background(.bar)
                .task(id: banner) {
                    try? await Task.sleep(for: .seconds(6))
                    if model.banner == banner { model.banner = nil }
                }
            }
        }
        .overlay {
            if dropTargeted {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 3, dash: [10, 6]))
                    .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                    .overlay(Label("Drop a player CSV to import", systemImage: "tray.and.arrow.down").font(.title2))
                    .padding(8)
                    .allowsHitTesting(false)
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $dropTargeted) { [model] providers in
            for provider in providers {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    guard let url else { return }
                    Task { @MainActor in model.importFiles([url]) }
                }
            }
            return true
        }
        .fileImporter(isPresented: $model.showingImporter,
                      allowedContentTypes: [.commaSeparatedText, .plainText, .tabSeparatedText],
                      allowsMultipleSelection: true) { result in
            if case .success(let urls) = result { model.importFiles(urls) }
        }
        .sheet(isPresented: $model.showingFeedback) { FeedbackView() }
        .alert("Something went wrong", isPresented: Binding(get: { model.alert != nil }, set: { if !$0 { model.alert = nil } })) {
            Button("OK") { model.alert = nil }
        } message: {
            Text(model.alert ?? "")
        }
        .background(FirstLaunchWindowSize(size: CGSize(width: 1200, height: 780)))
        .onAppear(perform: installPasteMonitor)
        .onDisappear {
            if let pasteMonitor { NSEvent.removeMonitor(pasteMonitor) }
        }
    }

    /// ⌘V anywhere in the window imports copied CSV files or text, unless a text field is being edited.
    private func installPasteMonitor() {
        guard pasteMonitor == nil else { return }
        let model = model
        pasteMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command,
                  event.charactersIgnoringModifiers == "v",
                  !(event.window?.firstResponder is NSText) else { return event }
            return MainActor.assumeIsolated { model.pasteFromClipboard() } ? nil : event
        }
    }
}

/// Gives the window a roomy size the first time it opens; after that macOS restores whatever the person chose.
struct FirstLaunchWindowSize: NSViewRepresentable {
    var size: CGSize

    func makeNSView(context: Context) -> NSView { Probe(size: size) }
    func updateNSView(_ nsView: NSView, context: Context) {}

    final class Probe: NSView {
        let size: CGSize
        init(size: CGSize) { self.size = size; super.init(frame: .zero) }
        required init?(coder: NSCoder) { fatalError() }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window, !UserDefaults.standard.bool(forKey: "sizedOnce") else { return }
            UserDefaults.standard.set(true, forKey: "sizedOnce")
            DispatchQueue.main.async {
                window.setContentSize(self.size)
                window.center()
            }
        }
    }
}
