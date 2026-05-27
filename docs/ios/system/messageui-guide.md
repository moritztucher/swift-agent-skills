# MessageUI Framework Guide for iOS Development

## Overview & Purpose

The **MessageUI** framework provides specialized view controllers for presenting standard composition interfaces for email and SMS/iMessage text messages. It allows your app to add message delivery capabilities without requiring users to leave your app.

### Key Components

| Component | Purpose |
|-----------|---------|
| `MFMailComposeViewController` | Compose and send email messages |
| `MFMessageComposeViewController` | Compose and send SMS/iMessage messages |
| `MFMailComposeViewControllerDelegate` | Handle email composition results |
| `MFMessageComposeViewControllerDelegate` | Handle message composition results |

### Framework Import

```swift
import MessageUI
```

### Platform Availability

- **iOS 3.0+** (original availability)
- **macCatalyst 13.1+**
- **visionOS 1.0+**

> **Note:** MessageUI is not available on watchOS or tvOS.

---

## MFMailComposeViewController for Email

`MFMailComposeViewController` is a standard view controller whose interface lets the user manage, edit, and send email messages. It inherits from `UINavigationController`.

### Key Methods and Properties

| Method/Property | Description |
|-----------------|-------------|
| `canSendMail()` | Class method to check if email is available |
| `setToRecipients(_:)` | Set primary recipients |
| `setCcRecipients(_:)` | Set CC recipients |
| `setBccRecipients(_:)` | Set BCC recipients |
| `setSubject(_:)` | Set email subject |
| `setMessageBody(_:isHTML:)` | Set email body (plain text or HTML) |
| `addAttachmentData(_:mimeType:fileName:)` | Add file attachment |
| `setPreferredSendingEmailAddress(_:)` | Set preferred sender address (iOS 11+) |
| `mailComposeDelegate` | Delegate for handling results |

### Basic Email Composition

```swift
import MessageUI

@Observable
final class EmailService {
    var canSendEmail: Bool {
        MFMailComposeViewController.canSendMail()
    }

    func createMailComposer(
        to recipients: [String],
        subject: String,
        body: String,
        isHTML: Bool = false
    ) -> MFMailComposeViewController? {
        guard canSendEmail else { return nil }

        let composer = MFMailComposeViewController()
        composer.setToRecipients(recipients)
        composer.setSubject(subject)
        composer.setMessageBody(body, isHTML: isHTML)

        return composer
    }
}
```

### Email with HTML Content

```swift
func createHTMLEmailComposer() -> MFMailComposeViewController? {
    guard MFMailComposeViewController.canSendMail() else { return nil }

    let composer = MFMailComposeViewController()
    composer.setToRecipients(["support@example.com"])
    composer.setSubject("Feedback")

    let htmlBody = """
    <html>
    <body>
        <h1>App Feedback</h1>
        <p>Hello,</p>
        <p>I would like to share my feedback about the app.</p>
        <ul>
            <li>Feature A works great</li>
            <li>Feature B needs improvement</li>
        </ul>
    </body>
    </html>
    """

    composer.setMessageBody(htmlBody, isHTML: true)

    return composer
}
```

---

## MFMessageComposeViewController for SMS/iMessage

`MFMessageComposeViewController` is a standard view controller for composing and sending SMS or MMS messages via the Messages app.

### Key Methods and Properties

| Method/Property | Description |
|-----------------|-------------|
| `canSendText()` | Class method to check if SMS is available |
| `canSendSubject()` | Check if subjects are supported |
| `canSendAttachments()` | Check if attachments are supported |
| `isSupportedAttachmentUTI(_:)` | Check if specific file type is supported |
| `recipients` | Array of recipient phone numbers |
| `body` | Message body text |
| `subject` | Message subject (if supported) |
| `message` | Associated MSMessage (for Messages extensions) |
| `disableUserAttachments()` | Disable user attachment additions |
| `addAttachmentURL(_:withAlternateFilename:)` | Add attachment via URL |
| `addAttachmentData(_:typeIdentifier:filename:)` | Add attachment via Data |
| `messageComposeDelegate` | Delegate for handling results |

### Basic Message Composition

```swift
import MessageUI

@Observable
final class MessageService {
    var canSendText: Bool {
        MFMessageComposeViewController.canSendText()
    }

    var canSendSubject: Bool {
        MFMessageComposeViewController.canSendSubject()
    }

    var canSendAttachments: Bool {
        MFMessageComposeViewController.canSendAttachments()
    }

    func createMessageComposer(
        to recipients: [String],
        body: String,
        subject: String? = nil
    ) -> MFMessageComposeViewController? {
        guard canSendText else { return nil }

        let composer = MFMessageComposeViewController()
        composer.recipients = recipients
        composer.body = body

        if let subject, canSendSubject {
            composer.subject = subject
        }

        return composer
    }
}
```

---

## Checking Availability

Always check device capabilities before attempting to present compose view controllers. These checks verify the device has the required accounts configured and can send messages.

### Email Availability

```swift
func checkEmailAvailability() -> Bool {
    guard MFMailComposeViewController.canSendMail() else {
        // Device cannot send mail
        // - No email account configured
        // - Mail services disabled
        // NOTE: Does not include third-party mail apps (Gmail, Outlook)
        return false
    }
    return true
}
```

### SMS/iMessage Availability

```swift
func checkMessageAvailability() -> (
    canSendText: Bool,
    canSendSubject: Bool,
    canSendAttachments: Bool
) {
    return (
        MFMessageComposeViewController.canSendText(),
        MFMessageComposeViewController.canSendSubject(),
        MFMessageComposeViewController.canSendAttachments()
    )
}
```

### Checking Specific Attachment Types

```swift
func canAttachImage() -> Bool {
    MFMessageComposeViewController.isSupportedAttachmentUTI("public.jpeg")
}

func canAttachPDF() -> Bool {
    MFMessageComposeViewController.isSupportedAttachmentUTI("com.adobe.pdf")
}
```

### Availability Check View Model

```swift
import MessageUI

@Observable
final class CommunicationViewModel {

    // MARK: - Computed Properties

    var emailAvailable: Bool {
        MFMailComposeViewController.canSendMail()
    }

    var smsAvailable: Bool {
        MFMessageComposeViewController.canSendText()
    }

    var availabilityMessage: String {
        var messages: [String] = []

        if !emailAvailable {
            messages.append("Email not configured on this device")
        }

        if !smsAvailable {
            messages.append("SMS not available on this device")
        }

        return messages.isEmpty ? "All communication methods available" : messages.joined(separator: "\n")
    }
}
```

---

## SwiftUI Integration

MessageUI view controllers require `UIViewControllerRepresentable` wrappers for SwiftUI integration. A Coordinator class handles the delegate callbacks.

### Mail Compose View (SwiftUI Wrapper)

```swift
import SwiftUI
import MessageUI

struct MailComposeView: UIViewControllerRepresentable {

    // MARK: - Configuration

    let recipients: [String]
    let subject: String
    let body: String
    let isHTML: Bool
    let attachments: [MailAttachment]
    let onDismiss: (Result<MFMailComposeResult, Error>) -> Void

    // MARK: - Attachment Model

    struct MailAttachment {
        let data: Data
        let mimeType: String
        let fileName: String
    }

    // MARK: - Initializer

    init(
        recipients: [String] = [],
        subject: String = "",
        body: String = "",
        isHTML: Bool = false,
        attachments: [MailAttachment] = [],
        onDismiss: @escaping (Result<MFMailComposeResult, Error>) -> Void
    ) {
        self.recipients = recipients
        self.subject = subject
        self.body = body
        self.isHTML = isHTML
        self.attachments = attachments
        self.onDismiss = onDismiss
    }

    // MARK: - UIViewControllerRepresentable

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let controller = MFMailComposeViewController()
        controller.mailComposeDelegate = context.coordinator
        controller.setToRecipients(recipients)
        controller.setSubject(subject)
        controller.setMessageBody(body, isHTML: isHTML)

        for attachment in attachments {
            controller.addAttachmentData(
                attachment.data,
                mimeType: attachment.mimeType,
                fileName: attachment.fileName
            )
        }

        return controller
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {
        // No updates needed after initial configuration
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onDismiss: onDismiss)
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let onDismiss: (Result<MFMailComposeResult, Error>) -> Void

        init(onDismiss: @escaping (Result<MFMailComposeResult, Error>) -> Void) {
            self.onDismiss = onDismiss
        }

        func mailComposeController(
            _ controller: MFMailComposeViewController,
            didFinishWith result: MFMailComposeResult,
            error: Error?
        ) {
            if let error {
                onDismiss(.failure(error))
            } else {
                onDismiss(.success(result))
            }
            controller.dismiss(animated: true)
        }
    }
}
```

### Message Compose View (SwiftUI Wrapper)

```swift
import SwiftUI
import MessageUI

struct MessageComposeView: UIViewControllerRepresentable {

    // MARK: - Configuration

    let recipients: [String]
    let body: String
    let subject: String?
    let attachments: [MessageAttachment]
    let onDismiss: (MessageComposeResult) -> Void

    // MARK: - Attachment Model

    struct MessageAttachment {
        let url: URL
        let alternateFilename: String?

        init(url: URL, alternateFilename: String? = nil) {
            self.url = url
            self.alternateFilename = alternateFilename
        }
    }

    // MARK: - Initializer

    init(
        recipients: [String] = [],
        body: String = "",
        subject: String? = nil,
        attachments: [MessageAttachment] = [],
        onDismiss: @escaping (MessageComposeResult) -> Void
    ) {
        self.recipients = recipients
        self.body = body
        self.subject = subject
        self.attachments = attachments
        self.onDismiss = onDismiss
    }

    // MARK: - UIViewControllerRepresentable

    func makeUIViewController(context: Context) -> MFMessageComposeViewController {
        let controller = MFMessageComposeViewController()
        controller.messageComposeDelegate = context.coordinator
        controller.recipients = recipients
        controller.body = body

        if let subject, MFMessageComposeViewController.canSendSubject() {
            controller.subject = subject
        }

        if MFMessageComposeViewController.canSendAttachments() {
            for attachment in attachments {
                controller.addAttachmentURL(
                    attachment.url,
                    withAlternateFilename: attachment.alternateFilename
                )
            }
        }

        return controller
    }

    func updateUIViewController(_ uiViewController: MFMessageComposeViewController, context: Context) {
        // No updates needed after initial configuration
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onDismiss: onDismiss)
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
        let onDismiss: (MessageComposeResult) -> Void

        init(onDismiss: @escaping (MessageComposeResult) -> Void) {
            self.onDismiss = onDismiss
        }

        func messageComposeViewController(
            _ controller: MFMessageComposeViewController,
            didFinishWith result: MessageComposeResult
        ) {
            onDismiss(result)
            controller.dismiss(animated: true)
        }
    }
}
```

### Complete SwiftUI Usage Example

```swift
import SwiftUI
import MessageUI

struct ContactView: View {

    // MARK: - State

    @State private var showMailComposer = false
    @State private var showMessageComposer = false
    @State private var alertMessage = ""
    @State private var showAlert = false

    // MARK: - Computed Properties

    private var canSendMail: Bool {
        MFMailComposeViewController.canSendMail()
    }

    private var canSendText: Bool {
        MFMessageComposeViewController.canSendText()
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 20) {
            Button("Send Email") {
                if canSendMail {
                    showMailComposer = true
                } else {
                    alertMessage = "Email is not configured on this device."
                    showAlert = true
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canSendMail)

            Button("Send Message") {
                if canSendText {
                    showMessageComposer = true
                } else {
                    alertMessage = "SMS is not available on this device."
                    showAlert = true
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canSendText)
        }
        .sheet(isPresented: $showMailComposer) {
            MailComposeView(
                recipients: ["support@example.com"],
                subject: "App Feedback",
                body: "Hello, I have some feedback..."
            ) { result in
                handleMailResult(result)
            }
        }
        .sheet(isPresented: $showMessageComposer) {
            MessageComposeView(
                recipients: ["+1234567890"],
                body: "Check out this app!"
            ) { result in
                handleMessageResult(result)
            }
        }
        .alert("Notice", isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }

    // MARK: - Methods

    private func handleMailResult(_ result: Result<MFMailComposeResult, Error>) {
        switch result {
        case .success(let composeResult):
            switch composeResult {
            case .cancelled:
                alertMessage = "Email cancelled"
            case .saved:
                alertMessage = "Email saved as draft"
            case .sent:
                alertMessage = "Email sent successfully"
            case .failed:
                alertMessage = "Email failed to send"
            @unknown default:
                alertMessage = "Unknown result"
            }
        case .failure(let error):
            alertMessage = "Error: \(error.localizedDescription)"
        }
        showAlert = true
    }

    private func handleMessageResult(_ result: MessageComposeResult) {
        switch result {
        case .cancelled:
            alertMessage = "Message cancelled"
        case .sent:
            alertMessage = "Message sent successfully"
        case .failed:
            alertMessage = "Message failed to send"
        @unknown default:
            alertMessage = "Unknown result"
        }
        showAlert = true
    }
}
```

---

## Pre-populating Recipients, Subject, Body, Attachments

### Email Pre-population

```swift
func createFeedbackEmail(
    userEmail: String,
    appVersion: String,
    deviceInfo: String
) -> MFMailComposeViewController? {
    guard MFMailComposeViewController.canSendMail() else { return nil }

    let composer = MFMailComposeViewController()

    // Recipients
    composer.setToRecipients(["support@example.com"])
    composer.setCcRecipients(["feedback@example.com"])

    // Subject with app info
    composer.setSubject("[\(appVersion)] App Feedback")

    // Body with device info
    let body = """
    Please describe your feedback below:



    ---
    Device Info: \(deviceInfo)
    App Version: \(appVersion)
    User: \(userEmail)
    """
    composer.setMessageBody(body, isHTML: false)

    return composer
}
```

### Adding Attachments

```swift
// MARK: - Image Attachment

func addImageAttachment(
    to composer: MFMailComposeViewController,
    image: UIImage,
    fileName: String = "image.jpg"
) {
    guard let imageData = image.jpegData(compressionQuality: 0.8) else { return }

    composer.addAttachmentData(
        imageData,
        mimeType: "image/jpeg",
        fileName: fileName
    )
}

// MARK: - PDF Attachment

func addPDFAttachment(
    to composer: MFMailComposeViewController,
    pdfData: Data,
    fileName: String = "document.pdf"
) {
    composer.addAttachmentData(
        pdfData,
        mimeType: "application/pdf",
        fileName: fileName
    )
}

// MARK: - JSON Attachment

func addJSONAttachment(
    to composer: MFMailComposeViewController,
    jsonData: Data,
    fileName: String = "data.json"
) {
    composer.addAttachmentData(
        jsonData,
        mimeType: "application/json",
        fileName: fileName
    )
}

// MARK: - File from Bundle

func addBundleFileAttachment(
    to composer: MFMailComposeViewController,
    resourceName: String,
    resourceType: String,
    mimeType: String
) {
    guard let filePath = Bundle.main.path(forResource: resourceName, ofType: resourceType),
          let fileData = FileManager.default.contents(atPath: filePath) else {
        return
    }

    composer.addAttachmentData(
        fileData,
        mimeType: mimeType,
        fileName: "\(resourceName).\(resourceType)"
    )
}
```

### SMS with Attachments

```swift
func createMessageWithAttachment(
    recipients: [String],
    body: String,
    imageURL: URL
) -> MFMessageComposeViewController? {
    guard MFMessageComposeViewController.canSendText(),
          MFMessageComposeViewController.canSendAttachments() else {
        return nil
    }

    let composer = MFMessageComposeViewController()
    composer.recipients = recipients
    composer.body = body

    // Add image attachment
    composer.addAttachmentURL(imageURL, withAlternateFilename: "shared_image.jpg")

    return composer
}

// Using Data instead of URL
func addDataAttachmentToMessage(
    to composer: MFMessageComposeViewController,
    data: Data,
    typeIdentifier: String,
    filename: String
) {
    composer.addAttachmentData(data, typeIdentifier: typeIdentifier, filename: filename)
}
```

---

## Handling Completion Results

### MFMailComposeResult Enum

| Case | Description |
|------|-------------|
| `.cancelled` | User cancelled the email composition |
| `.saved` | User saved the email as a draft |
| `.sent` | User sent the email |
| `.failed` | Email failed to send (check error) |

### MFMailComposeError

| Error Code | Description |
|------------|-------------|
| `.saveFailed` | Email could not be saved as draft |
| `.sendFailed` | Email could not be sent |

### MessageComposeResult Enum

| Case | Description |
|------|-------------|
| `.cancelled` | User cancelled the message |
| `.sent` | User sent the message |
| `.failed` | Message failed to send |

### Comprehensive Result Handler

```swift
import MessageUI

enum CommunicationResult {
    case emailSent
    case emailSaved
    case emailCancelled
    case emailFailed(Error?)
    case messageSent
    case messageCancelled
    case messageFailed

    var userMessage: String {
        switch self {
        case .emailSent:
            return "Your email has been sent successfully."
        case .emailSaved:
            return "Your email has been saved as a draft."
        case .emailCancelled:
            return "Email composition was cancelled."
        case .emailFailed(let error):
            if let error {
                return "Failed to send email: \(error.localizedDescription)"
            }
            return "Failed to send email. Please try again."
        case .messageSent:
            return "Your message has been sent successfully."
        case .messageCancelled:
            return "Message composition was cancelled."
        case .messageFailed:
            return "Failed to send message. Please try again."
        }
    }

    var isSuccess: Bool {
        switch self {
        case .emailSent, .emailSaved, .messageSent:
            return true
        default:
            return false
        }
    }
}

// MARK: - Result Conversion Extensions

extension MFMailComposeResult {
    func toCommunicationResult(error: Error?) -> CommunicationResult {
        switch self {
        case .cancelled:
            return .emailCancelled
        case .saved:
            return .emailSaved
        case .sent:
            return .emailSent
        case .failed:
            return .emailFailed(error)
        @unknown default:
            return .emailFailed(nil)
        }
    }
}

extension MessageComposeResult {
    func toCommunicationResult() -> CommunicationResult {
        switch self {
        case .cancelled:
            return .messageCancelled
        case .sent:
            return .messageSent
        case .failed:
            return .messageFailed
        @unknown default:
            return .messageFailed
        }
    }
}
```

### Using async/await Pattern for Results

```swift
import MessageUI

actor MailComposeManager {
    private var continuation: CheckedContinuation<CommunicationResult, Never>?

    func presentMailComposer(
        from viewController: UIViewController,
        recipients: [String],
        subject: String,
        body: String
    ) async -> CommunicationResult {
        guard MFMailComposeViewController.canSendMail() else {
            return .emailFailed(nil)
        }

        return await withCheckedContinuation { continuation in
            Task { @MainActor in
                self.continuation = continuation

                let composer = MFMailComposeViewController()
                composer.mailComposeDelegate = self
                composer.setToRecipients(recipients)
                composer.setSubject(subject)
                composer.setMessageBody(body, isHTML: false)

                viewController.present(composer, animated: true)
            }
        }
    }
}

extension MailComposeManager: MFMailComposeViewControllerDelegate {
    nonisolated func mailComposeController(
        _ controller: MFMailComposeViewController,
        didFinishWith result: MFMailComposeResult,
        error: Error?
    ) {
        Task { @MainActor in
            controller.dismiss(animated: true)

            let communicationResult = result.toCommunicationResult(error: error)
            self.continuation?.resume(returning: communicationResult)
            self.continuation = nil
        }
    }
}
```

---

## iOS 18/26 Specific Features

### iOS 18 Considerations

While the MessageUI framework API has remained stable, iOS 18 introduced several changes to the Mail app experience:

1. **Tabbed Inboxes:** Mail now automatically sorts emails into categories (Primary, Transactions, Updates, Promotions)

2. **Enhanced Privacy:** Apple continues to emphasize privacy, which may affect email tracking and analytics

3. **Email Clipping:** More aggressive message clipping in the inbox - keep compose messages concise

### iOS 26 and Beyond

As of iOS 26, the MessageUI framework maintains backward compatibility. Key considerations:

1. **Liquid Glass UI:** When presenting mail/message composers, they integrate with the system's Liquid Glass design language automatically

2. **Privacy Manifest:** If your app uses MessageUI, ensure you have appropriate Privacy Manifest entries for any data collection

3. **No Breaking Changes:** MFMailComposeViewController and MFMessageComposeViewController APIs remain unchanged

### Checking iOS Version for Feature Availability

```swift
func checkiOSFeatures() {
    if #available(iOS 18, *) {
        // iOS 18+ specific handling
        print("Running on iOS 18+")
    }

    if #available(iOS 26, *) {
        // iOS 26+ specific handling
        print("Running on iOS 26+")
    }
}
```

### iPad Considerations

```swift
// Configure popover presentation for iPad
func presentMailComposer(
    from viewController: UIViewController,
    sourceView: UIView? = nil,
    sourceRect: CGRect? = nil
) {
    guard MFMailComposeViewController.canSendMail() else { return }

    let composer = MFMailComposeViewController()

    // Configure for iPad popover if needed
    if let popover = composer.popoverPresentationController {
        popover.sourceView = sourceView ?? viewController.view
        popover.sourceRect = sourceRect ?? CGRect(
            x: viewController.view.bounds.midX,
            y: viewController.view.bounds.midY,
            width: 0,
            height: 0
        )
        popover.permittedArrowDirections = .any
    }

    viewController.present(composer, animated: true)
}
```

---

## Common Use Cases

### 1. Bug Report / Feedback Email

```swift
import UIKit
import MessageUI

@Observable
final class FeedbackManager {

    // MARK: - Properties

    private let supportEmail = "support@example.com"

    // MARK: - Methods

    func createBugReportComposer() -> MFMailComposeViewController? {
        guard MFMailComposeViewController.canSendMail() else { return nil }

        let composer = MFMailComposeViewController()
        composer.setToRecipients([supportEmail])
        composer.setSubject("Bug Report - \(appName) v\(appVersion)")

        let body = """
        Please describe the issue you encountered:



        Steps to reproduce:
        1.
        2.
        3.

        Expected behavior:


        Actual behavior:


        ---
        Debug Information (do not edit):
        App Version: \(appVersion)
        Build: \(buildNumber)
        iOS Version: \(iOSVersion)
        Device: \(deviceModel)
        Locale: \(Locale.current.identifier)
        """

        composer.setMessageBody(body, isHTML: false)

        return composer
    }

    // MARK: - Private Helpers

    private var appName: String {
        Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "Unknown"
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }

    private var iOSVersion: String {
        UIDevice.current.systemVersion
    }

    private var deviceModel: String {
        UIDevice.current.model
    }
}
```

### 2. Share via SMS/iMessage

```swift
@Observable
final class ShareManager {

    func createShareMessage(
        itemName: String,
        shareLink: URL
    ) -> MFMessageComposeViewController? {
        guard MFMessageComposeViewController.canSendText() else { return nil }

        let composer = MFMessageComposeViewController()
        composer.body = "Check out \(itemName)! \(shareLink.absoluteString)"

        return composer
    }

    func createInviteMessage(
        friendName: String,
        inviteCode: String
    ) -> MFMessageComposeViewController? {
        guard MFMessageComposeViewController.canSendText() else { return nil }

        let composer = MFMessageComposeViewController()
        composer.body = """
        Hey \(friendName)! I've been using this amazing app and thought you'd love it too. \
        Use my invite code \(inviteCode) to get started!
        """

        return composer
    }
}
```

### 3. Export Data via Email

```swift
func exportDataAsEmail(data: Codable) async throws -> MFMailComposeViewController? {
    guard MFMailComposeViewController.canSendMail() else { return nil }

    let composer = MFMailComposeViewController()
    composer.setSubject("Data Export - \(Date().formatted(date: .abbreviated, time: .shortened))")
    composer.setMessageBody("Please find your exported data attached.", isHTML: false)

    // Encode and attach data
    let encoder = JSONEncoder()
    encoder.outputFormatting = .prettyPrinted
    let jsonData = try encoder.encode(data)

    composer.addAttachmentData(
        jsonData,
        mimeType: "application/json",
        fileName: "export_\(Date().ISO8601Format()).json"
    )

    return composer
}
```

### 4. Contact Support with Screenshot

```swift
import UIKit
import MessageUI

func createSupportEmailWithScreenshot(
    screenshot: UIImage,
    issueDescription: String
) -> MFMailComposeViewController? {
    guard MFMailComposeViewController.canSendMail() else { return nil }

    let composer = MFMailComposeViewController()
    composer.setToRecipients(["support@example.com"])
    composer.setSubject("Support Request")
    composer.setMessageBody(issueDescription, isHTML: false)

    // Attach screenshot
    if let imageData = screenshot.jpegData(compressionQuality: 0.7) {
        composer.addAttachmentData(
            imageData,
            mimeType: "image/jpeg",
            fileName: "screenshot.jpg"
        )
    }

    return composer
}
```

### 5. Share Location via Message

```swift
import CoreLocation
import MessageUI

func createLocationShareMessage(
    location: CLLocation,
    placeName: String?
) -> MFMessageComposeViewController? {
    guard MFMessageComposeViewController.canSendText() else { return nil }

    let composer = MFMessageComposeViewController()

    let mapsURL = "https://maps.apple.com/?ll=\(location.coordinate.latitude),\(location.coordinate.longitude)"

    if let placeName {
        composer.body = "I'm at \(placeName)! \(mapsURL)"
    } else {
        composer.body = "Here's my location: \(mapsURL)"
    }

    return composer
}
```

---

## Best Practices & Limitations

### Best Practices

1. **Always Check Availability First**
   ```swift
   // Check before showing compose buttons
   if MFMailComposeViewController.canSendMail() {
       // Show email button
   }
   ```

2. **Handle All Result Cases**
   - Always implement the delegate and handle all possible results
   - Never ignore the delegate callback

3. **Dismiss the Controller**
   - You are responsible for dismissing the compose view controller
   - Always dismiss in the delegate callback

4. **Pre-populate Thoughtfully**
   - Provide helpful defaults but allow user modification
   - Include device/app info in bug reports

5. **Test on Real Devices**
   - SMS functionality only works on physical devices
   - Email requires a configured account

6. **Use Environment Pattern for SwiftUI**
   ```swift
   // Create a reusable mail capability environment value
   extension EnvironmentValues {
       @Entry var canSendMail: Bool = MFMailComposeViewController.canSendMail()
   }
   ```

7. **Provide Fallback Options**
   ```swift
   func openMailFallback(to email: String, subject: String) {
       let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
       if let url = URL(string: "mailto:\(email)?subject=\(encodedSubject)") {
           UIApplication.shared.open(url)
       }
   }
   ```

### Limitations

1. **No Programmatic Sending**
   - Users must manually tap "Send" - you cannot send emails/messages programmatically
   - This is by design for privacy and security

2. **canSendMail() Only Checks Native Mail**
   - Does not detect third-party email apps (Gmail, Outlook, etc.)
   - Consider offering mailto: URL fallback

3. **Simulator Limitations**
   - SMS does not work on Simulator
   - Email requires a configured account

4. **No Access to Sent Messages**
   - You receive confirmation the user sent, but no access to the actual sent message
   - No access to user's mail or message history

5. **Appearance Customization Limited**
   - Cannot fully customize the compose view controller appearance
   - Navigation bar tint can be adjusted but overall style follows system

6. **iPad Presentation**
   - May require popover configuration on iPad
   - Some users report issues with SwiftUI sheet presentation on iPad

7. **Privacy Manifest Requirements**
   - If collecting any user data via email/message, include in Privacy Manifest
   - No NSPrivacyAccessedAPITypes entries specifically required for MessageUI

### Error Handling Recommendations

```swift
enum MessageUIError: LocalizedError {
    case mailNotAvailable
    case smsNotAvailable
    case attachmentFailed
    case compositionFailed(Error)

    var errorDescription: String? {
        switch self {
        case .mailNotAvailable:
            return "Email is not configured on this device. Please set up an email account in Settings."
        case .smsNotAvailable:
            return "SMS is not available on this device."
        case .attachmentFailed:
            return "Failed to attach the file. Please try again."
        case .compositionFailed(let error):
            return "Failed to compose message: \(error.localizedDescription)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .mailNotAvailable:
            return "Go to Settings > Mail > Accounts to add an email account."
        case .smsNotAvailable:
            return "Ensure your device has cellular capabilities and a SIM card installed."
        case .attachmentFailed:
            return "Check that the file exists and is accessible."
        case .compositionFailed:
            return "Try closing and reopening the app."
        }
    }
}
```

---

## Quick Reference

### Email Composition Checklist

- [ ] Import MessageUI
- [ ] Check `MFMailComposeViewController.canSendMail()`
- [ ] Create MFMailComposeViewController
- [ ] Set `mailComposeDelegate`
- [ ] Configure recipients, subject, body
- [ ] Add attachments if needed
- [ ] Present the controller
- [ ] Handle delegate callback
- [ ] Dismiss controller in delegate

### SMS Composition Checklist

- [ ] Import MessageUI
- [ ] Check `MFMessageComposeViewController.canSendText()`
- [ ] Check `canSendSubject()` / `canSendAttachments()` if needed
- [ ] Create MFMessageComposeViewController
- [ ] Set `messageComposeDelegate`
- [ ] Configure recipients and body
- [ ] Add attachments if supported
- [ ] Present the controller (real device only)
- [ ] Handle delegate callback
- [ ] Dismiss controller in delegate

### Common MIME Types for Attachments

| File Type | MIME Type |
|-----------|-----------|
| JPEG Image | `image/jpeg` |
| PNG Image | `image/png` |
| PDF Document | `application/pdf` |
| JSON | `application/json` |
| Plain Text | `text/plain` |
| CSV | `text/csv` |
| ZIP Archive | `application/zip` |
| MP4 Video | `video/mp4` |
| MP3 Audio | `audio/mpeg` |
