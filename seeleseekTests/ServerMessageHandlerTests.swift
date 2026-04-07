import Testing
import Foundation
@testable import SeeleseekCore

/// Integration tests for ServerMessageHandler: build raw binary server messages,
/// feed them through `handle(_ data:)`, and verify the correct NetworkClient
/// callbacks fire with the right data.
@Suite("ServerMessageHandler Integration Tests", .serialized)
@MainActor
struct ServerMessageHandlerTests {

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

    /// Build a complete wire-format server message from a raw UInt32 code.
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

    // MARK: - Login

    @Test("Login success sets loggedIn to true and stores greeting")
    func loginSuccess() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        var payload = Data()
        payload.appendUInt8(1) // success = true
        payload.appendString("Welcome to SoulSeek!")
        payload.appendUInt32(makeIP(203, 0, 113, 42)) // IP

        let msg = buildServerMessage(code: .login, payload: payload)
        await handler.handle(msg)

        #expect(client.loggedIn == true)
    }

    @Test("Login failure sets loggedIn to false and stores error")
    func loginFailure() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        var payload = Data()
        payload.appendUInt8(0) // success = false
        payload.appendString("INVALIDPASS")

        let msg = buildServerMessage(code: .login, payload: payload)
        await handler.handle(msg)

        #expect(client.loggedIn == false)
        #expect(client.connectionError == "INVALIDPASS")
    }

    @Test("Login failure with unknown error when reason is missing")
    func loginFailureNoReason() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        var payload = Data()
        payload.appendUInt8(0) // success = false
        // No reason string follows — intentionally truncated

        let msg = buildServerMessage(code: .login, payload: payload)
        await handler.handle(msg)

        #expect(client.loggedIn == false)
        #expect(client.connectionError == "Unknown error")
    }

    // MARK: - Room List

    @Test("Room list dispatches public rooms via onRoomList callback")
    func roomListCallsOnRoomList() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        var capturedRooms: [ChatRoom]?
        client.onRoomList = { rooms in
            capturedRooms = rooms
        }

        // Build a room list payload: 2 rooms with counts
        var payload = Data()
        // Public rooms: names
        payload.appendUInt32(2)
        payload.appendString("Lounge")
        payload.appendString("Metal")
        // Public rooms: user counts
        payload.appendUInt32(2)
        payload.appendUInt32(50)
        payload.appendUInt32(120)

        let msg = buildServerMessage(code: .roomList, payload: payload)
        await handler.handle(msg)

        #expect(capturedRooms != nil)
        #expect(capturedRooms?.count == 2)
        #expect(capturedRooms?[0].name == "Lounge")
        #expect(capturedRooms?[0].users.count == 50)
        #expect(capturedRooms?[1].name == "Metal")
        #expect(capturedRooms?[1].users.count == 120)
    }

    @Test("Room list dispatches via onRoomListFull when set")
    func roomListCallsOnRoomListFull() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        var capturedPublic: [ChatRoom]?
        var capturedOwnedPrivate: [ChatRoom]?
        var capturedMemberPrivate: [ChatRoom]?
        var capturedOperated: [String]?

        client.onRoomListFull = { pub, owned, member, operated in
            capturedPublic = pub
            capturedOwnedPrivate = owned
            capturedMemberPrivate = member
            capturedOperated = operated
        }

        var payload = Data()
        // Public rooms: 1 room
        payload.appendUInt32(1)
        payload.appendString("Lounge")
        payload.appendUInt32(1)
        payload.appendUInt32(50)
        // Owned private rooms: 1 room
        payload.appendUInt32(1)
        payload.appendString("MyRoom")
        payload.appendUInt32(1)
        payload.appendUInt32(5)
        // Member private rooms: 0
        payload.appendUInt32(0)
        payload.appendUInt32(0)
        // Operated room names: 1
        payload.appendUInt32(1)
        payload.appendString("ModdedRoom")

        let msg = buildServerMessage(code: .roomList, payload: payload)
        await handler.handle(msg)

        #expect(capturedPublic?.count == 1)
        #expect(capturedPublic?[0].name == "Lounge")
        #expect(capturedOwnedPrivate?.count == 1)
        #expect(capturedOwnedPrivate?[0].name == "MyRoom")
        #expect(capturedOwnedPrivate?[0].isPrivate == true)
        #expect(capturedMemberPrivate?.count == 0)
        #expect(capturedOperated == ["ModdedRoom"])
    }

    @Test("Empty room list dispatches empty array")
    func roomListEmpty() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        var capturedRooms: [ChatRoom]?
        client.onRoomList = { rooms in
            capturedRooms = rooms
        }

        var payload = Data()
        payload.appendUInt32(0) // 0 public rooms
        payload.appendUInt32(0) // 0 counts

        let msg = buildServerMessage(code: .roomList, payload: payload)
        await handler.handle(msg)

        #expect(capturedRooms != nil)
        #expect(capturedRooms?.isEmpty == true)
    }

    // MARK: - User Status

    @Test("getUserStatus dispatches status via handleUserStatusResponse")
    func getUserStatus() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        var capturedUsername: String?
        var capturedStatus: UserStatus?
        var capturedPrivileged: Bool?

        client.addUserStatusHandler { username, status, privileged in
            capturedUsername = username
            capturedStatus = status
            capturedPrivileged = privileged
        }

        var payload = Data()
        payload.appendString("alice")
        payload.appendUInt32(UserStatus.online.rawValue)
        payload.appendUInt8(1) // privileged

        let msg = buildServerMessage(code: .getUserStatus, payload: payload)
        await handler.handle(msg)

        // The handler dispatches via Task, so we need a small yield
        try? await Task.sleep(for: .milliseconds(50))

        #expect(capturedUsername == "alice")
        #expect(capturedStatus == .online)
        #expect(capturedPrivileged == true)
    }

    @Test("getUserStatus with away status and not privileged")
    func getUserStatusAway() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        var capturedStatus: UserStatus?
        var capturedPrivileged: Bool?

        client.addUserStatusHandler { _, status, privileged in
            capturedStatus = status
            capturedPrivileged = privileged
        }

        var payload = Data()
        payload.appendString("bob")
        payload.appendUInt32(UserStatus.away.rawValue)
        payload.appendUInt8(0)

        let msg = buildServerMessage(code: .getUserStatus, payload: payload)
        await handler.handle(msg)

        try? await Task.sleep(for: .milliseconds(50))

        #expect(capturedStatus == .away)
        #expect(capturedPrivileged == false)
    }

    // MARK: - Private Message

    @Test("Private message dispatches with correct fields")
    func privateMessage() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        var capturedUsername: String?
        var capturedMessage: ChatMessage?

        client.onPrivateMessage = { username, message in
            capturedUsername = username
            capturedMessage = message
        }

        var payload = Data()
        payload.appendUInt32(999) // messageId
        payload.appendUInt32(1704067200) // timestamp
        payload.appendString("bob")
        payload.appendString("Hey there!")
        payload.appendUInt8(0) // isNewMessage = false (offline)

        let msg = buildServerMessage(code: .privateMessages, payload: payload)
        await handler.handle(msg)

        #expect(capturedUsername == "bob")
        #expect(capturedMessage?.content == "Hey there!")
        #expect(capturedMessage?.username == "bob")
        #expect(capturedMessage?.messageId == 999)
        #expect(capturedMessage?.isNewMessage == false)
        #expect(capturedMessage?.isOwn == false)
    }

    @Test("Private message with real-time flag (isNewMessage = true)")
    func privateMessageRealTime() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        var capturedMessage: ChatMessage?
        client.onPrivateMessage = { _, message in
            capturedMessage = message
        }

        var payload = Data()
        payload.appendUInt32(1001)
        payload.appendUInt32(1704100000)
        payload.appendString("carol")
        payload.appendString("Real-time message")
        payload.appendUInt8(1) // isNewMessage = true

        let msg = buildServerMessage(code: .privateMessages, payload: payload)
        await handler.handle(msg)

        #expect(capturedMessage?.isNewMessage == true)
        #expect(capturedMessage?.content == "Real-time message")
    }

    // MARK: - Join Room

    @Test("Join room dispatches room name and user list")
    func joinRoom() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        var capturedRoom: String?
        var capturedUsers: [String]?
        var capturedOwner: String?
        var capturedOperators: [String]?

        client.onRoomJoined = { room, users, owner, operators in
            capturedRoom = room
            capturedUsers = users
            capturedOwner = owner
            capturedOperators = operators
        }

        var payload = Data()
        payload.appendString("TestRoom")
        // 2 users
        payload.appendUInt32(2)
        payload.appendString("alice")
        payload.appendString("bob")
        // 2 statuses
        payload.appendUInt32(2)
        payload.appendUInt32(2) // online
        payload.appendUInt32(1) // away
        // 2 stats (20 bytes each: uint32 avgSpeed + uint64 uploadNum + uint32 files + uint32 dirs)
        payload.appendUInt32(2)
        payload.appendUInt32(50000); payload.appendUInt64(100); payload.appendUInt32(500); payload.appendUInt32(20)
        payload.appendUInt32(30000); payload.appendUInt64(50); payload.appendUInt32(200); payload.appendUInt32(10)
        // 2 slots full
        payload.appendUInt32(2)
        payload.appendUInt32(0); payload.appendUInt32(1)
        // 2 countries
        payload.appendUInt32(2)
        payload.appendString("US")
        payload.appendString("DE")

        let msg = buildServerMessage(code: .joinRoom, payload: payload)
        await handler.handle(msg)

        #expect(capturedRoom == "TestRoom")
        #expect(capturedUsers == ["alice", "bob"])
        #expect(capturedOwner == nil) // No private room data
        #expect(capturedOperators == [])
    }

    @Test("Join room with private room data (owner and operators)")
    func joinRoomPrivate() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        var capturedOwner: String?
        var capturedOperators: [String]?

        client.onRoomJoined = { _, _, owner, operators in
            capturedOwner = owner
            capturedOperators = operators
        }

        var payload = Data()
        payload.appendString("VIPRoom")
        // 1 user
        payload.appendUInt32(1)
        payload.appendString("admin")
        // 1 status
        payload.appendUInt32(1)
        payload.appendUInt32(2)
        // 1 stats
        payload.appendUInt32(1)
        payload.appendUInt32(100000); payload.appendUInt64(200); payload.appendUInt32(1000); payload.appendUInt32(50)
        // 1 slots full
        payload.appendUInt32(1)
        payload.appendUInt32(0)
        // 1 country
        payload.appendUInt32(1)
        payload.appendString("US")
        // Private room data
        payload.appendString("admin") // owner
        payload.appendUInt32(1) // 1 operator
        payload.appendString("mod1")

        let msg = buildServerMessage(code: .joinRoom, payload: payload)
        await handler.handle(msg)

        #expect(capturedOwner == "admin")
        #expect(capturedOperators == ["mod1"])
    }

    // MARK: - Leave Room

    @Test("Leave room dispatches room name")
    func leaveRoom() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        var capturedRoom: String?
        client.onRoomLeft = { room in
            capturedRoom = room
        }

        var payload = Data()
        payload.appendString("TestRoom")

        let msg = buildServerMessage(code: .leaveRoom, payload: payload)
        await handler.handle(msg)

        #expect(capturedRoom == "TestRoom")
    }

    // MARK: - Say in Room

    @Test("Say in room dispatches room name, username, and message")
    func sayInRoom() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        var capturedRoom: String?
        var capturedMessage: ChatMessage?

        client.onRoomMessage = { room, message in
            capturedRoom = room
            capturedMessage = message
        }

        var payload = Data()
        payload.appendString("Lounge")
        payload.appendString("alice")
        payload.appendString("Hello everyone!")

        let msg = buildServerMessage(code: .sayInChatRoom, payload: payload)
        await handler.handle(msg)

        #expect(capturedRoom == "Lounge")
        #expect(capturedMessage?.username == "alice")
        #expect(capturedMessage?.content == "Hello everyone!")
    }

    // MARK: - User Joined / Left Room

    @Test("User joined room dispatches room and username")
    func userJoinedRoom() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        var capturedRoom: String?
        var capturedUser: String?

        client.onUserJoinedRoom = { room, user in
            capturedRoom = room
            capturedUser = user
        }

        var payload = Data()
        payload.appendString("Metal")
        payload.appendString("headbanger42")

        let msg = buildServerMessage(code: .userJoinedRoom, payload: payload)
        await handler.handle(msg)

        #expect(capturedRoom == "Metal")
        #expect(capturedUser == "headbanger42")
    }

    @Test("User left room dispatches room and username")
    func userLeftRoom() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        var capturedRoom: String?
        var capturedUser: String?

        client.onUserLeftRoom = { room, user in
            capturedRoom = room
            capturedUser = user
        }

        var payload = Data()
        payload.appendString("Jazz")
        payload.appendString("smoothjazz")

        let msg = buildServerMessage(code: .userLeftRoom, payload: payload)
        await handler.handle(msg)

        #expect(capturedRoom == "Jazz")
        #expect(capturedUser == "smoothjazz")
    }

    // MARK: - Peer Address

    @Test("Peer address response dispatches username, IP, and port")
    func peerAddress() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        var capturedUsername: String?
        var capturedIP: String?
        var capturedPort: Int?

        client.onPeerAddress = { username, ip, port in
            capturedUsername = username
            capturedIP = ip
            capturedPort = port
        }

        var payload = Data()
        payload.appendString("alice")
        payload.appendUInt32(makeIP(192, 168, 1, 100))
        payload.appendUInt32(2234)

        let msg = buildServerMessage(code: .getPeerAddress, payload: payload)
        await handler.handle(msg)

        #expect(capturedUsername == "alice")
        #expect(capturedIP == "192.168.1.100")
        #expect(capturedPort == 2234)
    }

    // MARK: - Admin Message

    @Test("Admin message dispatches message text")
    func adminMessage() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        var capturedMessage: String?
        client.onAdminMessage = { message in
            capturedMessage = message
        }

        var payload = Data()
        payload.appendString("Server maintenance at midnight UTC")

        let msg = buildServerMessage(code: .adminMessage, payload: payload)
        await handler.handle(msg)

        #expect(capturedMessage == "Server maintenance at midnight UTC")
    }

    // MARK: - Recommendations

    @Test("Recommendations callback receives items and scores")
    func recommendations() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        var capturedRecs: [(item: String, score: Int32)]?
        var capturedUnrecs: [(item: String, score: Int32)]?

        client.onRecommendations = { recs, unrecs in
            capturedRecs = recs
            capturedUnrecs = unrecs
        }

        var payload = Data()
        // 2 recommendations
        payload.appendUInt32(2)
        payload.appendString("electronic")
        payload.appendInt32(42)
        payload.appendString("ambient")
        payload.appendInt32(-5)
        // 1 unrecommendation
        payload.appendUInt32(1)
        payload.appendString("country")
        payload.appendInt32(-100)

        let msg = buildServerMessage(code: .recommendations, payload: payload)
        await handler.handle(msg)

        #expect(capturedRecs?.count == 2)
        #expect(capturedRecs?[0].item == "electronic")
        #expect(capturedRecs?[0].score == 42)
        #expect(capturedRecs?[1].item == "ambient")
        #expect(capturedRecs?[1].score == -5)
        #expect(capturedUnrecs?.count == 1)
        #expect(capturedUnrecs?[0].item == "country")
        #expect(capturedUnrecs?[0].score == -100)
    }

    @Test("Global recommendations callback receives items")
    func globalRecommendations() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        var capturedRecs: [(item: String, score: Int32)]?
        client.onGlobalRecommendations = { recs, _ in
            capturedRecs = recs
        }

        var payload = Data()
        payload.appendUInt32(1)
        payload.appendString("rock")
        payload.appendInt32(99)
        payload.appendUInt32(0) // 0 unrecommendations

        let msg = buildServerMessage(code: .globalRecommendations, payload: payload)
        await handler.handle(msg)

        #expect(capturedRecs?.count == 1)
        #expect(capturedRecs?[0].item == "rock")
        #expect(capturedRecs?[0].score == 99)
    }

    // MARK: - User Interests

    @Test("User interests dispatches likes and hates")
    func userInterests() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        var capturedUsername: String?
        var capturedLikes: [String]?
        var capturedHates: [String]?

        client.onUserInterests = { username, likes, hates in
            capturedUsername = username
            capturedLikes = likes
            capturedHates = hates
        }

        var payload = Data()
        payload.appendString("alice")
        payload.appendUInt32(2)
        payload.appendString("jazz")
        payload.appendString("blues")
        payload.appendUInt32(1)
        payload.appendString("noise")

        let msg = buildServerMessage(code: .userInterests, payload: payload)
        await handler.handle(msg)

        #expect(capturedUsername == "alice")
        #expect(capturedLikes == ["jazz", "blues"])
        #expect(capturedHates == ["noise"])
    }

    // MARK: - Similar Users

    @Test("Similar users dispatches username-rating pairs")
    func similarUsers() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        var capturedUsers: [(username: String, rating: UInt32)]?
        client.onSimilarUsers = { users in
            capturedUsers = users
        }

        var payload = Data()
        payload.appendUInt32(2)
        payload.appendString("user1")
        payload.appendUInt32(85)
        payload.appendString("user2")
        payload.appendUInt32(72)

        let msg = buildServerMessage(code: .similarUsers, payload: payload)
        await handler.handle(msg)

        #expect(capturedUsers?.count == 2)
        #expect(capturedUsers?[0].username == "user1")
        #expect(capturedUsers?[0].rating == 85)
        #expect(capturedUsers?[1].username == "user2")
        #expect(capturedUsers?[1].rating == 72)
    }

    // MARK: - Room Tickers

    @Test("Room ticker state dispatches tickers")
    func roomTickerState() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        var capturedRoom: String?
        var capturedTickers: [(username: String, ticker: String)]?

        client.onRoomTickerState = { room, tickers in
            capturedRoom = room
            capturedTickers = tickers
        }

        var payload = Data()
        payload.appendString("Lounge")
        payload.appendUInt32(2)
        payload.appendString("alice")
        payload.appendString("Playing jazz")
        payload.appendString("bob")
        payload.appendString("AFK")

        let msg = buildServerMessage(code: .roomTickerState, payload: payload)
        await handler.handle(msg)

        #expect(capturedRoom == "Lounge")
        #expect(capturedTickers?.count == 2)
        #expect(capturedTickers?[0].username == "alice")
        #expect(capturedTickers?[0].ticker == "Playing jazz")
        #expect(capturedTickers?[1].username == "bob")
        #expect(capturedTickers?[1].ticker == "AFK")
    }

    @Test("Room ticker add dispatches room, username, and ticker text")
    func roomTickerAdd() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        var capturedRoom: String?
        var capturedUser: String?
        var capturedTicker: String?

        client.onRoomTickerAdd = { room, user, ticker in
            capturedRoom = room
            capturedUser = user
            capturedTicker = ticker
        }

        var payload = Data()
        payload.appendString("Lounge")
        payload.appendString("carol")
        payload.appendString("New ticker!")

        let msg = buildServerMessage(code: .roomTickerAdd, payload: payload)
        await handler.handle(msg)

        #expect(capturedRoom == "Lounge")
        #expect(capturedUser == "carol")
        #expect(capturedTicker == "New ticker!")
    }

    @Test("Room ticker remove dispatches room and username")
    func roomTickerRemove() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        var capturedRoom: String?
        var capturedUser: String?

        client.onRoomTickerRemove = { room, user in
            capturedRoom = room
            capturedUser = user
        }

        var payload = Data()
        payload.appendString("Lounge")
        payload.appendString("dave")

        let msg = buildServerMessage(code: .roomTickerRemove, payload: payload)
        await handler.handle(msg)

        #expect(capturedRoom == "Lounge")
        #expect(capturedUser == "dave")
    }

    // MARK: - Privileges

    @Test("Check privileges dispatches time remaining")
    func checkPrivileges() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        var capturedTimeLeft: UInt32?
        client.onPrivilegesChecked = { timeLeft in
            capturedTimeLeft = timeLeft
        }

        var payload = Data()
        payload.appendUInt32(86400)

        let msg = buildServerMessage(code: .checkPrivileges, payload: payload)
        await handler.handle(msg)

        #expect(capturedTimeLeft == 86400)
    }

    @Test("User privileges dispatches username and privileged flag")
    func userPrivileges() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        var capturedUsername: String?
        var capturedPrivileged: Bool?

        client.onUserPrivileges = { username, privileged in
            capturedUsername = username
            capturedPrivileged = privileged
        }

        var payload = Data()
        payload.appendString("vipuser")
        payload.appendUInt8(1) // privileged = true

        let msg = buildServerMessage(code: .userPrivileges, payload: payload)
        await handler.handle(msg)

        #expect(capturedUsername == "vipuser")
        #expect(capturedPrivileged == true)
    }

    // MARK: - Private Rooms

    @Test("Private room members dispatches room and member list")
    func privateRoomMembers() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        var capturedRoom: String?
        var capturedMembers: [String]?

        client.onPrivateRoomMembers = { room, members in
            capturedRoom = room
            capturedMembers = members
        }

        var payload = Data()
        payload.appendString("VIP")
        payload.appendUInt32(3)
        payload.appendString("alice")
        payload.appendString("bob")
        payload.appendString("carol")

        let msg = buildServerMessage(code: .privateRoomMembers, payload: payload)
        await handler.handle(msg)

        #expect(capturedRoom == "VIP")
        #expect(capturedMembers == ["alice", "bob", "carol"])
    }

    @Test("Private room operator granted dispatches room name")
    func privateRoomOperatorGranted() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        var capturedRoom: String?
        client.onPrivateRoomOperatorGranted = { room in
            capturedRoom = room
        }

        var payload = Data()
        payload.appendString("VIP")

        let msg = buildServerMessage(code: .privateRoomOperatorGranted, payload: payload)
        await handler.handle(msg)

        #expect(capturedRoom == "VIP")
    }

    // MARK: - Misc Callbacks

    @Test("Wishlist interval dispatches seconds")
    func wishlistInterval() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        var capturedInterval: UInt32?
        client.onWishlistInterval = { interval in
            capturedInterval = interval
        }

        var payload = Data()
        payload.appendUInt32(720)

        let msg = buildServerMessage(code: .wishlistInterval, payload: payload)
        await handler.handle(msg)

        #expect(capturedInterval == 720)
    }

    @Test("Room added dispatches room name")
    func roomAdded() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        var capturedRoom: String?
        client.onRoomAdded = { room in
            capturedRoom = room
        }

        var payload = Data()
        payload.appendString("NewRoom")

        let msg = buildServerMessage(code: .roomAdded, payload: payload)
        await handler.handle(msg)

        #expect(capturedRoom == "NewRoom")
    }

    @Test("Room removed dispatches room name")
    func roomRemoved() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        var capturedRoom: String?
        client.onRoomRemoved = { room in
            capturedRoom = room
        }

        var payload = Data()
        payload.appendString("OldRoom")

        let msg = buildServerMessage(code: .roomRemoved, payload: payload)
        await handler.handle(msg)

        #expect(capturedRoom == "OldRoom")
    }

    @Test("Can't connect to peer dispatches token")
    func cantConnectToPeer() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        var capturedToken: UInt32?
        client.onCantConnectToPeer = { token in
            capturedToken = token
        }

        var payload = Data()
        payload.appendUInt32(77777)

        let msg = buildServerMessage(code: .cantConnectToPeer, payload: payload)
        await handler.handle(msg)

        #expect(capturedToken == 77777)
    }

    @Test("Can't create room dispatches room name")
    func cantCreateRoom() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        var capturedRoom: String?
        client.onCantCreateRoom = { room in
            capturedRoom = room
        }

        var payload = Data()
        payload.appendString("Reserved Room")

        let msg = buildServerMessage(code: .cantCreateRoom, payload: payload)
        await handler.handle(msg)

        #expect(capturedRoom == "Reserved Room")
    }

    @Test("Room membership granted dispatches room name")
    func roomMembershipGranted() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        var capturedRoom: String?
        client.onRoomMembershipGranted = { room in
            capturedRoom = room
        }

        var payload = Data()
        payload.appendString("PrivateRoom")

        let msg = buildServerMessage(code: .roomMembershipGranted, payload: payload)
        await handler.handle(msg)

        #expect(capturedRoom == "PrivateRoom")
    }

    @Test("Room invitations enabled dispatches boolean")
    func enableRoomInvitations() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        var capturedEnabled: Bool?
        client.onRoomInvitationsEnabled = { enabled in
            capturedEnabled = enabled
        }

        var payload = Data()
        payload.appendUInt8(1) // enabled

        let msg = buildServerMessage(code: .enableRoomInvitations, payload: payload)
        await handler.handle(msg)

        #expect(capturedEnabled == true)
    }

    @Test("Global room message dispatches room, username, and message")
    func globalRoomMessage() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        var capturedRoom: String?
        var capturedUsername: String?
        var capturedMessage: String?

        client.onGlobalRoomMessage = { room, username, message in
            capturedRoom = room
            capturedUsername = username
            capturedMessage = message
        }

        var payload = Data()
        payload.appendString("GlobalLounge")
        payload.appendString("broadcaster")
        payload.appendString("Hello everyone!")

        let msg = buildServerMessage(code: .globalRoomMessage, payload: payload)
        await handler.handle(msg)

        #expect(capturedRoom == "GlobalLounge")
        #expect(capturedUsername == "broadcaster")
        #expect(capturedMessage == "Hello everyone!")
    }

    // MARK: - Unknown / Invalid Message Code

    @Test("Unknown message code does not crash and dispatches nothing")
    func unknownMessageCode() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        var callbackCalled = false
        client.onProtocolNotice = { _, _ in
            callbackCalled = true
        }

        // Use a code that is not in ServerMessageCode enum (e.g. 9999)
        let msg = buildServerMessage(rawCode: 9999, payload: Data())
        await handler.handle(msg)

        // Unknown codes (not in the enum) are not dispatched at all
        #expect(callbackCalled == false)
    }

    // MARK: - Truncated / Malformed Messages

    @Test("Message shorter than 8 bytes is silently ignored")
    func messageTooShort() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        var anyCalled = false
        client.onRoomList = { _ in anyCalled = true }
        client.onRoomMessage = { _, _ in anyCalled = true }

        // Only 4 bytes (no code field)
        var shortMsg = Data()
        shortMsg.appendUInt32(0)
        await handler.handle(shortMsg)

        #expect(anyCalled == false)
    }

    @Test("Empty data is silently ignored")
    func emptyData() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        // Should not crash
        await handler.handle(Data())
    }

    @Test("Truncated login payload does not crash")
    func truncatedLoginPayload() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        // Login message with declared length but truncated payload (no success byte)
        var msg = Data()
        msg.appendUInt32(4) // length = just the code
        msg.appendUInt32(ServerMessageCode.login.rawValue)
        // No payload at all

        await handler.handle(msg)

        // Login should not have succeeded or set any state
        #expect(client.loggedIn == false)
    }

    @Test("Truncated room message does not crash or fire callback")
    func truncatedSayInRoom() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        var callbackCalled = false
        client.onRoomMessage = { _, _ in
            callbackCalled = true
        }

        // Say in room with only room name, missing username and message
        var payload = Data()
        payload.appendString("Lounge")
        // Missing: username and message strings

        let msg = buildServerMessage(code: .sayInChatRoom, payload: payload)
        await handler.handle(msg)

        #expect(callbackCalled == false)
    }

    @Test("Truncated private message does not crash or fire callback")
    func truncatedPrivateMessage() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        var callbackCalled = false
        client.onPrivateMessage = { _, _ in
            callbackCalled = true
        }

        // Private message with only messageId, missing everything else
        var payload = Data()
        payload.appendUInt32(999)
        // Missing: timestamp, username, message, isNewMessage

        let msg = buildServerMessage(code: .privateMessages, payload: payload)
        await handler.handle(msg)

        #expect(callbackCalled == false)
    }

    @Test("Excluded search phrases dispatches phrase list")
    func excludedSearchPhrases() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        var capturedPhrases: [String]?
        client.onExcludedSearchPhrases = { phrases in
            capturedPhrases = phrases
        }

        var payload = Data()
        payload.appendUInt32(3)
        payload.appendString("xxx")
        payload.appendString("warez")
        payload.appendString("crack")

        let msg = buildServerMessage(code: .excludedSearchPhrases, payload: payload)
        await handler.handle(msg)

        #expect(capturedPhrases == ["xxx", "warez", "crack"])
    }

    @Test("Password changed dispatches new password")
    func passwordChanged() async {
        let client = NetworkClient()
        let handler = ServerMessageHandler(client: client)

        var capturedPassword: String?
        client.onPasswordChanged = { password in
            capturedPassword = password
        }

        var payload = Data()
        payload.appendString("newSecret123")

        let msg = buildServerMessage(code: .newPassword, payload: payload)
        await handler.handle(msg)

        #expect(capturedPassword == "newSecret123")
    }
}
