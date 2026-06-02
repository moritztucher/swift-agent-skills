---
name: contacts
description: Read, write, pick, and gate access to the user's address book with the Contacts and ContactsUI frameworks — CNContactStore, CNContact/CNMutableContact, fetch/save, CNContactPickerViewController, and the iOS 18 limited-access flow (ContactAccessButton, contactAccessPicker). Use when the user mentions Contacts, CNContactStore, address book, contact picker, contacts permission, ContactAccessButton, or limited contact access on iOS.
license: MIT
metadata:
  author: Moritz Tucher
  version: "1.0"
  currency_checked: "2026-06-02"
  source: Apple Contacts & ContactsUI docs via Context7 (/websites/developer_apple)
---

# Contacts & ContactsUI

Reading, writing, picking, and gating access to the user's contacts on Apple platforms. The deep API reference — authorization, fetch predicates, enumerate vs. unifiedContacts, CRUD with CNSaveRequest, the picker wrapper, ContactAccessButton, and the iOS 18 limited-access flow — lives in `references/guide.md`. This file is the decision and discipline layer: read it first, open the guide for specifics.

## Dials

Set these explicitly at the start; they change what "correct" means.

1. `ACCESS_MODEL` — `picker-only` (default; use `CNContactPickerViewController` / `ContactAccessButton`, request **no** permission) · `full` (`requestAccess(for:.contacts)` for read/write over the whole database — only when the feature genuinely needs the full address book) · `limited` (design around iOS 18 `.limited`: incremental access via `ContactAccessButton` + `contactAccessPicker`).
2. `OPERATION` — `read` (fetch/enumerate) · `write` (create/update/delete via `CNSaveRequest`) · `both`. Write requires full or limited authorization; reads via the picker need none.
3. `FETCH_SCALE` — `single`/`few` (`unifiedContacts(matching:keysToFetch:)` with a predicate) · `all`/`bulk` (`enumerateContacts(with:)` streaming, off the main thread).

## When to use

Building or reviewing any code that touches the address book: a contact picker, a permission prompt and its denied/limited states, fetching or searching contacts, creating/editing/deleting contacts, or the iOS 18 limited-access UI. If all you need is "let the user pick one contact and hand me the data," you almost certainly want `picker-only` and should not request permission at all.

## Core rules

- **Default to no permission.** `CNContactPickerViewController` returns the selected contact's data without any authorization — prefer it for one-off selection. Only request access when you need programmatic read/write the picker can't provide.
- `NSContactsUsageDescription` is mandatory in Info.plist before any `requestAccess` call, and the string must explain *why*. No string = crash on request.
- **Fetch exactly the keys you use, no more, no less.** Every property you read must be in `keysToFetch`; reading an unfetched key throws `CNContactPropertyNotFetchedException`. Don't over-fetch either (privacy + perf).
- **Design for `.limited` (iOS 18+), not just authorized/denied.** Handle all five `CNAuthorizationStatus` cases with `@unknown default`. Under `.limited` the store transparently returns only the shared subset.
- **Run store operations off the main thread** (`Task.detached` or a background context) and update `@Observable`/UI state back on `@MainActor`.

## Anti-rationalization

| The rationalization | The reality |
|---|---|
| "I'll request full Contacts access so the user can pick someone." | Picking needs zero permission. Use `CNContactPickerViewController` (or `ContactAccessButton` for incremental access). Requesting full access for a picker is a privacy smell and an App Review risk. |
| "I fetched the contact, so I can read any property." | A fetched `CNContact` only holds the keys in `keysToFetch`. Touching any other property throws `CNContactPropertyNotFetchedException` and crashes. Add the key, or refetch by identifier with the extra keys before reading. |
| "Only authorized vs. denied matter." | iOS 18 added `.limited` — full API access to a user-chosen subset. Treat it as a working state, drive more contacts in via `ContactAccessButton`/`contactAccessPicker`, and never assume `!authorized` means "no access." |
| "I'll add the usage string later / a generic one is fine." | Missing `NSContactsUsageDescription` crashes the app the instant you call `requestAccess`. A vague string gets rejected. Write a specific reason before wiring the call. |
| "ContactAccessButton works whenever, I'll always show it." | It only does something under `.notDetermined`/`.limited`. Under `.authorized` it renders nothing; under `.denied` it shows a prompt to open access. Showing it unconditionally next to a full-access flow is dead UI — gate on the status. |
| "I'll enumerate all contacts on the main thread, it's fast enough." | `enumerateContacts` over a large address book blocks the main thread and hitches the UI. Stream it off-main and only request the keys you render. |

## Verification gate

Before shipping anything that touches Contacts, confirm every line:

- [ ] If the feature is selection-only, it uses the picker / `ContactAccessButton` and requests **no** permission.
- [ ] `NSContactsUsageDescription` is present and specific (only if you call `requestAccess`).
- [ ] `keysToFetch` lists every property the code reads — verified against actual property access, with `isKeyAvailable(_:)` or a refetch-by-identifier where keys may be missing.
- [ ] All five `CNAuthorizationStatus` cases are handled, including `.limited`, with `@unknown default`.
- [ ] Limited-access path exists where relevant (`ContactAccessButton` and/or `contactAccessPicker`), gated on the current status.
- [ ] Store fetch/save runs off the main thread; UI/state updates hop back to `@MainActor`.
- [ ] Writes use `CNSaveRequest` (`add`/`update`/`delete`) on a `mutableCopy()`, and revoked/denied access degrades gracefully with a Settings deep link.

## Deep reference

`references/guide.md` — full setup and Info.plist, authorization statuses and the iOS 18 two-stage flow, CNContact/CNMutableContact/CNLabeledValue/CNKeyDescriptor, fetch predicates, `unifiedContacts` vs. `enumerateContacts`, partial-contact refetch, create/update/delete with `CNSaveRequest`, store-change notifications, the SwiftUI `CNContactPickerViewController` wrapper, `ContactAccessButton` and `contactAccessPicker`, common use cases, and a key/API quick reference. Load it for any concrete API question.
