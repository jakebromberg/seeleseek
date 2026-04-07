import Testing
import Foundation
@testable import SeeleseekCore
@testable import seeleseek

@Suite(.serialized)
@MainActor
struct SocialStateCallbackTests {

    // MARK: - Helpers

    /// Create a SocialState wired up with a real NetworkClient via setupCallbacks.
    /// The networkClient is NOT connected to any server, but callbacks are wired.
    private func makeWiredState() -> (SocialState, NetworkClient) {
        let state = SocialState()
        let client = NetworkClient()
        state.setupCallbacks(client: client)
        return (state, client)
    }

    // MARK: - setupCallbacks wiring

    @Test("setupCallbacks stores weak reference to network client")
    func setupCallbacksStoresClient() {
        let (state, client) = makeWiredState()
        #expect(state.networkClient === client)
    }

    // MARK: - onRecommendations callback

    @Test("onRecommendations callback updates recommendations and unrecommendations")
    func onRecommendationsUpdatesState() {
        let (state, client) = makeWiredState()
        state.isLoadingRecommendations = true

        let recs: [(item: String, score: Int32)] = [
            (item: "electronic", score: 100),
            (item: "ambient", score: 50),
        ]
        let unrecs: [(item: String, score: Int32)] = [
            (item: "country", score: -30),
        ]

        client.onRecommendations?(recs, unrecs)

        #expect(state.recommendations.count == 2)
        #expect(state.recommendations[0].item == "electronic")
        #expect(state.recommendations[0].score == 100)
        #expect(state.recommendations[1].item == "ambient")
        #expect(state.unrecommendations.count == 1)
        #expect(state.unrecommendations[0].item == "country")
        #expect(!state.isLoadingRecommendations)
    }

    @Test("onRecommendations with empty arrays clears state")
    func onRecommendationsEmpty() {
        let (state, client) = makeWiredState()
        state.recommendations = [(item: "old", score: 1)]
        state.unrecommendations = [(item: "old2", score: -1)]

        client.onRecommendations?([], [])

        #expect(state.recommendations.isEmpty)
        #expect(state.unrecommendations.isEmpty)
    }

    // MARK: - onGlobalRecommendations callback

    @Test("onGlobalRecommendations callback updates global recommendations")
    func onGlobalRecommendationsUpdatesState() {
        let (state, client) = makeWiredState()

        let globalRecs: [(item: String, score: Int32)] = [
            (item: "pop", score: 500),
            (item: "rock", score: 400),
            (item: "jazz", score: 300),
        ]

        client.onGlobalRecommendations?(globalRecs, [])

        #expect(state.globalRecommendations.count == 3)
        #expect(state.globalRecommendations[0].item == "pop")
        #expect(state.globalRecommendations[0].score == 500)
        #expect(state.globalRecommendations[2].item == "jazz")
    }

    // MARK: - onSimilarUsers callback

    @Test("onSimilarUsers callback updates similarUsers and clears loading flag")
    func onSimilarUsersUpdatesState() {
        let (state, client) = makeWiredState()
        state.isLoadingSimilar = true

        let users: [(username: String, rating: UInt32)] = [
            (username: "musicfan42", rating: 95),
            (username: "audiophile", rating: 80),
        ]

        client.onSimilarUsers?(users)

        #expect(state.similarUsers.count == 2)
        #expect(state.similarUsers[0].username == "musicfan42")
        #expect(state.similarUsers[0].rating == 95)
        #expect(state.similarUsers[1].username == "audiophile")
        #expect(!state.isLoadingSimilar)
    }

    @Test("onSimilarUsers with empty array clears the list")
    func onSimilarUsersEmpty() {
        let (state, client) = makeWiredState()
        state.similarUsers = [(username: "old", rating: 1)]

        client.onSimilarUsers?([])

        #expect(state.similarUsers.isEmpty)
    }

    // MARK: - onUserInterests callback

    @Test("onUserInterests updates viewed profile interests when username matches")
    func onUserInterestsUpdatesViewingProfile() {
        let (state, client) = makeWiredState()
        state.viewingProfile = UserProfile(username: "alice")

        client.onUserInterests?("alice", ["electronic", "jazz"], ["country"])

        #expect(state.viewingProfile?.likedInterests == ["electronic", "jazz"])
        #expect(state.viewingProfile?.hatedInterests == ["country"])
    }

    @Test("onUserInterests does not update profile when username does not match")
    func onUserInterestsIgnoresMismatch() {
        let (state, client) = makeWiredState()
        state.viewingProfile = UserProfile(username: "alice")

        client.onUserInterests?("bob", ["rock"], ["pop"])

        #expect(state.viewingProfile?.likedInterests.isEmpty == true)
        #expect(state.viewingProfile?.hatedInterests.isEmpty == true)
    }

    @Test("onUserInterests does nothing when no profile is being viewed")
    func onUserInterestsNoProfile() {
        let (state, client) = makeWiredState()
        #expect(state.viewingProfile == nil)

        // Should not crash
        client.onUserInterests?("alice", ["electronic"], ["country"])
        #expect(state.viewingProfile == nil)
    }

    // MARK: - onPrivilegesChecked callback

    @Test("onPrivilegesChecked updates privilege time remaining")
    func onPrivilegesCheckedUpdatesTime() {
        let (state, client) = makeWiredState()
        #expect(state.privilegeTimeRemaining == 0)

        client.onPrivilegesChecked?(86400)

        #expect(state.privilegeTimeRemaining == 86400)
    }

    @Test("onPrivilegesChecked with zero clears privilege time")
    func onPrivilegesCheckedZero() {
        let (state, client) = makeWiredState()
        state.privilegeTimeRemaining = 1000

        client.onPrivilegesChecked?(0)

        #expect(state.privilegeTimeRemaining == 0)
    }

    // MARK: - onUserPrivileges callback

    @Test("onUserPrivileges updates viewing profile when username matches")
    func onUserPrivilegesUpdatesProfile() {
        let (state, client) = makeWiredState()
        state.viewingProfile = UserProfile(username: "alice", isPrivileged: false)

        client.onUserPrivileges?("alice", true)

        #expect(state.viewingProfile?.isPrivileged == true)
    }

    @Test("onUserPrivileges does not update when username does not match")
    func onUserPrivilegesIgnoresMismatch() {
        let (state, client) = makeWiredState()
        state.viewingProfile = UserProfile(username: "alice", isPrivileged: false)

        client.onUserPrivileges?("bob", true)

        #expect(state.viewingProfile?.isPrivileged == false)
    }

    // MARK: - User status handler (via handleUserStatusResponse)

    @Test("user status handler updates buddy status to online")
    func userStatusHandlerOnline() {
        let (state, client) = makeWiredState()
        state.buddies = [Buddy(username: "alice", status: .offline)]

        client.handleUserStatusResponse(username: "alice", status: .online, privileged: true)

        #expect(state.buddies[0].status == .online)
        #expect(state.buddies[0].isPrivileged == true)
        #expect(state.buddies[0].lastSeen != nil)
    }

    @Test("user status handler updates buddy status to away")
    func userStatusHandlerAway() {
        let (state, client) = makeWiredState()
        state.buddies = [Buddy(username: "alice", status: .online)]

        client.handleUserStatusResponse(username: "alice", status: .away, privileged: false)

        #expect(state.buddies[0].status == .away)
        #expect(state.buddies[0].isPrivileged == false)
        #expect(state.buddies[0].lastSeen != nil)
    }

    @Test("user status handler updates buddy status to offline without updating lastSeen")
    func userStatusHandlerOffline() {
        let (state, client) = makeWiredState()
        state.buddies = [Buddy(username: "alice", status: .online, lastSeen: nil)]

        client.handleUserStatusResponse(username: "alice", status: .offline, privileged: false)

        #expect(state.buddies[0].status == .offline)
        // lastSeen should NOT be updated when going offline
        #expect(state.buddies[0].lastSeen == nil)
    }

    @Test("user status handler ignores unknown username")
    func userStatusHandlerUnknownUser() {
        let (state, client) = makeWiredState()
        state.buddies = [Buddy(username: "alice")]

        client.handleUserStatusResponse(username: "unknown", status: .online, privileged: false)

        #expect(state.buddies[0].status == .offline)
    }

    @Test("user status handler also updates viewing profile when username matches")
    func userStatusHandlerUpdatesViewingProfile() {
        let (state, client) = makeWiredState()
        state.buddies = [Buddy(username: "alice")]
        state.viewingProfile = UserProfile(username: "alice", status: .offline, isPrivileged: false)

        client.handleUserStatusResponse(username: "alice", status: .online, privileged: true)

        #expect(state.viewingProfile?.status == .online)
        #expect(state.viewingProfile?.isPrivileged == true)
    }

    // MARK: - User stats handler (via dispatchUserStats)

    @Test("user stats handler updates buddy stats")
    func userStatsHandlerUpdatesBuddy() {
        let (state, client) = makeWiredState()
        state.buddies = [Buddy(username: "alice")]

        client.dispatchUserStats(username: "alice", avgSpeed: 5000, uploadNum: 100, files: 200, dirs: 10)

        #expect(state.buddies[0].averageSpeed == 5000)
        #expect(state.buddies[0].fileCount == 200)
        #expect(state.buddies[0].folderCount == 10)
    }

    @Test("user stats handler also updates viewing profile when username matches")
    func userStatsHandlerUpdatesProfile() {
        let (state, client) = makeWiredState()
        state.buddies = [Buddy(username: "alice")]
        state.viewingProfile = UserProfile(username: "alice")

        client.dispatchUserStats(username: "alice", avgSpeed: 5000, uploadNum: 100, files: 200, dirs: 10)

        #expect(state.viewingProfile?.averageSpeed == 5000)
        #expect(state.viewingProfile?.totalUploads == 100)
        #expect(state.viewingProfile?.sharedFiles == 200)
        #expect(state.viewingProfile?.sharedFolders == 10)
    }

    @Test("user stats handler ignores unknown username for buddy list")
    func userStatsHandlerIgnoresUnknown() {
        let (state, client) = makeWiredState()
        state.buddies = [Buddy(username: "alice")]

        client.dispatchUserStats(username: "unknown", avgSpeed: 9999, uploadNum: 0, files: 0, dirs: 0)

        #expect(state.buddies[0].averageSpeed == 0)
    }

    // MARK: - profileDataProvider callback

    @Test("profileDataProvider returns description and picture")
    func profileDataProviderReturnsData() {
        let (state, client) = makeWiredState()
        state.myDescription = "Hello world"
        state.myPicture = Data([0x01, 0x02, 0x03])

        let result = client.profileDataProvider?()

        #expect(result?.description == "Hello world")
        #expect(result?.picture == Data([0x01, 0x02, 0x03]))
    }

    @Test("profileDataProvider returns default description when empty")
    func profileDataProviderDefault() {
        let (state, client) = makeWiredState()
        state.myDescription = ""

        let result = client.profileDataProvider?()

        #expect(result?.description == "SeeleSeek - Soulseek client for macOS")
    }

    // MARK: - updateBuddyStatus (direct method)

    @Test("updateBuddyStatus updates correct buddy by username")
    func updateBuddyStatusDirect() {
        let state = SocialState()
        state.buddies = [
            Buddy(username: "alice", status: .offline),
            Buddy(username: "bob", status: .offline),
        ]

        state.updateBuddyStatus(username: "bob", status: .online, privileged: true)

        #expect(state.buddies[0].status == .offline)
        #expect(state.buddies[1].status == .online)
        #expect(state.buddies[1].isPrivileged == true)
    }

    @Test("updateBuddyStatus sets lastSeen for non-offline statuses")
    func updateBuddyStatusSetsLastSeen() {
        let state = SocialState()
        state.buddies = [Buddy(username: "alice", status: .offline, lastSeen: nil)]

        state.updateBuddyStatus(username: "alice", status: .away, privileged: false)

        #expect(state.buddies[0].lastSeen != nil)
    }

    @Test("updateBuddyStatus does not set lastSeen for offline")
    func updateBuddyStatusOfflineNoLastSeen() {
        let state = SocialState()
        state.buddies = [Buddy(username: "alice", status: .online, lastSeen: nil)]

        state.updateBuddyStatus(username: "alice", status: .offline, privileged: false)

        #expect(state.buddies[0].lastSeen == nil)
    }

    // MARK: - updateBuddyNotes

    @Test("updateBuddyNotes sets notes on correct buddy")
    func updateBuddyNotesSetsNotes() {
        let state = SocialState()
        state.buddies = [Buddy(username: "alice"), Buddy(username: "bob")]

        state.updateBuddyNotes("alice", notes: "Great taste in music")

        #expect(state.buddies[0].notes == "Great taste in music")
        #expect(state.buddies[1].notes == nil)
    }

    @Test("updateBuddyNotes clears notes when empty string")
    func updateBuddyNotesClearsEmpty() {
        let state = SocialState()
        state.buddies = [Buddy(username: "alice", notes: "Old notes")]

        state.updateBuddyNotes("alice", notes: "")

        #expect(state.buddies[0].notes == nil)
    }

    @Test("updateBuddyNotes ignores unknown username")
    func updateBuddyNotesUnknownUser() {
        let state = SocialState()
        state.buddies = [Buddy(username: "alice")]

        state.updateBuddyNotes("unknown", notes: "Some notes")

        #expect(state.buddies[0].notes == nil)
    }

    // MARK: - Leech detection via checkForLeech

    @Test("checkForLeech detects leech with low files")
    func checkForLeechLowFiles() {
        let state = SocialState()
        state.leechSettings.enabled = true
        state.leechSettings.minSharedFiles = 10
        state.leechSettings.minSharedFolders = 1

        state.checkForLeech(username: "freeloader", files: 5, folders: 2)

        #expect(state.detectedLeeches.contains("freeloader"))
    }

    @Test("checkForLeech detects leech with low folders")
    func checkForLeechLowFolders() {
        let state = SocialState()
        state.leechSettings.enabled = true
        state.leechSettings.minSharedFiles = 10
        state.leechSettings.minSharedFolders = 3

        state.checkForLeech(username: "freeloader", files: 50, folders: 1)

        #expect(state.detectedLeeches.contains("freeloader"))
    }

    @Test("checkForLeech removes leech when user starts sharing enough")
    func checkForLeechRehabilitates() {
        let state = SocialState()
        state.leechSettings.enabled = true
        state.leechSettings.minSharedFiles = 10
        state.leechSettings.minSharedFolders = 1
        state.detectedLeeches = ["reformed"]
        state.warnedLeeches = ["reformed"]

        state.checkForLeech(username: "reformed", files: 50, folders: 5)

        #expect(!state.detectedLeeches.contains("reformed"))
        #expect(!state.warnedLeeches.contains("reformed"))
    }

    @Test("checkForLeech does nothing when disabled")
    func checkForLeechDisabled() {
        let state = SocialState()
        state.leechSettings.enabled = false

        state.checkForLeech(username: "freeloader", files: 0, folders: 0)

        #expect(state.detectedLeeches.isEmpty)
    }

    @Test("checkForLeech skips blocked users")
    func checkForLeechSkipsBlocked() {
        let state = SocialState()
        state.leechSettings.enabled = true
        state.blockedUsers = [BlockedUser(username: "baduser")]

        state.checkForLeech(username: "baduser", files: 0, folders: 0)

        #expect(!state.detectedLeeches.contains("baduser"))
    }

    // MARK: - shouldAllowUpload

    @Test("shouldAllowUpload denies blocked user")
    func shouldAllowUploadDeniesBlocked() {
        let state = SocialState()
        state.blockedUsers = [BlockedUser(username: "spammer")]

        #expect(!state.shouldAllowUpload(to: "spammer"))
    }

    @Test("shouldAllowUpload denies leech with deny action")
    func shouldAllowUploadDeniesLeech() {
        let state = SocialState()
        state.leechSettings.enabled = true
        state.leechSettings.action = .deny
        state.detectedLeeches = ["freeloader"]

        #expect(!state.shouldAllowUpload(to: "freeloader"))
    }

    @Test("shouldAllowUpload allows leech with warn action")
    func shouldAllowUploadAllowsLeechWarn() {
        let state = SocialState()
        state.leechSettings.enabled = true
        state.leechSettings.action = .warn
        state.detectedLeeches = ["freeloader"]

        #expect(state.shouldAllowUpload(to: "freeloader"))
    }

    @Test("shouldAllowUpload allows normal user")
    func shouldAllowUploadAllowsNormal() {
        let state = SocialState()
        #expect(state.shouldAllowUpload(to: "gooduser"))
    }

    // MARK: - Block/unblock state changes (local state only)

    @Test("blocking adds user to blockedUsers list")
    func blockingAddsUser() async {
        let state = SocialState()
        #expect(state.blockedUsers.isEmpty)

        // blockUser is async and touches DB, but we test the local state change
        // It should append to blockedUsers even though DB may fail
        await state.blockUser("spammer", reason: "spam")

        #expect(state.blockedUsers.count == 1)
        #expect(state.blockedUsers[0].username == "spammer")
        #expect(state.blockedUsers[0].reason == "spam")
    }

    @Test("blocking already blocked user is a no-op")
    func blockingAlreadyBlocked() async {
        let state = SocialState()
        state.blockedUsers = [BlockedUser(username: "spammer")]

        await state.blockUser("spammer")

        #expect(state.blockedUsers.count == 1)
    }

    @Test("unblocking removes user from blockedUsers")
    func unblockingRemovesUser() async {
        let state = SocialState()
        state.blockedUsers = [
            BlockedUser(username: "spammer"),
            BlockedUser(username: "troll"),
        ]

        await state.unblockUser("spammer")

        #expect(state.blockedUsers.count == 1)
        #expect(state.blockedUsers[0].username == "troll")
    }

    @Test("unblocking is case-insensitive")
    func unblockingCaseInsensitive() async {
        let state = SocialState()
        state.blockedUsers = [BlockedUser(username: "Spammer")]

        await state.unblockUser("spammer")

        #expect(state.blockedUsers.isEmpty)
    }

    // MARK: - Ignore/unignore state changes (local state only)

    @Test("ignoring adds user to ignoredUsers list")
    func ignoringAddsUser() async {
        let state = SocialState()
        // Give it a client so ignoreUser doesn't crash on nil networkClient
        let client = NetworkClient()
        state.setupCallbacks(client: client)

        await state.ignoreUser("annoying", reason: "too chatty")

        #expect(state.ignoredUsers.count == 1)
        #expect(state.ignoredUsers[0].username == "annoying")
        #expect(state.ignoredUsers[0].reason == "too chatty")
    }

    @Test("ignoring already ignored user is a no-op")
    func ignoringAlreadyIgnored() async {
        let state = SocialState()
        let client = NetworkClient()
        state.setupCallbacks(client: client)
        state.ignoredUsers = [IgnoredUser(username: "annoying")]

        await state.ignoreUser("annoying")

        #expect(state.ignoredUsers.count == 1)
    }

    @Test("ignoring empty username is a no-op")
    func ignoringEmptyUsername() async {
        let state = SocialState()
        let client = NetworkClient()
        state.setupCallbacks(client: client)

        await state.ignoreUser("   ")

        #expect(state.ignoredUsers.isEmpty)
    }

    @Test("unignoring removes user from ignoredUsers")
    func unignoringRemovesUser() async {
        let state = SocialState()
        let client = NetworkClient()
        state.setupCallbacks(client: client)
        state.ignoredUsers = [
            IgnoredUser(username: "annoying"),
            IgnoredUser(username: "chatty"),
        ]

        await state.unignoreUser("annoying")

        #expect(state.ignoredUsers.count == 1)
        #expect(state.ignoredUsers[0].username == "chatty")
    }

    @Test("unignoring is case-insensitive")
    func unignoringCaseInsensitive() async {
        let state = SocialState()
        let client = NetworkClient()
        state.setupCallbacks(client: client)
        state.ignoredUsers = [IgnoredUser(username: "Annoying")]

        await state.unignoreUser("annoying")

        #expect(state.ignoredUsers.isEmpty)
    }
}
