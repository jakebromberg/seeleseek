import Testing
import Foundation
@testable import SeeleseekCore

@Suite("Model Tests")
struct ModelTests {

    // MARK: - SearchResult

    @Suite("SearchResult")
    struct SearchResultTests {

        @Test("displayFilename extracts last path component")
        func displayFilename() {
            let result = SearchResult(username: "user", filename: "@@music\\Artist\\Album\\Track.mp3", size: 1000)
            #expect(result.displayFilename == "Track.mp3")
        }

        @Test("displayFilename returns full name when no separators")
        func displayFilenameNoSeparator() {
            let result = SearchResult(username: "user", filename: "Track.mp3", size: 1000)
            #expect(result.displayFilename == "Track.mp3")
        }

        @Test("folderPath returns path without filename")
        func folderPath() {
            let result = SearchResult(username: "user", filename: "@@music\\Artist\\Album\\Track.mp3", size: 1000)
            #expect(result.folderPath == "@@music\\Artist\\Album")
        }

        @Test("folderPath returns empty for single component")
        func folderPathSingleComponent() {
            let result = SearchResult(username: "user", filename: "Track.mp3", size: 1000)
            #expect(result.folderPath == "")
        }

        @Test("formattedDuration nil when duration is nil")
        func formattedDurationNil() {
            let result = SearchResult(username: "user", filename: "f", size: 0, duration: nil)
            #expect(result.formattedDuration == nil)
        }

        @Test("formattedDuration formats minutes and seconds")
        func formattedDuration() {
            let result = SearchResult(username: "user", filename: "f", size: 0, duration: 185)
            #expect(result.formattedDuration == "3:05")
        }

        @Test("formattedDuration zero seconds")
        func formattedDurationZero() {
            let result = SearchResult(username: "user", filename: "f", size: 0, duration: 0)
            #expect(result.formattedDuration == "0:00")
        }

        @Test("formattedBitrate nil when bitrate is nil")
        func formattedBitrateNil() {
            let result = SearchResult(username: "user", filename: "f", size: 0, bitrate: nil)
            #expect(result.formattedBitrate == nil)
        }

        @Test("formattedBitrate CBR format")
        func formattedBitrateCBR() {
            let result = SearchResult(username: "user", filename: "f", size: 0, bitrate: 320, isVBR: false)
            #expect(result.formattedBitrate == "320 kbps")
        }

        @Test("formattedBitrate VBR format with tilde prefix")
        func formattedBitrateVBR() {
            let result = SearchResult(username: "user", filename: "f", size: 0, bitrate: 256, isVBR: true)
            #expect(result.formattedBitrate == "~256 kbps")
        }

        @Test("formattedSampleRate nil when nil")
        func formattedSampleRateNil() {
            let result = SearchResult(username: "user", filename: "f", size: 0, sampleRate: nil)
            #expect(result.formattedSampleRate == nil)
        }

        @Test("formattedSampleRate nil when zero")
        func formattedSampleRateZero() {
            let result = SearchResult(username: "user", filename: "f", size: 0, sampleRate: 0)
            #expect(result.formattedSampleRate == nil)
        }

        @Test("formattedSampleRate 44100 Hz")
        func formattedSampleRate44100() {
            let result = SearchResult(username: "user", filename: "f", size: 0, sampleRate: 44100)
            #expect(result.formattedSampleRate == "44.1 kHz")
        }

        @Test("formattedSampleRate 48000 Hz")
        func formattedSampleRate48000() {
            let result = SearchResult(username: "user", filename: "f", size: 0, sampleRate: 48000)
            #expect(result.formattedSampleRate == "48 kHz")
        }

        @Test("formattedSampleRate 96000 Hz")
        func formattedSampleRate96000() {
            let result = SearchResult(username: "user", filename: "f", size: 0, sampleRate: 96000)
            #expect(result.formattedSampleRate == "96 kHz")
        }

        @Test("formattedBitDepth nil when nil")
        func formattedBitDepthNil() {
            let result = SearchResult(username: "user", filename: "f", size: 0, bitDepth: nil)
            #expect(result.formattedBitDepth == nil)
        }

        @Test("formattedBitDepth nil when zero")
        func formattedBitDepthZero() {
            let result = SearchResult(username: "user", filename: "f", size: 0, bitDepth: 0)
            #expect(result.formattedBitDepth == nil)
        }

        @Test("formattedBitDepth formats correctly", arguments: [
            (UInt32(16), "16-bit"),
            (UInt32(24), "24-bit"),
            (UInt32(32), "32-bit"),
        ])
        func formattedBitDepth(bitDepth: UInt32, expected: String) {
            let result = SearchResult(username: "user", filename: "f", size: 0, bitDepth: bitDepth)
            #expect(result.formattedBitDepth == expected)
        }

        @Test("fileExtension extracts lowercased extension")
        func fileExtension() {
            let result = SearchResult(username: "user", filename: "@@music\\Track.MP3", size: 0)
            #expect(result.fileExtension == "mp3")
        }

        @Test("fileExtension returns empty for no extension")
        func fileExtensionNone() {
            let result = SearchResult(username: "user", filename: "noext", size: 0)
            #expect(result.fileExtension == "")
        }

        @Test("isAudioFile delegates to FileTypes")
        func isAudioFile() {
            let mp3 = SearchResult(username: "user", filename: "song.mp3", size: 0)
            let jpg = SearchResult(username: "user", filename: "pic.jpg", size: 0)
            #expect(mp3.isAudioFile)
            #expect(!jpg.isAudioFile)
        }

        @Test("isLossless delegates to FileTypes")
        func isLossless() {
            let flac = SearchResult(username: "user", filename: "song.flac", size: 0)
            let mp3 = SearchResult(username: "user", filename: "song.mp3", size: 0)
            #expect(flac.isLossless)
            #expect(!mp3.isLossless)
        }

        @Test("formattedSize delegates to ByteFormatter")
        func formattedSize() {
            let result = SearchResult(username: "user", filename: "f", size: 1_048_576)
            #expect(result.formattedSize == "1.0 MB")
        }

        @Test("formattedSpeed delegates to ByteFormatter")
        func formattedSpeed() {
            let result = SearchResult(username: "user", filename: "f", size: 0, uploadSpeed: 0)
            #expect(result.formattedSpeed == "0 B/s")
        }
    }

    // MARK: - SharedFile

    @Suite("SharedFile")
    struct SharedFileTests {

        @Test("displayName extracts last path component")
        func displayName() {
            let file = SharedFile(filename: "@@music\\Artist\\Song.flac")
            #expect(file.displayName == "Song.flac")
        }

        @Test("displayName returns full name when no separator")
        func displayNameNoSeparator() {
            let file = SharedFile(filename: "Song.flac")
            #expect(file.displayName == "Song.flac")
        }

        @Test("fileExtension extracts and lowercases")
        func fileExtension() {
            let file = SharedFile(filename: "Song.FLAC")
            #expect(file.fileExtension == "flac")
        }

        @Test("fileExtension returns empty for no extension")
        func fileExtensionNone() {
            let file = SharedFile(filename: "README")
            #expect(file.fileExtension == "")
        }

        @Test("isAudioFile for audio extension")
        func isAudioFile() {
            #expect(SharedFile(filename: "song.mp3").isAudioFile)
            #expect(!SharedFile(filename: "pic.jpg").isAudioFile)
        }

        @Test("isImageFile for image extension")
        func isImageFile() {
            #expect(SharedFile(filename: "cover.jpg").isImageFile)
            #expect(!SharedFile(filename: "song.mp3").isImageFile)
        }

        @Test("isVideoFile for video extension")
        func isVideoFile() {
            #expect(SharedFile(filename: "clip.mp4").isVideoFile)
        }

        @Test("isArchiveFile for archive extension")
        func isArchiveFile() {
            #expect(SharedFile(filename: "files.zip").isArchiveFile)
        }

        @Test("isLossless for lossless extension")
        func isLossless() {
            #expect(SharedFile(filename: "song.flac").isLossless)
            #expect(!SharedFile(filename: "song.mp3").isLossless)
        }

        @Test("collectAllFiles from flat list of non-directories")
        func collectAllFilesFlat() {
            let files = [
                SharedFile(filename: "a.mp3", size: 100),
                SharedFile(filename: "b.flac", size: 200),
            ]
            let collected = SharedFile.collectAllFiles(in: files)
            #expect(collected.count == 2)
        }

        @Test("collectAllFiles recurses into directories")
        func collectAllFilesNested() {
            let dir = SharedFile(
                filename: "folder",
                isDirectory: true,
                children: [
                    SharedFile(filename: "a.mp3", size: 100),
                    SharedFile(filename: "b.mp3", size: 200),
                ]
            )
            let collected = SharedFile.collectAllFiles(in: [dir])
            #expect(collected.count == 2)
        }

        @Test("collectAllFiles skips empty directories")
        func collectAllFilesEmptyDir() {
            let dir = SharedFile(filename: "empty", isDirectory: true, children: [])
            let collected = SharedFile.collectAllFiles(in: [dir])
            #expect(collected.isEmpty)
        }

        @Test("buildTree from empty array returns empty")
        func buildTreeEmpty() {
            let tree = SharedFile.buildTree(from: [])
            #expect(tree.isEmpty)
        }

        @Test("buildTree creates hierarchy from flat files")
        func buildTreeHierarchy() {
            let files = [
                SharedFile(filename: "@@music\\Artist\\Album\\01 Song.mp3", size: 1000),
                SharedFile(filename: "@@music\\Artist\\Album\\02 Track.mp3", size: 2000),
            ]
            let tree = SharedFile.buildTree(from: files)

            #expect(tree.count == 1) // one root folder: @@music
            let root = tree[0]
            #expect(root.isDirectory)
            #expect(root.fileCount == 2)
            #expect(root.size == 3000)
        }

        @Test("buildTree sorts folders before files alphabetically")
        func buildTreeSorting() {
            let files = [
                SharedFile(filename: "root\\Zebra\\file.mp3", size: 100),
                SharedFile(filename: "root\\Alpha\\file.mp3", size: 200),
                SharedFile(filename: "root\\standalone.mp3", size: 300),
            ]
            let tree = SharedFile.buildTree(from: files)

            #expect(tree.count == 1)
            let root = tree[0]
            let children = root.children ?? []

            // Folders first (Alpha, Zebra), then files (standalone.mp3)
            #expect(children.count == 3)
            #expect(children[0].isDirectory)
            #expect(children[0].displayName == "Alpha")
            #expect(children[1].isDirectory)
            #expect(children[1].displayName == "Zebra")
            #expect(!children[2].isDirectory)
            #expect(children[2].displayName == "standalone.mp3")
        }
    }

    // MARK: - Transfer

    @Suite("Transfer")
    struct TransferTests {

        @Test("displayFilename extracts last component")
        func displayFilename() {
            let t = Transfer(username: "user", filename: "@@music\\Artist\\Song.mp3", size: 100, direction: .download)
            #expect(t.displayFilename == "Song.mp3")
        }

        @Test("folderPath skips @@ prefix and joins with /")
        func folderPath() {
            let t = Transfer(username: "user", filename: "@@music\\Artist\\Album\\Song.mp3", size: 100, direction: .download)
            #expect(t.folderPath == "Artist / Album")
        }

        @Test("folderPath nil for single component")
        func folderPathSingle() {
            let t = Transfer(username: "user", filename: "Song.mp3", size: 100, direction: .download)
            #expect(t.folderPath == nil)
        }

        @Test("folderPath includes root when not prefixed with @@")
        func folderPathNoPrefix() {
            let t = Transfer(username: "user", filename: "Music\\Artist\\Song.mp3", size: 100, direction: .download)
            #expect(t.folderPath == "Music / Artist")
        }

        @Test("progress zero when size is zero")
        func progressZeroSize() {
            let t = Transfer(username: "user", filename: "f", size: 0, direction: .download)
            #expect(t.progress == 0)
        }

        @Test("progress calculates correctly")
        func progressCalculation() {
            let t = Transfer(username: "user", filename: "f", size: 100, direction: .download, bytesTransferred: 50)
            #expect(t.progress == 0.5)
        }

        @Test("progress at 100%")
        func progressComplete() {
            let t = Transfer(username: "user", filename: "f", size: 100, direction: .download, bytesTransferred: 100)
            #expect(t.progress == 1.0)
        }

        @Test("isActive true for connecting and transferring", arguments: [
            Transfer.TransferStatus.connecting,
            .transferring,
        ])
        func isActive(status: Transfer.TransferStatus) {
            let t = Transfer(username: "user", filename: "f", size: 100, direction: .download, status: status)
            #expect(t.isActive)
        }

        @Test("isActive false for non-active statuses", arguments: [
            Transfer.TransferStatus.queued,
            .completed,
            .failed,
            .cancelled,
            .waiting,
        ])
        func isNotActive(status: Transfer.TransferStatus) {
            let t = Transfer(username: "user", filename: "f", size: 100, direction: .download, status: status)
            #expect(!t.isActive)
        }

        @Test("canCancel true for cancellable statuses", arguments: [
            Transfer.TransferStatus.queued,
            .connecting,
            .transferring,
            .waiting,
        ])
        func canCancel(status: Transfer.TransferStatus) {
            let t = Transfer(username: "user", filename: "f", size: 100, direction: .download, status: status)
            #expect(t.canCancel)
        }

        @Test("canCancel false for non-cancellable statuses", arguments: [
            Transfer.TransferStatus.completed,
            .failed,
            .cancelled,
        ])
        func cannotCancel(status: Transfer.TransferStatus) {
            let t = Transfer(username: "user", filename: "f", size: 100, direction: .download, status: status)
            #expect(!t.canCancel)
        }

        @Test("canRetry true for failed and cancelled", arguments: [
            Transfer.TransferStatus.failed,
            .cancelled,
        ])
        func canRetry(status: Transfer.TransferStatus) {
            let t = Transfer(username: "user", filename: "f", size: 100, direction: .download, status: status)
            #expect(t.canRetry)
        }

        @Test("canRetry false for non-retryable statuses", arguments: [
            Transfer.TransferStatus.queued,
            .connecting,
            .transferring,
            .completed,
            .waiting,
        ])
        func cannotRetry(status: Transfer.TransferStatus) {
            let t = Transfer(username: "user", filename: "f", size: 100, direction: .download, status: status)
            #expect(!t.canRetry)
        }

        @Test("isAudioFile checks extension via NSString pathExtension")
        func isAudioFile() {
            let mp3 = Transfer(username: "user", filename: "song.mp3", size: 100, direction: .download)
            let jpg = Transfer(username: "user", filename: "pic.jpg", size: 100, direction: .download)
            #expect(mp3.isAudioFile)
            #expect(!jpg.isAudioFile)
        }
    }

    // MARK: - UserShares

    @Suite("UserShares")
    struct UserSharesTests {

        @Test("totalFiles counts non-directory files recursively")
        func totalFiles() {
            let dir = SharedFile(
                filename: "root",
                isDirectory: true,
                children: [
                    SharedFile(filename: "a.mp3", size: 100),
                    SharedFile(filename: "sub", isDirectory: true, children: [
                        SharedFile(filename: "b.mp3", size: 200),
                    ]),
                ]
            )
            let shares = UserShares(username: "user", folders: [dir])
            #expect(shares.totalFiles == 2)
        }

        @Test("totalSize sums all file sizes recursively")
        func totalSize() {
            let dir = SharedFile(
                filename: "root",
                isDirectory: true,
                children: [
                    SharedFile(filename: "a.mp3", size: 100),
                    SharedFile(filename: "sub", isDirectory: true, children: [
                        SharedFile(filename: "b.mp3", size: 200),
                    ]),
                ]
            )
            let shares = UserShares(username: "user", folders: [dir])
            #expect(shares.totalSize == 300)
        }

        @Test("empty folders return zero stats")
        func emptyFolders() {
            let shares = UserShares(username: "user", folders: [])
            #expect(shares.totalFiles == 0)
            #expect(shares.totalSize == 0)
        }

        @Test("computeStats caches results")
        func computeStatsCaches() {
            var shares = UserShares(
                username: "user",
                folders: [SharedFile(filename: "a.mp3", size: 500)]
            )
            #expect(shares.cachedTotalFiles == nil)
            shares.computeStats()
            #expect(shares.cachedTotalFiles == 1)
            #expect(shares.cachedTotalSize == 500)
        }
    }

    // MARK: - SearchQuery

    @Suite("SearchQuery")
    struct SearchQueryTests {

        @Test("resultCount returns results count")
        func resultCount() {
            var query = SearchQuery(query: "test", token: 1)
            #expect(query.resultCount == 0)
            query.results.append(SearchResult(username: "user", filename: "f", size: 0))
            #expect(query.resultCount == 1)
        }

        @Test("uniqueUsers counts distinct usernames")
        func uniqueUsers() {
            var query = SearchQuery(query: "test", token: 1)
            query.results = [
                SearchResult(username: "alice", filename: "f1", size: 0),
                SearchResult(username: "bob", filename: "f2", size: 0),
                SearchResult(username: "alice", filename: "f3", size: 0),
            ]
            #expect(query.uniqueUsers == 2)
        }

        @Test("convenience init sets defaults correctly")
        func convenienceInit() {
            let query = SearchQuery(query: "music", token: 42)
            #expect(query.query == "music")
            #expect(query.token == 42)
            #expect(query.results.isEmpty)
            #expect(query.isSearching)
        }
    }

    // MARK: - ChatMessage

    @Suite("ChatMessage")
    struct ChatMessageTests {

        @Test("formattedTime produces non-empty string")
        func formattedTime() {
            let msg = ChatMessage(username: "user", content: "hello")
            #expect(!msg.formattedTime.isEmpty)
        }

        @Test("formattedDate produces non-empty string")
        func formattedDate() {
            let msg = ChatMessage(username: "user", content: "hello")
            #expect(!msg.formattedDate.isEmpty)
        }

        @Test("default values are correct")
        func defaults() {
            let msg = ChatMessage(username: "user", content: "hello")
            #expect(!msg.isSystem)
            #expect(!msg.isOwn)
            #expect(msg.isNewMessage)
            #expect(msg.messageId == nil)
        }
    }

    // MARK: - ChatRoom

    @Suite("ChatRoom")
    struct ChatRoomTests {

        @Test("userCount returns users count")
        func userCount() {
            let room = ChatRoom(name: "test", users: ["alice", "bob", "charlie"])
            #expect(room.userCount == 3)
        }

        @Test("userCount zero for empty room")
        func userCountEmpty() {
            let room = ChatRoom(name: "test")
            #expect(room.userCount == 0)
        }

        @Test("id equals name")
        func idEqualsName() {
            let room = ChatRoom(name: "soulseek")
            #expect(room.id == "soulseek")
        }
    }

    // MARK: - User

    @Suite("User")
    struct UserTests {

        @Test("formattedSpeed delegates to ByteFormatter")
        func formattedSpeed() {
            let user = User(username: "test", averageSpeed: 0)
            #expect(user.formattedSpeed == "0 B/s")
        }

        @Test("formattedSpeed with value")
        func formattedSpeedWithValue() {
            let user = User(username: "test", averageSpeed: 102_400)
            #expect(user.formattedSpeed == "100.0 KB/s")
        }

        @Test("default status is offline")
        func defaultStatus() {
            let user = User(username: "test")
            #expect(user.status == .offline)
        }

        @Test("id equals username")
        func idEqualsUsername() {
            let user = User(username: "alice")
            #expect(user.id == "alice")
        }
    }
}
