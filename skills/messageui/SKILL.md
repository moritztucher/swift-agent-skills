---
name: messageui
description: Add in-app email and SMS/iMessage composition with MessageUI — MFMailComposeViewController, MFMessageComposeViewController, availability checks, attachments, result handling, and SwiftUI UIViewControllerRepresentable wrapping. Use when the user mentions MessageUI, sending email in-app, MFMailComposeViewController, SMS, mail compose, message compose, in-app feedback/bug-report email, or sharing via iMessage.
license: MIT
metadata:
  author: Moritz Tucher
  version: "1.0"
  currency_checked: "2026-06-02"
  source: Apple Developer Documentation via Context7 (/websites/developer_apple)
---

# MessageUI

System compose sheets for email and SMS/iMessage. The framework presents Apple-owned UI; the user always taps Send — you never send programmatically. The deep API reference — every method, SwiftUI wrappers, attachment handling, result enums, common use cases, MIME table — lives in `references/guide.md`. This file is the decision and discipline layer: read it first, open the guide for specifics.

## Dials

Set these explicitly at the start; they change what "correct" means.

1. `CHANNEL` — `mail` (`MFMailComposeViewController`) · `message` (`MFMessageComposeViewController`, SMS/iMessage) · `both` (offer whichever the device supports, gate each independently).
2. `FALLBACK` — `none` (hide/disable the action when unavailable) · `mailto` (open `mailto:`/`sms:` URL via `UIApplication.open` so third-party mail apps still work) · `alert` (explain why it's unavailable).
3. `ATTACHMENTS` — `none` · `data` (`addAttachmentData` with explicit MIME/UTI) · `url` (`addAttachmentURL`, messages only, gated on `canSendAttachments()`).

## When to use

Building or reviewing any in-app email or SMS/iMessage composition: feedback/bug-report mail, "email support," share-via-message, invite codes, exporting data as an attachment. Not for chat UI inside your app (that's a custom view or a third-party kit) and not for Messages app extensions (that's the Messages framework / `MSMessage`).

## Core rules

- `import MessageUI`. iOS only path is fine; the framework is unavailable on watchOS/tvOS.
- **Check capability before you present.** `MFMailComposeViewController.canSendMail()` / `MFMessageComposeViewController.canSendText()` must be `true` before presenting, every time — not just at launch.
- **You present and you dismiss.** Present modally; dismiss the controller yourself inside the delegate `didFinish` callback. The sheet does not dismiss itself.
- **In SwiftUI, wrap with `UIViewControllerRepresentable` + a `Coordinator`** that owns the delegate. Configure once in `makeUIViewController`; leave `updateUIViewController` empty.
- Handle every result case (`.sent`, `.cancelled`, `.saved` for mail, `.failed`) and `@unknown default`. `.cancelled` is normal — never surface it as an error.

## Anti-rationalization

| The rationalization | The reality |
|---|---|
| "I'll just present the compose sheet." | Without `canSendMail()` / `canSendText()` returning `true` first, presenting fails silently or shows a blank/unusable sheet. Gate it every time, right before presenting. |
| "Tested it in the Simulator, works." | The Simulator can't send mail or SMS — `canSendText()` is false and mail won't deliver. Verify on a real device with a configured Mail account / SIM. |
| "I'll embed the composer in my view hierarchy." | `MFMailComposeViewController`/`MFMessageComposeViewController` are presented modally, full-stop. Don't push, embed, or add as a child — present it. |
| "The user sent it, the sheet will close." | You own dismissal. If you don't call `controller.dismiss(animated:)` in the delegate `didFinish`, the sheet stays stuck on screen. |
| "`canSendMail()` is false, so the user just can't email." | `canSendMail()` only reports the native Mail app — Gmail/Outlook users read false. Offer a `mailto:`/`sms:` URL fallback via `UIApplication.shared.open` so they still reach an email/SMS app. |
| "I set the delegate to a local object and presented." | The compose controller holds the delegate `weak`. A `Coordinator` or service that goes out of scope means the callback never fires and the sheet never dismisses — keep a strong reference (Coordinator retained by the representable, or a stored property). |

## Verification gate

Before shipping a compose flow, confirm every line:

- [ ] `canSendMail()` / `canSendText()` checked immediately before each present, not cached from launch.
- [ ] The action is hidden/disabled or has a `mailto:`/`sms:` fallback when the capability is false.
- [ ] Composer is presented modally (sheet/`present`), never embedded.
- [ ] `mailComposeDelegate` / `messageComposeDelegate` set, and the delegate object is strongly retained for the sheet's lifetime.
- [ ] `controller.dismiss(animated:)` called inside the `didFinish` delegate callback for every result.
- [ ] All result cases handled including `@unknown default`; `.cancelled` does not show an error.
- [ ] Attachments use correct MIME type (mail) / UTI (`canSendAttachments()`-gated, messages); large data attached as a file, not inline.
- [ ] Verified on a physical device — not only the Simulator.

## Deep reference

`references/guide.md` — full method tables for both composers, availability checks, SwiftUI `UIViewControllerRepresentable` wrappers with Coordinators, async/await continuation pattern, pre-population, attachment helpers, result enums and error codes, iPad popover config, common use cases (bug report, share, export, location), limitations, and a MIME-type quick reference. Load it for any concrete API question.
