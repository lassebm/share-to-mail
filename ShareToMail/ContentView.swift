import SwiftUI

struct ContentView: View {
    @State private var showShareSheet = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Open the Share Sheet in any app", systemImage: "square.and.arrow.up")
                        Label("Select \"Share to Mail\"", systemImage: "envelope")
                        Label("Enter your recipient email (first time only)", systemImage: "at")
                        Label("Review and send the pre-filled email", systemImage: "paperplane")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                } header: {
                    Text("How to Use")
                }

                Section {
                    Button {
                        showShareSheet = true
                    } label: {
                        Label("Set Recipient Email", systemImage: "at")
                    }
                } footer: {
                    Text("Opens the share sheet — select \"Share to Mail\" to set the recipient email.")
                }
            }
            .navigationTitle("Share to Mail")
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(items: ["sharetomail:set-email"])
            }
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    ContentView()
}
