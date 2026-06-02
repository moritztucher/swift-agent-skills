# Core NFC — Deep Reference

Core NFC reads (and writes) NFC tags on iPhone. Two session classes cover almost everything: `NFCNDEFReaderSession` for NDEF-formatted tags, and `NFCTagReaderSession` for raw tag protocols (ISO 7816, ISO 15693, MiFare, FeliCa). Plus background tag reading, where the system scans for you and launches your app.

Source: Apple Core NFC docs via Context7 (`/websites/developer_apple_corenfc`). Verified 2026-06-02.

---

## 1. Capabilities and platform support

| Capability | API | Min OS | Hardware |
|---|---|---|---|
| Read/write NDEF | `NFCNDEFReaderSession` | iOS 11 (write iOS 13) | iPhone 7+ |
| Raw tag protocols (ISO 7816 / 15693 / MiFare / FeliCa) | `NFCTagReaderSession` | iOS 13 | iPhone 7+ |
| Background NDEF tag reading | `NFCNDEFReaderSession` (system-driven) | iOS 12 | iPhone XS+ |
| VAS / card emulation | `NFCVASReaderSession`, `CardSession` | iOS 13 / iOS 17.4 | varies |

Core NFC is **iPhone only**. iPad has no NFC reader hardware — `NFCNDEFReaderSession.readingAvailable` / `NFCTagReaderSession.readingAvailable` return `false`. Mac Catalyst compiles but is unsupported at runtime. Always gate behind the availability check:

```swift
guard NFCNDEFReaderSession.readingAvailable else {
    // No NFC hardware or NFC disabled. Hide/disable the scan UI.
    return
}
```

`NFCTagReaderSession` requires an iPhone 7 or later; tag sessions are unavailable on devices older than that even though `NFCNDEFReaderSession` is not.

---

## 2. Project setup — entitlement + Info.plist (mandatory)

Reading anything requires three pieces of configuration. Miss them and the app either crashes at session `begin()` or the session immediately invalidates.

### 2.1 The entitlement

Add the **Near Field Communication Tag Reading** capability in Xcode (Signing & Capabilities). This writes the entitlement:

```xml
<!-- App.entitlements -->
<key>com.apple.developer.nfc.readersession.formats</key>
<array>
    <string>NDEF</string>   <!-- required for NFCNDEFReaderSession -->
    <string>TAG</string>    <!-- required for NFCTagReaderSession (raw protocols) -->
</array>
```

- `NDEF` — enables `NFCNDEFReaderSession`.
- `TAG` — enables `NFCTagReaderSession` (ISO 7816, 15693, MiFare, FeliCa).

Without the matching format string, instantiating the session throws / the capability check fails. This entitlement also requires a matching App ID capability in the developer portal and a provisioning profile that includes it.

### 2.2 NFCReaderUsageDescription (Info.plist) — required

```xml
<key>NFCReaderUsageDescription</key>
<string>This app reads NFC tags to look up product details.</string>
```

This privacy string is **required** for any reader session. If it is missing, `begin()` raises an exception and the app crashes. There is no permission prompt the way camera/location have — the string is shown contextually, but it must exist.

### 2.3 ISO 7816 application identifiers (required for ISO 7816)

To talk to ISO 7816 smartcard applets you must declare the AIDs you intend to select, as an Info.plist array. The system uses these for hardware-level filtering during polling.

```xml
<key>com.apple.developer.nfc.readersession.iso7816.select-identifiers</key>
<array>
    <string>A0000000031010</string>   <!-- Visa -->
    <string>A0000000041010</string>   <!-- Mastercard -->
</array>
```

`NFCTagReaderSession.Configuration.iso7816SelectIdentifiers` (and the legacy `NFCTagReaderSession(pollingOption:delegate:queue:)` path) only use AIDs that are listed here — unknown entries passed at runtime are dropped. An empty runtime array means "use everything in Info.plist". Without at least one declared AID, ISO 7816 tags will not be discovered.

### 2.4 FeliCa system codes (required for FeliCa)

```xml
<key>com.apple.developer.nfc.readersession.felica.systemcodes</key>
<array>
    <string>0003</string>   <!-- Suica/transit -->
    <string>FE00</string>   <!-- common -->
</array>
```

Same rule as ISO 7816: FeliCa system codes must be pre-declared in Info.plist or polling won't surface the tag.

### 2.5 Background tag reading (optional)

To support background NDEF reads (system scans, then launches your app), declare the record types you handle:

```xml
<key>com.apple.developer.nfc.readersession.formats</key>
<array><string>NDEF</string></array>

<!-- Background reading also requires the associated-domains / app to be installed;
     no extra plist key beyond NDEF format. The system delivers the NDEF via
     the app's scene/Universal Link mechanism. -->
```

See §7.

---

## 3. NDEF reading — `NFCNDEFReaderSession`

### 3.1 Lifecycle

```swift
import CoreNFC

final class NDEFReader: NSObject, NFCNDEFReaderSessionDelegate {
    private var session: NFCNDEFReaderSession?

    func beginScanning() {
        guard NFCNDEFReaderSession.readingAvailable else { return }
        // A session is single-use. Create a fresh one for every scan.
        session = NFCNDEFReaderSession(delegate: self,
                                       queue: nil,
                                       invalidateAfterFirstRead: true)
        session?.alertMessage = "Hold your iPhone near an NFC tag."
        session?.begin()   // triggers the system scan sheet
    }

    // Simple read path: system reads the NDEF for you.
    func readerSession(_ session: NFCNDEFReaderSession,
                       didDetectNDEFs messages: [NFCNDEFMessage]) {
        for message in messages {
            for record in message.records {
                // record.typeNameFormat, record.type, record.payload, record.identifier
                handle(record)
            }
        }
        // With invalidateAfterFirstRead: true the session ends automatically.
    }

    func readerSession(_ session: NFCNDEFReaderSession,
                       didInvalidateWithError error: Error) {
        // Always called when the session ends. See §6 for error handling.
        self.session = nil
    }
}
```

**Initializer**: `init(delegate:queue:invalidateAfterFirstRead:)`.
- `queue: nil` → an internal serial queue is created; callbacks are NOT on the main thread, so hop to main before touching UI.
- `invalidateAfterFirstRead: true` → ends after the first successful read and delivers `readerSessionInvalidationErrorFirstNDEFTagRead` in `didInvalidateWithError` (this is a normal end, not a failure).
- `invalidateAfterFirstRead: false` → required for writing and for reading multiple tags in one session.

`begin()` presents the system scan sheet; `invalidate()` (or `invalidate(errorMessage:)`) ends the session and dismisses it. `session.alertMessage` updates the sheet text mid-scan; `session.restartPolling()` resumes scanning after handling a tag without tearing the sheet down.

### 3.2 `NFCNDEFMessage` / `NFCNDEFPayload`

- `NFCNDEFMessage(records: [NFCNDEFPayload])` — an ordered list of records.
- `NFCNDEFPayload(format:type:identifier:payload:)`, where `format` is an `NFCTypeNameFormat` (`.nfcWellKnown`, `.media`, `.absoluteURI`, `.nfcExternal`, `.empty`, `.unknown`, `.unchanged`).
- Convenience constructors: `NFCNDEFPayload.wellKnownTypeURIPayload(url:)` and `.wellKnownTypeTextPayload(string:locale:)`.
- Convenience decoders: `payload.wellKnownTypeURIPayload()` → `URL?`, `payload.wellKnownTypeTextPayload()` → `(String?, Locale?)`.

---

## 4. NDEF writing — `didDetect tags` path

Writing requires the richer delegate callback `readerSession(_:didDetect:)` that hands you `[NFCNDEFTag]`. You must **connect**, then **query NDEF status**, then **write**. Skipping the status query risks writing to a read-only or non-NDEF tag and getting an error.

```swift
func beginWriting(_ message: NFCNDEFMessage) {
    self.message = message
    session = NFCNDEFReaderSession(delegate: self, queue: nil,
                                   invalidateAfterFirstRead: false)  // must be false to write
    session?.alertMessage = "Hold your iPhone near a tag to write."
    session?.begin()
}

func readerSession(_ session: NFCNDEFReaderSession,
                   didDetect tags: [NFCNDEFTag]) {
    if tags.count > 1 {
        session.alertMessage = "More than one tag detected. Remove all and try again."
        DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(500)) {
            session.restartPolling()
        }
        return
    }
    let tag = tags.first!
    session.connect(to: tag) { error in
        if error != nil {
            session.invalidate(errorMessage: "Unable to connect to tag.")
            return
        }
        tag.queryNDEFStatus { status, capacity, error in
            guard error == nil else {
                session.invalidate(errorMessage: "Unable to query NDEF status.")
                return
            }
            switch status {
            case .notSupported:
                session.invalidate(errorMessage: "Tag is not NDEF compliant.")
            case .readOnly:
                session.invalidate(errorMessage: "Tag is read only.")
            case .readWrite:
                // Optionally compare message length against `capacity`.
                tag.writeNDEF(self.message) { error in
                    if let error {
                        session.invalidate(errorMessage: "Write failed: \(error)")
                    } else {
                        session.alertMessage = "Write successful."
                        session.invalidate()
                    }
                }
            @unknown default:
                session.invalidate(errorMessage: "Unknown tag status.")
            }
        }
    }
}
```

### `NFCNDEFTag` protocol

| Member | Purpose |
|---|---|
| `isAvailable: Bool` | Tag still in the field for this session. |
| `queryNDEFStatus(completionHandler:)` | `(NFCNDEFStatus, capacity: Int, Error?)`. Status: `.notSupported`, `.readOnly`, `.readWrite`. |
| `readNDEF(completionHandler:)` | `(NFCNDEFMessage?, Error?)` — manual read after `connect`. |
| `writeNDEF(_:completionHandler:)` | Save a message to a `.readWrite` tag. |
| `writeLock(completionHandler:)` | Make the tag permanently read-only. Irreversible. |

`didDetectNDEFs:` (simple) and `didDetect tags:` (connect/read/write) are mutually exclusive in practice — implement the one you need. The `tags` callback is what you use for writing and for any read that needs `connect`.

---

## 5. Raw tag protocols — `NFCTagReaderSession`

For ISO 7816 smartcards, ISO 15693, MiFare, and FeliCa you need `NFCTagReaderSession`, which exposes the underlying protocol after you connect.

### 5.1 Polling options

`NFCTagReaderSession.PollingOption` is an option set:
- `.iso14443` — ISO 14443 type A/B → covers ISO 7816 and MiFare.
- `.iso15693` — ISO 15693 (vicinity cards).
- `.iso18092` — FeliCa.
- `.pace` — PACE for ISO 7816 (e.g. ePassports).

### 5.2 Start a session and dispatch by tag type

```swift
final class TagReader: NSObject, NFCTagReaderSessionDelegate {
    private var session: NFCTagReaderSession?

    func begin() {
        guard NFCTagReaderSession.readingAvailable else { return }
        session = NFCTagReaderSession(pollingOption: [.iso14443, .iso18092],
                                      delegate: self, queue: nil)
        session?.alertMessage = "Hold your iPhone near the card."
        session?.begin()
    }

    func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {}

    func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        guard let first = tags.first else { return }
        if tags.count > 1 {
            session.alertMessage = "More than one tag. Present a single card."
            DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(500)) {
                session.restartPolling()
            }
            return
        }
        session.connect(to: first) { error in
            if let error {
                session.invalidate(errorMessage: error.localizedDescription)
                return
            }
            switch first {
            case let .iso7816(tag):  self.handleISO7816(tag, session)
            case let .miFare(tag):   self.handleMiFare(tag, session)
            case let .feliCa(tag):   self.handleFeliCa(tag, session)
            case let .iso15693(tag): self.handleISO15693(tag, session)
            @unknown default:
                session.invalidate(errorMessage: "Unsupported tag.")
            }
        }
    }

    func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
        self.session = nil
    }
}
```

`NFCTag` is an enum: `.iso7816(NFCISO7816Tag)`, `.miFare(NFCMiFareTag)`, `.feliCa(NFCFeliCaTag)`, `.iso15693(NFCISO15693Tag)`. You must `connect(to:)` before issuing protocol commands.

### 5.3 ISO 7816 — `NFCISO7816Tag`

Smartcard APDU exchange. Useful properties: `identifier`, `historicalBytes`, `applicationData`, `initialSelectedAID`.

```swift
func handleISO7816(_ tag: NFCISO7816Tag, _ session: NFCTagReaderSession) {
    let apdu = NFCISO7816APDU(instructionClass: 0x00, instructionCode: 0xB0,
                              p1Parameter: 0x00, p2Parameter: 0x00,
                              data: Data(), expectedResponseLength: 256)
    tag.sendCommand(apdu: apdu) { responseData, sw1, sw2, error in
        if let error {
            session.invalidate(errorMessage: error.localizedDescription)
            return
        }
        // sw1/sw2 == 0x90/0x00 means success in ISO 7816 terms.
        process(responseData, sw1, sw2)
        session.invalidate()
    }
}
```

You can also init an APDU from raw bytes: `NFCISO7816APDU(data:)`. Remember the AID(s) you select must be in the `iso7816.select-identifiers` Info.plist array (§2.3).

### 5.4 MiFare — `NFCMiFareTag`

```swift
func handleMiFare(_ tag: NFCMiFareTag, _ session: NFCTagReaderSession) {
    // tag.mifareFamily (.ultralight / .plus / .desfire / .unknown), tag.identifier, tag.historicalBytes
    let command = Data([0x30, 0x04])   // READ page 4
    tag.sendMiFareCommand(commandPacket: command) { response, error in
        if let error {
            session.invalidate(errorMessage: error.localizedDescription)
            return
        }
        process(response)
        session.invalidate()
    }
}
```

MiFare DESFire/Plus can also use `sendMiFareISO7816Command(_:completionHandler:)` to wrap APDUs.

### 5.5 FeliCa — `NFCFeliCaTag`

Rich command surface (`currentSystemCode`, `currentIDm`, `polling`, `requestService`, `requestResponse`, `requestSystemCode`, `readWithoutEncryption`, `writeWithoutEncryption`, `sendFeliCaCommand`). Newer overloads take a `resultHandler: (Result<…, Error>)`.

```swift
func handleFeliCa(_ tag: NFCFeliCaTag, _ session: NFCTagReaderSession) {
    tag.requestSystemCode { systemCodes, error in
        if let error {
            session.invalidate(errorMessage: error.localizedDescription)
            return
        }
        // systemCodes: [Data]
        session.invalidate()
    }
}
```

FeliCa system codes must be declared in Info.plist (§2.4).

### 5.6 ISO 15693 — `NFCISO15693Tag`

Vicinity tags with their own command set (`readSingleBlock`, `writeSingleBlock`, `customCommand`, etc.) and `identifier` / `icManufacturerCode` properties.

---

## 6. Error handling

Everything routes through `didInvalidateWithError` (or per-command `completionHandler` errors). Cast to `NFCReaderError` and switch on `.code`. Errors live in `NFCErrorDomain`.

```swift
func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
    if let nfcError = error as? NFCReaderError {
        switch nfcError.code {
        case .readerSessionInvalidationErrorFirstNDEFTagRead:
            break  // normal end when invalidateAfterFirstRead == true
        case .readerSessionInvalidationErrorUserCanceled:
            break  // user tapped Cancel or app called invalidate() — not an error to surface
        case .readerSessionInvalidationErrorSessionTimeout:
            // ~60s system timeout; offer "scan again"
            break
        case .readerSessionInvalidationErrorSystemIsBusy,
             .readerSessionInvalidationErrorSessionTerminatedUnexpectedly:
            break  // retry later
        default:
            // surface a real error
            break
        }
    }
}
```

Key codes:
- Session: `…FirstNDEFTagRead`, `…UserCanceled`, `…SessionTimeout`, `…SystemIsBusy`, `…SessionTerminatedUnexpectedly`.
- NDEF write: `ndefReaderSessionErrorTagNotWritable`, `…TagSizeTooSmall`, `…TagUpdateFailure`, `…ZeroLengthMessage`.
- Transceive: `readerTransceiveErrorTagConnectionLost`, `…TagNotConnected`, `…TagResponseError`, `…RetryExceeded`, `…SessionInvalidated`, `…PacketTooLong`.
- Other: `readerErrorUnsupportedFeature`, `readerErrorInvalidParameter`, `readerErrorRadioDisabled`, `readerErrorSecurityViolation`.

Treat `…UserCanceled` and `…FirstNDEFTagRead` as silent, expected endings — never show an error alert for them.

---

## 7. Background NDEF tag reading

On iPhone XS and later, the system can scan for NFC tags without your app being open and without any session at all. You do **not** create an `NFCNDEFReaderSession`; the system reads the tag and launches/foregrounds your app via the tag's payload (typically a Universal Link in the NDEF record).

Requirements:
- The `NDEF` format in the `com.apple.developer.nfc.readersession.formats` entitlement.
- The tag's NDEF record encodes a URL that maps to your app's **associated domain** (Universal Link), so iOS knows which app to launch.
- The app must already be installed; iOS shows a notification banner the user taps.

Delivery arrives through the normal Universal Link path:

```swift
// SwiftUI
.onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
    guard let url = activity.webpageURL else { return }
    route(to: url)
}
```

Background reading is best-effort and only handles NDEF URL records — there is no background equivalent of `NFCTagReaderSession`. For everything else, you need a foreground session the user explicitly starts.

---

## 8. UI and session timing

`begin()` shows the system scan sheet (a sheet you cannot customize beyond `alertMessage`). The system enforces a timeout (~60 seconds) and shows a Cancel button. Implications:

- Keep the time between `begin()` and a successful read/write short. Pre-compute the `NFCNDEFMessage` before `begin()`; don't make network calls mid-session.
- Update `session.alertMessage` to guide the user ("Hold steady…", "Writing…").
- Use `session.invalidate(errorMessage:)` to show a red error on the sheet, or `invalidate()` for a clean success dismissal after setting `alertMessage`.
- Use `session.restartPolling()` (not a new session) to keep scanning after a multi-tag collision.

---

## 9. Quick reference

| Need | API |
|---|---|
| Check support | `NFCNDEFReaderSession.readingAvailable`, `NFCTagReaderSession.readingAvailable` |
| Read NDEF (simple) | `NFCNDEFReaderSession(... invalidateAfterFirstRead: true)` + `didDetectNDEFs:` |
| Read/write NDEF (connect) | `... invalidateAfterFirstRead: false` + `didDetect tags:` → `connect` → `queryNDEFStatus` → `readNDEF`/`writeNDEF` |
| Raw protocols | `NFCTagReaderSession(pollingOption:delegate:queue:)` + `didDetect tags: [NFCTag]` → `connect` → switch tag enum |
| ISO 7816 command | `NFCISO7816APDU(...)` → `tag.sendCommand(apdu:completionHandler:)` |
| MiFare command | `tag.sendMiFareCommand(commandPacket:completionHandler:)` |
| FeliCa command | `tag.sendFeliCaCommand(commandPacket:completionHandler:)` + typed helpers |
| End session | `session.invalidate()` / `invalidate(errorMessage:)` |
| Errors | cast `Error as? NFCReaderError`, switch on `.code` |

Entitlement: `com.apple.developer.nfc.readersession.formats` (`NDEF` and/or `TAG`).
Info.plist: `NFCReaderUsageDescription` (always), `com.apple.developer.nfc.readersession.iso7816.select-identifiers` (ISO 7816), `com.apple.developer.nfc.readersession.felica.systemcodes` (FeliCa).
