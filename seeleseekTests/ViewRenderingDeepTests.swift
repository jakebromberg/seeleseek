import Testing
import SwiftUI
@testable import seeleseek
@testable import SeeleseekCore

// MARK: - Deep View Rendering Tests
//
// These tests render SwiftUI views with populated state to cover branches
// that only execute when data is present: if/else, switch, ForEach, overlays,
// and different states (empty, loading, error, populated).

@Suite("Deep View Rendering Tests")
@MainActor
struct ViewRenderingDeepTests {

    // MARK: - Helpers

    private func renderView<V: View>(_ view: V) {
        let renderer = ImageRenderer(content: view.frame(width: 900, height: 700))
        let _ = renderer.cgImage
    }

    private func makeConnectedState() -> AppState {
        PreviewData.connectedAppState
    }

    // MARK: - BrowseView (721 uncovered)

    @Test("BrowseView with loaded shares shows file tree")
    func browseViewWithLoadedShares() {
        let state = makeConnectedState()
        let shares = UserShares(
            username: "musiclover42",
            folders: PreviewData.sampleFolderStructure,
            isLoading: false
        )
        state.browseState.browses.append(shares)
        state.browseState.currentUser = "musiclover42"
        renderView(
            BrowseView()
                .environment(\.appState, state)
        )
    }

    @Test("BrowseView with multiple tabs")
    func browseViewWithMultipleTabs() {
        let state = makeConnectedState()
        let shares1 = UserShares(
            username: "alice",
            folders: PreviewData.sampleFolderStructure,
            isLoading: false
        )
        let shares2 = UserShares(username: "bob", isLoading: true)
        let shares3 = UserShares(username: "charlie", isLoading: false, error: "User is offline")
        state.browseState.browses = [shares1, shares2, shares3]
        state.browseState.currentUser = "alice"
        renderView(
            BrowseView()
                .environment(\.appState, state)
        )
    }

    @Test("BrowseView loading state")
    func browseViewLoading() {
        let state = makeConnectedState()
        let shares = UserShares(username: "loadinguser", isLoading: true)
        state.browseState.browses.append(shares)
        state.browseState.currentUser = "loadinguser"
        renderView(
            BrowseView()
                .environment(\.appState, state)
        )
    }

    @Test("BrowseView error state")
    func browseViewError() {
        let state = makeConnectedState()
        let shares = UserShares(username: "erroruser", isLoading: false, error: "Connection timed out")
        state.browseState.browses.append(shares)
        state.browseState.currentUser = "erroruser"
        renderView(
            BrowseView()
                .environment(\.appState, state)
        )
    }

    @Test("BrowseView empty shares state")
    func browseViewEmptyShares() {
        let state = makeConnectedState()
        let shares = UserShares(username: "emptyuser", folders: [], isLoading: false)
        state.browseState.browses.append(shares)
        state.browseState.currentUser = "emptyuser"
        renderView(
            BrowseView()
                .environment(\.appState, state)
        )
    }

    @Test("BrowseView with browse history")
    func browseViewWithHistory() {
        let state = makeConnectedState()
        state.browseState.browseHistory = ["alice", "bob", "charlie", "dave", "eve"]
        renderView(
            BrowseView()
                .environment(\.appState, state)
        )
    }

    @Test("BrowseView with current user input shows clear button")
    func browseViewWithCurrentUser() {
        let state = makeConnectedState()
        state.browseState.currentUser = "someuser"
        renderView(
            BrowseView()
                .environment(\.appState, state)
        )
    }

    @Test("BrowseView with folder navigation breadcrumb")
    func browseViewWithFolderPath() {
        let state = makeConnectedState()
        let shares = UserShares(
            username: "musiclover42",
            folders: PreviewData.sampleFolderStructure,
            isLoading: false
        )
        state.browseState.browses.append(shares)
        state.browseState.currentUser = "musiclover42"
        state.browseState.currentFolderPath = "Music\\Albums"
        renderView(
            BrowseView()
                .environment(\.appState, state)
        )
    }

    // MARK: - RoomManagementSheet (621 uncovered)

    @Test("RoomManagementSheet for public room with tickers")
    func roomManagementPublicRoom() {
        let state = makeConnectedState()
        let room = ChatRoom(
            name: "PublicRoom",
            users: ["alice", "bob", "charlie", "dave"],
            isJoined: true,
            isPrivate: false,
            tickers: ["alice": "Listening to jazz", "bob": "afk"]
        )
        renderView(
            RoomManagementSheet(room: room, chatState: state.chatState, isPresented: .constant(true))
                .environment(\.appState, state)
        )
    }

    @Test("RoomManagementSheet for private room as owner with members and operators")
    func roomManagementOwnerView() {
        let state = makeConnectedState()
        // Set up so isOwner returns true
        let room = ChatRoom(
            name: "MyPrivateRoom",
            users: ["previewuser", "alice", "bob", "charlie"],
            isJoined: true,
            isPrivate: true,
            owner: "previewuser",
            operators: ["alice"],
            members: ["alice", "bob", "charlie"]
        )
        // Add room to joinedRooms so isOwner/isOperator lookups work
        state.chatState.joinedRooms = [room]
        renderView(
            RoomManagementSheet(room: room, chatState: state.chatState, isPresented: .constant(true))
                .environment(\.appState, state)
        )
    }

    @Test("RoomManagementSheet for private room as operator")
    func roomManagementOperatorView() {
        let state = makeConnectedState()
        let room = ChatRoom(
            name: "OperatedRoom",
            users: ["alice", "previewuser", "bob"],
            isJoined: true,
            isPrivate: true,
            owner: "alice",
            operators: ["previewuser"],
            members: ["previewuser", "bob"]
        )
        state.chatState.joinedRooms = [room]
        renderView(
            RoomManagementSheet(room: room, chatState: state.chatState, isPresented: .constant(true))
                .environment(\.appState, state)
        )
    }

    // MARK: - DiagnosticsSection (520 uncovered)
    // Note: DiagnosticsSection accesses appState.networkClient which triggers lazy init.
    // We render it anyway to cover the view body — it will show the default disconnected state.

    @Test("DiagnosticsSection renders with default state")
    func diagnosticsSectionDefault() {
        let state = makeConnectedState()
        renderView(
            ScrollView {
                DiagnosticsSection()
                    .padding()
            }
            .environment(\.appState, state)
        )
    }

    // MARK: - SearchView (515 uncovered)

    @Test("SearchView with active search tabs and results")
    func searchViewWithTabs() {
        let state = makeConnectedState()
        let token1 = UInt32(1)
        let token2 = UInt32(2)
        state.searchState.searchQuery = "pink floyd"
        state.searchState.startSearch(token: token1)
        state.searchState.addResults([
            SearchResult(username: "user1", filename: "Music\\Pink Floyd\\Time.flac", size: 45_000_000, bitrate: 1411, duration: 413, freeSlots: true, queueLength: 0),
            SearchResult(username: "user2", filename: "Music\\Pink Floyd\\Time.mp3", size: 8_500_000, bitrate: 320, duration: 413, freeSlots: false, queueLength: 5),
            SearchResult(username: "user3", filename: "Music\\Pink Floyd\\Money.flac", size: 50_000_000, bitrate: 1411, duration: 382, sampleRate: 96000, bitDepth: 24, freeSlots: true, queueLength: 0),
        ], forToken: token1)
        state.searchState.markSearchComplete(token: token1)

        state.searchState.searchQuery = "radiohead"
        state.searchState.startSearch(token: token2)

        renderView(
            SearchView()
                .environment(\.appState, state)
        )
    }

    @Test("SearchView searching state with no results yet")
    func searchViewSearching() {
        let state = makeConnectedState()
        let token = UInt32(10)
        state.searchState.searchQuery = "boards of canada"
        state.searchState.startSearch(token: token)
        renderView(
            SearchView()
                .environment(\.appState, state)
        )
    }

    @Test("SearchView with completed empty search (no results)")
    func searchViewNoResults() {
        let state = makeConnectedState()
        let token = UInt32(20)
        state.searchState.searchQuery = "xyznonexistent12345"
        state.searchState.startSearch(token: token)
        state.searchState.markSearchComplete(token: token)
        renderView(
            SearchView()
                .environment(\.appState, state)
        )
    }

    @Test("SearchView with selection mode active")
    func searchViewSelectionMode() {
        let state = makeConnectedState()
        let token = UInt32(30)
        state.searchState.searchQuery = "ambient"
        state.searchState.startSearch(token: token)
        let result1 = SearchResult(username: "user1", filename: "Music\\Ambient\\Track.flac", size: 45_000_000, bitrate: 1411, duration: 300, freeSlots: true, queueLength: 0)
        let result2 = SearchResult(username: "user2", filename: "Music\\Ambient\\Song.mp3", size: 8_000_000, bitrate: 320, duration: 240, freeSlots: true, queueLength: 0)
        state.searchState.addResults([result1, result2], forToken: token)
        state.searchState.isSelectionMode = true
        state.searchState.selectedResults.insert(result1.id)
        renderView(
            SearchView()
                .environment(\.appState, state)
        )
    }

    @Test("SearchView with active filters showing filter count")
    func searchViewWithFilters() {
        let state = makeConnectedState()
        let token = UInt32(40)
        state.searchState.searchQuery = "jazz"
        state.searchState.startSearch(token: token)
        state.searchState.addResults([
            SearchResult(username: "user1", filename: "Music\\Jazz\\Track.flac", size: 45_000_000, bitrate: 1411, duration: 300, freeSlots: true, queueLength: 0),
        ], forToken: token)
        state.searchState.filterMinBitrate = 320
        state.searchState.filterFreeSlotOnly = true
        renderView(
            SearchView()
                .environment(\.appState, state)
        )
    }

    @Test("SearchView with search history")
    func searchViewWithHistory() {
        let state = makeConnectedState()
        state.searchState.searchHistory = ["pink floyd", "radiohead", "boards of canada", "aphex twin", "autechre"]
        renderView(
            SearchView()
                .environment(\.appState, state)
        )
    }

    // MARK: - SearchFilterBar and SearchFilterPanel

    @Test("SearchFilterBar with active filters shows count and clear button")
    func searchFilterBarActive() {
        let state = makeConnectedState()
        state.searchState.filterMinBitrate = 320
        state.searchState.filterExtensions = ["mp3"]
        state.searchState.filterFreeSlotOnly = true
        renderView(
            SearchFilterBar(searchState: state.searchState)
                .environment(\.appState, state)
        )
    }

    @Test("SearchFilterBar with FLAC preset active")
    func searchFilterBarFlacPreset() {
        let state = makeConnectedState()
        state.searchState.applyPreset(.flac)
        renderView(
            SearchFilterBar(searchState: state.searchState)
                .environment(\.appState, state)
        )
    }

    @Test("SearchFilterPanel renders with all filter sections")
    func searchFilterPanelFull() {
        let state = makeConnectedState()
        state.searchState.showFilters = true
        state.searchState.filterExtensions = ["flac", "wav"]
        state.searchState.filterMinBitrate = 320
        state.searchState.filterMinSampleRate = 44100
        state.searchState.filterMinBitDepth = 16
        state.searchState.filterFreeSlotOnly = true
        renderView(
            SearchFilterPanel(searchState: state.searchState)
                .environment(\.appState, state)
        )
    }

    // MARK: - UpdateSettingsSection (429 uncovered)

    @Test("UpdateSettingsSection default state")
    func updateSettingsDefault() {
        let state = makeConnectedState()
        renderView(
            ScrollView {
                UpdateSettingsSection(updateState: state.updateState)
                    .padding()
            }
            .environment(\.appState, state)
        )
    }

    @Test("UpdateSettingsSection with update available")
    func updateSettingsWithUpdate() {
        let state = makeConnectedState()
        state.updateState.updateAvailable = true
        state.updateState.latestVersion = "v2.0.0"
        state.updateState.releaseNotes = "New feature: improved search\nBug fix: connection stability"
        state.updateState.latestReleaseURL = URL(string: "https://github.com/example/releases/tag/v2.0.0")
        state.updateState.lastCheckDate = Date().addingTimeInterval(-3600)
        renderView(
            ScrollView {
                UpdateSettingsSection(updateState: state.updateState)
                    .padding()
            }
            .environment(\.appState, state)
        )
    }

    @Test("UpdateSettingsSection with error message")
    func updateSettingsWithError() {
        let state = makeConnectedState()
        state.updateState.errorMessage = "Network request failed: timeout"
        state.updateState.lastCheckDate = Date().addingTimeInterval(-7200)
        renderView(
            ScrollView {
                UpdateSettingsSection(updateState: state.updateState)
                    .padding()
            }
            .environment(\.appState, state)
        )
    }

    @Test("UpdateSettingsSection with checking state")
    func updateSettingsChecking() {
        let state = makeConnectedState()
        state.updateState.isChecking = true
        renderView(
            ScrollView {
                UpdateSettingsSection(updateState: state.updateState)
                    .padding()
            }
            .environment(\.appState, state)
        )
    }

    @Test("UpdateSettingsSection up to date after check")
    func updateSettingsUpToDate() {
        let state = makeConnectedState()
        state.updateState.lastCheckDate = Date().addingTimeInterval(-60)
        state.updateState.updateAvailable = false
        state.updateState.isChecking = false
        state.updateState.errorMessage = nil
        renderView(
            ScrollView {
                UpdateSettingsSection(updateState: state.updateState)
                    .padding()
            }
            .environment(\.appState, state)
        )
    }

    @Test("UpdateSettingsSection downloading state")
    func updateSettingsDownloading() {
        let state = makeConnectedState()
        state.updateState.updateAvailable = true
        state.updateState.latestVersion = "v2.0.0"
        state.updateState.isDownloading = true
        state.updateState.downloadProgress = 0.65
        state.updateState.lastCheckDate = Date()
        renderView(
            ScrollView {
                UpdateSettingsSection(updateState: state.updateState)
                    .padding()
            }
            .environment(\.appState, state)
        )
    }

    // MARK: - PrivacySettingsSection (428 uncovered)

    @Test("PrivacySettingsSection with blocked users")
    func privacySettingsWithBlockedUsers() {
        let state = makeConnectedState()
        state.socialState.blockedUsers = [
            BlockedUser(username: "spammer1", reason: "Spam", dateBlocked: Date()),
            BlockedUser(username: "leecher2", reason: nil, dateBlocked: Date().addingTimeInterval(-86400)),
            BlockedUser(username: "troll3", reason: "Abusive messages", dateBlocked: Date().addingTimeInterval(-172800)),
        ]
        renderView(
            ScrollView {
                PrivacySettingsSection(settings: state.settings)
                    .padding()
            }
            .environment(\.appState, state)
        )
    }

    @Test("PrivacySettingsSection with leech detection enabled and detected leeches")
    func privacySettingsLeechDetection() {
        let state = makeConnectedState()
        state.socialState.leechSettings.enabled = true
        state.socialState.leechSettings.action = .message
        state.socialState.leechSettings.customMessage = "Please share some files before downloading."
        state.socialState.detectedLeeches = ["leech_user1", "no_shares_bob", "freeloader99"]
        state.socialState.warnedLeeches = ["leech_user1"]
        renderView(
            ScrollView {
                PrivacySettingsSection(settings: state.settings)
                    .padding()
            }
            .environment(\.appState, state)
        )
    }

    @Test("PrivacySettingsSection with leech detection enabled but no leeches")
    func privacySettingsLeechNoDetections() {
        let state = makeConnectedState()
        state.socialState.leechSettings.enabled = true
        state.socialState.leechSettings.action = .deny
        renderView(
            ScrollView {
                PrivacySettingsSection(settings: state.settings)
                    .padding()
            }
            .environment(\.appState, state)
        )
    }

    @Test("PrivacySettingsSection with all settings toggled")
    func privacySettingsAllToggled() {
        let state = makeConnectedState()
        state.settings.showOnlineStatus = false
        state.settings.allowBrowsing = false
        state.settings.respondToSearches = false
        renderView(
            ScrollView {
                PrivacySettingsSection(settings: state.settings)
                    .padding()
            }
            .environment(\.appState, state)
        )
    }

    // MARK: - RoomBrowserSheet (311 uncovered)

    @Test("RoomBrowserSheet with rooms loaded")
    func roomBrowserWithRooms() {
        let state = makeConnectedState()
        state.chatState.availableRooms = [
            ChatRoom(name: "NicotineHelp", users: Array(repeating: "user", count: 150), isJoined: false),
            ChatRoom(name: "FLAC", users: Array(repeating: "user", count: 85), isJoined: false),
            ChatRoom(name: "Jazz", users: Array(repeating: "user", count: 40), isJoined: false),
        ]
        state.chatState.joinedRooms = [
            ChatRoom(name: "FLAC", users: ["alice", "bob"], isJoined: true),
        ]
        state.chatState.isLoadingRooms = false
        renderView(
            RoomBrowserSheet(chatState: state.chatState, isPresented: .constant(true))
                .environment(\.appState, state)
        )
    }

    @Test("RoomBrowserSheet loading state")
    func roomBrowserLoading() {
        let state = makeConnectedState()
        state.chatState.isLoadingRooms = true
        renderView(
            RoomBrowserSheet(chatState: state.chatState, isPresented: .constant(true))
                .environment(\.appState, state)
        )
    }

    @Test("RoomBrowserSheet empty filtered results")
    func roomBrowserEmpty() {
        let state = makeConnectedState()
        state.chatState.isLoadingRooms = false
        state.chatState.availableRooms = []
        renderView(
            RoomBrowserSheet(chatState: state.chatState, isPresented: .constant(true))
                .environment(\.appState, state)
        )
    }

    @Test("RoomBrowserSheet with create room section visible")
    func roomBrowserCreateRoom() {
        let state = makeConnectedState()
        state.chatState.showCreateRoom = true
        state.chatState.createRoomName = "NewRoom"
        state.chatState.isLoadingRooms = false
        renderView(
            RoomBrowserSheet(chatState: state.chatState, isPresented: .constant(true))
                .environment(\.appState, state)
        )
    }

    @Test("RoomBrowserSheet create room with error")
    func roomBrowserCreateRoomError() {
        let state = makeConnectedState()
        state.chatState.showCreateRoom = true
        state.chatState.createRoomError = "Cannot create room 'test'"
        state.chatState.isLoadingRooms = false
        renderView(
            RoomBrowserSheet(chatState: state.chatState, isPresented: .constant(true))
                .environment(\.appState, state)
        )
    }

    @Test("RoomBrowserSheet with owned private rooms")
    func roomBrowserOwnedRooms() {
        let state = makeConnectedState()
        state.chatState.ownedPrivateRooms = [
            ChatRoom(name: "MyPrivateRoom", users: ["alice"], isJoined: false, isPrivate: true, owner: "previewuser"),
        ]
        state.chatState.roomListTab = .owned
        state.chatState.isLoadingRooms = false
        renderView(
            RoomBrowserSheet(chatState: state.chatState, isPresented: .constant(true))
                .environment(\.appState, state)
        )
    }

    @Test("RoomBrowserSheet on private tab with no rooms shows hint")
    func roomBrowserPrivateTabEmpty() {
        let state = makeConnectedState()
        state.chatState.roomListTab = .private
        state.chatState.memberPrivateRooms = []
        state.chatState.isLoadingRooms = false
        renderView(
            RoomBrowserSheet(chatState: state.chatState, isPresented: .constant(true))
                .environment(\.appState, state)
        )
    }

    // MARK: - TransfersView (282 uncovered)

    @Test("TransfersView with uploads")
    func transfersViewWithUploads() {
        let state = makeConnectedState()
        state.transferState.uploads = [
            Transfer(
                username: "bob",
                filename: "Music\\Upload.mp3",
                size: 8_000_000,
                direction: .upload,
                status: .transferring,
                bytesTransferred: 4_000_000,
                speed: 500_000
            ),
            Transfer(
                username: "charlie",
                filename: "Music\\Another.flac",
                size: 40_000_000,
                direction: .upload,
                status: .queued,
                queuePosition: 1
            ),
        ]
        renderView(
            TransfersView()
                .environment(\.appState, state)
        )
    }

    @Test("TransfersView with history")
    func transfersViewWithHistory() {
        let state = makeConnectedState()
        state.transferState.history = [
            TransferHistoryItem(
                id: "hist-1",
                timestamp: Date().addingTimeInterval(-3600),
                filename: "Music\\Albums\\Artist\\01 - Track.flac",
                username: "alice",
                size: 45_000_000,
                duration: 36.0,
                averageSpeed: 1_250_000,
                isDownload: true,
                localPath: nil
            ),
            TransferHistoryItem(
                id: "hist-2",
                timestamp: Date().addingTimeInterval(-7200),
                filename: "Music\\Song.mp3",
                username: "bob",
                size: 8_000_000,
                duration: 10.0,
                averageSpeed: 800_000,
                isDownload: false,
                localPath: nil
            ),
        ]
        renderView(
            TransfersView()
                .environment(\.appState, state)
        )
    }

    @Test("TransfersView with completed and failed downloads showing clear menu")
    func transfersViewCompletedAndFailed() {
        let state = makeConnectedState()
        state.transferState.downloads = [
            Transfer(
                username: "alice",
                filename: "Music\\Done.flac",
                size: 45_000_000,
                direction: .download,
                status: .completed,
                bytesTransferred: 45_000_000
            ),
            Transfer(
                username: "bob",
                filename: "Music\\Failed.mp3",
                size: 8_000_000,
                direction: .download,
                status: .failed,
                error: "Connection refused"
            ),
            Transfer(
                username: "charlie",
                filename: "Music\\Active.flac",
                size: 30_000_000,
                direction: .download,
                status: .transferring,
                bytesTransferred: 15_000_000,
                speed: 1_000_000
            ),
        ]
        renderView(
            TransfersView()
                .environment(\.appState, state)
        )
    }

    @Test("TransfersView with download speed stats")
    func transfersViewWithSpeeds() {
        let state = makeConnectedState()
        state.transferState.downloads = [
            Transfer(
                username: "alice",
                filename: "Music\\Track.flac",
                size: 45_000_000,
                direction: .download,
                status: .transferring,
                bytesTransferred: 22_500_000,
                speed: 1_250_000
            ),
        ]
        state.transferState.uploads = [
            Transfer(
                username: "bob",
                filename: "Music\\Upload.mp3",
                size: 8_000_000,
                direction: .upload,
                status: .transferring,
                bytesTransferred: 4_000_000,
                speed: 500_000
            ),
        ]
        renderView(
            TransfersView()
                .environment(\.appState, state)
        )
    }

    // MARK: - SearchResultRow (210 uncovered)

    @Test("SearchResultRow renders lossless hi-res file with sample rate and bit depth")
    func searchResultRowHiRes() {
        let state = makeConnectedState()
        let result = SearchResult(
            username: "audiophile",
            filename: "Music\\Albums\\Artist\\01 - Track.flac",
            size: 120_000_000,
            bitrate: 4608,
            duration: 413,
            sampleRate: 192000,
            bitDepth: 24,
            freeSlots: true,
            uploadSpeed: 2_000_000,
            queueLength: 0
        )
        renderView(
            SearchResultRow(result: result)
                .environment(\.appState, state)
        )
    }

    @Test("SearchResultRow renders private file")
    func searchResultRowPrivate() {
        let state = makeConnectedState()
        let result = SearchResult(
            username: "buddy",
            filename: "Private\\Secret\\Track.mp3",
            size: 8_000_000,
            bitrate: 256,
            duration: 240,
            freeSlots: true,
            queueLength: 0,
            isPrivate: true
        )
        renderView(
            SearchResultRow(result: result)
                .environment(\.appState, state)
        )
    }

    @Test("SearchResultRow renders non-audio file")
    func searchResultRowNonAudio() {
        let state = makeConnectedState()
        let result = SearchResult(
            username: "uploader",
            filename: "Documents\\readme.txt",
            size: 1_500,
            freeSlots: true,
            queueLength: 0
        )
        renderView(
            SearchResultRow(result: result)
                .environment(\.appState, state)
        )
    }

    @Test("SearchResultRow renders medium bitrate file")
    func searchResultRowMediumBitrate() {
        let state = makeConnectedState()
        let result = SearchResult(
            username: "user",
            filename: "Music\\Track.mp3",
            size: 6_000_000,
            bitrate: 192,
            duration: 240,
            freeSlots: false,
            queueLength: 10
        )
        renderView(
            SearchResultRow(result: result)
                .environment(\.appState, state)
        )
    }

    @Test("SearchResultRow renders from ignored user")
    func searchResultRowIgnoredUser() {
        let state = makeConnectedState()
        state.socialState.ignoredUsers = [
            IgnoredUser(username: "ignoredperson", reason: "annoying", dateIgnored: Date()),
        ]
        let result = SearchResult(
            username: "ignoredperson",
            filename: "Music\\Track.flac",
            size: 45_000_000,
            bitrate: 1411,
            duration: 300,
            freeSlots: true,
            queueLength: 0
        )
        renderView(
            SearchResultRow(result: result)
                .environment(\.appState, state)
        )
    }

    @Test("SearchResultRow renders 48kHz sample rate file")
    func searchResultRow48kHz() {
        let state = makeConnectedState()
        let result = SearchResult(
            username: "user",
            filename: "Music\\Track.flac",
            size: 60_000_000,
            bitrate: 2304,
            duration: 300,
            sampleRate: 48000,
            bitDepth: 24,
            freeSlots: true,
            queueLength: 0
        )
        renderView(
            SearchResultRow(result: result)
                .environment(\.appState, state)
        )
    }

    // MARK: - FileTreeRow (193 uncovered)

    @Test("FileTreeRow renders expanded directory with children")
    func fileTreeRowExpandedDir() {
        let state = makeConnectedState()
        let folder = SharedFile(
            filename: "Music\\Albums\\Pink Floyd",
            isDirectory: true,
            children: [
                SharedFile(filename: "Music\\Albums\\Pink Floyd\\01 - Speak to Me.flac", size: 15_234_567, bitrate: 1411, duration: 68),
                SharedFile(filename: "Music\\Albums\\Pink Floyd\\02 - Breathe.flac", size: 24_567_890, bitrate: 1411, duration: 163),
            ],
            fileCount: 2
        )
        state.browseState.expandedFolders.insert(folder.id)
        renderView(
            FileTreeRow(file: folder, depth: 1, browseState: state.browseState, username: "testuser")
                .environment(\.appState, state)
        )
    }

    @Test("FileTreeRow renders deeply nested file")
    func fileTreeRowDeepNesting() {
        let state = makeConnectedState()
        let file = SharedFile(
            filename: "Music\\Albums\\Artist\\Album\\Disc 1\\01 - Track.flac",
            size: 45_000_000,
            bitrate: 1411,
            duration: 413
        )
        renderView(
            FileTreeRow(file: file, depth: 5, browseState: state.browseState, username: "testuser")
                .environment(\.appState, state)
        )
    }

    @Test("FileTreeRow renders zero depth file")
    func fileTreeRowZeroDepth() {
        let state = makeConnectedState()
        let file = SharedFile(
            filename: "Music\\Track.mp3",
            size: 8_000_000,
            bitrate: 320,
            duration: 240
        )
        renderView(
            FileTreeRow(file: file, depth: 0, browseState: state.browseState, username: "testuser")
                .environment(\.appState, state)
        )
    }

    @Test("FileTreeRow renders folder with zero file count")
    func fileTreeRowFolderNoCount() {
        let state = makeConnectedState()
        let folder = SharedFile(
            filename: "EmptyFolder",
            isDirectory: true,
            children: [],
            fileCount: 0
        )
        renderView(
            FileTreeRow(file: folder, depth: 0, browseState: state.browseState, username: "testuser")
                .environment(\.appState, state)
        )
    }

    // MARK: - UserProfileSheet (120 uncovered)

    @Test("UserProfileSheet renders away user with no interests")
    func userProfileSheetAway() {
        let state = makeConnectedState()
        let profile = UserProfile(
            username: "awayuser",
            description: "",
            totalUploads: 500,
            queueSize: 0,
            hasFreeSlots: true,
            averageSpeed: 500_000,
            sharedFiles: 5000,
            sharedFolders: 100,
            status: .away
        )
        renderView(
            UserProfileSheet(profile: profile)
                .environment(\.appState, state)
        )
    }

    @Test("UserProfileSheet renders offline user who is already a buddy")
    func userProfileSheetBuddy() {
        let state = makeConnectedState()
        state.socialState.buddies = [
            Buddy(username: "mybuddy", status: .offline),
        ]
        let profile = UserProfile(
            username: "mybuddy",
            description: "I share lots of music",
            totalUploads: 10000,
            queueSize: 2,
            hasFreeSlots: false,
            averageSpeed: 2_000_000,
            sharedFiles: 50000,
            sharedFolders: 2000,
            likedInterests: ["jazz", "electronic"],
            hatedInterests: ["country"],
            status: .offline,
            isPrivileged: false
        )
        renderView(
            UserProfileSheet(profile: profile)
                .environment(\.appState, state)
        )
    }

    @Test("UserProfileSheet renders ignored user")
    func userProfileSheetIgnored() {
        let state = makeConnectedState()
        state.socialState.ignoredUsers = [
            IgnoredUser(username: "ignoreduser", reason: "rude", dateIgnored: Date()),
        ]
        let profile = UserProfile(
            username: "ignoreduser",
            description: "Some user",
            status: .online
        )
        renderView(
            UserProfileSheet(profile: profile)
                .environment(\.appState, state)
        )
    }

    // MARK: - ChatView (with rooms and messages)

    @Test("ChatView with selected room showing room icon variants")
    func chatViewWithRoomTypes() {
        let state = makeConnectedState()
        // Public room
        let publicRoom = ChatRoom(
            name: "PublicRoom",
            users: ["alice", "bob"],
            messages: [
                ChatMessage(username: "alice", content: "Hello!", isOwn: false),
            ],
            isJoined: true
        )
        // Private room where user is operator
        let operatedRoom = ChatRoom(
            name: "OperatedRoom",
            users: ["previewuser", "charlie"],
            isJoined: true,
            isPrivate: true,
            owner: "charlie"
        )
        state.chatState.joinedRooms = [publicRoom, operatedRoom]
        state.chatState.operatedRoomNames = ["OperatedRoom"]
        state.chatState.selectRoom("PublicRoom")

        let chat = PrivateChat(
            username: "dave",
            messages: [ChatMessage(username: "dave", content: "Hey!", isOwn: false)],
            isOnline: false
        )
        state.chatState.privateChats = [chat]
        renderView(
            ChatView()
                .environment(\.appState, state)
        )
    }

    @Test("ChatView with selected private chat")
    func chatViewWithPrivateChat() {
        let state = makeConnectedState()
        let chat = PrivateChat(
            username: "alice",
            messages: [
                ChatMessage(username: "alice", content: "Hey there!", isOwn: false),
                ChatMessage(username: "previewuser", content: "Hi Alice!", isOwn: true),
                ChatMessage(username: "alice", content: "How are you?", isOwn: false),
            ],
            isOnline: true
        )
        state.chatState.privateChats = [chat]
        state.chatState.selectPrivateChat("alice")
        renderView(
            ChatView()
                .environment(\.appState, state)
        )
    }

    @Test("ChatView with room having unread messages")
    func chatViewWithUnread() {
        let state = makeConnectedState()
        let room = ChatRoom(name: "NicotineHelp", users: ["a", "b"], unreadCount: 12, isJoined: true)
        let chat = PrivateChat(username: "bob", isOnline: true)
        state.chatState.joinedRooms = [room]
        state.chatState.privateChats = [chat]
        renderView(
            ChatView()
                .environment(\.appState, state)
        )
    }

    // MARK: - MyProfileView (95 uncovered)

    @Test("MyProfileView with interests showing overflow count")
    func myProfileViewManyInterests() {
        let state = makeConnectedState()
        state.socialState.myDescription = "Music lover sharing my collection of jazz, electronic, and ambient."
        state.socialState.myLikes = ["jazz", "electronic", "ambient", "classical", "experimental", "vinyl", "downtempo", "idm"]
        state.socialState.myHates = ["pop", "country", "reggaeton", "mumble rap", "autotune", "overproduced"]
        state.socialState.privilegeTimeRemaining = 86400 * 5
        renderView(
            MyProfileView()
                .environment(\.appState, state)
        )
    }

    @Test("MyProfileView with no privileges")
    func myProfileViewNoPrivileges() {
        let state = makeConnectedState()
        state.socialState.privilegeTimeRemaining = 0
        renderView(
            MyProfileView()
                .environment(\.appState, state)
        )
    }

    // MARK: - WishlistView (136 uncovered)

    @Test("WishlistView with expanded results")
    func wishlistViewWithResults() {
        let state = makeConnectedState()
        let item1 = WishlistItem(query: "ambient electronic", lastSearchedAt: Date().addingTimeInterval(-300), resultCount: 42)
        let item2 = WishlistItem(query: "boards of canada flac", lastSearchedAt: Date().addingTimeInterval(-120), resultCount: 128)
        state.wishlistState.items = [item1, item2]
        state.wishlistState.results[item1.id] = [
            SearchResult(username: "user1", filename: "Music\\Ambient\\Track.flac", size: 45_000_000, bitrate: 1411, duration: 300, freeSlots: true, queueLength: 0),
            SearchResult(username: "user2", filename: "Music\\Ambient\\Song.mp3", size: 8_000_000, bitrate: 320, duration: 240, freeSlots: true, queueLength: 0),
        ]
        state.wishlistState.expandedItemId = item1.id
        renderView(
            WishlistView()
                .environment(\.appState, state)
        )
    }

    @Test("WishlistView with new query input showing clear button")
    func wishlistViewWithInput() {
        let state = makeConnectedState()
        state.wishlistState.newQuery = "pink floyd"
        state.wishlistState.items = [
            WishlistItem(query: "existing search", resultCount: 10),
        ]
        renderView(
            WishlistView()
                .environment(\.appState, state)
        )
    }

    @Test("WishlistItemRow with results count badge")
    func wishlistItemRowWithResults() {
        let state = makeConnectedState()
        let item = WishlistItem(query: "jazz vinyl", lastSearchedAt: Date(), resultCount: 42)
        state.wishlistState.items = [item]
        state.wishlistState.results[item.id] = [
            SearchResult(username: "user", filename: "Music\\Jazz.flac", size: 45_000_000, bitrate: 1411, duration: 300, freeSlots: true, queueLength: 0),
        ]
        renderView(
            WishlistItemRow(item: item)
                .environment(\.appState, state)
        )
    }

    // MARK: - SharesSettingsSection (132 uncovered)

    @Test("SharesSettingsSection renders default state")
    func sharesSettingsDefault() {
        let state = makeConnectedState()
        renderView(
            ScrollView {
                SharesSettingsSection(settings: state.settings)
                    .padding()
            }
            .environment(\.appState, state)
        )
    }

    // MARK: - HistoryRow (118 uncovered)

    @Test("HistoryRow renders download with local file that does not exist")
    func historyRowNoLocalFile() {
        let state = makeConnectedState()
        let item = TransferHistoryItem(
            id: "hist-nofile",
            timestamp: Date().addingTimeInterval(-1800),
            filename: "Music\\Albums\\Artist\\Track.flac",
            username: "testuser",
            size: 45_000_000,
            duration: 30.0,
            averageSpeed: 1_500_000,
            isDownload: true,
            localPath: URL(fileURLWithPath: "/nonexistent/path/file.flac")
        )
        renderView(
            HistoryRow(item: item)
                .environment(\.appState, state)
        )
    }

    // MARK: - BuddyRowView (107 uncovered)

    @Test("BuddyRowView renders away buddy with stats")
    func buddyRowViewAway() {
        let state = makeConnectedState()
        let buddy = Buddy(
            username: "jazzfan",
            status: .away,
            isPrivileged: false,
            averageSpeed: 500_000,
            fileCount: 3200,
            countryCode: "GB"
        )
        renderView(
            BuddyRowView(buddy: buddy)
                .environment(\.appState, state)
        )
    }

    @Test("BuddyRowView renders buddy with no stats")
    func buddyRowViewNoStats() {
        let state = makeConnectedState()
        let buddy = Buddy(
            username: "newuser",
            status: .online
        )
        renderView(
            BuddyRowView(buddy: buddy)
                .environment(\.appState, state)
        )
    }

    @Test("BuddyRowView renders ignored buddy")
    func buddyRowViewIgnored() {
        let state = makeConnectedState()
        state.socialState.ignoredUsers = [
            IgnoredUser(username: "ignoredbuddy", reason: nil, dateIgnored: Date()),
        ]
        let buddy = Buddy(
            username: "ignoredbuddy",
            status: .online,
            averageSpeed: 100_000,
            fileCount: 500
        )
        renderView(
            BuddyRowView(buddy: buddy)
                .environment(\.appState, state)
        )
    }

    // MARK: - SearchActivityView (226 uncovered)

    @Test("SearchActivityView with recent events")
    func searchActivityViewWithEvents() {
        let state = makeConnectedState()
        let tracker = SearchState.activityTracker
        tracker.recordOutgoingSearch(query: "pink floyd")
        tracker.recordSearchResults(query: "pink floyd", count: 45)
        tracker.recordOutgoingSearch(query: "radiohead ok computer")
        tracker.recordIncomingSearch(username: "alice", query: "boards of canada", matchCount: 3)
        tracker.recordIncomingSearch(username: "bob", query: "aphex twin flac", matchCount: 12)
        renderView(
            SearchActivityView()
                .environment(\.appState, state)
        )
    }

    @Test("SearchActivityView empty state")
    func searchActivityViewEmpty() {
        let state = makeConnectedState()
        renderView(
            SearchActivityView()
                .environment(\.appState, state)
        )
    }

    @Test("SearchTimelineView with events")
    func searchTimelineViewWithEvents() {
        let events = [
            SearchActivityState.SearchEvent(timestamp: Date(), query: "test", direction: .outgoing),
            SearchActivityState.SearchEvent(timestamp: Date().addingTimeInterval(-60), query: "test2", direction: .incoming, resultsCount: 5),
        ]
        renderView(
            SearchTimelineView(events: events)
                .frame(width: 500, height: 60)
        )
    }

    @Test("SearchEventRow renders outgoing with results count")
    func searchEventRowOutgoing() {
        let event = SearchActivityState.SearchEvent(timestamp: Date(), query: "pink floyd", direction: .outgoing, resultsCount: 42)
        renderView(
            SearchEventRow(event: event)
        )
    }

    @Test("SearchEventRow renders incoming without results count")
    func searchEventRowIncoming() {
        let event = SearchActivityState.SearchEvent(timestamp: Date(), query: "jazz", direction: .incoming)
        renderView(
            SearchEventRow(event: event)
        )
    }

    @Test("IncomingSearchRow renders")
    func incomingSearchRow() {
        let search = SearchActivityState.IncomingSearch(timestamp: Date(), username: "jazzfan42", query: "miles davis kind of blue flac", matchCount: 8)
        renderView(
            IncomingSearchRow(search: search)
        )
    }

    // MARK: - SidebarConsoleView (162 uncovered)

    @Test("SidebarConsoleView with activity events")
    func sidebarConsoleViewWithEvents() {
        let log = ActivityLog.shared
        log.logSearchStarted(query: "pink floyd")
        log.logPeerConnected(username: "alice", ip: "192.168.1.100")
        log.logDownloadStarted(filename: "Track.flac", from: "alice")
        log.logDownloadCompleted(filename: "Track.flac")
        log.logInfo("Test info message")
        renderView(
            SidebarConsoleView()
        )
    }

    // MARK: - StandardTabBar (127 uncovered, 0%)

    @Test("StandardTabBar renders with badge counts")
    func standardTabBarWithBadges() {
        renderView(
            StandardTabBar(
                selection: .constant(TransfersView.TransferTab.downloads),
                tabs: TransfersView.TransferTab.allCases
            ) { tab in
                switch tab {
                case .downloads: return 3
                case .uploads: return 0
                case .history: return 5
                }
            }
        )
    }

    @Test("StandardTabBar renders with different selection")
    func standardTabBarDifferentSelection() {
        renderView(
            StandardTabBar(
                selection: .constant(TransfersView.TransferTab.history),
                tabs: TransfersView.TransferTab.allCases
            ) { tab in
                switch tab {
                case .downloads: return 0
                case .uploads: return 2
                case .history: return 10
                }
            }
        )
    }

    @Test("StandardTabBar renders with no badges")
    func standardTabBarNoBadges() {
        renderView(
            StandardTabBar(
                selection: .constant(TransfersView.TransferTab.uploads),
                tabs: TransfersView.TransferTab.allCases
            )
        )
    }

    // MARK: - RecordingSearchResults (209 uncovered)

    @Test("RecordingSearchResults with results")
    func recordingSearchResultsPopulated() {
        let metadataState = MetadataState()
        metadataState.detectedArtist = "Pink Floyd"
        metadataState.detectedTitle = "Time"
        metadataState.searchResults = [
            MusicBrainzClient.MBRecording(
                id: "rec-1",
                title: "Time",
                artist: "Pink Floyd",
                artistMBID: "83d91898-7763-47d7-b03b-faaee37e1009",
                releaseTitle: "The Dark Side of the Moon",
                releaseMBID: "release-1",
                duration: 413000,
                score: 95
            ),
            MusicBrainzClient.MBRecording(
                id: "rec-2",
                title: "Time",
                artist: "Pink Floyd",
                artistMBID: "83d91898-7763-47d7-b03b-faaee37e1009",
                releaseTitle: "Pulse",
                releaseMBID: "release-2",
                duration: 450000,
                score: 78
            ),
            MusicBrainzClient.MBRecording(
                id: "rec-3",
                title: "Time",
                artist: "Alan Parsons",
                artistMBID: nil,
                releaseTitle: nil,
                releaseMBID: nil,
                duration: 300000,
                score: 45
            ),
        ]
        metadataState.selectedRecording = metadataState.searchResults.first
        renderView(
            RecordingSearchResults(state: metadataState)
                .frame(width: 400, height: 300)
        )
    }

    @Test("RecordingSearchResults empty state")
    func recordingSearchResultsEmpty() {
        let metadataState = MetadataState()
        metadataState.detectedArtist = ""
        metadataState.detectedTitle = ""
        metadataState.searchResults = []
        renderView(
            RecordingSearchResults(state: metadataState)
                .frame(width: 400, height: 300)
        )
    }

    @Test("RecordingSearchResults searching state")
    func recordingSearchResultsSearching() {
        let metadataState = MetadataState()
        metadataState.detectedArtist = "Pink Floyd"
        metadataState.detectedTitle = "Time"
        metadataState.isSearching = true
        renderView(
            RecordingSearchResults(state: metadataState)
                .frame(width: 400, height: 300)
        )
    }

    @Test("RecordingSearchResults with error")
    func recordingSearchResultsError() {
        let metadataState = MetadataState()
        metadataState.searchError = "Network request failed"
        metadataState.searchResults = []
        renderView(
            RecordingSearchResults(state: metadataState)
                .frame(width: 400, height: 300)
        )
    }

    @Test("RecordingRow renders with low score")
    func recordingRowLowScore() {
        let metadataState = MetadataState()
        let recording = MusicBrainzClient.MBRecording(
            id: "rec-low",
            title: "Time",
            artist: "Unknown Artist",
            artistMBID: nil,
            releaseTitle: nil,
            releaseMBID: nil,
            duration: nil,
            score: 30
        )
        renderView(
            RecordingRow(recording: recording, state: metadataState)
        )
    }

    @Test("RecordingRow renders with medium score")
    func recordingRowMediumScore() {
        let metadataState = MetadataState()
        let recording = MusicBrainzClient.MBRecording(
            id: "rec-med",
            title: "Time",
            artist: "Pink Floyd",
            artistMBID: nil,
            releaseTitle: "Compilation",
            releaseMBID: nil,
            duration: 400000,
            score: 55
        )
        renderView(
            RecordingRow(recording: recording, state: metadataState)
        )
    }

    // MARK: - CoverArtEditView (99 uncovered)

    @Test("CoverArtEditView empty state")
    func coverArtEditViewEmpty() {
        let metadataState = MetadataState()
        renderView(
            CoverArtEditView(state: metadataState)
                .frame(width: 300)
        )
    }

    @Test("CoverArtEditView loading state")
    func coverArtEditViewLoading() {
        let metadataState = MetadataState()
        metadataState.isLoadingCoverArt = true
        renderView(
            CoverArtEditView(state: metadataState)
                .frame(width: 300)
        )
    }

    @Test("CoverArtEditView with cover art data from MusicBrainz")
    func coverArtEditViewWithData() {
        let metadataState = MetadataState()
        // Create a minimal 1x1 PNG image data
        metadataState.coverArtData = createMinimalPNGData()
        metadataState.coverArtSource = .musicBrainz
        renderView(
            CoverArtEditView(state: metadataState)
                .frame(width: 300)
        )
    }

    @Test("CoverArtEditView with manual cover art")
    func coverArtEditViewManual() {
        let metadataState = MetadataState()
        metadataState.coverArtData = createMinimalPNGData()
        metadataState.coverArtSource = .manual
        renderView(
            CoverArtEditView(state: metadataState)
                .frame(width: 300)
        )
    }

    @Test("CoverArtEditView with embedded source")
    func coverArtEditViewEmbedded() {
        let metadataState = MetadataState()
        metadataState.coverArtData = createMinimalPNGData()
        metadataState.coverArtSource = .embedded
        renderView(
            CoverArtEditView(state: metadataState)
                .frame(width: 300)
        )
    }

    // MARK: - Additional TransferRow states

    @Test("TransferRow renders connecting download")
    func transferRowConnecting() {
        let state = makeConnectedState()
        let transfer = Transfer(
            username: "alice",
            filename: "Music\\Track.flac",
            size: 45_000_000,
            direction: .download,
            status: .connecting
        )
        renderView(
            TransferRow(transfer: transfer, onCancel: {}, onRetry: {}, onRemove: {})
                .environment(\.appState, state)
        )
    }

    @Test("TransferRow renders cancelled download")
    func transferRowCancelled() {
        let state = makeConnectedState()
        let transfer = Transfer(
            username: "alice",
            filename: "Music\\Track.flac",
            size: 45_000_000,
            direction: .download,
            status: .cancelled
        )
        renderView(
            TransferRow(transfer: transfer, onCancel: {}, onRetry: {}, onRemove: {})
                .environment(\.appState, state)
        )
    }

    // MARK: - Additional HistoryRow states

    @Test("HistoryRow renders recent upload")
    func historyRowRecentUpload() {
        let state = makeConnectedState()
        let item = TransferHistoryItem(
            id: "hist-upload-recent",
            timestamp: Date().addingTimeInterval(-120),
            filename: "Music\\Singles\\Song.mp3",
            username: "charlie",
            size: 8_000_000,
            duration: 8.0,
            averageSpeed: 1_000_000,
            isDownload: false,
            localPath: nil
        )
        renderView(
            HistoryRow(item: item)
                .environment(\.appState, state)
        )
    }

    // MARK: - ChatRoomContentView additional branches

    @Test("ChatRoomContentView with many messages and tickers")
    func chatRoomContentViewDetailed() {
        let state = makeConnectedState()
        let room = ChatRoom(
            name: "TestRoom",
            users: ["alice", "bob", "charlie", "dave", "eve"],
            messages: [
                ChatMessage(username: "", content: "alice joined the room", isSystem: true),
                ChatMessage(username: "alice", content: "Hello everyone!", isOwn: false),
                ChatMessage(username: "bob", content: "What's up?", isOwn: false),
                ChatMessage(username: "previewuser", content: "Hey!", isOwn: true),
                ChatMessage(username: "charlie", content: "Nice to see everyone here", isOwn: false),
                ChatMessage(username: "", content: "dave left the room", isSystem: true),
                ChatMessage(username: "alice", content: "Anyone have any good jazz recommendations?", isOwn: false),
                ChatMessage(username: "previewuser", content: "Check out Kind of Blue by Miles Davis", isOwn: true),
            ],
            isJoined: true,
            tickers: ["alice": "Listening to jazz", "bob": "brb", "charlie": "Sharing 50000 files"]
        )
        renderView(
            ChatRoomContentView(room: room, chatState: state.chatState, appState: state)
                .environment(\.appState, state)
        )
    }

    // MARK: - Sidebar with various selections

    @Test("Sidebar with user sidebar item")
    func sidebarRowUser() {
        let state = makeConnectedState()
        renderView(
            SidebarRow(item: .user("alice"))
                .environment(\.appState, state)
        )
    }

    @Test("Sidebar with room sidebar item")
    func sidebarRowRoom() {
        let state = makeConnectedState()
        renderView(
            SidebarRow(item: .room("NicotineHelp"))
                .environment(\.appState, state)
        )
    }

    // MARK: - Helpers

    /// Create a minimal valid PNG image data (1x1 pixel, red)
    private func createMinimalPNGData() -> Data {
        // Minimal 1x1 red PNG
        let bytes: [UInt8] = [
            0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG signature
            0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, // IHDR chunk
            0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
            0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53,
            0xDE, 0x00, 0x00, 0x00, 0x0C, 0x49, 0x44, 0x41, // IDAT chunk
            0x54, 0x08, 0xD7, 0x63, 0xF8, 0xCF, 0xC0, 0x00,
            0x00, 0x00, 0x02, 0x00, 0x01, 0xE2, 0x21, 0xBC,
            0x33, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, // IEND chunk
            0x44, 0xAE, 0x42, 0x60, 0x82,
        ]
        return Data(bytes)
    }
}
