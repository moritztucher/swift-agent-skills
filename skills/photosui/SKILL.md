---
name: photosui
description: Select photos and videos and read/write the photo library on Apple platforms — SwiftUI PhotosPicker, PHPickerViewController, PhotosPickerItem.loadTransferable, PhotoKit authorization (read/write vs add-only), limited library access, and Live Photos. Use when the user mentions PhotosPicker, photo library, PHPickerViewController, image picker, PhotoKit, photos permission, picking or uploading a photo/avatar, or saving an image to the library.
license: MIT
metadata:
  author: Moritz Tucher
  version: "1.0"
  currency_checked: "2026-06-02"
  source: Apple Developer docs via Context7 (/websites/developer_apple) — PhotosUI, PhotoKit, Photos
---

# PhotosUI / PhotoKit

Picking photos/videos and reading or writing the photo library on Apple platforms. The deep API reference — every `PhotosPicker` form, `loadTransferable` patterns, `PHPickerFilter`, the UIKit `PHPickerViewController` wrapper, authorization, limited access, Live Photos, and memory/compression — lives in `references/guide.md`. This file is the decision and discipline layer: read it first, open the guide for specifics.

## Dials

Set these explicitly at the start; they change what "correct" means.

1. `ACCESS_MODEL` — `picker-only` (default; `PhotosPicker`/`PHPickerViewController` — user picks specific items, **no permission prompt, no Info.plist key**) · `library-read` (you enumerate the library with `PHAsset`/`PHImageManager` → needs `NSPhotoLibraryUsageDescription` + `requestAuthorization(for: .readWrite)`) · `add-only` (you only save images → needs `NSPhotoLibraryAddUsageDescription` + `requestAuthorization(for: .addOnly)`).
2. `SELECTION` — `single` (`PhotosPickerItem?`) · `multi` (`[PhotosPickerItem]`, set `maxSelectionCount` + `selectionBehavior`).
3. `PAYLOAD` — `image` (load `Image` for display) · `data` (load `Data` for upload/compression/Core Image) · `livephoto` (`PHLivePhoto`) · `custom` (own `Transferable`).

## When to use

Building or reviewing any photo/video picking, avatar upload, "save to Photos", or library-enumeration code on iOS/iPadOS/macOS/visionOS. If all you need is "let the user pick an image", you almost certainly want `ACCESS_MODEL = picker-only` and no permission at all.

## Core rules

- **Prefer the picker. It needs no permission.** `PhotosPicker` (iOS 16+) and `PHPickerViewController` (iOS 14+) run out of process and hand back only what the user selected. Reach for `PHPhotoLibrary` authorization **only** when you must enumerate or save to the library yourself.
- Load asynchronously: `loadTransferable(type:)` is `async throws` and can return `nil` or throw. Drive it from `.task(id:)` so a new selection cancels the previous load.
- For authorization use the access-level APIs — `authorizationStatus(for:)` / `requestAuthorization(for:handler:)` — never the no-argument legacy ones.
- Match the usage-description key to intent: `NSPhotoLibraryUsageDescription` for read/write, `NSPhotoLibraryAddUsageDescription` for add-only. Ship neither for picker-only.
- iOS 16+ target for `PhotosPicker`; iOS 17+ for `.photosPickerStyle` / accessory / disabled-capabilities modifiers.

## Anti-rationalization

| The rationalization | The reality |
|---|---|
| "I need a photo, so I'll request photo-library permission first." | A picker (`PhotosPicker` / `PHPickerViewController`) needs **zero** permission and no Info.plist key — it runs out of process. Requesting access for a plain pick is a needless prompt that costs you grants and an App Store review question. Only request when you enumerate or save the library yourself. |
| "`requestAuthorization` returned `.authorized`, so I have full access." | The **no-argument** `authorizationStatus()` / `requestAuthorization(_:)` are deprecated and report `.authorized` even when the user granted **limited** access. Use the `for:` variants and handle `.limited` distinctly — otherwise you'll try to read assets that aren't shared and silently get nothing. |
| "`limited` is basically the same as authorized, I'll treat them together." | Under `.limited` the user shared only specific assets; the rest don't exist to you. Surface a way to manage the selection via `presentLimitedLibraryPicker(from:)`, and expect the set to be small. Treating it as full access produces empty galleries and confused users. |
| "`loadTransferable` gave me the item, so I have the image." | It's `async throws` and returns an **optional** — it can throw or yield `nil` (unsupported representation, cancelled, iCloud download failure). Force-unwrapping (`try!`/`!`) crashes on a flaky network. Handle nil and error, show a fallback. |
| "I'll just keep the picked `Data` / `UIImage` originals in an array." | Originals are huge (12MP HEIC, 4K video, multi-MB each). Loading a multi-select straight into memory as full images is a memory bomb. Load `Data`, downsample (`preparingThumbnail(of:)` / ImageIO), compress for upload, and load full-size only on demand. |
| "Add-only saving is read access, same usage string." | Add-only is a separate access level (`requestAuthorization(for: .addOnly)`) with its own key (`NSPhotoLibraryAddUsageDescription`). Using the read key for a save-only feature over-asks and can fail review; using the wrong access level prompts for more than you need. |

## Verification gate

Before shipping photo code, confirm every line:

- [ ] If the feature is just picking, it uses `PhotosPicker`/`PHPickerViewController` with **no** `PHPhotoLibrary` authorization call and **no** Info.plist usage key.
- [ ] Any direct-library access requests the right access level (`.readWrite` or `.addOnly`) via the `for:` API, with the matching usage-description string present.
- [ ] `.limited` is handled as its own case (not folded into `.authorized`), with a path to `presentLimitedLibraryPicker(from:)` where relevant.
- [ ] Every `loadTransferable` call handles both `nil` and thrown errors; no `try!` / force-unwrap on picked content.
- [ ] Loads run off `.task(id:)` (or a cancellable `Task`), not a synchronous `onChange`, with a loading state shown for large items.
- [ ] Multi-select / large originals are downsampled or compressed — full-resolution images aren't all held in memory at once.
- [ ] Legacy no-argument `authorizationStatus()` / `requestAuthorization(_:)` are not used.

## Deep reference

`references/guide.md` — every `PhotosPicker` and `photosPicker(...)` form, single/multi selection, `loadTransferable` (Image/Data/custom `Transferable`/progress), `PHPickerFilter` (including compound `.any/.all/.not`), the iOS 17 styling modifiers, UIKit `PHPickerViewController` + SwiftUI wrapper, `PHPhotoLibrary` authorization and change observation, limited-library picker, Live Photos (`PHLivePhotoView`), memory/thumbnail/compression patterns, version compatibility, and a full profile-photo example. Load it for any concrete API question.
