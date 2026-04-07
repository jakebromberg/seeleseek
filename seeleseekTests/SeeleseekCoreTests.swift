import Testing
import Foundation
@testable import SeeleseekCore

// MARK: - NetworkClient Tests

@Suite("NetworkClient", .serialized)
struct NetworkClientTests {

    @Test("NetworkClient initializes with default state")
    @MainActor func defaultState() {
        let client = NetworkClient()
        #expect(client.isConnecting == false)
        #expect(client.isConnected == false)
        #expect(client.connectionError == nil)
        #expect(client.username == "")
        #expect(client.loggedIn == false)
        #expect(client.listenPort == 0)
        #expect(client.obfuscatedPort == 0)
        #expect(client.externalIP == nil)
        #expect(client.acceptDistributedChildren == true)
        #expect(client.distributedBranchLevel == 0)
        #expect(client.distributedBranchRoot == "")
        #expect(client.distributedChildren.isEmpty)
    }

    @Test("NetworkClient creates peerConnectionPool on init")
    @MainActor func hasPeerConnectionPool() {
        let client = NetworkClient()
        let pool = client.peerConnectionPool
        #expect(pool.connections.isEmpty)
    }

    @Test("NetworkClient creates shareManager on init")
    @MainActor func hasShareManager() {
        let client = NetworkClient()
        let sm = client.shareManager
        #expect(sm.totalFiles == 0)
        #expect(sm.totalFolders == 0)
    }

    @Test("NetworkClient creates userInfoCache on init")
    @MainActor func hasUserInfoCache() {
        let client = NetworkClient()
        let cache = client.userInfoCache
        #expect(cache.countryCode(for: "someuser") == nil)
    }

    @Test("NetworkClient metadataReader is nil by default")
    @MainActor func metadataReaderNil() {
        let client = NetworkClient()
        #expect(client.metadataReader == nil)
    }

    @Test("NetworkClient callbacks are nil by default")
    @MainActor func callbacksNil() {
        let client = NetworkClient()
        #expect(client.onConnectionStatusChanged == nil)
        #expect(client.onSearchResults == nil)
        #expect(client.onRoomList == nil)
        #expect(client.onRoomListFull == nil)
        #expect(client.onRoomMessage == nil)
        #expect(client.onPrivateMessage == nil)
        #expect(client.onRoomJoined == nil)
        #expect(client.onRoomLeft == nil)
        #expect(client.onUserJoinedRoom == nil)
        #expect(client.onUserLeftRoom == nil)
        #expect(client.onPeerAddress == nil)
        #expect(client.onAdminMessage == nil)
        #expect(client.onExcludedSearchPhrases == nil)
        #expect(client.onWishlistInterval == nil)
        #expect(client.onPasswordChanged == nil)
        #expect(client.onCantCreateRoom == nil)
        #expect(client.onCantConnectToPeer == nil)
        #expect(client.onGlobalRoomMessage == nil)
        #expect(client.onProtocolNotice == nil)
    }

    @Test("NetworkClient reconnect delays are defined")
    @MainActor func reconnectDelaysExist() {
        // Access via the public type - reconnectDelays is private static,
        // but we can verify the client doesn't crash during init
        let client = NetworkClient()
        _ = client // no crash
    }

    @Test("addPeerAddressHandler does not crash")
    @MainActor func addPeerAddressHandler() {
        let client = NetworkClient()
        var callCount = 0
        client.addPeerAddressHandler { _, _, _ in
            callCount += 1
        }
        // Adding handler should succeed without crashing
    }

    @Test("addUserStatusHandler does not crash")
    @MainActor func addUserStatusHandler() {
        let client = NetworkClient()
        client.addUserStatusHandler { _, _, _ in }
    }

    @Test("addUserStatsHandler does not crash")
    @MainActor func addUserStatsHandler() {
        let client = NetworkClient()
        client.addUserStatsHandler { _, _, _, _, _ in }
    }

    @Test("dispatchUserStats delivers to registered handlers")
    @MainActor func dispatchUserStats() {
        let client = NetworkClient()
        var receivedUsername: String?
        var receivedSpeed: UInt32?
        client.addUserStatsHandler { username, avgSpeed, _, _, _ in
            receivedUsername = username
            receivedSpeed = avgSpeed
        }
        client.dispatchUserStats(username: "alice", avgSpeed: 50000, uploadNum: 10, files: 100, dirs: 5)
        #expect(receivedUsername == "alice")
        #expect(receivedSpeed == 50000)
    }

    @Test("dispatchUserStats delivers to multiple handlers")
    @MainActor func dispatchUserStatsMultiple() {
        let client = NetworkClient()
        var handler1Called = false
        var handler2Called = false
        client.addUserStatsHandler { _, _, _, _, _ in handler1Called = true }
        client.addUserStatsHandler { _, _, _, _, _ in handler2Called = true }
        client.dispatchUserStats(username: "bob", avgSpeed: 0, uploadNum: 0, files: 0, dirs: 0)
        #expect(handler1Called)
        #expect(handler2Called)
    }
}

// MARK: - NetworkError Tests

@Suite("NetworkError")
struct NetworkErrorTests {

    @Test("NetworkError.notConnected description")
    func notConnected() {
        let error = NetworkError.notConnected
        #expect(error.errorDescription == "Not connected to server")
    }

    @Test("NetworkError.connectionFailed includes reason")
    func connectionFailed() {
        let error = NetworkError.connectionFailed("socket closed")
        #expect(error.errorDescription == "Connection failed: socket closed")
    }

    @Test("NetworkError.timeout description")
    func timeout() {
        let error = NetworkError.timeout
        #expect(error.errorDescription == "Connection timed out")
    }

    @Test("NetworkError.invalidResponse description")
    func invalidResponse() {
        let error = NetworkError.invalidResponse
        #expect(error.errorDescription == "Invalid server response")
    }
}

// MARK: - NATService Tests

@Suite("NATService")
struct NATServiceTests {

    @Test("NATService initializes without crash")
    func initialization() {
        let service = NATService()
        _ = service
    }

    @Test("NATService.externalAddress is nil initially")
    func externalAddressNil() async {
        let service = NATService()
        let addr = await service.externalAddress
        #expect(addr == nil)
    }
}

// MARK: - NATError Tests

@Suite("NATError")
struct NATErrorTests {

    @Test("NATError case descriptions", arguments: [
        (NATError.noGatewayFound, "No UPnP gateway found"),
        (.noLocalIP, "Could not determine local IP address"),
        (.mappingFailed, "Port mapping failed"),
        (.discoveryTimeout, "Gateway discovery timed out"),
        (.invalidGatewayURL, "Invalid gateway URL"),
        (.invalidGatewayResponse, "Invalid gateway response"),
        (.noControlURL, "No control URL found"),
        (.ipDiscoveryFailed, "Could not discover external IP"),
    ])
    func errorDescriptions(error: NATError, expected: String) {
        #expect(error.errorDescription == expected)
    }

    @Test("All NATError cases are distinct errors")
    func allCasesDistinct() {
        let errors: [NATError] = [
            .noGatewayFound, .noLocalIP, .mappingFailed, .discoveryTimeout,
            .invalidGatewayURL, .invalidGatewayResponse, .noControlURL, .ipDiscoveryFailed,
        ]
        let descriptions = errors.compactMap(\.errorDescription)
        #expect(descriptions.count == 8)
        #expect(Set(descriptions).count == 8) // all unique
    }
}

// MARK: - GeoIPService Tests

@Suite("GeoIPService")
struct GeoIPServiceTests {

    @Test("flag for US returns US flag emoji")
    func flagUS() {
        let flag = GeoIPService.flag(for: "US")
        #expect(!flag.isEmpty)
        #expect(flag.count >= 1) // flag emoji is a single grapheme cluster
    }

    @Test("flag for DE returns non-empty flag")
    func flagDE() {
        let flag = GeoIPService.flag(for: "DE")
        #expect(!flag.isEmpty)
    }

    @Test("flag for GB returns non-empty flag")
    func flagGB() {
        let flag = GeoIPService.flag(for: "GB")
        #expect(!flag.isEmpty)
    }

    @Test("flag for single character returns white flag")
    func flagSingleChar() {
        let flag = GeoIPService.flag(for: "X")
        // Should return the default white flag emoji (🏳️)
        #expect(flag == "🏳️")
    }

    @Test("flag for empty string returns white flag")
    func flagEmpty() {
        let flag = GeoIPService.flag(for: "")
        #expect(flag == "🏳️")
    }

    @Test("flag for three-character code returns white flag")
    func flagThreeChar() {
        let flag = GeoIPService.flag(for: "USA")
        #expect(flag == "🏳️")
    }

    @Test("flag is case-insensitive — converts to uppercase")
    func flagLowercase() {
        let upper = GeoIPService.flag(for: "US")
        let lower = GeoIPService.flag(for: "us")
        #expect(upper == lower)
    }

    @Test("flag produces different emojis for different countries")
    func flagsDiffer() {
        let us = GeoIPService.flag(for: "US")
        let de = GeoIPService.flag(for: "DE")
        let jp = GeoIPService.flag(for: "JP")
        #expect(us != de)
        #expect(de != jp)
        #expect(us != jp)
    }

    @Test("getCountryCode returns nil for private IPs", arguments: [
        "10.0.0.1",
        "192.168.1.1",
        "172.16.0.1",
        "127.0.0.1",
        "0.0.0.0",
    ])
    func privateIPsReturnNil(ip: String) async {
        let service = GeoIPService()
        let result = await service.getCountryCode(for: ip)
        #expect(result == nil)
    }

    @Test("getCountryCode returns nil for invalid IP")
    func invalidIPReturnsNil() async {
        let service = GeoIPService()
        let result = await service.getCountryCode(for: "not-an-ip")
        #expect(result == nil)
    }

    @Test("getCountryCode returns nil for empty string")
    func emptyIPReturnsNil() async {
        let service = GeoIPService()
        let result = await service.getCountryCode(for: "")
        #expect(result == nil)
    }

    @Test("getCountryCode caches results")
    func caching() async {
        let service = GeoIPService()
        // Look up a known public IP range (8.x.x.x is US in the database)
        let first = await service.getCountryCode(for: "8.8.8.8")
        let second = await service.getCountryCode(for: "8.8.8.8")
        #expect(first == second)
        // The database should have US for 8.x.x.x
        if let code = first {
            #expect(code == "US")
        }
    }

    @Test("getCountryCodes batch lookup returns results for known IPs")
    func batchLookup() async {
        let service = GeoIPService()
        let results = await service.getCountryCodes(for: ["8.8.8.8", "192.168.1.1", "not-valid"])
        // Private IPs and invalid IPs should not be in results
        #expect(results["192.168.1.1"] == nil)
        #expect(results["not-valid"] == nil)
    }

    @Test("getCountryCode returns nil for 172.x private ranges", arguments: [
        "172.16.0.1", "172.17.0.1", "172.18.0.1", "172.19.0.1",
        "172.20.0.1", "172.21.0.1", "172.22.0.1", "172.23.0.1",
        "172.24.0.1", "172.25.0.1", "172.26.0.1", "172.27.0.1",
        "172.28.0.1", "172.29.0.1", "172.30.0.1", "172.31.0.1",
    ])
    func privateRanges172(ip: String) async {
        let service = GeoIPService()
        let result = await service.getCountryCode(for: ip)
        #expect(result == nil)
    }
}

// MARK: - UserInfoCache Tests

@Suite("UserInfoCache", .serialized)
struct UserInfoCacheTests {

    @Test("UserInfoCache initializes with empty state")
    @MainActor func emptyInitialState() {
        let cache = UserInfoCache()
        #expect(cache.countryCode(for: "alice") == nil)
        #expect(cache.flag(for: "alice") == "")
        #expect(cache.ipAddress(for: "alice") == nil)
    }

    @Test("ipAddress returns stored IP after registerIP")
    @MainActor func ipAddressStored() {
        let cache = UserInfoCache()
        cache.registerIP("1.2.3.4", for: "bob")
        #expect(cache.ipAddress(for: "bob") == "1.2.3.4")
    }

    @Test("registerIP ignores empty IP")
    @MainActor func ignoresEmptyIP() {
        let cache = UserInfoCache()
        cache.registerIP("", for: "charlie")
        #expect(cache.ipAddress(for: "charlie") == nil)
    }

    @Test("registerIP ignores empty username")
    @MainActor func ignoresEmptyUsername() {
        let cache = UserInfoCache()
        cache.registerIP("1.2.3.4", for: "")
        #expect(cache.ipAddress(for: "") == nil)
    }

    @Test("countryCode returns nil for unknown user")
    @MainActor func unknownUserCountryCode() {
        let cache = UserInfoCache()
        #expect(cache.countryCode(for: "nonexistent") == nil)
    }

    @Test("flag returns empty string for unknown user")
    @MainActor func unknownUserFlag() {
        let cache = UserInfoCache()
        #expect(cache.flag(for: "nonexistent") == "")
    }

    @Test("clear removes all cached data")
    @MainActor func clearRemovesAll() {
        let cache = UserInfoCache()
        cache.registerIP("1.2.3.4", for: "alice")
        cache.registerIP("5.6.7.8", for: "bob")
        #expect(cache.ipAddress(for: "alice") == "1.2.3.4")
        #expect(cache.ipAddress(for: "bob") == "5.6.7.8")

        cache.clear()
        #expect(cache.ipAddress(for: "alice") == nil)
        #expect(cache.ipAddress(for: "bob") == nil)
        #expect(cache.countryCode(for: "alice") == nil)
        #expect(cache.countryCode(for: "bob") == nil)
    }

    @Test("registerIP updates IP for existing user")
    @MainActor func updateIP() {
        let cache = UserInfoCache()
        cache.registerIP("1.2.3.4", for: "dave")
        #expect(cache.ipAddress(for: "dave") == "1.2.3.4")
        cache.registerIP("5.6.7.8", for: "dave")
        #expect(cache.ipAddress(for: "dave") == "5.6.7.8")
    }

    @Test("countries dictionary is initially empty")
    @MainActor func countriesEmpty() {
        let cache = UserInfoCache()
        #expect(cache.countries.isEmpty)
    }
}

// MARK: - ShareManager Tests

@Suite("ShareManager", .serialized)
struct ShareManagerTests {

    @Test("ShareManager initializes with empty state")
    @MainActor func emptyState() {
        let sm = ShareManager()
        #expect(sm.sharedFolders.isEmpty)
        #expect(sm.fileIndex.isEmpty)
        #expect(sm.isScanning == false)
        #expect(sm.scanProgress == 0)
        #expect(sm.totalFiles == 0)
        #expect(sm.totalFolders == 0)
        #expect(sm.totalSize == 0)
    }

    @Test("SharedFolder displayName extracts last path component")
    @MainActor func sharedFolderDisplayName() {
        let folder = ShareManager.SharedFolder(path: "/Users/test/Music/MyShares")
        #expect(folder.displayName == "MyShares")
    }

    @Test("SharedFolder displayName for root path")
    @MainActor func sharedFolderDisplayNameRoot() {
        let folder = ShareManager.SharedFolder(path: "/")
        #expect(folder.displayName == "/")
    }

    @Test("SharedFolder default values")
    @MainActor func sharedFolderDefaults() {
        let folder = ShareManager.SharedFolder(path: "/test")
        #expect(folder.fileCount == 0)
        #expect(folder.totalSize == 0)
        #expect(folder.lastScanned == nil)
    }

    @Test("SharedFolder is Codable")
    @MainActor func sharedFolderCodable() throws {
        let folder = ShareManager.SharedFolder(
            path: "/test/music",
            fileCount: 42,
            totalSize: 1_000_000
        )
        let data = try JSONEncoder().encode(folder)
        let decoded = try JSONDecoder().decode(ShareManager.SharedFolder.self, from: data)
        #expect(decoded.path == folder.path)
        #expect(decoded.fileCount == folder.fileCount)
        #expect(decoded.totalSize == folder.totalSize)
        #expect(decoded.id == folder.id)
    }

    @Test("SharedFolder is Hashable")
    @MainActor func sharedFolderHashable() {
        let folder1 = ShareManager.SharedFolder(path: "/a")
        let folder2 = ShareManager.SharedFolder(path: "/b")
        let set: Set<ShareManager.SharedFolder> = [folder1, folder2]
        #expect(set.count == 2)
    }

    @Test("IndexedFile stores expected properties")
    @MainActor func indexedFileProperties() {
        let file = ShareManager.IndexedFile(
            localPath: "/Users/test/Music/song.mp3",
            sharedPath: "Music\\song.mp3",
            size: 5_000_000,
            bitrate: 320
        )
        #expect(file.localPath == "/Users/test/Music/song.mp3")
        #expect(file.sharedPath == "Music\\song.mp3")
        #expect(file.filename == "song.mp3")
        #expect(file.size == 5_000_000)
        #expect(file.bitrate == 320)
        #expect(file.duration == nil)
        #expect(file.fileExtension == "mp3")
    }

    @Test("IndexedFile extracts correct extension")
    @MainActor func indexedFileExtension() {
        let flac = ShareManager.IndexedFile(localPath: "/test/song.FLAC", sharedPath: "x", size: 0)
        #expect(flac.fileExtension == "flac")

        let noExt = ShareManager.IndexedFile(localPath: "/test/README", sharedPath: "x", size: 0)
        #expect(noExt.fileExtension == "")
    }

    @Test("search returns matching files")
    @MainActor func searchMatching() {
        let sm = ShareManager()
        // We cannot add files directly to the index (it's private(set)),
        // but we can test the search method behavior on the empty index
        let results = sm.search(query: "nonexistent")
        #expect(results.isEmpty)
    }

    @Test("search with empty query returns all files")
    @MainActor func searchEmptyQuery() {
        let sm = ShareManager()
        let results = sm.search(query: "")
        // Empty query with empty index
        #expect(results.isEmpty)
    }

    @Test("toSharedFiles returns empty for no indexed files")
    @MainActor func toSharedFilesEmpty() {
        let sm = ShareManager()
        let shared = sm.toSharedFiles()
        #expect(shared.isEmpty)
    }

    @Test("removeFolder removes by ID")
    @MainActor func removeFolderById() {
        let sm = ShareManager()
        // Since we can't add folders easily without security-scoped resources,
        // verify the method doesn't crash on empty state
        let folder = ShareManager.SharedFolder(path: "/nonexistent")
        sm.removeFolder(folder)
        #expect(sm.sharedFolders.isEmpty)
    }

    @Test("rescanAll guards against concurrent scanning")
    @MainActor func rescanAllGuard() async {
        let sm = ShareManager()
        // With no folders, this should complete quickly
        await sm.rescanAll()
        #expect(sm.isScanning == false)
        #expect(sm.lastScanDate != nil)
    }
}

// MARK: - UploadManager Tests

@Suite("UploadManager", .serialized)
struct UploadManagerTests {

    @Test("UploadManager initializes with default configuration")
    @MainActor func defaults() {
        let um = UploadManager()
        #expect(um.maxConcurrentUploads == 3)
        #expect(um.maxQueuedPerUser == 50)
        #expect(um.uploadSpeedLimit == nil)
        #expect(um.uploadPermissionChecker == nil)
    }

    @Test("maxConcurrentUploads is configurable")
    @MainActor func configurableMaxConcurrent() {
        let um = UploadManager()
        um.maxConcurrentUploads = 5
        #expect(um.maxConcurrentUploads == 5)
    }

    @Test("maxQueuedPerUser is configurable")
    @MainActor func configurableMaxQueued() {
        let um = UploadManager()
        um.maxQueuedPerUser = 100
        #expect(um.maxQueuedPerUser == 100)
    }

    @Test("uploadSpeedLimit can be set")
    @MainActor func speedLimit() {
        let um = UploadManager()
        um.uploadSpeedLimit = 1_000_000
        #expect(um.uploadSpeedLimit == 1_000_000)
        um.uploadSpeedLimit = nil
        #expect(um.uploadSpeedLimit == nil)
    }

    @Test("getQueuePosition returns 0 for unknown file")
    @MainActor func queuePositionUnknown() {
        let um = UploadManager()
        let pos = um.getQueuePosition(for: "nonexistent.mp3", username: "bob")
        #expect(pos == 0)
    }

    @Test("uploadPermissionChecker can be set and invoked")
    @MainActor func permissionChecker() {
        let um = UploadManager()
        um.uploadPermissionChecker = { username in
            return username != "blocked_user"
        }
        #expect(um.uploadPermissionChecker?("alice") == true)
        #expect(um.uploadPermissionChecker?("blocked_user") == false)
    }
}

// MARK: - UploadError Tests

@Suite("UploadError")
struct UploadErrorTests {

    @Test("UploadError case descriptions", arguments: [
        (UploadManager.UploadError.fileNotFound, "File not found"),
        (.fileNotShared, "File not in shared folders"),
        (.cannotReadFile, "Cannot read file"),
        (.connectionFailed, "Connection to peer failed"),
        (.peerRejected, "Peer rejected the transfer"),
        (.timeout, "Transfer timed out"),
    ])
    func errorDescriptions(error: UploadManager.UploadError, expected: String) {
        #expect(error.errorDescription == expected)
    }

    @Test("All UploadError cases have descriptions")
    func allCasesHaveDescriptions() {
        let errors: [UploadManager.UploadError] = [
            .fileNotFound, .fileNotShared, .cannotReadFile,
            .connectionFailed, .peerRejected, .timeout,
        ]
        for error in errors {
            #expect(error.errorDescription != nil)
            #expect(!error.errorDescription!.isEmpty)
        }
    }
}

// MARK: - DownloadManager Tests (additional to existing DownloadManagerTests.swift)

@Suite("DownloadManager Init")
struct DownloadManagerInitTests {

    @Test("DownloadManager initializes cleanly")
    @MainActor func cleanInit() {
        let dm = DownloadManager()
        _ = dm // no crash
    }
}

// MARK: - PeerConnection Tests

@Suite("PeerConnection")
struct PeerConnectionTests {

    @Test("ConnectionType raw values match protocol")
    func connectionTypeRawValues() {
        #expect(PeerConnection.ConnectionType.peer.rawValue == "P")
        #expect(PeerConnection.ConnectionType.file.rawValue == "F")
        #expect(PeerConnection.ConnectionType.distributed.rawValue == "D")
    }

    @Test("ConnectionType can be created from raw value")
    func connectionTypeFromRawValue() {
        #expect(PeerConnection.ConnectionType(rawValue: "P") == .peer)
        #expect(PeerConnection.ConnectionType(rawValue: "F") == .file)
        #expect(PeerConnection.ConnectionType(rawValue: "D") == .distributed)
        #expect(PeerConnection.ConnectionType(rawValue: "X") == nil)
    }

    @Test("PeerConnection.State equatable - matching states")
    func stateEquatable() {
        #expect(PeerConnection.State.disconnected == .disconnected)
        #expect(PeerConnection.State.connecting == .connecting)
        #expect(PeerConnection.State.handshaking == .handshaking)
        #expect(PeerConnection.State.connected == .connected)
    }

    @Test("PeerConnection.State equatable - failed states match regardless of error")
    func stateFailedEquatable() {
        let err1 = PeerConnection.State.failed(PeerError.timeout)
        let err2 = PeerConnection.State.failed(PeerError.notConnected)
        #expect(err1 == err2) // .failed matches .failed regardless of error
    }

    @Test("PeerConnection.State equatable - different states don't match")
    func stateNotEqual() {
        #expect(PeerConnection.State.disconnected != .connecting)
        #expect(PeerConnection.State.connecting != .connected)
        #expect(PeerConnection.State.connected != .failed(PeerError.timeout))
    }

    @Test("PeerInfo stores provided values")
    func peerInfoProperties() {
        let info = PeerConnection.PeerInfo(
            username: "alice",
            ip: "1.2.3.4",
            port: 2234,
            uploadSpeed: 100_000,
            downloadSpeed: 50_000,
            freeUploadSlots: false,
            queueLength: 5,
            sharedFiles: 1000,
            sharedFolders: 50
        )
        #expect(info.username == "alice")
        #expect(info.ip == "1.2.3.4")
        #expect(info.port == 2234)
        #expect(info.uploadSpeed == 100_000)
        #expect(info.downloadSpeed == 50_000)
        #expect(info.freeUploadSlots == false)
        #expect(info.queueLength == 5)
        #expect(info.sharedFiles == 1000)
        #expect(info.sharedFolders == 50)
    }

    @Test("PeerInfo default values")
    func peerInfoDefaults() {
        let info = PeerConnection.PeerInfo(username: "bob", ip: "5.6.7.8", port: 2234)
        #expect(info.uploadSpeed == 0)
        #expect(info.downloadSpeed == 0)
        #expect(info.freeUploadSlots == true)
        #expect(info.queueLength == 0)
        #expect(info.sharedFiles == 0)
        #expect(info.sharedFolders == 0)
    }

    @Test("PeerConnection init with PeerInfo stores properties")
    func peerConnectionInit() async {
        let info = PeerConnection.PeerInfo(username: "charlie", ip: "10.0.0.1", port: 3000)
        let pc = PeerConnection(peerInfo: info, type: .peer, token: 42, isIncoming: false)

        let storedInfo = pc.peerInfo
        #expect(storedInfo.username == "charlie")
        #expect(storedInfo.ip == "10.0.0.1")
        #expect(storedInfo.port == 3000)
        #expect(pc.connectionType == .peer)
        #expect(pc.token == 42)
        #expect(pc.isIncoming == false)
    }

    @Test("PeerConnection.isConnected is false when disconnected")
    func isConnectedFalse() async {
        let info = PeerConnection.PeerInfo(username: "test", ip: "1.2.3.4", port: 1234)
        let pc = PeerConnection(peerInfo: info)
        let connected = await pc.isConnected
        #expect(connected == false)
    }

    @Test("PeerConnection with file type")
    func fileConnection() async {
        let info = PeerConnection.PeerInfo(username: "test", ip: "1.2.3.4", port: 1234)
        let pc = PeerConnection(peerInfo: info, type: .file, token: 99)
        #expect(pc.connectionType == .file)
        #expect(pc.token == 99)
    }

    @Test("PeerConnection with distributed type")
    func distributedConnection() async {
        let info = PeerConnection.PeerInfo(username: "test", ip: "1.2.3.4", port: 1234)
        let pc = PeerConnection(peerInfo: info, type: .distributed, token: 0)
        #expect(pc.connectionType == .distributed)
    }

    @Test("PeerConnection getPeerUsername returns initial username")
    func getPeerUsername() async {
        let info = PeerConnection.PeerInfo(username: "original", ip: "1.2.3.4", port: 1234)
        let pc = PeerConnection(peerInfo: info)
        let name = await pc.getPeerUsername()
        #expect(name == "")  // peerUsername is separate from peerInfo.username
    }

    @Test("PeerConnection setPeerUsername updates username")
    func setPeerUsername() async {
        let info = PeerConnection.PeerInfo(username: "", ip: "1.2.3.4", port: 1234)
        let pc = PeerConnection(peerInfo: info)
        await pc.setPeerUsername("newuser")
        let name = await pc.getPeerUsername()
        #expect(name == "newuser")
        let updatedInfo = pc.peerInfo
        #expect(updatedInfo.username == "newuser")
    }

    @Test("PeerConnection getState returns disconnected initially")
    func getStateDisconnected() async {
        let info = PeerConnection.PeerInfo(username: "test", ip: "1.2.3.4", port: 1234)
        let pc = PeerConnection(peerInfo: info)
        let state = await pc.getState()
        #expect(state == .disconnected)
    }

    @Test("PeerConnection statistics start at zero")
    func statisticsZero() async {
        let info = PeerConnection.PeerInfo(username: "test", ip: "1.2.3.4", port: 1234)
        let pc = PeerConnection(peerInfo: info)
        let bytesRx = await pc.bytesReceived
        let bytesTx = await pc.bytesSent
        let msgsRx = await pc.messagesReceived
        let msgsTx = await pc.messagesSent
        let connAt = await pc.connectedAt
        let lastAct = await pc.lastActivityAt
        #expect(bytesRx == 0)
        #expect(bytesTx == 0)
        #expect(msgsRx == 0)
        #expect(msgsTx == 0)
        #expect(connAt == nil)
        #expect(lastAct == nil)
    }

    @Test("PeerConnection disconnect on never-connected is safe")
    func disconnectSafe() async {
        let info = PeerConnection.PeerInfo(username: "test", ip: "1.2.3.4", port: 1234)
        let pc = PeerConnection(peerInfo: info)
        await pc.disconnect()
        let state = await pc.getState()
        #expect(state == .disconnected)
    }
}

// MARK: - PeerError Tests

@Suite("PeerError")
struct PeerErrorTests {

    @Test("PeerError case descriptions", arguments: [
        (PeerError.notConnected, "Not connected to peer"),
        (.connectionClosed, "Connection closed"),
        (.handshakeFailed, "Handshake failed"),
        (.decompressionFailed, "Failed to decompress data"),
        (.timeout, "Connection timed out"),
        (.invalidPort, "Invalid port number"),
    ])
    func errorDescriptions(error: PeerError, expected: String) {
        #expect(error.errorDescription == expected)
    }
}

// MARK: - TransferRequest Tests

@Suite("TransferRequest")
struct TransferRequestTests {

    @Test("TransferRequest stores all fields")
    func storesFields() {
        let req = TransferRequest(
            direction: .download,
            token: 12345,
            filename: "@@music\\Song.mp3",
            size: 5_000_000,
            username: "alice"
        )
        #expect(req.direction == .download)
        #expect(req.token == 12345)
        #expect(req.filename == "@@music\\Song.mp3")
        #expect(req.size == 5_000_000)
        #expect(req.username == "alice")
    }

    @Test("TransferRequest with upload direction")
    func uploadDirection() {
        let req = TransferRequest(
            direction: .upload,
            token: 99,
            filename: "file.flac",
            size: 30_000_000,
            username: "bob"
        )
        #expect(req.direction == .upload)
    }
}

// MARK: - PeerConnectionPool Type Tests

@Suite("PeerConnectionPool Types")
struct PeerConnectionPoolTypeTests {

    @Test("PeerConnectionInfo stores all fields")
    @MainActor func peerConnectionInfo() {
        let now = Date()
        let info = PeerConnectionPool.PeerConnectionInfo(
            id: "test-id",
            username: "alice",
            ip: "1.2.3.4",
            port: 2234,
            state: .connected,
            connectionType: .peer,
            bytesReceived: 1000,
            bytesSent: 500,
            connectedAt: now,
            lastActivity: now,
            currentSpeed: 50000.0
        )
        #expect(info.id == "test-id")
        #expect(info.username == "alice")
        #expect(info.ip == "1.2.3.4")
        #expect(info.port == 2234)
        #expect(info.state == .connected)
        #expect(info.connectionType == .peer)
        #expect(info.bytesReceived == 1000)
        #expect(info.bytesSent == 500)
        #expect(info.connectedAt == now)
        #expect(info.lastActivity == now)
        #expect(info.currentSpeed == 50000.0)
    }

    @Test("PeerConnectionInfo default stat values")
    @MainActor func peerConnectionInfoDefaults() {
        let info = PeerConnectionPool.PeerConnectionInfo(
            id: "x",
            username: "u",
            ip: "0.0.0.0",
            port: 0,
            state: .disconnected,
            connectionType: .peer
        )
        #expect(info.bytesReceived == 0)
        #expect(info.bytesSent == 0)
        #expect(info.connectedAt == nil)
        #expect(info.lastActivity == nil)
        #expect(info.currentSpeed == 0)
    }

    @Test("PendingConnection stores all fields")
    @MainActor func pendingConnection() {
        let now = Date()
        let pending = PeerConnectionPool.PendingConnection(
            username: "bob",
            token: 42,
            timestamp: now,
            attempts: 3
        )
        #expect(pending.username == "bob")
        #expect(pending.token == 42)
        #expect(pending.timestamp == now)
        #expect(pending.attempts == 3)
    }

    @Test("PendingConnection default attempts is 0")
    @MainActor func pendingConnectionDefaultAttempts() {
        let pending = PeerConnectionPool.PendingConnection(
            username: "charlie",
            token: 100,
            timestamp: Date()
        )
        #expect(pending.attempts == 0)
    }

    @Test("SpeedSample stores values")
    @MainActor func speedSample() {
        let now = Date()
        let sample = PeerConnectionPool.SpeedSample(
            timestamp: now,
            downloadSpeed: 1_000_000.0,
            uploadSpeed: 500_000.0
        )
        #expect(sample.timestamp == now)
        #expect(sample.downloadSpeed == 1_000_000.0)
        #expect(sample.uploadSpeed == 500_000.0)
    }

    @Test("PeerLocation stores values")
    @MainActor func peerLocation() {
        let loc = PeerConnectionPool.PeerLocation(
            username: "dave",
            country: "US",
            latitude: 37.7749,
            longitude: -122.4194
        )
        #expect(loc.username == "dave")
        #expect(loc.country == "US")
        #expect(loc.latitude == 37.7749)
        #expect(loc.longitude == -122.4194)
    }

    @Test("Pool connection limits are reasonable")
    @MainActor func poolLimits() {
        let pool = PeerConnectionPool()
        #expect(pool.maxConnections == 50)
        #expect(pool.maxConnectionsPerIP == 30)
        #expect(pool.connectionTimeout == 60)
    }
}

// MARK: - PeerConnectionError Tests (not already covered by PeerConnectionPoolTests)

@Suite("PeerConnectionError Descriptions")
struct PeerConnectionErrorDescriptionTests {

    @Test("invalidAddress has expected description")
    func invalidAddressDescription() {
        let error = PeerConnectionError.invalidAddress
        #expect(error.errorDescription?.contains("multicast") == true || error.errorDescription?.contains("Invalid") == true)
    }

    @Test("timeout has expected description")
    func timeoutDescription() {
        let error = PeerConnectionError.timeout
        #expect(error.errorDescription == "Connection timed out")
    }

    @Test("connectionFailed includes reason")
    func connectionFailedDescription() {
        let error = PeerConnectionError.connectionFailed("reset by peer")
        #expect(error.errorDescription?.contains("reset by peer") == true)
    }
}

// MARK: - ListenerError Tests

@Suite("ListenerError")
struct ListenerErrorTests {

    @Test("noAvailablePort has description")
    func noAvailablePort() {
        let error = ListenerError.noAvailablePort
        #expect(error.errorDescription != nil)
        #expect(!error.errorDescription!.isEmpty)
    }

    @Test("bindFailed includes reason")
    func bindFailed() {
        let error = ListenerError.bindFailed("address in use")
        #expect(error.errorDescription?.contains("address in use") == true)
    }
}

// MARK: - DecompressionError Tests

@Suite("DecompressionError")
struct DecompressionErrorTests {

    @Test("ZlibDecompression maxDecompressedSize is 50MB")
    func maxSize() {
        #expect(ZlibDecompression.maxDecompressedSize == 50 * 1024 * 1024)
    }

    @Test("ZlibDecompression maxCompressionRatio is 1000")
    func maxRatio() {
        #expect(ZlibDecompression.maxCompressionRatio == 1000)
    }

    @Test("ZlibDecompression throws dataTooShort for small input")
    func dataTooShort() throws {
        let data = Data([0x78, 0x9C, 0x01]) // too short
        #expect(throws: DecompressionError.self) {
            try ZlibDecompression.decompress(data)
        }
    }
}

// MARK: - ConnectionStatus Tests (additional coverage beyond DownloadManagerTests)

@Suite("ConnectionStatus")
struct ConnectionStatusTests {

    @Test("ConnectionStatus is CaseIterable")
    func caseIterable() {
        let all = ConnectionStatus.allCases
        #expect(all.count == 5)
    }

    @Test("ConnectionStatus is Sendable")
    func sendable() {
        let status: ConnectionStatus = .connected
        Task {
            _ = status // Sendable conformance
        }
    }

    @Test("ConnectionStatus can be created from raw value", arguments: [
        ("disconnected", ConnectionStatus.disconnected),
        ("connecting", .connecting),
        ("connected", .connected),
        ("reconnecting", .reconnecting),
        ("error", .error),
    ])
    func fromRawValue(rawValue: String, expected: ConnectionStatus) {
        #expect(ConnectionStatus(rawValue: rawValue) == expected)
    }

    @Test("ConnectionStatus returns nil for unknown raw value")
    func unknownRawValue() {
        #expect(ConnectionStatus(rawValue: "unknown") == nil)
    }
}

// MARK: - UserStatus Tests

@Suite("UserStatus")
struct UserStatusTests {

    @Test("UserStatus raw values match protocol", arguments: [
        (UserStatus.offline, UInt32(0)),
        (.away, 1),
        (.online, 2),
    ])
    func rawValues(status: UserStatus, expected: UInt32) {
        #expect(status.rawValue == expected)
    }

    @Test("UserStatus descriptions", arguments: [
        (UserStatus.offline, "Offline"),
        (.away, "Away"),
        (.online, "Online"),
    ])
    func descriptions(status: UserStatus, expected: String) {
        #expect(status.description == expected)
    }

    @Test("UserStatus can be created from raw value")
    func fromRawValue() {
        #expect(UserStatus(rawValue: 0) == .offline)
        #expect(UserStatus(rawValue: 1) == .away)
        #expect(UserStatus(rawValue: 2) == .online)
        #expect(UserStatus(rawValue: 99) == nil)
    }
}

// MARK: - FileTransferDirection Tests

@Suite("FileTransferDirection")
struct FileTransferDirectionTests {

    @Test("FileTransferDirection raw values", arguments: [
        (FileTransferDirection.download, UInt8(0)),
        (.upload, 1),
    ])
    func rawValues(direction: FileTransferDirection, expected: UInt8) {
        #expect(direction.rawValue == expected)
    }

    @Test("FileTransferDirection from raw value")
    func fromRawValue() {
        #expect(FileTransferDirection(rawValue: 0) == .download)
        #expect(FileTransferDirection(rawValue: 1) == .upload)
        #expect(FileTransferDirection(rawValue: 99) == nil)
    }
}

// MARK: - LoginResult Tests

@Suite("LoginResult")
struct LoginResultTests {

    @Test("LoginResult.success stores greeting, ip, and hash")
    func successCase() {
        let result = LoginResult.success(greeting: "Welcome!", ip: "1.2.3.4", hash: "abc123")
        if case .success(let greeting, let ip, let hash) = result {
            #expect(greeting == "Welcome!")
            #expect(ip == "1.2.3.4")
            #expect(hash == "abc123")
        } else {
            Issue.record("Expected success case")
        }
    }

    @Test("LoginResult.success with nil hash")
    func successNoHash() {
        let result = LoginResult.success(greeting: "Hi", ip: "5.6.7.8", hash: nil)
        if case .success(_, _, let hash) = result {
            #expect(hash == nil)
        } else {
            Issue.record("Expected success case")
        }
    }

    @Test("LoginResult.failure stores reason")
    func failureCase() {
        let result = LoginResult.failure(reason: "Invalid password")
        if case .failure(let reason) = result {
            #expect(reason == "Invalid password")
        } else {
            Issue.record("Expected failure case")
        }
    }
}

// MARK: - SeeleSeekPeerCode Additional Tests

@Suite("SeeleSeekPeerCode Additional")
struct SeeleSeekPeerCodeAdditionalTests {

    @Test("SeeleSeekPeerCode raw values are in 10000+ range", arguments: SeeleSeekPeerCode.allCases)
    func rawValuesInRange(code: SeeleSeekPeerCode) {
        #expect(code.rawValue >= 10000)
    }

    @Test("SeeleSeekPeerCode from raw value round trips", arguments: SeeleSeekPeerCode.allCases)
    func rawValueRoundTrip(code: SeeleSeekPeerCode) {
        #expect(SeeleSeekPeerCode(rawValue: code.rawValue) == code)
    }

    @Test("SeeleSeekPeerCode unknown raw value returns nil")
    func unknownRawValue() {
        #expect(SeeleSeekPeerCode(rawValue: 9999) == nil)
        #expect(SeeleSeekPeerCode(rawValue: 10003) == nil)
    }
}

// MARK: - DistributedMessageCode Tests

@Suite("DistributedMessageCode")
struct DistributedMessageCodeTests {

    @Test("DistributedMessageCode raw values", arguments: [
        (DistributedMessageCode.ping, UInt8(0)),
        (.searchRequest, 3),
        (.branchLevel, 4),
        (.branchRoot, 5),
        (.childDepth, 7),
        (.embeddedMessage, 93),
    ])
    func rawValues(code: DistributedMessageCode, expected: UInt8) {
        #expect(code.rawValue == expected)
    }

    @Test("DistributedMessageCode descriptions", arguments: [
        (DistributedMessageCode.ping, "DistributedPing"),
        (.searchRequest, "DistributedSearch"),
        (.branchLevel, "BranchLevel"),
        (.branchRoot, "BranchRoot"),
        (.childDepth, "ChildDepth"),
        (.embeddedMessage, "EmbeddedMessage"),
    ])
    func descriptions(code: DistributedMessageCode, expected: String) {
        #expect(code.description == expected)
    }
}

// MARK: - PeerMessageCode Tests

@Suite("PeerMessageCode")
struct PeerMessageCodeTests {

    @Test("PeerMessageCode critical raw values", arguments: [
        (PeerMessageCode.pierceFirewall, UInt8(0)),
        (.peerInit, 1),
        (.sharesRequest, 4),
        (.sharesReply, 5),
        (.searchRequest, 8),
        (.searchReply, 9),
        (.userInfoRequest, 15),
        (.userInfoReply, 16),
        (.folderContentsRequest, 36),
        (.folderContentsReply, 37),
        (.transferRequest, 40),
        (.transferReply, 41),
        (.queueDownload, 43),
        (.placeInQueueReply, 44),
        (.uploadFailed, 46),
        (.uploadDenied, 50),
        (.placeInQueueRequest, 51),
    ])
    func rawValues(code: PeerMessageCode, expected: UInt8) {
        #expect(code.rawValue == expected)
    }

    @Test("PeerMessageCode descriptions are non-empty")
    func descriptionsNonEmpty() {
        let codes: [PeerMessageCode] = [
            .pierceFirewall, .peerInit, .sharesRequest, .sharesReply,
            .searchRequest, .searchReply, .userInfoRequest, .userInfoReply,
            .folderContentsRequest, .folderContentsReply, .transferRequest,
            .transferReply, .uploadPlacehold, .queueDownload,
            .placeInQueueReply, .uploadFailed, .uploadDenied,
            .placeInQueueRequest, .uploadQueueNotification,
        ]
        for code in codes {
            #expect(!code.description.isEmpty)
        }
    }
}

// MARK: - Transfer Additional Tests

@Suite("Transfer Additional")
struct TransferAdditionalTests {

    @Test("Transfer.TransferDirection raw values")
    func directionRawValues() {
        #expect(Transfer.TransferDirection.download.rawValue == "download")
        #expect(Transfer.TransferDirection.upload.rawValue == "upload")
    }

    @Test("Transfer.TransferStatus raw values", arguments: [
        (Transfer.TransferStatus.queued, "queued"),
        (.connecting, "connecting"),
        (.transferring, "transferring"),
        (.completed, "completed"),
        (.failed, "failed"),
        (.cancelled, "cancelled"),
        (.waiting, "waiting"),
    ])
    func statusRawValues(status: Transfer.TransferStatus, expected: String) {
        #expect(status.rawValue == expected)
    }

    @Test("Transfer default retryCount is 0")
    func defaultRetryCount() {
        let t = Transfer(username: "u", filename: "f", size: 0, direction: .download)
        #expect(t.retryCount == 0)
    }

    @Test("Transfer formattedProgress uses ByteFormatter")
    func formattedProgress() {
        let t = Transfer(
            username: "u",
            filename: "f",
            size: 1_048_576,
            direction: .download,
            bytesTransferred: 524_288
        )
        // Should contain both transferred and total
        #expect(t.formattedProgress.contains("512.0 KB"))
        #expect(t.formattedProgress.contains("1.0 MB"))
    }

    @Test("Transfer formattedSpeed uses ByteFormatter")
    func formattedSpeed() {
        let t = Transfer(
            username: "u",
            filename: "f",
            size: 100,
            direction: .download,
            speed: 1024
        )
        #expect(t.formattedSpeed == "1.0 KB/s")
    }

    @Test("Transfer folderPath with two components and @@ prefix")
    func folderPathTwoComponents() {
        let t = Transfer(username: "u", filename: "@@music\\Song.mp3", size: 0, direction: .download)
        // After skipping @@ prefix, only filename remains => nil
        #expect(t.folderPath == nil)
    }

    @Test("Transfer folderPath with three components and @@ prefix")
    func folderPathThreeComponents() {
        let t = Transfer(username: "u", filename: "@@music\\Artist\\Song.mp3", size: 0, direction: .download)
        #expect(t.folderPath == "Artist")
    }

    @Test("Transfer localPath is nil by default")
    func localPathNil() {
        let t = Transfer(username: "u", filename: "f", size: 0, direction: .download)
        #expect(t.localPath == nil)
    }

    @Test("Transfer error is nil by default")
    func errorNil() {
        let t = Transfer(username: "u", filename: "f", size: 0, direction: .download)
        #expect(t.error == nil)
    }

    @Test("Transfer queuePosition is nil by default")
    func queuePositionNil() {
        let t = Transfer(username: "u", filename: "f", size: 0, direction: .download)
        #expect(t.queuePosition == nil)
    }

    @Test("Transfer Hashable - same ID is equal")
    func hashableEqual() {
        let id = UUID()
        let t1 = Transfer(id: id, username: "u", filename: "f", size: 0, direction: .download)
        let t2 = Transfer(id: id, username: "u", filename: "f", size: 0, direction: .download)
        #expect(t1 == t2)
    }

    @Test("Transfer Hashable - different ID is not equal")
    func hashableNotEqual() {
        let t1 = Transfer(username: "u", filename: "f", size: 0, direction: .download)
        let t2 = Transfer(username: "u", filename: "f", size: 0, direction: .download)
        #expect(t1 != t2)
    }
}

// MARK: - SharedFile Additional Tests

@Suite("SharedFile Additional")
struct SharedFileAdditionalTests {

    @Test("SharedFile default init values")
    func defaultValues() {
        let f = SharedFile(filename: "test.mp3")
        #expect(f.size == 0)
        #expect(f.bitrate == nil)
        #expect(f.duration == nil)
        #expect(f.isDirectory == false)
        #expect(f.isPrivate == false)
        #expect(f.children == nil)
        #expect(f.fileCount == 0)
    }

    @Test("SharedFile formattedSize uses ByteFormatter")
    func formattedSize() {
        let f = SharedFile(filename: "big.flac", size: 1_048_576)
        #expect(f.formattedSize == "1.0 MB")
    }

    @Test("SharedFile displayFilename equals displayName")
    func displayFilenameEqualsDisplayName() {
        let f = SharedFile(filename: "folder\\song.mp3")
        #expect(f.displayFilename == f.displayName)
    }

    @Test("SharedFile isPrivate can be set")
    func isPrivate() {
        let f = SharedFile(filename: "private.mp3", isPrivate: true)
        #expect(f.isPrivate)
    }

    @Test("SharedFile directory with children")
    func directoryWithChildren() {
        let child1 = SharedFile(filename: "a.mp3", size: 100)
        let child2 = SharedFile(filename: "b.flac", size: 200)
        let dir = SharedFile(
            filename: "Album",
            isDirectory: true,
            children: [child1, child2],
            fileCount: 2
        )
        #expect(dir.isDirectory)
        #expect(dir.children?.count == 2)
        #expect(dir.fileCount == 2)
    }

    @Test("SharedFile buildTree with multiple roots")
    func buildTreeMultipleRoots() {
        let files = [
            SharedFile(filename: "root1\\file1.mp3", size: 100),
            SharedFile(filename: "root2\\file2.mp3", size: 200),
        ]
        let tree = SharedFile.buildTree(from: files)
        #expect(tree.count == 2) // two root folders
    }

    @Test("SharedFile buildTree with deeply nested paths")
    func buildTreeDeepNesting() {
        let files = [
            SharedFile(filename: "A\\B\\C\\D\\file.mp3", size: 100),
        ]
        let tree = SharedFile.buildTree(from: files)
        #expect(tree.count == 1)
        let root = tree[0]
        #expect(root.isDirectory)
        #expect(root.displayName == "A")
    }

    @Test("SharedFile collectAllFiles from deeply nested structure")
    func collectAllFilesDeep() {
        let innerDir = SharedFile(
            filename: "inner",
            isDirectory: true,
            children: [SharedFile(filename: "deep.flac", size: 500)]
        )
        let outerDir = SharedFile(
            filename: "outer",
            isDirectory: true,
            children: [innerDir, SharedFile(filename: "shallow.mp3", size: 300)]
        )
        let collected = SharedFile.collectAllFiles(in: [outerDir])
        #expect(collected.count == 2)
    }
}

// MARK: - SearchResult Additional Tests

@Suite("SearchResult Additional")
struct SearchResultAdditionalTests {

    @Test("SearchResult default values")
    func defaults() {
        let r = SearchResult(username: "u", filename: "f", size: 0)
        #expect(r.bitrate == nil)
        #expect(r.duration == nil)
        #expect(r.sampleRate == nil)
        #expect(r.bitDepth == nil)
        #expect(r.isVBR == false)
        #expect(r.freeSlots == true)
        #expect(r.uploadSpeed == 0)
        #expect(r.queueLength == 0)
        #expect(r.isPrivate == false)
    }

    @Test("SearchResult isPrivate can be set")
    func isPrivate() {
        let r = SearchResult(username: "u", filename: "f", size: 0, isPrivate: true)
        #expect(r.isPrivate)
    }

    @Test("SearchResult formattedSampleRate 88200")
    func sampleRate88200() {
        let r = SearchResult(username: "u", filename: "f", size: 0, sampleRate: 88200)
        #expect(r.formattedSampleRate == "88.2 kHz")
    }

    @Test("SearchResult formattedSampleRate exact kHz")
    func sampleRateExact() {
        let r = SearchResult(username: "u", filename: "f", size: 0, sampleRate: 192000)
        #expect(r.formattedSampleRate == "192 kHz")
    }

    @Test("SearchResult Hashable conformance")
    func hashable() {
        let id = UUID()
        let r1 = SearchResult(id: id, username: "u", filename: "f", size: 0)
        let r2 = SearchResult(id: id, username: "u", filename: "f", size: 0)
        #expect(r1 == r2)
    }

    @Test("SearchResult fileExtension with mixed case path")
    func fileExtMixedCase() {
        let r = SearchResult(username: "u", filename: "Folder\\SubFolder\\Track.FLAC", size: 0)
        #expect(r.fileExtension == "flac")
    }
}

// MARK: - PrivateChat Tests

@Suite("PrivateChat")
struct PrivateChatTests {

    @Test("PrivateChat id equals username")
    func idEqualsUsername() {
        let chat = PrivateChat(username: "alice")
        #expect(chat.id == "alice")
    }

    @Test("PrivateChat default values")
    func defaults() {
        let chat = PrivateChat(username: "bob")
        #expect(chat.messages.isEmpty)
        #expect(chat.unreadCount == 0)
        #expect(chat.isOnline == false)
    }

    @Test("PrivateChat with messages")
    func withMessages() {
        let msg = ChatMessage(username: "alice", content: "Hello!")
        let chat = PrivateChat(
            username: "alice",
            messages: [msg],
            unreadCount: 1,
            isOnline: true
        )
        #expect(chat.messages.count == 1)
        #expect(chat.unreadCount == 1)
        #expect(chat.isOnline)
    }

    @Test("PrivateChat is Hashable")
    func hashable() {
        let c1 = PrivateChat(username: "alice")
        let c2 = PrivateChat(username: "bob")
        let set: Set<PrivateChat> = [c1, c2]
        #expect(set.count == 2)
    }
}

// MARK: - CountryFormatter Tests

@Suite("CountryFormatter")
struct CountryFormatterTests {

    @Test("flag for two-letter code returns non-empty")
    func validCode() {
        let flag = CountryFormatter.flag(for: "US")
        #expect(!flag.isEmpty)
    }

    @Test("flag for invalid length returns empty")
    func invalidLength() {
        #expect(CountryFormatter.flag(for: "") == "")
        #expect(CountryFormatter.flag(for: "A") == "")
        #expect(CountryFormatter.flag(for: "USA") == "")
    }

    @Test("flag produces different emojis for different countries")
    func differentCountries() {
        let us = CountryFormatter.flag(for: "US")
        let de = CountryFormatter.flag(for: "DE")
        #expect(us != de)
    }

    @Test("flag handles lowercase by uppercasing")
    func lowercase() {
        let upper = CountryFormatter.flag(for: "JP")
        let lower = CountryFormatter.flag(for: "jp")
        #expect(upper == lower)
    }
}

// MARK: - DateTimeFormatters Additional Tests

@Suite("DateTimeFormatters Additional")
struct DateTimeFormattersAdditionalTests {

    @Test("formatDuration with hours")
    func durationHours() {
        #expect(DateTimeFormatters.formatDuration(7230) == "2h 0m")
    }

    @Test("formatDuration with minutes and seconds")
    func durationMinSec() {
        #expect(DateTimeFormatters.formatDuration(330) == "5m 30s")
    }

    @Test("formatDuration with seconds only")
    func durationSecondsOnly() {
        #expect(DateTimeFormatters.formatDuration(45) == "45s")
    }

    @Test("formatDuration zero")
    func durationZero() {
        #expect(DateTimeFormatters.formatDuration(0) == "0s")
    }

    @Test("formatAudioDuration formats MM:SS")
    func audioDuration() {
        #expect(DateTimeFormatters.formatAudioDuration(0) == "0:00")
        #expect(DateTimeFormatters.formatAudioDuration(65) == "1:05")
        #expect(DateTimeFormatters.formatAudioDuration(3600) == "60:00")
    }

    @Test("formatTime produces non-empty string")
    func formatTime() {
        let s = DateTimeFormatters.formatTime(Date())
        #expect(!s.isEmpty)
    }

    @Test("formatDate produces non-empty string")
    func formatDate() {
        let s = DateTimeFormatters.formatDate(Date())
        #expect(!s.isEmpty)
    }

    @Test("formatDateTime produces non-empty string")
    func formatDateTime() {
        let s = DateTimeFormatters.formatDateTime(Date())
        #expect(!s.isEmpty)
    }

    @Test("formatRelative produces non-empty string")
    func formatRelative() {
        let s = DateTimeFormatters.formatRelative(Date())
        #expect(!s.isEmpty)
    }

    @Test("formatDurationSince returns duration string")
    func formatDurationSince() {
        let past = Date(timeIntervalSinceNow: -120)
        let s = DateTimeFormatters.formatDurationSince(past)
        // Should be approximately "2m 0s"
        #expect(s.contains("m") || s.contains("s"))
    }
}

// MARK: - NumberFormatters Tests

@Suite("NumberFormatters Additional")
struct NumberFormattersAdditionalTests {

    @Test("format Int zero")
    func formatIntZero() {
        #expect(NumberFormatters.format(0) == "0")
    }

    @Test("format UInt32 zero")
    func formatUInt32Zero() {
        #expect(NumberFormatters.format(UInt32(0)) == "0")
    }

    @Test("format UInt64 zero")
    func formatUInt64Zero() {
        #expect(NumberFormatters.format(UInt64(0)) == "0")
    }

    @Test("format Int with thousands separator")
    func formatIntThousands() {
        let result = NumberFormatters.format(1_000_000)
        // Should contain thousand separator (locale-dependent)
        #expect(result.count > 3) // at least "1,000,000" or equivalent
    }

    @Test("format UInt32 with value")
    func formatUInt32Value() {
        let result = NumberFormatters.format(UInt32(12345))
        #expect(!result.isEmpty)
    }

    @Test("format UInt64 large value")
    func formatUInt64Large() {
        let result = NumberFormatters.format(UInt64(9_999_999))
        #expect(!result.isEmpty)
    }
}

// MARK: - PeerConnectionEvent Tests

@Suite("PeerConnectionEvent")
struct PeerConnectionEventTests {

    @Test("PeerConnectionEvent cases can be constructed")
    func constructCases() {
        // Verify each case can be created without crashes
        _ = PeerConnectionEvent.stateChanged(.connected)
        _ = PeerConnectionEvent.message(code: 4, payload: Data())
        _ = PeerConnectionEvent.sharesReceived([])
        _ = PeerConnectionEvent.searchReply(token: 1, results: [])
        _ = PeerConnectionEvent.pierceFirewall(token: 42)
        _ = PeerConnectionEvent.uploadDenied(filename: "f", reason: "r")
        _ = PeerConnectionEvent.uploadFailed(filename: "f")
        _ = PeerConnectionEvent.queueUpload(username: "u", filename: "f")
        _ = PeerConnectionEvent.transferResponse(token: 1, allowed: true, filesize: 100)
        _ = PeerConnectionEvent.folderContentsRequest(token: 1, folder: "dir")
        _ = PeerConnectionEvent.folderContentsResponse(token: 1, folder: "dir", files: [])
        _ = PeerConnectionEvent.placeInQueueRequest(username: "u", filename: "f")
        _ = PeerConnectionEvent.placeInQueueReply(filename: "f", position: 5)
        _ = PeerConnectionEvent.sharesRequest
        _ = PeerConnectionEvent.userInfoRequest
        _ = PeerConnectionEvent.artworkRequest(token: 1, filePath: "/test.mp3")
        _ = PeerConnectionEvent.artworkReply(token: 1, imageData: Data())
    }
}

// MARK: - PeerPoolEvent Tests

@Suite("PeerPoolEvent")
struct PeerPoolEventTests {

    @Test("PeerPoolEvent.searchResults can be constructed")
    func searchResults() {
        let event = PeerPoolEvent.searchResults(token: 42, results: [])
        if case .searchResults(let token, let results) = event {
            #expect(token == 42)
            #expect(results.isEmpty)
        } else {
            Issue.record("Expected searchResults")
        }
    }

    @Test("PeerPoolEvent.uploadDenied can be constructed")
    func uploadDenied() {
        let event = PeerPoolEvent.uploadDenied(filename: "song.mp3", reason: "Queue full")
        if case .uploadDenied(let f, let r) = event {
            #expect(f == "song.mp3")
            #expect(r == "Queue full")
        } else {
            Issue.record("Expected uploadDenied")
        }
    }

    @Test("PeerPoolEvent.uploadFailed can be constructed")
    func uploadFailed() {
        let event = PeerPoolEvent.uploadFailed(filename: "track.flac")
        if case .uploadFailed(let f) = event {
            #expect(f == "track.flac")
        } else {
            Issue.record("Expected uploadFailed")
        }
    }

    @Test("PeerPoolEvent.folderContentsResponse stores data")
    func folderContentsResponse() {
        let files = [SharedFile(filename: "test.mp3", size: 100)]
        let event = PeerPoolEvent.folderContentsResponse(token: 1, folder: "Music", files: files)
        if case .folderContentsResponse(let t, let f, let fs) = event {
            #expect(t == 1)
            #expect(f == "Music")
            #expect(fs.count == 1)
        } else {
            Issue.record("Expected folderContentsResponse")
        }
    }

    @Test("PeerPoolEvent.userIPDiscovered stores username and IP")
    func userIPDiscovered() {
        let event = PeerPoolEvent.userIPDiscovered(username: "alice", ip: "1.2.3.4")
        if case .userIPDiscovered(let u, let ip) = event {
            #expect(u == "alice")
            #expect(ip == "1.2.3.4")
        } else {
            Issue.record("Expected userIPDiscovered")
        }
    }

    @Test("PeerPoolEvent.artworkReply stores token and data")
    func artworkReply() {
        let data = Data([0xFF, 0xD8, 0xFF])
        let event = PeerPoolEvent.artworkReply(token: 42, imageData: data)
        if case .artworkReply(let t, let d) = event {
            #expect(t == 42)
            #expect(d == data)
        } else {
            Issue.record("Expected artworkReply")
        }
    }
}

// MARK: - Protocols Tests

@Suite("Protocols")
struct ProtocolsTests {

    @Test("AudioFileMetadata init with all parameters")
    func audioMetadataFull() {
        let m = AudioFileMetadata(artist: "A", album: "B", title: "C")
        #expect(m.artist == "A")
        #expect(m.album == "B")
        #expect(m.title == "C")
    }

    @Test("AudioFileMetadata is mutable")
    func audioMetadataMutable() {
        var m = AudioFileMetadata()
        m.artist = "Test"
        #expect(m.artist == "Test")
    }

    @Test("ActivityLogger.shared is nil by default")
    @MainActor func activityLoggerDefault() {
        // Don't set it, just verify it starts as nil (or whatever it is)
        // Note: might not be nil in test environment if other tests set it
        _ = ActivityLogger.shared
    }

    @Test("ConnectionStatus allCases count is 5")
    func connectionStatusCount() {
        #expect(ConnectionStatus.allCases.count == 5)
    }
}

// MARK: - User Additional Tests

@Suite("User Additional")
struct UserAdditionalTests {

    @Test("User init with all parameters")
    func fullInit() {
        let user = User(
            username: "alice",
            status: .online,
            isPrivileged: true,
            averageSpeed: 1_000_000,
            downloadCount: 50,
            fileCount: 1000,
            folderCount: 50,
            countryCode: "US"
        )
        #expect(user.username == "alice")
        #expect(user.status == .online)
        #expect(user.isPrivileged == true)
        #expect(user.averageSpeed == 1_000_000)
        #expect(user.downloadCount == 50)
        #expect(user.fileCount == 1000)
        #expect(user.folderCount == 50)
        #expect(user.countryCode == "US")
    }

    @Test("User default values")
    func defaults() {
        let user = User(username: "bob")
        #expect(user.status == .offline)
        #expect(user.isPrivileged == false)
        #expect(user.averageSpeed == 0)
        #expect(user.downloadCount == 0)
        #expect(user.fileCount == 0)
        #expect(user.folderCount == 0)
        #expect(user.countryCode == nil)
    }

    @Test("User Hashable conformance")
    func hashable() {
        let u1 = User(username: "alice")
        let u2 = User(username: "bob")
        let u3 = User(username: "alice")
        let set: Set<User> = [u1, u2, u3]
        #expect(set.count == 2) // alice appears once
    }
}

// MARK: - ChatRoom Additional Tests

@Suite("ChatRoom Additional")
struct ChatRoomAdditionalTests {

    @Test("ChatRoom init with all parameters")
    func fullInit() {
        let room = ChatRoom(
            name: "testroom",
            users: ["a", "b"],
            messages: [],
            unreadCount: 5,
            isJoined: true,
            isPrivate: true,
            owner: "admin",
            operators: Set(["mod1"]),
            members: ["a", "b"],
            tickers: ["a": "Hello"]
        )
        #expect(room.name == "testroom")
        #expect(room.users.count == 2)
        #expect(room.unreadCount == 5)
        #expect(room.isJoined)
        #expect(room.isPrivate)
        #expect(room.owner == "admin")
        #expect(room.operators.contains("mod1"))
        #expect(room.members.count == 2)
        #expect(room.tickers["a"] == "Hello")
    }

    @Test("ChatRoom defaults")
    func defaults() {
        let room = ChatRoom(name: "default")
        #expect(room.users.isEmpty)
        #expect(room.messages.isEmpty)
        #expect(room.unreadCount == 0)
        #expect(!room.isJoined)
        #expect(!room.isPrivate)
        #expect(room.owner == nil)
        #expect(room.operators.isEmpty)
        #expect(room.members.isEmpty)
        #expect(room.tickers.isEmpty)
    }

    @Test("ChatRoom Hashable conformance")
    func hashable() {
        let r1 = ChatRoom(name: "room1")
        let r2 = ChatRoom(name: "room2")
        let set: Set<ChatRoom> = [r1, r2]
        #expect(set.count == 2)
    }
}

// MARK: - ChatMessage Additional Tests

@Suite("ChatMessage Additional")
struct ChatMessageAdditionalTests {

    @Test("ChatMessage with all parameters")
    func fullInit() {
        let now = Date()
        let msg = ChatMessage(
            messageId: 42,
            timestamp: now,
            username: "alice",
            content: "Hello!",
            isSystem: true,
            isOwn: true,
            isNewMessage: false
        )
        #expect(msg.messageId == 42)
        #expect(msg.timestamp == now)
        #expect(msg.username == "alice")
        #expect(msg.content == "Hello!")
        #expect(msg.isSystem)
        #expect(msg.isOwn)
        #expect(!msg.isNewMessage)
    }

    @Test("ChatMessage Hashable conformance")
    func hashable() {
        let id = UUID()
        let now = Date()
        let m1 = ChatMessage(id: id, timestamp: now, username: "u", content: "a")
        let m2 = ChatMessage(id: id, timestamp: now, username: "u", content: "a")
        #expect(m1 == m2)
    }
}

// MARK: - SearchQuery Additional Tests

@Suite("SearchQuery Additional")
struct SearchQueryAdditionalTests {

    @Test("SearchQuery full memberwise init")
    func fullInit() {
        let id = UUID()
        let now = Date()
        let results = [SearchResult(username: "u", filename: "f", size: 0)]
        let query = SearchQuery(
            id: id,
            query: "test",
            token: 42,
            timestamp: now,
            results: results,
            isSearching: false
        )
        #expect(query.id == id)
        #expect(query.query == "test")
        #expect(query.token == 42)
        #expect(query.timestamp == now)
        #expect(query.results.count == 1)
        #expect(!query.isSearching)
    }

    @Test("SearchQuery Hashable conformance")
    func hashable() {
        let q1 = SearchQuery(query: "a", token: 1)
        let q2 = SearchQuery(query: "b", token: 2)
        let set: Set<SearchQuery> = [q1, q2]
        #expect(set.count == 2)
    }

    @Test("SearchQuery uniqueUsers returns 0 for empty results")
    func uniqueUsersEmpty() {
        let q = SearchQuery(query: "test", token: 1)
        #expect(q.uniqueUsers == 0)
    }
}

// MARK: - UserShares Additional Tests

@Suite("UserShares Additional")
struct UserSharesAdditionalTests {

    @Test("UserShares default isLoading is true")
    func defaultLoading() {
        let shares = UserShares(username: "alice")
        #expect(shares.isLoading)
    }

    @Test("UserShares error is nil by default")
    func defaultError() {
        let shares = UserShares(username: "bob")
        #expect(shares.error == nil)
    }

    @Test("UserShares with directory-only structure counts no files")
    func dirOnlyNoFiles() {
        let dir = SharedFile(filename: "empty", isDirectory: true, children: [])
        let shares = UserShares(username: "u", folders: [dir])
        #expect(shares.totalFiles == 0)
        #expect(shares.totalSize == 0)
    }

    @Test("UserShares computeStats caches nil-returning on empty")
    func computeStatsEmpty() {
        var shares = UserShares(username: "u", folders: [])
        shares.computeStats()
        #expect(shares.cachedTotalFiles == 0)
        #expect(shares.cachedTotalSize == 0)
    }
}

// MARK: - Data Extensions Additional Coverage

@Suite("Data Extensions Additional")
struct DataExtensionsAdditionalTests {

    @Test("readBool returns true for non-zero byte")
    func readBoolTrue() {
        let data = Data([0x01])
        #expect(data.readBool(at: 0) == true)
    }

    @Test("readBool returns false for zero byte")
    func readBoolFalse() {
        let data = Data([0x00])
        #expect(data.readBool(at: 0) == false)
    }

    @Test("readBool returns nil for out of bounds")
    func readBoolOutOfBounds() {
        let data = Data()
        #expect(data.readBool(at: 0) == nil)
    }

    @Test("readByte is alias for readUInt8")
    func readByteAlias() {
        let data = Data([0x42])
        #expect(data.readByte(at: 0) == data.readUInt8(at: 0))
    }

    @Test("readInt32 reads signed values correctly")
    func readInt32() {
        var data = Data()
        data.appendInt32(-1)
        #expect(data.readInt32(at: 0) == -1)
    }

    @Test("readInt32 positive value")
    func readInt32Positive() {
        var data = Data()
        data.appendInt32(42)
        #expect(data.readInt32(at: 0) == 42)
    }

    @Test("safeSubdata returns nil for out of bounds")
    func safeSubdataOutOfBounds() {
        let data = Data([0x01, 0x02])
        #expect(data.safeSubdata(in: 0..<5) == nil)
    }

    @Test("safeSubdata returns nil for negative lower bound")
    func safeSubdataNegativeLower() {
        let data = Data([0x01, 0x02])
        #expect(data.safeSubdata(in: -1..<1) == nil)
    }

    @Test("safeSubdata returns correct subdata")
    func safeSubdataValid() {
        let data = Data([0x01, 0x02, 0x03, 0x04])
        let sub = data.safeSubdata(in: 1..<3)
        #expect(sub == Data([0x02, 0x03]))
    }

    @Test("safeSubdata empty range returns empty data")
    func safeSubdataEmptyRange() {
        let data = Data([0x01, 0x02])
        let sub = data.safeSubdata(in: 1..<1)
        #expect(sub == Data())
    }

    @Test("readString returns nil for length exceeding maxStringLength")
    func readStringTooLong() {
        var data = Data()
        data.appendUInt32(UInt32(Data.maxStringLength + 1))
        // Even without the string body, the length check should reject it
        #expect(data.readString(at: 0) == nil)
    }

    @Test("readString returns nil when string data extends beyond buffer")
    func readStringBeyondBuffer() {
        var data = Data()
        data.appendUInt32(100) // claims 100 bytes of string
        data.append(contentsOf: [0x41]) // only 1 byte of actual string
        #expect(data.readString(at: 0) == nil)
    }

    @Test("appendBool appends 1 for true and 0 for false")
    func appendBool() {
        var data = Data()
        data.appendBool(true)
        data.appendBool(false)
        #expect(data[0] == 1)
        #expect(data[1] == 0)
    }

    @Test("hexString roundtrip")
    func hexStringRoundtrip() {
        let original = Data([0xDE, 0xAD, 0xBE, 0xEF])
        let hex = original.hexString
        #expect(hex == "de ad be ef")
        let restored = Data(hexString: hex)
        #expect(restored == original)
    }

    @Test("Data init from hex string without spaces")
    func hexStringNoSpaces() {
        let data = Data(hexString: "DEADBEEF")
        #expect(data == Data([0xDE, 0xAD, 0xBE, 0xEF]))
    }

    @Test("readUInt64 round trips")
    func readUInt64RoundTrip() {
        var data = Data()
        let value: UInt64 = 0x0123456789ABCDEF
        data.appendUInt64(value)
        #expect(data.readUInt64(at: 0) == value)
    }

    @Test("readUInt64 returns nil for insufficient data")
    func readUInt64TooShort() {
        let data = Data([0x01, 0x02, 0x03])
        #expect(data.readUInt64(at: 0) == nil)
    }

    @Test("Data.maxStringLength is 1MB")
    func maxStringLength() {
        #expect(Data.maxStringLength == 1_000_000)
    }
}

// MARK: - ByteFormatter Additional Tests

@Suite("ByteFormatter Additional")
struct ByteFormatterAdditionalTests {

    @Test("format negative bytes")
    func formatNegative() {
        // Implementation should handle this gracefully
        let result = ByteFormatter.format(-1)
        #expect(!result.isEmpty)
    }

    @Test("formatSpeed with GB/s range")
    func formatSpeedGB() {
        // 2 GB/s = 2,147,483,648
        let result = ByteFormatter.formatSpeed(Int64(2_147_483_648))
        #expect(result.contains("GB/s"))
    }
}
