import FamilyHubCore
import MessageUI
import SwiftUI

/// Opens Messages with the opener already typed in. When iOS reports the text was sent,
/// the person's clock resets automatically — no extra tap needed.
struct MessageComposer: View {
    let person: Person
    let messageText: String
    let onFinish: (_ sent: Bool) -> Void

    var body: some View {
        if MFMessageComposeViewController.canSendText() {
            ComposeController(recipients: person.phone.isEmpty ? [] : [person.phone], messageText: messageText, onFinish: onFinish)
        } else {
            FallbackCompose(person: person, text: messageText, onFinish: onFinish)
        }
    }
}

private struct ComposeController: UIViewControllerRepresentable {
    let recipients: [String]
    let messageText: String
    let onFinish: (Bool) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    func makeUIViewController(context: Context) -> MFMessageComposeViewController {
        let vc = MFMessageComposeViewController()
        vc.recipients = recipients
        vc.body = messageText
        vc.messageComposeDelegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ vc: MFMessageComposeViewController, context: Context) {}

    final class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
        let onFinish: (Bool) -> Void
        init(onFinish: @escaping (Bool) -> Void) { self.onFinish = onFinish }

        func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
            // The caller clears the sheet binding, which dismisses this controller.
            onFinish(result == .sent)
        }
    }
}

/// Used where Messages isn't available (Simulator, iPad without SMS): copy the text and log it by hand.
private struct FallbackCompose: View {
    @Environment(\.dismiss) private var dismiss
    let person: Person
    let text: String
    let onFinish: (Bool) -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text(text)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                Button("Copy message", systemImage: "doc.on.doc") {
                    UIPasteboard.general.string = text
                }
                Button("I sent it to \(person.firstName)", systemImage: "checkmark.circle.fill") {
                    onFinish(true)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                Spacer()
            }
            .padding()
            .navigationTitle("Text \(person.firstName)")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onFinish(false); dismiss() }
                }
            }
        }
    }
}
