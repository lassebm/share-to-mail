import UIKit
import MessageUI
import UniformTypeIdentifiers

@MainActor
class ShareViewController: UIViewController, @preconcurrency MFMailComposeViewControllerDelegate {
    private static let emailKey = "recipientEmail"
    static let setEmailTrigger = "sharetomail:set-email"

    private let spinner = UIActivityIndicatorView(style: .large)
    private let iconView = UIImageView()
    private var hasPresented = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear

        iconView.image = UIImage(named: "AppIcon")
        iconView.contentMode = .scaleAspectFit
        iconView.layer.cornerRadius = 24
        iconView.layer.cornerCurve = .continuous
        iconView.clipsToBounds = true
        iconView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(iconView)

        spinner.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(spinner)

        NSLayoutConstraint.activate([
            iconView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -20),
            iconView.widthAnchor.constraint(equalToConstant: 120),
            iconView.heightAnchor.constraint(equalToConstant: 120),

            spinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            spinner.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 32),
        ])
        spinner.startAnimating()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !hasPresented else { return }
        hasPresented = true
        Task { await startSharing() }
    }

    // MARK: - Main Flow

    private func startSharing() async {
        let isSetEmailRequest = await isSetEmailTrigger()

        var email: String?
        if isSetEmailRequest {
            email = await promptForEmail(prefill: savedEmail())
        } else {
            email = savedEmail()
            if email == nil {
                email = await promptForEmail()
            }
        }

        guard let email, !email.isEmpty else {
            cancel()
            return
        }

        saveEmail(email)

        if isSetEmailRequest {
            await showAlert(title: "Email Saved", message: "Recipient set to \(email).")
            extensionContext?.completeRequest(returningItems: nil)
            return
        }

        guard MFMailComposeViewController.canSendMail() else {
            await showAlert(
                title: "Mail Not Available",
                message: "Please set up a Mail account on this device in Settings > Mail."
            )
            cancel()
            return
        }

        let (body, attachments) = await extractSharedContent()
        presentMailCompose(to: email, body: body, attachments: attachments)
    }

    // MARK: - Email Configuration

    private func savedEmail() -> String? {
        let email = UserDefaults.standard.string(forKey: Self.emailKey)
        return (email?.isEmpty == false) ? email : nil
    }

    private func saveEmail(_ email: String) {
        UserDefaults.standard.set(email, forKey: Self.emailKey)
    }

    private func isSetEmailTrigger() async -> Bool {
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else { return false }
        for item in items {
            for provider in item.attachments ?? [] {
                if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    do {
                        let result = try await provider.loadItem(forTypeIdentifier: UTType.plainText.identifier)
                        if let text = result as? String, text == Self.setEmailTrigger {
                            return true
                        }
                    } catch {}
                }
            }
        }
        return false
    }

    private func promptForEmail(prefill: String? = nil) async -> String? {
        await withCheckedContinuation { (continuation: CheckedContinuation<String?, Never>) in
            spinner.stopAnimating()
            let alert = UIAlertController(
                title: "Set Recipient Email",
                message: "Enter the email address to send shared content to. This is saved for future use.",
                preferredStyle: .alert
            )
            alert.addTextField { field in
                field.placeholder = "email@example.com"
                field.text = prefill
                field.keyboardType = .emailAddress
                field.autocapitalizationType = .none
                field.autocorrectionType = .no
            }
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
                continuation.resume(returning: nil)
            })
            alert.addAction(UIAlertAction(title: "Save", style: .default) { _ in
                let email = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines)
                continuation.resume(returning: email)
            })
            present(alert, animated: true)
        }
    }

    // MARK: - Content Extraction

    fileprivate struct Attachment: Sendable {
        let data: Data
        let mimeType: String
        let filename: String
    }

    fileprivate enum ExtractedItem: Sendable {
        case body(String)
        case attachment(Attachment)
    }

    private func extractSharedContent() async -> (String, [Attachment]) {
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else {
            return ("", [])
        }

        var providers: [ProviderWork] = []
        for item in items {
            for provider in item.attachments ?? [] {
                if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    providers.append(ProviderWork(provider: provider, kind: .url))
                } else if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    providers.append(ProviderWork(provider: provider, kind: .text))
                } else if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                    providers.append(ProviderWork(provider: provider, kind: .image))
                } else if provider.hasItemConformingToTypeIdentifier(UTType.data.identifier) {
                    providers.append(ProviderWork(provider: provider, kind: .file))
                }
            }
        }

        return await ContentExtractor.extractAll(providers)
    }

    // MARK: - Subject Generation

    private func generateSubject(body: String, attachments: [Attachment]) -> String {
        if let firstLine = body.components(separatedBy: "\n").first,
           let url = URL(string: firstLine),
           let host = url.host {
            return "Shared: \(host)"
        }
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return "Shared: \(String(trimmed.prefix(50)))"
        }
        return "Shared content"
    }

    // MARK: - Mail Compose

    private func presentMailCompose(to email: String, body: String, attachments: [Attachment]) {
        spinner.stopAnimating()

        let composer = MFMailComposeViewController()
        composer.mailComposeDelegate = self
        composer.setToRecipients([email])
        composer.setSubject(generateSubject(body: body, attachments: attachments))

        if !body.isEmpty {
            composer.setMessageBody(body, isHTML: false)
        }

        for (index, attachment) in attachments.enumerated() {
            let name = attachments.count > 1 && attachment.filename.starts(with: "image.")
                ? "image_\(index + 1).\(attachment.filename.components(separatedBy: ".").last ?? "jpg")"
                : attachment.filename
            composer.addAttachmentData(attachment.data, mimeType: attachment.mimeType, fileName: name)
        }

        present(composer, animated: true)
    }

    // MARK: - MFMailComposeViewControllerDelegate

    func mailComposeController(
        _ controller: MFMailComposeViewController,
        didFinishWith result: MFMailComposeResult,
        error: Error?
    ) {
        controller.dismiss(animated: true) { [weak self] in
            switch result {
            case .sent, .saved:
                self?.extensionContext?.completeRequest(returningItems: nil)
            case .cancelled, .failed:
                let err = error ?? NSError(
                    domain: "dk.lbm.sharetomail",
                    code: 0,
                    userInfo: [NSLocalizedDescriptionKey: "Mail cancelled"]
                )
                self?.extensionContext?.cancelRequest(withError: err)
            @unknown default:
                self?.extensionContext?.completeRequest(returningItems: nil)
            }
        }
    }

    // MARK: - Helpers

    private func showAlert(title: String, message: String) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            spinner.stopAnimating()
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                continuation.resume()
            })
            present(alert, animated: true)
        }
    }

    private func cancel() {
        extensionContext?.cancelRequest(withError: NSError(
            domain: "dk.lbm.sharetomail",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Share cancelled"]
        ))
    }
}

// MARK: - Content Extraction (nonisolated)

private enum ProviderWorkKind: Sendable { case url, text, image, file }

private struct ProviderWork: @unchecked Sendable {
    let provider: NSItemProvider
    let kind: ProviderWorkKind
}

private enum ContentExtractor {
    typealias Attachment = ShareViewController.Attachment
    typealias ExtractedItem = ShareViewController.ExtractedItem

    static func extractAll(_ work: [ProviderWork]) async -> (String, [Attachment]) {
        await withTaskGroup(of: ExtractedItem?.self) { group in
            for item in work {
                group.addTask {
                    switch item.kind {
                    case .url: return await loadURL(from: item.provider)
                    case .text: return await loadText(from: item.provider)
                    case .image: return await loadImage(from: item.provider)
                    case .file: return await loadFile(from: item.provider)
                    }
                }
            }

            var bodies: [String] = []
            var attachments: [Attachment] = []
            for await result in group {
                switch result {
                case .body(let text): bodies.append(text)
                case .attachment(let att): attachments.append(att)
                case nil: break
                }
            }
            return (bodies.joined(separator: "\n\n"), attachments)
        }
    }

    static func loadURL(from provider: NSItemProvider) async -> ExtractedItem? {
        do {
            let item = try await provider.loadItem(forTypeIdentifier: UTType.url.identifier)
            if let url = item as? URL {
                return .body(url.absoluteString)
            }
        } catch {}
        return nil
    }

    static func loadText(from provider: NSItemProvider) async -> ExtractedItem? {
        do {
            let item = try await provider.loadItem(forTypeIdentifier: UTType.plainText.identifier)
            if let text = item as? String {
                return .body(text)
            }
        } catch {}
        return nil
    }

    static func loadImage(from provider: NSItemProvider) async -> ExtractedItem? {
        let isPNG = provider.hasItemConformingToTypeIdentifier(UTType.png.identifier)
        let suggestedName = provider.suggestedName

        guard let data = await loadData(from: provider, for: UTType.image) else { return nil }

        let ext = isPNG ? "png" : "jpg"
        let mime = isPNG ? "image/png" : "image/jpeg"
        let filename = suggestedName.map { "\($0).\(ext)" } ?? "image.\(ext)"
        return .attachment(Attachment(data: data, mimeType: mime, filename: filename))
    }

    static func loadFile(from provider: NSItemProvider) async -> ExtractedItem? {
        let suggestedName = provider.suggestedName

        guard let data = await loadData(from: provider, for: UTType.data) else { return nil }

        let filename = filenameWithExtension(suggestedName: suggestedName, provider: provider)
        let mime = mimeType(for: filename)
        return .attachment(Attachment(data: data, mimeType: mime, filename: filename))
    }

    static func loadData(from provider: NSItemProvider, for type: UTType) async -> Data? {
        await withCheckedContinuation { continuation in
            provider.loadDataRepresentation(forTypeIdentifier: type.identifier) { data, _ in
                continuation.resume(returning: data)
            }
        }
    }

    static func filenameWithExtension(suggestedName: String?, provider: NSItemProvider) -> String {
        let name = suggestedName ?? "attachment"
        if !(name as NSString).pathExtension.isEmpty {
            return name
        }
        for identifier in provider.registeredTypeIdentifiers {
            if let utType = UTType(identifier), let ext = utType.preferredFilenameExtension {
                return "\(name).\(ext)"
            }
        }
        return name
    }

    static func mimeType(for filename: String) -> String {
        let ext = (filename as NSString).pathExtension.lowercased()
        if let utType = UTType(filenameExtension: ext) {
            return utType.preferredMIMEType ?? "application/octet-stream"
        }
        return "application/octet-stream"
    }
}
