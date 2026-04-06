import Testing
import Foundation
@testable import SeeleseekCore
@testable import seeleseek

@Suite(.serialized)
@MainActor
struct ChatStateCallbackTests {

    // MARK: - Helpers

    private func makeMessage(
        username: String = "alice",
        content: String = "hello",
        isSystem: Bool = false,
        isOwn: Bool = false
    ) -> ChatMessage {
        ChatMessage(username: username, content: content, isSystem: isSystem, isOwn: isOwn)
    }

    private func makeRoom(
        name: String,
        users: [String] = [],
        isJoined: Bool = false
    ) -> ChatRoom {
        ChatRoom(name: name, users: users, isJoined: isJoined)
    }

    // MARK: - setupCallbacks

    @Suite(.serialized)
    @MainActor
    struct SetupCallbacksTests {

        @Test("setupCallbacks stores a weak reference to the client")
        func storesClientReference() {
            let state = ChatState()
            let client = NetworkClient()
            state.setupCallbacks(client: client)
            #expect(state.networkClient === client)
        }

        @Test("setupCallbacks wires all room callbacks on the client")
        func wiresCallbacks() {
            let state = ChatState()
            let client = NetworkClient()
            state.setupCallbacks(client: client)

            #expect(client.onRoomList != nil)
            #expect(client.onRoomListFull != nil)
            #expect(client.onRoomJoined != nil)
            #expect(client.onRoomLeft != nil)
            #expect(client.onRoomMessage != nil)
            #expect(client.onPrivateMessage != nil)
            #expect(client.onUserJoinedRoom != nil)
            #expect(client.onUserLeftRoom != nil)
            #expect(client.onCantCreateRoom != nil)
            #expect(client.onPrivateRoomMembers != nil)
            #expect(client.onPrivateRoomMemberAdded != nil)
            #expect(client.onPrivateRoomMemberRemoved != nil)
            #expect(client.onPrivateRoomOperators != nil)
            #expect(client.onPrivateRoomOperatorGranted != nil)
            #expect(client.onPrivateRoomOperatorRevoked != nil)
            #expect(client.onRoomMembershipGranted != nil)
            #expect(client.onRoomMembershipRevoked != nil)
            #expect(client.onRoomTickerState != nil)
            #expect(client.onRoomTickerAdd != nil)
            #expect(client.onRoomTickerRemove != nil)
        }
    }

    // MARK: - onRoomList callback

    @Suite(.serialized)
    @MainActor
    struct OnRoomListTests {

        @Test("onRoomList updates availableRooms and clears loading flag")
        func updatesAvailableRooms() {
            let state = ChatState()
            let client = NetworkClient()
            state.setupCallbacks(client: client)
            state.isLoadingRooms = true

            let rooms = [
                ChatRoom(name: "Music", users: ["a", "b", "c"]),
                ChatRoom(name: "Chat", users: ["x"])
            ]
            client.onRoomList?(rooms)

            #expect(state.availableRooms.count == 2)
            #expect(state.availableRooms[0].name == "Music")
            #expect(state.availableRooms[1].name == "Chat")
            #expect(state.isLoadingRooms == false)
        }

        @Test("onRoomList replaces previous rooms")
        func replacesPreviousRooms() {
            let state = ChatState()
            let client = NetworkClient()
            state.setupCallbacks(client: client)

            client.onRoomList?([ChatRoom(name: "Old")])
            #expect(state.availableRooms.count == 1)

            client.onRoomList?([ChatRoom(name: "New1"), ChatRoom(name: "New2")])
            #expect(state.availableRooms.count == 2)
            #expect(state.availableRooms[0].name == "New1")
        }
    }

    // MARK: - onRoomListFull callback

    @Suite(.serialized)
    @MainActor
    struct OnRoomListFullTests {

        @Test("onRoomListFull populates all room categories")
        func populatesAllCategories() {
            let state = ChatState()
            let client = NetworkClient()
            state.setupCallbacks(client: client)
            state.isLoadingRooms = true

            let publicRooms = [ChatRoom(name: "Public1")]
            let ownedPrivate = [ChatRoom(name: "MyRoom", isPrivate: true)]
            let memberPrivate = [ChatRoom(name: "TheirRoom", isPrivate: true)]
            let operated = ["OpRoom1", "OpRoom2"]

            client.onRoomListFull?(publicRooms, ownedPrivate, memberPrivate, operated)

            #expect(state.availableRooms.count == 1)
            #expect(state.availableRooms[0].name == "Public1")
            #expect(state.ownedPrivateRooms.count == 1)
            #expect(state.ownedPrivateRooms[0].name == "MyRoom")
            #expect(state.memberPrivateRooms.count == 1)
            #expect(state.memberPrivateRooms[0].name == "TheirRoom")
            #expect(state.operatedRoomNames == Set(["OpRoom1", "OpRoom2"]))
            #expect(state.isLoadingRooms == false)
        }
    }

    // MARK: - onRoomJoined callback

    @Suite(.serialized)
    @MainActor
    struct OnRoomJoinedTests {

        @Test("onRoomJoined adds a new room to joinedRooms")
        func addsNewRoom() {
            let state = ChatState()
            let client = NetworkClient()
            state.setupCallbacks(client: client)

            client.onRoomJoined?("Music", ["alice", "bob"], nil, [])

            #expect(state.joinedRooms.count == 1)
            #expect(state.joinedRooms[0].name == "Music")
            #expect(state.joinedRooms[0].users == ["alice", "bob"])
            #expect(state.selectedRoom == "Music")
        }

        @Test("onRoomJoined updates existing room if already joined")
        func updatesExistingRoom() {
            let state = ChatState()
            let client = NetworkClient()
            state.setupCallbacks(client: client)

            // Join first time
            client.onRoomJoined?("Music", ["alice"], nil, [])
            #expect(state.joinedRooms[0].users == ["alice"])

            // Join again with updated user list
            client.onRoomJoined?("Music", ["alice", "bob", "charlie"], nil, [])
            #expect(state.joinedRooms.count == 1)
            #expect(state.joinedRooms[0].users == ["alice", "bob", "charlie"])
        }

        @Test("onRoomJoined sets owner and marks private when owner is provided")
        func setsOwnerAndPrivate() {
            let state = ChatState()
            let client = NetworkClient()
            state.setupCallbacks(client: client)

            client.onRoomJoined?("Secret", ["alice"], "alice", ["bob"])

            #expect(state.joinedRooms[0].owner == "alice")
            #expect(state.joinedRooms[0].isPrivate == true)
            #expect(state.joinedRooms[0].operators == Set(["bob"]))
        }

        @Test("onRoomJoined selects the joined room")
        func selectsJoinedRoom() {
            let state = ChatState()
            let client = NetworkClient()
            state.setupCallbacks(client: client)

            client.onRoomJoined?("First", ["a"], nil, [])
            client.onRoomJoined?("Second", ["b"], nil, [])

            #expect(state.selectedRoom == "Second")
        }
    }

    // MARK: - onRoomLeft callback

    @Suite(.serialized)
    @MainActor
    struct OnRoomLeftTests {

        @Test("onRoomLeft removes the room from joinedRooms")
        func removesRoom() {
            let state = ChatState()
            let client = NetworkClient()
            state.setupCallbacks(client: client)

            client.onRoomJoined?("Music", ["a"], nil, [])
            client.onRoomJoined?("Chat", ["b"], nil, [])
            #expect(state.joinedRooms.count == 2)

            client.onRoomLeft?("Music")
            #expect(state.joinedRooms.count == 1)
            #expect(state.joinedRooms[0].name == "Chat")
        }

        @Test("onRoomLeft updates selectedRoom when the selected room is left")
        func updatesSelectionOnLeave() {
            let state = ChatState()
            let client = NetworkClient()
            state.setupCallbacks(client: client)

            client.onRoomJoined?("Alpha", ["a"], nil, [])
            client.onRoomJoined?("Beta", ["b"], nil, [])

            state.selectedRoom = "Beta"
            client.onRoomLeft?("Beta")

            #expect(state.selectedRoom == "Alpha")
        }

        @Test("onRoomLeft sets selectedRoom to nil when last room is left")
        func nilWhenLastRoomLeft() {
            let state = ChatState()
            let client = NetworkClient()
            state.setupCallbacks(client: client)

            client.onRoomJoined?("Only", ["a"], nil, [])
            state.selectedRoom = "Only"

            client.onRoomLeft?("Only")
            #expect(state.selectedRoom == nil)
        }
    }

    // MARK: - onRoomMessage callback

    @Suite(.serialized)
    @MainActor
    struct OnRoomMessageTests {

        @Test("onRoomMessage adds message to the correct room")
        func addsMessageToRoom() {
            let state = ChatState()
            let client = NetworkClient()
            state.setupCallbacks(client: client)

            client.onRoomJoined?("Music", ["alice"], nil, [])
            let msg = ChatMessage(username: "alice", content: "hello everyone")

            client.onRoomMessage?("Music", msg)

            #expect(state.joinedRooms[0].messages.count == 1)
            #expect(state.joinedRooms[0].messages[0].content == "hello everyone")
        }

        @Test("onRoomMessage skips own messages (server echo)")
        func skipsOwnMessages() {
            let state = ChatState()
            let client = NetworkClient()
            state.setupCallbacks(client: client)

            client.onRoomJoined?("Music", ["me"], nil, [])
            let ownMsg = ChatMessage(username: "me", content: "my message", isOwn: true)

            client.onRoomMessage?("Music", ownMsg)

            #expect(state.joinedRooms[0].messages.isEmpty)
        }

        @Test("onRoomMessage increments unread count when room is not selected")
        func incrementsUnreadForNonSelected() {
            let state = ChatState()
            let client = NetworkClient()
            state.setupCallbacks(client: client)

            client.onRoomJoined?("Music", ["alice"], nil, [])
            client.onRoomJoined?("Chat", ["bob"], nil, [])
            state.selectedRoom = "Chat"

            let msg = ChatMessage(username: "alice", content: "hi")
            client.onRoomMessage?("Music", msg)

            #expect(state.joinedRooms[0].unreadCount == 1)
        }

        @Test("onRoomMessage does not increment unread for currently selected room")
        func noUnreadForSelected() {
            let state = ChatState()
            let client = NetworkClient()
            state.setupCallbacks(client: client)

            client.onRoomJoined?("Music", ["alice"], nil, [])
            state.selectedRoom = "Music"

            let msg = ChatMessage(username: "alice", content: "hi")
            client.onRoomMessage?("Music", msg)

            #expect(state.joinedRooms[0].unreadCount == 0)
        }
    }

    // MARK: - onPrivateMessage callback

    @Suite(.serialized)
    @MainActor
    struct OnPrivateMessageTests {

        @Test("onPrivateMessage creates a new chat if one does not exist")
        func createsNewChat() {
            let state = ChatState()
            let client = NetworkClient()
            state.setupCallbacks(client: client)

            let msg = ChatMessage(username: "bob", content: "hey there")
            client.onPrivateMessage?("bob", msg)

            #expect(state.privateChats.count == 1)
            #expect(state.privateChats[0].username == "bob")
            #expect(state.privateChats[0].messages.count == 1)
            #expect(state.privateChats[0].messages[0].content == "hey there")
        }

        @Test("onPrivateMessage appends to existing chat")
        func appendsToExisting() {
            let state = ChatState()
            let client = NetworkClient()
            state.setupCallbacks(client: client)

            let msg1 = ChatMessage(username: "bob", content: "first")
            let msg2 = ChatMessage(username: "bob", content: "second")
            client.onPrivateMessage?("bob", msg1)
            client.onPrivateMessage?("bob", msg2)

            #expect(state.privateChats.count == 1)
            #expect(state.privateChats[0].messages.count == 2)
        }

        @Test("onPrivateMessage marks sender as online for incoming messages")
        func marksSenderOnline() {
            let state = ChatState()
            let client = NetworkClient()
            state.setupCallbacks(client: client)

            let msg = ChatMessage(username: "bob", content: "hi", isOwn: false)
            client.onPrivateMessage?("bob", msg)

            #expect(state.privateChats[0].isOnline == true)
        }

        @Test("onPrivateMessage increments unread when chat is not selected")
        func incrementsUnread() {
            let state = ChatState()
            let client = NetworkClient()
            state.setupCallbacks(client: client)

            state.selectedPrivateChat = nil
            let msg = ChatMessage(username: "bob", content: "hi")
            client.onPrivateMessage?("bob", msg)

            #expect(state.privateChats[0].unreadCount == 1)
        }

        @Test("onPrivateMessage does not increment unread when chat is selected")
        func noUnreadWhenSelected() {
            let state = ChatState()
            let client = NetworkClient()
            state.setupCallbacks(client: client)

            // Pre-create the chat so it exists when selected
            state.privateChats.append(PrivateChat(username: "bob"))
            state.selectedPrivateChat = "bob"

            let msg = ChatMessage(username: "bob", content: "hi")
            client.onPrivateMessage?("bob", msg)

            #expect(state.privateChats[0].unreadCount == 0)
        }
    }

    // MARK: - onUserJoinedRoom / onUserLeftRoom callbacks

    @Suite(.serialized)
    @MainActor
    struct UserJoinLeaveTests {

        @Test("onUserJoinedRoom adds user to room user list")
        func addsUser() {
            let state = ChatState()
            let client = NetworkClient()
            state.setupCallbacks(client: client)

            client.onRoomJoined?("Music", ["alice"], nil, [])
            client.onUserJoinedRoom?("Music", "bob")

            #expect(state.joinedRooms[0].users.contains("bob"))
        }

        @Test("onUserJoinedRoom does not duplicate user")
        func noDuplicate() {
            let state = ChatState()
            let client = NetworkClient()
            state.setupCallbacks(client: client)

            client.onRoomJoined?("Music", ["alice"], nil, [])
            client.onUserJoinedRoom?("Music", "alice")

            #expect(state.joinedRooms[0].users.filter { $0 == "alice" }.count == 1)
        }

        @Test("onUserJoinedRoom adds a system message")
        func addsJoinSystemMessage() {
            let state = ChatState()
            let client = NetworkClient()
            state.setupCallbacks(client: client)

            client.onRoomJoined?("Music", ["alice"], nil, [])
            client.onUserJoinedRoom?("Music", "bob")

            #expect(state.joinedRooms[0].messages.count == 1)
            #expect(state.joinedRooms[0].messages[0].isSystem == true)
            #expect(state.joinedRooms[0].messages[0].content.contains("bob"))
            #expect(state.joinedRooms[0].messages[0].content.contains("joined"))
        }

        @Test("onUserLeftRoom removes user from room user list")
        func removesUser() {
            let state = ChatState()
            let client = NetworkClient()
            state.setupCallbacks(client: client)

            client.onRoomJoined?("Music", ["alice", "bob"], nil, [])
            client.onUserLeftRoom?("Music", "bob")

            #expect(!state.joinedRooms[0].users.contains("bob"))
            #expect(state.joinedRooms[0].users.contains("alice"))
        }

        @Test("onUserLeftRoom adds a system message")
        func addsLeaveSystemMessage() {
            let state = ChatState()
            let client = NetworkClient()
            state.setupCallbacks(client: client)

            client.onRoomJoined?("Music", ["alice", "bob"], nil, [])
            client.onUserLeftRoom?("Music", "bob")

            let systemMessages = state.joinedRooms[0].messages.filter(\.isSystem)
            #expect(systemMessages.count == 1)
            #expect(systemMessages[0].content.contains("bob"))
            #expect(systemMessages[0].content.contains("left"))
        }
    }

    // MARK: - onCantCreateRoom callback

    @Suite(.serialized)
    @MainActor
    struct CantCreateRoomTests {

        @Test("onCantCreateRoom sets createRoomError")
        func setsError() {
            let state = ChatState()
            let client = NetworkClient()
            state.setupCallbacks(client: client)

            client.onCantCreateRoom?("BadRoom")
            #expect(state.createRoomError != nil)
            #expect(state.createRoomError!.contains("BadRoom"))
        }
    }

    // MARK: - Private room member/operator callbacks

    @Suite(.serialized)
    @MainActor
    struct PrivateRoomMemberOperatorTests {

        @Test("onPrivateRoomMembers updates members list for joined room")
        func updatesMembers() {
            let state = ChatState()
            let client = NetworkClient()
            state.setupCallbacks(client: client)

            client.onRoomJoined?("Secret", ["alice"], "alice", [])
            client.onPrivateRoomMembers?("Secret", ["alice", "bob", "charlie"])

            #expect(state.joinedRooms[0].members == ["alice", "bob", "charlie"])
        }

        @Test("onPrivateRoomMemberAdded adds a member without duplicates")
        func addsMember() {
            let state = ChatState()
            let client = NetworkClient()
            state.setupCallbacks(client: client)

            client.onRoomJoined?("Secret", ["alice"], "alice", [])
            state.joinedRooms[0].members = ["alice"]

            client.onPrivateRoomMemberAdded?("Secret", "bob")
            #expect(state.joinedRooms[0].members.contains("bob"))

            // Adding again should not duplicate
            client.onPrivateRoomMemberAdded?("Secret", "bob")
            #expect(state.joinedRooms[0].members.filter { $0 == "bob" }.count == 1)
        }

        @Test("onPrivateRoomMemberRemoved removes a member")
        func removesMember() {
            let state = ChatState()
            let client = NetworkClient()
            state.setupCallbacks(client: client)

            client.onRoomJoined?("Secret", ["alice"], "alice", [])
            state.joinedRooms[0].members = ["alice", "bob"]

            client.onPrivateRoomMemberRemoved?("Secret", "bob")
            #expect(!state.joinedRooms[0].members.contains("bob"))
        }

        @Test("onPrivateRoomOperators updates operators set")
        func updatesOperators() {
            let state = ChatState()
            let client = NetworkClient()
            state.setupCallbacks(client: client)

            client.onRoomJoined?("Secret", ["alice"], "alice", [])
            client.onPrivateRoomOperators?("Secret", ["bob", "charlie"])

            #expect(state.joinedRooms[0].operators == Set(["bob", "charlie"]))
        }

        @Test("onPrivateRoomOperatorGranted adds to operatedRoomNames")
        func grantsOperator() {
            let state = ChatState()
            let client = NetworkClient()
            state.setupCallbacks(client: client)

            client.onPrivateRoomOperatorGranted?("SecretRoom")
            #expect(state.operatedRoomNames.contains("SecretRoom"))
        }

        @Test("onPrivateRoomOperatorRevoked removes from operatedRoomNames")
        func revokesOperator() {
            let state = ChatState()
            let client = NetworkClient()
            state.setupCallbacks(client: client)

            state.operatedRoomNames.insert("SecretRoom")
            client.onPrivateRoomOperatorRevoked?("SecretRoom")
            #expect(!state.operatedRoomNames.contains("SecretRoom"))
        }
    }

    // MARK: - Membership granted/revoked callbacks

    @Suite(.serialized)
    @MainActor
    struct MembershipGrantedRevokedTests {

        @Test("onRoomMembershipGranted adds system message to current room")
        func addsSystemMessage() {
            let state = ChatState()
            let client = NetworkClient()
            state.setupCallbacks(client: client)

            client.onRoomJoined?("General", ["me"], nil, [])
            state.selectedRoom = "General"

            client.onRoomMembershipGranted?("VIPRoom")

            #expect(state.joinedRooms[0].messages.count == 1)
            #expect(state.joinedRooms[0].messages[0].isSystem == true)
            #expect(state.joinedRooms[0].messages[0].content.contains("VIPRoom"))
        }

        @Test("onRoomMembershipRevoked removes room from joinedRooms")
        func removesFromJoined() {
            let state = ChatState()
            let client = NetworkClient()
            state.setupCallbacks(client: client)

            client.onRoomJoined?("Secret", ["me"], "owner", [])
            state.selectedRoom = "Secret"

            client.onRoomMembershipRevoked?("Secret")

            #expect(state.joinedRooms.isEmpty)
            #expect(state.selectedRoom == nil)
        }

        @Test("onRoomMembershipRevoked removes room from memberPrivateRooms")
        func removesFromMemberPrivate() {
            let state = ChatState()
            let client = NetworkClient()
            state.setupCallbacks(client: client)

            state.memberPrivateRooms = [ChatRoom(name: "Secret", isPrivate: true)]
            client.onRoomMembershipRevoked?("Secret")

            #expect(state.memberPrivateRooms.isEmpty)
        }

        @Test("onRoomMembershipRevoked selects next room when selected room is revoked")
        func selectsNextRoom() {
            let state = ChatState()
            let client = NetworkClient()
            state.setupCallbacks(client: client)

            client.onRoomJoined?("General", ["me"], nil, [])
            client.onRoomJoined?("Secret", ["me"], "owner", [])
            state.selectedRoom = "Secret"

            client.onRoomMembershipRevoked?("Secret")

            #expect(state.selectedRoom == "General")
        }
    }

    // MARK: - Ticker callbacks

    @Suite(.serialized)
    @MainActor
    struct TickerCallbackTests {

        @Test("onRoomTickerState sets all tickers for a room")
        func setsAllTickers() {
            let state = ChatState()
            let client = NetworkClient()
            state.setupCallbacks(client: client)

            client.onRoomJoined?("Music", ["alice", "bob"], nil, [])
            let tickers: [(username: String, ticker: String)] = [
                (username: "alice", ticker: "Listening to Radiohead"),
                (username: "bob", ticker: "AFK")
            ]
            client.onRoomTickerState?("Music", tickers)

            #expect(state.joinedRooms[0].tickers["alice"] == "Listening to Radiohead")
            #expect(state.joinedRooms[0].tickers["bob"] == "AFK")
        }

        @Test("onRoomTickerAdd adds or updates a single ticker")
        func addsTicker() {
            let state = ChatState()
            let client = NetworkClient()
            state.setupCallbacks(client: client)

            client.onRoomJoined?("Music", ["alice"], nil, [])
            client.onRoomTickerAdd?("Music", "alice", "Now playing: Boards of Canada")

            #expect(state.joinedRooms[0].tickers["alice"] == "Now playing: Boards of Canada")
        }

        @Test("onRoomTickerRemove removes a ticker")
        func removesTicker() {
            let state = ChatState()
            let client = NetworkClient()
            state.setupCallbacks(client: client)

            client.onRoomJoined?("Music", ["alice"], nil, [])
            state.joinedRooms[0].tickers["alice"] = "some ticker"

            client.onRoomTickerRemove?("Music", "alice")
            #expect(state.joinedRooms[0].tickers["alice"] == nil)
        }
    }

    // MARK: - selectRoom

    @Suite(.serialized)
    @MainActor
    struct SelectRoomTests {

        @Test("selectRoom sets selectedRoom and clears selectedPrivateChat")
        func setsSelection() {
            let state = ChatState()
            let client = NetworkClient()
            state.setupCallbacks(client: client)

            client.onRoomJoined?("Music", ["alice"], nil, [])
            state.selectedPrivateChat = "bob"

            state.selectRoom("Music")

            #expect(state.selectedRoom == "Music")
            #expect(state.selectedPrivateChat == nil)
        }

        @Test("selectRoom clears unread count for the selected room")
        func clearsUnread() {
            let state = ChatState()
            let client = NetworkClient()
            state.setupCallbacks(client: client)

            client.onRoomJoined?("Music", ["alice"], nil, [])
            client.onRoomJoined?("Chat", ["bob"], nil, [])
            state.selectedRoom = "Chat"

            // Add messages to Music while it's not selected
            let msg = ChatMessage(username: "alice", content: "hello")
            state.addRoomMessage("Music", message: msg)
            #expect(state.joinedRooms[0].unreadCount == 1)

            state.selectRoom("Music")
            #expect(state.joinedRooms[0].unreadCount == 0)
        }
    }

    // MARK: - selectPrivateChat

    @Suite(.serialized)
    @MainActor
    struct SelectPrivateChatTests {

        @Test("selectPrivateChat sets selectedPrivateChat and clears selectedRoom")
        func setsSelection() {
            let state = ChatState()
            state.selectedRoom = "Music"

            state.selectPrivateChat("alice")

            #expect(state.selectedPrivateChat == "alice")
            #expect(state.selectedRoom == nil)
        }

        @Test("selectPrivateChat creates a new chat if it does not exist")
        func createsChat() {
            let state = ChatState()
            state.selectPrivateChat("newuser")

            #expect(state.privateChats.count == 1)
            #expect(state.privateChats[0].username == "newuser")
        }

        @Test("selectPrivateChat clears unread count for the selected chat")
        func clearsUnread() {
            let state = ChatState()
            let client = NetworkClient()
            state.setupCallbacks(client: client)

            // Create a chat with unread messages
            let msg = ChatMessage(username: "alice", content: "hi")
            client.onPrivateMessage?("alice", msg)
            #expect(state.privateChats[0].unreadCount == 1)

            state.selectPrivateChat("alice")
            #expect(state.privateChats[0].unreadCount == 0)
        }

        @Test("selectPrivateChat does not duplicate existing chat")
        func noDuplicate() {
            let state = ChatState()
            state.privateChats.append(PrivateChat(username: "alice"))

            state.selectPrivateChat("alice")
            #expect(state.privateChats.count == 1)
        }
    }

    // MARK: - closePrivateChat

    @Suite(.serialized)
    @MainActor
    struct ClosePrivateChatTests {

        @Test("closePrivateChat removes the chat")
        func removesChat() {
            let state = ChatState()
            state.privateChats.append(PrivateChat(username: "alice"))
            state.privateChats.append(PrivateChat(username: "bob"))

            state.closePrivateChat("alice")

            #expect(state.privateChats.count == 1)
            #expect(state.privateChats[0].username == "bob")
        }

        @Test("closePrivateChat clears selection when the closed chat was selected")
        func clearsSelection() {
            let state = ChatState()
            state.privateChats.append(PrivateChat(username: "alice"))
            state.selectedPrivateChat = "alice"

            state.closePrivateChat("alice")
            #expect(state.selectedPrivateChat == nil)
        }

        @Test("closePrivateChat does not affect selection when a different chat was selected")
        func preservesOtherSelection() {
            let state = ChatState()
            state.privateChats.append(PrivateChat(username: "alice"))
            state.privateChats.append(PrivateChat(username: "bob"))
            state.selectedPrivateChat = "bob"

            state.closePrivateChat("alice")
            #expect(state.selectedPrivateChat == "bob")
        }
    }

    // MARK: - addRoomMessage (direct call)

    @Suite(.serialized)
    @MainActor
    struct AddRoomMessageTests {

        @Test("addRoomMessage appends message to the correct room")
        func appendsToRoom() {
            let state = ChatState()
            state.joinedRooms.append(ChatRoom(name: "Music", isJoined: true))
            state.joinedRooms.append(ChatRoom(name: "Chat", isJoined: true))

            let msg = ChatMessage(username: "alice", content: "hello")
            state.addRoomMessage("Music", message: msg)

            #expect(state.joinedRooms[0].messages.count == 1)
            #expect(state.joinedRooms[1].messages.isEmpty)
        }

        @Test("addRoomMessage does nothing for unknown room")
        func unknownRoomNoOp() {
            let state = ChatState()
            state.joinedRooms.append(ChatRoom(name: "Music", isJoined: true))

            let msg = ChatMessage(username: "alice", content: "hello")
            state.addRoomMessage("NonExistent", message: msg)

            #expect(state.joinedRooms[0].messages.isEmpty)
        }
    }

    // MARK: - updateRoomUsers

    @Suite(.serialized)
    @MainActor
    struct UpdateRoomUsersTests {

        @Test("updateRoomUsers replaces the user list for the room")
        func replacesUserList() {
            let state = ChatState()
            state.joinedRooms.append(ChatRoom(name: "Music", users: ["old1", "old2"], isJoined: true))

            state.updateRoomUsers("Music", users: ["new1", "new2", "new3"])
            #expect(state.joinedRooms[0].users == ["new1", "new2", "new3"])
        }
    }

    // MARK: - Computed properties

    @Suite(.serialized)
    @MainActor
    struct ComputedPropertyTests {

        @Test("currentRoom returns the selected joined room")
        func currentRoom() {
            let state = ChatState()
            state.joinedRooms.append(ChatRoom(name: "Music", isJoined: true))
            state.joinedRooms.append(ChatRoom(name: "Chat", isJoined: true))
            state.selectedRoom = "Chat"

            #expect(state.currentRoom?.name == "Chat")
        }

        @Test("currentRoom returns nil when nothing is selected")
        func currentRoomNil() {
            let state = ChatState()
            state.selectedRoom = nil
            #expect(state.currentRoom == nil)
        }

        @Test("currentPrivateChat returns the selected private chat")
        func currentPrivateChat() {
            let state = ChatState()
            state.privateChats.append(PrivateChat(username: "alice"))
            state.selectedPrivateChat = "alice"

            #expect(state.currentPrivateChat?.username == "alice")
        }

        @Test("currentPrivateChat returns nil when nothing is selected")
        func currentPrivateChatNil() {
            let state = ChatState()
            state.selectedPrivateChat = nil
            #expect(state.currentPrivateChat == nil)
        }

        @Test("totalUnreadCount sums room and private chat unreads")
        func totalUnread() {
            let state = ChatState()
            var room = ChatRoom(name: "Music", isJoined: true)
            room.unreadCount = 3
            state.joinedRooms.append(room)

            var chat = PrivateChat(username: "alice")
            chat.unreadCount = 2
            state.privateChats.append(chat)

            #expect(state.totalUnreadCount == 5)
        }

        @Test("totalUnreadCount is zero when no unreads")
        func totalUnreadZero() {
            let state = ChatState()
            state.joinedRooms.append(ChatRoom(name: "Music", isJoined: true))
            state.privateChats.append(PrivateChat(username: "alice"))

            #expect(state.totalUnreadCount == 0)
        }

        @Test("canSendMessage is false for empty or whitespace-only input")
        func canSendMessageFalse() {
            let state = ChatState()
            state.messageInput = ""
            #expect(!state.canSendMessage)

            state.messageInput = "   "
            #expect(!state.canSendMessage)
        }

        @Test("canSendMessage is true for valid input")
        func canSendMessageTrue() {
            let state = ChatState()
            state.messageInput = "hello"
            #expect(state.canSendMessage)
        }

        @Test("canSendMessage is false when message exceeds max length")
        func canSendMessageTooLong() {
            let state = ChatState()
            state.messageInput = String(repeating: "a", count: 2001)
            #expect(!state.canSendMessage)
        }
    }

    // MARK: - filteredRooms

    @Suite(.serialized)
    @MainActor
    struct FilteredRoomsTests {

        @Test("filteredRooms returns available rooms sorted by user count for 'all' tab")
        func allTabSortedByUserCount() {
            let state = ChatState()
            state.roomListTab = .all
            state.availableRooms = [
                ChatRoom(name: "Small", users: ["a"]),
                ChatRoom(name: "Big", users: ["a", "b", "c"]),
                ChatRoom(name: "Medium", users: ["a", "b"])
            ]

            let filtered = state.filteredRooms
            #expect(filtered[0].name == "Big")
            #expect(filtered[1].name == "Medium")
            #expect(filtered[2].name == "Small")
        }

        @Test("filteredRooms filters by search query case-insensitively")
        func filtersByQuery() {
            let state = ChatState()
            state.roomListTab = .all
            state.availableRooms = [
                ChatRoom(name: "Music"),
                ChatRoom(name: "MUSIC_FLAC"),
                ChatRoom(name: "Chat")
            ]
            state.roomSearchQuery = "music"

            let filtered = state.filteredRooms
            #expect(filtered.count == 2)
            #expect(filtered.allSatisfy { $0.name.lowercased().contains("music") })
        }

        @Test("filteredRooms returns owned private rooms for 'owned' tab")
        func ownedTab() {
            let state = ChatState()
            state.roomListTab = .owned
            state.ownedPrivateRooms = [ChatRoom(name: "MyRoom", isPrivate: true)]
            state.availableRooms = [ChatRoom(name: "Public")]

            let filtered = state.filteredRooms
            #expect(filtered.count == 1)
            #expect(filtered[0].name == "MyRoom")
        }

        @Test("filteredRooms returns member private rooms for 'private' tab")
        func privateTab() {
            let state = ChatState()
            state.roomListTab = .private
            state.memberPrivateRooms = [ChatRoom(name: "TheirRoom", isPrivate: true)]
            state.availableRooms = [ChatRoom(name: "Public")]

            let filtered = state.filteredRooms
            #expect(filtered.count == 1)
            #expect(filtered[0].name == "TheirRoom")
        }
    }

    // MARK: - updateUserOnlineStatus

    @Suite(.serialized)
    @MainActor
    struct UserOnlineStatusTests {

        @Test("updateUserOnlineStatus marks user as online")
        func marksOnline() {
            let state = ChatState()
            state.privateChats.append(PrivateChat(username: "alice", isOnline: false))

            state.updateUserOnlineStatus(username: "alice", status: .online)
            #expect(state.privateChats[0].isOnline == true)
        }

        @Test("updateUserOnlineStatus marks user as offline")
        func marksOffline() {
            let state = ChatState()
            state.privateChats.append(PrivateChat(username: "alice", isOnline: true))

            state.updateUserOnlineStatus(username: "alice", status: .offline)
            #expect(state.privateChats[0].isOnline == false)
        }

        @Test("updateUserOnlineStatus marks away user as online")
        func marksAwayAsOnline() {
            let state = ChatState()
            state.privateChats.append(PrivateChat(username: "alice", isOnline: false))

            state.updateUserOnlineStatus(username: "alice", status: .away)
            #expect(state.privateChats[0].isOnline == true)
        }

        @Test("updateUserOnlineStatus is a no-op for unknown user")
        func unknownUserNoOp() {
            let state = ChatState()
            state.privateChats.append(PrivateChat(username: "alice"))

            state.updateUserOnlineStatus(username: "unknown", status: .online)
            // No crash, alice unchanged
            #expect(state.privateChats.count == 1)
        }
    }

    // MARK: - createRoom validation

    @Suite(.serialized)
    @MainActor
    struct CreateRoomValidationTests {

        @Test("createRoom sets error for empty name")
        func emptyNameError() {
            let state = ChatState()
            state.createRoomName = "   "
            state.createRoom()
            #expect(state.createRoomError != nil)
            #expect(state.createRoomError!.contains("empty"))
        }

        @Test("createRoom sets error for name exceeding 24 characters")
        func tooLongNameError() {
            let state = ChatState()
            state.createRoomName = String(repeating: "a", count: 25)
            state.createRoom()
            #expect(state.createRoomError != nil)
            #expect(state.createRoomError!.contains("24"))
        }

        @Test("createRoom sets error for name with spaces")
        func spacesInNameError() {
            let state = ChatState()
            state.createRoomName = "my room"
            state.createRoom()
            #expect(state.createRoomError != nil)
            #expect(state.createRoomError!.contains("ASCII"))
        }

        @Test("createRoom sets error for non-ASCII name")
        func nonAsciiNameError() {
            let state = ChatState()
            state.createRoomName = "musiqu\u{00E9}"
            state.createRoom()
            #expect(state.createRoomError != nil)
        }

        @Test("createRoom clears UI state on valid name")
        func clearsUIOnValid() {
            let state = ChatState()
            let client = NetworkClient()
            state.setupCallbacks(client: client)

            state.createRoomName = "ValidRoom"
            state.createRoomIsPrivate = true
            state.showCreateRoom = true

            state.createRoom()

            #expect(state.createRoomName == "")
            #expect(state.createRoomIsPrivate == false)
            #expect(state.showCreateRoom == false)
            #expect(state.createRoomError == nil)
        }
    }

    // MARK: - setAvailableRooms (direct method)

    @Suite(.serialized)
    @MainActor
    struct SetAvailableRoomsTests {

        @Test("setAvailableRooms replaces rooms and clears loading")
        func replacesAndClearsLoading() {
            let state = ChatState()
            state.isLoadingRooms = true
            state.availableRooms = [ChatRoom(name: "Old")]

            state.setAvailableRooms([ChatRoom(name: "New1"), ChatRoom(name: "New2")])

            #expect(state.availableRooms.count == 2)
            #expect(state.isLoadingRooms == false)
        }
    }
}
