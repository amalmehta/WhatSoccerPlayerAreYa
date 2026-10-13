import AppKit
import SwiftUI

/// A small form for notes about the app, saved to a local file.
struct FeedbackView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var kind = "Idea"
    @State private var message = ""
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Send Feedback").font(.title2.bold())
            Picker("Type", selection: $kind) {
                ForEach(["Idea", "Bug", "Wrong match", "Other"], id: \.self) { Text($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            TextEditor(text: $message)
                .font(.body)
                .frame(minHeight: 140)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(.quaternary))
            Text("Saved on this Mac in Feedback.json — nothing is sent anywhere.")
                .font(.caption)
                .foregroundStyle(.secondary)
            if let error { Text(error).foregroundStyle(.red).font(.caption) }
            HStack {
                Button("Show File") { NSWorkspace.shared.activateFileViewerSelecting([model.feedbackURL]) }
                    .disabled(!FileManager.default.fileExists(atPath: model.feedbackURL.path))
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Save") {
                    do {
                        try model.saveFeedback(kind: kind, message: message)
                        model.banner = "Thanks — feedback saved."
                        dismiss()
                    } catch {
                        self.error = error.localizedDescription
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 460)
    }
}
