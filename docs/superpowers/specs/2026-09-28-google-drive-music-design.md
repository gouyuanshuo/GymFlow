# Google Drive music design

## Intent and scope

GymFlow's owner wants to upload songs already imported into the app to a private Google Drive folder, then play them without retaining permanent song copies on the iPhone. Existing playlists, workout music controls, and local playback must continue to work. Workouts, plans, timers, and history remain usable offline; cloud-only songs require a connection.

"No download" means GymFlow stores no complete audio file after the user removes the verified local copy. Playback still transfers and buffers temporary bytes. The app will not claim that iOS keeps zero transient media data.

## Recommended approach

Integrate directly with the Google Drive API. Google Drive's `files.get?alt=media` supports byte-range requests, allowing on-demand reads for playback. Opening Drive files through Files is unsuitable for this goal because a file provider can download the whole file before the app reads it. The direct integration uses native Apple APIs, no GymFlow backend, and the narrow `drive.file` scope for files GymFlow creates.

The app owner must enable the Google Drive API, configure an OAuth consent screen and an iOS OAuth client for bundle ID `com.gouyuanshuo.GymFlow`, and provide the client ID to the Xcode build. Credentials are not committed. A live Google sign-in test requires that setup.

## User flow

1. The Music screen offers **Connect Google Drive**. Sign-in is optional and uses Google's consent screen.
2. **Upload Imported Songs** uploads selected or all local tracks to a `GymFlow Music` folder with per-track progress. The current local library and playlists remain available throughout.
3. GymFlow marks a track cloud-ready only after Google returns its file ID and a metadata read confirms the uploaded size; it also compares the checksum when Google provides one. It retains an incomplete upload's remote ID so retry can verify that file before creating another. Interrupted or unverified uploads leave the local copy intact.
4. Once verified and successfully opened by the cloud player, the track offers **Remove Local Copy**. This deletes only GymFlow's app-owned copy after confirmation. The track, its stable UUID, queue position, and playlist memberships remain.
5. Playback prefers an available local copy and otherwise streams the Drive file. Cloud-only rows show their network requirement. If offline or signed out, they remain in the library but show a recoverable error when played.
6. Removing a track from GymFlow removes its local record and playlist memberships, and any remaining app-owned local copy. It never deletes the Drive original. The Settings bulk audio deletion follows the same rule and says so explicitly.

New imports keep the existing local import path and can then be uploaded and converted to cloud-only tracks. Automatic upload is outside this release so importing a file never silently sends it to Google.

## Components and data flow

- `GoogleDriveAuthorizationService` uses `ASWebAuthenticationSession` with PKCE and a random state value. Refresh credentials live in Keychain; access tokens are refreshed as needed. Disconnect revokes credentials when possible but retains track and playlist metadata so reconnection can restore access.
- `GoogleDriveMusicService` creates or locates the app-owned folder, performs resumable uploads, verifies metadata, and requests authenticated byte ranges. It keeps API, retry, and HTTP error handling out of SwiftUI views. Access tokens are sent only to Google's API host; any download redirects are checked before following them.
- `ImportedTrack` gains optional remote file metadata while retaining its UUID and existing local filename fields. A missing local file is valid when a verified Drive file ID exists. Existing SwiftData stores migrate without rewriting completed workout snapshots.
- `AudioPlayerService` remains the single queue and Now Playing owner. A small playback-engine boundary retains the current `AVAudioPlayer` path for local files and adds an `AVPlayer` path with `AVAssetResourceLoader` for Drive ranges. Both expose play, pause, seek, duration, completion, and volume so shuffle, repeat, remote commands, background playback, and rest-alert ducking keep one behavior.
- The streaming loader fetches only ranges requested by the media player, bounds in-memory buffering, cancels obsolete requests after a seek or track change, and never writes song data to Application Support. It refreshes an expired token once and reports permission, missing-file, network, and unsupported-format failures in the Music UI.

The first release supports one connected Google account at a time. Switching accounts does not rewrite existing cloud track IDs; tracks from the previous account stay visible and may be played again after reconnecting to that account.

## Verification and rollout

- Unit tests cover upload/verification transitions, interrupted retry behavior, local-copy preservation, range headers and responses, token refresh, cloud-only offline errors, and playlist/queue identity.
- Focused playback tests cover the supported imported formats, seeking, track advance, background controls, and timer-alert ducking. A real-device pass with the owner's Google account checks upload, cloud-only playback, backgrounding, network loss, and local-copy removal.
- Run semantic lint, a simulator build after each milestone, and relevant tests. Record exact commands and outcomes in `PROGRESS.md`; update `PROJECT_SPEC.md`, `PLANS.md`, and `README.md` to describe optional online music accurately.
- Upload or playback failure never deletes the local source. Cloud-only playback does not fall back to downloading a full file.

## Sources

- [Google Drive download and byte-range support](https://developers.google.com/workspace/drive/api/guides/manage-downloads)
- [Google Drive upload guidance](https://developers.google.com/workspace/drive/api/guides/manage-uploads)
- [Google Drive scopes](https://developers.google.com/workspace/drive/api/guides/api-specific-auth)
- [Google OAuth for iOS](https://developers.google.com/identity/protocols/oauth2/native-app)
- [Apple resource loader](https://developer.apple.com/documentation/avfoundation/avassetresourceloader)
- [Apple document picker download behavior](https://developer.apple.com/library/archive/documentation/FileManagement/Conceptual/DocumentPickerProgrammingGuide/CreatinganOutstandingUserExperience/CreatinganOutstandingUserExperience.html)
