import Testing
import Foundation
@testable import SeeleseekCore
@testable import seeleseek

@Suite("SocialState Filters")
@MainActor
struct SocialStateFilterTests {

    // MARK: - filteredBuddies

    @Suite("filteredBuddies")
    @MainActor
    struct FilteredBuddiesTests {

        @Test("returns all buddies sorted by status when no search query")
        func noSearch() {
            let state = SocialState()
            state.buddies = [
                Buddy(username: "offline_user", status: .offline),
                Buddy(username: "online_user", status: .online),
                Buddy(username: "away_user", status: .away),
            ]
            let filtered = state.filteredBuddies
            #expect(filtered.count == 3)
            #expect(filtered[0].username == "online_user")
            #expect(filtered[1].username == "away_user")
            #expect(filtered[2].username == "offline_user")
        }

        @Test("filters by search query case-insensitively")
        func searchFilter() {
            let state = SocialState()
            state.buddies = [
                Buddy(username: "AliceInChains"),
                Buddy(username: "BobMarley"),
                Buddy(username: "alice_cooper"),
            ]
            state.buddySearchQuery = "alice"
            let filtered = state.filteredBuddies
            #expect(filtered.count == 2)
            let names = filtered.map(\.username)
            #expect(names.contains("AliceInChains"))
            #expect(names.contains("alice_cooper"))
        }

        @Test("returns empty when search query matches nobody")
        func noMatch() {
            let state = SocialState()
            state.buddies = [
                Buddy(username: "alice"),
                Buddy(username: "bob"),
            ]
            state.buddySearchQuery = "charlie"
            #expect(state.filteredBuddies.isEmpty)
        }

        @Test("returns empty when buddy list is empty")
        func emptyBuddies() {
            let state = SocialState()
            #expect(state.filteredBuddies.isEmpty)
        }

        @Test("maintains sort order after filtering")
        func sortedAfterFilter() {
            let state = SocialState()
            state.buddies = [
                Buddy(username: "alice_offline", status: .offline),
                Buddy(username: "alice_online", status: .online),
                Buddy(username: "alice_away", status: .away),
                Buddy(username: "bob_online", status: .online),
            ]
            state.buddySearchQuery = "alice"
            let filtered = state.filteredBuddies
            #expect(filtered.count == 3)
            #expect(filtered[0].username == "alice_online")
            #expect(filtered[1].username == "alice_away")
            #expect(filtered[2].username == "alice_offline")
        }
    }

    // MARK: - onlineBuddies / offlineBuddies

    @Suite("onlineBuddies and offlineBuddies")
    @MainActor
    struct OnlineOfflineBuddiesTests {

        @Test("onlineBuddies includes online and away users")
        func onlineIncludesAway() {
            let state = SocialState()
            state.buddies = [
                Buddy(username: "online", status: .online),
                Buddy(username: "away", status: .away),
                Buddy(username: "offline", status: .offline),
            ]
            let online = state.onlineBuddies
            #expect(online.count == 2)
            let names = online.map(\.username)
            #expect(names.contains("online"))
            #expect(names.contains("away"))
        }

        @Test("offlineBuddies includes only offline users")
        func offlineOnly() {
            let state = SocialState()
            state.buddies = [
                Buddy(username: "online", status: .online),
                Buddy(username: "away", status: .away),
                Buddy(username: "offline", status: .offline),
            ]
            let offline = state.offlineBuddies
            #expect(offline.count == 1)
            #expect(offline[0].username == "offline")
        }

        @Test("onlineBuddies empty when all offline")
        func allOffline() {
            let state = SocialState()
            state.buddies = [
                Buddy(username: "a", status: .offline),
                Buddy(username: "b", status: .offline),
            ]
            #expect(state.onlineBuddies.isEmpty)
        }

        @Test("offlineBuddies empty when all online")
        func allOnline() {
            let state = SocialState()
            state.buddies = [
                Buddy(username: "a", status: .online),
                Buddy(username: "b", status: .away),
            ]
            #expect(state.offlineBuddies.isEmpty)
        }

        @Test("both empty when no buddies")
        func noBuddies() {
            let state = SocialState()
            #expect(state.onlineBuddies.isEmpty)
            #expect(state.offlineBuddies.isEmpty)
        }
    }

    // MARK: - filteredBlockedUsers

    @Suite("filteredBlockedUsers")
    @MainActor
    struct FilteredBlockedUsersTests {

        @Test("returns all blocked users when no search query")
        func noSearch() {
            let state = SocialState()
            state.blockedUsers = [
                BlockedUser(username: "spammer"),
                BlockedUser(username: "troll"),
            ]
            #expect(state.filteredBlockedUsers.count == 2)
        }

        @Test("filters by search query case-insensitively")
        func searchFilter() {
            let state = SocialState()
            state.blockedUsers = [
                BlockedUser(username: "Spammer123"),
                BlockedUser(username: "troll"),
                BlockedUser(username: "spam_bot"),
            ]
            state.blockSearchQuery = "spam"
            let filtered = state.filteredBlockedUsers
            #expect(filtered.count == 2)
            let names = filtered.map(\.username)
            #expect(names.contains("Spammer123"))
            #expect(names.contains("spam_bot"))
        }

        @Test("returns empty when search matches nobody")
        func noMatch() {
            let state = SocialState()
            state.blockedUsers = [BlockedUser(username: "troll")]
            state.blockSearchQuery = "xyz"
            #expect(state.filteredBlockedUsers.isEmpty)
        }

        @Test("returns empty when blocklist is empty")
        func emptyBlocklist() {
            let state = SocialState()
            state.blockSearchQuery = "anything"
            #expect(state.filteredBlockedUsers.isEmpty)
        }
    }

    // MARK: - filteredIgnoredUsers

    @Suite("filteredIgnoredUsers")
    @MainActor
    struct FilteredIgnoredUsersTests {

        @Test("returns all ignored users when no search query")
        func noSearch() {
            let state = SocialState()
            state.ignoredUsers = [
                IgnoredUser(username: "annoying"),
                IgnoredUser(username: "spammer"),
            ]
            #expect(state.filteredIgnoredUsers.count == 2)
        }

        @Test("filters by search query case-insensitively")
        func searchFilter() {
            let state = SocialState()
            state.ignoredUsers = [
                IgnoredUser(username: "AnnoyingUser"),
                IgnoredUser(username: "spammer"),
                IgnoredUser(username: "annoy_bot"),
            ]
            state.ignoreSearchQuery = "annoy"
            let filtered = state.filteredIgnoredUsers
            #expect(filtered.count == 2)
            let names = filtered.map(\.username)
            #expect(names.contains("AnnoyingUser"))
            #expect(names.contains("annoy_bot"))
        }

        @Test("returns empty when search matches nobody")
        func noMatch() {
            let state = SocialState()
            state.ignoredUsers = [IgnoredUser(username: "someone")]
            state.ignoreSearchQuery = "xyz"
            #expect(state.filteredIgnoredUsers.isEmpty)
        }

        @Test("returns empty when ignore list is empty")
        func emptyIgnoreList() {
            let state = SocialState()
            state.ignoreSearchQuery = "anything"
            #expect(state.filteredIgnoredUsers.isEmpty)
        }
    }

    // MARK: - isBlocked

    @Suite("isBlocked")
    @MainActor
    struct IsBlockedTests {

        @Test("returns true for blocked user")
        func blocked() {
            let state = SocialState()
            state.blockedUsers = [BlockedUser(username: "baduser")]
            #expect(state.isBlocked("baduser"))
        }

        @Test("returns false for non-blocked user")
        func notBlocked() {
            let state = SocialState()
            state.blockedUsers = [BlockedUser(username: "baduser")]
            #expect(!state.isBlocked("gooduser"))
        }

        @Test("case-insensitive comparison")
        func caseInsensitive() {
            let state = SocialState()
            state.blockedUsers = [BlockedUser(username: "BadUser")]
            #expect(state.isBlocked("baduser"))
            #expect(state.isBlocked("BADUSER"))
            #expect(state.isBlocked("BadUser"))
        }

        @Test("returns false when blocklist is empty")
        func emptyBlocklist() {
            let state = SocialState()
            #expect(!state.isBlocked("anyone"))
        }
    }

    // MARK: - isIgnored

    @Suite("isIgnored")
    @MainActor
    struct IsIgnoredTests {

        @Test("returns true for ignored user")
        func ignored() {
            let state = SocialState()
            state.ignoredUsers = [IgnoredUser(username: "annoying")]
            #expect(state.isIgnored("annoying"))
        }

        @Test("returns false for non-ignored user")
        func notIgnored() {
            let state = SocialState()
            state.ignoredUsers = [IgnoredUser(username: "annoying")]
            #expect(!state.isIgnored("friendly"))
        }

        @Test("case-insensitive comparison")
        func caseInsensitive() {
            let state = SocialState()
            state.ignoredUsers = [IgnoredUser(username: "Annoying")]
            #expect(state.isIgnored("annoying"))
            #expect(state.isIgnored("ANNOYING"))
            #expect(state.isIgnored("Annoying"))
        }

        @Test("returns false when ignore list is empty")
        func emptyIgnoreList() {
            let state = SocialState()
            #expect(!state.isIgnored("anyone"))
        }
    }

    // MARK: - isLeech

    @Suite("isLeech")
    @MainActor
    struct IsLeechTests {

        @Test("returns true for detected leech")
        func isLeech() {
            let state = SocialState()
            state.detectedLeeches = ["freeloader"]
            #expect(state.isLeech("freeloader"))
        }

        @Test("returns false for non-leech")
        func notLeech() {
            let state = SocialState()
            state.detectedLeeches = ["freeloader"]
            #expect(!state.isLeech("sharer"))
        }

        @Test("returns false when no leeches detected")
        func noLeeches() {
            let state = SocialState()
            #expect(!state.isLeech("anyone"))
        }

        @Test("is case-sensitive (uses Set.contains)")
        func caseSensitive() {
            let state = SocialState()
            state.detectedLeeches = ["Freeloader"]
            #expect(state.isLeech("Freeloader"))
            #expect(!state.isLeech("freeloader"))
        }
    }

    // MARK: - formattedPrivilegeTime

    @Suite("formattedPrivilegeTime")
    @MainActor
    struct FormattedPrivilegeTimeTests {

        @Test("returns 'No privileges' when zero")
        func noPrivileges() {
            let state = SocialState()
            state.privilegeTimeRemaining = 0
            #expect(state.formattedPrivilegeTime == "No privileges")
        }

        @Test("formats days and hours")
        func daysAndHours() {
            let state = SocialState()
            state.privilegeTimeRemaining = 90000  // 1 day + 1 hour
            #expect(state.formattedPrivilegeTime == "1 day, 1 hour")
        }

        @Test("formats multiple days and hours")
        func multipleDays() {
            let state = SocialState()
            state.privilegeTimeRemaining = 180000  // 2 days + 2 hours
            #expect(state.formattedPrivilegeTime == "2 days, 2 hours")
        }

        @Test("formats hours and minutes when less than a day")
        func hoursAndMinutes() {
            let state = SocialState()
            state.privilegeTimeRemaining = 3660  // 1 hour + 1 minute
            #expect(state.formattedPrivilegeTime == "1 hour, 1 min")
        }

        @Test("formats zero hours and minutes")
        func zeroHoursMinutes() {
            let state = SocialState()
            state.privilegeTimeRemaining = 300  // 5 minutes
            #expect(state.formattedPrivilegeTime == "0 hours, 5 min")
        }

        @Test("formats day with zero hours")
        func dayZeroHours() {
            let state = SocialState()
            state.privilegeTimeRemaining = 86400  // exactly 1 day
            #expect(state.formattedPrivilegeTime == "1 day, 0 hours")
        }
    }

    // MARK: - shouldAllowUpload

    @Suite("shouldAllowUpload")
    @MainActor
    struct ShouldAllowUploadTests {

        @Test("denies upload to blocked user")
        func blockedUser() {
            let state = SocialState()
            state.blockedUsers = [BlockedUser(username: "baduser")]
            #expect(!state.shouldAllowUpload(to: "baduser"))
        }

        @Test("denies upload to leech when action is deny")
        func leechDeny() {
            let state = SocialState()
            state.leechSettings.enabled = true
            state.leechSettings.action = .deny
            state.detectedLeeches = ["freeloader"]
            #expect(!state.shouldAllowUpload(to: "freeloader"))
        }

        @Test("allows upload to leech when action is not deny")
        func leechWarnOnly() {
            let state = SocialState()
            state.leechSettings.enabled = true
            state.leechSettings.action = .warn
            state.detectedLeeches = ["freeloader"]
            #expect(state.shouldAllowUpload(to: "freeloader"))
        }

        @Test("allows upload to leech when leech detection is disabled")
        func leechDetectionDisabled() {
            let state = SocialState()
            state.leechSettings.enabled = false
            state.leechSettings.action = .deny
            state.detectedLeeches = ["freeloader"]
            #expect(state.shouldAllowUpload(to: "freeloader"))
        }

        @Test("allows upload to normal user")
        func normalUser() {
            let state = SocialState()
            #expect(state.shouldAllowUpload(to: "gooduser"))
        }

        @Test("blocked takes precedence over leech check")
        func blockedTakesPrecedence() {
            let state = SocialState()
            state.blockedUsers = [BlockedUser(username: "baduser")]
            state.leechSettings.enabled = true
            state.leechSettings.action = .deny
            state.detectedLeeches = ["baduser"]
            #expect(!state.shouldAllowUpload(to: "baduser"))
        }
    }

    // MARK: - checkForLeech

    @Suite("checkForLeech")
    @MainActor
    struct CheckForLeechTests {

        @Test("detects leech when files below threshold")
        func lowFiles() {
            let state = SocialState()
            state.leechSettings.enabled = true
            state.leechSettings.minSharedFiles = 10
            state.leechSettings.minSharedFolders = 1
            state.checkForLeech(username: "freeloader", files: 5, folders: 2)
            #expect(state.detectedLeeches.contains("freeloader"))
        }

        @Test("detects leech when folders below threshold")
        func lowFolders() {
            let state = SocialState()
            state.leechSettings.enabled = true
            state.leechSettings.minSharedFiles = 10
            state.leechSettings.minSharedFolders = 3
            state.checkForLeech(username: "freeloader", files: 50, folders: 1)
            #expect(state.detectedLeeches.contains("freeloader"))
        }

        @Test("does not flag user who shares enough")
        func goodUser() {
            let state = SocialState()
            state.leechSettings.enabled = true
            state.leechSettings.minSharedFiles = 10
            state.leechSettings.minSharedFolders = 1
            state.checkForLeech(username: "sharer", files: 50, folders: 5)
            #expect(!state.detectedLeeches.contains("sharer"))
        }

        @Test("does nothing when leech detection is disabled")
        func disabled() {
            let state = SocialState()
            state.leechSettings.enabled = false
            state.checkForLeech(username: "freeloader", files: 0, folders: 0)
            #expect(!state.detectedLeeches.contains("freeloader"))
        }

        @Test("does not flag blocked users")
        func blockedUser() {
            let state = SocialState()
            state.leechSettings.enabled = true
            state.blockedUsers = [BlockedUser(username: "baduser")]
            state.checkForLeech(username: "baduser", files: 0, folders: 0)
            #expect(!state.detectedLeeches.contains("baduser"))
        }

        @Test("removes leech status when user starts sharing")
        func rehabilitated() {
            let state = SocialState()
            state.leechSettings.enabled = true
            state.leechSettings.minSharedFiles = 10
            state.leechSettings.minSharedFolders = 1
            state.detectedLeeches = ["redeemed"]
            state.warnedLeeches = ["redeemed"]

            state.checkForLeech(username: "redeemed", files: 50, folders: 5)
            #expect(!state.detectedLeeches.contains("redeemed"))
            #expect(!state.warnedLeeches.contains("redeemed"))
        }

        @Test("does not duplicate detection for already-detected leech")
        func alreadyDetected() {
            let state = SocialState()
            state.leechSettings.enabled = true
            state.leechSettings.minSharedFiles = 10
            state.leechSettings.minSharedFolders = 1
            state.detectedLeeches = ["freeloader"]

            state.checkForLeech(username: "freeloader", files: 0, folders: 0)
            #expect(state.detectedLeeches.count == 1)
        }
    }
}
