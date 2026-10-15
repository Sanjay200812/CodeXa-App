# CodeXa Mobile — Offline Sticker Library (README)

## Purpose

Implement a **device-local, deterministic sticker catalog** in the existing Flutter/Android CodeXa app. Sticker images must be loaded from bundled application assets or from an explicitly installed on-device offline sticker pack. **Do not upload sticker image bytes to CodeXa Core, Chat Supabase Storage, or a database.** Preserve the existing Chat Supabase message system for **small message metadata only** (sender, conversation/recipient, sticker ID, catalog version, timestamps, message state).

> **Status:** Integration contract and build instructions. The Flutter repository and actual ZIP/WebP asset files were **not** supplied with this README; nothing has been built into an APK or verified on a phone yet. The provided `stickers.md` and `Pasted text.txt` are file inventories, not sticker image archives.

## Supplied inventory (from the user's reports)

Original local folder: `G:\AntiGravity IDE\codexa app\WhatsApp Stickers`.

| Reported item type | Count | Reported size | Import policy |
|---|---:|---:|---|
| Individual `.webp` | 3,413 | 684.69 MB | Validate and include all supported unique sticker images |
| `.zip` pack archives | 34 | 101.05 MB | Inspect archives securely, include valid contained sticker images, avoid duplicates |
| `.was` | 10 | 200.25 KB | **Do not assume playable**; investigate format/available lawful decoder; report unsupported entries |
| `.enc` | 4 | 8.57 MB | Encrypted/unknown; **do not bypass encryption**; report unless a documented, authorized decoder/key is available |
| `.nomedia` | 1 | 37 B | Ignore (not a sticker) |
| **All files listed** | **3,462** | **794.51 MB** | This does **not** mean 3,462 distinct playable stickers |

The inventory may include duplicated images contained inside multiple archives, duplicates among loose files, and unusable/unsupported records. **Final accepted/duplicate/unsupported counts must be generated from the actual bytes**, not assumed from this report.

### Packaging / size constraint

The inventory represents **about 795 MB of source files**. Bundling every original asset unoptimized into the base APK is likely to create an impractically large install and startup/memory risks. Do not drop stickers silently to reduce size. Measure actual unique bytes first, deduplicate by SHA-256, preserve animations, optionally optimize images *without losing distinct sticker identities*, and report the release APK size. If still too large, choose a documented delivery mode:

1. **Bundled release:** All supported unique content is delivered in the same CodeXa APK/split installation to each user. Completely offline sticker resolution; larger install.
2. **Offline installed pack:** Users import the same CodeXa sticker ZIP through Android's document picker into app-private local storage on **each** device. No media server/database storage; sender/recipient must both have the pack. App can offer a shareable locally exported pack file.
3. **Play Asset Delivery:** Only if distribution is through Google Play and implementation actually supports it. Treat as a change in packaging/delivery requirements, not a database media upload.

If two devices do not have matching sticker asset packs, the recipient cannot display a sticker by ID alone. Show **“Sticker pack unavailable on this device”** and an appropriate local import/update instruction. Never fake that a sticker was delivered visually.

## Repository layout (recommended, adapt to actual repo)

```
codexa-mobile/
  README.md
  assets/
    stickers/
      source/                 # Input only, ignored by Flutter asset list; do not commit third-party assets without rights
      bundled/                # Generated unique local image assets
      catalog.json            # Generated sticker metadata/asset references; part of APK
      import-report.json      # Generated accepted/duplicate/unsupported/errors report
  scripts/
    build_sticker_catalog.py  # Scan loose files and ZIPs, validate, dedup, generate catalog
  lib/
    features/
      messages/
        stickers/
          data/local_sticker_repository.dart
          domain/sticker_asset.dart
          presentation/sticker_picker.dart
          presentation/sticker_message_bubble.dart
  test/
    sticker_catalog_test.dart
    sticker_message_test.dart
```

### Adding the user's sticker collection to a development checkout

1. Place the actual `WhatsApp Stickers` source folder, its `.webp` files and `.zip` files under `assets/stickers/source/`, preserving subfolders/pack names. **Inventory `.md`/`.txt` files alone cannot populate stickers.**
2. Inspect the rights to distribute this artwork to CodeXa users. User access/export from WhatsApp is not by itself proof of redistribution rights. For private personal use vs distribution, follow applicable rights/licensing.
3. Run the provided `scripts/build_sticker_catalog.py` from repository root:

   ```bash
   python scripts/build_sticker_catalog.py --source assets/stickers/source
   ```

4. Read `assets/stickers/import-report.json` and resolve any unsupported/corrupted files. Verify counts against actual ZIP contents; no silent loss.
5. Register generated assets in Flutter `pubspec.yaml`:

   ```yaml
   flutter:
     assets:
       - assets/stickers/catalog.json
       - assets/stickers/bundled/
   ```

6. Run `flutter pub get`, `flutter analyze`, `flutter test`, release build, and real-device testing. Do not forget the corresponding Dart code; `pubspec.yaml` entries alone do not create a sticker picker.
7. Run on **two devices with identical catalog version** and verify realtime messaging offline from sticker media storage perspective (the message metadata still needs a network connection to reach another device).
8. Confirm that neither Core DB nor Chat Storage received sticker image bytes.

**Optional:** For APK size control, do not ship `source/`, `.zip`, `.enc`, `.was` or inventory documentation as Flutter sticker assets. Build only from validated generated assets and catalog; do not include raw folders in `pubspec.yaml`.

## Catalog schema

The build tool writes a stable JSON catalog with content-hash sticker IDs. Example **format** (not actual user stickers):

```json
{
  "schemaVersion": 1,
  "catalogVersion": "<deterministic-content-fingerprint>",
  "stickers": [
    {
      "id": "<sha256-of-sticker-file>",
      "assetPath": "assets/stickers/bundled/<sha256>.webp",
      "mimeType": "image/webp",
      "animated": false,
      "sha256": "<sha256>",
      "byteLength": 54321
    }
  ],
  "packs": [
    {"id": "<stable-pack-id>", "name": "My Pack", "stickerIds": ["<sha256>"]}
  ]
}
```

The generator must validate WebP/PNG/GIF signatures rather than trusting extensions, detect animated WebP where possible, and never include encrypted/unsupported objects as fake playable stickers. Assets from multiple ZIPs can map to the same deduplicated content ID. **Do not use sequential array indices as sticker IDs** because future additions will shift them.

## Flutter local repository and UI

- Read `assets/stickers/catalog.json` with `rootBundle` at first sticker picker open, not on every chat render.
- Implement `LocalStickerRepository` that maps `stickerId` to a bundled asset path (or installed offline pack path). Never query a server to resolve bundled sticker artwork.
- Render bundled items with `Image.asset(assetPath, ...)` and local installed items with `Image.file(...)`; use an appropriate animated WebP-compatible renderer where tested.
- Lazy-build the grid (`GridView.builder`), display appropriately sized thumbnails, cache recent and favorite IDs **on device** (e.g., preferences/SQLite, isolated by CodeXa account). Do not decode/load all 3,000+ images into RAM at startup.
- Tabs: **All, Packs, Recent, Favorites**. Provide local search/tags when metadata exists; don't invent descriptions/tags from filenames.
- Enable sticker picker in actual DM/group composer according to Chat membership and feature flags.
- Animated sticker support must be tested against real provided bytes and actual Android release build.
- Handle malformed/unsupported assets per item rather than crashing entire grid.

## Message protocol: metadata only

A sticker is a normal **Chat message** with `type = STICKER`. Send an authenticated message containing only a reference to an asset both clients know:

```json
{
  "conversationId": "<real-conversation-id>",
  "clientMessageId": "<idempotency-id>",
  "type": "STICKER",
  "stickerId": "<sha256-of-a-bundled-sticker>",
  "catalogVersion": "<catalog-version>"
}
```

Server must derive `senderCoreUserId` from the authenticated session. For DMs, recipient is resolved from canonical conversation membership. For groups, recipients are determined by membership at the appropriate event boundary; **do not accept a forged recipient or sender ID from Flutter**. On commit, persist the minimum message metadata:

| Field | Purpose |
|---|---|
| `id` | Server message ID |
| `conversationId` | Target DM/group |
| `senderCoreUserId` | Who sent it (server-derived) |
| `type` | `STICKER` |
| `stickerId` | Which local asset to display (mandatory) |
| `catalogVersion` | Helps detect pack mismatch; resolve stable ID first |
| `clientMessageId` | Idempotent retries |
| `createdAt` | True sent timestamp |
| Read/delivery markers | Use existing Chat protocol |

No `imageBytes`, base64, image Blob, permanent image URL, sticker image Storage upload or stickers table holding media is required. A message row needs `stickerId`: **only who sent to whom is insufficient to identify which sticker**. Keep existing chat message retention and authorization policies.

### Cross-device semantics

1. Sender taps local sticker and sees immediate `SENDING` optimistic artwork.
2. Chat server checks account, conversation membership and `MOBILE_CHAT_STICKERS` permission, persists only message metadata, acknowledges canonical `SENT`.
3. Chat Supabase Realtime sends metadata to recipients; FCM can use non-sensitive `Sticker` preview.
4. Recipient resolves `stickerId` locally. If bundled asset exists, renders actual sticker offline from device storage. If missing, renders a visible **pack-missing** placeholder (not a blank bubble) with instructions to install matching offline pack.
5. `DELIVERED`/`SEEN` must use real receipt semantics, not be assumed from metadata arrival.
6. On app restart, the Chat DB returns message references and local assets render again without a sticker media download.

### Important consistency rule

If users install different catalog revisions, **stable content-hash `stickerId` is more important than version equality**: an older client can still render a sticker if it has the referenced asset. `catalogVersion` is useful to detect unsupported newer items. Keep old referenced asset IDs available across new releases or ship a clear missing-pack state.

## Backend changes — minimal and intentional

- Reuse existing Chat message table and realtime channel; add `stickerId`/`catalogVersion` fields or a structured JSON metadata field if missing.
- Validate `STICKER` messages: membership, feature flag, sticker ID shape, payload size, allowed/recognized catalog if the server has a lightweight signed/compiled ID allowlist. **Backend catalog manifest contains IDs/metadata only, never image bytes.**
- Persist standard message sender, conversation, timestamps, status/read markers. No new Core business DB tables are needed to hold sticker files.
- Group sender avatar/name comes from Core profile mapping, not sticker metadata.
- Conversation preview can display `You: Sticker` / `Sticker`, but inside chat render the actual local sticker graphic.
- A recipient must never receive arbitrary filesystem paths supplied by another user.

## Packaging/security and copyright

- Handle ZIPs as untrusted input: prevent path traversal, symlinks, decompression bombs, oversized files, wrong magic bytes and duplicates.
- Never attempt to decrypt `.enc` files without a documented lawful method and access credentials.
- `.was` support requires an actual verified decoder/renderer/converter. Do not rename the extension and call it playable.
- No raw WhatsApp, Sticker.ly or third-party pack redistribution unless proper rights permit it.
- Never include files with unknown/unsafe formats in app assets.
- Never commit secrets or the user's private personal exported media into a public GitHub repository without permission and rights review.

## Acceptance tests

- [ ] Actual bytes (not catalog report only) are present in checkout before catalog generation.
- [ ] Build report lists all observed files, accepted unique stickers, duplicates and unsupported/skipped entries.
- [ ] Every supported unique `.webp` and valid ZIP-contained sticker is represented; no silent losses.
- [ ] Report identifies `.enc` and `.was` unsupported entries accurately; do not falsely count them as usable.
- [ ] Animated WebP renders on test Android phone; no single-frame freeze when animation is expected.
- [ ] Picker opens without decoding the entire catalog; scroll stays responsive.
- [ ] Direct and group chats send real STICKER metadata using existing Chat API.
- [ ] Two phones on matching catalog render actual same sticker.
- [ ] Version mismatch produces correct missing-pack fallback, not crash/fake sticker.
- [ ] Chat history persists after app close/restart and stickers resolve locally.
- [ ] Realtime message, sender name/avatar, unread and Seen state remain correct.
- [ ] No sticker image bytes, base64 or raw files appear in Core/Chat database or Chat Storage.
- [ ] Release APK's size/performance measured, documented and acceptable for distribution.
- [ ] Only rights-cleared assets are distributed to other devices.

## Handoff for Antigravity

**Inspect the actual repository, execute catalog generation against the real ZIP/assets, integrate the local repository/UI and metadata-only Chat message type, then run tests. Do not declare completion from these README instructions alone.** Deliver actual change list, APK build status, import report, skipped formats, file-size analysis and two-device delivery evidence.
