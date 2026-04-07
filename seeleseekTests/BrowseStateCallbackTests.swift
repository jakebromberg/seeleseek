import Testing
import Foundation
@testable import SeeleseekCore
@testable import seeleseek

@Suite(.serialized)
@MainActor
struct BrowseStateCallbackTests {

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

    // MARK: - Initialization

    @Test("initial state has empty browses")
    func initialState() {
        let state = BrowseState()
        #expect(state.browses.isEmpty)
        #expect(state.selectedBrowseIndex == 0)
        #expect(state.currentBrowse == nil)
        #expect(state.currentUser == "")
        #expect(state.expandedFolders.isEmpty)
        #expect(state.selectedFile == nil)
        #expect(state.filterQuery == "")
        #expect(state.currentFolderPath == nil)
        #expect(state.browseHistory.isEmpty)
    }

    // MARK: - configure

    @Test("configure stores weak reference to network client")
    func configureStoresClient() {
        let state = BrowseState()
        let client = NetworkClient()
        state.configure(networkClient: client)
        #expect(state.networkClient === client)
    }

    // MARK: - Computed Properties

    @Test("currentBrowse returns nil when browses is empty")
    func currentBrowseEmpty() {
        let state = BrowseState()
        #expect(state.currentBrowse == nil)
    }

    @Test("currentBrowse returns browse at selectedBrowseIndex")
    func currentBrowseReturnsCorrect() {
        let state = BrowseState()
        state.browses = [
            UserShares(username: "alice"),
            UserShares(username: "bob"),
        ]
        state.selectedBrowseIndex = 1
        #expect(state.currentBrowse?.username == "bob")
    }

    @Test("currentBrowse returns nil when index is out of bounds")
    func currentBrowseOutOfBounds() {
        let state = BrowseState()
        state.browses = [UserShares(username: "alice")]
        state.selectedBrowseIndex = 5
        #expect(state.currentBrowse == nil)
    }

    @Test("userShares returns same as currentBrowse (legacy compat)")
    func userSharesLegacy() {
        let state = BrowseState()
        state.browses = [UserShares(username: "alice")]
        state.selectedBrowseIndex = 0
        #expect(state.userShares?.username == state.currentBrowse?.username)
    }

    @Test("isLoading reflects current browse loading state")
    func isLoadingReflectsBrowse() {
        let state = BrowseState()
        state.browses = [UserShares(username: "alice", isLoading: true)]
        state.selectedBrowseIndex = 0
        #expect(state.isLoading)
    }

    @Test("isLoading is false when no current browse")
    func isLoadingNoBrowse() {
        let state = BrowseState()
        #expect(!state.isLoading)
    }

    @Test("hasError is true when current browse has an error")
    func hasErrorTrue() {
        let state = BrowseState()
        var shares = UserShares(username: "alice", isLoading: false)
        shares.error = "Failed"
        state.browses = [shares]
        state.selectedBrowseIndex = 0
        #expect(state.hasError)
    }

    @Test("hasError is false when no error")
    func hasErrorFalse() {
        let state = BrowseState()
        state.browses = [UserShares(username: "alice", isLoading: false)]
        state.selectedBrowseIndex = 0
        #expect(!state.hasError)
    }

    @Test("canBrowse is true when currentUser is non-empty")
    func canBrowseTrue() {
        let state = BrowseState()
        state.currentUser = "alice"
        #expect(state.canBrowse)
    }

    @Test("canBrowse is false when currentUser is empty")
    func canBrowseFalseEmpty() {
        let state = BrowseState()
        state.currentUser = ""
        #expect(!state.canBrowse)
    }

    @Test("canBrowse is false when currentUser is only whitespace")
    func canBrowseFalseWhitespace() {
        let state = BrowseState()
        state.currentUser = "   "
        #expect(!state.canBrowse)
    }

    // MARK: - displayedFolders

    @Test("displayedFolders returns empty when no current browse")
    func displayedFoldersNoBrowse() {
        let state = BrowseState()
        #expect(state.displayedFolders.isEmpty)
    }

    @Test("displayedFolders returns all root folders when no folder path set")
    func displayedFoldersRootLevel() {
        let state = BrowseState()
        let folder1 = makeFolder(name: "Music")
        let folder2 = makeFolder(name: "Videos")
        state.browses = [UserShares(username: "alice", folders: [folder1, folder2], isLoading: false)]
        state.selectedBrowseIndex = 0
        state.currentFolderPath = nil

        #expect(state.displayedFolders.count == 2)
    }

    // MARK: - Tab Management

    @Test("closeBrowse removes tab and adjusts selection")
    func closeBrowseRemovesTab() {
        let state = BrowseState()
        state.browses = [
            UserShares(username: "alice"),
            UserShares(username: "bob"),
            UserShares(username: "charlie"),
        ]
        state.selectedBrowseIndex = 2

        state.closeBrowse(at: 1)

        #expect(state.browses.count == 2)
        #expect(state.browses[0].username == "alice")
        #expect(state.browses[1].username == "charlie")
        // selectedBrowseIndex should adjust if it was beyond count
        #expect(state.selectedBrowseIndex <= state.browses.count - 1)
    }

    @Test("closeBrowse at invalid index does nothing")
    func closeBrowseInvalidIndex() {
        let state = BrowseState()
        state.browses = [UserShares(username: "alice")]

        state.closeBrowse(at: 5)

        #expect(state.browses.count == 1)
    }

    @Test("closeBrowse at negative index does nothing")
    func closeBrowseNegativeIndex() {
        let state = BrowseState()
        state.browses = [UserShares(username: "alice")]

        state.closeBrowse(at: -1)

        #expect(state.browses.count == 1)
    }

    @Test("closeBrowse adjusts selectedBrowseIndex when closing last tab")
    func closeBrowseAdjustsIndex() {
        let state = BrowseState()
        state.browses = [
            UserShares(username: "alice"),
            UserShares(username: "bob"),
        ]
        state.selectedBrowseIndex = 1

        state.closeBrowse(at: 1)

        #expect(state.browses.count == 1)
        #expect(state.selectedBrowseIndex == 0)
    }

    @Test("closeBrowse last remaining tab leaves index at 0")
    func closeBrowseLastTab() {
        let state = BrowseState()
        state.browses = [UserShares(username: "alice")]
        state.selectedBrowseIndex = 0

        state.closeBrowse(at: 0)

        #expect(state.browses.isEmpty)
        #expect(state.selectedBrowseIndex == 0)
    }

    // MARK: - selectBrowse

    @Test("selectBrowse updates selectedBrowseIndex and currentUser")
    func selectBrowseUpdatesIndex() {
        let state = BrowseState()
        state.browses = [
            UserShares(username: "alice"),
            UserShares(username: "bob"),
        ]

        state.selectBrowse(at: 1)

        #expect(state.selectedBrowseIndex == 1)
        #expect(state.currentUser == "bob")
    }

    @Test("selectBrowse resets UI state")
    func selectBrowseResetsUI() {
        let state = BrowseState()
        state.browses = [
            UserShares(username: "alice"),
            UserShares(username: "bob"),
        ]
        state.expandedFolders = [UUID()]
        state.selectedFile = makeFile(name: "test.mp3")
        state.currentFolderPath = "Music\\Artist"

        state.selectBrowse(at: 1)

        #expect(state.expandedFolders.isEmpty)
        #expect(state.selectedFile == nil)
        #expect(state.currentFolderPath == nil)
    }

    @Test("selectBrowse at invalid index does nothing")
    func selectBrowseInvalidIndex() {
        let state = BrowseState()
        state.browses = [UserShares(username: "alice")]
        state.selectedBrowseIndex = 0

        state.selectBrowse(at: 5)

        #expect(state.selectedBrowseIndex == 0)
    }

    // MARK: - Folder Toggle & File Selection

    @Test("toggleFolder adds folder ID when not expanded")
    func toggleFolderExpands() {
        let state = BrowseState()
        let id = UUID()

        state.toggleFolder(id)

        #expect(state.expandedFolders.contains(id))
    }

    @Test("toggleFolder removes folder ID when already expanded")
    func toggleFolderCollapses() {
        let state = BrowseState()
        let id = UUID()
        state.expandedFolders = [id]

        state.toggleFolder(id)

        #expect(!state.expandedFolders.contains(id))
    }

    @Test("selectFile toggles directory folder")
    func selectFileDirectory() {
        let state = BrowseState()
        let folder = makeFolder(name: "Music")

        state.selectFile(folder)

        #expect(state.expandedFolders.contains(folder.id))
    }

    @Test("selectFile sets selectedFile for non-directory")
    func selectFileNonDirectory() {
        let state = BrowseState()
        let file = makeFile(name: "song.mp3")

        state.selectFile(file)

        #expect(state.selectedFile == file)
    }

    @Test("selectFile replaces previously selected file")
    func selectFileReplaces() {
        let state = BrowseState()
        let file1 = makeFile(name: "song1.mp3")
        let file2 = makeFile(name: "song2.mp3")
        state.selectedFile = file1

        state.selectFile(file2)

        #expect(state.selectedFile == file2)
    }

    // MARK: - Navigation

    @Test("navigateUp goes from subfolder to parent")
    func navigateUpToParent() {
        let state = BrowseState()
        state.currentFolderPath = "Music\\Artist\\Album"

        state.navigateUp()

        #expect(state.currentFolderPath == "Music\\Artist")
    }

    @Test("navigateUp goes to root from single-level folder")
    func navigateUpToRoot() {
        let state = BrowseState()
        state.currentFolderPath = "Music"

        state.navigateUp()

        #expect(state.currentFolderPath == nil)
    }

    @Test("navigateUp does nothing from root")
    func navigateUpFromRoot() {
        let state = BrowseState()
        state.currentFolderPath = nil

        state.navigateUp()

        #expect(state.currentFolderPath == nil)
    }

    @Test("navigateToRoot clears currentFolderPath")
    func navigateToRootClears() {
        let state = BrowseState()
        state.currentFolderPath = "Music\\Artist\\Album"

        state.navigateToRoot()

        #expect(state.currentFolderPath == nil)
    }

    // MARK: - clear

    @Test("clear resets all browsing state")
    func clearResetsState() {
        let state = BrowseState()
        state.currentUser = "alice"
        state.expandedFolders = [UUID(), UUID()]
        state.selectedFile = makeFile(name: "song.mp3")
        state.currentFolderPath = "Music"

        state.clear()

        #expect(state.currentUser == "")
        #expect(state.expandedFolders.isEmpty)
        #expect(state.selectedFile == nil)
        #expect(state.currentFolderPath == nil)
    }

    // MARK: - setShares / setError

    @Test("setShares updates current browse folders and clears loading")
    func setSharesUpdatesFolders() {
        let state = BrowseState()
        state.browses = [UserShares(username: "alice", isLoading: true)]
        state.selectedBrowseIndex = 0

        let folder = makeFolder(name: "Music", children: [makeFile(name: "song.mp3")])
        state.setShares([folder])

        #expect(state.currentBrowse?.folders.count == 1)
        #expect(state.currentBrowse?.isLoading == false)
    }

    @Test("setError updates current browse error and clears loading")
    func setErrorSetsMessage() {
        let state = BrowseState()
        state.browses = [UserShares(username: "alice", isLoading: true)]
        state.selectedBrowseIndex = 0

        state.setError("Connection failed")

        #expect(state.currentBrowse?.error == "Connection failed")
        #expect(state.currentBrowse?.isLoading == false)
    }

    // MARK: - visibleFlatTree

    @Test("visibleFlatTree returns root items when nothing is expanded")
    func visibleFlatTreeCollapsed() {
        let state = BrowseState()
        let child = makeFile(name: "Music\\song.mp3")
        let folder = makeFolder(name: "Music", children: [child])
        state.browses = [UserShares(username: "alice", folders: [folder], isLoading: false)]
        state.selectedBrowseIndex = 0

        let flat = state.visibleFlatTree

        // Only the root folder should be visible (not its children)
        #expect(flat.count == 1)
        #expect(flat[0].file.isDirectory)
        #expect(flat[0].depth == 0)
    }

    @Test("visibleFlatTree includes children when folder is expanded")
    func visibleFlatTreeExpanded() {
        let state = BrowseState()
        let child = makeFile(name: "Music\\song.mp3")
        let folder = makeFolder(name: "Music", children: [child])
        state.browses = [UserShares(username: "alice", folders: [folder], isLoading: false)]
        state.selectedBrowseIndex = 0
        state.expandedFolders = [folder.id]

        let flat = state.visibleFlatTree

        #expect(flat.count == 2)
        #expect(flat[0].file.isDirectory)
        #expect(flat[0].depth == 0)
        #expect(!flat[1].file.isDirectory)
        #expect(flat[1].depth == 1)
    }

    // MARK: - filteredFlatTree

    @Test("filteredFlatTree returns all items when filter is empty")
    func filteredFlatTreeNoFilter() {
        let state = BrowseState()
        let child = makeFile(name: "Music\\song.mp3")
        let folder = makeFolder(name: "Music", children: [child])
        state.browses = [UserShares(username: "alice", folders: [folder], isLoading: false)]
        state.selectedBrowseIndex = 0
        state.expandedFolders = [folder.id]
        state.filterQuery = ""

        let filtered = state.filteredFlatTree

        #expect(filtered.count == 2)
    }

    @Test("filteredFlatTree filters by file name")
    func filteredFlatTreeFilters() {
        let state = BrowseState()
        let file1 = makeFile(name: "Music\\song.mp3")
        let file2 = makeFile(name: "Music\\readme.txt")
        let folder = makeFolder(name: "Music", children: [file1, file2])
        state.browses = [UserShares(username: "alice", folders: [folder], isLoading: false)]
        state.selectedBrowseIndex = 0
        state.expandedFolders = [folder.id]
        state.filterQuery = "song"

        let filtered = state.filteredFlatTree

        // Should include the matching file and its ancestor directory
        let fileItems = filtered.filter { !$0.file.isDirectory }
        #expect(fileItems.count == 1)
        #expect(fileItems[0].file.displayName == "song.mp3")
    }

    @Test("filteredFlatTree returns empty when nothing matches")
    func filteredFlatTreeNoMatch() {
        let state = BrowseState()
        let file1 = makeFile(name: "Music\\song.mp3")
        let folder = makeFolder(name: "Music", children: [file1])
        state.browses = [UserShares(username: "alice", folders: [folder], isLoading: false)]
        state.selectedBrowseIndex = 0
        state.expandedFolders = [folder.id]
        state.filterQuery = "nonexistent"

        let filtered = state.filteredFlatTree

        #expect(filtered.isEmpty)
    }
}
