import Testing
import Foundation
@testable import SeeleseekCore
@testable import seeleseek

@Suite("SearchState Filters")
@MainActor
struct SearchStateFilterTests {

    // MARK: - Helpers

    /// Create a SearchState with a single search tab populated with the given results.
    private func makeState(results: [SearchResult]) -> SearchState {
        let state = SearchState()
        var query = SearchQuery(query: "test", token: 1)
        query.results = results
        query.isSearching = false
        state.searches = [query]
        state.selectedSearchIndex = 0
        return state
    }

    /// Convenience: build a SearchResult with only the fields under test filled in.
    private func result(
        username: String = "user",
        filename: String = "track.mp3",
        size: UInt64 = 1000,
        bitrate: UInt32? = nil,
        sampleRate: UInt32? = nil,
        bitDepth: UInt32? = nil,
        freeSlots: Bool = true,
        uploadSpeed: UInt32 = 0,
        queueLength: UInt32 = 0
    ) -> SearchResult {
        SearchResult(
            username: username,
            filename: filename,
            size: size,
            bitrate: bitrate,
            sampleRate: sampleRate,
            bitDepth: bitDepth,
            freeSlots: freeSlots,
            uploadSpeed: uploadSpeed,
            queueLength: queueLength
        )
    }

    // MARK: - hasActiveFilters

    @Suite("hasActiveFilters")
    @MainActor
    struct HasActiveFiltersTests {
        @Test("false when no filters are set")
        func noFilters() {
            let state = SearchState()
            #expect(!state.hasActiveFilters)
        }

        @Test("true when filterMinBitrate is set")
        func minBitrate() {
            let state = SearchState()
            state.filterMinBitrate = 320
            #expect(state.hasActiveFilters)
        }

        @Test("true when filterMinSampleRate is set")
        func minSampleRate() {
            let state = SearchState()
            state.filterMinSampleRate = 44100
            #expect(state.hasActiveFilters)
        }

        @Test("true when filterMinBitDepth is set")
        func minBitDepth() {
            let state = SearchState()
            state.filterMinBitDepth = 24
            #expect(state.hasActiveFilters)
        }

        @Test("true when filterMinSize is set")
        func minSize() {
            let state = SearchState()
            state.filterMinSize = 1000
            #expect(state.hasActiveFilters)
        }

        @Test("true when filterMaxSize is set")
        func maxSize() {
            let state = SearchState()
            state.filterMaxSize = 100_000
            #expect(state.hasActiveFilters)
        }

        @Test("true when filterExtensions is not empty")
        func extensions() {
            let state = SearchState()
            state.filterExtensions = ["mp3"]
            #expect(state.hasActiveFilters)
        }

        @Test("true when filterFreeSlotOnly is true")
        func freeSlotOnly() {
            let state = SearchState()
            state.filterFreeSlotOnly = true
            #expect(state.hasActiveFilters)
        }
    }

    // MARK: - activeFilterCount

    @Suite("activeFilterCount")
    @MainActor
    struct ActiveFilterCountTests {
        @Test("zero when no filters set")
        func noFilters() {
            let state = SearchState()
            #expect(state.activeFilterCount == 0)
        }

        @Test("counts each active filter independently")
        func allFilters() {
            let state = SearchState()
            state.filterMinBitrate = 320
            state.filterMinSampleRate = 44100
            state.filterMinBitDepth = 24
            state.filterExtensions = ["flac"]
            state.filterFreeSlotOnly = true
            state.filterMinSize = 1000
            state.filterMaxSize = 100_000
            #expect(state.activeFilterCount == 7)
        }

        @Test("counts only set filters")
        func partialFilters() {
            let state = SearchState()
            state.filterMinBitrate = 320
            state.filterFreeSlotOnly = true
            #expect(state.activeFilterCount == 2)
        }
    }

    // MARK: - filteredResults

    @Suite("filteredResults")
    @MainActor
    struct FilteredResultsTests {

        private func makeState(results: [SearchResult]) -> SearchState {
            let state = SearchState()
            var query = SearchQuery(query: "test", token: 1)
            query.results = results
            query.isSearching = false
            state.searches = [query]
            state.selectedSearchIndex = 0
            return state
        }

        private func result(
            username: String = "user",
            filename: String = "track.mp3",
            size: UInt64 = 1000,
            bitrate: UInt32? = nil,
            sampleRate: UInt32? = nil,
            bitDepth: UInt32? = nil,
            freeSlots: Bool = true,
            uploadSpeed: UInt32 = 0,
            queueLength: UInt32 = 0
        ) -> SearchResult {
            SearchResult(
                username: username,
                filename: filename,
                size: size,
                bitrate: bitrate,
                sampleRate: sampleRate,
                bitDepth: bitDepth,
                freeSlots: freeSlots,
                uploadSpeed: uploadSpeed,
                queueLength: queueLength
            )
        }

        @Test("returns empty when no current search")
        func noSearch() {
            let state = SearchState()
            #expect(state.filteredResults.isEmpty)
        }

        @Test("returns all results when no filters are active")
        func noFilters() {
            let state = makeState(results: [
                result(filename: "a.mp3"),
                result(filename: "b.flac"),
            ])
            #expect(state.filteredResults.count == 2)
        }

        @Test("filters by minimum bitrate")
        func minBitrate() {
            let state = makeState(results: [
                result(filename: "low.mp3", bitrate: 128),
                result(filename: "high.mp3", bitrate: 320),
                result(filename: "nil.mp3", bitrate: nil),
            ])
            state.filterMinBitrate = 256
            let filtered = state.filteredResults
            #expect(filtered.count == 1)
            #expect(filtered[0].bitrate == 320)
        }

        @Test("filters by minimum sample rate")
        func minSampleRate() {
            let state = makeState(results: [
                result(filename: "low.flac", sampleRate: 44100),
                result(filename: "high.flac", sampleRate: 96000),
                result(filename: "nil.flac", sampleRate: nil),
            ])
            state.filterMinSampleRate = 48000
            let filtered = state.filteredResults
            #expect(filtered.count == 1)
            #expect(filtered[0].sampleRate == 96000)
        }

        @Test("filters by minimum bit depth")
        func minBitDepth() {
            let state = makeState(results: [
                result(filename: "16.flac", bitDepth: 16),
                result(filename: "24.flac", bitDepth: 24),
                result(filename: "nil.flac", bitDepth: nil),
            ])
            state.filterMinBitDepth = 24
            let filtered = state.filteredResults
            #expect(filtered.count == 1)
            #expect(filtered[0].bitDepth == 24)
        }

        @Test("filters by minimum size")
        func minSize() {
            let state = makeState(results: [
                result(filename: "small.mp3", size: 500),
                result(filename: "big.mp3", size: 5000),
            ])
            state.filterMinSize = 1000
            let filtered = state.filteredResults
            #expect(filtered.count == 1)
            #expect(filtered[0].size == 5000)
        }

        @Test("filters by maximum size")
        func maxSize() {
            let state = makeState(results: [
                result(filename: "small.mp3", size: 500),
                result(filename: "big.mp3", size: 5000),
            ])
            state.filterMaxSize = 1000
            let filtered = state.filteredResults
            #expect(filtered.count == 1)
            #expect(filtered[0].size == 500)
        }

        @Test("filters by size range (min and max)")
        func sizeRange() {
            let state = makeState(results: [
                result(filename: "tiny.mp3", size: 100),
                result(filename: "medium.mp3", size: 1000),
                result(filename: "huge.mp3", size: 10_000),
            ])
            state.filterMinSize = 500
            state.filterMaxSize = 5000
            let filtered = state.filteredResults
            #expect(filtered.count == 1)
            #expect(filtered[0].size == 1000)
        }

        @Test("filters by file extension")
        func extensionFilter() {
            let state = makeState(results: [
                result(filename: "song.mp3"),
                result(filename: "song.flac"),
                result(filename: "song.wav"),
            ])
            state.filterExtensions = ["flac", "wav"]
            let filtered = state.filteredResults
            #expect(filtered.count == 2)
            let extensions = Set(filtered.map(\.fileExtension))
            #expect(extensions == ["flac", "wav"])
        }

        @Test("filters by free slots only")
        func freeSlots() {
            let state = makeState(results: [
                result(filename: "free.mp3", freeSlots: true),
                result(filename: "busy.mp3", freeSlots: false),
            ])
            state.filterFreeSlotOnly = true
            let filtered = state.filteredResults
            #expect(filtered.count == 1)
            #expect(filtered[0].freeSlots)
        }

        @Test("combines multiple filters")
        func combinedFilters() {
            let state = makeState(results: [
                result(filename: "good.flac", size: 5000, bitrate: 320, freeSlots: true),
                result(filename: "wrong_ext.mp3", size: 5000, bitrate: 320, freeSlots: true),
                result(filename: "low_bitrate.flac", size: 5000, bitrate: 128, freeSlots: true),
                result(filename: "no_slots.flac", size: 5000, bitrate: 320, freeSlots: false),
                result(filename: "too_small.flac", size: 100, bitrate: 320, freeSlots: true),
            ])
            state.filterExtensions = ["flac"]
            state.filterMinBitrate = 256
            state.filterFreeSlotOnly = true
            state.filterMinSize = 1000
            let filtered = state.filteredResults
            #expect(filtered.count == 1)
            #expect(filtered[0].filename == "good.flac")
        }
    }

    // MARK: - Sort Ordering

    @Suite("sortOrder")
    @MainActor
    struct SortOrderTests {

        private func makeState(results: [SearchResult]) -> SearchState {
            let state = SearchState()
            var query = SearchQuery(query: "test", token: 1)
            query.results = results
            query.isSearching = false
            state.searches = [query]
            state.selectedSearchIndex = 0
            return state
        }

        private func result(
            filename: String = "track.mp3",
            size: UInt64 = 1000,
            bitrate: UInt32? = nil,
            sampleRate: UInt32? = nil,
            uploadSpeed: UInt32 = 0,
            queueLength: UInt32 = 0
        ) -> SearchResult {
            SearchResult(
                username: "user",
                filename: filename,
                size: size,
                bitrate: bitrate,
                sampleRate: sampleRate,
                uploadSpeed: uploadSpeed,
                queueLength: queueLength
            )
        }

        @Test("relevance preserves original order")
        func relevance() {
            let state = makeState(results: [
                result(filename: "first.mp3", bitrate: 128),
                result(filename: "second.mp3", bitrate: 320),
                result(filename: "third.mp3", bitrate: 256),
            ])
            state.sortOrder = .relevance
            let names = state.filteredResults.map(\.filename)
            #expect(names == ["first.mp3", "second.mp3", "third.mp3"])
        }

        @Test("bitrate sorts descending")
        func bitrate() {
            let state = makeState(results: [
                result(filename: "low.mp3", bitrate: 128),
                result(filename: "high.mp3", bitrate: 320),
                result(filename: "mid.mp3", bitrate: 256),
            ])
            state.sortOrder = .bitrate
            let bitrates = state.filteredResults.compactMap(\.bitrate)
            #expect(bitrates == [320, 256, 128])
        }

        @Test("sampleRate sorts descending")
        func sampleRate() {
            let state = makeState(results: [
                result(filename: "low.flac", sampleRate: 44100),
                result(filename: "high.flac", sampleRate: 96000),
                result(filename: "mid.flac", sampleRate: 48000),
            ])
            state.sortOrder = .sampleRate
            let rates = state.filteredResults.compactMap(\.sampleRate)
            #expect(rates == [96000, 48000, 44100])
        }

        @Test("size sorts descending")
        func size() {
            let state = makeState(results: [
                result(filename: "small.mp3", size: 100),
                result(filename: "large.mp3", size: 10_000),
                result(filename: "medium.mp3", size: 1000),
            ])
            state.sortOrder = .size
            let sizes = state.filteredResults.map(\.size)
            #expect(sizes == [10_000, 1000, 100])
        }

        @Test("speed sorts descending")
        func speed() {
            let state = makeState(results: [
                result(filename: "slow.mp3", uploadSpeed: 100),
                result(filename: "fast.mp3", uploadSpeed: 10_000),
                result(filename: "mid.mp3", uploadSpeed: 1000),
            ])
            state.sortOrder = .speed
            let speeds = state.filteredResults.map(\.uploadSpeed)
            #expect(speeds == [10_000, 1000, 100])
        }

        @Test("queue sorts ascending")
        func queue() {
            let state = makeState(results: [
                result(filename: "long.mp3", queueLength: 50),
                result(filename: "short.mp3", queueLength: 1),
                result(filename: "mid.mp3", queueLength: 10),
            ])
            state.sortOrder = .queue
            let queues = state.filteredResults.map(\.queueLength)
            #expect(queues == [1, 10, 50])
        }

        @Test("nil bitrate treated as zero when sorting")
        func nilBitrateSorting() {
            let state = makeState(results: [
                result(filename: "nil.mp3", bitrate: nil),
                result(filename: "has.mp3", bitrate: 320),
            ])
            state.sortOrder = .bitrate
            let names = state.filteredResults.map(\.filename)
            #expect(names == ["has.mp3", "nil.mp3"])
        }
    }

    // MARK: - Presets

    @Suite("presets")
    @MainActor
    struct PresetTests {

        @Test("applyPreset sets mp3_320 filters")
        func applyMp3320() {
            let state = SearchState()
            state.applyPreset(.mp3_320)
            #expect(state.filterExtensions == ["mp3"])
            #expect(state.filterMinBitrate == 320)
            #expect(state.filterMinSampleRate == nil)
            #expect(state.filterMinBitDepth == nil)
        }

        @Test("applyPreset sets flac filters")
        func applyFlac() {
            let state = SearchState()
            state.applyPreset(.flac)
            #expect(state.filterExtensions == ["flac"])
            #expect(state.filterMinBitrate == nil)
        }

        @Test("applyPreset sets lossless filters")
        func applyLossless() {
            let state = SearchState()
            state.applyPreset(.lossless)
            #expect(state.filterExtensions == ["flac", "wav", "aiff", "alac", "ape"])
            #expect(state.filterMinBitrate == nil)
        }

        @Test("applyPreset sets hiRes filters")
        func applyHiRes() {
            let state = SearchState()
            state.applyPreset(.hiRes)
            #expect(state.filterExtensions == ["flac", "wav", "aiff", "alac"])
            #expect(state.filterMinSampleRate == 96000)
            #expect(state.filterMinBitDepth == 24)
            #expect(state.filterMinBitrate == nil)
        }

        @Test("isPresetActive returns true when preset matches")
        func isPresetActiveTrue() {
            let state = SearchState()
            state.applyPreset(.mp3_320)
            #expect(state.isPresetActive(.mp3_320))
        }

        @Test("isPresetActive returns false when preset does not match")
        func isPresetActiveFalse() {
            let state = SearchState()
            state.applyPreset(.mp3_320)
            #expect(!state.isPresetActive(.flac))
            #expect(!state.isPresetActive(.hiRes))
            #expect(!state.isPresetActive(.lossless))
        }

        @Test("isPresetActive returns false when no preset applied")
        func isPresetActiveNoPreset() {
            let state = SearchState()
            #expect(!state.isPresetActive(.mp3_320))
        }

        @Test("applying the same preset twice toggles it off")
        func togglePreset() {
            let state = SearchState()
            state.applyPreset(.flac)
            #expect(state.isPresetActive(.flac))

            state.applyPreset(.flac)
            #expect(!state.isPresetActive(.flac))
            #expect(state.filterExtensions.isEmpty)
            #expect(state.filterMinBitrate == nil)
            #expect(state.filterMinSampleRate == nil)
            #expect(state.filterMinBitDepth == nil)
        }

        @Test("applying a different preset replaces the current one")
        func switchPreset() {
            let state = SearchState()
            state.applyPreset(.mp3_320)
            #expect(state.isPresetActive(.mp3_320))

            state.applyPreset(.hiRes)
            #expect(!state.isPresetActive(.mp3_320))
            #expect(state.isPresetActive(.hiRes))
        }
    }

    // MARK: - toggleExtension

    @Suite("toggleExtension")
    @MainActor
    struct ToggleExtensionTests {

        @Test("adds an extension when not present")
        func addExtension() {
            let state = SearchState()
            state.toggleExtension("mp3")
            #expect(state.filterExtensions.contains("mp3"))
        }

        @Test("removes an extension when already present")
        func removeExtension() {
            let state = SearchState()
            state.filterExtensions = ["mp3", "flac"]
            state.toggleExtension("mp3")
            #expect(!state.filterExtensions.contains("mp3"))
            #expect(state.filterExtensions.contains("flac"))
        }

        @Test("toggling the same extension twice is a no-op")
        func doubleToggle() {
            let state = SearchState()
            state.toggleExtension("wav")
            state.toggleExtension("wav")
            #expect(!state.filterExtensions.contains("wav"))
        }
    }

    // MARK: - clearFilters

    @Suite("clearFilters")
    @MainActor
    struct ClearFiltersTests {

        @Test("resets all filters to defaults")
        func clearAll() {
            let state = SearchState()
            state.filterMinBitrate = 320
            state.filterMinSampleRate = 96000
            state.filterMinBitDepth = 24
            state.filterMinSize = 1000
            state.filterMaxSize = 100_000
            state.filterExtensions = ["flac"]
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
            #expect(!state.filterFreeSlotOnly)
            #expect(state.sortOrder == .relevance)
            #expect(state.resultGrouping == .flat)
        }

        @Test("clearFilters has no effect when filters are already default")
        func clearAlreadyDefault() {
            let state = SearchState()
            state.clearFilters()
            #expect(!state.hasActiveFilters)
            #expect(state.activeFilterCount == 0)
        }
    }

    // MARK: - Selection

    @Suite("selection")
    @MainActor
    struct SelectionTests {

        private func makeState(results: [SearchResult]) -> SearchState {
            let state = SearchState()
            var query = SearchQuery(query: "test", token: 1)
            query.results = results
            query.isSearching = false
            state.searches = [query]
            state.selectedSearchIndex = 0
            return state
        }

        @Test("toggleSelection adds an id when not present")
        func toggleAdds() {
            let state = SearchState()
            let id = UUID()
            state.toggleSelection(id)
            #expect(state.selectedResults.contains(id))
        }

        @Test("toggleSelection removes an id when already present")
        func toggleRemoves() {
            let state = SearchState()
            let id = UUID()
            state.selectedResults.insert(id)
            state.toggleSelection(id)
            #expect(!state.selectedResults.contains(id))
        }

        @Test("toggleSelection twice is a no-op")
        func toggleTwice() {
            let state = SearchState()
            let id = UUID()
            state.toggleSelection(id)
            state.toggleSelection(id)
            #expect(!state.selectedResults.contains(id))
        }

        @Test("selectAll selects all filtered result ids")
        func selectAll() {
            let r1 = SearchResult(username: "u", filename: "a.mp3", size: 0)
            let r2 = SearchResult(username: "u", filename: "b.mp3", size: 0)
            let r3 = SearchResult(username: "u", filename: "c.mp3", size: 0)
            let state = makeState(results: [r1, r2, r3])
            state.selectAll()
            #expect(state.selectedResults.count == 3)
            #expect(state.selectedResults.contains(r1.id))
            #expect(state.selectedResults.contains(r2.id))
            #expect(state.selectedResults.contains(r3.id))
        }

        @Test("selectAll respects active filters")
        func selectAllWithFilters() {
            let r1 = SearchResult(username: "u", filename: "a.mp3", size: 0, bitrate: 320)
            let r2 = SearchResult(username: "u", filename: "b.mp3", size: 0, bitrate: 128)
            let state = makeState(results: [r1, r2])
            state.filterMinBitrate = 256
            state.selectAll()
            #expect(state.selectedResults.count == 1)
            #expect(state.selectedResults.contains(r1.id))
            #expect(!state.selectedResults.contains(r2.id))
        }

        @Test("deselectAll removes all selections")
        func deselectAll() {
            let state = SearchState()
            state.selectedResults = [UUID(), UUID(), UUID()]
            state.deselectAll()
            #expect(state.selectedResults.isEmpty)
        }

        @Test("disabling selection mode clears selections")
        func disableSelectionMode() {
            let state = SearchState()
            state.isSelectionMode = true
            state.selectedResults = [UUID(), UUID()]
            state.isSelectionMode = false
            #expect(state.selectedResults.isEmpty)
        }

        @Test("enabling selection mode does not clear existing selections")
        func enableSelectionMode() {
            let state = SearchState()
            let id = UUID()
            state.selectedResults = [id]
            state.isSelectionMode = true
            #expect(state.selectedResults.contains(id))
        }
    }

    // MARK: - canSearch

    @Suite("canSearch")
    @MainActor
    struct CanSearchTests {

        @Test("false when query is empty")
        func emptyQuery() {
            let state = SearchState()
            state.searchQuery = ""
            #expect(!state.canSearch)
        }

        @Test("false when query is only whitespace")
        func whitespaceQuery() {
            let state = SearchState()
            state.searchQuery = "   "
            #expect(!state.canSearch)
        }

        @Test("true when query has content")
        func validQuery() {
            let state = SearchState()
            state.searchQuery = "daft punk"
            #expect(state.canSearch)
        }
    }

    // MARK: - isSearching

    @Suite("isSearching")
    @MainActor
    struct IsSearchingTests {

        @Test("false when there is no current search")
        func noSearch() {
            let state = SearchState()
            #expect(!state.isSearching)
        }

        @Test("true when current search is actively searching")
        func activeSearch() {
            let state = SearchState()
            var query = SearchQuery(query: "test", token: 1)
            query.isSearching = true
            state.searches = [query]
            state.selectedSearchIndex = 0
            #expect(state.isSearching)
        }

        @Test("false when current search has completed")
        func completedSearch() {
            let state = SearchState()
            var query = SearchQuery(query: "test", token: 1)
            query.isSearching = false
            state.searches = [query]
            state.selectedSearchIndex = 0
            #expect(!state.isSearching)
        }
    }

    // MARK: - groupedResults

    @Suite("groupedResults")
    @MainActor
    struct GroupedResultsTests {

        private func makeState(results: [SearchResult]) -> SearchState {
            let state = SearchState()
            var query = SearchQuery(query: "test", token: 1)
            query.results = results
            query.isSearching = false
            state.searches = [query]
            state.selectedSearchIndex = 0
            return state
        }

        @Test("flat grouping puts all results under one key")
        func flatGrouping() {
            let state = makeState(results: [
                SearchResult(username: "alice", filename: "a.mp3", size: 0),
                SearchResult(username: "bob", filename: "b.mp3", size: 0),
            ])
            state.resultGrouping = .flat
            let grouped = state.groupedResults
            #expect(grouped.count == 1)
            #expect(grouped["All Results"]?.count == 2)
        }

        @Test("byUser groups results by username")
        func byUser() {
            let state = makeState(results: [
                SearchResult(username: "alice", filename: "a.mp3", size: 0),
                SearchResult(username: "bob", filename: "b.mp3", size: 0),
                SearchResult(username: "alice", filename: "c.mp3", size: 0),
            ])
            state.resultGrouping = .byUser
            let grouped = state.groupedResults
            #expect(grouped.count == 2)
            #expect(grouped["alice"]?.count == 2)
            #expect(grouped["bob"]?.count == 1)
        }

        @Test("byFolder groups results by folder path")
        func byFolder() {
            let state = makeState(results: [
                SearchResult(username: "u", filename: "Music\\Artist\\song1.mp3", size: 0),
                SearchResult(username: "u", filename: "Music\\Artist\\song2.mp3", size: 0),
                SearchResult(username: "u", filename: "Other\\song3.mp3", size: 0),
            ])
            state.resultGrouping = .byFolder
            let grouped = state.groupedResults
            #expect(grouped.count == 2)
            #expect(grouped["Music\\Artist"]?.count == 2)
            #expect(grouped["Other"]?.count == 1)
        }

        @Test("byFolder uses Root for files with no folder")
        func byFolderRoot() {
            let state = makeState(results: [
                SearchResult(username: "u", filename: "song.mp3", size: 0),
            ])
            state.resultGrouping = .byFolder
            let grouped = state.groupedResults
            #expect(grouped["Root"]?.count == 1)
        }
    }

    // MARK: - sortedGroupKeys

    @Suite("sortedGroupKeys")
    @MainActor
    struct SortedGroupKeysTests {

        private func makeState(results: [SearchResult]) -> SearchState {
            let state = SearchState()
            var query = SearchQuery(query: "test", token: 1)
            query.results = results
            query.isSearching = false
            state.searches = [query]
            state.selectedSearchIndex = 0
            return state
        }

        @Test("flat grouping returns single key")
        func flat() {
            let state = makeState(results: [
                SearchResult(username: "u", filename: "a.mp3", size: 0),
            ])
            state.resultGrouping = .flat
            #expect(state.sortedGroupKeys == ["All Results"])
        }

        @Test("byUser sorts by count descending, then alphabetically")
        func byUserSorted() {
            let state = makeState(results: [
                SearchResult(username: "bob", filename: "a.mp3", size: 0),
                SearchResult(username: "alice", filename: "b.mp3", size: 0),
                SearchResult(username: "alice", filename: "c.mp3", size: 0),
            ])
            state.resultGrouping = .byUser
            let keys = state.sortedGroupKeys
            // alice has 2 results, bob has 1, so alice first
            #expect(keys.first == "alice")
            #expect(keys.last == "bob")
        }

        @Test("byFolder sorts alphabetically")
        func byFolderSorted() {
            let state = makeState(results: [
                SearchResult(username: "u", filename: "Zebra\\song.mp3", size: 0),
                SearchResult(username: "u", filename: "Alpha\\song.mp3", size: 0),
            ])
            state.resultGrouping = .byFolder
            let keys = state.sortedGroupKeys
            #expect(keys == ["Alpha", "Zebra"])
        }
    }
}
