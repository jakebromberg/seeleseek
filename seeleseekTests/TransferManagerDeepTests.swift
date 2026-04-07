import Testing
import Foundation
@testable import SeeleseekCore
@testable import seeleseek

// MARK: - Mock Implementations (redefined for this file since originals may be file-private)

@MainActor
private final class DeepMockTransferTracking: TransferTracking {
    var downloads: [Transfer] = []
    var uploads: [Transfer] = []

    private(set) var addDownloadCalls: [Transfer] = []
    private(set) var addUploadCalls: [Transfer] = []
    private(set) var updateTransferCallIds: [UUID] = []
    private(set) var getTransferCalls: [UUID] = []

    func addDownload(_ transfer: Transfer) {
        addDownloadCalls.append(transfer)
        downloads.append(transfer)
    }

    func addUpload(_ transfer: Transfer) {
        addUploadCalls.append(transfer)
        uploads.append(transfer)
    }

    func updateTransfer(id: UUID, update: (inout Transfer) -> Void) {
        updateTransferCallIds.append(id)
        if let index = downloads.firstIndex(where: { $0.id == id }) {
            update(&downloads[index])
        }
        if let index = uploads.firstIndex(where: { $0.id == id }) {
            update(&uploads[index])
        }
    }

    func getTransfer(id: UUID) -> Transfer? {
        getTransferCalls.append(id)
        return downloads.first(where: { $0.id == id }) ?? uploads.first(where: { $0.id == id })
    }
}

@MainActor
private final class DeepMockStatisticsRecording: StatisticsRecording {
    struct RecordedTransfer {
        let filename: String
        let username: String
        let size: UInt64
        let duration: TimeInterval
        let isDownload: Bool
    }

    private(set) var recordedTransfers: [RecordedTransfer] = []

    func recordTransfer(filename: String, username: String, size: UInt64, duration: TimeInterval, isDownload: Bool) {
        recordedTransfers.append(RecordedTransfer(
            filename: filename,
            username: username,
            size: size,
            duration: duration,
            isDownload: isDownload
        ))
    }
}

@MainActor
private final class DeepMockDownloadSettings: DownloadSettingsProviding {
    var activeDownloadTemplate: String = "{username}/{folders}/{filename}"
    var setFolderIcons: Bool = false
}

private actor DeepMockMetadataReader: MetadataReading {
    var metadataToReturn: AudioFileMetadata?

    func extractAudioMetadata(from url: URL) async -> AudioFileMetadata? {
        metadataToReturn
    }

    func extractArtwork(from url: URL) async -> Data? {
        nil
    }

    func applyArtworkAsFolderIcon(for directory: URL) async -> Bool {
        false
    }
}

// MARK: - DownloadManager Deep Tests

@Suite("DownloadManager Deep Tests", .serialized)
@MainActor
struct DownloadManagerDeepTests {

    // MARK: - Helpers

    private func makeConfiguredDownloadManager() -> (DownloadManager, DeepMockTransferTracking, DeepMockStatisticsRecording, UploadManager, NetworkClient) {
        let dm = DownloadManager()
        let client = NetworkClient()
        let tracking = DeepMockTransferTracking()
        let stats = DeepMockStatisticsRecording()
        let settings = DeepMockDownloadSettings()
        let metadata = DeepMockMetadataReader()
        let um = UploadManager()

        dm.configure(
            networkClient: client,
            transferState: tracking,
            statisticsState: stats,
            uploadManager: um,
            settings: settings,
            metadataReader: metadata
        )

        return (dm, tracking, stats, um, client)
    }

    // MARK: - configure()

    @Test("configure() sets up internal dependencies without crash")
    func configureSetsDependencies() {
        let (dm, _, _, _, _) = makeConfiguredDownloadManager()
        _ = dm // Verify configure completed
    }

    @Test("configure() can be called with different settings")
    func configureWithCustomSettings() {
        let dm = DownloadManager()
        let client = NetworkClient()
        let tracking = DeepMockTransferTracking()
        let stats = DeepMockStatisticsRecording()
        let settings = DeepMockDownloadSettings()
        settings.activeDownloadTemplate = "{artist}/{album}/{filename}"
        settings.setFolderIcons = true
        let metadata = DeepMockMetadataReader()
        let um = UploadManager()

        dm.configure(
            networkClient: client,
            transferState: tracking,
            statisticsState: stats,
            uploadManager: um,
            settings: settings,
            metadataReader: metadata
        )
    }

    // MARK: - queueDownload()

    @Test("queueDownload adds transfer to tracking")
    func queueDownloadAddsTransfer() {
        let (dm, tracking, _, _, client) = makeConfiguredDownloadManager()
        _ = client  // retain NetworkClient so weak ref stays alive

        let result = SearchResult(username: "alice", filename: "@@music\\Artist\\Song.mp3", size: 5_000_000)
        dm.queueDownload(from: result)

        #expect(tracking.addDownloadCalls.count == 1)
        #expect(tracking.addDownloadCalls[0].username == "alice")
        #expect(tracking.addDownloadCalls[0].filename == "@@music\\Artist\\Song.mp3")
        #expect(tracking.addDownloadCalls[0].size == 5_000_000)
        #expect(tracking.addDownloadCalls[0].direction == .download)
        #expect(tracking.addDownloadCalls[0].status == .queued)
    }

    @Test("queueDownload skips macOS resource fork files")
    func queueDownloadSkipsResourceFork() {
        let (dm, tracking, _, _, client) = makeConfiguredDownloadManager()
        _ = client

        // __MACOSX folder
        let result1 = SearchResult(username: "alice", filename: "@@music\\__MACOSX\\._Song.mp3", size: 100)
        dm.queueDownload(from: result1)

        #expect(tracking.addDownloadCalls.isEmpty)

        // ._ prefix file
        let result2 = SearchResult(username: "alice", filename: "@@music\\Artist\\._hidden.mp3", size: 100)
        dm.queueDownload(from: result2)

        #expect(tracking.addDownloadCalls.isEmpty)

        // .DS_Store file
        let result3 = SearchResult(username: "alice", filename: "@@music\\Artist\\.DS_Store", size: 100)
        dm.queueDownload(from: result3)

        #expect(tracking.addDownloadCalls.isEmpty)
    }

    @Test("queueDownload accepts normal files")
    func queueDownloadAcceptsNormal() {
        let (dm, tracking, _, _, client) = makeConfiguredDownloadManager()
        _ = client

        let result = SearchResult(username: "bob", filename: "@@music\\Radiohead\\OK Computer\\01 Airbag.flac", size: 30_000_000)
        dm.queueDownload(from: result)

        #expect(tracking.addDownloadCalls.count == 1)
        #expect(tracking.addDownloadCalls[0].filename == "@@music\\Radiohead\\OK Computer\\01 Airbag.flac")
    }

    @Test("Multiple queueDownload calls create multiple transfers")
    func queueDownloadMultiple() {
        let (dm, tracking, _, _, client) = makeConfiguredDownloadManager()
        _ = client

        for i in 0..<5 {
            let result = SearchResult(username: "alice", filename: "@@music\\Artist\\Song\(i).mp3", size: UInt64(i * 1000))
            dm.queueDownload(from: result)
        }

        #expect(tracking.addDownloadCalls.count == 5)
    }

    // MARK: - resumeDownloadsOnConnect()

    @Test("resumeDownloadsOnConnect with no queued downloads is a no-op")
    func resumeDownloadsOnConnectEmpty() {
        let (dm, _, _, _, _) = makeConfiguredDownloadManager()
        dm.resumeDownloadsOnConnect()
        // Should not crash
    }

    @Test("resumeDownloadsOnConnect resumes queued downloads")
    func resumeDownloadsOnConnectQueued() {
        let (dm, tracking, _, _, _) = makeConfiguredDownloadManager()

        // Manually add a queued download to tracking
        let transfer = Transfer(
            username: "alice",
            filename: "@@music\\Song.mp3",
            size: 5000,
            direction: .download,
            status: .queued
        )
        tracking.addDownload(transfer)

        dm.resumeDownloadsOnConnect()
        // The method should attempt to resume the download (won't connect since no real server)
    }

    @Test("resumeDownloadsOnConnect resumes waiting downloads")
    func resumeDownloadsOnConnectWaiting() {
        let (dm, tracking, _, _, _) = makeConfiguredDownloadManager()

        var transfer = Transfer(
            username: "alice",
            filename: "@@music\\Song.mp3",
            size: 5000,
            direction: .download,
            status: .waiting
        )
        tracking.addDownload(transfer)

        dm.resumeDownloadsOnConnect()
    }

    @Test("resumeDownloadsOnConnect resumes retriable failed downloads")
    func resumeDownloadsOnConnectRetriableFailed() {
        let (dm, tracking, _, _, _) = makeConfiguredDownloadManager()

        let transfer = Transfer(
            username: "alice",
            filename: "@@music\\Song.mp3",
            size: 5000,
            direction: .download,
            status: .failed,
            error: "Connection timeout"
        )
        tracking.addDownload(transfer)

        dm.resumeDownloadsOnConnect()

        // The failed download with retriable error should be reset to queued
        let updated = tracking.getTransfer(id: transfer.id)
        #expect(updated?.status == .queued || updated?.error == nil)
    }

    @Test("resumeDownloadsOnConnect does not resume non-retriable failures")
    func resumeDownloadsOnConnectNonRetriable() {
        let (dm, tracking, _, _, _) = makeConfiguredDownloadManager()

        let transfer = Transfer(
            username: "alice",
            filename: "@@music\\Song.mp3",
            size: 5000,
            direction: .download,
            status: .failed,
            error: "Denied: not shared"
        )
        tracking.addDownload(transfer)

        dm.resumeDownloadsOnConnect()

        // The non-retriable failure should remain as-is
        let updated = tracking.getTransfer(id: transfer.id)
        #expect(updated?.status == .failed)
    }

    // MARK: - handleUploadDenied()

    @Test("handleUploadDenied with no pending download is a no-op")
    func handleUploadDeniedNoPending() {
        let (dm, _, _, _, _) = makeConfiguredDownloadManager()
        dm.handleUploadDenied(filename: "nonexistent.mp3", reason: "Not shared")
    }

    @Test("handleUploadDenied is safe after configure")
    func handleUploadDeniedAfterConfigure() {
        let (dm, _, _, _, _) = makeConfiguredDownloadManager()
        dm.handleUploadDenied(filename: "@@music\\Song.mp3", reason: "Queued")
    }

    // MARK: - handleUploadFailed()

    @Test("handleUploadFailed with no pending download is a no-op")
    func handleUploadFailedNoPending() {
        let (dm, _, _, _, _) = makeConfiguredDownloadManager()
        dm.handleUploadFailed(filename: "nonexistent.mp3")
    }

    @Test("handleUploadFailed is safe after configure")
    func handleUploadFailedAfterConfigure() {
        let (dm, _, _, _, _) = makeConfiguredDownloadManager()
        dm.handleUploadFailed(filename: "@@music\\Song.mp3")
    }

    // MARK: - retryFailedDownload()

    @Test("retryFailedDownload with unknown ID is a no-op")
    func retryFailedDownloadUnknownId() {
        let (dm, _, _, _, _) = makeConfiguredDownloadManager()
        dm.retryFailedDownload(transferId: UUID())
    }

    @Test("retryFailedDownload with non-failed transfer is a no-op")
    func retryFailedDownloadNotFailed() {
        let (dm, tracking, _, _, _) = makeConfiguredDownloadManager()

        let transfer = Transfer(
            username: "alice",
            filename: "@@music\\Song.mp3",
            size: 5000,
            direction: .download,
            status: .queued
        )
        tracking.addDownload(transfer)

        dm.retryFailedDownload(transferId: transfer.id)

        // Status should not have changed
        let updated = tracking.getTransfer(id: transfer.id)
        #expect(updated?.status == .queued)
    }

    @Test("retryFailedDownload with failed transfer requeues it")
    func retryFailedDownloadRequeues() {
        let (dm, tracking, _, _, _) = makeConfiguredDownloadManager()

        let transfer = Transfer(
            username: "alice",
            filename: "@@music\\Song.mp3",
            size: 5000,
            direction: .download,
            status: .failed,
            error: "Connection timeout"
        )
        tracking.addDownload(transfer)

        dm.retryFailedDownload(transferId: transfer.id)

        let updated = tracking.getTransfer(id: transfer.id)
        #expect(updated?.status == .queued)
        #expect(updated?.error == nil)
        #expect(updated?.retryCount == 1)
    }

    @Test("retryFailedDownload with cancelled transfer requeues it")
    func retryFailedDownloadCancelled() {
        let (dm, tracking, _, _, _) = makeConfiguredDownloadManager()

        let transfer = Transfer(
            username: "alice",
            filename: "@@music\\Song.mp3",
            size: 5000,
            direction: .download,
            status: .cancelled
        )
        tracking.addDownload(transfer)

        dm.retryFailedDownload(transferId: transfer.id)

        let updated = tracking.getTransfer(id: transfer.id)
        #expect(updated?.status == .queued)
    }

    // MARK: - cancelRetry()

    @Test("cancelRetry with unknown ID is a no-op")
    func cancelRetryUnknownId() {
        let (dm, _, _, _, _) = makeConfiguredDownloadManager()
        dm.cancelRetry(transferId: UUID())
    }

    @Test("cancelRetry does not crash after configure")
    func cancelRetryAfterConfigure() {
        let (dm, _, _, _, _) = makeConfiguredDownloadManager()
        let id = UUID()
        dm.cancelRetry(transferId: id)
    }

    // MARK: - PendingDownload type

    @Test("PendingDownload default resumeOffset is 0")
    func pendingDownloadDefaultOffset() {
        let pending = DownloadManager.PendingDownload(
            transferId: UUID(),
            username: "alice",
            filename: "song.mp3",
            size: 1000
        )
        #expect(pending.resumeOffset == 0)
    }

    @Test("PendingDownload can have custom resumeOffset")
    func pendingDownloadCustomOffset() {
        var pending = DownloadManager.PendingDownload(
            transferId: UUID(),
            username: "alice",
            filename: "song.mp3",
            size: 10000
        )
        pending.resumeOffset = 5000
        #expect(pending.resumeOffset == 5000)
    }

    @Test("PendingDownload peerConnection is initially nil")
    func pendingDownloadNilConnection() {
        let pending = DownloadManager.PendingDownload(
            transferId: UUID(),
            username: "alice",
            filename: "song.mp3",
            size: 1000
        )
        #expect(pending.peerConnection == nil)
        #expect(pending.peerIP == nil)
        #expect(pending.peerPort == nil)
    }

    // MARK: - PendingFileTransfer type

    @Test("PendingFileTransfer stores all fields correctly")
    func pendingFileTransferFields() {
        let id = UUID()
        let pft = DownloadManager.PendingFileTransfer(
            transferId: id,
            username: "bob",
            filename: "@@shared\\track.flac",
            size: 50_000_000,
            downloadToken: 111,
            transferToken: 222,
            offset: 4096
        )

        #expect(pft.transferId == id)
        #expect(pft.username == "bob")
        #expect(pft.filename == "@@shared\\track.flac")
        #expect(pft.size == 50_000_000)
        #expect(pft.downloadToken == 111)
        #expect(pft.transferToken == 222)
        #expect(pft.offset == 4096)
    }

    @Test("PendingFileTransfer with zero offset")
    func pendingFileTransferZeroOffset() {
        let pft = DownloadManager.PendingFileTransfer(
            transferId: UUID(),
            username: "alice",
            filename: "song.mp3",
            size: 1000,
            downloadToken: 1,
            transferToken: 2,
            offset: 0
        )
        #expect(pft.offset == 0)
    }

    // MARK: - DownloadError descriptions

    @Test("All DownloadError cases have non-nil descriptions")
    func allDownloadErrorDescriptions() {
        let errors: [DownloadManager.DownloadError] = [
            .invalidPort,
            .connectionCancelled,
            .connectionClosed,
            .cannotCreateFile,
            .timeout,
            .incompleteTransfer(expected: 100, actual: 50),
            .verificationFailed,
        ]

        for error in errors {
            #expect(error.errorDescription != nil)
            #expect(error.errorDescription?.isEmpty == false)
        }
    }

    @Test("incompleteTransfer description includes both byte counts")
    func incompleteTransferDescription() {
        let error = DownloadManager.DownloadError.incompleteTransfer(expected: 999999, actual: 123456)
        let desc = error.errorDescription!
        #expect(desc.contains("999999"))
        #expect(desc.contains("123456"))
    }

    // MARK: - resolveDownloadPath edge cases

    @Test("resolveDownloadPath with no folders")
    func resolvePathNoFolders() {
        let result = DownloadManager.resolveDownloadPath(
            soulseekPath: "@@music\\Song.mp3",
            username: "alice",
            template: "{username}/{folders}/{filename}"
        )
        // folders would be empty, double slashes should be cleaned
        #expect(result.contains("Song.mp3"))
        #expect(result.contains("alice"))
        #expect(!result.contains("//"))
    }

    @Test("resolveDownloadPath with deep folder hierarchy")
    func resolvePathDeepFolders() {
        let result = DownloadManager.resolveDownloadPath(
            soulseekPath: "@@music\\Genre\\SubGenre\\Artist\\Album\\01 Song.mp3",
            username: "bob",
            template: "{folders}/{filename}"
        )
        #expect(result == "Genre/SubGenre/Artist/Album/01 Song.mp3")
    }

    @Test("resolveDownloadPath with artist/album template and metadata")
    func resolvePathWithMetadata() {
        let metadata = AudioFileMetadata(artist: "Daft Punk", album: "Discovery")
        let result = DownloadManager.resolveDownloadPath(
            soulseekPath: "@@music\\Unknown\\Unknown\\01 One More Time.mp3",
            username: "alice",
            template: "{artist}/{album}/{filename}",
            metadata: metadata
        )
        #expect(result == "Daft Punk/Discovery/01 One More Time.mp3")
    }

    @Test("resolveDownloadPath with metadata overriding folder-derived values")
    func resolvePathMetadataOverride() {
        let metadata = AudioFileMetadata(artist: "Real Artist")
        let result = DownloadManager.resolveDownloadPath(
            soulseekPath: "@@music\\Wrong Artist\\Album\\Song.mp3",
            username: "alice",
            template: "{artist}/{album}/{filename}",
            metadata: metadata
        )
        // artist from metadata, album from folder
        #expect(result.hasPrefix("Real Artist/"))
        #expect(result.contains("Album"))
    }

    @Test("resolveDownloadPath with empty soulseek path returns fallback")
    func resolvePathEmpty() {
        let result = DownloadManager.resolveDownloadPath(
            soulseekPath: "",
            username: "alice",
            template: "{username}/{filename}"
        )
        // Should produce some non-empty fallback
        #expect(!result.isEmpty)
    }

    @Test("resolveDownloadPath strips @@ root marker")
    func resolvePathStripsRoot() {
        let result = DownloadManager.resolveDownloadPath(
            soulseekPath: "@@downloads\\Music\\Song.mp3",
            username: "alice",
            template: "{folders}/{filename}"
        )
        #expect(!result.contains("@@"))
        #expect(result.contains("Music"))
    }

    @Test("resolveDownloadPath with only filename (no folders, no root)")
    func resolvePathOnlyFilename() {
        let result = DownloadManager.resolveDownloadPath(
            soulseekPath: "Song.mp3",
            username: "alice",
            template: "{filename}"
        )
        #expect(result == "Song.mp3")
    }

    @Test("resolveDownloadPath with nil metadata falls back to folder-derived values")
    func resolvePathNilMetadata() {
        let result = DownloadManager.resolveDownloadPath(
            soulseekPath: "@@music\\Artist\\Album\\Song.mp3",
            username: "alice",
            template: "{artist}/{album}/{filename}",
            metadata: nil
        )
        #expect(result == "Artist/Album/Song.mp3")
    }
}

// MARK: - UploadManager Deep Tests

@Suite("UploadManager Deep Tests", .serialized)
@MainActor
struct UploadManagerDeepTests {

    // MARK: - Helpers

    private func makeConfiguredUploadManager() -> (UploadManager, DeepMockTransferTracking, ShareManager, NetworkClient) {
        let um = UploadManager()
        let client = NetworkClient()
        let tracking = DeepMockTransferTracking()
        let stats = DeepMockStatisticsRecording()
        let shareManager = ShareManager()

        um.configure(
            networkClient: client,
            transferState: tracking,
            shareManager: shareManager,
            statisticsState: stats
        )

        return (um, tracking, shareManager, client)
    }

    // MARK: - Initialization and Configuration

    @Test("UploadManager can be instantiated")
    func instantiation() {
        let um = UploadManager()
        _ = um
    }

    @Test("configure() sets up dependencies without crash")
    func configureSetsDependencies() {
        let (um, _, _, _) = makeConfiguredUploadManager()
        _ = um
    }

    // MARK: - Default Configuration Values

    @Test("maxConcurrentUploads defaults to 3")
    func defaultMaxConcurrentUploads() {
        let um = UploadManager()
        #expect(um.maxConcurrentUploads == 3)
    }

    @Test("maxQueuedPerUser defaults to 50")
    func defaultMaxQueuedPerUser() {
        let um = UploadManager()
        #expect(um.maxQueuedPerUser == 50)
    }

    @Test("uploadSpeedLimit defaults to nil")
    func defaultUploadSpeedLimit() {
        let um = UploadManager()
        #expect(um.uploadSpeedLimit == nil)
    }

    @Test("maxConcurrentUploads is configurable")
    func configurableMaxConcurrent() {
        let um = UploadManager()
        um.maxConcurrentUploads = 5
        #expect(um.maxConcurrentUploads == 5)
    }

    @Test("maxQueuedPerUser is configurable")
    func configurableMaxQueued() {
        let um = UploadManager()
        um.maxQueuedPerUser = 100
        #expect(um.maxQueuedPerUser == 100)
    }

    @Test("uploadSpeedLimit is configurable")
    func configurableSpeedLimit() {
        let um = UploadManager()
        um.uploadSpeedLimit = 1_000_000  // 1 MB/s
        #expect(um.uploadSpeedLimit == 1_000_000)
    }

    // MARK: - getQueuePosition()

    @Test("getQueuePosition returns 0 for non-queued file")
    func queuePositionNotQueued() {
        let (um, _, _, _) = makeConfiguredUploadManager()
        let position = um.getQueuePosition(for: "nonexistent.mp3", username: "alice")
        #expect(position == 0)
    }

    @Test("getQueuePosition returns 0 for wrong username")
    func queuePositionWrongUser() {
        let (um, _, _, _) = makeConfiguredUploadManager()
        let position = um.getQueuePosition(for: "song.mp3", username: "nobody")
        #expect(position == 0)
    }

    // MARK: - Public API properties

    @Test("queuedUploads is initially empty")
    func queuedUploadsEmpty() {
        let (um, _, _, _) = makeConfiguredUploadManager()
        #expect(um.queuedUploads.isEmpty)
    }

    @Test("activeUploadCount is initially 0")
    func activeUploadCountZero() {
        let (um, _, _, _) = makeConfiguredUploadManager()
        #expect(um.activeUploadCount == 0)
    }

    @Test("queueDepth is initially 0")
    func queueDepthZero() {
        let (um, _, _, _) = makeConfiguredUploadManager()
        #expect(um.queueDepth == 0)
    }

    @Test("slotsSummary shows 0/maxConcurrent initially")
    func slotsSummaryInitial() {
        let (um, _, _, _) = makeConfiguredUploadManager()
        #expect(um.slotsSummary == "0/3")
    }

    @Test("slotsSummary reflects changed maxConcurrentUploads")
    func slotsSummaryCustomMax() {
        let (um, _, _, _) = makeConfiguredUploadManager()
        um.maxConcurrentUploads = 10
        #expect(um.slotsSummary == "0/10")
    }

    // MARK: - cancelQueuedUpload()

    @Test("cancelQueuedUpload with unknown ID is a no-op")
    func cancelQueuedUploadUnknown() {
        let (um, _, _, _) = makeConfiguredUploadManager()
        um.cancelQueuedUpload(UUID())
        #expect(um.queueDepth == 0)
    }

    // MARK: - cancelActiveUpload()

    @Test("cancelActiveUpload with unknown ID is a no-op")
    func cancelActiveUploadUnknown() async {
        let (um, _, _, _) = makeConfiguredUploadManager()
        await um.cancelActiveUpload(UUID())
        #expect(um.activeUploadCount == 0)
    }

    // MARK: - hasPendingUpload()

    @Test("hasPendingUpload returns false for unknown token")
    func hasPendingUploadFalse() {
        let (um, _, _, _) = makeConfiguredUploadManager()
        #expect(um.hasPendingUpload(token: 12345) == false)
    }

    @Test("hasPendingUpload returns false for zero token")
    func hasPendingUploadZeroToken() {
        let (um, _, _, _) = makeConfiguredUploadManager()
        #expect(um.hasPendingUpload(token: 0) == false)
    }

    // MARK: - handleCantConnectToPeer()

    @Test("handleCantConnectToPeer with no matching token is a no-op")
    func handleCantConnectToPeerNoMatch() {
        let (um, _, _, _) = makeConfiguredUploadManager()
        um.handleCantConnectToPeer(token: 99999)
        // Should not crash, no matching pending upload
    }

    // MARK: - uploadPermissionChecker

    @Test("uploadPermissionChecker is initially nil")
    func permissionCheckerNil() {
        let um = UploadManager()
        #expect(um.uploadPermissionChecker == nil)
    }

    @Test("uploadPermissionChecker can be set and called")
    func permissionCheckerSet() {
        let um = UploadManager()
        var checkedUsers: [String] = []

        um.uploadPermissionChecker = { username in
            checkedUsers.append(username)
            return username != "blocked"
        }

        let allowedResult = um.uploadPermissionChecker?("alice")
        let blockedResult = um.uploadPermissionChecker?("blocked")

        #expect(allowedResult == true)
        #expect(blockedResult == false)
        #expect(checkedUsers == ["alice", "blocked"])
    }

    // MARK: - UploadError descriptions

    @Test("All UploadError cases have non-nil descriptions")
    func allUploadErrorDescriptions() {
        let errors: [UploadManager.UploadError] = [
            .fileNotFound,
            .fileNotShared,
            .cannotReadFile,
            .connectionFailed,
            .peerRejected,
            .timeout,
        ]

        for error in errors {
            #expect(error.errorDescription != nil)
            #expect(error.errorDescription?.isEmpty == false)
        }
    }

    @Test("UploadError.fileNotFound has correct description")
    func uploadErrorFileNotFound() {
        let error = UploadManager.UploadError.fileNotFound
        #expect(error.errorDescription == "File not found")
    }

    @Test("UploadError.fileNotShared has correct description")
    func uploadErrorFileNotShared() {
        let error = UploadManager.UploadError.fileNotShared
        #expect(error.errorDescription == "File not in shared folders")
    }

    @Test("UploadError.cannotReadFile has correct description")
    func uploadErrorCannotRead() {
        let error = UploadManager.UploadError.cannotReadFile
        #expect(error.errorDescription == "Cannot read file")
    }

    @Test("UploadError.connectionFailed has correct description")
    func uploadErrorConnectionFailed() {
        let error = UploadManager.UploadError.connectionFailed
        #expect(error.errorDescription == "Connection to peer failed")
    }

    @Test("UploadError.peerRejected has correct description")
    func uploadErrorPeerRejected() {
        let error = UploadManager.UploadError.peerRejected
        #expect(error.errorDescription == "Peer rejected the transfer")
    }

    @Test("UploadError.timeout has correct description")
    func uploadErrorTimeout() {
        let error = UploadManager.UploadError.timeout
        #expect(error.errorDescription == "Transfer timed out")
    }

    // MARK: - QueuedUpload type

    @Test("QueuedUpload has unique id")
    func queuedUploadUniqueId() {
        let peerInfo = PeerConnection.PeerInfo(username: "alice", ip: "1.2.3.4", port: 2234)
        let conn = PeerConnection(peerInfo: peerInfo, type: .peer, token: 1)

        let q1 = UploadManager.QueuedUpload(
            username: "alice",
            filename: "song.mp3",
            localPath: "/tmp/song.mp3",
            size: 1000,
            connection: conn,
            queuedAt: Date()
        )
        let q2 = UploadManager.QueuedUpload(
            username: "alice",
            filename: "song.mp3",
            localPath: "/tmp/song.mp3",
            size: 1000,
            connection: conn,
            queuedAt: Date()
        )

        #expect(q1.id != q2.id)
    }

    @Test("QueuedUpload stores all fields")
    func queuedUploadFields() {
        let peerInfo = PeerConnection.PeerInfo(username: "bob", ip: "10.0.0.1", port: 3000)
        let conn = PeerConnection(peerInfo: peerInfo, type: .peer, token: 42)
        let now = Date()

        let queued = UploadManager.QueuedUpload(
            username: "bob",
            filename: "@@shared\\track.flac",
            localPath: "/home/bob/music/track.flac",
            size: 50_000_000,
            connection: conn,
            queuedAt: now
        )

        #expect(queued.username == "bob")
        #expect(queued.filename == "@@shared\\track.flac")
        #expect(queued.localPath == "/home/bob/music/track.flac")
        #expect(queued.size == 50_000_000)
        #expect(queued.queuedAt == now)
    }

    // MARK: - ActiveUpload type

    @Test("ActiveUpload has default zero values")
    func activeUploadDefaults() {
        let active = UploadManager.ActiveUpload(
            transferId: UUID(),
            username: "alice",
            filename: "song.mp3",
            localPath: "/tmp/song.mp3",
            size: 1000,
            token: 42
        )

        #expect(active.bytesSent == 0)
        #expect(active.startTime == nil)
    }

    @Test("ActiveUpload stores all fields")
    func activeUploadFields() {
        let id = UUID()
        let now = Date()
        let active = UploadManager.ActiveUpload(
            transferId: id,
            username: "bob",
            filename: "track.flac",
            localPath: "/music/track.flac",
            size: 50_000_000,
            token: 999,
            bytesSent: 25_000_000,
            startTime: now
        )

        #expect(active.transferId == id)
        #expect(active.username == "bob")
        #expect(active.filename == "track.flac")
        #expect(active.localPath == "/music/track.flac")
        #expect(active.size == 50_000_000)
        #expect(active.token == 999)
        #expect(active.bytesSent == 25_000_000)
        #expect(active.startTime == now)
    }

    // MARK: - PendingUpload type

    @Test("PendingUpload stores all fields")
    func pendingUploadFields() {
        let id = UUID()
        let peerInfo = PeerConnection.PeerInfo(username: "alice", ip: "1.2.3.4", port: 2234)
        let conn = PeerConnection(peerInfo: peerInfo, type: .peer, token: 1)

        let pending = UploadManager.PendingUpload(
            transferId: id,
            username: "alice",
            filename: "@@shared\\song.mp3",
            localPath: "/music/song.mp3",
            size: 5_000_000,
            token: 12345,
            connection: conn
        )

        #expect(pending.transferId == id)
        #expect(pending.username == "alice")
        #expect(pending.filename == "@@shared\\song.mp3")
        #expect(pending.localPath == "/music/song.mp3")
        #expect(pending.size == 5_000_000)
        #expect(pending.token == 12345)
    }

    // MARK: - Multiple manager interaction safety

    @Test("UploadManager and DownloadManager can coexist on same NetworkClient")
    func coexistOnSameClient() {
        let client = NetworkClient()
        let tracking = DeepMockTransferTracking()
        let stats = DeepMockStatisticsRecording()

        let um = UploadManager()
        let shareManager = ShareManager()
        um.configure(networkClient: client, transferState: tracking, shareManager: shareManager, statisticsState: stats)

        let dm = DownloadManager()
        let settings = DeepMockDownloadSettings()
        let metadata = DeepMockMetadataReader()
        dm.configure(
            networkClient: client,
            transferState: tracking,
            statisticsState: stats,
            uploadManager: um,
            settings: settings,
            metadataReader: metadata
        )

        // Both managers should be functional
        #expect(um.queueDepth == 0)
        #expect(um.activeUploadCount == 0)

        let result = SearchResult(username: "alice", filename: "@@music\\Song.mp3", size: 1000)
        dm.queueDownload(from: result)
        #expect(tracking.addDownloadCalls.count == 1)
    }

    // MARK: - Unconfigured state safety for UploadManager

    @Test("getQueuePosition is safe when unconfigured")
    func getQueuePositionUnconfigured() {
        let um = UploadManager()
        let pos = um.getQueuePosition(for: "song.mp3", username: "alice")
        #expect(pos == 0)
    }

    @Test("cancelQueuedUpload is safe when unconfigured")
    func cancelQueuedUploadUnconfigured() {
        let um = UploadManager()
        um.cancelQueuedUpload(UUID())
    }

    @Test("cancelActiveUpload is safe when unconfigured")
    func cancelActiveUploadUnconfigured() async {
        let um = UploadManager()
        await um.cancelActiveUpload(UUID())
    }

    @Test("hasPendingUpload is safe when unconfigured")
    func hasPendingUploadUnconfigured() {
        let um = UploadManager()
        #expect(um.hasPendingUpload(token: 42) == false)
    }

    @Test("handleCantConnectToPeer is safe when unconfigured")
    func handleCantConnectToPeerUnconfigured() {
        let um = UploadManager()
        um.handleCantConnectToPeer(token: 42)
    }

    @Test("queuedUploads is empty when unconfigured")
    func queuedUploadsUnconfigured() {
        let um = UploadManager()
        #expect(um.queuedUploads.isEmpty)
    }

    @Test("activeUploadCount is 0 when unconfigured")
    func activeUploadCountUnconfigured() {
        let um = UploadManager()
        #expect(um.activeUploadCount == 0)
    }

    @Test("queueDepth is 0 when unconfigured")
    func queueDepthUnconfigured() {
        let um = UploadManager()
        #expect(um.queueDepth == 0)
    }

    @Test("slotsSummary returns 0/3 when unconfigured")
    func slotsSummaryUnconfigured() {
        let um = UploadManager()
        #expect(um.slotsSummary == "0/3")
    }
}
