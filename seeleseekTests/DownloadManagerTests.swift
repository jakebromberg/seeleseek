import Testing
import Foundation
@testable import SeeleseekCore
@testable import seeleseek

// MARK: - Mock Implementations

@MainActor
final class MockTransferTracking: TransferTracking {
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
final class MockStatisticsRecording: StatisticsRecording {
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
final class MockDownloadSettings: DownloadSettingsProviding {
    var activeDownloadTemplate: String = "{username}/{folders}/{filename}"
    var setFolderIcons: Bool = false
}

actor MockMetadataReader: MetadataReading {
    private(set) var extractMetadataCalls: [URL] = []
    private(set) var extractArtworkCalls: [URL] = []
    private(set) var applyArtworkCalls: [URL] = []

    var metadataToReturn: AudioFileMetadata?
    var artworkToReturn: Data?
    var applyArtworkResult: Bool = false

    func setMetadataToReturn(_ metadata: AudioFileMetadata?) {
        metadataToReturn = metadata
    }

    func setArtworkToReturn(_ data: Data?) {
        artworkToReturn = data
    }

    func setApplyArtworkResult(_ result: Bool) {
        applyArtworkResult = result
    }

    func extractAudioMetadata(from url: URL) async -> AudioFileMetadata? {
        extractMetadataCalls.append(url)
        return metadataToReturn
    }

    func extractArtwork(from url: URL) async -> Data? {
        extractArtworkCalls.append(url)
        return artworkToReturn
    }

    func applyArtworkAsFolderIcon(for directory: URL) async -> Bool {
        applyArtworkCalls.append(directory)
        return applyArtworkResult
    }
}

// MARK: - DownloadManager Tests

@Suite("DownloadManager Tests", .serialized)
struct DownloadManagerTests {

    // MARK: - Initialization

    @Test("DownloadManager can be instantiated")
    @MainActor func instantiation() {
        let manager = DownloadManager()
        _ = manager  // Verify no crash
    }

    // MARK: - DownloadError

    @Test("DownloadError.invalidPort has description")
    func invalidPortDescription() {
        let error = DownloadManager.DownloadError.invalidPort
        #expect(error.errorDescription == "Invalid port number")
    }

    @Test("DownloadError.connectionCancelled has description")
    func connectionCancelledDescription() {
        let error = DownloadManager.DownloadError.connectionCancelled
        #expect(error.errorDescription == "Connection was cancelled")
    }

    @Test("DownloadError.connectionClosed has description")
    func connectionClosedDescription() {
        let error = DownloadManager.DownloadError.connectionClosed
        #expect(error.errorDescription == "Connection closed unexpectedly")
    }

    @Test("DownloadError.cannotCreateFile has description")
    func cannotCreateFileDescription() {
        let error = DownloadManager.DownloadError.cannotCreateFile
        #expect(error.errorDescription == "Cannot create download file")
    }

    @Test("DownloadError.timeout has description")
    func timeoutDescription() {
        let error = DownloadManager.DownloadError.timeout
        #expect(error.errorDescription == "Connection timed out")
    }

    @Test("DownloadError.incompleteTransfer includes byte counts")
    func incompleteTransferDescription() {
        let error = DownloadManager.DownloadError.incompleteTransfer(expected: 1000, actual: 500)
        #expect(error.errorDescription?.contains("500") == true)
        #expect(error.errorDescription?.contains("1000") == true)
    }

    @Test("DownloadError.verificationFailed has description")
    func verificationFailedDescription() {
        let error = DownloadManager.DownloadError.verificationFailed
        #expect(error.errorDescription == "File verification failed")
    }

    // MARK: - PendingDownload Type

    @Test("PendingDownload stores all fields")
    @MainActor func pendingDownloadConstruction() {
        let transferId = UUID()
        let pending = DownloadManager.PendingDownload(
            transferId: transferId,
            username: "alice",
            filename: "@@music\\Artist\\Song.mp3",
            size: 5_000_000
        )

        #expect(pending.transferId == transferId)
        #expect(pending.username == "alice")
        #expect(pending.filename == "@@music\\Artist\\Song.mp3")
        #expect(pending.size == 5_000_000)
        #expect(pending.peerConnection == nil)
        #expect(pending.peerIP == nil)
        #expect(pending.peerPort == nil)
        #expect(pending.resumeOffset == 0)
    }

    // MARK: - PendingFileTransfer Type

    @Test("PendingFileTransfer stores all fields")
    @MainActor func pendingFileTransferConstruction() {
        let transferId = UUID()
        let pending = DownloadManager.PendingFileTransfer(
            transferId: transferId,
            username: "bob",
            filename: "@@music\\Artist\\Track.flac",
            size: 30_000_000,
            downloadToken: 42,
            transferToken: 99,
            offset: 1024
        )

        #expect(pending.transferId == transferId)
        #expect(pending.username == "bob")
        #expect(pending.filename == "@@music\\Artist\\Track.flac")
        #expect(pending.size == 30_000_000)
        #expect(pending.downloadToken == 42)
        #expect(pending.transferToken == 99)
        #expect(pending.offset == 1024)
    }

    // MARK: - Unconfigured State Safety

    @Test("handleUploadDenied is safe when unconfigured")
    @MainActor func handleUploadDeniedUnconfigured() {
        let manager = DownloadManager()
        // Should not crash even without configure() being called
        manager.handleUploadDenied(filename: "test.mp3", reason: "Denied")
    }

    @Test("handleUploadFailed is safe when unconfigured")
    @MainActor func handleUploadFailedUnconfigured() {
        let manager = DownloadManager()
        // Should not crash even without configure() being called
        manager.handleUploadFailed(filename: "test.mp3")
    }

    @Test("retryFailedDownload is safe when unconfigured")
    @MainActor func retryFailedDownloadUnconfigured() {
        let manager = DownloadManager()
        // Should not crash - guards on transferState being nil
        manager.retryFailedDownload(transferId: UUID())
    }

    @Test("cancelRetry is safe when unconfigured")
    @MainActor func cancelRetryUnconfigured() {
        let manager = DownloadManager()
        // Should not crash
        manager.cancelRetry(transferId: UUID())
    }

    @Test("resumeDownloadsOnConnect is safe when unconfigured")
    @MainActor func resumeDownloadsOnConnectUnconfigured() {
        let manager = DownloadManager()
        // Should not crash - guards on transferState being nil
        manager.resumeDownloadsOnConnect()
    }

    @Test("queueDownload is safe when unconfigured")
    @MainActor func queueDownloadUnconfigured() {
        let manager = DownloadManager()
        let result = SearchResult(username: "alice", filename: "@@music\\Song.mp3", size: 1000)
        // Should not crash - guards on transferState and networkClient being nil
        manager.queueDownload(from: result)
    }

    // MARK: - Mock Protocol Tests

    @Test("MockTransferTracking records addDownload calls")
    @MainActor func mockTransferTrackingAddDownload() {
        let mock = MockTransferTracking()
        let transfer = Transfer(username: "alice", filename: "song.mp3", size: 1000, direction: .download)

        mock.addDownload(transfer)

        #expect(mock.addDownloadCalls.count == 1)
        #expect(mock.addDownloadCalls[0].username == "alice")
        #expect(mock.downloads.count == 1)
    }

    @Test("MockTransferTracking records addUpload calls")
    @MainActor func mockTransferTrackingAddUpload() {
        let mock = MockTransferTracking()
        let transfer = Transfer(username: "bob", filename: "track.flac", size: 2000, direction: .upload)

        mock.addUpload(transfer)

        #expect(mock.addUploadCalls.count == 1)
        #expect(mock.addUploadCalls[0].username == "bob")
        #expect(mock.uploads.count == 1)
    }

    @Test("MockTransferTracking updateTransfer modifies stored download")
    @MainActor func mockTransferTrackingUpdate() {
        let mock = MockTransferTracking()
        let transfer = Transfer(username: "alice", filename: "song.mp3", size: 1000, direction: .download)
        mock.addDownload(transfer)

        mock.updateTransfer(id: transfer.id) { t in
            t.status = .transferring
            t.bytesTransferred = 500
        }

        #expect(mock.updateTransferCallIds.count == 1)
        let updated = mock.getTransfer(id: transfer.id)
        #expect(updated?.status == .transferring)
        #expect(updated?.bytesTransferred == 500)
    }

    @Test("MockTransferTracking getTransfer returns nil for unknown ID")
    @MainActor func mockTransferTrackingGetUnknown() {
        let mock = MockTransferTracking()
        let result = mock.getTransfer(id: UUID())
        #expect(result == nil)
        #expect(mock.getTransferCalls.count == 1)
    }

    @Test("MockStatisticsRecording records transfers")
    @MainActor func mockStatisticsRecording() {
        let mock = MockStatisticsRecording()
        mock.recordTransfer(filename: "song.mp3", username: "alice", size: 5000, duration: 10.0, isDownload: true)

        #expect(mock.recordedTransfers.count == 1)
        #expect(mock.recordedTransfers[0].filename == "song.mp3")
        #expect(mock.recordedTransfers[0].username == "alice")
        #expect(mock.recordedTransfers[0].size == 5000)
        #expect(mock.recordedTransfers[0].duration == 10.0)
        #expect(mock.recordedTransfers[0].isDownload == true)
    }

    @Test("MockDownloadSettings has configurable template")
    @MainActor func mockDownloadSettings() {
        let mock = MockDownloadSettings()
        #expect(mock.activeDownloadTemplate == "{username}/{folders}/{filename}")

        mock.activeDownloadTemplate = "{artist}/{album}/{filename}"
        #expect(mock.activeDownloadTemplate == "{artist}/{album}/{filename}")
    }

    @Test("MockDownloadSettings has configurable folder icons setting")
    @MainActor func mockDownloadSettingsFolderIcons() {
        let mock = MockDownloadSettings()
        #expect(mock.setFolderIcons == false)

        mock.setFolderIcons = true
        #expect(mock.setFolderIcons == true)
    }

    @Test("MockMetadataReader records calls and returns configured values")
    func mockMetadataReader() async {
        let mock = MockMetadataReader()
        let testURL = URL(fileURLWithPath: "/tmp/test.mp3")

        // Test with no configured return value
        let metadata = await mock.extractAudioMetadata(from: testURL)
        #expect(metadata == nil)
        let callCount1 = await mock.extractMetadataCalls.count
        #expect(callCount1 == 1)

        // Configure and test again
        await mock.setMetadataToReturn(AudioFileMetadata(artist: "Test Artist", album: "Test Album"))
        let metadata2 = await mock.extractAudioMetadata(from: testURL)
        #expect(metadata2?.artist == "Test Artist")
        #expect(metadata2?.album == "Test Album")
    }

    @Test("MockMetadataReader extractArtwork returns configured data")
    func mockMetadataReaderArtwork() async {
        let mock = MockMetadataReader()
        let testURL = URL(fileURLWithPath: "/tmp/test.mp3")

        let artwork = await mock.extractArtwork(from: testURL)
        #expect(artwork == nil)

        await mock.setArtworkToReturn(Data([0xFF, 0xD8, 0xFF]))
        let artwork2 = await mock.extractArtwork(from: testURL)
        #expect(artwork2 == Data([0xFF, 0xD8, 0xFF]))
        let callCount = await mock.extractArtworkCalls.count
        #expect(callCount == 2)
    }

    @Test("MockMetadataReader applyArtworkAsFolderIcon returns configured result")
    func mockMetadataReaderApplyArtwork() async {
        let mock = MockMetadataReader()
        let testURL = URL(fileURLWithPath: "/tmp/album")

        let result = await mock.applyArtworkAsFolderIcon(for: testURL)
        #expect(result == false)

        await mock.setApplyArtworkResult(true)
        let result2 = await mock.applyArtworkAsFolderIcon(for: testURL)
        #expect(result2 == true)
        let callCount = await mock.applyArtworkCalls.count
        #expect(callCount == 2)
    }

    // MARK: - AudioFileMetadata

    @Test("AudioFileMetadata initializes with all nil by default")
    func audioFileMetadataDefaults() {
        let metadata = AudioFileMetadata()
        #expect(metadata.artist == nil)
        #expect(metadata.album == nil)
        #expect(metadata.title == nil)
    }

    @Test("AudioFileMetadata initializes with provided values")
    func audioFileMetadataWithValues() {
        let metadata = AudioFileMetadata(artist: "Daft Punk", album: "Discovery", title: "One More Time")
        #expect(metadata.artist == "Daft Punk")
        #expect(metadata.album == "Discovery")
        #expect(metadata.title == "One More Time")
    }

    @Test("AudioFileMetadata supports partial initialization")
    func audioFileMetadataPartial() {
        let metadata = AudioFileMetadata(artist: "Radiohead")
        #expect(metadata.artist == "Radiohead")
        #expect(metadata.album == nil)
        #expect(metadata.title == nil)
    }

    // MARK: - ConnectionStatus Enum

    @Test("ConnectionStatus has all expected cases")
    func connectionStatusCases() {
        let allCases = ConnectionStatus.allCases
        #expect(allCases.contains(.disconnected))
        #expect(allCases.contains(.connecting))
        #expect(allCases.contains(.connected))
        #expect(allCases.contains(.reconnecting))
        #expect(allCases.contains(.error))
        #expect(allCases.count == 5)
    }

    @Test("ConnectionStatus raw values are strings")
    func connectionStatusRawValues() {
        #expect(ConnectionStatus.disconnected.rawValue == "disconnected")
        #expect(ConnectionStatus.connecting.rawValue == "connecting")
        #expect(ConnectionStatus.connected.rawValue == "connected")
        #expect(ConnectionStatus.reconnecting.rawValue == "reconnecting")
        #expect(ConnectionStatus.error.rawValue == "error")
    }
}
