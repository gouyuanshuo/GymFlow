# Google Drive Music Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Upload existing imported songs to Google Drive and play verified cloud-only tracks without retaining permanent audio files on the phone.

**Architecture:** Keep `AudioPlayerService` as queue/Now Playing owner and its `AVAudioPlayer` path for local files. Add native OAuth, a narrowly scoped Drive HTTP client, resumable transfer coordination, and an authenticated byte-range `AVPlayer` resource loader. Persist cloud metadata on the existing track UUID so playlists and workout assignments remain stable.

**Tech Stack:** Swift 5, iOS 17+, SwiftUI, SwiftData, AVFoundation, AuthenticationServices, CryptoKit, Security, URLSession, Swift Testing; no third-party runtime dependencies.

**Spec:** `docs/superpowers/specs/2026-09-28-google-drive-music-design.md`

## Global Constraints

- The core app remains useful offline; only cloud-only audio requires network access.
- Uploads are explicit. Upload or playback failure never deletes the local source.
- `drive.file` is the only Drive scope; do not commit OAuth credentials or a refresh token.
- A local copy is removable only after remote size/checksum verification **and** a successful cloud-player open.
- Removing a GymFlow track or all audio never deletes its Google Drive file.
- Use `BE3E1DA1-5745-42DA-88B2-D3CAFF380FFF` for simulator tests only after confirming it is still installed with `xcrun simctl list devices available`.
- After each code task run the generic simulator build from `AGENTS.md`; run the complete `GymFlowTests` suite and semantic lint before calling the feature finished. Record exact outcomes in `PROGRESS.md`.

**Shared verification commands:** Build: `xcodebuild -project GymFlow.xcodeproj -scheme GymFlow -sdk iphonesimulator -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/GymFlowDerivedData CODE_SIGNING_ALLOWED=NO build`. Full unit suite: `xcodebuild -project GymFlow.xcodeproj -scheme GymFlow -destination 'platform=iOS Simulator,id=BE3E1DA1-5745-42DA-88B2-D3CAFF380FFF' -derivedDataPath /tmp/GymFlowDerivedData CODE_SIGNING_ALLOWED=NO -only-testing:GymFlowTests test`. Lint: `xcrun swift-format lint --recursive --parallel GymFlow GymFlowActivityShared GymFlowLiveActivityExtension GymFlowTests`.

## Review Focus

- No OAuth client ID configured: Connect is disabled with setup guidance; Tasks 2 and 6 test this.
- Upload interrupted after a server file ID exists: retry verifies that ID before creating another file; Task 3 tests this.
- Remote size or supplied MD5 differs: local audio stays and cloud-ready stays false; Task 3 tests this.
- Range endpoint ignores `Range` and returns `200` with a whole file: reject it rather than buffer the file; Task 4 tests this.
- Cloud-only song is offline, signed out, or belongs to another account: retain queue/playlist identity and show a recoverable playback error; Task 5 tests this.

## File Map

- `GymFlow/Models/ImportedTrack.swift`: optional Drive ID, owner ID, remote size/checksum, verification and first-play timestamps; keep `storedFileName` for pre-upgrade records.
- `GymFlow/Services/DriveTrackStorage.swift`: local-copy eligibility and app-owned file deletion, never a Drive delete.
- `GymFlow/Services/GoogleDriveAuthorizationService.swift`: OAuth configuration, PKCE/state, Keychain refresh credential, token refresh and disconnect.
- `GymFlow/Services/GoogleDriveMusicService.swift`: folder lookup/create, resumable upload/checkpoint, metadata verification, bounded range reads; inject an HTTP transport for tests.
- `GymFlow/Services/DriveMediaResourceLoader.swift`: `AVAssetResourceLoaderDelegate` bridge and cancellation for requested byte ranges.
- `GymFlow/Services/AudioPlaybackEngine.swift`: local and cloud engine adapters with one control surface.
- `GymFlow/Services/AudioPlayerService.swift`: select engine, preserve queue, remote controls, ducking, interruption and snapshot behavior.
- `GymFlow/ViewModels/DriveMusicController.swift`: connect/upload/verify/remove state and per-track progress.
- `GymFlow/Views/Music/DriveMusicView.swift`, `MusicLibraryView.swift`, `GymFlow/Components/TrackRow.swift`, `GymFlow/Views/Settings/SettingsView.swift`: opt-in controls, statuses, confirmations and errors.
- `GymFlow/Info.plist`, `GymFlow.xcodeproj/project.pbxproj`: build-supplied iOS OAuth client ID and registered callback scheme; no credential values in git.
- `GymFlowTests/GoogleDriveMusicTests.swift`: fake transport/API and persisted-track regression tests.
- `README.md`, `PROJECT_SPEC.md`, `PLANS.md`, `PROGRESS.md`: optional-online capability, Google setup, milestone/test record and manual device checklist.

---

### Task 1: Cloud Track State and Safe Local Deletion

**Files:** Modify `ImportedTrack.swift`; create `DriveTrackStorage.swift`, `GymFlowTests/GoogleDriveMusicTests.swift`.

**Interfaces:** Produce optional `driveFileID: String?`, `driveOwnerID: String?`, `driveFileSize: Int64?`, `driveMD5Checksum: String?`, `driveVerifiedAt: Date?`, `drivePlaybackValidatedAt: Date?`; `DriveTrackStorage.canRemoveLocalCopy(_ track: ImportedTrack, connectedOwnerID: String?) -> Bool` and `removeLocalCopy(of track: ImportedTrack, connectedOwnerID: String?, store: AudioFileStore, context: ModelContext) throws`. A cloud-only track retains its `id`, original `storedFileName`, and playlist memberships.

- [ ] **Step 1: Write failing tests.** `existingTrackDefaultsToLocal`: `#expect(track.driveFileID == nil && track.driveOwnerID == nil && track.driveFileSize == nil && track.driveMD5Checksum == nil && track.driveVerifiedAt == nil && track.drivePlaybackValidatedAt == nil)`. `removalRequiresVerificationAndFirstCloudOpen`: `#expect(!DriveTrackStorage.canRemoveLocalCopy(track, connectedOwnerID: "owner"))` until ID/size, verification and playback dates exist, then `#expect(DriveTrackStorage.canRemoveLocalCopy(track, connectedOwnerID: "owner"))`; owner mismatch remains false. `localRemovalPreservesTrackAndMembership`: `#expect(!FileManager.default.fileExists(atPath: localURL.path))`, `#expect(track.id == originalID)`, `#expect(membership.trackID == originalID)`. Use an in-memory `ModelContainer` and temporary `AudioFileStore`.
- [ ] **Step 2: Run** `xcodebuild -project GymFlow.xcodeproj -scheme GymFlow -destination 'platform=iOS Simulator,id=BE3E1DA1-5745-42DA-88B2-D3CAFF380FFF' -derivedDataPath /tmp/GymFlowDerivedData CODE_SIGNING_ALLOWED=NO -only-testing:GymFlowTests/GoogleDriveMusicTests test`. **Expected:** fail on missing fields/service.
- [ ] **Step 3: Implement** the fields and `DriveTrackStorage`; guard all eligibility before deletion and save model state only after the file operation succeeds. Existing local records must still load.
- [ ] **Step 4: Re-run the exact Task 1 test command.** **Expected:** the three tests pass.
- [ ] **Step 5: Run** the generic simulator build from `AGENTS.md`. **Expected:** `BUILD SUCCEEDED`; commit Task 1 files.

### Task 2: Native Google Authorization

**Files:** Create `GoogleDriveAuthorizationService.swift`; modify `Info.plist`, `project.pbxproj`; extend `GoogleDriveMusicTests.swift`.

**Interfaces:** Produce `GoogleDriveOAuthConfiguration.from(bundle: Bundle) -> GoogleDriveOAuthConfiguration?`, `GoogleDriveOAuthRequest.make(configuration: GoogleDriveOAuthConfiguration) -> GoogleDriveOAuthRequest` with `authorizationURL`, `verifier`, `state`, `code(from callbackURL: URL) throws -> String`, and `DriveAuthorizationError.invalidCallback`; `DriveAccessTokenProvider` with `accessToken() async throws -> String`, `refreshAccessToken() async throws -> String`, `connectedOwnerID: String?`; `GoogleDriveAuthorizationService.connect() async throws`, `disconnect() async`. Store refresh credential in Keychain. An injectable token exchange tests refresh without a browser; obtain owner ID from Drive `about.get?fields=user(permissionId)` after sign-in.

- [ ] **Step 1: Write failing tests.** `#expect(GoogleDriveOAuthConfiguration.from(bundle: emptyBundle) == nil)`; decode authorization URL query items and expect `scope == "https://www.googleapis.com/auth/drive.file"`, `code_challenge_method == "S256"` and nonempty state; `#expect(throws: DriveAuthorizationError.invalidCallback) { try request.code(from: wrongStateURL) }`; an expired access token yields exactly one fake token-exchange call, while a failed refresh leaves local tracks untouched.
- [ ] **Step 2: Run the Task 1 test command.** **Expected:** fail on missing authorization types.
- [ ] **Step 3: Implement** `ASWebAuthenticationSession` with PKCE and state, build-supplied client ID/reversed callback scheme, Keychain refresh storage, and an ephemeral token HTTP session. Disconnect attempts token revocation and always clears local credentials; a missing configuration must not affect app startup or local audio.
- [ ] **Step 4: Re-run the Task 1 test command.** **Expected:** authorization tests pass.
- [ ] **Step 5: Run** the generic simulator build from `AGENTS.md`. **Expected:** `BUILD SUCCEEDED`; commit Task 2 files.

### Task 3: Resumable Upload and Verification

**Files:** Create `GoogleDriveMusicService.swift`; extend `GoogleDriveMusicTests.swift`.

**Interfaces:** Produce `DriveHTTPTransport.send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)`, `DriveFileMetadata(id: String, size: Int64, md5Checksum: String?, ownerID: String)`, `GoogleDriveMusicService.upload(track: ImportedTrack, localURL: URL, context: ModelContext, onProgress: @escaping (Double) -> Void) async throws -> DriveFileMetadata`, and `verify(fileID: String, expectedSize: Int64, expectedMD5: String?) async throws -> DriveFileMetadata`. Inject `DriveAccessTokenProvider` and `DriveHTTPTransport`. Persist resumable-session checkpoints securely by track ID; keep a returned remote ID on the track before the subsequent verification request. `onProgress` reports `0...1`.

- [ ] **Step 1: Write failing tests.** A fake transport expects folder metadata name `"GymFlow Music"`, chunk `Content-Range` boundaries divisible by `262144` except the last, and monotonically increasing `onProgress` values ending at `1`. On retry after a returned file ID, `#expect(fake.createCount == 1)`; on size/MD5 mismatch, `#expect(track.driveVerifiedAt == nil)` and `#expect(FileManager.default.fileExists(atPath: localURL.path))`.
- [ ] **Step 2: Run the Task 1 test command.** **Expected:** fail on missing upload service.
- [ ] **Step 3: Implement** Drive `files.list`/`files.create`, resumable `PUT`/status query, metadata `files.get`, local MD5 with streaming `FileHandle` reads, and status-specific errors. Keep bearer tokens on `www.googleapis.com` requests; validate any upload-session URL before reuse. Save track metadata at each recoverable boundary.
- [ ] **Step 4: Re-run the Task 1 test command.** **Expected:** upload and preservation tests pass.
- [ ] **Step 5: Run** the generic simulator build from `AGENTS.md`. **Expected:** `BUILD SUCCEEDED`; commit Task 3 files.

### Task 4: Bounded Authenticated Range Loading

**Files:** Create `DriveMediaResourceLoader.swift`; extend `GoogleDriveMusicService.swift`, `GoogleDriveMusicTests.swift`.

**Interfaces:** Produce `GoogleDriveMusicService.readRange(fileID: String, start: Int64, length: Int) async throws -> Data` with a strict `206`/`Content-Range` contract; `DriveMediaResourceLoader(fileID: String, fileExtension: String, fileSize: Int64, service: GoogleDriveMusicService)` exposes an `AVURLAsset` with a custom scheme and implements cancellation of obsolete loading requests. Cap each network request at 256 KiB and use an ephemeral URL session with no disk URL cache.

- [ ] **Step 1: Write failing tests.** For `readRange(fileID: "id", start: 1024, length: 1024)`, `#expect(request.value(forHTTPHeaderField: "Range") == "bytes=1024-2047")` and `#expect(data.count == 1024)` on matching `206`. Assert `200`, malformed `Content-Range`, and an off-host redirect throw; `401` refreshes exactly once; `403`/`404` yield distinct user-facing errors; cancellation marks the fake range task cancelled.
- [ ] **Step 2: Run the Task 1 test command.** **Expected:** fail on missing range API/loader.
- [ ] **Step 3: Implement** host-safe authenticated range requests and `AVAssetResourceLoaderDelegate` content information/data responses. Never write media bytes to Application Support or accept a full-body fallback.
- [ ] **Step 4: Re-run the Task 1 test command.** **Expected:** range and cancellation tests pass.
- [ ] **Step 5: Run** the generic simulator build from `AGENTS.md`. **Expected:** `BUILD SUCCEEDED`; commit Task 4 files.

### Task 5: Shared Local/Cloud Playback

**Files:** Create `AudioPlaybackEngine.swift`; modify `AudioPlayerService.swift`; extend `GoogleDriveMusicTests.swift` and existing playback tests.

**Interfaces:** Produce `@MainActor AudioPlaybackEngine` with `isPlaying: Bool`, `currentTime: TimeInterval`, `duration: TimeInterval`, `volume: Float`, `onFinish: (() -> Void)?`, `onReady: (() -> Void)?`, `onError: ((Error) -> Void)?`, `play()`, `pause()`, `stop()`, `seek(to: TimeInterval)`, `setVolume(_: Float, fadeDuration: TimeInterval)`; `@MainActor AudioPlaybackEngineFactory.makeLocal(url: URL) throws -> any AudioPlaybackEngine`, `makeCloud(track: ImportedTrack) throws -> any AudioPlaybackEngine`, `connectedOwnerID: String?`, `canUseNetwork: Bool`. The cloud adapter calls `onReady` only after the item is playable **and** has received initial media bytes. Extend the existing `AudioPlayerService` initializer with an optional factory for tests and app injection, keeping its public UI API unchanged. Local adapter wraps `AVAudioPlayer`; cloud adapter wraps `AVPlayer` plus `DriveMediaResourceLoader`.

- [ ] **Step 1: Write failing tests.** With injected fake engines, `#expect(factory.localCount == 1 && factory.cloudCount == 0)` when the file exists, `#expect(factory.cloudCount == 1)` after it is missing and Drive is verified, and `#expect(player.playlist.map(\.id) == originalIDs)` across fallback. Trigger the fake finish callback and expect the next track ID; assert seek, alert duck/restore and pause route to the active engine. Offline/signed-out/other-owner cases must leave `factory.cloudCount == 0` and set a recoverable `lastError`. Only fake ready **plus first buffered media** may set `drivePlaybackValidatedAt`; a test table covers all eight `AudioFileStore.supportedExtensions` for content-type mapping, with real decoder checks and a signed-device format matrix where fixtures permit.
- [ ] **Step 2: Run the Task 1 test command.** **Expected:** fail on missing engine seam/cloud selection.
- [ ] **Step 3: Implement** the adapters and refactor only the engine-specific portions of `AudioPlayerService`. Preserve its queue snapshot, interruption handling, remote commands and Now Playing updates; cancel obsolete range loads on track changes.
- [ ] **Step 4: Re-run the Task 1 test command.** **Expected:** playback tests pass; run the full `GymFlowTests` suite to catch local-audio regressions.
- [ ] **Step 5: Run** the generic simulator build from `AGENTS.md`. **Expected:** `BUILD SUCCEEDED`; commit Task 5 files.

### Task 6: Music Controls, Safe Deletion and Rollout

**Files:** Create `DriveMusicController.swift`, `DriveMusicView.swift`; modify `MusicLibraryView.swift`, `TrackRow.swift`, `SettingsView.swift`, `GymFlowApp.swift`, `README.md`, `PROJECT_SPEC.md`, `PLANS.md`, `PROGRESS.md`; extend `GoogleDriveMusicTests.swift` and `GymFlowUITests.swift`.

**Interfaces:** `@MainActor DriveMusicController` exposes connection status, `uploadProgressByTrackID: [UUID: Double]`, `connect() async`, `upload(_ tracks: [ImportedTrack], context: ModelContext) async`, `removeLocalCopy(_ track: ImportedTrack, context: ModelContext) throws`, `disconnect() async`; views show explicit selection/all upload, verified/cloud-only badges, a confirmed local-copy removal action and recoverable errors.

- [ ] **Step 1: Write failing tests.** For selected IDs `[first.id]`, `#expect(fake.uploadedIDs == [first.id])` and the second file still exists. On failed upload, expect both files present. A fake remote delete trap must remain uncalled after track deletion and Settings bulk audio; playlist membership is removed only when the GymFlow track is removed. After disconnect, `#expect(membership.trackID == track.id)`. UI test `testDriveMusicUnconfigured` finds setup guidance and enabled **Import Audio**.
- [ ] **Step 2: Run** the Task 1 test command, then `xcodebuild -project GymFlow.xcodeproj -scheme GymFlow -destination 'platform=iOS Simulator,id=BE3E1DA1-5745-42DA-88B2-D3CAFF380FFF' -derivedDataPath /tmp/GymFlowDerivedData CODE_SIGNING_ALLOWED=NO -only-testing:GymFlowUITests/GymFlowUITests/testDriveMusicUnconfigured test`. **Expected:** fail on missing controller/controls.
- [ ] **Step 3: Implement** the controller and screens, accessibility labels, confirmations and deletion copy. Provide setup instructions for Google Cloud Drive API, consent screen, iOS OAuth client ID and callback scheme, and a manual signed-iPhone matrix for upload, playback, backgrounding, network loss, local removal and supported audio formats.
- [ ] **Step 4: Run** complete `GymFlowTests` and relevant `GymFlowUITests`. **Expected:** `TEST SUCCEEDED`; record any credential-dependent real-device checks as unverified until actually run.
- [ ] **Step 5: Run** semantic lint and the generic simulator build from `AGENTS.md`; inspect `git diff --check`. **Expected:** zero semantic lint findings, `BUILD SUCCEEDED`, no whitespace errors; update `PLANS.md`/`PROGRESS.md` and commit Task 6 files.
