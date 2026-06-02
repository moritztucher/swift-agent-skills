---
name: core-nfc
description: Read and write NFC tags on iPhone with Core NFC — NDEF reading/writing via NFCNDEFReaderSession, raw tag protocols (ISO 7816, MiFare, FeliCa, ISO 15693) via NFCTagReaderSession, the required entitlement + Info.plist setup, and background tag reading. Use when the user mentions Core NFC, NFC, NFCNDEFReaderSession, NFCTagReaderSession, read NFC tag, write NDEF, scan a tag, or contactless reading on iOS.
license: MIT
metadata:
  author: Moritz Tucher
  version: "1.0"
  currency_checked: "2026-06-02"
  source: Apple Core NFC docs via Context7 (/websites/developer_apple_corenfc)
---

# Core NFC

Detecting, reading, and writing NFC tags on iPhone. Two session classes do the work: `NFCNDEFReaderSession` for NDEF-formatted tags and `NFCTagReaderSession` for raw tag protocols (ISO 7816, MiFare, FeliCa, ISO 15693), plus system-driven background NDEF reading. The deep API reference — full session lifecycle, every tag protocol, the entitlement/Info.plist matrix, error codes, background reading, and the scan-sheet UI — lives in `references/guide.md`. This file is the decision and discipline layer: read it first, open the guide for specifics.

## Dials

Set these explicitly at the start; they change what "correct" means.

1. `MODE` — `ndef-read` (default; system reads the message, simplest path) · `ndef-write` (connect + queryNDEFStatus + writeNDEF) · `tag-protocol` (raw APDU / protocol commands).
2. `TAG` — `ndef` (default) · `iso7816` (smartcard APDUs; needs the select-identifiers Info.plist array) · `mifare` · `felica` (needs the system-codes Info.plist array).
3. `TRIGGER` — `in-app-session` (default; user taps, you `begin()` a session and show the scan sheet) · `background` (system scans with no session and launches the app via the tag's Universal Link).

## When to use

Building or reviewing any iOS code that scans, reads, or writes NFC tags — loyalty/transit cards, ISO 7816 smartcards, MiFare/FeliCa, NDEF stickers, or background tag taps. Core NFC is iPhone-only (no iPad). For raw protocols pick `tag-protocol`; for simple NDEF reads stay on `ndef-read`.

## Core rules

- Core NFC is **iPhone only**. Always gate on `NFCNDEFReaderSession.readingAvailable` / `NFCTagReaderSession.readingAvailable` before creating a session — iPad and unsupported devices return `false`.
- Every reader session needs both the `com.apple.developer.nfc.readersession.formats` entitlement (`NDEF` and/or `TAG`) **and** the `NFCReaderUsageDescription` Info.plist string. Missing either = crash or instant invalidation.
- A session is **single-use**: create a fresh `NFC*ReaderSession` for every scan. Don't reuse one after it invalidates.
- All delegate callbacks land on the session queue (or an internal queue when `queue: nil`) — hop to the main thread before touching UI. End every session with `invalidate()` / `invalidate(errorMessage:)`.

## Anti-rationalization

| The rationalization | The reality |
|---|---|
| "I'll add the entitlement later; reading should work." | No. Without `com.apple.developer.nfc.readersession.formats` AND `NFCReaderUsageDescription` in Info.plist, `begin()` throws and the app crashes. Both are mandatory before the first scan. |
| "ISO 7816 polling isn't finding my card." | ISO 7816 AIDs must be declared in `com.apple.developer.nfc.readersession.iso7816.select-identifiers` in Info.plist (FeliCa needs `...felica.systemcodes`). Identifiers not listed there are dropped — the tag never surfaces. |
| "I'll keep one session around and call `begin()` again to rescan." | A session is single-use. After it invalidates it's dead — allocate a new `NFCNDEFReaderSession`/`NFCTagReaderSession` for each scan. Use `restartPolling()` only to resume within a still-active session. |
| "I'll just call `writeNDEF` on the detected tag." | Writing requires `invalidateAfterFirstRead: false`, then `connect(to:)` → `queryNDEFStatus` (reject `.notSupported`/`.readOnly`) → `writeNDEF`. Writing blind risks errors on read-only or non-NDEF tags. |
| "Tag sessions work everywhere NDEF does." | `NFCTagReaderSession` needs iPhone 7+, and NFC is iPhone-only (no iPad at all). Background reading needs iPhone XS+. Gate on `readingAvailable` and don't assume parity. |
| "I'll fetch data over the network mid-scan, then write." | The system scan sheet times out (~60s). Pre-compute the `NFCNDEFMessage` and keep the field time short; treat `…UserCanceled` and `…FirstNDEFTagRead` as normal endings, not errors. |

## Verification gate

Before shipping NFC code, confirm every line:

- [ ] `readingAvailable` checked before any session is created; scan UI hidden/disabled when false.
- [ ] Entitlement `com.apple.developer.nfc.readersession.formats` includes the needed format (`NDEF` and/or `TAG`); App ID + provisioning profile carry the capability.
- [ ] `NFCReaderUsageDescription` present in Info.plist with a real, user-facing string.
- [ ] ISO 7816 AIDs in `...iso7816.select-identifiers` (if `iso7816`); FeliCa codes in `...felica.systemcodes` (if `felica`).
- [ ] A fresh session is created per scan; `invalidate()`/`invalidate(errorMessage:)` always called; multi-tag collisions handled with `restartPolling()`.
- [ ] Writing path uses `invalidateAfterFirstRead: false` and goes `connect` → `queryNDEFStatus` → `writeNDEF`, rejecting `.notSupported`/`.readOnly`.
- [ ] `didInvalidateWithError` casts to `NFCReaderError`; `…UserCanceled` and `…FirstNDEFTagRead` are silent, not error alerts.
- [ ] UI callbacks dispatched to main; `alertMessage` guides the user; no long-running work blocks the scan sheet.

## Deep reference

`references/guide.md` — platform/hardware support, the full entitlement + Info.plist matrix, NDEF read and write lifecycles, `NFCTagReaderSession` with ISO 7816 / MiFare / FeliCa / ISO 15693 command surfaces, the complete `NFCReaderError` code list, background NDEF reading, scan-sheet UI/timing, and a quick-reference table. Load it for any concrete API question.
