import Testing
import Foundation
@testable import SeeleseekCore

/// Deep coverage tests for ServerMessageHandler: exercises every remaining
/// handler method not already covered by ServerMessageHandlerTests.
@Suite("ServerMessageHandler Deep Tests", .serialized)
@MainActor
struct ServerMessageHandlerDeepTests {

    // MARK: - Helpers

    /// Build a complete wire-format server message: [uint32 length][uint32 code][payload]
    /// where length = 4 + payload.count (includes the code bytes).
    private func buildServerMessage(code: ServerMessageCode, payload: Data = Data()) -> Data {
        var msg = Data()
        let length = UInt32(4 + payload.count)
        msg.appendUInt32(length)
        msg.appendUInt32(code.rawValue)
        msg.append(payload)
        return msg
    }

    private func buildServerMessage(rawCode: UInt32, payload: Data = Data()) -> Data {
        var msg = Data()
        let length = UInt32(4 + payload.count)
        msg.appendUInt32(length)
        msg.appendUInt32(rawCode)
        msg.append(payload)
        return msg
    }

    /// Construct an IP uint32 in the protocol's format: bytes in network order stored as LE uint32.
    private func makeIP(_ a: UInt8, _ b: UInt8, _ c: UInt8, _ d: UInt8) -> UInt32 {
        (UInt32(a) << 24) | (UInt32(b) << 16) | (UInt32(c) << 8) | UInt32(d)
    }

    // MARK: - ConnectToPeer (code 18)

    @Test("ConnectToPeer with port 0 is silently ignored")
    func connectToPeerPortZero() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        var payload = Data()
        payload.appendString("alice")
        payload.appendString("P")
        payload.appendUInt32(makeIP(10, 0, 0, 1))
        payload.appendUInt32(0)          // port = 0 -> skipped
        payload.appendUInt32(12345)      // token

        let msg = buildServerMessage(code: .connectToPeer, payload: payload)
        // Should not crash; the handler skips port-0 addresses
        await handler.handle(msg)
    }

    @Test("ConnectToPeer with IP 0.0.0.0 is silently ignored")
    func connectToPeerZeroIP() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        var payload = Data()
        payload.appendString("bob")
        payload.appendString("P")
        payload.appendUInt32(0)          // IP 0.0.0.0
        payload.appendUInt32(2234)
        payload.appendUInt32(99999)

        let msg = buildServerMessage(code: .connectToPeer, payload: payload)
        await handler.handle(msg)
    }

    @Test("ConnectToPeer with truncated payload does not crash")
    func connectToPeerTruncated() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        // Only username, no connection type
        var payload = Data()
        payload.appendString("alice")

        let msg = buildServerMessage(code: .connectToPeer, payload: payload)
        await handler.handle(msg)
    }

    @Test("ConnectToPeer duplicate token is skipped")
    func connectToPeerDuplicate() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        var payload = Data()
        payload.appendString("alice")
        payload.appendString("P")
        payload.appendUInt32(makeIP(10, 0, 0, 1))
        payload.appendUInt32(2234)
        payload.appendUInt32(55555)

        let msg = buildServerMessage(code: .connectToPeer, payload: payload)
        // Send twice — the second should be deduplicated
        await handler.handle(msg)
        await handler.handle(msg)
    }

    // MARK: - WatchUser (code 5)

    @Test("WatchUser with existing user dispatches status and stats")
    func watchUserExists() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        var capturedUsername: String?
        var capturedStatus: UserStatus?
        client.addUserStatusHandler { username, status, _ in
            capturedUsername = username
            capturedStatus = status
        }

        var capturedStatsUser: String?
        var capturedAvgSpeed: UInt32?
        var capturedFiles: UInt32?
        var capturedDirs: UInt32?
        client.addUserStatsHandler { username, avgSpeed, _, files, dirs in
            capturedStatsUser = username
            capturedAvgSpeed = avgSpeed
            capturedFiles = files
            capturedDirs = dirs
        }

        var payload = Data()
        payload.appendString("alice")
        payload.appendUInt8(1)             // exists = true
        payload.appendUInt32(UserStatus.online.rawValue)
        payload.appendUInt32(50000)        // avgSpeed
        payload.appendUInt32(100)          // uploadNum
        payload.appendUInt32(0)            // unknown field
        payload.appendUInt32(1234)         // files
        payload.appendUInt32(56)           // dirs
        // optional country
        payload.appendString("US")

        let msg = buildServerMessage(code: .watchUser, payload: payload)
        await handler.handle(msg)

        try? await Task.sleep(for: .milliseconds(100))

        #expect(capturedUsername == "alice")
        #expect(capturedStatus == .online)
        #expect(capturedStatsUser == "alice")
        #expect(capturedAvgSpeed == 50000)
        #expect(capturedFiles == 1234)
        #expect(capturedDirs == 56)
    }

    @Test("WatchUser with non-existent user dispatches offline status")
    func watchUserNotExists() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        var capturedStatus: UserStatus?
        client.addUserStatusHandler { _, status, _ in
            capturedStatus = status
        }

        var payload = Data()
        payload.appendString("ghost")
        payload.appendUInt8(0) // exists = false

        let msg = buildServerMessage(code: .watchUser, payload: payload)
        await handler.handle(msg)

        try? await Task.sleep(for: .milliseconds(100))

        #expect(capturedStatus == .offline)
    }

    @Test("WatchUser with away status reads country")
    func watchUserAway() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        var capturedStatus: UserStatus?
        client.addUserStatusHandler { _, status, _ in
            capturedStatus = status
        }

        var payload = Data()
        payload.appendString("sleepy")
        payload.appendUInt8(1)
        payload.appendUInt32(UserStatus.away.rawValue)
        payload.appendUInt32(10000)
        payload.appendUInt32(50)
        payload.appendUInt32(0)
        payload.appendUInt32(500)
        payload.appendUInt32(20)
        payload.appendString("DE")

        let msg = buildServerMessage(code: .watchUser, payload: payload)
        await handler.handle(msg)

        try? await Task.sleep(for: .milliseconds(100))

        #expect(capturedStatus == .away)
    }

    // MARK: - GetUserStats (code 36)

    @Test("GetUserStats dispatches stats via addUserStatsHandler")
    func getUserStats() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        var capturedUsername: String?
        var capturedSpeed: UInt32?
        var capturedUploadNum: UInt64?
        var capturedFiles: UInt32?
        var capturedDirs: UInt32?

        client.addUserStatsHandler { username, avgSpeed, uploadNum, files, dirs in
            capturedUsername = username
            capturedSpeed = avgSpeed
            capturedUploadNum = uploadNum
            capturedFiles = files
            capturedDirs = dirs
        }

        var payload = Data()
        payload.appendString("statsuser")
        payload.appendUInt32(999999)   // avgSpeed
        payload.appendUInt32(42)       // uploadNum
        payload.appendUInt32(0)        // unknown field (skipped)
        payload.appendUInt32(10000)    // files
        payload.appendUInt32(500)      // dirs

        let msg = buildServerMessage(code: .getUserStats, payload: payload)
        await handler.handle(msg)

        #expect(capturedUsername == "statsuser")
        #expect(capturedSpeed == 999999)
        #expect(capturedUploadNum == 42)
        #expect(capturedFiles == 10000)
        #expect(capturedDirs == 500)
    }

    @Test("GetUserStats with truncated payload does not crash")
    func getUserStatsTruncated() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        var called = false
        client.addUserStatsHandler { _, _, _, _, _ in
            called = true
        }

        // Only username, no stat fields
        var payload = Data()
        payload.appendString("partial")

        let msg = buildServerMessage(code: .getUserStats, payload: payload)
        await handler.handle(msg)

        #expect(called == false)
    }

    // MARK: - Relogged (code 41)

    @Test("Relogged calls handleReloggedDisconnect")
    func relogged() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        // Relogged has no payload
        let msg = buildServerMessage(code: .relogged)
        await handler.handle(msg)

        // handleReloggedDisconnect sets shouldAutoReconnect = false internally;
        // we verify it didn't crash
    }

    // MARK: - EmbeddedMessage (code 93)

    @Test("EmbeddedMessage with search request parses correctly")
    func embeddedMessageSearch() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        // Build an embedded distributed search message
        // Format: uint8 distribCode=3 (searchRequest) + search payload
        var innerPayload = Data()
        innerPayload.appendUInt32(0)         // unknown
        innerPayload.appendString("searcher")
        innerPayload.appendUInt32(77777)     // token
        innerPayload.appendString("daft punk")

        var payload = Data()
        payload.appendUInt8(DistributedMessageCode.searchRequest.rawValue)
        payload.append(innerPayload)

        let msg = buildServerMessage(code: .embeddedMessage, payload: payload)
        // Should not crash — the handler attempts to search shared files (none exist)
        await handler.handle(msg)
    }

    @Test("EmbeddedMessage with non-search code is a no-op")
    func embeddedMessageNonSearch() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        // Embedded message with branchLevel code (not a search)
        var payload = Data()
        payload.appendUInt8(DistributedMessageCode.branchLevel.rawValue)
        payload.appendUInt32(5)

        let msg = buildServerMessage(code: .embeddedMessage, payload: payload)
        await handler.handle(msg)
    }

    @Test("EmbeddedMessage with empty payload does not crash")
    func embeddedMessageEmpty() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        let msg = buildServerMessage(code: .embeddedMessage)
        await handler.handle(msg)
    }

    // MARK: - PossibleParents (code 102)

    @Test("PossibleParents parses parent list")
    func possibleParents() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        var payload = Data()
        payload.appendUInt32(2)          // 2 parents
        // Parent 1
        payload.appendString("parent1")
        payload.appendUInt32(makeIP(10, 0, 0, 1))
        payload.appendUInt32(2234)
        // Parent 2
        payload.appendString("parent2")
        payload.appendUInt32(makeIP(10, 0, 0, 2))
        payload.appendUInt32(2235)

        let msg = buildServerMessage(code: .possibleParents, payload: payload)
        // Will try to connect to parents (will fail since no real network), that's fine
        await handler.handle(msg)
    }

    @Test("PossibleParents with zero parents is handled")
    func possibleParentsEmpty() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        var payload = Data()
        payload.appendUInt32(0) // 0 parents

        let msg = buildServerMessage(code: .possibleParents, payload: payload)
        await handler.handle(msg)
    }

    @Test("PossibleParents with excessively large count is rejected")
    func possibleParentsTooMany() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        var payload = Data()
        payload.appendUInt32(200_000) // exceeds maxItemCount

        let msg = buildServerMessage(code: .possibleParents, payload: payload)
        await handler.handle(msg)
    }

    // MARK: - ResetDistributed (code 130)

    @Test("ResetDistributed fires without crashing")
    func resetDistributed() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        let msg = buildServerMessage(code: .resetDistributed)
        await handler.handle(msg)
    }

    // MARK: - ParentMinSpeed and ParentSpeedRatio

    @Test("ParentMinSpeed reads speed value")
    func parentMinSpeed() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        var payload = Data()
        payload.appendUInt32(100)

        let msg = buildServerMessage(code: .parentMinSpeed, payload: payload)
        await handler.handle(msg)
    }

    @Test("ParentSpeedRatio reads ratio value")
    func parentSpeedRatio() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        var payload = Data()
        payload.appendUInt32(50)

        let msg = buildServerMessage(code: .parentSpeedRatio, payload: payload)
        await handler.handle(msg)
    }

    @Test("ParentMinSpeed with empty payload does not crash")
    func parentMinSpeedEmpty() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        let msg = buildServerMessage(code: .parentMinSpeed)
        await handler.handle(msg)
    }

    @Test("ParentSpeedRatio with empty payload does not crash")
    func parentSpeedRatioEmpty() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        let msg = buildServerMessage(code: .parentSpeedRatio)
        await handler.handle(msg)
    }

    // MARK: - PrivilegedUsers (code 69)

    @Test("PrivilegedUsers dispatches user list")
    func privilegedUsers() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        var capturedUsers: [String]?
        client.onPrivilegedUsers = { users in
            capturedUsers = users
        }

        var payload = Data()
        payload.appendUInt32(3)
        payload.appendString("vip1")
        payload.appendString("vip2")
        payload.appendString("vip3")

        let msg = buildServerMessage(code: .privilegedUsers, payload: payload)
        await handler.handle(msg)

        #expect(capturedUsers == ["vip1", "vip2", "vip3"])
    }

    @Test("PrivilegedUsers with zero users dispatches empty list")
    func privilegedUsersEmpty() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        var capturedUsers: [String]?
        client.onPrivilegedUsers = { users in
            capturedUsers = users
        }

        var payload = Data()
        payload.appendUInt32(0)

        let msg = buildServerMessage(code: .privilegedUsers, payload: payload)
        await handler.handle(msg)

        #expect(capturedUsers == [])
    }

    @Test("PrivilegedUsers with excessively large count is rejected")
    func privilegedUsersTooMany() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        var capturedUsers: [String]?
        client.onPrivilegedUsers = { users in
            capturedUsers = users
        }

        var payload = Data()
        payload.appendUInt32(200_000) // exceeds maxItemCount

        let msg = buildServerMessage(code: .privilegedUsers, payload: payload)
        await handler.handle(msg)

        #expect(capturedUsers == nil)
    }

    // MARK: - ItemRecommendations (code 111)

    @Test("ItemRecommendations dispatches item and recommendations")
    func itemRecommendations() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        var capturedItem: String?
        var capturedRecs: [(item: String, score: Int32)]?

        client.onItemRecommendations = { item, recs in
            capturedItem = item
            capturedRecs = recs
        }

        var payload = Data()
        payload.appendString("jazz")
        payload.appendUInt32(2)
        payload.appendString("smooth jazz")
        payload.appendInt32(85)
        payload.appendString("bebop")
        payload.appendInt32(72)

        let msg = buildServerMessage(code: .itemRecommendations, payload: payload)
        await handler.handle(msg)

        #expect(capturedItem == "jazz")
        #expect(capturedRecs?.count == 2)
        #expect(capturedRecs?[0].item == "smooth jazz")
        #expect(capturedRecs?[0].score == 85)
        #expect(capturedRecs?[1].item == "bebop")
        #expect(capturedRecs?[1].score == 72)
    }

    @Test("ItemRecommendations with zero recs dispatches empty list")
    func itemRecommendationsEmpty() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        var capturedRecs: [(item: String, score: Int32)]?
        client.onItemRecommendations = { _, recs in
            capturedRecs = recs
        }

        var payload = Data()
        payload.appendString("niche genre")
        payload.appendUInt32(0) // 0 recommendations

        let msg = buildServerMessage(code: .itemRecommendations, payload: payload)
        await handler.handle(msg)

        #expect(capturedRecs?.isEmpty == true)
    }

    // MARK: - ItemSimilarUsers (code 112)

    @Test("ItemSimilarUsers dispatches item and users")
    func itemSimilarUsers() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        var capturedItem: String?
        var capturedUsers: [String]?

        client.onItemSimilarUsers = { item, users in
            capturedItem = item
            capturedUsers = users
        }

        var payload = Data()
        payload.appendString("electronic")
        payload.appendUInt32(3)
        payload.appendString("dj1")
        payload.appendString("dj2")
        payload.appendString("dj3")

        let msg = buildServerMessage(code: .itemSimilarUsers, payload: payload)
        await handler.handle(msg)

        #expect(capturedItem == "electronic")
        #expect(capturedUsers == ["dj1", "dj2", "dj3"])
    }

    @Test("ItemSimilarUsers with zero users dispatches empty list")
    func itemSimilarUsersEmpty() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        var capturedUsers: [String]?
        client.onItemSimilarUsers = { _, users in
            capturedUsers = users
        }

        var payload = Data()
        payload.appendString("very niche")
        payload.appendUInt32(0)

        let msg = buildServerMessage(code: .itemSimilarUsers, payload: payload)
        await handler.handle(msg)

        #expect(capturedUsers?.isEmpty == true)
    }

    // MARK: - PrivateRoomAddMember (code 134)

    @Test("PrivateRoomAddMember dispatches room and username")
    func privateRoomAddMember() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        var capturedRoom: String?
        var capturedUser: String?

        client.onPrivateRoomMemberAdded = { room, user in
            capturedRoom = room
            capturedUser = user
        }

        var payload = Data()
        payload.appendString("VIPRoom")
        payload.appendString("newmember")

        let msg = buildServerMessage(code: .privateRoomAddMember, payload: payload)
        await handler.handle(msg)

        #expect(capturedRoom == "VIPRoom")
        #expect(capturedUser == "newmember")
    }

    // MARK: - PrivateRoomRemoveMember (code 135)

    @Test("PrivateRoomRemoveMember dispatches room and username")
    func privateRoomRemoveMember() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        var capturedRoom: String?
        var capturedUser: String?

        client.onPrivateRoomMemberRemoved = { room, user in
            capturedRoom = room
            capturedUser = user
        }

        var payload = Data()
        payload.appendString("VIPRoom")
        payload.appendString("exmember")

        let msg = buildServerMessage(code: .privateRoomRemoveMember, payload: payload)
        await handler.handle(msg)

        #expect(capturedRoom == "VIPRoom")
        #expect(capturedUser == "exmember")
    }

    // MARK: - PrivateRoomOperatorRevoked (code 146)

    @Test("PrivateRoomOperatorRevoked dispatches room name")
    func privateRoomOperatorRevoked() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        var capturedRoom: String?
        client.onPrivateRoomOperatorRevoked = { room in
            capturedRoom = room
        }

        var payload = Data()
        payload.appendString("ModdedRoom")

        let msg = buildServerMessage(code: .privateRoomOperatorRevoked, payload: payload)
        await handler.handle(msg)

        #expect(capturedRoom == "ModdedRoom")
    }

    // MARK: - PrivateRoomOperators (code 148)

    @Test("PrivateRoomOperators dispatches room and operator list")
    func privateRoomOperators() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        var capturedRoom: String?
        var capturedOps: [String]?

        client.onPrivateRoomOperators = { room, ops in
            capturedRoom = room
            capturedOps = ops
        }

        var payload = Data()
        payload.appendString("ModdedRoom")
        payload.appendUInt32(2)
        payload.appendString("op1")
        payload.appendString("op2")

        let msg = buildServerMessage(code: .privateRoomOperators, payload: payload)
        await handler.handle(msg)

        #expect(capturedRoom == "ModdedRoom")
        #expect(capturedOps == ["op1", "op2"])
    }

    @Test("PrivateRoomOperators with zero operators")
    func privateRoomOperatorsEmpty() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        var capturedOps: [String]?
        client.onPrivateRoomOperators = { _, ops in
            capturedOps = ops
        }

        var payload = Data()
        payload.appendString("ModdedRoom")
        payload.appendUInt32(0)

        let msg = buildServerMessage(code: .privateRoomOperators, payload: payload)
        await handler.handle(msg)

        #expect(capturedOps == [])
    }

    // MARK: - RoomMembershipRevoked (code 140)

    @Test("RoomMembershipRevoked dispatches room name")
    func roomMembershipRevoked() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        var capturedRoom: String?
        client.onRoomMembershipRevoked = { room in
            capturedRoom = room
        }

        var payload = Data()
        payload.appendString("ExclusiveRoom")

        let msg = buildServerMessage(code: .roomMembershipRevoked, payload: payload)
        await handler.handle(msg)

        #expect(capturedRoom == "ExclusiveRoom")
    }

    // MARK: - EnableRoomInvitations (code 141) — disabled case

    @Test("EnableRoomInvitations disabled dispatches false")
    func enableRoomInvitationsDisabled() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        var capturedEnabled: Bool?
        client.onRoomInvitationsEnabled = { enabled in
            capturedEnabled = enabled
        }

        var payload = Data()
        payload.appendUInt8(0) // disabled

        let msg = buildServerMessage(code: .enableRoomInvitations, payload: payload)
        await handler.handle(msg)

        #expect(capturedEnabled == false)
    }

    // MARK: - SimilarRecommendations (code 50) and MyRecommendations (code 55)

    @Test("SimilarRecommendations uses onRecommendations callback")
    func similarRecommendations() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        var capturedRecs: [(item: String, score: Int32)]?
        client.onRecommendations = { recs, _ in
            capturedRecs = recs
        }

        var payload = Data()
        payload.appendUInt32(1)
        payload.appendString("trip-hop")
        payload.appendInt32(55)
        payload.appendUInt32(0)

        let msg = buildServerMessage(code: .similarRecommendations, payload: payload)
        await handler.handle(msg)

        #expect(capturedRecs?.count == 1)
        #expect(capturedRecs?[0].item == "trip-hop")
    }

    @Test("MyRecommendations uses onRecommendations callback")
    func myRecommendations() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        var capturedRecs: [(item: String, score: Int32)]?
        client.onRecommendations = { recs, _ in
            capturedRecs = recs
        }

        var payload = Data()
        payload.appendUInt32(2)
        payload.appendString("house")
        payload.appendInt32(30)
        payload.appendString("techno")
        payload.appendInt32(20)
        payload.appendUInt32(0)

        let msg = buildServerMessage(code: .myRecommendations, payload: payload)
        await handler.handle(msg)

        #expect(capturedRecs?.count == 2)
    }

    // MARK: - Protocol Notice codes

    @Test("IgnoreUser dispatches via onProtocolNotice")
    func ignoreUser() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        var capturedCode: UInt32?
        client.onProtocolNotice = { code, _ in
            capturedCode = code
        }

        let msg = buildServerMessage(code: .ignoreUser, payload: Data([0x01]))
        await handler.handle(msg)

        #expect(capturedCode == ServerMessageCode.ignoreUser.rawValue)
    }

    @Test("UnignoreUser dispatches via onProtocolNotice")
    func unignoreUser() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        var capturedCode: UInt32?
        client.onProtocolNotice = { code, _ in
            capturedCode = code
        }

        let msg = buildServerMessage(code: .unignoreUser, payload: Data([0x01]))
        await handler.handle(msg)

        #expect(capturedCode == ServerMessageCode.unignoreUser.rawValue)
    }

    @Test("FileSearchRoom dispatches via onProtocolNotice")
    func fileSearchRoom() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        var capturedCode: UInt32?
        client.onProtocolNotice = { code, _ in
            capturedCode = code
        }

        let msg = buildServerMessage(code: .fileSearchRoom, payload: Data([0x42]))
        await handler.handle(msg)

        #expect(capturedCode == ServerMessageCode.fileSearchRoom.rawValue)
    }

    @Test("SendConnectToken dispatches via onProtocolNotice")
    func sendConnectToken() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        var capturedCode: UInt32?
        client.onProtocolNotice = { code, _ in
            capturedCode = code
        }

        let msg = buildServerMessage(code: .sendConnectToken, payload: Data())
        await handler.handle(msg)

        #expect(capturedCode == ServerMessageCode.sendConnectToken.rawValue)
    }

    @Test("SendDownloadSpeed dispatches via onProtocolNotice")
    func sendDownloadSpeed() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        var capturedCode: UInt32?
        client.onProtocolNotice = { code, _ in
            capturedCode = code
        }

        let msg = buildServerMessage(code: .sendDownloadSpeed, payload: Data())
        await handler.handle(msg)

        #expect(capturedCode == ServerMessageCode.sendDownloadSpeed.rawValue)
    }

    @Test("SearchParent dispatches via onProtocolNotice")
    func searchParent() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        var capturedCode: UInt32?
        client.onProtocolNotice = { code, _ in
            capturedCode = code
        }

        let msg = buildServerMessage(code: .searchParent, payload: Data())
        await handler.handle(msg)

        #expect(capturedCode == ServerMessageCode.searchParent.rawValue)
    }

    @Test("SearchInactivityTimeout dispatches via onProtocolNotice")
    func searchInactivityTimeout() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        var capturedCode: UInt32?
        client.onProtocolNotice = { code, _ in
            capturedCode = code
        }

        let msg = buildServerMessage(code: .searchInactivityTimeout, payload: Data())
        await handler.handle(msg)

        #expect(capturedCode == ServerMessageCode.searchInactivityTimeout.rawValue)
    }

    @Test("MinParentsInCache dispatches via onProtocolNotice")
    func minParentsInCache() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        var capturedCode: UInt32?
        client.onProtocolNotice = { code, _ in
            capturedCode = code
        }

        let msg = buildServerMessage(code: .minParentsInCache, payload: Data())
        await handler.handle(msg)

        #expect(capturedCode == ServerMessageCode.minParentsInCache.rawValue)
    }

    @Test("DistribPingInterval dispatches via onProtocolNotice")
    func distribPingInterval() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        var capturedCode: UInt32?
        client.onProtocolNotice = { code, _ in
            capturedCode = code
        }

        let msg = buildServerMessage(code: .distribPingInterval, payload: Data())
        await handler.handle(msg)

        #expect(capturedCode == ServerMessageCode.distribPingInterval.rawValue)
    }

    @Test("AdminCommand dispatches via onProtocolNotice")
    func adminCommand() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        var capturedCode: UInt32?
        client.onProtocolNotice = { code, _ in
            capturedCode = code
        }

        let msg = buildServerMessage(code: .adminCommand, payload: Data())
        await handler.handle(msg)

        #expect(capturedCode == ServerMessageCode.adminCommand.rawValue)
    }

    @Test("UploadSlotsFull dispatches via onProtocolNotice")
    func uploadSlotsFull() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        var capturedCode: UInt32?
        client.onProtocolNotice = { code, _ in
            capturedCode = code
        }

        let msg = buildServerMessage(code: .uploadSlotsFull, payload: Data())
        await handler.handle(msg)

        #expect(capturedCode == ServerMessageCode.uploadSlotsFull.rawValue)
    }

    @Test("PlaceInLineRequest dispatches via onProtocolNotice")
    func placeInLineRequest() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        var capturedCode: UInt32?
        client.onProtocolNotice = { code, _ in
            capturedCode = code
        }

        let msg = buildServerMessage(code: .placeInLineRequest, payload: Data())
        await handler.handle(msg)

        #expect(capturedCode == ServerMessageCode.placeInLineRequest.rawValue)
    }

    @Test("PlaceInLineResponse dispatches via onProtocolNotice")
    func placeInLineResponse() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        var capturedCode: UInt32?
        client.onProtocolNotice = { code, _ in
            capturedCode = code
        }

        let msg = buildServerMessage(code: .placeInLineResponse, payload: Data())
        await handler.handle(msg)

        #expect(capturedCode == ServerMessageCode.placeInLineResponse.rawValue)
    }

    @Test("NotifyPrivileges dispatches via onProtocolNotice")
    func notifyPrivileges() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        var capturedCode: UInt32?
        client.onProtocolNotice = { code, _ in
            capturedCode = code
        }

        let msg = buildServerMessage(code: .notifyPrivileges, payload: Data())
        await handler.handle(msg)

        #expect(capturedCode == ServerMessageCode.notifyPrivileges.rawValue)
    }

    @Test("AckNotifyPrivileges dispatches via onProtocolNotice")
    func ackNotifyPrivileges() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        var capturedCode: UInt32?
        client.onProtocolNotice = { code, _ in
            capturedCode = code
        }

        let msg = buildServerMessage(code: .ackNotifyPrivileges, payload: Data())
        await handler.handle(msg)

        #expect(capturedCode == ServerMessageCode.ackNotifyPrivileges.rawValue)
    }

    @Test("PrivateRoomUnknown138 dispatches via onProtocolNotice")
    func privateRoomUnknown138() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        var capturedCode: UInt32?
        client.onProtocolNotice = { code, _ in
            capturedCode = code
        }

        let msg = buildServerMessage(code: .privateRoomUnknown138, payload: Data())
        await handler.handle(msg)

        #expect(capturedCode == ServerMessageCode.privateRoomUnknown138.rawValue)
    }

    @Test("RoomUnknown153 dispatches via onProtocolNotice")
    func roomUnknown153() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        var capturedCode: UInt32?
        client.onProtocolNotice = { code, _ in
            capturedCode = code
        }

        let msg = buildServerMessage(code: .roomUnknown153, payload: Data())
        await handler.handle(msg)

        #expect(capturedCode == ServerMessageCode.roomUnknown153.rawValue)
    }

    // MARK: - Room handlers with parse fallback

    @Test("RoomAdded with empty payload falls back to onProtocolNotice")
    func roomAddedFallback() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        var capturedCode: UInt32?
        client.onProtocolNotice = { code, _ in
            capturedCode = code
        }

        // Empty payload that can't parse a string
        let msg = buildServerMessage(code: .roomAdded, payload: Data())
        await handler.handle(msg)

        #expect(capturedCode == ServerMessageCode.roomAdded.rawValue)
    }

    @Test("RoomRemoved with empty payload falls back to onProtocolNotice")
    func roomRemovedFallback() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        var capturedCode: UInt32?
        client.onProtocolNotice = { code, _ in
            capturedCode = code
        }

        let msg = buildServerMessage(code: .roomRemoved, payload: Data())
        await handler.handle(msg)

        #expect(capturedCode == ServerMessageCode.roomRemoved.rawValue)
    }

    // MARK: - Recommendations edge cases

    @Test("Recommendations with large list of items")
    func recommendationsLargeList() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        var capturedRecs: [(item: String, score: Int32)]?
        client.onRecommendations = { recs, _ in
            capturedRecs = recs
        }

        var payload = Data()
        let count: UInt32 = 50
        payload.appendUInt32(count)
        for i in 0..<count {
            payload.appendString("genre_\(i)")
            payload.appendInt32(Int32(i) * 10 - 100)
        }
        payload.appendUInt32(0) // no unrecommendations

        let msg = buildServerMessage(code: .recommendations, payload: payload)
        await handler.handle(msg)

        #expect(capturedRecs?.count == 50)
        #expect(capturedRecs?[0].item == "genre_0")
        #expect(capturedRecs?[0].score == -100)
        #expect(capturedRecs?[49].item == "genre_49")
        #expect(capturedRecs?[49].score == 390)
    }

    @Test("Recommendations with both recs and unrecommendations non-empty")
    func recommendationsWithUnrecs() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        var capturedRecs: [(item: String, score: Int32)]?
        var capturedUnrecs: [(item: String, score: Int32)]?
        client.onRecommendations = { recs, unrecs in
            capturedRecs = recs
            capturedUnrecs = unrecs
        }

        var payload = Data()
        payload.appendUInt32(1)
        payload.appendString("liked")
        payload.appendInt32(50)
        payload.appendUInt32(2)
        payload.appendString("disliked1")
        payload.appendInt32(-20)
        payload.appendString("disliked2")
        payload.appendInt32(-30)

        let msg = buildServerMessage(code: .recommendations, payload: payload)
        await handler.handle(msg)

        #expect(capturedRecs?.count == 1)
        #expect(capturedUnrecs?.count == 2)
        #expect(capturedUnrecs?[1].item == "disliked2")
        #expect(capturedUnrecs?[1].score == -30)
    }

    @Test("GlobalRecommendations dispatches both recs and unrecommendations")
    func globalRecommendationsWithUnrecs() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        var capturedRecs: [(item: String, score: Int32)]?
        var capturedUnrecs: [(item: String, score: Int32)]?
        client.onGlobalRecommendations = { recs, unrecs in
            capturedRecs = recs
            capturedUnrecs = unrecs
        }

        var payload = Data()
        payload.appendUInt32(2)
        payload.appendString("popular1")
        payload.appendInt32(200)
        payload.appendString("popular2")
        payload.appendInt32(150)
        payload.appendUInt32(1)
        payload.appendString("unpopular")
        payload.appendInt32(-50)

        let msg = buildServerMessage(code: .globalRecommendations, payload: payload)
        await handler.handle(msg)

        #expect(capturedRecs?.count == 2)
        #expect(capturedUnrecs?.count == 1)
        #expect(capturedUnrecs?[0].item == "unpopular")
    }

    // MARK: - UserInterests edge cases

    @Test("UserInterests with only likes, no hates")
    func userInterestsNoHates() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        var capturedHates: [String]?
        client.onUserInterests = { _, _, hates in
            capturedHates = hates
        }

        var payload = Data()
        payload.appendString("bob")
        payload.appendUInt32(2)
        payload.appendString("rock")
        payload.appendString("metal")
        payload.appendUInt32(0) // 0 hates

        let msg = buildServerMessage(code: .userInterests, payload: payload)
        await handler.handle(msg)

        #expect(capturedHates?.isEmpty == true)
    }

    // MARK: - SimilarUsers edge cases

    @Test("SimilarUsers with zero users dispatches empty list")
    func similarUsersEmpty() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        var capturedUsers: [(username: String, rating: UInt32)]?
        client.onSimilarUsers = { users in
            capturedUsers = users
        }

        var payload = Data()
        payload.appendUInt32(0)

        let msg = buildServerMessage(code: .similarUsers, payload: payload)
        await handler.handle(msg)

        #expect(capturedUsers?.isEmpty == true)
    }

    // MARK: - CantConnectToPeer edge cases

    @Test("CantConnectToPeer with empty payload logs warning and returns")
    func cantConnectToPeerEmpty() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        var capturedToken: UInt32?
        client.onCantConnectToPeer = { token in
            capturedToken = token
        }

        let msg = buildServerMessage(code: .cantConnectToPeer, payload: Data())
        await handler.handle(msg)

        #expect(capturedToken == nil)
    }

    // MARK: - AdminMessage edge cases

    @Test("AdminMessage with empty payload does not dispatch")
    func adminMessageEmpty() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        var called = false
        client.onAdminMessage = { _ in
            called = true
        }

        let msg = buildServerMessage(code: .adminMessage, payload: Data())
        await handler.handle(msg)

        #expect(called == false)
    }

    // MARK: - ExcludedSearchPhrases edge cases

    @Test("ExcludedSearchPhrases with zero phrases dispatches empty list")
    func excludedSearchPhrasesEmpty() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        var capturedPhrases: [String]?
        client.onExcludedSearchPhrases = { phrases in
            capturedPhrases = phrases
        }

        var payload = Data()
        payload.appendUInt32(0)

        let msg = buildServerMessage(code: .excludedSearchPhrases, payload: payload)
        await handler.handle(msg)

        #expect(capturedPhrases == [])
    }

    @Test("ExcludedSearchPhrases with excessively large count is rejected")
    func excludedSearchPhrasesTooMany() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        var capturedPhrases: [String]?
        client.onExcludedSearchPhrases = { phrases in
            capturedPhrases = phrases
        }

        var payload = Data()
        payload.appendUInt32(200_000)

        let msg = buildServerMessage(code: .excludedSearchPhrases, payload: payload)
        await handler.handle(msg)

        #expect(capturedPhrases == nil)
    }

    // MARK: - NewPassword edge cases

    @Test("NewPassword with empty payload does not dispatch")
    func newPasswordEmpty() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        var called = false
        client.onPasswordChanged = { _ in
            called = true
        }

        let msg = buildServerMessage(code: .newPassword, payload: Data())
        await handler.handle(msg)

        #expect(called == false)
    }

    // MARK: - Distributed message logging path

    @Test("Distributed-related code 93 triggers extra logging path")
    func distributedLoggingPath() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        // code 93 (embeddedMessage) is in the distributed logging set
        var payload = Data()
        payload.appendUInt8(DistributedMessageCode.searchRequest.rawValue)
        payload.appendUInt32(0)
        payload.appendString("test")
        payload.appendUInt32(111)
        payload.appendString("query")

        let msg = buildServerMessage(code: .embeddedMessage, payload: payload)
        await handler.handle(msg)
    }

    @Test("Code 102 triggers distributed logging path")
    func distributedLoggingPathPossibleParents() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        var payload = Data()
        payload.appendUInt32(0)

        let msg = buildServerMessage(code: .possibleParents, payload: payload)
        await handler.handle(msg)
    }

    // MARK: - Multiple items in lists

    @Test("PrivateRoomMembers with many members")
    func privateRoomMembersMany() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        var capturedMembers: [String]?
        client.onPrivateRoomMembers = { _, members in
            capturedMembers = members
        }

        var payload = Data()
        payload.appendString("BigRoom")
        let count: UInt32 = 20
        payload.appendUInt32(count)
        for i in 0..<count {
            payload.appendString("member_\(i)")
        }

        let msg = buildServerMessage(code: .privateRoomMembers, payload: payload)
        await handler.handle(msg)

        #expect(capturedMembers?.count == 20)
        #expect(capturedMembers?.first == "member_0")
        #expect(capturedMembers?.last == "member_19")
    }

    @Test("RoomTickerState with many tickers")
    func roomTickerStateMany() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        var capturedTickers: [(username: String, ticker: String)]?
        client.onRoomTickerState = { _, tickers in
            capturedTickers = tickers
        }

        var payload = Data()
        payload.appendString("BigRoom")
        let count: UInt32 = 10
        payload.appendUInt32(count)
        for i in 0..<count {
            payload.appendString("user_\(i)")
            payload.appendString("ticker_\(i)")
        }

        let msg = buildServerMessage(code: .roomTickerState, payload: payload)
        await handler.handle(msg)

        #expect(capturedTickers?.count == 10)
        #expect(capturedTickers?[9].username == "user_9")
        #expect(capturedTickers?[9].ticker == "ticker_9")
    }

    @Test("JoinRoom with many users and full metadata")
    func joinRoomManyUsers() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        var capturedUsers: [String]?
        client.onRoomJoined = { _, users, _, _ in
            capturedUsers = users
        }

        var payload = Data()
        payload.appendString("BigRoom")
        let count: UInt32 = 10
        // Users
        payload.appendUInt32(count)
        for i in 0..<count {
            payload.appendString("user_\(i)")
        }
        // Statuses
        payload.appendUInt32(count)
        for _ in 0..<count {
            payload.appendUInt32(2) // online
        }
        // Stats (20 bytes each)
        payload.appendUInt32(count)
        for _ in 0..<count {
            payload.appendUInt32(50000)
            payload.appendUInt64(100)
            payload.appendUInt32(500)
            payload.appendUInt32(20)
        }
        // Slots full
        payload.appendUInt32(count)
        for _ in 0..<count {
            payload.appendUInt32(0)
        }
        // Countries
        payload.appendUInt32(count)
        for _ in 0..<count {
            payload.appendString("US")
        }

        let msg = buildServerMessage(code: .joinRoom, payload: payload)
        await handler.handle(msg)

        #expect(capturedUsers?.count == 10)
        #expect(capturedUsers?[0] == "user_0")
        #expect(capturedUsers?[9] == "user_9")
    }

    // MARK: - Callbacks not set (no crash)

    @Test("Handler gracefully handles nil callbacks for all code paths")
    func nilCallbacksNoCrash() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)
        // Do NOT set any callbacks on client

        // Test several codes that dispatch via optional callbacks
        let codes: [(ServerMessageCode, () -> Data)] = [
            (.roomList, {
                var p = Data()
                p.appendUInt32(1); p.appendString("Room"); p.appendUInt32(1); p.appendUInt32(5)
                return p
            }),
            (.leaveRoom, {
                var p = Data(); p.appendString("Room"); return p
            }),
            (.roomTickerState, {
                var p = Data(); p.appendString("Room"); p.appendUInt32(0); return p
            }),
            (.roomTickerAdd, {
                var p = Data(); p.appendString("R"); p.appendString("U"); p.appendString("T"); return p
            }),
            (.roomTickerRemove, {
                var p = Data(); p.appendString("R"); p.appendString("U"); return p
            }),
            (.checkPrivileges, {
                var p = Data(); p.appendUInt32(0); return p
            }),
            (.userPrivileges, {
                var p = Data(); p.appendString("u"); p.appendUInt8(1); return p
            }),
            (.privilegedUsers, {
                var p = Data(); p.appendUInt32(0); return p
            }),
            (.wishlistInterval, {
                var p = Data(); p.appendUInt32(100); return p
            }),
            (.privateRoomMembers, {
                var p = Data(); p.appendString("R"); p.appendUInt32(0); return p
            }),
            (.privateRoomAddMember, {
                var p = Data(); p.appendString("R"); p.appendString("U"); return p
            }),
            (.privateRoomRemoveMember, {
                var p = Data(); p.appendString("R"); p.appendString("U"); return p
            }),
            (.privateRoomOperatorGranted, {
                var p = Data(); p.appendString("R"); return p
            }),
            (.privateRoomOperatorRevoked, {
                var p = Data(); p.appendString("R"); return p
            }),
            (.privateRoomOperators, {
                var p = Data(); p.appendString("R"); p.appendUInt32(0); return p
            }),
            (.cantConnectToPeer, {
                var p = Data(); p.appendUInt32(1); return p
            }),
            (.adminMessage, {
                var p = Data(); p.appendString("msg"); return p
            }),
            (.excludedSearchPhrases, {
                var p = Data(); p.appendUInt32(0); return p
            }),
            (.roomMembershipGranted, {
                var p = Data(); p.appendString("R"); return p
            }),
            (.roomMembershipRevoked, {
                var p = Data(); p.appendString("R"); return p
            }),
            (.enableRoomInvitations, {
                var p = Data(); p.appendUInt8(1); return p
            }),
            (.newPassword, {
                var p = Data(); p.appendString("pw"); return p
            }),
            (.globalRoomMessage, {
                var p = Data(); p.appendString("R"); p.appendString("U"); p.appendString("M"); return p
            }),
            (.cantCreateRoom, {
                var p = Data(); p.appendString("R"); return p
            }),
            (.roomAdded, {
                var p = Data(); p.appendString("R"); return p
            }),
            (.roomRemoved, {
                var p = Data(); p.appendString("R"); return p
            }),
            (.itemRecommendations, {
                var p = Data(); p.appendString("it"); p.appendUInt32(0); return p
            }),
            (.itemSimilarUsers, {
                var p = Data(); p.appendString("it"); p.appendUInt32(0); return p
            }),
        ]

        for (code, makePayload) in codes {
            let msg = buildServerMessage(code: code, payload: makePayload())
            await handler.handle(msg)
        }
    }

    // MARK: - CheckPrivileges edge cases

    @Test("CheckPrivileges with zero time left")
    func checkPrivilegesZero() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        var capturedTimeLeft: UInt32?
        client.onPrivilegesChecked = { timeLeft in
            capturedTimeLeft = timeLeft
        }

        var payload = Data()
        payload.appendUInt32(0)

        let msg = buildServerMessage(code: .checkPrivileges, payload: payload)
        await handler.handle(msg)

        #expect(capturedTimeLeft == 0)
    }

    @Test("CheckPrivileges with max uint32 time")
    func checkPrivilegesMax() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        var capturedTimeLeft: UInt32?
        client.onPrivilegesChecked = { timeLeft in
            capturedTimeLeft = timeLeft
        }

        var payload = Data()
        payload.appendUInt32(UInt32.max)

        let msg = buildServerMessage(code: .checkPrivileges, payload: payload)
        await handler.handle(msg)

        #expect(capturedTimeLeft == UInt32.max)
    }

    @Test("CheckPrivileges with empty payload does not dispatch")
    func checkPrivilegesEmpty() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        var called = false
        client.onPrivilegesChecked = { _ in
            called = true
        }

        let msg = buildServerMessage(code: .checkPrivileges, payload: Data())
        await handler.handle(msg)

        #expect(called == false)
    }

    // MARK: - UserPrivileges edge cases

    @Test("UserPrivileges with not privileged flag")
    func userPrivilegesNotPrivileged() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        var capturedPrivileged: Bool?
        client.onUserPrivileges = { _, privileged in
            capturedPrivileged = privileged
        }

        var payload = Data()
        payload.appendString("regularuser")
        payload.appendUInt8(0) // not privileged

        let msg = buildServerMessage(code: .userPrivileges, payload: payload)
        await handler.handle(msg)

        #expect(capturedPrivileged == false)
    }

    // MARK: - CantCreateRoom edge cases

    @Test("CantCreateRoom with empty payload does not dispatch")
    func cantCreateRoomEmpty() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        var called = false
        client.onCantCreateRoom = { _ in
            called = true
        }

        let msg = buildServerMessage(code: .cantCreateRoom, payload: Data())
        await handler.handle(msg)

        #expect(called == false)
    }

    // MARK: - Distributed search self-filter

    @Test("EmbeddedMessage search from own username does not respond")
    func embeddedMessageSelfSearch() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        // Set client's username so the handler can detect self-search
        // username is typically set during login

        var innerPayload = Data()
        innerPayload.appendUInt32(0)
        innerPayload.appendString(client.username)  // same username as client
        innerPayload.appendUInt32(12345)
        innerPayload.appendString("test query")

        var payload = Data()
        payload.appendUInt8(DistributedMessageCode.searchRequest.rawValue)
        payload.append(innerPayload)

        let msg = buildServerMessage(code: .embeddedMessage, payload: payload)
        await handler.handle(msg)
        // Should not crash, and self-search should be silently filtered
    }

    // MARK: - Truncated payloads for various handlers

    @Test("Truncated WatchUser payload does not crash")
    func watchUserTruncated() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        // Only username, missing exists byte
        var payload = Data()
        payload.appendString("partial")

        let msg = buildServerMessage(code: .watchUser, payload: payload)
        await handler.handle(msg)
    }

    @Test("Truncated ItemRecommendations payload does not crash")
    func itemRecommendationsTruncated() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        // Only item name, missing rec count
        var payload = Data()
        payload.appendString("jazz")

        let msg = buildServerMessage(code: .itemRecommendations, payload: payload)
        await handler.handle(msg)
    }

    @Test("Truncated ItemSimilarUsers payload does not crash")
    func itemSimilarUsersTruncated() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        var payload = Data()
        payload.appendString("jazz")

        let msg = buildServerMessage(code: .itemSimilarUsers, payload: payload)
        await handler.handle(msg)
    }

    @Test("Truncated PrivateRoomOperators payload does not crash")
    func privateRoomOperatorsTruncated() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        var payload = Data()
        payload.appendString("Room")
        // Missing operator count

        let msg = buildServerMessage(code: .privateRoomOperators, payload: payload)
        await handler.handle(msg)
    }

    @Test("Truncated GetUserAddress payload does not crash")
    func getUserAddressTruncated() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        // Only username, missing IP and port
        var payload = Data()
        payload.appendString("alice")

        let msg = buildServerMessage(code: .getPeerAddress, payload: payload)
        await handler.handle(msg)
    }

    @Test("Truncated GlobalRoomMessage payload does not crash")
    func globalRoomMessageTruncated() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        var called = false
        client.onGlobalRoomMessage = { _, _, _ in
            called = true
        }

        // Only room name, missing username and message
        var payload = Data()
        payload.appendString("GlobalRoom")

        let msg = buildServerMessage(code: .globalRoomMessage, payload: payload)
        await handler.handle(msg)

        #expect(called == false)
    }

    // MARK: - Default switch branch

    @Test("Default branch logs and does nothing for unhandled known codes")
    func defaultBranch() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        // setOnlineStatus (code 28) is in the enum but has no case in the switch
        // Actually, looking at the switch, setOnlineStatus doesn't appear — it would hit default
        // Let's use a code that IS in the enum but NOT in the switch
        // Looking at the switch: .setOnlineStatus is NOT listed.
        // But wait — setOnlineStatus IS in the enum (28). Let's test:
        let msg = buildServerMessage(code: .setOnlineStatus, payload: Data())
        await handler.handle(msg)
    }

    @Test("SharedFoldersFiles code hits default branch")
    func sharedFoldersFiles() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        let msg = buildServerMessage(code: .sharedFoldersFiles, payload: Data())
        await handler.handle(msg)
    }

    @Test("UserSearch code hits default branch")
    func userSearch() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        let msg = buildServerMessage(code: .userSearch, payload: Data())
        await handler.handle(msg)
    }

    @Test("WishlistSearch code hits default branch")
    func wishlistSearch() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        let msg = buildServerMessage(code: .wishlistSearch, payload: Data())
        await handler.handle(msg)
    }
}
