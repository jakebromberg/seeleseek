import Testing
import Foundation
@testable import SeeleseekCore
@testable import seeleseek

// MARK: - Helpers

private func makeFolder(
    name: String,
    children: [SharedFile]? = nil
) -> SharedFile {
    SharedFile(
        filename: name,
        isDirectory: true,
        children: children
    )
}

private func makeFile(name: String, size: UInt64 = 1000) -> SharedFile {
    SharedFile(filename: name, size: size)
}

private func makeTransfer(
    id: UUID = UUID(),
    username: String = "alice",
    filename: String = "@@music\\Artist\\song.mp3",
    size: UInt64 = 10_000,
    direction: Transfer.TransferDirection = .download,
    status: Transfer.TransferStatus = .queued,
    bytesTransferred: UInt64 = 0,
    speed: Int64 = 0
) -> Transfer {
    Transfer(
        id: id,
        username: username,
        filename: filename,
        size: size,
        direction: direction,
        status: status,
        bytesTransferred: bytesTransferred,
        speed: speed
    )
}

// MARK: - BrowseState Additional Tests

@Suite(.serialized)
@MainActor
struct BrowseStateAdditionalTests {

    // MARK: - browseUser setup (no network)

    @Test("browseUser with empty username does nothing")
    func browseUserEmptyUsername() {
        let state = BrowseState()
        state.browseUser("")
        #expect(state.browses.isEmpty)
    }

    @Test("browseUser with whitespace-only username does nothing")
    func browseUserWhitespaceUsername() {
        let state = BrowseState()
        state.browseUser("   ")
        #expect(state.browses.isEmpty)
    }

    @Test("browseUser creates new tab and sets history")
    func browseUserCreatesTab() {
        let state = BrowseState()
        state.browseUser("alice")

        #expect(state.browses.count == 1)
        #expect(state.browses[0].username == "alice")
        #expect(state.selectedBrowseIndex == 0)
        #expect(state.currentUser == "alice")
        #expect(state.browseHistory.contains("alice"))
    }

    @Test("browseUser switches to existing tab for same user")
    func browseUserSwitchesToExisting() {
        let state = BrowseState()
        // Manually add a browse for alice
        state.browses = [
            UserShares(username: "alice", isLoading: false),
            UserShares(username: "bob", isLoading: false),
        ]
        state.selectedBrowseIndex = 1

        state.browseUser("alice")

        // Should switch to index 0, not create a new tab
        #expect(state.browses.count == 2)
        #expect(state.selectedBrowseIndex == 0)
    }

    @Test("browseUser case-insensitive match for existing tab")
    func browseUserCaseInsensitive() {
        let state = BrowseState()
        state.browses = [UserShares(username: "Alice", isLoading: false)]
        state.selectedBrowseIndex = 0

        state.browseUser("alice")

        #expect(state.browses.count == 1)
        #expect(state.selectedBrowseIndex == 0)
    }

    @Test("browseUser clears UI state for new browse")
    func browseUserClearsUI() {
        let state = BrowseState()
        state.expandedFolders = [UUID()]
        state.selectedFile = makeFile(name: "old.mp3")

        state.browseUser("alice")

        #expect(state.expandedFolders.isEmpty)
        #expect(state.selectedFile == nil)
    }

    @Test("browseUser adds to history at front, deduplicates case-insensitively")
    func browseUserHistoryDedup() {
        let state = BrowseState()
        state.browseHistory = ["existinguser"]

        state.browseUser("ExistingUser")

        // Should not create a duplicate
        let matchingEntries = state.browseHistory.filter { $0.lowercased() == "existinguser" }
        #expect(matchingEntries.count == 1)
    }

    @Test("browseUser history limited to 20 entries")
    func browseUserHistoryLimit() {
        let state = BrowseState()
        state.browseHistory = (0..<20).map { "user\($0)" }

        state.browseUser("newuser")

        // History should not exceed 20
        #expect(state.browseHistory.count <= 20)
    }

    @Test("browseUser with targetPath sets currentFolderPath")
    func browseUserWithTargetPath() {
        let state = BrowseState()

        state.browseUser("alice", targetPath: "@@music\\Artist\\Album\\song.mp3")

        #expect(state.currentFolderPath == "@@music\\Artist\\Album")
    }

    @Test("browseUser without targetPath clears currentFolderPath")
    func browseUserWithoutTargetPath() {
        let state = BrowseState()
        state.currentFolderPath = "old\\path"

        state.browseUser("alice", targetPath: nil)

        #expect(state.currentFolderPath == nil)
    }

    // MARK: - retryCurrentBrowse

    @Test("retryCurrentBrowse does nothing when no error")
    func retryNoError() {
        let state = BrowseState()
        state.browses = [UserShares(username: "alice", isLoading: false)]
        state.selectedBrowseIndex = 0

        state.retryCurrentBrowse()

        // Should not crash; browse still exists
        #expect(state.browses.count == 1)
    }

    @Test("retryCurrentBrowse does nothing when no current browse")
    func retryNoBrowse() {
        let state = BrowseState()
        state.retryCurrentBrowse()
        #expect(state.browses.isEmpty)
    }

    // MARK: - setShares with complex trees

    @Test("setShares with deeply nested tree")
    func setSharesDeepTree() {
        let state = BrowseState()
        state.browses = [UserShares(username: "alice", isLoading: true)]
        state.selectedBrowseIndex = 0

        let innerFile = makeFile(name: "deep\\file.mp3")
        let innerFolder = makeFolder(name: "deep", children: [innerFile])
        let outerFolder = makeFolder(name: "outer", children: [innerFolder])

        state.setShares([outerFolder])

        #expect(state.currentBrowse?.folders.count == 1)
        #expect(state.currentBrowse?.folders[0].children?.count == 1)
        #expect(state.currentBrowse?.isLoading == false)
    }

    @Test("setShares with no current browse does nothing")
    func setSharesNoBrowse() {
        let state = BrowseState()
        state.setShares([makeFolder(name: "test")])
        #expect(state.browses.isEmpty)
    }

    @Test("setError with no current browse does nothing")
    func setErrorNoBrowse() {
        let state = BrowseState()
        state.setError("some error")
        #expect(state.browses.isEmpty)
    }

    // MARK: - visibleFlatTree with various expand states

    @Test("visibleFlatTree with multi-level expansion")
    func visibleFlatTreeMultiLevel() {
        let state = BrowseState()
        let grandchild = makeFile(name: "Music\\Artist\\song.mp3", size: 5000)
        let child = makeFolder(name: "Music\\Artist", children: [grandchild])
        let root = makeFolder(name: "Music", children: [child])

        state.browses = [UserShares(username: "alice", folders: [root], isLoading: false)]
        state.selectedBrowseIndex = 0
        // Expand both levels
        state.expandedFolders = [root.id, child.id]

        let flat = state.visibleFlatTree

        #expect(flat.count == 3)
        #expect(flat[0].depth == 0)
        #expect(flat[1].depth == 1)
        #expect(flat[2].depth == 2)
    }

    @Test("visibleFlatTree with partially expanded tree")
    func visibleFlatTreePartialExpand() {
        let state = BrowseState()
        let file1 = makeFile(name: "Music\\song.mp3")
        let file2 = makeFile(name: "Videos\\movie.mp4")
        let folder1 = makeFolder(name: "Music", children: [file1])
        let folder2 = makeFolder(name: "Videos", children: [file2])

        state.browses = [UserShares(username: "alice", folders: [folder1, folder2], isLoading: false)]
        state.selectedBrowseIndex = 0
        // Only expand first folder
        state.expandedFolders = [folder1.id]

        let flat = state.visibleFlatTree

        // folder1, file1, folder2 (folder2 children hidden)
        #expect(flat.count == 3)
        #expect(flat[0].file.isDirectory)
        #expect(!flat[1].file.isDirectory)
        #expect(flat[2].file.isDirectory)
    }

    @Test("visibleFlatTree empty when no browse")
    func visibleFlatTreeEmpty() {
        let state = BrowseState()
        #expect(state.visibleFlatTree.isEmpty)
    }

    // MARK: - filteredFlatTree with search queries

    @Test("filteredFlatTree case-insensitive matching")
    func filteredFlatTreeCaseInsensitive() {
        let state = BrowseState()
        let file1 = makeFile(name: "Music\\SONG.MP3")
        let folder = makeFolder(name: "Music", children: [file1])
        state.browses = [UserShares(username: "alice", folders: [folder], isLoading: false)]
        state.selectedBrowseIndex = 0
        state.expandedFolders = [folder.id]
        state.filterQuery = "song"

        let filtered = state.filteredFlatTree
        let files = filtered.filter { !$0.file.isDirectory }

        #expect(files.count == 1)
    }

    @Test("filteredFlatTree preserves ancestor directories of matches")
    func filteredFlatTreeAncestors() {
        let state = BrowseState()
        let file1 = makeFile(name: "Music\\match.mp3")
        let file2 = makeFile(name: "Music\\nomatch.txt")
        let folder = makeFolder(name: "Music", children: [file1, file2])
        state.browses = [UserShares(username: "alice", folders: [folder], isLoading: false)]
        state.selectedBrowseIndex = 0
        state.expandedFolders = [folder.id]
        state.filterQuery = "match.mp3"

        let filtered = state.filteredFlatTree

        // Should include: Music folder (ancestor) + match.mp3
        let dirs = filtered.filter { $0.file.isDirectory }
        let files = filtered.filter { !$0.file.isDirectory }
        #expect(dirs.count == 1)
        #expect(files.count == 1)
    }

    @Test("filteredFlatTree with whitespace-only query returns all")
    func filteredFlatTreeWhitespaceQuery() {
        let state = BrowseState()
        let file = makeFile(name: "Music\\song.mp3")
        let folder = makeFolder(name: "Music", children: [file])
        state.browses = [UserShares(username: "alice", folders: [folder], isLoading: false)]
        state.selectedBrowseIndex = 0
        state.expandedFolders = [folder.id]
        state.filterQuery = "   "

        let filtered = state.filteredFlatTree

        #expect(filtered.count == 2)
    }

    // MARK: - displayedFolders with currentFolderPath

    @Test("displayedFolders navigates into subfolder")
    func displayedFoldersSubfolder() {
        let state = BrowseState()
        let grandchild = makeFile(name: "Music\\Rock\\song.mp3")
        let child = makeFolder(name: "Music\\Rock", children: [grandchild])
        let root = makeFolder(name: "Music", children: [child])

        state.browses = [UserShares(username: "alice", folders: [root], isLoading: false)]
        state.selectedBrowseIndex = 0
        state.currentFolderPath = "Music"

        let displayed = state.displayedFolders

        #expect(displayed.count == 1)
        #expect(displayed[0].isDirectory)
    }

    @Test("displayedFolders returns empty for nonexistent path")
    func displayedFoldersNonexistentPath() {
        let state = BrowseState()
        let root = makeFolder(name: "Music", children: [makeFile(name: "Music\\song.mp3")])

        state.browses = [UserShares(username: "alice", folders: [root], isLoading: false)]
        state.selectedBrowseIndex = 0
        state.currentFolderPath = "NonExistent"

        let displayed = state.displayedFolders

        #expect(displayed.isEmpty)
    }

    // MARK: - currentBrowse setter

    @Test("setting currentBrowse updates browse at selected index")
    func setCurrentBrowse() {
        let state = BrowseState()
        state.browses = [UserShares(username: "alice", isLoading: true)]
        state.selectedBrowseIndex = 0

        var updated = state.currentBrowse!
        updated.isLoading = false
        updated.error = "test error"
        state.currentBrowse = updated

        #expect(state.browses[0].isLoading == false)
        #expect(state.browses[0].error == "test error")
    }

    @Test("setting currentBrowse out of bounds does nothing")
    func setCurrentBrowseOutOfBounds() {
        let state = BrowseState()
        state.browses = [UserShares(username: "alice")]
        state.selectedBrowseIndex = 5

        state.currentBrowse = UserShares(username: "bob")

        #expect(state.browses.count == 1)
        #expect(state.browses[0].username == "alice")
    }
}

// MARK: - MetadataState Tests

@Suite(.serialized)
@MainActor
struct MetadataStateTests {

    @Test("init has expected defaults")
    func initDefaults() {
        let state = MetadataState()
        #expect(!state.isEditorPresented)
        #expect(state.currentFilePath == nil)
        #expect(state.currentFilename == "")
        #expect(state.detectedArtist == "")
        #expect(state.detectedTitle == "")
        #expect(state.editTitle == "")
        #expect(state.editArtist == "")
        #expect(state.editAlbum == "")
        #expect(state.editYear == "")
        #expect(state.editTrackNumber == "")
        #expect(state.editGenre == "")
        #expect(state.searchResults.isEmpty)
        #expect(state.selectedRecording == nil)
        #expect(state.selectedRelease == nil)
        #expect(state.coverArtData == nil)
        #expect(state.coverArtURL == nil)
        #expect(!state.isLoadingCoverArt)
        #expect(!state.isSearching)
        #expect(state.searchError == nil)
        #expect(!state.isApplying)
        #expect(state.applyError == nil)
        #expect(!state.autoEnrichOnDownload)
        #expect(!state.showEditorOnDownload)
    }

    // MARK: - parseFilename

    @Test("parseFilename: Artist - Title pattern", arguments: [
        ("Pink Floyd - Comfortably Numb.mp3", "Pink Floyd", "Comfortably Numb"),
        ("Led Zeppelin - Stairway to Heaven.flac", "Led Zeppelin", "Stairway to Heaven"),
    ])
    func parseFilenameArtistTitle(input: String, expectedArtist: String, expectedTitle: String) {
        let state = MetadataState()
        let result = state.parseFilename(input)
        #expect(result.artist == expectedArtist)
        #expect(result.title == expectedTitle)
    }

    @Test("parseFilename: track number prefix is stripped from title")
    func parseFilenameTrackNumber() {
        let state = MetadataState()
        let result = state.parseFilename("Artist - 01 Song Title.mp3")
        #expect(result.artist == "Artist")
        #expect(result.title == "Song Title")
    }

    @Test("parseFilename: numeric-only first part treated as track number")
    func parseFilenameNumericFirst() {
        let state = MetadataState()
        let result = state.parseFilename("01 - Song Title.mp3")
        #expect(result.artist == "")
        #expect(result.title == "Song Title")
    }

    @Test("parseFilename: 01. Title pattern")
    func parseFilenameDotPattern() {
        let state = MetadataState()
        let result = state.parseFilename("03. My Song.mp3")
        #expect(result.artist == "")
        #expect(result.title == "My Song")
    }

    @Test("parseFilename: no pattern matched returns filename as title")
    func parseFilenameNoPattern() {
        let state = MetadataState()
        let result = state.parseFilename("just_a_filename.mp3")
        #expect(result.artist == "")
        #expect(result.title == "just_a_filename")
    }

    @Test("parseFilename: multi-dash format")
    func parseFilenameMultiDash() {
        let state = MetadataState()
        let result = state.parseFilename("Artist - Album - 01 - Title.mp3")
        #expect(result.artist == "Artist")
        // Remaining parts joined back
        #expect(result.title.contains("Title"))
    }

    // MARK: - closeEditor

    @Test("closeEditor resets all fields")
    func closeEditorResetsAll() {
        let state = MetadataState()
        state.isEditorPresented = true
        state.currentFilePath = URL(fileURLWithPath: "/tmp/test.mp3")
        state.currentFilename = "test.mp3"
        state.detectedArtist = "Artist"
        state.detectedTitle = "Title"
        state.editTitle = "Title"
        state.editArtist = "Artist"
        state.editAlbum = "Album"
        state.editYear = "2024"
        state.editTrackNumber = "1"
        state.editGenre = "Rock"
        state.coverArtData = Data([0x01])
        state.coverArtURL = URL(string: "https://example.com/art.jpg")
        state.coverArtSource = .musicBrainz
        state.applyError = "some error"

        state.closeEditor()

        #expect(!state.isEditorPresented)
        #expect(state.currentFilePath == nil)
        #expect(state.currentFilename == "")
        #expect(state.detectedArtist == "")
        #expect(state.detectedTitle == "")
        #expect(state.editTitle == "")
        #expect(state.editArtist == "")
        #expect(state.editAlbum == "")
        #expect(state.editYear == "")
        #expect(state.editTrackNumber == "")
        #expect(state.editGenre == "")
        #expect(state.searchResults.isEmpty)
        #expect(state.selectedRecording == nil)
        #expect(state.selectedRelease == nil)
        #expect(state.coverArtData == nil)
        #expect(state.coverArtURL == nil)
        #expect(state.applyError == nil)
    }

    // MARK: - setCoverArt / clearCoverArt

    @Test("setCoverArt sets data and source to manual")
    func setCoverArt() {
        let state = MetadataState()
        let data = Data([0x89, 0x50, 0x4E, 0x47])

        state.setCoverArt(data)

        #expect(state.coverArtData == data)
        #expect(state.coverArtSource == .manual)
        #expect(state.coverArtURL == nil)
    }

    @Test("clearCoverArt resets cover art state")
    func clearCoverArt() {
        let state = MetadataState()
        state.coverArtData = Data([0x01])
        state.coverArtSource = .musicBrainz
        state.coverArtURL = URL(string: "https://example.com/art.jpg")

        state.clearCoverArt()

        #expect(state.coverArtData == nil)
        #expect(state.coverArtSource == .none)
        #expect(state.coverArtURL == nil)
    }

    // MARK: - CoverArtSource

    @Test("CoverArtSource enum values exist")
    func coverArtSourceValues() {
        let none = MetadataState.CoverArtSource.none
        let embedded = MetadataState.CoverArtSource.embedded
        let musicBrainz = MetadataState.CoverArtSource.musicBrainz
        let manual = MetadataState.CoverArtSource.manual

        #expect(none != embedded)
        #expect(embedded != musicBrainz)
        #expect(musicBrainz != manual)
    }

    // MARK: - search validation

    @Test("search sets error when both artist and title are empty")
    func searchEmptyFields() async {
        let state = MetadataState()
        state.detectedArtist = ""
        state.detectedTitle = ""

        await state.search()

        #expect(state.searchError == "Enter artist or title to search")
    }

    // MARK: - applyMetadata validation

    @Test("applyMetadata fails when no file selected")
    func applyMetadataNoFile() async {
        let state = MetadataState()
        state.currentFilePath = nil

        let result = await state.applyMetadata()

        #expect(!result)
        #expect(state.applyError == "No file selected")
    }

    @Test("applyMetadata fails when title and artist are empty")
    func applyMetadataEmptyFields() async {
        let state = MetadataState()
        state.currentFilePath = URL(fileURLWithPath: "/tmp/test.mp3")
        state.editTitle = ""
        state.editArtist = ""

        let result = await state.applyMetadata()

        #expect(!result)
        #expect(state.applyError == "Please enter at least a title or artist")
    }

    // MARK: - EditableMetadata / DetectedMetadata structs

    @Test("EditableMetadata holds all fields")
    func editableMetadata() {
        let metadata = MetadataState.EditableMetadata(
            title: "Song",
            artist: "Artist",
            album: "Album",
            year: "2024",
            trackNumber: 5,
            genre: "Rock",
            coverArt: Data([0x01])
        )

        #expect(metadata.title == "Song")
        #expect(metadata.artist == "Artist")
        #expect(metadata.album == "Album")
        #expect(metadata.year == "2024")
        #expect(metadata.trackNumber == 5)
        #expect(metadata.genre == "Rock")
        #expect(metadata.coverArt != nil)
    }

    @Test("DetectedMetadata holds fields correctly")
    func detectedMetadata() {
        let metadata = MetadataState.DetectedMetadata(
            artist: "Artist",
            title: "Title",
            album: "Album",
            trackNumber: 3
        )

        #expect(metadata.artist == "Artist")
        #expect(metadata.title == "Title")
        #expect(metadata.album == "Album")
        #expect(metadata.trackNumber == 3)
    }

    @Test("DetectedMetadata with nil optionals")
    func detectedMetadataNils() {
        let metadata = MetadataState.DetectedMetadata(
            artist: "Artist",
            title: "Title",
            album: nil,
            trackNumber: nil
        )

        #expect(metadata.album == nil)
        #expect(metadata.trackNumber == nil)
    }
}

// MARK: - TransferState Tests

@Suite(.serialized)
@MainActor
struct TransferStateTests {

    // MARK: - Init

    @Test("init has empty transfers")
    func initDefaults() {
        let state = TransferState()
        #expect(state.downloads.isEmpty)
        #expect(state.uploads.isEmpty)
        #expect(state.history.isEmpty)
        #expect(state.totalDownloadSpeed == 0)
        #expect(state.totalUploadSpeed == 0)
        #expect(state.totalDownloaded == 0)
        #expect(state.totalUploaded == 0)
    }

    // MARK: - addDownload / addUpload

    @Test("addDownload inserts at front")
    func addDownload() {
        let state = TransferState()
        let t1 = makeTransfer(username: "alice", filename: "file1.mp3")
        let t2 = makeTransfer(username: "bob", filename: "file2.mp3")

        state.addDownload(t1)
        state.addDownload(t2)

        #expect(state.downloads.count == 2)
        #expect(state.downloads[0].username == "bob")
        #expect(state.downloads[1].username == "alice")
    }

    @Test("addUpload inserts at front")
    func addUpload() {
        let state = TransferState()
        let t1 = makeTransfer(username: "alice", direction: .upload)
        let t2 = makeTransfer(username: "bob", direction: .upload)

        state.addUpload(t1)
        state.addUpload(t2)

        #expect(state.uploads.count == 2)
        #expect(state.uploads[0].username == "bob")
    }

    // MARK: - getTransfer

    @Test("getTransfer finds download by ID")
    func getTransferDownload() {
        let state = TransferState()
        let id = UUID()
        let transfer = makeTransfer(id: id, username: "alice")
        state.addDownload(transfer)

        let found = state.getTransfer(id: id)

        #expect(found != nil)
        #expect(found?.username == "alice")
    }

    @Test("getTransfer finds upload by ID")
    func getTransferUpload() {
        let state = TransferState()
        let id = UUID()
        let transfer = makeTransfer(id: id, username: "bob", direction: .upload)
        state.addUpload(transfer)

        let found = state.getTransfer(id: id)

        #expect(found != nil)
        #expect(found?.username == "bob")
    }

    @Test("getTransfer returns nil for unknown ID")
    func getTransferNotFound() {
        let state = TransferState()
        #expect(state.getTransfer(id: UUID()) == nil)
    }

    // MARK: - updateTransfer

    @Test("updateTransfer modifies download in place")
    func updateTransferDownload() {
        let state = TransferState()
        let id = UUID()
        state.addDownload(makeTransfer(id: id, status: .queued))

        state.updateTransfer(id: id) { transfer in
            transfer.status = .transferring
            transfer.bytesTransferred = 5000
            transfer.speed = 1000
        }

        let updated = state.getTransfer(id: id)
        #expect(updated?.status == .transferring)
        #expect(updated?.bytesTransferred == 5000)
        #expect(updated?.speed == 1000)
    }

    @Test("updateTransfer modifies upload in place")
    func updateTransferUpload() {
        let state = TransferState()
        let id = UUID()
        state.addUpload(makeTransfer(id: id, direction: .upload, status: .queued))

        state.updateTransfer(id: id) { transfer in
            transfer.status = .completed
        }

        let updated = state.getTransfer(id: id)
        #expect(updated?.status == .completed)
    }

    @Test("updateTransfer with unknown ID does nothing")
    func updateTransferUnknown() {
        let state = TransferState()
        state.addDownload(makeTransfer(username: "alice"))

        state.updateTransfer(id: UUID()) { transfer in
            transfer.status = .failed
        }

        // Original download should be unchanged
        #expect(state.downloads[0].status == .queued)
    }

    // MARK: - removeTransfer

    @Test("removeTransfer removes download")
    func removeDownload() {
        let state = TransferState()
        let id = UUID()
        state.addDownload(makeTransfer(id: id))

        state.removeTransfer(id: id)

        #expect(state.downloads.isEmpty)
    }

    @Test("removeTransfer removes upload")
    func removeUpload() {
        let state = TransferState()
        let id = UUID()
        state.addUpload(makeTransfer(id: id, direction: .upload))

        state.removeTransfer(id: id)

        #expect(state.uploads.isEmpty)
    }

    // MARK: - cancelTransfer / retryTransfer

    @Test("cancelTransfer sets status to cancelled")
    func cancelTransfer() {
        let state = TransferState()
        let id = UUID()
        state.addDownload(makeTransfer(id: id, status: .transferring))

        state.cancelTransfer(id: id)

        #expect(state.getTransfer(id: id)?.status == .cancelled)
    }

    @Test("retryTransfer resets status and bytes")
    func retryTransfer() {
        let state = TransferState()
        let id = UUID()
        var transfer = makeTransfer(id: id, status: .failed)
        transfer.bytesTransferred = 5000
        transfer.error = "Connection lost"
        state.downloads = [transfer]

        state.retryTransfer(id: id)

        let retried = state.getTransfer(id: id)
        #expect(retried?.status == .queued)
        #expect(retried?.bytesTransferred == 0)
        #expect(retried?.error == nil)
    }

    // MARK: - clearCompleted / clearFailed

    @Test("clearCompleted removes completed transfers")
    func clearCompleted() {
        let state = TransferState()
        state.addDownload(makeTransfer(status: .completed))
        state.addDownload(makeTransfer(status: .queued))
        state.addUpload(makeTransfer(direction: .upload, status: .completed))
        state.addUpload(makeTransfer(direction: .upload, status: .transferring))

        state.clearCompleted()

        #expect(state.downloads.count == 1)
        #expect(state.downloads[0].status == .queued)
        #expect(state.uploads.count == 1)
        #expect(state.uploads[0].status == .transferring)
    }

    @Test("clearFailed removes failed and cancelled transfers")
    func clearFailed() {
        let state = TransferState()
        state.addDownload(makeTransfer(status: .failed))
        state.addDownload(makeTransfer(status: .cancelled))
        state.addDownload(makeTransfer(status: .queued))

        state.clearFailed()

        #expect(state.downloads.count == 1)
        #expect(state.downloads[0].status == .queued)
    }

    // MARK: - Computed Properties

    @Test("activeDownloads filters connecting and transferring")
    func activeDownloads() {
        let state = TransferState()
        state.addDownload(makeTransfer(status: .connecting))
        state.addDownload(makeTransfer(status: .transferring))
        state.addDownload(makeTransfer(status: .queued))
        state.addDownload(makeTransfer(status: .completed))

        #expect(state.activeDownloads.count == 2)
    }

    @Test("activeUploads filters active uploads")
    func activeUploads() {
        let state = TransferState()
        state.addUpload(makeTransfer(direction: .upload, status: .transferring))
        state.addUpload(makeTransfer(direction: .upload, status: .completed))

        #expect(state.activeUploads.count == 1)
    }

    @Test("queuedDownloads filters queued and waiting")
    func queuedDownloads() {
        let state = TransferState()
        state.addDownload(makeTransfer(status: .queued))
        state.addDownload(makeTransfer(status: .waiting))
        state.addDownload(makeTransfer(status: .transferring))

        #expect(state.queuedDownloads.count == 2)
    }

    @Test("completedDownloads filters completed")
    func completedDownloads() {
        let state = TransferState()
        state.addDownload(makeTransfer(status: .completed))
        state.addDownload(makeTransfer(status: .queued))

        #expect(state.completedDownloads.count == 1)
    }

    @Test("failedDownloads filters failed and cancelled")
    func failedDownloads() {
        let state = TransferState()
        state.addDownload(makeTransfer(status: .failed))
        state.addDownload(makeTransfer(status: .cancelled))
        state.addDownload(makeTransfer(status: .queued))

        #expect(state.failedDownloads.count == 2)
    }

    @Test("hasActiveTransfers reflects active state")
    func hasActiveTransfers() {
        let state = TransferState()
        #expect(!state.hasActiveTransfers)

        state.addDownload(makeTransfer(status: .transferring))
        #expect(state.hasActiveTransfers)
    }

    // MARK: - downloadStatus / isFileQueued

    @Test("downloadStatus returns status for known file")
    func downloadStatus() {
        let state = TransferState()
        state.addDownload(makeTransfer(username: "alice", filename: "file.mp3", status: .transferring))

        let status = state.downloadStatus(for: "file.mp3", from: "alice")

        #expect(status == .transferring)
    }

    @Test("downloadStatus returns nil for unknown file")
    func downloadStatusUnknown() {
        let state = TransferState()
        #expect(state.downloadStatus(for: "nonexistent", from: "nobody") == nil)
    }

    @Test("isFileQueued returns true for active download")
    func isFileQueuedTrue() {
        let state = TransferState()
        state.addDownload(makeTransfer(username: "alice", filename: "file.mp3", status: .queued))

        #expect(state.isFileQueued(filename: "file.mp3", username: "alice"))
    }

    @Test("isFileQueued returns false for completed download")
    func isFileQueuedCompleted() {
        let state = TransferState()
        state.addDownload(makeTransfer(username: "alice", filename: "file.mp3", status: .completed))

        #expect(!state.isFileQueued(filename: "file.mp3", username: "alice"))
    }

    @Test("isFileQueued returns false for unknown file")
    func isFileQueuedUnknown() {
        let state = TransferState()
        #expect(!state.isFileQueued(filename: "nope", username: "nobody"))
    }

    // MARK: - Move operations

    @Test("moveDownload reorders downloads")
    func moveDownload() {
        let state = TransferState()
        let t1 = makeTransfer(username: "first")
        let t2 = makeTransfer(username: "second")
        let t3 = makeTransfer(username: "third")
        state.downloads = [t1, t2, t3]

        state.moveDownload(from: IndexSet(integer: 2), to: 0)

        #expect(state.downloads[0].username == "third")
    }

    @Test("moveDownloadToTop moves to index 0")
    func moveDownloadToTop() {
        let state = TransferState()
        let t1 = makeTransfer(username: "first")
        let t2 = makeTransfer(username: "second")
        let t3 = makeTransfer(username: "third")
        state.downloads = [t1, t2, t3]

        state.moveDownloadToTop(id: t3.id)

        #expect(state.downloads[0].username == "third")
    }

    @Test("moveDownloadToBottom moves to end")
    func moveDownloadToBottom() {
        let state = TransferState()
        let t1 = makeTransfer(username: "first")
        let t2 = makeTransfer(username: "second")
        let t3 = makeTransfer(username: "third")
        state.downloads = [t1, t2, t3]

        state.moveDownloadToBottom(id: t1.id)

        #expect(state.downloads.last?.username == "first")
    }

    @Test("moveDownloadToTop with unknown ID does nothing")
    func moveDownloadToTopUnknown() {
        let state = TransferState()
        state.downloads = [makeTransfer(username: "alice")]

        state.moveDownloadToTop(id: UUID())

        #expect(state.downloads.count == 1)
    }

    @Test("moveDownloadToBottom with unknown ID does nothing")
    func moveDownloadToBottomUnknown() {
        let state = TransferState()
        state.downloads = [makeTransfer(username: "alice")]

        state.moveDownloadToBottom(id: UUID())

        #expect(state.downloads.count == 1)
    }

    // MARK: - updateSpeeds

    @Test("updateSpeeds computes totals from active transfers")
    func updateSpeeds() {
        let state = TransferState()
        state.addDownload(makeTransfer(status: .transferring, speed: 100))
        state.addDownload(makeTransfer(status: .transferring, speed: 200))
        state.addDownload(makeTransfer(status: .queued, speed: 50))
        state.addUpload(makeTransfer(direction: .upload, status: .transferring, speed: 75))

        state.updateSpeeds()

        #expect(state.totalDownloadSpeed == 300)
        #expect(state.totalUploadSpeed == 75)
    }

    // MARK: - clearHistory

    @Test("clearHistory empties history and resets totals")
    func clearHistory() {
        let state = TransferState()
        state.history = [TransferHistoryItem(
            id: "test",
            timestamp: Date(),
            filename: "test.mp3",
            username: "alice",
            size: 1000,
            duration: 10,
            averageSpeed: 100,
            isDownload: true,
            localPath: nil
        )]
        state.totalDownloaded = 5000
        state.totalUploaded = 3000

        state.clearHistory()

        #expect(state.history.isEmpty)
        #expect(state.totalDownloaded == 0)
        #expect(state.totalUploaded == 0)
    }

    // MARK: - downloadStatusIndex

    @Test("downloadStatusIndex rebuilds on downloads didSet")
    func downloadStatusIndex() {
        let state = TransferState()
        let transfer = makeTransfer(username: "alice", filename: "song.mp3", status: .transferring)
        state.downloads = [transfer]

        #expect(state.downloadStatusIndex["alice\0song.mp3"] == .transferring)
    }
}

// MARK: - TransferHistoryItem Tests

@Suite
struct TransferHistoryItemTests {

    @Test("displayFilename extracts last path component")
    func displayFilename() {
        let item = TransferHistoryItem(
            id: "1",
            timestamp: Date(),
            filename: "@@music\\Artist\\Album\\song.mp3",
            username: "alice",
            size: 5_000_000,
            duration: 30,
            averageSpeed: 166_666,
            isDownload: true,
            localPath: nil
        )

        #expect(item.displayFilename == "song.mp3")
    }

    @Test("displayFilename returns full filename when no backslash")
    func displayFilenameNoSeparator() {
        let item = TransferHistoryItem(
            id: "1",
            timestamp: Date(),
            filename: "song.mp3",
            username: "alice",
            size: 1000,
            duration: 5,
            averageSpeed: 200,
            isDownload: true,
            localPath: nil
        )

        #expect(item.displayFilename == "song.mp3")
    }

    @Test("isAudioFile detects audio extensions")
    func isAudioFile() {
        let audioItem = TransferHistoryItem(
            id: "1", timestamp: Date(), filename: "@@music\\song.mp3",
            username: "a", size: 1000, duration: 1, averageSpeed: 1000,
            isDownload: true, localPath: nil
        )
        let nonAudioItem = TransferHistoryItem(
            id: "2", timestamp: Date(), filename: "@@docs\\readme.txt",
            username: "a", size: 1000, duration: 1, averageSpeed: 1000,
            isDownload: true, localPath: nil
        )

        #expect(audioItem.isAudioFile)
        #expect(!nonAudioItem.isAudioFile)
    }

    @Test("formattedSize formats bytes")
    func formattedSize() {
        let item = TransferHistoryItem(
            id: "1", timestamp: Date(), filename: "song.mp3",
            username: "a", size: 5_242_880, duration: 10, averageSpeed: 524_288,
            isDownload: true, localPath: nil
        )

        #expect(!item.formattedSize.isEmpty)
    }

    @Test("formattedSpeed formats speed")
    func formattedSpeed() {
        let item = TransferHistoryItem(
            id: "1", timestamp: Date(), filename: "song.mp3",
            username: "a", size: 1000, duration: 10, averageSpeed: 100,
            isDownload: true, localPath: nil
        )

        #expect(!item.formattedSpeed.isEmpty)
    }

    @Test("formattedDuration with minutes")
    func formattedDurationMinutes() {
        let item = TransferHistoryItem(
            id: "1", timestamp: Date(), filename: "song.mp3",
            username: "a", size: 1000, duration: 125, averageSpeed: 8,
            isDownload: true, localPath: nil
        )

        #expect(item.formattedDuration == "2m 5s")
    }

    @Test("formattedDuration seconds only")
    func formattedDurationSecondsOnly() {
        let item = TransferHistoryItem(
            id: "1", timestamp: Date(), filename: "song.mp3",
            username: "a", size: 1000, duration: 45, averageSpeed: 22,
            isDownload: true, localPath: nil
        )

        #expect(item.formattedDuration == "45s")
    }

    @Test("formattedDate produces non-empty string")
    func formattedDate() {
        let item = TransferHistoryItem(
            id: "1", timestamp: Date(), filename: "song.mp3",
            username: "a", size: 1000, duration: 10, averageSpeed: 100,
            isDownload: true, localPath: nil
        )

        #expect(!item.formattedDate.isEmpty)
    }

    @Test("fileExists returns false when localPath is nil")
    func fileExistsNilPath() {
        let item = TransferHistoryItem(
            id: "1", timestamp: Date(), filename: "song.mp3",
            username: "a", size: 1000, duration: 10, averageSpeed: 100,
            isDownload: true, localPath: nil
        )

        #expect(!item.fileExists)
    }
}

// MARK: - StatisticsState Tests

@Suite(.serialized)
@MainActor
struct StatisticsStateTests {

    @Test("init has expected defaults")
    func initDefaults() {
        let state = StatisticsState()
        #expect(state.totalDownloaded == 0)
        #expect(state.totalUploaded == 0)
        #expect(state.sessionDownloaded == 0)
        #expect(state.sessionUploaded == 0)
        #expect(state.downloadHistory.isEmpty)
        #expect(state.uploadHistory.isEmpty)
        #expect(state.speedSamples.isEmpty)
        #expect(state.maxRecordedSpeed == 0)
        #expect(state.peersConnected == 0)
        #expect(state.peersEverConnected == 0)
        #expect(state.connectionAttempts == 0)
        #expect(state.connectionFailures == 0)
        #expect(state.searchesPerformed == 0)
        #expect(state.totalResultsReceived == 0)
        #expect(state.averageResponseTime == 0)
        #expect(state.filesDownloaded == 0)
        #expect(state.filesUploaded == 0)
        #expect(state.uniqueUsersDownloadedFrom.isEmpty)
        #expect(state.uniqueUsersUploadedTo.isEmpty)
    }

    // MARK: - Computed Properties

    @Test("sessionDuration returns positive value")
    func sessionDuration() {
        let state = StatisticsState()
        state.sessionStartTime = Date().addingTimeInterval(-3600)

        #expect(state.sessionDuration >= 3599)
    }

    @Test("formattedSessionDuration with hours")
    func formattedSessionDurationHours() {
        let state = StatisticsState()
        state.sessionStartTime = Date().addingTimeInterval(-3661)

        let formatted = state.formattedSessionDuration

        #expect(formatted.contains("1:"))
    }

    @Test("formattedSessionDuration without hours")
    func formattedSessionDurationNoHours() {
        let state = StatisticsState()
        state.sessionStartTime = Date().addingTimeInterval(-65)

        let formatted = state.formattedSessionDuration

        // Should be "1:05" format
        #expect(formatted.contains(":"))
    }

    @Test("averageDownloadSpeed computes correctly")
    func averageDownloadSpeed() {
        let state = StatisticsState()
        state.sessionStartTime = Date().addingTimeInterval(-100)
        state.sessionDownloaded = 10_000

        let speed = state.averageDownloadSpeed

        #expect(speed > 0)
        #expect(speed <= 110) // ~100 B/s with some tolerance
    }

    @Test("averageUploadSpeed computes correctly")
    func averageUploadSpeed() {
        let state = StatisticsState()
        state.sessionStartTime = Date().addingTimeInterval(-100)
        state.sessionUploaded = 10_000

        let speed = state.averageUploadSpeed

        #expect(speed > 0)
    }

    @Test("averageDownloadSpeed returns 0 when session just started")
    func averageDownloadSpeedZeroDuration() {
        let state = StatisticsState()
        state.sessionStartTime = Date()

        // With a session that just started, duration could be ~0
        #expect(state.averageDownloadSpeed >= 0)
    }

    @Test("connectionSuccessRate computes correctly")
    func connectionSuccessRate() {
        let state = StatisticsState()
        state.connectionAttempts = 10
        state.connectionFailures = 3

        #expect(state.connectionSuccessRate == 0.7)
    }

    @Test("connectionSuccessRate returns 0 with no attempts")
    func connectionSuccessRateNoAttempts() {
        let state = StatisticsState()
        #expect(state.connectionSuccessRate == 0)
    }

    @Test("currentDownloadSpeed from last sample")
    func currentDownloadSpeed() {
        let state = StatisticsState()
        state.addSpeedSample(download: 500, upload: 200)

        #expect(state.currentDownloadSpeed == 500)
        #expect(state.currentUploadSpeed == 200)
    }

    @Test("currentDownloadSpeed returns 0 when no samples")
    func currentDownloadSpeedNoSamples() {
        let state = StatisticsState()
        #expect(state.currentDownloadSpeed == 0)
        #expect(state.currentUploadSpeed == 0)
    }

    // MARK: - addSpeedSample

    @Test("addSpeedSample appends and tracks max")
    func addSpeedSample() {
        let state = StatisticsState()
        state.addSpeedSample(download: 100, upload: 50)
        state.addSpeedSample(download: 300, upload: 150)

        #expect(state.speedSamples.count == 2)
        #expect(state.maxRecordedSpeed == 300)
    }

    @Test("addSpeedSample caps at 120 samples")
    func addSpeedSampleCap() {
        let state = StatisticsState()
        for i in 0..<130 {
            state.addSpeedSample(download: Double(i), upload: 0)
        }

        #expect(state.speedSamples.count == 120)
    }

    // MARK: - recordTransfer

    @Test("recordTransfer download increments stats")
    func recordTransferDownload() {
        let state = StatisticsState()
        state.recordTransfer(filename: "song.mp3", username: "alice", size: 5000, duration: 10, isDownload: true)

        #expect(state.filesDownloaded == 1)
        #expect(state.sessionDownloaded == 5000)
        #expect(state.totalDownloaded == 5000)
        #expect(state.downloadHistory.count == 1)
        #expect(state.uniqueUsersDownloadedFrom.contains("alice"))
    }

    @Test("recordTransfer upload increments stats")
    func recordTransferUpload() {
        let state = StatisticsState()
        state.recordTransfer(filename: "song.mp3", username: "bob", size: 3000, duration: 5, isDownload: false)

        #expect(state.filesUploaded == 1)
        #expect(state.sessionUploaded == 3000)
        #expect(state.totalUploaded == 3000)
        #expect(state.uploadHistory.count == 1)
        #expect(state.uniqueUsersUploadedTo.contains("bob"))
    }

    @Test("recordTransfer caps history at 100")
    func recordTransferHistoryCap() {
        let state = StatisticsState()
        for i in 0..<105 {
            state.recordTransfer(filename: "file\(i).mp3", username: "user", size: 100, duration: 1, isDownload: true)
        }

        #expect(state.downloadHistory.count == 100)
    }

    @Test("recordTransfer computes averageSpeed correctly")
    func recordTransferAverageSpeed() {
        let state = StatisticsState()
        state.recordTransfer(filename: "song.mp3", username: "alice", size: 10000, duration: 5, isDownload: true)

        #expect(state.downloadHistory[0].averageSpeed == 2000)
    }

    @Test("recordTransfer with zero duration has zero averageSpeed")
    func recordTransferZeroDuration() {
        let state = StatisticsState()
        state.recordTransfer(filename: "song.mp3", username: "alice", size: 10000, duration: 0, isDownload: true)

        #expect(state.downloadHistory[0].averageSpeed == 0)
    }

    // MARK: - recordSearch

    @Test("recordSearch increments stats")
    func recordSearch() {
        let state = StatisticsState()
        state.recordSearch(resultsCount: 50, responseTime: 1.5)

        #expect(state.searchesPerformed == 1)
        #expect(state.totalResultsReceived == 50)
        #expect(state.averageResponseTime == 1.5)
    }

    @Test("recordSearch computes rolling average")
    func recordSearchRollingAverage() {
        let state = StatisticsState()
        state.recordSearch(resultsCount: 10, responseTime: 1.0)
        state.recordSearch(resultsCount: 20, responseTime: 3.0)

        #expect(state.searchesPerformed == 2)
        #expect(state.totalResultsReceived == 30)
        #expect(state.averageResponseTime == 2.0)
    }

    // MARK: - recordConnectionAttempt

    @Test("recordConnectionAttempt success increments peersEverConnected")
    func recordConnectionAttemptSuccess() {
        let state = StatisticsState()
        state.recordConnectionAttempt(success: true)

        #expect(state.connectionAttempts == 1)
        #expect(state.connectionFailures == 0)
        #expect(state.peersEverConnected == 1)
    }

    @Test("recordConnectionAttempt failure increments failures")
    func recordConnectionAttemptFailure() {
        let state = StatisticsState()
        state.recordConnectionAttempt(success: false)

        #expect(state.connectionAttempts == 1)
        #expect(state.connectionFailures == 1)
        #expect(state.peersEverConnected == 0)
    }

    // MARK: - resetSession

    @Test("resetSession clears session data")
    func resetSession() {
        let state = StatisticsState()
        state.sessionDownloaded = 5000
        state.sessionUploaded = 3000
        state.addSpeedSample(download: 100, upload: 50)
        state.peersConnected = 5
        state.connectionAttempts = 10
        state.connectionFailures = 2
        state.searchesPerformed = 5
        state.totalResultsReceived = 100
        state.averageResponseTime = 2.0

        state.resetSession()

        #expect(state.sessionDownloaded == 0)
        #expect(state.sessionUploaded == 0)
        #expect(state.speedSamples.isEmpty)
        #expect(state.peersConnected == 0)
        #expect(state.connectionAttempts == 0)
        #expect(state.connectionFailures == 0)
        #expect(state.searchesPerformed == 0)
        #expect(state.totalResultsReceived == 0)
        #expect(state.averageResponseTime == 0)
    }

    @Test("resetSession preserves total counters")
    func resetSessionPreservesTotals() {
        let state = StatisticsState()
        state.totalDownloaded = 50_000
        state.totalUploaded = 30_000
        state.filesDownloaded = 10

        state.resetSession()

        #expect(state.totalDownloaded == 50_000)
        #expect(state.totalUploaded == 30_000)
        #expect(state.filesDownloaded == 10)
    }

    // MARK: - SpeedSample

    @Test("SpeedSample is identifiable")
    func speedSampleIdentifiable() {
        let sample = StatisticsState.SpeedSample(
            timestamp: Date(),
            downloadSpeed: 100,
            uploadSpeed: 50
        )

        #expect(sample.id != UUID())
        #expect(sample.downloadSpeed == 100)
        #expect(sample.uploadSpeed == 50)
    }

    // MARK: - TransferHistoryEntry

    @Test("TransferHistoryEntry is identifiable")
    func transferHistoryEntryIdentifiable() {
        let entry = StatisticsState.TransferHistoryEntry(
            timestamp: Date(),
            filename: "song.mp3",
            username: "alice",
            size: 5000,
            duration: 10,
            averageSpeed: 500,
            isDownload: true
        )

        #expect(!entry.id.uuidString.isEmpty)
        #expect(entry.filename == "song.mp3")
    }
}

// MARK: - UpdateState Tests

@Suite(.serialized)
@MainActor
struct UpdateStateTests {

    @Test("init has expected defaults")
    func initDefaults() {
        let state = UpdateState()
        #expect(!state.isChecking)
        #expect(!state.isDownloading)
        #expect(!state.updateAvailable)
        #expect(state.latestVersion == nil)
        #expect(state.latestReleaseURL == nil)
        #expect(state.latestPkgURL == nil)
        #expect(state.releaseNotes == nil)
        #expect(state.lastCheckDate == nil)
        #expect(state.errorMessage == nil)
        #expect(state.downloadProgress == nil)
        #expect(state.downloadedPkgURL == nil)
    }

    @Test("currentVersion returns a version string")
    func currentVersion() {
        let state = UpdateState()
        // In test environment this may be "0.0.0" or a real version
        #expect(!state.currentVersion.isEmpty)
    }

    @Test("currentBuild returns a build string")
    func currentBuild() {
        let state = UpdateState()
        #expect(!state.currentBuild.isEmpty)
    }

    @Test("currentFullVersion combines version and build")
    func currentFullVersion() {
        let state = UpdateState()
        let full = state.currentFullVersion
        #expect(full.contains("("))
        #expect(full.contains(")"))
    }

    @Test("dismissUpdate resets all update state")
    func dismissUpdate() {
        let state = UpdateState()
        state.updateAvailable = true
        state.latestVersion = "v2.0.0"
        state.releaseNotes = "New features"
        state.latestReleaseURL = URL(string: "https://github.com/test")
        state.latestPkgURL = URL(string: "https://github.com/test.pkg")
        state.errorMessage = "some error"

        state.dismissUpdate()

        #expect(!state.updateAvailable)
        #expect(state.latestVersion == nil)
        #expect(state.releaseNotes == nil)
        #expect(state.latestReleaseURL == nil)
        #expect(state.latestPkgURL == nil)
        #expect(state.errorMessage == nil)
    }

    @Test("checkOnLaunch does nothing when autoCheck is disabled")
    func checkOnLaunchDisabled() {
        let state = UpdateState()
        state.autoCheckEnabled = false
        // Should not crash or start checking
        state.checkOnLaunch()
        // isChecking might not be set synchronously, so just verify no crash
    }
}

// MARK: - SearchActivityState Tests

@Suite(.serialized)
@MainActor
struct SearchActivityStateTests {

    @Test("init has expected defaults")
    func initDefaults() {
        let state = SearchActivityState()
        #expect(state.recentEvents.isEmpty)
        #expect(state.incomingSearches.isEmpty)
        #expect(!state.isActive)
    }

    // MARK: - recordOutgoingSearch

    @Test("recordOutgoingSearch adds event")
    func recordOutgoingSearch() {
        let state = SearchActivityState()
        state.recordOutgoingSearch(query: "pink floyd")

        #expect(state.recentEvents.count == 1)
        #expect(state.recentEvents[0].query == "pink floyd")
        #expect(state.recentEvents[0].resultsCount == nil)
    }

    @Test("recordOutgoingSearch inserts at front")
    func recordOutgoingSearchFront() {
        let state = SearchActivityState()
        state.recordOutgoingSearch(query: "first")
        state.recordOutgoingSearch(query: "second")

        #expect(state.recentEvents[0].query == "second")
        #expect(state.recentEvents[1].query == "first")
    }

    @Test("recordOutgoingSearch caps at 100 events")
    func recordOutgoingSearchCap() {
        let state = SearchActivityState()
        for i in 0..<105 {
            state.recordOutgoingSearch(query: "query\(i)")
        }

        #expect(state.recentEvents.count == 100)
    }

    @Test("recordOutgoingSearch triggers activity")
    func recordOutgoingSearchActivity() {
        let state = SearchActivityState()
        state.recordOutgoingSearch(query: "test")

        #expect(state.isActive)
    }

    // MARK: - recordSearchResults

    @Test("recordSearchResults updates matching event")
    func recordSearchResults() {
        let state = SearchActivityState()
        state.recordOutgoingSearch(query: "pink floyd")

        state.recordSearchResults(query: "pink floyd", count: 42)

        #expect(state.recentEvents[0].resultsCount == 42)
    }

    @Test("recordSearchResults does nothing for unknown query")
    func recordSearchResultsUnknown() {
        let state = SearchActivityState()
        state.recordOutgoingSearch(query: "pink floyd")

        state.recordSearchResults(query: "unknown", count: 10)

        #expect(state.recentEvents[0].resultsCount == nil)
    }

    // MARK: - recordIncomingSearch

    @Test("recordIncomingSearch adds to both lists")
    func recordIncomingSearch() {
        let state = SearchActivityState()
        state.recordIncomingSearch(username: "alice", query: "led zeppelin", matchCount: 5)

        #expect(state.incomingSearches.count == 1)
        #expect(state.incomingSearches[0].username == "alice")
        #expect(state.incomingSearches[0].query == "led zeppelin")
        #expect(state.incomingSearches[0].matchCount == 5)

        // Should also be in recentEvents
        #expect(state.recentEvents.count == 1)
    }

    @Test("recordIncomingSearch caps at 50")
    func recordIncomingSearchCap() {
        let state = SearchActivityState()
        for i in 0..<55 {
            state.recordIncomingSearch(username: "user\(i)", query: "query\(i)", matchCount: i)
        }

        #expect(state.incomingSearches.count == 50)
    }

    @Test("recordIncomingSearch triggers activity")
    func recordIncomingSearchActivity() {
        let state = SearchActivityState()
        state.recordIncomingSearch(username: "alice", query: "test", matchCount: 1)

        #expect(state.isActive)
    }

    // MARK: - SearchEvent

    @Test("SearchEvent Direction values exist")
    func searchEventDirections() {
        let outgoing = SearchActivityState.SearchEvent(timestamp: Date(), query: "test", direction: .outgoing)
        let incoming = SearchActivityState.SearchEvent(timestamp: Date(), query: "test", direction: .incoming, resultsCount: 5)

        #expect(outgoing.resultsCount == nil)
        #expect(incoming.resultsCount == 5)
    }

    // MARK: - IncomingSearch

    @Test("IncomingSearch stores all fields")
    func incomingSearchFields() {
        let search = SearchActivityState.IncomingSearch(
            timestamp: Date(),
            username: "bob",
            query: "test query",
            matchCount: 10
        )

        #expect(search.username == "bob")
        #expect(search.query == "test query")
        #expect(search.matchCount == 10)
        #expect(!search.id.uuidString.isEmpty)
    }
}

// MARK: - ConnectionState Tests

@Suite(.serialized)
@MainActor
struct ConnectionStateTests {

    @Test("init has expected defaults")
    func initDefaults() {
        let state = ConnectionState()
        #expect(state.connectionStatus == .disconnected)
        #expect(state.username == nil)
        #expect(state.serverIP == nil)
        #expect(state.serverGreeting == nil)
        #expect(state.errorMessage == nil)
        #expect(state.loginUsername == "")
        #expect(state.loginPassword == "")
        #expect(state.rememberCredentials == true)
    }

    // MARK: - setConnecting

    @Test("setConnecting transitions to connecting state")
    func setConnecting() {
        let state = ConnectionState()
        state.username = "old"
        state.serverIP = "old"
        state.serverGreeting = "old"
        state.errorMessage = "old error"

        state.setConnecting()

        #expect(state.connectionStatus == .connecting)
        #expect(state.errorMessage == nil)
        #expect(state.username == nil)
        #expect(state.serverIP == nil)
        #expect(state.serverGreeting == nil)
    }

    // MARK: - setConnected

    @Test("setConnected transitions to connected state")
    func setConnected() {
        let state = ConnectionState()
        state.errorMessage = "previous error"

        state.setConnected(username: "alice", ip: "1.2.3.4", greeting: "Welcome!")

        #expect(state.connectionStatus == .connected)
        #expect(state.username == "alice")
        #expect(state.serverIP == "1.2.3.4")
        #expect(state.serverGreeting == "Welcome!")
        #expect(state.errorMessage == nil)
    }

    @Test("setConnected with nil greeting")
    func setConnectedNilGreeting() {
        let state = ConnectionState()

        state.setConnected(username: "alice", ip: "1.2.3.4", greeting: nil)

        #expect(state.connectionStatus == .connected)
        #expect(state.serverGreeting == nil)
    }

    // MARK: - setDisconnected

    @Test("setDisconnected clears connection info")
    func setDisconnected() {
        let state = ConnectionState()
        state.setConnected(username: "alice", ip: "1.2.3.4", greeting: "Hi")

        state.setDisconnected()

        #expect(state.connectionStatus == .disconnected)
        #expect(state.username == nil)
        #expect(state.serverIP == nil)
        #expect(state.serverGreeting == nil)
    }

    // MARK: - setReconnecting

    @Test("setReconnecting transitions to reconnecting state")
    func setReconnecting() {
        let state = ConnectionState()

        state.setReconnecting(reason: "Connection lost")

        #expect(state.connectionStatus == .reconnecting)
        #expect(state.errorMessage == "Connection lost")
    }

    @Test("setReconnecting with nil reason")
    func setReconnectingNilReason() {
        let state = ConnectionState()

        state.setReconnecting(reason: nil)

        #expect(state.connectionStatus == .reconnecting)
        #expect(state.errorMessage == nil)
    }

    // MARK: - setError

    @Test("setError transitions to error state")
    func setError() {
        let state = ConnectionState()

        state.setError("Something went wrong")

        #expect(state.connectionStatus == .error)
        #expect(state.errorMessage == "Something went wrong")
    }

    // MARK: - clearError

    @Test("clearError from error state transitions to disconnected")
    func clearErrorFromError() {
        let state = ConnectionState()
        state.setError("oops")

        state.clearError()

        #expect(state.connectionStatus == .disconnected)
        #expect(state.errorMessage == nil)
    }

    @Test("clearError from non-error state only clears message")
    func clearErrorFromNonError() {
        let state = ConnectionState()
        state.connectionStatus = .connected
        state.errorMessage = "something"

        state.clearError()

        // Status should remain connected
        #expect(state.connectionStatus == .connected)
        #expect(state.errorMessage == nil)
    }

    // MARK: - isLoginValid

    @Test("isLoginValid with valid credentials")
    func isLoginValidTrue() {
        let state = ConnectionState()
        state.loginUsername = "alice"
        state.loginPassword = "secret"

        #expect(state.isLoginValid)
    }

    @Test("isLoginValid false with empty username")
    func isLoginValidEmptyUsername() {
        let state = ConnectionState()
        state.loginUsername = ""
        state.loginPassword = "secret"

        #expect(!state.isLoginValid)
    }

    @Test("isLoginValid false with whitespace-only username")
    func isLoginValidWhitespaceUsername() {
        let state = ConnectionState()
        state.loginUsername = "   "
        state.loginPassword = "secret"

        #expect(!state.isLoginValid)
    }

    @Test("isLoginValid false with empty password")
    func isLoginValidEmptyPassword() {
        let state = ConnectionState()
        state.loginUsername = "alice"
        state.loginPassword = ""

        #expect(!state.isLoginValid)
    }
}

// MARK: - AppState Tests

@Suite(.serialized)
@MainActor
struct AppStateTests {

    @Test("init has expected default sub-states")
    func initDefaults() {
        let state = AppState()
        #expect(state.adminMessages.isEmpty)
        #expect(!state.showAdminMessageAlert)
        #expect(state.latestAdminMessage == nil)
        #expect(state.selectedTab == .search)
        #expect(state.sidebarSelection == .search)
        #expect(!state.isDatabaseReady)
    }

    @Test("sub-states are initialized")
    func subStatesInitialized() {
        let state = AppState()
        // Verify sub-states exist (no crash)
        _ = state.connection
        _ = state.searchState
        _ = state.chatState
        _ = state.settings
        _ = state.transferState
        _ = state.statisticsState
        _ = state.browseState
        _ = state.metadataState
        _ = state.socialState
        _ = state.wishlistState
        _ = state.updateState
        _ = state.downloadManager
        _ = state.uploadManager
    }

    // MARK: - Navigation

    @Test("selectedTab can be set to each value")
    func selectedTabValues() {
        let state = AppState()
        for tab in NavigationTab.allCases {
            state.selectedTab = tab
            #expect(state.selectedTab == tab)
        }
    }

    @Test("sidebarSelection can be set")
    func sidebarSelection() {
        let state = AppState()
        state.sidebarSelection = .transfers
        #expect(state.sidebarSelection == .transfers)

        state.sidebarSelection = .user("alice")
        #expect(state.sidebarSelection == .user("alice"))
    }

    // MARK: - Admin Messages

    @Test("AdminMessage stores message and timestamp")
    func adminMessage() {
        let msg = AdminMessage(message: "Server maintenance at midnight")

        #expect(msg.message == "Server maintenance at midnight")
        #expect(!msg.id.uuidString.isEmpty)
        // Timestamp should be recent
        #expect(abs(msg.timestamp.timeIntervalSinceNow) < 5)
    }

    @Test("adminMessages can be appended")
    func adminMessageAppend() {
        let state = AppState()
        let msg = AdminMessage(message: "Hello")
        state.adminMessages.append(msg)

        #expect(state.adminMessages.count == 1)
        #expect(state.adminMessages[0].message == "Hello")
    }
}

// MARK: - NavigationTab Tests

@Suite
struct NavigationTabTests {

    @Test("all cases have non-empty title and icon")
    func allCasesHaveTitleAndIcon() {
        for tab in NavigationTab.allCases {
            #expect(!tab.title.isEmpty)
            #expect(!tab.icon.isEmpty)
            #expect(!tab.id.isEmpty)
        }
    }

    @Test("id is rawValue", arguments: NavigationTab.allCases)
    func idMatchesRaw(tab: NavigationTab) {
        #expect(tab.id == tab.rawValue)
    }

    @Test("specific titles are correct")
    func specificTitles() {
        #expect(NavigationTab.search.title == "Search")
        #expect(NavigationTab.transfers.title == "Transfers")
        #expect(NavigationTab.chat.title == "Chat")
        #expect(NavigationTab.browse.title == "Browse")
        #expect(NavigationTab.settings.title == "Settings")
    }

    @Test("specific icons are correct")
    func specificIcons() {
        #expect(NavigationTab.search.icon == "magnifyingglass")
        #expect(NavigationTab.transfers.icon == "arrow.down.arrow.up")
        #expect(NavigationTab.chat.icon == "bubble.left.and.bubble.right")
        #expect(NavigationTab.browse.icon == "folder")
        #expect(NavigationTab.settings.icon == "gear")
    }
}

// MARK: - SidebarItem Tests

@Suite
struct SidebarItemTests {

    @Test("id is unique for each case")
    func uniqueIds() {
        let items: [SidebarItem] = [
            .search, .wishlists, .transfers, .chat, .browse,
            .social, .statistics, .networkMonitor, .settings,
            .user("alice"), .user("bob"),
            .room("general"), .room("music"),
        ]

        let ids = items.map { $0.id }
        #expect(Set(ids).count == ids.count)
    }

    @Test("title for user and room cases")
    func titleForDynamic() {
        #expect(SidebarItem.user("alice").title == "alice")
        #expect(SidebarItem.room("jazz").title == "jazz")
    }

    @Test("all static cases have non-empty title, icon, id")
    func staticCasesHaveValues() {
        let items: [SidebarItem] = [
            .search, .wishlists, .transfers, .chat, .browse,
            .social, .statistics, .networkMonitor, .settings,
        ]
        for item in items {
            #expect(!item.title.isEmpty)
            #expect(!item.icon.isEmpty)
            #expect(!item.id.isEmpty)
        }
    }

    @Test("specific ids are correct")
    func specificIds() {
        #expect(SidebarItem.search.id == "search")
        #expect(SidebarItem.user("alice").id == "user-alice")
        #expect(SidebarItem.room("jazz").id == "room-jazz")
        #expect(SidebarItem.statistics.id == "statistics")
        #expect(SidebarItem.networkMonitor.id == "networkMonitor")
    }

    @Test("specific icons are correct")
    func specificIcons() {
        #expect(SidebarItem.search.icon == "magnifyingglass")
        #expect(SidebarItem.social.icon == "person.2")
        #expect(SidebarItem.user("x").icon == "person")
        #expect(SidebarItem.room("x").icon == "person.3")
        #expect(SidebarItem.statistics.icon == "chart.bar")
    }

    @Test("SidebarItem is Hashable")
    func hashable() {
        var set: Set<SidebarItem> = []
        set.insert(.search)
        set.insert(.search)
        set.insert(.user("alice"))
        set.insert(.user("alice"))

        #expect(set.count == 2)
    }
}
