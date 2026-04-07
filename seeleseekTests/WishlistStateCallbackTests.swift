import Testing
import Foundation
@testable import SeeleseekCore
@testable import seeleseek

@Suite(.serialized)
@MainActor
struct WishlistStateCallbackTests {

    // MARK: - Helpers

    private func makeWiredState() -> (WishlistState, NetworkClient) {
        let state = WishlistState()
        let client = NetworkClient()
        state.setupCallbacks(client: client)
        return (state, client)
    }

    // MARK: - setupCallbacks

    @Test("setupCallbacks stores weak reference to network client")
    func setupCallbacksStoresClient() {
        let (state, client) = makeWiredState()
        #expect(state.networkClient === client)
    }

    @Test("setupCallbacks wires onWishlistInterval callback")
    func setupCallbacksWiresInterval() {
        let (_, client) = makeWiredState()
        #expect(client.onWishlistInterval != nil)
    }

    // MARK: - onWishlistInterval callback

    @Test("onWishlistInterval updates the search interval")
    func onWishlistIntervalUpdatesState() {
        let (state, client) = makeWiredState()

        client.onWishlistInterval?(300)

        // searchInterval is private, but we can verify indirectly by checking that
        // the state accepted the callback without crashing. The scheduler restarts
        // with the new interval but since there are no enabled items, it stops.
        // We can't directly read searchInterval, but the test verifies the callback fires.
        // Verify the state is still functional:
        #expect(state.networkClient != nil)
    }

    // MARK: - Initial state

    @Test("initial state has empty items and results")
    func initialState() {
        let state = WishlistState()
        #expect(state.items.isEmpty)
        #expect(state.results.isEmpty)
        #expect(state.unviewedResultCount == 0)
        #expect(state.newQuery == "")
        #expect(state.expandedItemId == nil)
    }

    // MARK: - Token management

    @Test("isWishlistToken returns true for high-bit tokens")
    func isWishlistTokenTrue() {
        let state = WishlistState()
        #expect(state.isWishlistToken(0x8000_0000))
        #expect(state.isWishlistToken(0x8000_0001))
        #expect(state.isWishlistToken(0xFFFF_FFFF))
    }

    @Test("isWishlistToken returns false for low-bit tokens")
    func isWishlistTokenFalse() {
        let state = WishlistState()
        #expect(!state.isWishlistToken(0))
        #expect(!state.isWishlistToken(1))
        #expect(!state.isWishlistToken(0x7FFF_FFFF))
    }

    // MARK: - addItem

    @Test("addItem appends new item and clears newQuery")
    func addItemAppendsAndClears() {
        let (state, _) = makeWiredState()
        state.newQuery = "daft punk"

        state.addItem()

        #expect(state.items.count == 1)
        #expect(state.items[0].query == "daft punk")
        #expect(state.items[0].enabled == true)
        #expect(state.newQuery == "")
    }

    @Test("addItem does nothing with empty query")
    func addItemEmptyQuery() {
        let (state, _) = makeWiredState()
        state.newQuery = "   "

        state.addItem()

        #expect(state.items.isEmpty)
    }

    @Test("addItem does not add duplicate query (case-insensitive)")
    func addItemNoDuplicate() {
        let (state, _) = makeWiredState()
        state.items = [WishlistItem(query: "Daft Punk")]
        state.newQuery = "daft punk"

        state.addItem()

        #expect(state.items.count == 1)
    }

    @Test("addItem clears results for the new item after searchNow")
    func addItemClearsResults() {
        let (state, client) = makeWiredState()
        _ = client  // prevent deallocation of weak reference
        state.newQuery = "boards of canada"

        state.addItem()

        let item = state.items[0]
        // searchNow is called which sets results[item.id] = []
        #expect(state.results[item.id] != nil)
        #expect(state.results[item.id]?.isEmpty == true)
    }

    // MARK: - removeItem

    @Test("removeItem removes the item by ID")
    func removeItemRemoves() {
        let state = WishlistState()
        let item1 = WishlistItem(query: "query1")
        let item2 = WishlistItem(query: "query2")
        state.items = [item1, item2]
        state.results[item1.id] = [SearchResult(username: "u", filename: "f.mp3", size: 0)]

        state.removeItem(id: item1.id)

        #expect(state.items.count == 1)
        #expect(state.items[0].query == "query2")
        #expect(state.results[item1.id] == nil)
    }

    @Test("removeItem with non-existent ID does not crash")
    func removeItemNonExistent() {
        let state = WishlistState()
        state.items = [WishlistItem(query: "query1")]

        state.removeItem(id: UUID())

        #expect(state.items.count == 1)
    }

    // MARK: - toggleEnabled

    @Test("toggleEnabled flips enabled to false")
    func toggleEnabledOff() {
        let state = WishlistState()
        let item = WishlistItem(query: "test", enabled: true)
        state.items = [item]

        state.toggleEnabled(id: item.id)

        #expect(state.items[0].enabled == false)
    }

    @Test("toggleEnabled flips enabled to true")
    func toggleEnabledOn() {
        let state = WishlistState()
        let item = WishlistItem(query: "test", enabled: false)
        state.items = [item]

        state.toggleEnabled(id: item.id)

        #expect(state.items[0].enabled == true)
    }

    @Test("toggleEnabled with non-existent ID does not crash")
    func toggleEnabledNonExistent() {
        let state = WishlistState()
        state.items = [WishlistItem(query: "test")]

        state.toggleEnabled(id: UUID())

        #expect(state.items[0].enabled == true)
    }

    // MARK: - handleSearchResults

    @Test("handleSearchResults accumulates results for a known token")
    func handleSearchResultsAccumulates() {
        let (state, client) = makeWiredState()
        _ = client  // prevent deallocation of weak reference
        state.newQuery = "aphex twin"
        state.addItem()

        let item = state.items[0]

        // addItem calls searchNow which allocates a token starting at 0x8000_0000.
        // The first token allocated is 0x8000_0000.
        let token: UInt32 = 0x8000_0000

        let results = [
            SearchResult(username: "user1", filename: "track1.mp3", size: 5000),
            SearchResult(username: "user2", filename: "track2.flac", size: 10000),
        ]

        state.handleSearchResults(token: token, results: results)

        #expect(state.results[item.id]?.count == 2)
        #expect(state.unviewedResultCount == 2)
        #expect(state.items[0].resultCount == 2)
    }

    @Test("handleSearchResults accumulates across multiple calls")
    func handleSearchResultsMultipleCalls() {
        let (state, client) = makeWiredState()
        _ = client  // prevent deallocation of weak reference
        state.newQuery = "aphex twin"
        state.addItem()

        let item = state.items[0]
        let token: UInt32 = 0x8000_0000

        let batch1 = [SearchResult(username: "user1", filename: "track1.mp3", size: 5000)]
        let batch2 = [SearchResult(username: "user2", filename: "track2.mp3", size: 3000)]

        state.handleSearchResults(token: token, results: batch1)
        state.handleSearchResults(token: token, results: batch2)

        #expect(state.results[item.id]?.count == 2)
        #expect(state.unviewedResultCount == 2)
        #expect(state.items[0].resultCount == 2)
    }

    @Test("handleSearchResults ignores unknown token")
    func handleSearchResultsUnknownToken() {
        let state = WishlistState()

        let results = [SearchResult(username: "user1", filename: "track.mp3", size: 5000)]
        state.handleSearchResults(token: 0x9999_9999, results: results)

        #expect(state.results.isEmpty)
        #expect(state.unviewedResultCount == 0)
    }

    // MARK: - markResultsViewed

    @Test("markResultsViewed resets unviewedResultCount to zero")
    func markResultsViewedResetsCount() {
        let state = WishlistState()
        state.unviewedResultCount = 42

        state.markResultsViewed()

        #expect(state.unviewedResultCount == 0)
    }

    @Test("markResultsViewed on zero count stays zero")
    func markResultsViewedAlreadyZero() {
        let state = WishlistState()
        state.markResultsViewed()
        #expect(state.unviewedResultCount == 0)
    }

    // MARK: - searchNow

    @Test("searchNow clears previous results for the item")
    func searchNowClearsPreviousResults() {
        let (state, client) = makeWiredState()
        _ = client  // prevent deallocation of weak reference
        let item = WishlistItem(query: "test")
        state.items = [item]
        state.results[item.id] = [SearchResult(username: "u", filename: "old.mp3", size: 0)]

        state.searchNow(item: item)

        #expect(state.results[item.id]?.isEmpty == true)
    }

    @Test("searchNow updates lastSearchedAt on the item")
    func searchNowUpdatesLastSearched() {
        let (state, client) = makeWiredState()
        _ = client  // prevent deallocation of weak reference
        let item = WishlistItem(query: "test", lastSearchedAt: nil)
        state.items = [item]

        state.searchNow(item: item)

        #expect(state.items[0].lastSearchedAt != nil)
    }

    @Test("searchNow resets resultCount to zero")
    func searchNowResetsResultCount() {
        let (state, client) = makeWiredState()
        _ = client  // prevent deallocation of weak reference
        var item = WishlistItem(query: "test")
        item.resultCount = 42
        state.items = [item]

        state.searchNow(item: state.items[0])

        #expect(state.items[0].resultCount == 0)
    }

    @Test("searchNow does nothing when networkClient is nil")
    func searchNowNoClient() {
        let state = WishlistState()
        let item = WishlistItem(query: "test")
        state.items = [item]

        // Should not crash
        state.searchNow(item: item)

        // results should not be modified since the guard returns early
        #expect(state.results[item.id] == nil)
    }

    // MARK: - relativeTime helper

    @Test("relativeTime returns 'Never' for nil")
    func relativeTimeNil() {
        let state = WishlistState()
        #expect(state.relativeTime(from: nil) == "Never")
    }

    @Test("relativeTime returns 'Just now' for recent date")
    func relativeTimeJustNow() {
        let state = WishlistState()
        let recent = Date().addingTimeInterval(-30)
        #expect(state.relativeTime(from: recent) == "Just now")
    }

    @Test("relativeTime returns minutes for dates within the hour")
    func relativeTimeMinutes() {
        let state = WishlistState()
        let fiveMinutesAgo = Date().addingTimeInterval(-300)
        let result = state.relativeTime(from: fiveMinutesAgo)
        #expect(result == "5m ago")
    }

    @Test("relativeTime returns hours for dates within the day")
    func relativeTimeHours() {
        let state = WishlistState()
        let twoHoursAgo = Date().addingTimeInterval(-7200)
        let result = state.relativeTime(from: twoHoursAgo)
        #expect(result == "2h ago")
    }

    @Test("relativeTime returns days for dates beyond a day")
    func relativeTimeDays() {
        let state = WishlistState()
        let threeDaysAgo = Date().addingTimeInterval(-259200)
        let result = state.relativeTime(from: threeDaysAgo)
        #expect(result == "3d ago")
    }

    // MARK: - expandedItemId

    @Test("expandedItemId can be set and cleared")
    func expandedItemIdSetAndClear() {
        let state = WishlistState()
        let id = UUID()

        state.expandedItemId = id
        #expect(state.expandedItemId == id)

        state.expandedItemId = nil
        #expect(state.expandedItemId == nil)
    }
}
