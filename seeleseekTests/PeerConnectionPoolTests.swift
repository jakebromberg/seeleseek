import Testing
import Foundation
@testable import SeeleseekCore
@testable import seeleseek

// MARK: - PeerConnectionPool Tests

@Suite("PeerConnectionPool Tests", .serialized)
struct PeerConnectionPoolTests {

    // MARK: - Initialization and Configuration

    @Test("Pool initializes with empty state")
    @MainActor func poolInitializesEmpty() {
        let pool = PeerConnectionPool()
        #expect(pool.connections.isEmpty)
        #expect(pool.pendingConnections.isEmpty)
        #expect(pool.totalBytesReceived == 0)
        #expect(pool.totalBytesSent == 0)
        #expect(pool.totalConnections == 0)
        #expect(pool.activeConnections == 0)
        #expect(pool.connectToPeerCount == 0)
        #expect(pool.pierceFirewallCount == 0)
        #expect(pool.currentDownloadSpeed == 0)
        #expect(pool.currentUploadSpeed == 0)
        #expect(pool.speedHistory.isEmpty)
        #expect(pool.peerLocations.isEmpty)
    }

    @Test("Pool has expected connection limits")
    @MainActor func poolConnectionLimits() {
        let pool = PeerConnectionPool()
        #expect(pool.maxConnections == 50)
        #expect(pool.maxConnectionsPerIP == 30)
        #expect(pool.connectionTimeout == 60)
    }

    @Test("ourUsername defaults to empty and is settable")
    @MainActor func ourUsernameSettable() {
        let pool = PeerConnectionPool()
        #expect(pool.ourUsername == "")
        pool.ourUsername = "testuser"
        #expect(pool.ourUsername == "testuser")
    }

    @Test("listenPort defaults to zero and is settable")
    @MainActor func listenPortSettable() {
        let pool = PeerConnectionPool()
        #expect(pool.listenPort == 0)
        pool.listenPort = 12345
        #expect(pool.listenPort == 12345)
    }

    // MARK: - Pending Connection Management

    @Test("addPendingConnection stores connection by token")
    @MainActor func addPendingConnection() {
        let pool = PeerConnectionPool()
        pool.addPendingConnection(username: "alice", token: 42)
        #expect(pool.pendingConnections.count == 1)
        #expect(pool.pendingConnections[42]?.username == "alice")
        #expect(pool.pendingConnections[42]?.token == 42)
        #expect(pool.pendingConnections[42]?.attempts == 0)
    }

    @Test("addPendingConnection supports multiple pending connections")
    @MainActor func addMultiplePendingConnections() {
        let pool = PeerConnectionPool()
        pool.addPendingConnection(username: "alice", token: 1)
        pool.addPendingConnection(username: "bob", token: 2)
        pool.addPendingConnection(username: "charlie", token: 3)
        #expect(pool.pendingConnections.count == 3)
        #expect(pool.pendingConnections[1]?.username == "alice")
        #expect(pool.pendingConnections[2]?.username == "bob")
        #expect(pool.pendingConnections[3]?.username == "charlie")
    }

    @Test("resolvePendingConnection removes and returns connection")
    @MainActor func resolvePendingConnection() {
        let pool = PeerConnectionPool()
        pool.addPendingConnection(username: "alice", token: 42)

        let resolved = pool.resolvePendingConnection(token: 42)
        #expect(resolved != nil)
        #expect(resolved?.username == "alice")
        #expect(resolved?.token == 42)
        #expect(pool.pendingConnections.isEmpty)
    }

    @Test("resolvePendingConnection returns nil for unknown token")
    @MainActor func resolvePendingConnectionUnknownToken() {
        let pool = PeerConnectionPool()
        let resolved = pool.resolvePendingConnection(token: 999)
        #expect(resolved == nil)
    }

    @Test("resolvePendingConnection does not affect other pending connections")
    @MainActor func resolvePendingConnectionSelectivity() {
        let pool = PeerConnectionPool()
        pool.addPendingConnection(username: "alice", token: 1)
        pool.addPendingConnection(username: "bob", token: 2)

        let resolved = pool.resolvePendingConnection(token: 1)
        #expect(resolved?.username == "alice")
        #expect(pool.pendingConnections.count == 1)
        #expect(pool.pendingConnections[2]?.username == "bob")
    }

    // MARK: - Diagnostic Counters

    @Test("incrementConnectToPeerCount increments counter")
    @MainActor func incrementConnectToPeerCount() {
        let pool = PeerConnectionPool()
        #expect(pool.connectToPeerCount == 0)
        pool.incrementConnectToPeerCount()
        #expect(pool.connectToPeerCount == 1)
        pool.incrementConnectToPeerCount()
        pool.incrementConnectToPeerCount()
        #expect(pool.connectToPeerCount == 3)
    }

    @Test("incrementPierceFirewallCount increments counter")
    @MainActor func incrementPierceFirewallCount() {
        let pool = PeerConnectionPool()
        #expect(pool.pierceFirewallCount == 0)
        pool.incrementPierceFirewallCount()
        #expect(pool.pierceFirewallCount == 1)
        pool.incrementPierceFirewallCount()
        #expect(pool.pierceFirewallCount == 2)
    }

    // MARK: - IP Validation (Static Method)

    @Test("isValidPeerIP accepts valid public IPs", arguments: [
        "192.168.1.1",
        "10.0.0.1",
        "172.16.0.1",
        "8.8.8.8",
        "1.2.3.4",
        "203.0.113.50",
    ])
    func validIPs(ip: String) {
        #expect(PeerConnectionPool.isValidPeerIP(ip))
    }

    @Test("isValidPeerIP rejects multicast IPs", arguments: [
        "224.0.0.1",
        "224.0.0.251",
        "239.255.255.255",
        "230.1.2.3",
    ])
    func rejectMulticast(ip: String) {
        #expect(!PeerConnectionPool.isValidPeerIP(ip))
    }

    @Test("isValidPeerIP rejects broadcast address")
    func rejectBroadcast() {
        #expect(!PeerConnectionPool.isValidPeerIP("255.255.255.255"))
    }

    @Test("isValidPeerIP rejects loopback addresses", arguments: [
        "127.0.0.1",
        "127.0.0.0",
        "127.255.255.255",
    ])
    func rejectLoopback(ip: String) {
        #expect(!PeerConnectionPool.isValidPeerIP(ip))
    }

    @Test("isValidPeerIP rejects all-zeros address")
    func rejectAllZeros() {
        #expect(!PeerConnectionPool.isValidPeerIP("0.0.0.0"))
    }

    @Test("isValidPeerIP rejects reserved range (240+)", arguments: [
        "240.0.0.1",
        "241.0.0.0",
        "250.1.2.3",
        "254.0.0.0",
    ])
    func rejectReserved(ip: String) {
        #expect(!PeerConnectionPool.isValidPeerIP(ip))
    }

    @Test("isValidPeerIP rejects malformed IPs", arguments: [
        "",
        "not.an.ip",
        "1.2.3",
        "1.2.3.4.5",
        "256.0.0.1",
        "abc.def.ghi.jkl",
    ])
    func rejectMalformed(ip: String) {
        #expect(!PeerConnectionPool.isValidPeerIP(ip))
    }

    // MARK: - Connection Lookup (Empty Pool)

    @Test("getConnection returns nil for unknown ID")
    @MainActor func getConnectionUnknownId() {
        let pool = PeerConnectionPool()
        let result = pool.getConnection("nonexistent-id")
        #expect(result == nil)
    }

    @Test("getConnectionForUser returns nil when pool is empty")
    @MainActor func getConnectionForUserEmptyPool() async {
        let pool = PeerConnectionPool()
        let result = await pool.getConnectionForUser("alice")
        #expect(result == nil)
    }

    // MARK: - Disconnect All (Empty Pool)

    @Test("disconnectAll on empty pool leaves clean state")
    @MainActor func disconnectAllEmptyPool() async {
        let pool = PeerConnectionPool()
        pool.addPendingConnection(username: "alice", token: 42)
        #expect(pool.pendingConnections.count == 1)

        await pool.disconnectAll()
        #expect(pool.connections.isEmpty)
        #expect(pool.pendingConnections.isEmpty)
        #expect(pool.activeConnections == 0)
    }

    // MARK: - Cleanup Stale Connections

    @Test("cleanupStaleConnections keeps fresh pending connections")
    @MainActor func cleanupKeepsFreshPending() {
        let pool = PeerConnectionPool()
        pool.addPendingConnection(username: "alice", token: 1)
        pool.addPendingConnection(username: "bob", token: 2)

        // Fresh connections should survive cleanup
        pool.cleanupStaleConnections()

        #expect(pool.pendingConnections.count == 2)
    }

    @Test("cleanupStaleConnections does not crash on empty pool")
    @MainActor func cleanupEmptyPool() {
        let pool = PeerConnectionPool()
        pool.cleanupStaleConnections()
        #expect(pool.connections.isEmpty)
        #expect(pool.pendingConnections.isEmpty)
    }

    // MARK: - Analytics (Empty State)

    @Test("connectionsByType is empty when no connections")
    @MainActor func connectionsByTypeEmpty() {
        let pool = PeerConnectionPool()
        #expect(pool.connectionsByType.isEmpty)
    }

    @Test("averageConnectionDuration is zero when no connections")
    @MainActor func averageConnectionDurationEmpty() {
        let pool = PeerConnectionPool()
        #expect(pool.averageConnectionDuration == 0)
    }

    @Test("topPeersByTraffic is empty when no connections")
    @MainActor func topPeersByTrafficEmpty() {
        let pool = PeerConnectionPool()
        #expect(pool.topPeersByTraffic.isEmpty)
    }

    // MARK: - Type Construction

    @Test("PeerConnectionInfo can be created with all fields")
    func peerConnectionInfoConstruction() {
        let now = Date()
        let info = PeerConnectionPool.PeerConnectionInfo(
            id: "test-123",
            username: "alice",
            ip: "192.168.1.100",
            port: 2234,
            state: .connected,
            connectionType: .peer,
            bytesReceived: 1024,
            bytesSent: 512,
            connectedAt: now,
            lastActivity: now,
            currentSpeed: 50000
        )

        #expect(info.id == "test-123")
        #expect(info.username == "alice")
        #expect(info.ip == "192.168.1.100")
        #expect(info.port == 2234)
        #expect(info.state == .connected)
        #expect(info.connectionType == .peer)
        #expect(info.bytesReceived == 1024)
        #expect(info.bytesSent == 512)
        #expect(info.connectedAt == now)
        #expect(info.lastActivity == now)
        #expect(info.currentSpeed == 50000)
    }

    @Test("PeerConnectionInfo defaults are zero/nil")
    func peerConnectionInfoDefaults() {
        let info = PeerConnectionPool.PeerConnectionInfo(
            id: "test",
            username: "alice",
            ip: "1.2.3.4",
            port: 80,
            state: .disconnected,
            connectionType: .peer
        )

        #expect(info.bytesReceived == 0)
        #expect(info.bytesSent == 0)
        #expect(info.connectedAt == nil)
        #expect(info.lastActivity == nil)
        #expect(info.currentSpeed == 0)
    }

    @Test("PendingConnection stores all fields correctly")
    func pendingConnectionConstruction() {
        let now = Date()
        let pending = PeerConnectionPool.PendingConnection(
            username: "bob",
            token: 12345,
            timestamp: now,
            attempts: 3
        )

        #expect(pending.username == "bob")
        #expect(pending.token == 12345)
        #expect(pending.timestamp == now)
        #expect(pending.attempts == 3)
    }

    @Test("PendingConnection defaults attempts to zero")
    func pendingConnectionDefaultAttempts() {
        let pending = PeerConnectionPool.PendingConnection(
            username: "bob",
            token: 1,
            timestamp: Date()
        )
        #expect(pending.attempts == 0)
    }

    @Test("SpeedSample stores timestamp and speeds")
    func speedSampleConstruction() {
        let now = Date()
        let sample = PeerConnectionPool.SpeedSample(
            timestamp: now,
            downloadSpeed: 1_000_000,
            uploadSpeed: 500_000
        )

        #expect(sample.timestamp == now)
        #expect(sample.downloadSpeed == 1_000_000)
        #expect(sample.uploadSpeed == 500_000)
    }

    @Test("PeerLocation stores all fields")
    func peerLocationConstruction() {
        let location = PeerConnectionPool.PeerLocation(
            username: "alice",
            country: "US",
            latitude: 37.7749,
            longitude: -122.4194
        )

        #expect(location.username == "alice")
        #expect(location.country == "US")
        #expect(location.latitude == 37.7749)
        #expect(location.longitude == -122.4194)
    }

    // MARK: - Connect Validation

    @Test("connect rejects invalid IP addresses")
    @MainActor func connectRejectsInvalidIP() async {
        let pool = PeerConnectionPool()

        await #expect(throws: PeerConnectionError.self) {
            _ = try await pool.connect(to: "testuser", ip: "224.0.0.1", port: 2234, token: 1)
        }

        await #expect(throws: PeerConnectionError.self) {
            _ = try await pool.connect(to: "testuser", ip: "127.0.0.1", port: 2234, token: 2)
        }

        await #expect(throws: PeerConnectionError.self) {
            _ = try await pool.connect(to: "testuser", ip: "0.0.0.0", port: 2234, token: 3)
        }
    }

    // MARK: - Event Stream

    @Test("Pool exposes an event stream")
    @MainActor func poolHasEventStream() {
        let pool = PeerConnectionPool()
        // The events property should be accessible and non-nil
        let _ = pool.events
        // If we got here without crashing, the stream is properly initialized
    }

    // MARK: - Disconnect by Username (Empty Pool)

    @Test("disconnect by username on empty pool is a no-op")
    @MainActor func disconnectByUsernameEmptyPool() async {
        let pool = PeerConnectionPool()
        await pool.disconnect(username: "nonexistent")
        #expect(pool.connections.isEmpty)
        #expect(pool.activeConnections == 0)
    }
}

// MARK: - PeerConnectionError Tests

@Suite("PeerConnectionError Tests")
struct PeerConnectionErrorTests {

    @Test("invalidAddress has description")
    func invalidAddressDescription() {
        let error = PeerConnectionError.invalidAddress
        #expect(error.errorDescription?.contains("Invalid") == true)
    }

    @Test("timeout has description")
    func timeoutDescription() {
        let error = PeerConnectionError.timeout
        #expect(error.errorDescription?.contains("timed out") == true)
    }

    @Test("connectionFailed includes reason")
    func connectionFailedDescription() {
        let error = PeerConnectionError.connectionFailed("peer refused")
        #expect(error.errorDescription?.contains("peer refused") == true)
    }
}
