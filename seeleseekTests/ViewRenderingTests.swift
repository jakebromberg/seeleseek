import Testing
import SwiftUI
@testable import seeleseek
@testable import SeeleseekCore

// MARK: - View Rendering Tests
//
// These tests force SwiftUI to evaluate each view's body property (and all subviews)
// by using ImageRenderer. This provides code coverage for view code without needing
// to verify visual output.

@Suite("View Rendering Tests")
@MainActor
struct ViewRenderingTests {

    // MARK: - Helper

    /// Render a SwiftUI view using ImageRenderer to force body evaluation.
    private func renderView<V: View>(_ view: V) {
        let renderer = ImageRenderer(content: view.frame(width: 800, height: 600))
        let _ = renderer.cgImage
    }

    /// Create a basic disconnected AppState.
    private func makeAppState() -> AppState {
        AppState()
    }

    /// Create a connected AppState using PreviewData.
    private func makeConnectedAppState() -> AppState {
        PreviewData.connectedAppState
    }

    // MARK: - Search Views

    @Test("SearchView renders in empty state")
    func searchViewEmpty() {
        let state = makeConnectedAppState()
        renderView(
            SearchView()
                .environment(\.appState, state)
        )
    }

    @Test("SearchView renders with search results")
    func searchViewWithResults() {
        let state = makeConnectedAppState()
        let token = UInt32(1)
        state.searchState.searchQuery = "pink floyd"
        state.searchState.startSearch(token: token)
        state.searchState.addResults([
            SearchResult(username: "user1", filename: "Music\\Pink Floyd\\Time.flac", size: 45_000_000, bitrate: 1411, duration: 413, freeSlots: true, queueLength: 0),
            SearchResult(username: "user2", filename: "Music\\Pink Floyd\\Time.mp3", size: 8_500_000, bitrate: 320, duration: 413, freeSlots: false, queueLength: 5),
        ], forToken: token)
        renderView(
            SearchView()
                .environment(\.appState, state)
        )
    }

    @Test("SearchFilterBar renders")
    func searchFilterBar() {
        let state = makeConnectedAppState()
        renderView(
            SearchFilterBar(searchState: state.searchState)
                .environment(\.appState, state)
        )
    }

    @Test("SearchFilterPanel renders")
    func searchFilterPanel() {
        let state = makeConnectedAppState()
        state.searchState.showFilters = true
        renderView(
            SearchFilterPanel(searchState: state.searchState)
                .environment(\.appState, state)
        )
    }

    @Test("SearchResultRow renders with free slots")
    func searchResultRowFreeSlots() {
        let state = makeConnectedAppState()
        let result = SearchResult(
            username: "musiclover42",
            filename: "Music\\Albums\\Pink Floyd\\03 - Time.flac",
            size: 45_000_000,
            bitrate: 1411,
            duration: 413,
            freeSlots: true,
            uploadSpeed: 1_500_000,
            queueLength: 0
        )
        renderView(
            SearchResultRow(result: result)
                .environment(\.appState, state)
        )
    }

    @Test("SearchResultRow renders with queue and selection mode")
    func searchResultRowQueuedAndSelected() {
        let state = makeConnectedAppState()
        let result = SearchResult(
            username: "vinylcollector",
            filename: "Music\\MP3\\Pink Floyd - Time.mp3",
            size: 8_500_000,
            bitrate: 320,
            duration: 413,
            freeSlots: false,
            uploadSpeed: 800_000,
            queueLength: 5
        )
        renderView(
            SearchResultRow(
                result: result,
                isSelectionMode: true,
                isSelected: true,
                onToggleSelection: {}
            )
            .environment(\.appState, state)
        )
    }

    @Test("SearchResultRow renders low-bitrate lossy file")
    func searchResultRowLowBitrate() {
        let state = makeConnectedAppState()
        let result = SearchResult(
            username: "jazzfan",
            filename: "Downloads\\time.mp3",
            size: 4_200_000,
            bitrate: 128,
            duration: 413,
            isVBR: true,
            freeSlots: true,
            uploadSpeed: 256_000,
            queueLength: 0
        )
        renderView(
            SearchResultRow(result: result)
                .environment(\.appState, state)
        )
    }

    // MARK: - Chat Views

    @Test("ChatView renders empty state")
    func chatViewEmpty() {
        let state = makeConnectedAppState()
        renderView(
            ChatView()
                .environment(\.appState, state)
        )
    }

    @Test("ChatView renders with rooms and private chats")
    func chatViewWithData() {
        let state = makeConnectedAppState()
        let room = ChatRoom(
            name: "TestRoom",
            users: ["alice", "bob"],
            messages: [
                ChatMessage(username: "alice", content: "Hello!", isOwn: false),
                ChatMessage(username: "previewuser", content: "Hi there!", isOwn: true),
            ],
            isJoined: true
        )
        state.chatState.joinedRooms = [room]
        state.chatState.selectRoom("TestRoom")

        let chat = PrivateChat(
            username: "alice",
            messages: [
                ChatMessage(username: "alice", content: "Hey!", isOwn: false),
            ],
            isOnline: true
        )
        state.chatState.privateChats = [chat]
        renderView(
            ChatView()
                .environment(\.appState, state)
        )
    }

    @Test("ChatRoomContentView renders")
    func chatRoomContentView() {
        let state = makeConnectedAppState()
        let room = ChatRoom(
            name: "TestRoom",
            users: ["alice", "bob", "charlie"],
            messages: [
                ChatMessage(username: "alice", content: "Hello everyone!", isOwn: false),
                ChatMessage(username: "bob", content: "What's up?", isOwn: false),
                ChatMessage(username: "previewuser", content: "Hey!", isOwn: true),
                ChatMessage(username: "system", content: "alice joined the room", isSystem: true),
            ],
            isJoined: true,
            tickers: ["alice": "Listening to jazz"]
        )
        renderView(
            ChatRoomContentView(room: room, chatState: state.chatState, appState: state)
                .environment(\.appState, state)
        )
    }

    @Test("PrivateChatContentView renders")
    func privateChatContentView() {
        let state = makeConnectedAppState()
        let chat = PrivateChat(
            username: "alice",
            messages: [
                ChatMessage(username: "alice", content: "Hey there!", isOwn: false),
                ChatMessage(username: "previewuser", content: "Hi Alice!", isOwn: true),
            ],
            isOnline: true
        )
        renderView(
            PrivateChatContentView(chat: chat, chatState: state.chatState, appState: state)
                .environment(\.appState, state)
        )
    }

    @Test("MessageBubble renders own message")
    func messageBubbleOwn() {
        let state = makeConnectedAppState()
        let message = ChatMessage(username: "previewuser", content: "This is my message", isOwn: true)
        renderView(
            MessageBubble(message: message, chatState: state.chatState, appState: state)
                .environment(\.appState, state)
        )
    }

    @Test("MessageBubble renders other user message")
    func messageBubbleOther() {
        let state = makeConnectedAppState()
        let message = ChatMessage(username: "alice", content: "Hello from alice!", isOwn: false)
        renderView(
            MessageBubble(message: message, chatState: state.chatState, appState: state)
                .environment(\.appState, state)
        )
    }

    @Test("MessageBubble renders system message")
    func messageBubbleSystem() {
        let state = makeConnectedAppState()
        let message = ChatMessage(username: "system", content: "alice joined the room", isSystem: true)
        renderView(
            MessageBubble(message: message, chatState: state.chatState, appState: state)
                .environment(\.appState, state)
        )
    }

    @Test("MessageInput renders empty")
    func messageInputEmpty() {
        renderView(
            MessageInput(text: .constant(""), onSend: {})
        )
    }

    @Test("MessageInput renders with long text showing character count")
    func messageInputLongText() {
        let longText = String(repeating: "a", count: 1600)
        renderView(
            MessageInput(text: .constant(longText), onSend: {})
        )
    }

    @Test("RoomBrowserSheet renders")
    func roomBrowserSheet() {
        let state = makeConnectedAppState()
        renderView(
            RoomBrowserSheet(chatState: state.chatState, isPresented: .constant(true))
                .environment(\.appState, state)
        )
    }

    @Test("RoomManagementSheet renders")
    func roomManagementSheet() {
        let state = makeConnectedAppState()
        let room = ChatRoom(
            name: "MyPrivateRoom",
            users: ["alice", "bob"],
            isJoined: true,
            isPrivate: true,
            owner: "previewuser",
            operators: ["alice"],
            members: ["alice", "bob"]
        )
        renderView(
            RoomManagementSheet(room: room, chatState: state.chatState, isPresented: .constant(true))
                .environment(\.appState, state)
        )
    }

    @Test("RoomUserListPanel renders")
    func roomUserListPanel() {
        let state = makeConnectedAppState()
        let room = ChatRoom(
            name: "TestRoom",
            users: ["alice", "bob", "charlie"],
            isJoined: true,
            owner: "alice",
            operators: ["bob"]
        )
        renderView(
            RoomUserListPanel(room: room, chatState: state.chatState, appState: state)
                .environment(\.appState, state)
        )
    }

    // MARK: - Social Views

    @Test("SocialView renders")
    func socialView() {
        let state = makeConnectedAppState()
        renderView(
            SocialView()
                .environment(\.appState, state)
        )
    }

    @Test("AddBuddySheet renders")
    func addBuddySheet() {
        let state = makeConnectedAppState()
        renderView(
            AddBuddySheet()
                .environment(\.appState, state)
        )
    }

    @Test("BuddyListView renders empty")
    func buddyListViewEmpty() {
        let state = makeConnectedAppState()
        renderView(
            BuddyListView()
                .environment(\.appState, state)
        )
    }

    @Test("BuddyListView renders with buddies")
    func buddyListViewWithData() {
        let state = makeConnectedAppState()
        state.socialState.buddies = [
            Buddy(username: "alice", status: .online, averageSpeed: 1_500_000, fileCount: 12000),
            Buddy(username: "bob", status: .away, averageSpeed: 500_000, fileCount: 5000),
            Buddy(username: "charlie", status: .offline, fileCount: 3000),
        ]
        renderView(
            BuddyListView()
                .environment(\.appState, state)
        )
    }

    @Test("BuddyRowView renders online buddy")
    func buddyRowViewOnline() {
        let state = makeConnectedAppState()
        let buddy = Buddy(
            username: "alice",
            status: .online,
            isPrivileged: true,
            averageSpeed: 1_500_000,
            fileCount: 12345,
            countryCode: "US"
        )
        renderView(
            BuddyRowView(buddy: buddy)
                .environment(\.appState, state)
        )
    }

    @Test("BuddyRowView renders offline buddy")
    func buddyRowViewOffline() {
        let state = makeConnectedAppState()
        let buddy = Buddy(username: "charlie", status: .offline, fileCount: 3000)
        renderView(
            BuddyRowView(buddy: buddy)
                .environment(\.appState, state)
        )
    }

    @Test("BlocklistView renders empty")
    func blocklistViewEmpty() {
        let state = makeConnectedAppState()
        renderView(
            BlocklistView()
                .environment(\.appState, state)
        )
    }

    @Test("BlocklistView renders with blocked users")
    func blocklistViewWithData() {
        let state = makeConnectedAppState()
        state.socialState.blockedUsers = [
            BlockedUser(username: "spammer1", reason: "Spam", dateBlocked: Date()),
            BlockedUser(username: "leecher2", reason: nil, dateBlocked: Date().addingTimeInterval(-86400)),
        ]
        renderView(
            BlocklistView()
                .environment(\.appState, state)
        )
    }

    @Test("IgnoredUsersView renders empty")
    func ignoredUsersViewEmpty() {
        let state = makeConnectedAppState()
        renderView(
            IgnoredUsersView()
                .environment(\.appState, state)
        )
    }

    @Test("IgnoredUsersView renders with ignored users")
    func ignoredUsersViewWithData() {
        let state = makeConnectedAppState()
        state.socialState.ignoredUsers = [
            IgnoredUser(username: "annoyinguser", reason: "Rude messages", dateIgnored: Date()),
            IgnoredUser(username: "spammer", reason: nil, dateIgnored: Date().addingTimeInterval(-3600)),
        ]
        renderView(
            IgnoredUsersView()
                .environment(\.appState, state)
        )
    }

    @Test("InterestsView renders empty")
    func interestsViewEmpty() {
        let state = makeConnectedAppState()
        renderView(
            InterestsView()
                .environment(\.appState, state)
        )
    }

    @Test("InterestsView renders with interests")
    func interestsViewWithData() {
        let state = makeConnectedAppState()
        state.socialState.myLikes = ["jazz", "electronic", "classical", "vinyl", "lossless"]
        state.socialState.myHates = ["pop", "country"]
        renderView(
            InterestsView()
                .environment(\.appState, state)
        )
    }

    @Test("LeechSettingsView renders disabled")
    func leechSettingsViewDisabled() {
        let state = makeConnectedAppState()
        renderView(
            LeechSettingsView()
                .environment(\.appState, state)
        )
    }

    @Test("LeechSettingsView renders enabled with detected leeches")
    func leechSettingsViewEnabled() {
        let state = makeConnectedAppState()
        state.socialState.leechSettings.enabled = true
        state.socialState.detectedLeeches = ["leech_user1", "no_shares_bob"]
        state.socialState.warnedLeeches = ["leech_user1"]
        renderView(
            LeechSettingsView()
                .environment(\.appState, state)
        )
    }

    @Test("MyProfileView renders")
    func myProfileView() {
        let state = makeConnectedAppState()
        state.socialState.myDescription = "Music lover sharing my collection."
        state.socialState.myLikes = ["jazz", "electronic", "ambient", "classical", "experimental", "vinyl"]
        state.socialState.myHates = ["pop", "country"]
        renderView(
            MyProfileView()
                .environment(\.appState, state)
        )
    }

    @Test("MyProfileView renders with empty profile")
    func myProfileViewEmpty() {
        let state = makeConnectedAppState()
        renderView(
            MyProfileView()
                .environment(\.appState, state)
        )
    }

    @Test("RecommendationTag renders")
    func recommendationTag() {
        let state = makeConnectedAppState()
        renderView(
            RecommendationTag(item: "ambient", score: 45)
                .environment(\.appState, state)
        )
    }

    @Test("SimilarUserRow renders")
    func similarUserRow() {
        let state = makeConnectedAppState()
        renderView(
            SimilarUserRow(username: "jazzfan42", rating: 85)
                .environment(\.appState, state)
        )
    }

    @Test("SimilarUsersView renders empty")
    func similarUsersViewEmpty() {
        let state = makeConnectedAppState()
        renderView(
            SimilarUsersView()
                .environment(\.appState, state)
        )
    }

    @Test("SimilarUsersView renders with data")
    func similarUsersViewWithData() {
        let state = makeConnectedAppState()
        state.socialState.myLikes = ["jazz", "electronic"]
        state.socialState.similarUsers = [
            (username: "jazzfan42", rating: 85),
            (username: "electrohead", rating: 72),
        ]
        state.socialState.recommendations = [
            (item: "ambient", score: 45),
            (item: "experimental", score: 38),
        ]
        renderView(
            SimilarUsersView()
                .environment(\.appState, state)
        )
    }

    @Test("UserProfileSheet renders")
    func userProfileSheet() {
        let state = makeConnectedAppState()
        let profile = UserProfile(
            username: "testuser",
            description: "Music enthusiast sharing my collection. Mostly jazz, classical, and electronic.",
            totalUploads: 1234,
            queueSize: 5,
            hasFreeSlots: true,
            averageSpeed: 1_500_000,
            sharedFiles: 15000,
            sharedFolders: 200,
            likedInterests: ["jazz", "electronic", "classical", "vinyl"],
            hatedInterests: ["pop", "country"],
            status: .online,
            isPrivileged: true,
            countryCode: "US"
        )
        renderView(
            UserProfileSheet(profile: profile)
                .environment(\.appState, state)
        )
    }

    @Test("UserProfileSheet renders minimal profile")
    func userProfileSheetMinimal() {
        let state = makeConnectedAppState()
        let profile = UserProfile(username: "minimaluser")
        renderView(
            UserProfileSheet(profile: profile)
                .environment(\.appState, state)
        )
    }

    // MARK: - Browse Views

    @Test("BrowseView renders empty state")
    func browseViewEmpty() {
        let state = makeConnectedAppState()
        renderView(
            BrowseView()
                .environment(\.appState, state)
        )
    }

    @Test("BrowseTabButton renders selected")
    func browseTabButtonSelected() {
        let shares = UserShares(username: "testuser", folders: PreviewData.sampleFolderStructure, isLoading: false)
        renderView(
            BrowseTabButton(browse: shares, isSelected: true, onSelect: {}, onClose: {})
        )
    }

    @Test("BrowseTabButton renders loading")
    func browseTabButtonLoading() {
        let shares = UserShares(username: "testuser", isLoading: true)
        renderView(
            BrowseTabButton(browse: shares, isSelected: false, onSelect: {}, onClose: {})
        )
    }

    @Test("BrowseTabButton renders with error")
    func browseTabButtonError() {
        let shares = UserShares(username: "testuser", isLoading: false, error: "Timed out")
        renderView(
            BrowseTabButton(browse: shares, isSelected: false, onSelect: {}, onClose: {})
        )
    }

    @Test("FileTreeRow renders file")
    func fileTreeRowFile() {
        let state = makeConnectedAppState()
        let file = SharedFile(
            filename: "Music\\Albums\\Pink Floyd\\03 - Time.flac",
            size: 45_000_000,
            bitrate: 1411,
            duration: 413
        )
        renderView(
            FileTreeRow(file: file, depth: 2, browseState: state.browseState, username: "testuser")
                .environment(\.appState, state)
        )
    }

    @Test("FileTreeRow renders directory")
    func fileTreeRowDirectory() {
        let state = makeConnectedAppState()
        let folder = SharedFile(
            filename: "Music\\Albums\\Pink Floyd",
            isDirectory: true,
            children: [
                SharedFile(filename: "Music\\Albums\\Pink Floyd\\01 - Speak to Me.flac", size: 15_234_567, bitrate: 1411, duration: 68),
            ],
            fileCount: 3
        )
        renderView(
            FileTreeRow(file: folder, depth: 1, browseState: state.browseState, username: "testuser")
                .environment(\.appState, state)
        )
    }

    @Test("FileTreeRow renders private file")
    func fileTreeRowPrivate() {
        let state = makeConnectedAppState()
        let file = SharedFile(
            filename: "Private\\secret.flac",
            size: 10_000_000,
            isPrivate: true
        )
        renderView(
            FileTreeRow(file: file, depth: 0, browseState: state.browseState, username: "testuser")
                .environment(\.appState, state)
        )
    }

    @Test("SharesVisualizationPanel renders")
    func sharesVisualizationPanel() {
        let shares = UserShares(
            username: "testuser",
            folders: PreviewData.sampleFolderStructure,
            isLoading: false
        )
        renderView(
            SharesVisualizationPanel(shares: shares)
        )
    }

    @Test("SharesVisualizationPanel renders empty shares")
    func sharesVisualizationPanelEmpty() {
        let shares = UserShares(username: "testuser", folders: [], isLoading: false)
        renderView(
            SharesVisualizationPanel(shares: shares)
        )
    }

    @Test("StatCard renders")
    func statCard() {
        renderView(
            StatCard(title: "Files", value: "15,000", icon: "doc.fill", color: .blue)
        )
    }

    // MARK: - Transfer Views

    @Test("TransfersView renders empty")
    func transfersViewEmpty() {
        let state = makeConnectedAppState()
        renderView(
            TransfersView()
                .environment(\.appState, state)
        )
    }

    @Test("TransfersView renders with downloads")
    func transfersViewWithDownloads() {
        let state = makeConnectedAppState()
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
            Transfer(
                username: "bob",
                filename: "Music\\Song.mp3",
                size: 8_000_000,
                direction: .download,
                status: .queued,
                queuePosition: 3
            ),
        ]
        renderView(
            TransfersView()
                .environment(\.appState, state)
        )
    }

    @Test("TransferRow renders transferring download")
    func transferRowTransferring() {
        let state = makeConnectedAppState()
        let transfer = Transfer(
            username: "alice",
            filename: "Music\\Albums\\Artist\\01 - Track.flac",
            size: 45_000_000,
            direction: .download,
            status: .transferring,
            bytesTransferred: 22_500_000,
            startTime: Date().addingTimeInterval(-30),
            speed: 1_250_000
        )
        renderView(
            TransferRow(
                transfer: transfer,
                onCancel: {},
                onRetry: {},
                onRemove: {},
                onMoveToTop: {},
                onMoveToBottom: {}
            )
            .environment(\.appState, state)
        )
    }

    @Test("TransferRow renders queued download")
    func transferRowQueued() {
        let state = makeConnectedAppState()
        let transfer = Transfer(
            username: "bob",
            filename: "Music\\Song.mp3",
            size: 8_000_000,
            direction: .download,
            status: .queued,
            queuePosition: 5
        )
        renderView(
            TransferRow(transfer: transfer, onCancel: {}, onRetry: {}, onRemove: {})
                .environment(\.appState, state)
        )
    }

    @Test("TransferRow renders failed download")
    func transferRowFailed() {
        let state = makeConnectedAppState()
        let transfer = Transfer(
            username: "charlie",
            filename: "Music\\Failed.flac",
            size: 30_000_000,
            direction: .download,
            status: .failed,
            error: "Connection timed out"
        )
        renderView(
            TransferRow(transfer: transfer, onCancel: {}, onRetry: {}, onRemove: {})
                .environment(\.appState, state)
        )
    }

    @Test("TransferRow renders completed download")
    func transferRowCompleted() {
        let state = makeConnectedAppState()
        let transfer = Transfer(
            username: "alice",
            filename: "Music\\Done.flac",
            size: 45_000_000,
            direction: .download,
            status: .completed,
            bytesTransferred: 45_000_000
        )
        renderView(
            TransferRow(transfer: transfer, onCancel: {}, onRetry: {}, onRemove: {})
                .environment(\.appState, state)
        )
    }

    @Test("TransferRow renders upload")
    func transferRowUpload() {
        let state = makeConnectedAppState()
        let transfer = Transfer(
            username: "bob",
            filename: "Music\\Upload.mp3",
            size: 8_000_000,
            direction: .upload,
            status: .transferring,
            bytesTransferred: 4_000_000,
            speed: 500_000
        )
        renderView(
            TransferRow(transfer: transfer, onCancel: {}, onRetry: {}, onRemove: {})
                .environment(\.appState, state)
        )
    }

    @Test("HistoryRow renders download history")
    func historyRowDownload() {
        let state = makeConnectedAppState()
        let item = TransferHistoryItem(
            id: "hist-1",
            timestamp: Date().addingTimeInterval(-3600),
            filename: "Music\\Albums\\Artist\\01 - Track.flac",
            username: "alice",
            size: 45_000_000,
            duration: 36.0,
            averageSpeed: 1_250_000,
            isDownload: true,
            localPath: nil
        )
        renderView(
            HistoryRow(item: item)
                .environment(\.appState, state)
        )
    }

    @Test("HistoryRow renders upload history")
    func historyRowUpload() {
        let state = makeConnectedAppState()
        let item = TransferHistoryItem(
            id: "hist-2",
            timestamp: Date().addingTimeInterval(-7200),
            filename: "Music\\Song.mp3",
            username: "bob",
            size: 8_000_000,
            duration: 10.0,
            averageSpeed: 800_000,
            isDownload: false,
            localPath: nil
        )
        renderView(
            HistoryRow(item: item)
                .environment(\.appState, state)
        )
    }

    // MARK: - Connection Views

    @Test("ConnectionStatusView renders disconnected")
    func connectionStatusViewDisconnected() {
        let state = makeAppState()
        renderView(
            ConnectionStatusView()
                .environment(\.appState, state)
        )
    }

    @Test("ConnectionStatusView renders connected")
    func connectionStatusViewConnected() {
        let state = makeConnectedAppState()
        renderView(
            ConnectionStatusView()
                .environment(\.appState, state)
        )
    }

    @Test("ConnectionStatusView renders with error")
    func connectionStatusViewError() {
        let state = PreviewData.errorAppState
        renderView(
            ConnectionStatusView()
                .environment(\.appState, state)
        )
    }

    @Test("CompactConnectionStatus renders disconnected")
    func compactConnectionStatusDisconnected() {
        let state = makeAppState()
        renderView(
            CompactConnectionStatus()
                .environment(\.appState, state)
        )
    }

    @Test("CompactConnectionStatus renders connected")
    func compactConnectionStatusConnected() {
        let state = makeConnectedAppState()
        renderView(
            CompactConnectionStatus()
                .environment(\.appState, state)
        )
    }

    @Test("LoginView renders empty")
    func loginViewEmpty() {
        let state = makeAppState()
        renderView(
            LoginView()
                .environment(\.appState, state)
        )
    }

    @Test("LoginView renders with error")
    func loginViewWithError() {
        let state = PreviewData.errorAppState
        renderView(
            LoginView()
                .environment(\.appState, state)
        )
    }

    // MARK: - Console Views

    @Test("SidebarConsoleView renders")
    func sidebarConsoleView() {
        renderView(
            SidebarConsoleView()
        )
    }

    // MARK: - Wishlist Views

    @Test("WishlistView renders empty")
    func wishlistViewEmpty() {
        let state = makeConnectedAppState()
        renderView(
            WishlistView()
                .environment(\.appState, state)
        )
    }

    @Test("WishlistView renders with items")
    func wishlistViewWithItems() {
        let state = makeConnectedAppState()
        state.wishlistState.items = [
            WishlistItem(query: "ambient electronic", lastSearchedAt: Date().addingTimeInterval(-300), resultCount: 42),
            WishlistItem(query: "boards of canada flac", lastSearchedAt: Date().addingTimeInterval(-120), resultCount: 128),
            WishlistItem(query: "autechre", resultCount: 0),
        ]
        renderView(
            WishlistView()
                .environment(\.appState, state)
        )
    }

    @Test("WishlistItemRow renders enabled item")
    func wishlistItemRowEnabled() {
        let state = makeConnectedAppState()
        let item = WishlistItem(query: "ambient electronic", lastSearchedAt: Date(), resultCount: 42)
        renderView(
            WishlistItemRow(item: item)
                .environment(\.appState, state)
        )
    }

    @Test("WishlistItemRow renders disabled item")
    func wishlistItemRowDisabled() {
        let state = makeConnectedAppState()
        let item = WishlistItem(query: "old search", enabled: false, resultCount: 0)
        renderView(
            WishlistItemRow(item: item)
                .environment(\.appState, state)
        )
    }

    // MARK: - MenuBar View

    @Test("MenuBarView renders disconnected")
    func menuBarViewDisconnected() {
        let state = makeAppState()
        renderView(
            VStack {
                MenuBarView()
            }
            .environment(\.appState, state)
        )
    }

    @Test("MenuBarView renders connected")
    func menuBarViewConnected() {
        let state = makeConnectedAppState()
        renderView(
            VStack {
                MenuBarView()
            }
            .environment(\.appState, state)
        )
    }

    @Test("MenuBarView renders with active transfers")
    func menuBarViewWithTransfers() {
        let state = makeConnectedAppState()
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
            Transfer(
                username: "bob",
                filename: "Music\\Song.mp3",
                size: 8_000_000,
                direction: .download,
                status: .queued
            ),
        ]
        renderView(
            VStack {
                MenuBarView()
            }
            .environment(\.appState, state)
        )
    }

    // MARK: - Navigation Views

    @Test("Sidebar renders disconnected")
    func sidebarDisconnected() {
        let state = makeAppState()
        renderView(
            Sidebar()
                .environment(\.appState, state)
        )
    }

    @Test("Sidebar renders connected")
    func sidebarConnected() {
        let state = makeConnectedAppState()
        renderView(
            Sidebar()
                .environment(\.appState, state)
        )
    }

    @Test("SidebarRow renders search item")
    func sidebarRowSearch() {
        let state = makeConnectedAppState()
        renderView(
            SidebarRow(item: .search)
                .environment(\.appState, state)
        )
    }

    @Test("SidebarRow renders chat item with unread badge")
    func sidebarRowChatWithBadge() {
        let state = makeConnectedAppState()
        let room = ChatRoom(name: "TestRoom", unreadCount: 5, isJoined: true)
        state.chatState.joinedRooms = [room]
        renderView(
            SidebarRow(item: .chat)
                .environment(\.appState, state)
        )
    }

    @Test("SidebarRow renders each sidebar item")
    func sidebarRowAllItems() {
        let state = makeConnectedAppState()
        let items: [SidebarItem] = [.search, .wishlists, .transfers, .chat, .browse, .social, .statistics, .networkMonitor, .settings]
        for item in items {
            renderView(
                SidebarRow(item: item)
                    .environment(\.appState, state)
            )
        }
    }

    @Test("PlaceholderView renders")
    func placeholderView() {
        renderView(
            PlaceholderView(title: "Coming Soon", icon: "star")
        )
    }

    // MARK: - Settings and Statistics Views

    @Test("SettingsView renders")
    func settingsView() {
        let state = makeConnectedAppState()
        renderView(
            SettingsView()
                .environment(\.appState, state)
        )
    }

    @Test("StatisticsView renders")
    func statisticsView() {
        let state = makeConnectedAppState()
        renderView(
            StatisticsView()
                .environment(\.appState, state)
        )
    }

    @Test("NetworkMonitorView renders")
    func networkMonitorView() {
        let state = makeConnectedAppState()
        renderView(
            NetworkMonitorView()
                .environment(\.appState, state)
        )
    }
}
