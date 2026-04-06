import Testing
import Foundation
@testable import SeeleseekCore
@testable import seeleseek

@Suite(.serialized)
@MainActor
struct SearchStateCallbackTests {

    // MARK: - Helpers

    private func makeResult(
        username: String = "user1",
        filename: String = "@@music\\Artist\\Album\\track.mp3",
        size: UInt64 = 5_000_000,
        bitrate: UInt32? = 320,
        freeSlots: Bool = true,
        uploadSpeed: UInt32 = 100_000,
        queueLength: UInt32 = 0
    ) -> SearchResult {
        SearchResult(
            username: username,
            filename: filename,
            size: size,
            bitrate: bitrate,
            freeSlots: freeSlots,
            uploadSpeed: uploadSpeed,
            queueLength: queueLength
        )
    }

    // MARK: - setupCallbacks

    @Suite(.serialized)
    @MainActor
    struct SetupCallbacksTests {

        @Test("setupCallbacks stores a weak reference to the client")
        func storesClientReference() {
            let state = SearchState()
            let client = NetworkClient()
            state.setupCallbacks(client: client)
            #expect(state.networkClient === client)
        }

        @Test("setupCallbacks wires onSearchResults callback on the client")
        func wiresOnSearchResults() {
            let state = SearchState()
            let client = NetworkClient()
            #expect(client.onSearchResults == nil)
            state.setupCallbacks(client: client)
            #expect(client.onSearchResults != nil)
        }
    }

    // MARK: - startSearch

    @Suite(.serialized)
    @MainActor
    struct StartSearchTests {

        @Test("startSearch creates a new SearchQuery and appends to searches")
        func createsSearchQuery() {
            let state = SearchState()
            state.searchQuery = "daft punk"
            state.startSearch(token: 42)

            #expect(state.searches.count == 1)
            #expect(state.searches[0].query == "daft punk")
            #expect(state.searches[0].token == 42)
            #expect(state.searches[0].isSearching == true)
            #expect(state.searches[0].results.isEmpty)
        }

        @Test("startSearch selects the new tab as active")
        func selectsNewTab() {
            let state = SearchState()
            state.searchQuery = "first"
            state.startSearch(token: 1)
            #expect(state.selectedSearchIndex == 0)

            state.searchQuery = "second"
            state.startSearch(token: 2)
            #expect(state.selectedSearchIndex == 1)
        }

        @Test("startSearch adds query to search history")
        func addsToHistory() {
            let state = SearchState()
            state.searchQuery = "boards of canada"
            state.startSearch(token: 10)
            #expect(state.searchHistory.contains("boards of canada"))
        }

        @Test("startSearch does not duplicate history entries (case insensitive)")
        func noDuplicateHistory() {
            let state = SearchState()
            state.searchQuery = "Aphex Twin"
            state.startSearch(token: 1)
            state.searchQuery = "aphex twin"
            state.startSearch(token: 2)
            let matches = state.searchHistory.filter { $0.lowercased() == "aphex twin" }
            #expect(matches.count == 1)
        }

        @Test("startSearch caps history at 20 entries")
        func capsHistoryAt20() {
            let state = SearchState()
            for i in 0..<25 {
                state.searchQuery = "query \(i)"
                state.startSearch(token: UInt32(i))
            }
            #expect(state.searchHistory.count == 20)
        }

        @Test("multiple startSearch calls create multiple tabs")
        func multipleTabsCreated() {
            let state = SearchState()
            state.searchQuery = "tab1"
            state.startSearch(token: 100)
            state.searchQuery = "tab2"
            state.startSearch(token: 200)
            state.searchQuery = "tab3"
            state.startSearch(token: 300)

            #expect(state.searches.count == 3)
            #expect(state.searches[0].query == "tab1")
            #expect(state.searches[1].query == "tab2")
            #expect(state.searches[2].query == "tab3")
        }
    }

    // MARK: - addResults

    @Suite(.serialized)
    @MainActor
    struct AddResultsTests {

        private func makeResult(
            username: String = "user1",
            filename: String = "@@music\\track.mp3",
            size: UInt64 = 5_000_000
        ) -> SearchResult {
            SearchResult(username: username, filename: filename, size: size)
        }

        @Test("addResults appends results to the correct search by token")
        func appendsToCorrectSearch() {
            let state = SearchState()
            state.searchQuery = "first"
            state.startSearch(token: 10)
            state.searchQuery = "second"
            state.startSearch(token: 20)

            let results = [makeResult(username: "alice"), makeResult(username: "bob")]
            state.addResults(results, forToken: 10)

            #expect(state.searches[0].results.count == 2)
            #expect(state.searches[1].results.count == 0)
        }

        @Test("addResults accumulates results across multiple calls")
        func accumulatesResults() {
            let state = SearchState()
            state.searchQuery = "test"
            state.startSearch(token: 5)

            state.addResults([makeResult(username: "a")], forToken: 5)
            state.addResults([makeResult(username: "b"), makeResult(username: "c")], forToken: 5)

            #expect(state.searches[0].results.count == 3)
        }

        @Test("addResults does nothing for unknown token")
        func ignoresUnknownToken() {
            let state = SearchState()
            state.searchQuery = "test"
            state.startSearch(token: 1)

            state.addResults([makeResult()], forToken: 999)
            #expect(state.searches[0].results.count == 0)
        }

        @Test("addResults respects maxSearchResults from settings")
        func respectsMaxResults() {
            let state = SearchState()
            let settings = SettingsState()
            settings.maxSearchResults = 3
            state.settings = settings

            state.searchQuery = "test"
            state.startSearch(token: 1)

            let batch = (0..<5).map { makeResult(username: "user\($0)") }
            state.addResults(batch, forToken: 1)

            #expect(state.searches[0].results.count == 3)
        }

        @Test("addResults stops searching when limit reached")
        func stopsSearchingAtLimit() {
            let state = SearchState()
            let settings = SettingsState()
            settings.maxSearchResults = 2
            state.settings = settings

            state.searchQuery = "test"
            state.startSearch(token: 1)
            #expect(state.searches[0].isSearching == true)

            state.addResults([makeResult(), makeResult()], forToken: 1)
            #expect(state.searches[0].isSearching == false)
        }

        @Test("addResults ignores results after limit already reached")
        func ignoresAfterLimitReached() {
            let state = SearchState()
            let settings = SettingsState()
            settings.maxSearchResults = 2
            state.settings = settings

            state.searchQuery = "test"
            state.startSearch(token: 1)
            state.addResults([makeResult(), makeResult()], forToken: 1)

            // Further results should be ignored
            state.addResults([makeResult()], forToken: 1)
            #expect(state.searches[0].results.count == 2)
        }
    }

    // MARK: - Callback-driven flow (setupCallbacks -> onSearchResults)

    @Suite(.serialized)
    @MainActor
    struct CallbackFlowTests {

        private func makeResult(
            username: String = "user1",
            filename: String = "@@music\\track.mp3",
            size: UInt64 = 5_000_000
        ) -> SearchResult {
            SearchResult(username: username, filename: filename, size: size)
        }

        @Test("invoking onSearchResults callback adds results to matching search")
        func callbackAddsResults() {
            let state = SearchState()
            let client = NetworkClient()
            state.setupCallbacks(client: client)

            state.searchQuery = "test query"
            state.startSearch(token: 42)

            let results = [makeResult(username: "peer1"), makeResult(username: "peer2")]
            client.onSearchResults?(42, results)

            #expect(state.searches[0].results.count == 2)
            #expect(state.searches[0].results[0].username == "peer1")
        }

        @Test("callback results route to the correct search among multiple tabs")
        func callbackRoutesToCorrectTab() {
            let state = SearchState()
            let client = NetworkClient()
            state.setupCallbacks(client: client)

            state.searchQuery = "alpha"
            state.startSearch(token: 100)
            state.searchQuery = "beta"
            state.startSearch(token: 200)

            client.onSearchResults?(200, [makeResult(username: "forBeta")])
            client.onSearchResults?(100, [makeResult(username: "forAlpha")])

            #expect(state.searches[0].results.count == 1)
            #expect(state.searches[0].results[0].username == "forAlpha")
            #expect(state.searches[1].results.count == 1)
            #expect(state.searches[1].results[0].username == "forBeta")
        }

        @Test("callback with unknown token does not crash or mutate state")
        func callbackUnknownTokenSafe() {
            let state = SearchState()
            let client = NetworkClient()
            state.setupCallbacks(client: client)

            state.searchQuery = "test"
            state.startSearch(token: 1)

            client.onSearchResults?(9999, [makeResult()])
            #expect(state.searches[0].results.isEmpty)
        }
    }

    // MARK: - closeSearch

    @Suite(.serialized)
    @MainActor
    struct CloseSearchTests {

        @Test("closeSearch removes the search at the given index")
        func removesSearch() {
            let state = SearchState()
            state.searchQuery = "a"
            state.startSearch(token: 1)
            state.searchQuery = "b"
            state.startSearch(token: 2)

            state.closeSearch(at: 0)
            #expect(state.searches.count == 1)
            #expect(state.searches[0].query == "b")
        }

        @Test("closeSearch adjusts selectedSearchIndex when current tab is removed")
        func adjustsSelectedIndex() {
            let state = SearchState()
            state.searchQuery = "a"
            state.startSearch(token: 1)
            state.searchQuery = "b"
            state.startSearch(token: 2)
            state.selectedSearchIndex = 1

            state.closeSearch(at: 1)
            #expect(state.selectedSearchIndex == 0)
        }

        @Test("closeSearch updates token-to-index mapping so results still route correctly")
        func updatesTokenMapping() {
            let state = SearchState()
            let client = NetworkClient()
            state.setupCallbacks(client: client)

            state.searchQuery = "a"
            state.startSearch(token: 10)
            state.searchQuery = "b"
            state.startSearch(token: 20)
            state.searchQuery = "c"
            state.startSearch(token: 30)

            // Close the middle tab
            state.closeSearch(at: 1)

            // Results for token 30 should still route to the (now index 1) tab
            let result = SearchResult(username: "test", filename: "file.mp3", size: 100)
            client.onSearchResults?(30, [result])

            #expect(state.searches[1].results.count == 1)
            #expect(state.searches[1].query == "c")
        }

        @Test("closeSearch with out-of-range index is a no-op")
        func outOfRangeIsNoOp() {
            let state = SearchState()
            state.searchQuery = "a"
            state.startSearch(token: 1)

            state.closeSearch(at: 5)
            state.closeSearch(at: -1)
            #expect(state.searches.count == 1)
        }

        @Test("closing the last search sets selectedSearchIndex to 0")
        func closingLastSearch() {
            let state = SearchState()
            state.searchQuery = "only"
            state.startSearch(token: 1)

            state.closeSearch(at: 0)
            #expect(state.searches.isEmpty)
            #expect(state.selectedSearchIndex == 0)
        }
    }

    // MARK: - selectSearch

    @Suite(.serialized)
    @MainActor
    struct SelectSearchTests {

        @Test("selectSearch changes the selected tab index")
        func changesIndex() {
            let state = SearchState()
            state.searchQuery = "a"
            state.startSearch(token: 1)
            state.searchQuery = "b"
            state.startSearch(token: 2)

            state.selectSearch(at: 0)
            #expect(state.selectedSearchIndex == 0)
        }

        @Test("selectSearch ignores out-of-range index")
        func ignoresOutOfRange() {
            let state = SearchState()
            state.searchQuery = "a"
            state.startSearch(token: 1)
            state.selectedSearchIndex = 0

            state.selectSearch(at: 99)
            #expect(state.selectedSearchIndex == 0)
        }
    }

    // MARK: - currentSearch computed property

    @Suite(.serialized)
    @MainActor
    struct CurrentSearchTests {

        @Test("currentSearch returns nil when no searches exist")
        func nilWhenEmpty() {
            let state = SearchState()
            #expect(state.currentSearch == nil)
        }

        @Test("currentSearch returns the search at the selected index")
        func returnsSelectedSearch() {
            let state = SearchState()
            state.searchQuery = "first"
            state.startSearch(token: 1)
            state.searchQuery = "second"
            state.startSearch(token: 2)

            state.selectedSearchIndex = 0
            #expect(state.currentSearch?.query == "first")

            state.selectedSearchIndex = 1
            #expect(state.currentSearch?.query == "second")
        }

        @Test("currentSearch returns nil for out-of-range index")
        func nilForOutOfRange() {
            let state = SearchState()
            state.searchQuery = "test"
            state.startSearch(token: 1)
            state.selectedSearchIndex = 5
            #expect(state.currentSearch == nil)
        }
    }

    // MARK: - markSearchComplete

    @Suite(.serialized)
    @MainActor
    struct MarkSearchCompleteTests {

        @Test("markSearchComplete sets isSearching to false")
        func setsIsSearchingFalse() {
            let state = SearchState()
            state.searchQuery = "test"
            state.startSearch(token: 42)
            #expect(state.searches[0].isSearching == true)

            state.markSearchComplete(token: 42)
            #expect(state.searches[0].isSearching == false)
        }

        @Test("markSearchComplete with unknown token is a no-op")
        func unknownTokenNoOp() {
            let state = SearchState()
            state.searchQuery = "test"
            state.startSearch(token: 1)

            state.markSearchComplete(token: 999)
            #expect(state.searches[0].isSearching == true)
        }
    }

    // MARK: - startSearchFromCache

    @Suite(.serialized)
    @MainActor
    struct StartSearchFromCacheTests {

        @Test("startSearchFromCache adds the cached query and selects it")
        func addsCachedQuery() {
            let state = SearchState()
            var cached = SearchQuery(query: "cached query", token: 50)
            cached.results = [SearchResult(username: "u", filename: "f.mp3", size: 100)]
            cached.isSearching = false

            state.startSearchFromCache(cached)
            #expect(state.searches.count == 1)
            #expect(state.searches[0].query == "cached query")
            #expect(state.searches[0].results.count == 1)
            #expect(state.searches[0].isSearching == false)
            #expect(state.selectedSearchIndex == 0)
        }
    }

    // MARK: - Selection mode

    @Suite(.serialized)
    @MainActor
    struct SelectionModeTests {

        @Test("toggling selection mode off clears selections")
        func clearOnDeactivate() {
            let state = SearchState()
            let id = UUID()
            state.isSelectionMode = true
            state.selectedResults.insert(id)

            state.isSelectionMode = false
            #expect(state.selectedResults.isEmpty)
        }

        @Test("toggleSelection adds and removes items")
        func toggleAddRemove() {
            let state = SearchState()
            let id = UUID()
            state.toggleSelection(id)
            #expect(state.selectedResults.contains(id))

            state.toggleSelection(id)
            #expect(!state.selectedResults.contains(id))
        }

        @Test("deselectAll clears all selections")
        func deselectAllClears() {
            let state = SearchState()
            state.selectedResults = [UUID(), UUID(), UUID()]
            state.deselectAll()
            #expect(state.selectedResults.isEmpty)
        }
    }

    // MARK: - isSearching computed property

    @Suite(.serialized)
    @MainActor
    struct IsSearchingTests {

        @Test("isSearching reflects currentSearch state")
        func reflectsCurrentSearch() {
            let state = SearchState()
            #expect(state.isSearching == false)

            state.searchQuery = "test"
            state.startSearch(token: 1)
            #expect(state.isSearching == true)

            state.markSearchComplete(token: 1)
            #expect(state.isSearching == false)
        }
    }

    // MARK: - canSearch computed property

    @Suite(.serialized)
    @MainActor
    struct CanSearchTests {

        @Test("canSearch is false when query is empty or whitespace")
        func falseForEmpty() {
            let state = SearchState()
            state.searchQuery = ""
            #expect(!state.canSearch)

            state.searchQuery = "   "
            #expect(!state.canSearch)
        }

        @Test("canSearch is true when query has content")
        func trueForContent() {
            let state = SearchState()
            state.searchQuery = "radiohead"
            #expect(state.canSearch)
        }
    }

    // MARK: - clearFilters

    @Suite(.serialized)
    @MainActor
    struct ClearFiltersTests {

        @Test("clearFilters resets all filter properties to defaults")
        func resetsAll() {
            let state = SearchState()
            state.filterMinBitrate = 320
            state.filterMinSampleRate = 44100
            state.filterMinBitDepth = 24
            state.filterMinSize = 1000
            state.filterMaxSize = 99999
            state.filterExtensions = ["flac", "mp3"]
            state.filterFreeSlotOnly = true
            state.sortOrder = .bitrate
            state.resultGrouping = .byUser

            state.clearFilters()

            #expect(state.filterMinBitrate == nil)
            #expect(state.filterMinSampleRate == nil)
            #expect(state.filterMinBitDepth == nil)
            #expect(state.filterMinSize == nil)
            #expect(state.filterMaxSize == nil)
            #expect(state.filterExtensions.isEmpty)
            #expect(state.filterFreeSlotOnly == false)
            #expect(state.sortOrder == .relevance)
            #expect(state.resultGrouping == .flat)
        }
    }
}
