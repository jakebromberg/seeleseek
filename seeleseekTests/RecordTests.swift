import Testing
import Foundation
@testable import SeeleseekCore
@testable import seeleseek

// MARK: - SearchResultRecord Tests

@Suite("SearchResultRecord Tests")
struct SearchResultRecordTests {

    @Test("Round-trip from SearchResult through record and back preserves all fields")
    func testRoundTrip() {
        let id = UUID()
        let queryId = UUID()
        let result = SearchResult(
            id: id,
            username: "alice",
            filename: "@@music\\Artist\\Album\\01 Track.flac",
            size: 48_000_000,
            bitrate: 320,
            duration: 240,
            sampleRate: 44100,
            bitDepth: 16,
            isVBR: true,
            freeSlots: false,
            uploadSpeed: 5000,
            queueLength: 3
        )

        let record = SearchResultRecord.from(result, queryId: queryId)
        let restored = record.toSearchResult()

        #expect(restored.id == id)
        #expect(restored.username == "alice")
        #expect(restored.filename == "@@music\\Artist\\Album\\01 Track.flac")
        #expect(restored.size == 48_000_000)
        #expect(restored.bitrate == 320)
        #expect(restored.duration == 240)
        #expect(restored.sampleRate == 44100)
        #expect(restored.bitDepth == 16)
        #expect(restored.isVBR == true)
        #expect(restored.freeSlots == false)
        #expect(restored.uploadSpeed == 5000)
        #expect(restored.queueLength == 3)
    }

    @Test("Bool-to-Int encoding stores true as 1 and false as 0")
    func testBoolToIntEncoding() {
        let result = SearchResult(
            username: "bob",
            filename: "file.mp3",
            size: 1000,
            isVBR: true,
            freeSlots: false
        )

        let record = SearchResultRecord.from(result, queryId: UUID())

        // Encode to JSON to verify Int storage
        let encoder = JSONEncoder()
        let data = try! encoder.encode(record)
        let json = try! JSONSerialization.jsonObject(with: data) as! [String: Any]

        #expect(json["isVBR"] as? Int == 1)
        #expect(json["freeSlots"] as? Int == 0)
    }

    @Test("Nil optionals survive the round-trip")
    func testNilOptionalsSurvive() {
        let result = SearchResult(
            username: "charlie",
            filename: "track.ogg",
            size: 2000
        )

        let record = SearchResultRecord.from(result, queryId: UUID())
        let restored = record.toSearchResult()

        #expect(restored.bitrate == nil)
        #expect(restored.duration == nil)
        #expect(restored.sampleRate == nil)
        #expect(restored.bitDepth == nil)
    }

    @Test("Record stores queryId from the parameter")
    func testQueryIdStored() {
        let queryId = UUID()
        let result = SearchResult(username: "dave", filename: "f.mp3", size: 100)
        let record = SearchResultRecord.from(result, queryId: queryId)

        #expect(record.queryId == queryId.uuidString)
    }
}

// MARK: - TransferRecord Tests

@Suite("TransferRecord Tests")
struct TransferRecordTests {

    @Test("Full round-trip preserves all fields")
    func testRoundTrip() {
        let id = UUID()
        let startTime = Date(timeIntervalSince1970: 1_700_000_000)
        let localPath = URL(fileURLWithPath: "/Users/test/Downloads/song.mp3")

        let transfer = Transfer(
            id: id,
            username: "uploader99",
            filename: "@@music\\Band\\Album\\song.mp3",
            size: 10_000_000,
            direction: .download,
            status: .transferring,
            bytesTransferred: 5_000_000,
            startTime: startTime,
            speed: 125_000,
            queuePosition: 7,
            error: "timeout",
            localPath: localPath,
            retryCount: 2
        )

        let record = TransferRecord.from(transfer)
        let restored = record.toTransfer()

        #expect(restored.id == id)
        #expect(restored.username == "uploader99")
        #expect(restored.filename == "@@music\\Band\\Album\\song.mp3")
        #expect(restored.size == 10_000_000)
        #expect(restored.direction == .download)
        #expect(restored.status == .transferring)
        #expect(restored.bytesTransferred == 5_000_000)
        #expect(restored.speed == 125_000)
        #expect(restored.queuePosition == 7)
        #expect(restored.error == "timeout")
        #expect(restored.localPath?.path == localPath.path)
        #expect(restored.retryCount == 2)
    }

    @Test("Direction enum survives round-trip", arguments: [
        Transfer.TransferDirection.download,
        Transfer.TransferDirection.upload,
    ])
    func testDirectionSurvival(direction: Transfer.TransferDirection) {
        let transfer = Transfer(
            username: "user",
            filename: "file.mp3",
            size: 1000,
            direction: direction
        )

        let record = TransferRecord.from(transfer)
        let restored = record.toTransfer()

        #expect(restored.direction == direction)
    }

    @Test("Status enum survives round-trip", arguments: [
        Transfer.TransferStatus.queued,
        Transfer.TransferStatus.connecting,
        Transfer.TransferStatus.transferring,
        Transfer.TransferStatus.completed,
        Transfer.TransferStatus.failed,
        Transfer.TransferStatus.cancelled,
        Transfer.TransferStatus.waiting,
    ])
    func testStatusSurvival(status: Transfer.TransferStatus) {
        var transfer = Transfer(
            username: "user",
            filename: "file.mp3",
            size: 1000,
            direction: .download
        )
        transfer.status = status

        let record = TransferRecord.from(transfer)
        let restored = record.toTransfer()

        #expect(restored.status == status)
    }

    @Test("URL path preserved through string conversion")
    func testURLPathPreservation() {
        let path = URL(fileURLWithPath: "/tmp/music/deep/nested/folder/track.flac")
        let transfer = Transfer(
            username: "u",
            filename: "f.flac",
            size: 500,
            direction: .download,
            localPath: path
        )

        let record = TransferRecord.from(transfer)
        #expect(record.localPath == path.path)

        let restored = record.toTransfer()
        #expect(restored.localPath?.path == path.path)
    }

    @Test("Timestamp preservation through TimeInterval conversion")
    func testTimestampPreservation() {
        let startTime = Date(timeIntervalSince1970: 1_700_000_000.5)
        let transfer = Transfer(
            username: "u",
            filename: "f.mp3",
            size: 100,
            direction: .upload,
            startTime: startTime
        )

        let record = TransferRecord.from(transfer)
        let restored = record.toTransfer()

        #expect(restored.startTime?.timeIntervalSince1970 == startTime.timeIntervalSince1970)
    }

    @Test("Nil startTime and localPath survive round-trip")
    func testNilOptionals() {
        let transfer = Transfer(
            username: "u",
            filename: "f.mp3",
            size: 100,
            direction: .download
        )

        let record = TransferRecord.from(transfer)
        let restored = record.toTransfer()

        #expect(restored.startTime == nil)
        #expect(restored.localPath == nil)
        #expect(restored.error == nil)
        #expect(restored.queuePosition == nil)
    }

    @Test("from(_:createdAt:) preserves the original createdAt value")
    func testCreatedAtPreservation() {
        let originalCreatedAt: Double = 1_600_000_000
        let transfer = Transfer(
            username: "u",
            filename: "f.mp3",
            size: 100,
            direction: .download
        )

        let record = TransferRecord.from(transfer, createdAt: originalCreatedAt)
        #expect(record.createdAt == originalCreatedAt)
    }
}

// MARK: - SettingRecord Tests

@Suite("SettingRecord Tests")
struct SettingRecordTests {

    @Test("String value encode and decode round-trip")
    func testStringRoundTrip() throws {
        let record = try SettingRecord.create(key: "theme", value: "dark")
        let decoded = record.decode(String.self)

        #expect(record.key == "theme")
        #expect(decoded == "dark")
    }

    @Test("Int value encode and decode round-trip")
    func testIntRoundTrip() throws {
        let record = try SettingRecord.create(key: "maxConnections", value: 42)
        let decoded = record.decode(Int.self)

        #expect(decoded == 42)
    }

    @Test("Codable struct encode and decode round-trip")
    func testStructRoundTrip() throws {
        struct ServerConfig: Codable, Equatable {
            let host: String
            let port: Int
        }

        let config = ServerConfig(host: "server.slsk.org", port: 2242)
        let record = try SettingRecord.create(key: "serverConfig", value: config)
        let decoded = record.decode(ServerConfig.self)

        #expect(decoded == config)
    }

    @Test("Decoding as wrong type returns nil")
    func testWrongTypeReturnsNil() throws {
        let record = try SettingRecord.create(key: "count", value: 42)
        let wrongDecode = record.decode([String].self)

        #expect(wrongDecode == nil)
    }

    @Test("Bool value encode and decode round-trip")
    func testBoolRoundTrip() throws {
        let record = try SettingRecord.create(key: "enabled", value: true)
        let decoded = record.decode(Bool.self)

        #expect(decoded == true)
    }
}

// MARK: - TransferHistoryRecord Tests

@Suite("TransferHistoryRecord Tests")
struct TransferHistoryRecordTests {

    @Test("averageSpeed calculated from size and duration")
    func testAverageSpeedCalculation() {
        let transfer = Transfer(
            username: "user",
            filename: "song.mp3",
            size: 10_000_000,
            direction: .download
        )

        let record = TransferHistoryRecord.from(transfer, duration: 10.0)

        #expect(record.averageSpeed == 1_000_000.0)
        #expect(record.size == 10_000_000)
        #expect(record.duration == 10.0)
    }

    @Test("Division by zero safety: duration 0 gives speed 0")
    func testDivisionByZeroSafety() {
        let transfer = Transfer(
            username: "user",
            filename: "song.mp3",
            size: 5_000_000,
            direction: .download
        )

        let record = TransferHistoryRecord.from(transfer, duration: 0)

        #expect(record.averageSpeed == 0)
    }

    @Test("Bool-to-Int encoding for isDownload")
    func testBoolToIntEncoding() {
        let download = Transfer(
            username: "user",
            filename: "song.mp3",
            size: 1000,
            direction: .download
        )
        let upload = Transfer(
            username: "user",
            filename: "song.mp3",
            size: 1000,
            direction: .upload
        )

        let downloadRecord = TransferHistoryRecord.from(download, duration: 1.0)
        let uploadRecord = TransferHistoryRecord.from(upload, duration: 1.0)

        #expect(downloadRecord.isDownload == true)
        #expect(uploadRecord.isDownload == false)

        // Verify Int encoding in JSON
        let encoder = JSONEncoder()
        let downloadData = try! encoder.encode(downloadRecord)
        let downloadJson = try! JSONSerialization.jsonObject(with: downloadData) as! [String: Any]
        #expect(downloadJson["isDownload"] as? Int == 1)

        let uploadData = try! encoder.encode(uploadRecord)
        let uploadJson = try! JSONSerialization.jsonObject(with: uploadData) as! [String: Any]
        #expect(uploadJson["isDownload"] as? Int == 0)
    }

    @Test("Fields from transfer are correctly mapped")
    func testFieldMapping() {
        let localPath = URL(fileURLWithPath: "/tmp/song.mp3")
        let transfer = Transfer(
            username: "alice",
            filename: "@@music\\Artist\\song.mp3",
            size: 8_000_000,
            direction: .download,
            localPath: localPath
        )

        let record = TransferHistoryRecord.from(transfer, duration: 4.0)

        #expect(record.filename == "@@music\\Artist\\song.mp3")
        #expect(record.username == "alice")
        #expect(record.size == 8_000_000)
        #expect(record.localPath == localPath.path)
    }
}

// MARK: - PrivateMessageRecord Tests

@Suite("PrivateMessageRecord Tests")
struct PrivateMessageRecordTests {

    @Test("Round-trip from ChatMessage through record and back preserves fields")
    func testRoundTrip() {
        let id = UUID()
        let timestamp = Date(timeIntervalSince1970: 1_700_000_000)
        let message = ChatMessage(
            id: id,
            messageId: 42,
            timestamp: timestamp,
            username: "bob",
            content: "Hello there!",
            isSystem: false,
            isOwn: true
        )

        let record = PrivateMessageRecord.from(message, peerUsername: "bob")
        let restored = record.toChatMessage()

        #expect(restored.id == id)
        #expect(restored.messageId == 42)
        #expect(restored.timestamp.timeIntervalSince1970 == timestamp.timeIntervalSince1970)
        #expect(restored.username == "bob")
        #expect(restored.content == "Hello there!")
        #expect(restored.isSystem == false)
        #expect(restored.isOwn == true)
    }

    @Test("isOwn and isSystem flags preserved")
    func testBoolFlags() {
        let systemMsg = ChatMessage(
            username: "server",
            content: "User joined",
            isSystem: true,
            isOwn: false
        )

        let record = PrivateMessageRecord.from(systemMsg, peerUsername: "someone")
        let restored = record.toChatMessage()

        #expect(restored.isSystem == true)
        #expect(restored.isOwn == false)
    }

    @Test("Optional messageId nil survives round-trip")
    func testNilMessageId() {
        let message = ChatMessage(
            username: "alice",
            content: "hi"
        )

        let record = PrivateMessageRecord.from(message, peerUsername: "alice")
        let restored = record.toChatMessage()

        #expect(restored.messageId == nil)
    }

    @Test("peerUsername stored on record")
    func testPeerUsernameStored() {
        let message = ChatMessage(username: "alice", content: "hey")
        let record = PrivateMessageRecord.from(message, peerUsername: "bob")

        #expect(record.peerUsername == "bob")
        #expect(record.senderUsername == "alice")
    }
}

// MARK: - BuddyRecord Tests

@Suite("BuddyRecord Tests")
struct BuddyRecordTests {

    @Test("Round-trip preserves username, notes, and dates")
    func testRoundTrip() {
        let dateAdded = Date(timeIntervalSince1970: 1_700_000_000)
        let lastSeen = Date(timeIntervalSince1970: 1_700_001_000)
        let buddy = Buddy(
            username: "frienduser",
            notes: "Good uploads",
            dateAdded: dateAdded,
            lastSeen: lastSeen
        )

        let record = BuddyRecord.from(buddy)
        let restored = record.toBuddy()

        #expect(restored.username == "frienduser")
        #expect(restored.notes == "Good uploads")
        #expect(restored.dateAdded.timeIntervalSince1970 == dateAdded.timeIntervalSince1970)
        #expect(restored.lastSeen?.timeIntervalSince1970 == lastSeen.timeIntervalSince1970)
    }

    @Test("toBuddy sets status to offline")
    func testStatusSetToOffline() {
        let buddy = Buddy(username: "someone", status: .online)

        let record = BuddyRecord.from(buddy)
        let restored = record.toBuddy()

        #expect(restored.status == .offline)
    }

    @Test("Optional lastSeen nil survives round-trip")
    func testNilLastSeen() {
        let buddy = Buddy(username: "newbuddy")

        let record = BuddyRecord.from(buddy)
        let restored = record.toBuddy()

        #expect(restored.lastSeen == nil)
    }

    @Test("Optional notes nil survives round-trip")
    func testNilNotes() {
        let buddy = Buddy(username: "nonotesbuddy")

        let record = BuddyRecord.from(buddy)
        let restored = record.toBuddy()

        #expect(restored.notes == nil)
    }
}

// MARK: - SearchQueryRecord Tests

@Suite("SearchQueryRecord Tests")
struct SearchQueryRecordTests {

    @Test("Round-trip preserves id, query, token, and timestamp")
    func testRoundTrip() {
        let id = UUID()
        let timestamp = Date(timeIntervalSince1970: 1_700_000_000)
        let searchQuery = SearchQuery(
            id: id,
            query: "lossless jazz",
            token: 12345,
            timestamp: timestamp,
            results: [],
            isSearching: true
        )

        let record = SearchQueryRecord.from(searchQuery)
        let restored = record.toSearchQuery()

        #expect(restored.id == id)
        #expect(restored.query == "lossless jazz")
        #expect(restored.token == 12345)
        #expect(restored.timestamp.timeIntervalSince1970 == timestamp.timeIntervalSince1970)
        #expect(restored.isSearching == false) // Persisted queries are never actively searching
    }

    @Test("Token UInt32-to-Int64 conversion preserves large values")
    func testTokenConversion() {
        let largeToken: UInt32 = 0xFFFF_FFFE
        let searchQuery = SearchQuery(
            id: UUID(),
            query: "test",
            token: largeToken,
            timestamp: Date(),
            results: [],
            isSearching: false
        )

        let record = SearchQueryRecord.from(searchQuery)
        #expect(record.token == Int64(largeToken))

        let restored = record.toSearchQuery()
        #expect(restored.token == largeToken)
    }

    @Test("Token max UInt32 value survives round-trip")
    func testMaxTokenValue() {
        let maxToken: UInt32 = UInt32.max
        let searchQuery = SearchQuery(
            id: UUID(),
            query: "max",
            token: maxToken,
            timestamp: Date(),
            results: [],
            isSearching: false
        )

        let record = SearchQueryRecord.from(searchQuery)
        let restored = record.toSearchQuery()

        #expect(restored.token == maxToken)
    }

    @Test("Results are loaded separately, default to empty")
    func testResultsDefaultEmpty() {
        let searchQuery = SearchQuery(
            id: UUID(),
            query: "test",
            token: 1,
            timestamp: Date(),
            results: [
                SearchResult(username: "u", filename: "f", size: 100)
            ],
            isSearching: false
        )

        let record = SearchQueryRecord.from(searchQuery)
        let restored = record.toSearchQuery() // no results parameter

        #expect(restored.results.isEmpty)
    }
}

// MARK: - WishlistRecord Tests

@Suite("WishlistRecord Tests")
struct WishlistRecordTests {

    @Test("Bool-to-Int encoding for enabled field")
    func testBoolToIntEncoding() {
        let enabledItem = WishlistItem(query: "ambient", enabled: true)
        let disabledItem = WishlistItem(query: "noise", enabled: false)

        let enabledRecord = WishlistRecord.from(enabledItem)
        let disabledRecord = WishlistRecord.from(disabledItem)

        #expect(enabledRecord.enabled == 1)
        #expect(disabledRecord.enabled == 0)
    }

    @Test("Round-trip preserves all fields")
    func testRoundTrip() {
        let id = UUID()
        let createdAt = Date(timeIntervalSince1970: 1_700_000_000)
        let lastSearchedAt = Date(timeIntervalSince1970: 1_700_001_000)
        let item = WishlistItem(
            id: id,
            query: "progressive rock flac",
            createdAt: createdAt,
            enabled: true,
            lastSearchedAt: lastSearchedAt,
            resultCount: 42
        )

        let record = WishlistRecord.from(item)
        let restored = record.toWishlistItem()

        #expect(restored.id == id)
        #expect(restored.query == "progressive rock flac")
        #expect(restored.createdAt.timeIntervalSince1970 == createdAt.timeIntervalSince1970)
        #expect(restored.enabled == true)
        #expect(restored.lastSearchedAt?.timeIntervalSince1970 == lastSearchedAt.timeIntervalSince1970)
        #expect(restored.resultCount == 42)
    }

    @Test("Optional lastSearchedAt nil survives round-trip")
    func testNilLastSearchedAt() {
        let item = WishlistItem(query: "new search")

        let record = WishlistRecord.from(item)
        let restored = record.toWishlistItem()

        #expect(restored.lastSearchedAt == nil)
    }

    @Test("Disabled item round-trips correctly")
    func testDisabledItem() {
        let item = WishlistItem(query: "disabled query", enabled: false)

        let record = WishlistRecord.from(item)
        let restored = record.toWishlistItem()

        #expect(restored.enabled == false)
    }
}

// MARK: - BlockedUserRecord Tests

@Suite("BlockedUserRecord Tests")
struct BlockedUserRecordTests {

    @Test("Round-trip with non-nil reason")
    func testRoundTripWithReason() {
        let dateBlocked = Date(timeIntervalSince1970: 1_700_000_000)
        let blocked = BlockedUser(
            username: "spammer42",
            reason: "Flooding chat",
            dateBlocked: dateBlocked
        )

        let record = BlockedUserRecord.from(blocked)
        let restored = record.toBlockedUser()

        #expect(restored.username == "spammer42")
        #expect(restored.reason == "Flooding chat")
        #expect(restored.dateBlocked.timeIntervalSince1970 == dateBlocked.timeIntervalSince1970)
    }

    @Test("Round-trip with nil reason")
    func testRoundTripWithNilReason() {
        let blocked = BlockedUser(username: "annoyinguser")

        let record = BlockedUserRecord.from(blocked)
        let restored = record.toBlockedUser()

        #expect(restored.username == "annoyinguser")
        #expect(restored.reason == nil)
    }
}

// MARK: - InterestRecord Tests

@Suite("InterestRecord Tests")
struct InterestRecordTests {

    @Test("interestType computed property returns correct type for 'like'")
    func testInterestTypeLike() {
        let record = InterestRecord.from(item: "jazz", type: .like)

        #expect(record.interestType == .like)
        #expect(record.type == "like")
        #expect(record.item == "jazz")
    }

    @Test("interestType computed property returns correct type for 'hate'")
    func testInterestTypeHate() {
        let record = InterestRecord.from(item: "noise", type: .hate)

        #expect(record.interestType == .hate)
        #expect(record.type == "hate")
        #expect(record.item == "noise")
    }

    @Test("interestType defaults to .like for unknown raw value")
    func testInterestTypeDefaultsToLike() {
        let record = InterestRecord(
            item: "something",
            type: "unknown_value",
            addedAt: Date().timeIntervalSince1970
        )

        #expect(record.interestType == .like)
    }
}
