import Testing
@testable import SeeleseekCore

@Suite("Message Codes")
struct MessageCodeTests {

    // MARK: - ServerMessageCode raw values

    @Test("ServerMessageCode critical raw values", arguments: [
        (ServerMessageCode.login, UInt32(1)),
        (.setListenPort, 2),
        (.getPeerAddress, 3),
        (.getUserStatus, 7),
        (.sayInChatRoom, 13),
        (.joinRoom, 14),
        (.leaveRoom, 15),
        (.connectToPeer, 18),
        (.privateMessages, 22),
        (.fileSearch, 26),
        (.ping, 32),
        (.relogged, 41),
        (.roomList, 64),
        (.embeddedMessage, 93),
        (.possibleParents, 102),
        (.cantConnectToPeer, 1001),
    ])
    func serverMessageRawValues(code: ServerMessageCode, expected: UInt32) {
        #expect(code.rawValue == expected)
    }

    @Test("ServerMessageCode descriptions are non-empty for codes with explicit cases", arguments: [
        ServerMessageCode.login, .setListenPort, .getPeerAddress, .getUserStatus,
        .sayInChatRoom, .joinRoom, .leaveRoom, .connectToPeer, .privateMessages,
        .fileSearch, .ping, .relogged, .roomList, .embeddedMessage, .possibleParents,
        .watchUser, .unwatchUser, .ignoreUser, .unignoreUser, .sharedFoldersFiles,
        .getUserStats, .branchLevel, .branchRoot, .acceptChildren, .haveNoParent,
        .excludedSearchPhrases, .similarRecommendations, .myRecommendations,
        .adminCommand, .cantConnectToPeer, .cantCreateRoom,
        .roomMembershipGranted, .roomMembershipRevoked, .enableRoomInvitations,
        .newPassword, .givePrivileges, .messageUsers, .joinGlobalRoom,
        .leaveGlobalRoom, .globalRoomMessage,
    ])
    func serverMessageDescriptions(code: ServerMessageCode) {
        #expect(!code.description.isEmpty)
        #expect(!code.description.hasPrefix("Code("))
    }

    @Test("ServerMessageCode unknown raw value returns nil")
    func serverMessageUnknownCode() {
        #expect(ServerMessageCode(rawValue: 9999) == nil)
    }

    @Test("ServerMessageCode default description uses Code(N) format for uncovered cases", arguments: [
        ServerMessageCode.recommendations, .globalRecommendations, .userInterests,
        .addThingILike, .removeThingILike, .addThingIHate, .removeThingIHate,
        .wishlistSearch, .wishlistInterval, .similarUsers,
        .itemRecommendations, .itemSimilarUsers,
        .roomTickerState, .roomTickerAdd, .roomTickerRemove, .roomTickerSet,
    ])
    func serverMessageDefaultDescription(code: ServerMessageCode) {
        #expect(code.description == "Code(\(code.rawValue))")
    }

    // MARK: - PeerMessageCode

    @Test("PeerMessageCode critical raw values", arguments: [
        (PeerMessageCode.pierceFirewall, UInt8(0)),
        (.peerInit, 1),
        (.sharesRequest, 4),
        (.sharesReply, 5),
        (.searchRequest, 8),
        (.searchReply, 9),
        (.userInfoRequest, 15),
        (.userInfoReply, 16),
        (.transferRequest, 40),
        (.transferReply, 41),
        (.queueDownload, 43),
        (.placeInQueueReply, 44),
        (.uploadFailed, 46),
        (.uploadDenied, 50),
        (.placeInQueueRequest, 51),
    ])
    func peerMessageRawValues(code: PeerMessageCode, expected: UInt8) {
        #expect(code.rawValue == expected)
    }

    @Test("PeerMessageCode all cases have non-empty descriptions", arguments: [
        PeerMessageCode.pierceFirewall, .peerInit, .sharesRequest, .sharesReply,
        .searchRequest, .searchReply, .userInfoRequest, .userInfoReply,
        .folderContentsRequest, .folderContentsReply, .transferRequest, .transferReply,
        .uploadPlacehold, .queueDownload, .placeInQueueReply, .uploadFailed,
        .uploadDenied, .placeInQueueRequest, .uploadQueueNotification,
    ])
    func peerMessageDescriptions(code: PeerMessageCode) {
        #expect(!code.description.isEmpty)
    }

    // MARK: - SeeleSeekPeerCode

    @Test("SeeleSeekPeerCode has exactly 3 cases")
    func seeleseekPeerCodeCount() {
        #expect(SeeleSeekPeerCode.allCases.count == 3)
    }

    @Test("SeeleSeekPeerCode raw values start at 10000", arguments: [
        (SeeleSeekPeerCode.handshake, UInt32(10000)),
        (.artworkRequest, 10001),
        (.artworkReply, 10002),
    ])
    func seeleseekPeerCodeRawValues(code: SeeleSeekPeerCode, expected: UInt32) {
        #expect(code.rawValue == expected)
    }

    @Test("SeeleSeekPeerCode descriptions are non-empty", arguments: SeeleSeekPeerCode.allCases)
    func seeleseekPeerCodeDescriptions(code: SeeleSeekPeerCode) {
        #expect(!code.description.isEmpty)
    }

    // MARK: - DistributedMessageCode

    @Test("DistributedMessageCode raw values", arguments: [
        (DistributedMessageCode.ping, UInt8(0)),
        (.searchRequest, 3),
        (.branchLevel, 4),
        (.branchRoot, 5),
        (.childDepth, 7),
        (.embeddedMessage, 93),
    ])
    func distributedCodeRawValues(code: DistributedMessageCode, expected: UInt8) {
        #expect(code.rawValue == expected)
    }

    @Test("DistributedMessageCode descriptions are non-empty", arguments: [
        DistributedMessageCode.ping, .searchRequest, .branchLevel, .branchRoot, .childDepth, .embeddedMessage,
    ])
    func distributedCodeDescriptions(code: DistributedMessageCode) {
        #expect(!code.description.isEmpty)
    }

    // MARK: - FileTransferDirection

    @Test("FileTransferDirection raw values")
    func fileTransferDirection() {
        #expect(FileTransferDirection.download.rawValue == 0)
        #expect(FileTransferDirection.upload.rawValue == 1)
    }

    // MARK: - UserStatus

    @Test("UserStatus raw values")
    func userStatusRawValues() {
        #expect(UserStatus.offline.rawValue == 0)
        #expect(UserStatus.away.rawValue == 1)
        #expect(UserStatus.online.rawValue == 2)
    }

    @Test("UserStatus descriptions")
    func userStatusDescriptions() {
        #expect(UserStatus.offline.description == "Offline")
        #expect(UserStatus.away.description == "Away")
        #expect(UserStatus.online.description == "Online")
    }

    // MARK: - LoginResult

    @Test("LoginResult success carries greeting, ip, and optional hash")
    func loginResultSuccess() {
        let result = LoginResult.success(greeting: "Welcome!", ip: "1.2.3.4", hash: "abc123")
        if case .success(let greeting, let ip, let hash) = result {
            #expect(greeting == "Welcome!")
            #expect(ip == "1.2.3.4")
            #expect(hash == "abc123")
        } else {
            Issue.record("Expected success")
        }
    }

    @Test("LoginResult success with nil hash")
    func loginResultSuccessNoHash() {
        let result = LoginResult.success(greeting: "Hi", ip: "0.0.0.0", hash: nil)
        if case .success(_, _, let hash) = result {
            #expect(hash == nil)
        } else {
            Issue.record("Expected success")
        }
    }

    @Test("LoginResult failure carries reason")
    func loginResultFailure() {
        let result = LoginResult.failure(reason: "Bad password")
        if case .failure(let reason) = result {
            #expect(reason == "Bad password")
        } else {
            Issue.record("Expected failure")
        }
    }
}
