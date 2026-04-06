import Testing
import Foundation
import GRDB
@testable import SeeleseekCore
@testable import seeleseek

/// Tests that exercise the SQL patterns used by each repository against an in-memory database.
/// The repositories themselves route through `DatabaseManager.shared`, so we replicate their
/// query logic directly on a `DatabaseQueue` to validate correctness without touching the singleton.
@Suite("Repository SQL Pattern Tests", .serialized)
struct RepositoryTests {

    // MARK: - Test Database Helper

    /// Create an in-memory database with all production migrations applied.
    /// Copied from DatabaseIntegrationTests to keep schema in sync.
    private static func makeTestDatabase() throws -> DatabaseQueue {
        let db = try DatabaseQueue()
        try db.write { db in
            try db.execute(sql: "PRAGMA foreign_keys = ON")

            // v1: Initial schema
            try db.create(table: "transfers") { t in
                t.column("id", .text).primaryKey()
                t.column("username", .text).notNull()
                t.column("filename", .text).notNull()
                t.column("size", .integer).notNull()
                t.column("direction", .text).notNull()
                t.column("status", .text).notNull()
                t.column("bytesTransferred", .integer).defaults(to: 0)
                t.column("startTime", .double)
                t.column("speed", .integer).defaults(to: 0)
                t.column("queuePosition", .integer)
                t.column("error", .text)
                t.column("localPath", .text)
                t.column("retryCount", .integer).defaults(to: 0)
                t.column("createdAt", .double).notNull()
                t.column("updatedAt", .double).notNull()
            }
            try db.create(index: "idx_transfers_status", on: "transfers", columns: ["status"])

            try db.create(table: "search_queries") { t in
                t.column("id", .text).primaryKey()
                t.column("query", .text).notNull()
                t.column("token", .integer).notNull()
                t.column("timestamp", .double).notNull()
                t.column("createdAt", .double).notNull()
            }

            try db.create(table: "search_results") { t in
                t.column("id", .text).primaryKey()
                t.column("queryId", .text).notNull().references("search_queries", onDelete: .cascade)
                t.column("username", .text).notNull()
                t.column("filename", .text).notNull()
                t.column("size", .integer).notNull()
                t.column("bitrate", .integer)
                t.column("duration", .integer)
                t.column("isVBR", .integer).defaults(to: 0)
                t.column("freeSlots", .integer).defaults(to: 1)
                t.column("uploadSpeed", .integer).defaults(to: 0)
                t.column("queueLength", .integer).defaults(to: 0)
            }
            try db.create(index: "idx_search_results_query", on: "search_results", columns: ["queryId"])

            try db.create(table: "user_shares") { t in
                t.column("id", .text).primaryKey()
                t.column("username", .text).notNull().unique()
                t.column("cachedAt", .double).notNull()
                t.column("totalFiles", .integer).defaults(to: 0)
                t.column("totalSize", .integer).defaults(to: 0)
            }

            try db.create(table: "shared_files") { t in
                t.column("id", .text).primaryKey()
                t.column("userSharesId", .text).notNull().references("user_shares", onDelete: .cascade)
                t.column("parentId", .text).references("shared_files", onDelete: .cascade)
                t.column("filename", .text).notNull()
                t.column("size", .integer).defaults(to: 0)
                t.column("bitrate", .integer)
                t.column("duration", .integer)
                t.column("isDirectory", .integer).defaults(to: 0)
                t.column("sortOrder", .integer).defaults(to: 0)
            }
            try db.create(index: "idx_shared_files_user", on: "shared_files", columns: ["userSharesId"])
            try db.create(index: "idx_shared_files_parent", on: "shared_files", columns: ["parentId"])

            try db.create(table: "settings") { t in
                t.column("key", .text).primaryKey()
                t.column("value", .text).notNull()
                t.column("updatedAt", .double).notNull()
            }

            try db.create(table: "transfer_history") { t in
                t.column("id", .text).primaryKey()
                t.column("timestamp", .double).notNull()
                t.column("filename", .text).notNull()
                t.column("username", .text).notNull()
                t.column("size", .integer).notNull()
                t.column("duration", .double).notNull()
                t.column("averageSpeed", .double).notNull()
                t.column("isDownload", .integer).notNull()
            }
            try db.create(index: "idx_transfer_history_timestamp", on: "transfer_history", columns: ["timestamp"])

            // v2: Social features
            try db.create(table: "buddies") { t in
                t.column("username", .text).primaryKey()
                t.column("notes", .text)
                t.column("dateAdded", .double).notNull()
                t.column("lastSeen", .double)
            }

            try db.create(table: "my_interests") { t in
                t.column("item", .text).primaryKey()
                t.column("type", .text).notNull()
                t.column("addedAt", .double).notNull()
            }

            try db.create(table: "my_profile") { t in
                t.column("key", .text).primaryKey()
                t.column("value", .text).notNull()
            }

            // v3: Blocklist
            try db.create(table: "blocked_users") { t in
                t.column("username", .text).primaryKey()
                t.column("reason", .text)
                t.column("dateBlocked", .double).notNull()
            }

            // v4: Private messages
            try db.create(table: "private_messages") { t in
                t.column("id", .text).primaryKey()
                t.column("peerUsername", .text).notNull().indexed()
                t.column("senderUsername", .text).notNull()
                t.column("content", .text).notNull()
                t.column("isOwn", .integer).notNull()
                t.column("isSystem", .integer).notNull().defaults(to: 0)
                t.column("messageId", .integer)
                t.column("timestamp", .double).notNull()
            }
            try db.create(index: "idx_private_messages_peer_time", on: "private_messages", columns: ["peerUsername", "timestamp"])

            // v5: Wishlists
            try db.create(table: "wishlists") { t in
                t.column("id", .text).primaryKey()
                t.column("query", .text).notNull()
                t.column("createdAt", .double).notNull()
                t.column("enabled", .integer).notNull().defaults(to: 1)
                t.column("lastSearchedAt", .double)
                t.column("resultCount", .integer).notNull().defaults(to: 0)
            }

            // v6: Extra columns
            try db.execute(sql: "ALTER TABLE search_results ADD COLUMN sampleRate INTEGER")
            try db.execute(sql: "ALTER TABLE search_results ADD COLUMN bitDepth INTEGER")
            try db.execute(sql: "ALTER TABLE transfer_history ADD COLUMN localPath TEXT")
        }
        return db
    }

    // MARK: - Search Repository

    @Suite("Search Repository")
    struct SearchRepositoryTests {

        @Test("save complete search with results and fetch together")
        func saveCompleteSearchWithResults() throws {
            let db = try RepositoryTests.makeTestDatabase()
            let queryId = UUID().uuidString
            let now = Date().timeIntervalSince1970

            // Mirrors SearchRepository.saveComplete: insert query + results in one write
            try db.write { db in
                let queryRecord = SearchQueryRecord(
                    id: queryId, query: "pink floyd", token: 42,
                    timestamp: now, createdAt: now
                )
                try queryRecord.insert(db)

                for i in 0..<3 {
                    try SearchResultRecord(
                        id: UUID().uuidString, queryId: queryId,
                        username: "user\(i)", filename: "track\(i).mp3",
                        size: Int64(5_000_000 + i * 1_000_000),
                        bitrate: 320, duration: 240,
                        isVBR: false, freeSlots: true,
                        uploadSpeed: 50000, queueLength: 2
                    ).insert(db)
                }
            }

            // Fetch query + results together (mirrors SearchRepository.fetch(id:))
            let (query, results): (SearchQueryRecord?, [SearchResultRecord]) = try db.read { db in
                let q = try SearchQueryRecord.filter(Column("id") == queryId).fetchOne(db)
                let r = try SearchResultRecord.filter(Column("queryId") == queryId).fetchAll(db)
                return (q, r)
            }

            #expect(query?.query == "pink floyd")
            #expect(query?.token == 42)
            #expect(results.count == 3)
        }

        @Test("fetch recent queries ordered by timestamp descending with limit")
        func fetchRecentQueriesOrderedByTimestamp() throws {
            let db = try RepositoryTests.makeTestDatabase()
            let now = Date().timeIntervalSince1970

            try db.write { db in
                for i in 0..<5 {
                    try SearchQueryRecord(
                        id: UUID().uuidString, query: "query\(i)",
                        token: Int64(i), timestamp: now + Double(i),
                        createdAt: now + Double(i)
                    ).insert(db)
                }
            }

            // Mirrors SearchRepository.fetchRecent(limit:)
            let recent: [SearchQueryRecord] = try db.read { db in
                try SearchQueryRecord
                    .order(Column("timestamp").desc)
                    .limit(3)
                    .fetchAll(db)
            }

            #expect(recent.count == 3)
            #expect(recent[0].query == "query4")
            #expect(recent[1].query == "query3")
            #expect(recent[2].query == "query2")
        }

        @Test("find cached query by text and max age")
        func findCachedQueryByTextAndAge() throws {
            let db = try RepositoryTests.makeTestDatabase()
            let now = Date().timeIntervalSince1970
            let maxAge: TimeInterval = 3600

            try db.write { db in
                // Old query (2 hours ago)
                try SearchQueryRecord(
                    id: UUID().uuidString, query: "test query",
                    token: 1, timestamp: now - 7200, createdAt: now - 7200
                ).insert(db)
                // Fresh query (5 minutes ago)
                try SearchQueryRecord(
                    id: UUID().uuidString, query: "test query",
                    token: 2, timestamp: now - 300, createdAt: now - 300
                ).insert(db)
            }

            // Mirrors SearchRepository.findCached(query:maxAge:)
            let minTimestamp = now - maxAge
            let cached: SearchQueryRecord? = try db.read { db in
                try SearchQueryRecord
                    .filter(Column("query") == "test query" && Column("createdAt") >= minTimestamp)
                    .order(Column("createdAt").desc)
                    .fetchOne(db)
            }

            #expect(cached != nil)
            #expect(cached?.token == 2) // The fresh one
        }

        @Test("add results to existing query in separate write")
        func addResultsToExistingQuery() throws {
            let db = try RepositoryTests.makeTestDatabase()
            let queryId = UUID().uuidString
            let now = Date().timeIntervalSince1970

            // First write: save query
            try db.write { db in
                try SearchQueryRecord(
                    id: queryId, query: "test", token: 1,
                    timestamp: now, createdAt: now
                ).insert(db)
            }

            // Second write: add results (mirrors SearchRepository.addResults)
            try db.write { db in
                for i in 0..<2 {
                    try SearchResultRecord(
                        id: UUID().uuidString, queryId: queryId,
                        username: "peer\(i)", filename: "file\(i).flac",
                        size: 30_000_000, bitrate: 1411, duration: 300,
                        isVBR: false, freeSlots: true,
                        uploadSpeed: 100000, queueLength: 0
                    ).insert(db)
                }
            }

            let count: Int = try db.read { db in
                try SearchResultRecord.filter(Column("queryId") == queryId).fetchCount(db)
            }
            #expect(count == 2)
        }

        @Test("delete query cascades to results via foreign key")
        func deleteQueryCascadesToResults() throws {
            let db = try RepositoryTests.makeTestDatabase()
            let queryId = UUID().uuidString
            let now = Date().timeIntervalSince1970

            try db.write { db in
                try SearchQueryRecord(id: queryId, query: "doomed", token: 1, timestamp: now, createdAt: now).insert(db)
                try SearchResultRecord(id: UUID().uuidString, queryId: queryId, username: "u", filename: "f.mp3", size: 1000, bitrate: nil, duration: nil, isVBR: false, freeSlots: true, uploadSpeed: 0, queueLength: 0).insert(db)
            }

            // Mirrors SearchRepository.delete(id:)
            try db.write { db in
                try SearchQueryRecord.filter(Column("id") == queryId).deleteAll(db)
            }

            let resultCount: Int = try db.read { db in
                try SearchResultRecord.filter(Column("queryId") == queryId).fetchCount(db)
            }
            #expect(resultCount == 0)
        }

        @Test("delete expired queries by age cutoff")
        func deleteExpiredQueriesByAge() throws {
            let db = try RepositoryTests.makeTestDatabase()
            let now = Date().timeIntervalSince1970

            try db.write { db in
                try SearchQueryRecord(id: UUID().uuidString, query: "ancient", token: 1, timestamp: now - 7200, createdAt: now - 7200).insert(db)
                try SearchQueryRecord(id: UUID().uuidString, query: "recent", token: 2, timestamp: now - 100, createdAt: now - 100).insert(db)
            }

            // Mirrors SearchRepository.deleteExpired(olderThan:)
            let cutoff = now - 3600
            try db.write { db in
                try SearchQueryRecord.filter(Column("createdAt") < cutoff).deleteAll(db)
            }

            let remaining: [SearchQueryRecord] = try db.read { db in
                try SearchQueryRecord.fetchAll(db)
            }
            #expect(remaining.count == 1)
            #expect(remaining[0].query == "recent")
        }

        @Test("fetch distinct search history ordered by timestamp")
        func fetchDistinctSearchHistory() throws {
            let db = try RepositoryTests.makeTestDatabase()
            let now = Date().timeIntervalSince1970

            try db.write { db in
                try SearchQueryRecord(id: UUID().uuidString, query: "beatles", token: 1, timestamp: now, createdAt: now).insert(db)
                try SearchQueryRecord(id: UUID().uuidString, query: "beatles", token: 2, timestamp: now + 1, createdAt: now + 1).insert(db)
                try SearchQueryRecord(id: UUID().uuidString, query: "radiohead", token: 3, timestamp: now + 2, createdAt: now + 2).insert(db)
                try SearchQueryRecord(id: UUID().uuidString, query: "bjork", token: 4, timestamp: now + 3, createdAt: now + 3).insert(db)
            }

            // Mirrors SearchRepository.fetchHistory(limit:)
            let history: [String] = try db.read { db in
                let rows = try Row.fetchAll(db, sql: """
                    SELECT DISTINCT query FROM search_queries
                    ORDER BY timestamp DESC
                    LIMIT ?
                    """, arguments: [2])
                return rows.map { $0["query"] as String }
            }

            #expect(history.count == 2)
            #expect(history[0] == "bjork")
            #expect(history[1] == "radiohead")
        }
    }

    // MARK: - Chat Repository

    @Suite("Chat Repository")
    struct ChatRepositoryTests {

        @Test("save and fetch messages by peer in chronological order")
        func saveAndFetchMessagesByPeer() throws {
            let db = try RepositoryTests.makeTestDatabase()
            let now = Date().timeIntervalSince1970

            try db.write { db in
                try PrivateMessageRecord(id: UUID().uuidString, peerUsername: "alice", senderUsername: "me", content: "Hello Alice", isOwn: true, isSystem: false, messageId: 1, timestamp: now).insert(db)
                try PrivateMessageRecord(id: UUID().uuidString, peerUsername: "alice", senderUsername: "alice", content: "Hi there!", isOwn: false, isSystem: false, messageId: 2, timestamp: now + 1).insert(db)
                try PrivateMessageRecord(id: UUID().uuidString, peerUsername: "bob", senderUsername: "bob", content: "Hey", isOwn: false, isSystem: false, messageId: 3, timestamp: now + 2).insert(db)
            }

            // Mirrors ChatRepository.fetchMessages(for:limit:)
            let aliceRecords: [PrivateMessageRecord] = try db.read { db in
                try PrivateMessageRecord
                    .filter(Column("peerUsername") == "alice")
                    .order(Column("timestamp").desc)
                    .limit(200)
                    .fetchAll(db)
            }
            let aliceMessages = aliceRecords.reversed().map { $0.toChatMessage() }

            #expect(aliceMessages.count == 2)
            #expect(aliceMessages[0].content == "Hello Alice")
            #expect(aliceMessages[0].isOwn == true)
            #expect(aliceMessages[1].content == "Hi there!")
            #expect(aliceMessages[1].isOwn == false)
        }

        @Test("fetch conversations ordered by most recent message")
        func fetchConversationsOrderedByMostRecent() throws {
            let db = try RepositoryTests.makeTestDatabase()
            let now = Date().timeIntervalSince1970

            try db.write { db in
                try PrivateMessageRecord(id: UUID().uuidString, peerUsername: "charlie", senderUsername: "me", content: "oldest", isOwn: true, isSystem: false, messageId: nil, timestamp: now).insert(db)
                try PrivateMessageRecord(id: UUID().uuidString, peerUsername: "alice", senderUsername: "me", content: "middle", isOwn: true, isSystem: false, messageId: nil, timestamp: now + 5).insert(db)
                try PrivateMessageRecord(id: UUID().uuidString, peerUsername: "bob", senderUsername: "bob", content: "newest", isOwn: false, isSystem: false, messageId: nil, timestamp: now + 10).insert(db)
                // Another message to alice to make her most recent
                try PrivateMessageRecord(id: UUID().uuidString, peerUsername: "alice", senderUsername: "alice", content: "latest", isOwn: false, isSystem: false, messageId: nil, timestamp: now + 15).insert(db)
            }

            // Mirrors ChatRepository.fetchConversations()
            let conversations: [String] = try db.read { db in
                try String.fetchAll(db, sql: """
                    SELECT DISTINCT peerUsername FROM private_messages
                    ORDER BY (SELECT MAX(timestamp) FROM private_messages pm2 WHERE pm2.peerUsername = private_messages.peerUsername) DESC
                """)
            }

            #expect(conversations.count == 3)
            #expect(conversations[0] == "alice")
            #expect(conversations[1] == "bob")
            #expect(conversations[2] == "charlie")
        }

        @Test("delete conversation only affects target peer")
        func deleteConversationOnlyAffectsTargetPeer() throws {
            let db = try RepositoryTests.makeTestDatabase()
            let now = Date().timeIntervalSince1970

            try db.write { db in
                try PrivateMessageRecord(id: UUID().uuidString, peerUsername: "alice", senderUsername: "me", content: "a1", isOwn: true, isSystem: false, messageId: nil, timestamp: now).insert(db)
                try PrivateMessageRecord(id: UUID().uuidString, peerUsername: "alice", senderUsername: "alice", content: "a2", isOwn: false, isSystem: false, messageId: nil, timestamp: now + 1).insert(db)
                try PrivateMessageRecord(id: UUID().uuidString, peerUsername: "bob", senderUsername: "bob", content: "b1", isOwn: false, isSystem: false, messageId: nil, timestamp: now + 2).insert(db)
            }

            // Mirrors ChatRepository.deleteConversation
            try db.write { db in
                try PrivateMessageRecord.filter(Column("peerUsername") == "alice").deleteAll(db)
            }

            let remaining: [PrivateMessageRecord] = try db.read { db in
                try PrivateMessageRecord.fetchAll(db)
            }
            #expect(remaining.count == 1)
            #expect(remaining[0].peerUsername == "bob")
        }

        @Test("prune old messages keeps newest N per conversation")
        func pruneOldMessagesKeepsNewest() throws {
            let db = try RepositoryTests.makeTestDatabase()
            let now = Date().timeIntervalSince1970
            let keepCount = 5

            // Insert 8 messages for one peer
            try db.write { db in
                for i in 0..<8 {
                    try PrivateMessageRecord(
                        id: UUID().uuidString, peerUsername: "alice",
                        senderUsername: i % 2 == 0 ? "me" : "alice",
                        content: "msg\(i)", isOwn: i % 2 == 0, isSystem: false,
                        messageId: nil, timestamp: now + Double(i)
                    ).insert(db)
                }
            }

            // Mirrors ChatRepository.pruneOldMessages (simplified for smaller dataset)
            try db.write { db in
                let peers = try String.fetchAll(db, sql: "SELECT DISTINCT peerUsername FROM private_messages")
                for peer in peers {
                    let count = try PrivateMessageRecord.filter(Column("peerUsername") == peer).fetchCount(db)
                    if count > keepCount {
                        try db.execute(sql: """
                            DELETE FROM private_messages WHERE id IN (
                                SELECT id FROM private_messages
                                WHERE peerUsername = ?
                                ORDER BY timestamp ASC
                                LIMIT ?
                            )
                        """, arguments: [peer, count - keepCount])
                    }
                }
            }

            let remaining: [PrivateMessageRecord] = try db.read { db in
                try PrivateMessageRecord
                    .filter(Column("peerUsername") == "alice")
                    .order(Column("timestamp").asc)
                    .fetchAll(db)
            }
            #expect(remaining.count == keepCount)
            // Oldest remaining should be msg3 (indices 0,1,2 were pruned)
            #expect(remaining[0].content == "msg3")
            #expect(remaining[4].content == "msg7")
        }

        @Test("save message with upsert updates existing")
        func saveMessageWithUpsertBehavior() throws {
            let db = try RepositoryTests.makeTestDatabase()
            let msgId = UUID().uuidString
            let now = Date().timeIntervalSince1970

            // Initial save
            try db.write { db in
                try PrivateMessageRecord(
                    id: msgId, peerUsername: "alice", senderUsername: "me",
                    content: "original", isOwn: true, isSystem: false,
                    messageId: 42, timestamp: now
                ).save(db)
            }

            // Update via save (mirrors ChatRepository.saveMessage which uses record.save(db))
            try db.write { db in
                try PrivateMessageRecord(
                    id: msgId, peerUsername: "alice", senderUsername: "me",
                    content: "edited", isOwn: true, isSystem: false,
                    messageId: 42, timestamp: now
                ).save(db)
            }

            let all: [PrivateMessageRecord] = try db.read { db in
                try PrivateMessageRecord.fetchAll(db)
            }
            #expect(all.count == 1)
            #expect(all[0].content == "edited")
        }

        @Test("system message flag persists correctly")
        func systemMessagePersistence() throws {
            let db = try RepositoryTests.makeTestDatabase()
            let now = Date().timeIntervalSince1970

            try db.write { db in
                try PrivateMessageRecord(
                    id: UUID().uuidString, peerUsername: "server",
                    senderUsername: "system", content: "User joined the room",
                    isOwn: false, isSystem: true, messageId: nil, timestamp: now
                ).insert(db)
            }

            let fetched: PrivateMessageRecord? = try db.read { db in
                try PrivateMessageRecord.filter(Column("peerUsername") == "server").fetchOne(db)
            }
            #expect(fetched?.isSystem == true)
            #expect(fetched?.isOwn == false)

            let chatMessage = fetched?.toChatMessage()
            #expect(chatMessage?.isSystem == true)
        }
    }

    // MARK: - Social Repository

    @Suite("Social Repository")
    struct SocialRepositoryTests {

        @Test("save buddy and fetch sorted by username")
        func saveBuddyAndFetchSorted() throws {
            let db = try RepositoryTests.makeTestDatabase()
            let now = Date().timeIntervalSince1970

            try db.write { db in
                try BuddyRecord(username: "zach", notes: nil, dateAdded: now, lastSeen: nil).insert(db)
                try BuddyRecord(username: "alice", notes: "Best friend", dateAdded: now, lastSeen: nil).insert(db)
                try BuddyRecord(username: "mike", notes: nil, dateAdded: now, lastSeen: now).insert(db)
            }

            // Mirrors SocialRepository.fetchBuddies()
            let records: [BuddyRecord] = try db.read { db in
                try BuddyRecord.order(Column("username").asc).fetchAll(db)
            }
            let buddies = records.map { $0.toBuddy() }

            #expect(buddies.count == 3)
            #expect(buddies[0].username == "alice")
            #expect(buddies[0].notes == "Best friend")
            #expect(buddies[1].username == "mike")
            #expect(buddies[2].username == "zach")
        }

        @Test("buddy upsert updates existing record")
        func buddyUpsertUpdatesExisting() throws {
            let db = try RepositoryTests.makeTestDatabase()
            let now = Date().timeIntervalSince1970

            // Mirrors SocialRepository.saveBuddy (uses record.save(db))
            try db.write { db in
                try BuddyRecord(username: "bob", notes: "Original note", dateAdded: now, lastSeen: nil).save(db)
            }
            try db.write { db in
                try BuddyRecord(username: "bob", notes: "Updated note", dateAdded: now, lastSeen: now + 100).save(db)
            }

            let all: [BuddyRecord] = try db.read { db in try BuddyRecord.fetchAll(db) }
            #expect(all.count == 1)
            #expect(all[0].notes == "Updated note")
            #expect(all[0].lastSeen != nil)
        }

        @Test("delete buddy by username")
        func deleteBuddyByUsername() throws {
            let db = try RepositoryTests.makeTestDatabase()
            let now = Date().timeIntervalSince1970

            try db.write { db in
                try BuddyRecord(username: "alice", notes: nil, dateAdded: now, lastSeen: nil).insert(db)
                try BuddyRecord(username: "bob", notes: nil, dateAdded: now, lastSeen: nil).insert(db)
            }

            // Mirrors SocialRepository.deleteBuddy
            try db.write { db in
                try BuddyRecord.filter(Column("username") == "alice").deleteAll(db)
            }

            let remaining: [BuddyRecord] = try db.read { db in try BuddyRecord.fetchAll(db) }
            #expect(remaining.count == 1)
            #expect(remaining[0].username == "bob")
        }

        @Test("save and fetch interests partitioned by type")
        func saveAndFetchInterestsByType() throws {
            let db = try RepositoryTests.makeTestDatabase()
            let now = Date().timeIntervalSince1970

            try db.write { db in
                try InterestRecord(item: "jazz", type: "like", addedAt: now).insert(db)
                try InterestRecord(item: "electronic", type: "like", addedAt: now + 1).insert(db)
                try InterestRecord(item: "classical", type: "like", addedAt: now + 2).insert(db)
                try InterestRecord(item: "noise", type: "hate", addedAt: now + 3).insert(db)
                try InterestRecord(item: "mumble rap", type: "hate", addedAt: now + 4).insert(db)
            }

            // Mirrors SocialRepository.fetchInterests()
            let records: [InterestRecord] = try db.read { db in
                try InterestRecord.order(Column("addedAt").asc).fetchAll(db)
            }
            let likes = records.filter { $0.interestType == .like }
            let hates = records.filter { $0.interestType == .hate }

            #expect(likes.count == 3)
            #expect(hates.count == 2)
            #expect(likes[0].item == "jazz")
            #expect(hates[0].item == "noise")
        }

        @Test("delete interest by item name")
        func deleteInterestByItem() throws {
            let db = try RepositoryTests.makeTestDatabase()
            let now = Date().timeIntervalSince1970

            try db.write { db in
                try InterestRecord(item: "jazz", type: "like", addedAt: now).insert(db)
                try InterestRecord(item: "blues", type: "like", addedAt: now + 1).insert(db)
            }

            // Mirrors SocialRepository.deleteInterest
            try db.write { db in
                try InterestRecord.filter(Column("item") == "jazz").deleteAll(db)
            }

            let remaining: [InterestRecord] = try db.read { db in try InterestRecord.fetchAll(db) }
            #expect(remaining.count == 1)
            #expect(remaining[0].item == "blues")
        }

        @Test("delete all interests by type preserves other type")
        func deleteAllInterestsByType() throws {
            let db = try RepositoryTests.makeTestDatabase()
            let now = Date().timeIntervalSince1970

            try db.write { db in
                try InterestRecord(item: "jazz", type: "like", addedAt: now).insert(db)
                try InterestRecord(item: "blues", type: "like", addedAt: now).insert(db)
                try InterestRecord(item: "noise", type: "hate", addedAt: now).insert(db)
                try InterestRecord(item: "static", type: "hate", addedAt: now).insert(db)
            }

            // Mirrors SocialRepository.deleteAllInterests(type:)
            try db.write { db in
                try InterestRecord.filter(Column("type") == InterestType.like.rawValue).deleteAll(db)
            }

            let remaining: [InterestRecord] = try db.read { db in try InterestRecord.fetchAll(db) }
            #expect(remaining.count == 2)
            #expect(remaining.allSatisfy { $0.type == "hate" })
        }

        @Test("blocked user CRUD with isBlocked check")
        func blockedUserCRUD() throws {
            let db = try RepositoryTests.makeTestDatabase()

            // Save (mirrors SocialRepository.saveBlockedUser)
            try db.write { db in
                try BlockedUserRecord(username: "spammer", reason: "Flooding chat", dateBlocked: Date()).insert(db)
            }

            // isBlocked check (mirrors SocialRepository.isUserBlocked)
            let isBlocked: Bool = try db.read { db in
                try BlockedUserRecord.filter(Column("username") == "spammer").fetchCount(db) > 0
            }
            #expect(isBlocked == true)

            let isNotBlocked: Bool = try db.read { db in
                try BlockedUserRecord.filter(Column("username") == "friend").fetchCount(db) > 0
            }
            #expect(isNotBlocked == false)

            // Delete (mirrors SocialRepository.deleteBlockedUser)
            try db.write { db in
                try BlockedUserRecord.filter(Column("username") == "spammer").deleteAll(db)
            }

            let afterDelete: Bool = try db.read { db in
                try BlockedUserRecord.filter(Column("username") == "spammer").fetchCount(db) > 0
            }
            #expect(afterDelete == false)
        }

        @Test("fetch blocked users ordered by date descending")
        func fetchBlockedUsersOrderedByDateDesc() throws {
            let db = try RepositoryTests.makeTestDatabase()
            let now = Date()

            try db.write { db in
                try BlockedUserRecord(username: "first", reason: nil, dateBlocked: now.addingTimeInterval(-100)).insert(db)
                try BlockedUserRecord(username: "second", reason: "Rude", dateBlocked: now.addingTimeInterval(-50)).insert(db)
                try BlockedUserRecord(username: "third", reason: nil, dateBlocked: now).insert(db)
            }

            // Mirrors SocialRepository.fetchBlockedUsers()
            let records: [BlockedUserRecord] = try db.read { db in
                try BlockedUserRecord.order(Column("dateBlocked").desc).fetchAll(db)
            }
            let blocked = records.map { $0.toBlockedUser() }

            #expect(blocked.count == 3)
            #expect(blocked[0].username == "third")
            #expect(blocked[1].username == "second")
            #expect(blocked[1].reason == "Rude")
            #expect(blocked[2].username == "first")
        }

        @Test("profile setting get/set/delete")
        func profileSettingCRUD() throws {
            let db = try RepositoryTests.makeTestDatabase()

            // Set (mirrors SocialRepository.setProfileSetting)
            try db.write { db in
                try ProfileSettingRecord(key: "description", value: "Music lover").save(db)
            }

            // Get (mirrors SocialRepository.getProfileSetting)
            let value: String? = try db.read { db in
                let record = try ProfileSettingRecord.filter(Column("key") == "description").fetchOne(db)
                return record?.value
            }
            #expect(value == "Music lover")

            // Update via save
            try db.write { db in
                try ProfileSettingRecord(key: "description", value: "Updated bio").save(db)
            }

            let updated: String? = try db.read { db in
                try ProfileSettingRecord.filter(Column("key") == "description").fetchOne(db)?.value
            }
            #expect(updated == "Updated bio")

            let count: Int = try db.read { db in try ProfileSettingRecord.fetchCount(db) }
            #expect(count == 1)

            // Delete (mirrors SocialRepository.deleteProfileSetting)
            try db.write { db in
                try ProfileSettingRecord.filter(Column("key") == "description").deleteAll(db)
            }

            let deleted: ProfileSettingRecord? = try db.read { db in
                try ProfileSettingRecord.filter(Column("key") == "description").fetchOne(db)
            }
            #expect(deleted == nil)
        }
    }

    // MARK: - Transfer Repository

    @Suite("Transfer Repository")
    struct TransferRepositoryTests {

        @Test("save and fetch transfer by ID with all fields")
        func saveAndFetchTransfer() throws {
            let db = try RepositoryTests.makeTestDatabase()
            let id = UUID().uuidString
            let now = Date().timeIntervalSince1970

            try db.write { db in
                try TransferRecord(
                    id: id, username: "alice", filename: "@@music\\Artist\\song.mp3",
                    size: 8_500_000, direction: "download", status: "queued",
                    bytesTransferred: 0, startTime: nil, speed: 0,
                    queuePosition: 3, error: nil, localPath: nil,
                    retryCount: 0, createdAt: now, updatedAt: now
                ).insert(db)
            }

            // Mirrors TransferRepository.fetch(id:)
            let record: TransferRecord? = try db.read { db in
                try TransferRecord.filter(Column("id") == id).fetchOne(db)
            }
            let transfer = record?.toTransfer()

            #expect(transfer?.username == "alice")
            #expect(transfer?.filename == "@@music\\Artist\\song.mp3")
            #expect(transfer?.size == 8_500_000)
            #expect(transfer?.direction == .download)
            #expect(transfer?.status == .queued)
            #expect(transfer?.queuePosition == 3)
        }

        @Test("fetch persisted excludes completed transfers")
        func fetchPersistedExcludesCompleted() throws {
            let db = try RepositoryTests.makeTestDatabase()
            let now = Date().timeIntervalSince1970

            try db.write { db in
                try TransferRecord(id: UUID().uuidString, username: "u", filename: "done.mp3", size: 1000, direction: "download", status: "completed", bytesTransferred: 1000, startTime: nil, speed: 0, queuePosition: nil, error: nil, localPath: "/tmp/done.mp3", retryCount: 0, createdAt: now, updatedAt: now).insert(db)
                try TransferRecord(id: UUID().uuidString, username: "u", filename: "active.mp3", size: 5000, direction: "download", status: "transferring", bytesTransferred: 2000, startTime: now, speed: 50000, queuePosition: nil, error: nil, localPath: nil, retryCount: 0, createdAt: now, updatedAt: now).insert(db)
                try TransferRecord(id: UUID().uuidString, username: "u", filename: "waiting.mp3", size: 3000, direction: "download", status: "queued", bytesTransferred: 0, startTime: nil, speed: 0, queuePosition: 5, error: nil, localPath: nil, retryCount: 0, createdAt: now, updatedAt: now).insert(db)
            }

            // Mirrors TransferRepository.fetchPersisted()
            let persisted: [TransferRecord] = try db.read { db in
                try TransferRecord
                    .filter(Column("status") != "completed")
                    .order(Column("createdAt").desc)
                    .fetchAll(db)
            }

            #expect(persisted.count == 2)
            #expect(persisted.allSatisfy { $0.status != "completed" })
        }

        @Test("fetch transfers filtered by direction")
        func fetchByDirection() throws {
            let db = try RepositoryTests.makeTestDatabase()
            let now = Date().timeIntervalSince1970

            try db.write { db in
                try TransferRecord(id: UUID().uuidString, username: "alice", filename: "dl1.mp3", size: 1000, direction: "download", status: "queued", bytesTransferred: 0, startTime: nil, speed: 0, queuePosition: nil, error: nil, localPath: nil, retryCount: 0, createdAt: now, updatedAt: now).insert(db)
                try TransferRecord(id: UUID().uuidString, username: "alice", filename: "dl2.flac", size: 2000, direction: "download", status: "queued", bytesTransferred: 0, startTime: nil, speed: 0, queuePosition: nil, error: nil, localPath: nil, retryCount: 0, createdAt: now + 1, updatedAt: now + 1).insert(db)
                try TransferRecord(id: UUID().uuidString, username: "bob", filename: "ul1.mp3", size: 3000, direction: "upload", status: "transferring", bytesTransferred: 500, startTime: now, speed: 10000, queuePosition: nil, error: nil, localPath: nil, retryCount: 0, createdAt: now + 2, updatedAt: now + 2).insert(db)
            }

            // Mirrors TransferRepository.fetch(direction:)
            let downloads: [TransferRecord] = try db.read { db in
                try TransferRecord
                    .filter(Column("direction") == Transfer.TransferDirection.download.rawValue)
                    .order(Column("createdAt").desc)
                    .fetchAll(db)
            }
            #expect(downloads.count == 2)

            let uploads: [TransferRecord] = try db.read { db in
                try TransferRecord
                    .filter(Column("direction") == Transfer.TransferDirection.upload.rawValue)
                    .order(Column("createdAt").desc)
                    .fetchAll(db)
            }
            #expect(uploads.count == 1)
            #expect(uploads[0].filename == "ul1.mp3")
        }

        @Test("update transfer status via raw SQL")
        func updateTransferStatus() throws {
            let db = try RepositoryTests.makeTestDatabase()
            let id = UUID().uuidString
            let now = Date().timeIntervalSince1970

            try db.write { db in
                try TransferRecord(id: id, username: "u", filename: "f.mp3", size: 1000, direction: "download", status: "queued", bytesTransferred: 0, startTime: nil, speed: 0, queuePosition: nil, error: nil, localPath: nil, retryCount: 0, createdAt: now, updatedAt: now).insert(db)
            }

            // Mirrors TransferRepository.updateStatus(id:status:error:)
            try db.write { db in
                try db.execute(
                    sql: """
                        UPDATE transfers
                        SET status = ?, error = ?, updatedAt = ?
                        WHERE id = ?
                        """,
                    arguments: ["failed", "Peer closed connection", now + 5, id]
                )
            }

            let fetched: TransferRecord? = try db.read { db in
                try TransferRecord.filter(Column("id") == id).fetchOne(db)
            }
            #expect(fetched?.status == "failed")
            #expect(fetched?.error == "Peer closed connection")
            #expect(fetched?.updatedAt == now + 5)
        }

        @Test("update transfer progress via raw SQL")
        func updateTransferProgress() throws {
            let db = try RepositoryTests.makeTestDatabase()
            let id = UUID().uuidString
            let now = Date().timeIntervalSince1970

            try db.write { db in
                try TransferRecord(id: id, username: "u", filename: "f.mp3", size: 10_000_000, direction: "download", status: "transferring", bytesTransferred: 0, startTime: now, speed: 0, queuePosition: nil, error: nil, localPath: nil, retryCount: 0, createdAt: now, updatedAt: now).insert(db)
            }

            // Mirrors TransferRepository.updateProgress(id:bytesTransferred:speed:)
            try db.write { db in
                try db.execute(
                    sql: """
                        UPDATE transfers
                        SET bytesTransferred = ?, speed = ?, updatedAt = ?
                        WHERE id = ?
                        """,
                    arguments: [Int64(7_500_000), Int64(250_000), now + 10, id]
                )
            }

            let fetched: TransferRecord? = try db.read { db in
                try TransferRecord.filter(Column("id") == id).fetchOne(db)
            }
            #expect(fetched?.bytesTransferred == 7_500_000)
            #expect(fetched?.speed == 250_000)
        }

        @Test("delete completed transfers preserves active ones")
        func deleteCompletedTransfers() throws {
            let db = try RepositoryTests.makeTestDatabase()
            let now = Date().timeIntervalSince1970

            try db.write { db in
                try TransferRecord(id: UUID().uuidString, username: "u", filename: "done.mp3", size: 1, direction: "download", status: "completed", bytesTransferred: 1, startTime: nil, speed: 0, queuePosition: nil, error: nil, localPath: nil, retryCount: 0, createdAt: now, updatedAt: now).insert(db)
                try TransferRecord(id: UUID().uuidString, username: "u", filename: "active.mp3", size: 1, direction: "download", status: "transferring", bytesTransferred: 0, startTime: nil, speed: 0, queuePosition: nil, error: nil, localPath: nil, retryCount: 0, createdAt: now, updatedAt: now).insert(db)
                try TransferRecord(id: UUID().uuidString, username: "u", filename: "queued.mp3", size: 1, direction: "upload", status: "queued", bytesTransferred: 0, startTime: nil, speed: 0, queuePosition: nil, error: nil, localPath: nil, retryCount: 0, createdAt: now, updatedAt: now).insert(db)
            }

            // Mirrors TransferRepository.deleteCompleted()
            try db.write { db in
                try TransferRecord.filter(Column("status") == "completed").deleteAll(db)
            }

            let remaining: [TransferRecord] = try db.read { db in try TransferRecord.fetchAll(db) }
            #expect(remaining.count == 2)
            #expect(remaining.allSatisfy { $0.status != "completed" })
        }

        @Test("delete failed and cancelled transfers")
        func deleteFailedAndCancelledTransfers() throws {
            let db = try RepositoryTests.makeTestDatabase()
            let now = Date().timeIntervalSince1970

            try db.write { db in
                try TransferRecord(id: UUID().uuidString, username: "u", filename: "failed.mp3", size: 1, direction: "download", status: "failed", bytesTransferred: 0, startTime: nil, speed: 0, queuePosition: nil, error: "timeout", localPath: nil, retryCount: 2, createdAt: now, updatedAt: now).insert(db)
                try TransferRecord(id: UUID().uuidString, username: "u", filename: "cancelled.mp3", size: 1, direction: "download", status: "cancelled", bytesTransferred: 0, startTime: nil, speed: 0, queuePosition: nil, error: nil, localPath: nil, retryCount: 0, createdAt: now, updatedAt: now).insert(db)
                try TransferRecord(id: UUID().uuidString, username: "u", filename: "ok.mp3", size: 1, direction: "download", status: "queued", bytesTransferred: 0, startTime: nil, speed: 0, queuePosition: nil, error: nil, localPath: nil, retryCount: 0, createdAt: now, updatedAt: now).insert(db)
            }

            // Mirrors TransferRepository.deleteFailed()
            try db.write { db in
                try TransferRecord
                    .filter(["failed", "cancelled"].contains(Column("status")))
                    .deleteAll(db)
            }

            let remaining: [TransferRecord] = try db.read { db in try TransferRecord.fetchAll(db) }
            #expect(remaining.count == 1)
            #expect(remaining[0].status == "queued")
        }

        @Test("record completed transfer to history")
        func recordCompletionToHistory() throws {
            let db = try RepositoryTests.makeTestDatabase()
            let now = Date().timeIntervalSince1970

            // Mirrors TransferRepository.recordCompletion (inserts into transfer_history)
            try db.write { db in
                try TransferHistoryRecord(
                    id: UUID().uuidString, timestamp: now,
                    filename: "@@music\\Artist\\Album\\track01.flac",
                    username: "alice", size: 45_000_000,
                    duration: 12.5, averageSpeed: 3_600_000.0,
                    isDownload: true, localPath: "/Users/me/Music/track01.flac"
                ).insert(db)
            }

            let history: [TransferHistoryRecord] = try db.read { db in
                try TransferHistoryRecord.order(Column("timestamp").desc).fetchAll(db)
            }
            #expect(history.count == 1)
            #expect(history[0].filename == "@@music\\Artist\\Album\\track01.flac")
            #expect(history[0].isDownload == true)
            #expect(history[0].averageSpeed == 3_600_000.0)
            #expect(history[0].localPath == "/Users/me/Music/track01.flac")
        }
    }

    // MARK: - Browse Repository

    @Suite("Browse Repository")
    struct BrowseRepositoryTests {

        @Test("save user shares with nested file records")
        func saveUserSharesWithFiles() throws {
            let db = try RepositoryTests.makeTestDatabase()
            let sharesId = UUID().uuidString
            let dirId = UUID().uuidString
            let now = Date().timeIntervalSince1970

            // Mirrors BrowseRepository.save: delete old, insert shares + files
            try db.write { db in
                try UserSharesRecord(
                    id: sharesId, username: "alice",
                    cachedAt: now, totalFiles: 3, totalSize: 15_000_000
                ).insert(db)

                // Directory
                try SharedFileRecord(
                    id: dirId, userSharesId: sharesId, parentId: nil,
                    filename: "Music", size: 0, bitrate: nil, duration: nil,
                    isDirectory: true, sortOrder: 0
                ).insert(db)

                // Files inside directory
                try SharedFileRecord(
                    id: UUID().uuidString, userSharesId: sharesId, parentId: dirId,
                    filename: "song1.mp3", size: 5_000_000, bitrate: 320, duration: 210,
                    isDirectory: false, sortOrder: 0
                ).insert(db)
                try SharedFileRecord(
                    id: UUID().uuidString, userSharesId: sharesId, parentId: dirId,
                    filename: "song2.flac", size: 10_000_000, bitrate: 1411, duration: 300,
                    isDirectory: false, sortOrder: 1
                ).insert(db)
            }

            // Fetch back (mirrors BrowseRepository.fetch)
            let shares: UserSharesRecord? = try db.read { db in
                try UserSharesRecord.filter(Column("username").collating(.nocase) == "alice").fetchOne(db)
            }
            #expect(shares?.totalFiles == 3)
            #expect(shares?.totalSize == 15_000_000)

            let files: [SharedFileRecord] = try db.read { db in
                try SharedFileRecord.filter(Column("userSharesId") == sharesId).fetchAll(db)
            }
            #expect(files.count == 3)

            let dirs = files.filter { $0.isDirectory }
            let nonDirs = files.filter { !$0.isDirectory }
            #expect(dirs.count == 1)
            #expect(nonDirs.count == 2)
        }

        @Test("cache validity check with TTL")
        func cacheValidityCheck() throws {
            let db = try RepositoryTests.makeTestDatabase()
            let now = Date().timeIntervalSince1970
            let ttl: TimeInterval = 86400

            try db.write { db in
                try UserSharesRecord(id: UUID().uuidString, username: "recent", cachedAt: now - 100, totalFiles: 5, totalSize: 1000).insert(db)
                try UserSharesRecord(id: UUID().uuidString, username: "expired", cachedAt: now - 200_000, totalFiles: 3, totalSize: 500).insert(db)
            }

            // Mirrors BrowseRepository.isCacheValid(username:ttl:)
            let minCacheTime = now - ttl

            let recentValid: Bool = try db.read { db in
                try UserSharesRecord
                    .filter(Column("username").collating(.nocase) == "recent" && Column("cachedAt") >= minCacheTime)
                    .fetchCount(db) > 0
            }
            #expect(recentValid == true)

            let expiredValid: Bool = try db.read { db in
                try UserSharesRecord
                    .filter(Column("username").collating(.nocase) == "expired" && Column("cachedAt") >= minCacheTime)
                    .fetchCount(db) > 0
            }
            #expect(expiredValid == false)
        }

        @Test("delete expired shares cascades to files")
        func deleteExpiredCascadesToFiles() throws {
            let db = try RepositoryTests.makeTestDatabase()
            let now = Date().timeIntervalSince1970
            let oldSharesId = UUID().uuidString
            let freshSharesId = UUID().uuidString

            try db.write { db in
                try UserSharesRecord(id: oldSharesId, username: "old_user", cachedAt: now - 200_000, totalFiles: 1, totalSize: 1000).insert(db)
                try SharedFileRecord(id: UUID().uuidString, userSharesId: oldSharesId, parentId: nil, filename: "old.mp3", size: 1000, bitrate: nil, duration: nil, isDirectory: false, sortOrder: 0).insert(db)

                try UserSharesRecord(id: freshSharesId, username: "fresh_user", cachedAt: now - 100, totalFiles: 1, totalSize: 2000).insert(db)
                try SharedFileRecord(id: UUID().uuidString, userSharesId: freshSharesId, parentId: nil, filename: "fresh.mp3", size: 2000, bitrate: nil, duration: nil, isDirectory: false, sortOrder: 0).insert(db)
            }

            // Mirrors BrowseRepository.deleteExpired(olderThan:)
            let cutoff = now - 86400
            try db.write { db in
                try UserSharesRecord.filter(Column("cachedAt") < cutoff).deleteAll(db)
            }

            let shareCount: Int = try db.read { db in try UserSharesRecord.fetchCount(db) }
            let fileCount: Int = try db.read { db in try SharedFileRecord.fetchCount(db) }
            #expect(shareCount == 1) // Only fresh remains
            #expect(fileCount == 1) // Old files cascaded away
        }

        @Test("fetch cached usernames ordered by most recent")
        func fetchCachedUsernamesOrdered() throws {
            let db = try RepositoryTests.makeTestDatabase()
            let now = Date().timeIntervalSince1970

            try db.write { db in
                try UserSharesRecord(id: UUID().uuidString, username: "oldest", cachedAt: now - 1000, totalFiles: 0, totalSize: 0).insert(db)
                try UserSharesRecord(id: UUID().uuidString, username: "middle", cachedAt: now - 500, totalFiles: 0, totalSize: 0).insert(db)
                try UserSharesRecord(id: UUID().uuidString, username: "newest", cachedAt: now, totalFiles: 0, totalSize: 0).insert(db)
            }

            // Mirrors BrowseRepository.fetchCachedUsernames()
            let usernames: [String] = try db.read { db in
                let rows = try Row.fetchAll(db, sql: """
                    SELECT username FROM user_shares
                    ORDER BY cachedAt DESC
                    """)
                return rows.map { $0["username"] as String }
            }

            #expect(usernames.count == 3)
            #expect(usernames[0] == "newest")
            #expect(usernames[1] == "middle")
            #expect(usernames[2] == "oldest")
        }

        @Test("get cache statistics with COUNT and SUM")
        func getCacheStats() throws {
            let db = try RepositoryTests.makeTestDatabase()
            let now = Date().timeIntervalSince1970

            try db.write { db in
                try UserSharesRecord(id: UUID().uuidString, username: "alice", cachedAt: now, totalFiles: 100, totalSize: 5_000_000_000).insert(db)
                try UserSharesRecord(id: UUID().uuidString, username: "bob", cachedAt: now, totalFiles: 50, totalSize: 2_000_000_000).insert(db)
            }

            // Mirrors BrowseRepository.getCacheStats()
            let stats: (userCount: Int, totalFiles: Int, totalSize: Int64) = try db.read { db in
                let row = try Row.fetchOne(db, sql: """
                    SELECT COUNT(*) as userCount,
                           COALESCE(SUM(totalFiles), 0) as totalFiles,
                           COALESCE(SUM(totalSize), 0) as totalSize
                    FROM user_shares
                    """)
                return (
                    userCount: row?["userCount"] ?? 0,
                    totalFiles: row?["totalFiles"] ?? 0,
                    totalSize: row?["totalSize"] ?? 0
                )
            }

            #expect(stats.userCount == 2)
            #expect(stats.totalFiles == 150)
            #expect(stats.totalSize == 7_000_000_000)
        }

        @Test("delete by username is case insensitive")
        func deleteByUsernameCaseInsensitive() throws {
            let db = try RepositoryTests.makeTestDatabase()
            let now = Date().timeIntervalSince1970

            try db.write { db in
                try UserSharesRecord(id: UUID().uuidString, username: "Alice", cachedAt: now, totalFiles: 5, totalSize: 1000).insert(db)
            }

            // Mirrors BrowseRepository.delete(username:) with .collating(.nocase)
            try db.write { db in
                try UserSharesRecord
                    .filter(Column("username").collating(.nocase) == "alice")
                    .deleteAll(db)
            }

            let count: Int = try db.read { db in try UserSharesRecord.fetchCount(db) }
            #expect(count == 0)
        }
    }

    // MARK: - Wishlist Repository

    @Suite("Wishlist Repository")
    struct WishlistRepositoryTests {

        @Test("save and fetch all ordered by creation date")
        func saveAndFetchAllOrdered() throws {
            let db = try RepositoryTests.makeTestDatabase()
            let now = Date().timeIntervalSince1970

            try db.write { db in
                try WishlistRecord(id: UUID().uuidString, query: "rare vinyl", createdAt: now, enabled: 1, lastSearchedAt: nil, resultCount: 0).insert(db)
                try WishlistRecord(id: UUID().uuidString, query: "jazz imports", createdAt: now + 10, enabled: 1, lastSearchedAt: nil, resultCount: 0).insert(db)
                try WishlistRecord(id: UUID().uuidString, query: "bootlegs", createdAt: now + 20, enabled: 0, lastSearchedAt: nil, resultCount: 0).insert(db)
            }

            // Mirrors WishlistRepository.fetchAll()
            let records: [WishlistRecord] = try db.read { db in
                try WishlistRecord.order(Column("createdAt").asc).fetchAll(db)
            }
            let items = records.map { $0.toWishlistItem() }

            #expect(items.count == 3)
            #expect(items[0].query == "rare vinyl")
            #expect(items[0].enabled == true)
            #expect(items[1].query == "jazz imports")
            #expect(items[2].query == "bootlegs")
            #expect(items[2].enabled == false)
        }

        @Test("toggle enabled flag via SQL update")
        func toggleEnabled() throws {
            let db = try RepositoryTests.makeTestDatabase()
            let id = UUID().uuidString
            let now = Date().timeIntervalSince1970

            try db.write { db in
                try WishlistRecord(id: id, query: "something", createdAt: now, enabled: 1, lastSearchedAt: nil, resultCount: 0).insert(db)
            }

            // Toggle to disabled
            try db.write { db in
                try db.execute(sql: "UPDATE wishlists SET enabled = 0 WHERE id = ?", arguments: [id])
            }

            let disabled: WishlistRecord? = try db.read { db in
                try WishlistRecord.filter(Column("id") == id).fetchOne(db)
            }
            #expect(disabled?.enabled == 0)
            #expect(disabled?.toWishlistItem().enabled == false)

            // Toggle back to enabled
            try db.write { db in
                try db.execute(sql: "UPDATE wishlists SET enabled = 1 WHERE id = ?", arguments: [id])
            }

            let enabled: WishlistRecord? = try db.read { db in
                try WishlistRecord.filter(Column("id") == id).fetchOne(db)
            }
            #expect(enabled?.toWishlistItem().enabled == true)
        }

        @Test("update lastSearched and resultCount via raw SQL")
        func updateLastSearchedAndResultCount() throws {
            let db = try RepositoryTests.makeTestDatabase()
            let id = UUID().uuidString
            let now = Date().timeIntervalSince1970

            try db.write { db in
                try WishlistRecord(id: id, query: "test", createdAt: now, enabled: 1, lastSearchedAt: nil, resultCount: 0).insert(db)
            }

            // Mirrors WishlistRepository.updateLastSearched(id:resultCount:)
            let searchTime = now + 500
            try db.write { db in
                try db.execute(
                    sql: "UPDATE wishlists SET lastSearchedAt = ?, resultCount = ? WHERE id = ?",
                    arguments: [searchTime, 37, id]
                )
            }

            let fetched: WishlistRecord? = try db.read { db in
                try WishlistRecord.filter(Column("id") == id).fetchOne(db)
            }
            #expect(fetched?.resultCount == 37)
            #expect(fetched?.lastSearchedAt == searchTime)

            let item = fetched?.toWishlistItem()
            #expect(item?.resultCount == 37)
            #expect(item?.lastSearchedAt != nil)
        }

        @Test("delete wishlist by ID")
        func deleteById() throws {
            let db = try RepositoryTests.makeTestDatabase()
            let id1 = UUID().uuidString
            let id2 = UUID().uuidString
            let now = Date().timeIntervalSince1970

            try db.write { db in
                try WishlistRecord(id: id1, query: "keep", createdAt: now, enabled: 1, lastSearchedAt: nil, resultCount: 0).insert(db)
                try WishlistRecord(id: id2, query: "delete", createdAt: now, enabled: 1, lastSearchedAt: nil, resultCount: 0).insert(db)
            }

            // Mirrors WishlistRepository.delete(id:)
            try db.write { db in
                try WishlistRecord.filter(Column("id") == id2).deleteAll(db)
            }

            let remaining: [WishlistRecord] = try db.read { db in try WishlistRecord.fetchAll(db) }
            #expect(remaining.count == 1)
            #expect(remaining[0].query == "keep")
        }
    }

    // MARK: - Settings Repository

    @Suite("Settings Repository")
    struct SettingsRepositoryTests {

        @Test("insert and fetch setting by key")
        func insertAndFetchSetting() throws {
            let db = try RepositoryTests.makeTestDatabase()
            let now = Date().timeIntervalSince1970

            try db.write { db in
                try SettingRecord(key: "theme", value: "\"dark\"", updatedAt: now).insert(db)
            }

            // Mirrors SettingsRepository.get
            let record: SettingRecord? = try db.read { db in
                try SettingRecord.filter(Column("key") == "theme").fetchOne(db)
            }
            #expect(record?.value == "\"dark\"")
            let decoded: String? = record?.decode(String.self)
            #expect(decoded == "dark")
        }

        @Test("upsert setting via INSERT OR REPLACE")
        func upsertSetting() throws {
            let db = try RepositoryTests.makeTestDatabase()
            let now = Date().timeIntervalSince1970

            // Mirrors SettingsRepository.set (INSERT OR REPLACE)
            try db.write { db in
                try db.execute(
                    sql: "INSERT OR REPLACE INTO settings (key, value, updatedAt) VALUES (?, ?, ?)",
                    arguments: ["volume", "80", now]
                )
            }

            try db.write { db in
                try db.execute(
                    sql: "INSERT OR REPLACE INTO settings (key, value, updatedAt) VALUES (?, ?, ?)",
                    arguments: ["volume", "100", now + 1]
                )
            }

            let record: SettingRecord? = try db.read { db in
                try SettingRecord.filter(Column("key") == "volume").fetchOne(db)
            }
            #expect(record?.value == "100")

            let count: Int = try db.read { db in try SettingRecord.fetchCount(db) }
            #expect(count == 1)
        }

        @Test("delete setting by key")
        func deleteSetting() throws {
            let db = try RepositoryTests.makeTestDatabase()
            let now = Date().timeIntervalSince1970

            try db.write { db in
                try SettingRecord(key: "temp", value: "\"value\"", updatedAt: now).insert(db)
            }

            // Mirrors SettingsRepository.delete
            try db.write { db in
                try SettingRecord.filter(Column("key") == "temp").deleteAll(db)
            }

            let count: Int = try db.read { db in try SettingRecord.fetchCount(db) }
            #expect(count == 0)
        }

        @Test("get all settings as dictionary")
        func getAllSettings() throws {
            let db = try RepositoryTests.makeTestDatabase()
            let now = Date().timeIntervalSince1970

            try db.write { db in
                try SettingRecord(key: "theme", value: "\"dark\"", updatedAt: now).insert(db)
                try SettingRecord(key: "volume", value: "80", updatedAt: now).insert(db)
                try SettingRecord(key: "notifications", value: "true", updatedAt: now).insert(db)
            }

            // Mirrors SettingsRepository.getAll()
            let all: [String: String] = try db.read { db in
                let records = try SettingRecord.fetchAll(db)
                var result: [String: String] = [:]
                for record in records {
                    result[record.key] = record.value
                }
                return result
            }

            #expect(all.count == 3)
            #expect(all["theme"] == "\"dark\"")
            #expect(all["volume"] == "80")
            #expect(all["notifications"] == "true")
        }

        @Test("JSON encoding round-trip for typed values")
        func jsonEncodingRoundTrip() throws {
            let db = try RepositoryTests.makeTestDatabase()

            // Bool
            let boolRecord = try SettingRecord.create(key: "flag", value: true)
            try db.write { db in
                try db.execute(
                    sql: "INSERT OR REPLACE INTO settings (key, value, updatedAt) VALUES (?, ?, ?)",
                    arguments: [boolRecord.key, boolRecord.value, boolRecord.updatedAt]
                )
            }
            let fetchedBool: SettingRecord? = try db.read { db in
                try SettingRecord.filter(Column("key") == "flag").fetchOne(db)
            }
            #expect(fetchedBool?.decode(Bool.self) == true)

            // Int
            let intRecord = try SettingRecord.create(key: "port", value: 2242)
            try db.write { db in
                try db.execute(
                    sql: "INSERT OR REPLACE INTO settings (key, value, updatedAt) VALUES (?, ?, ?)",
                    arguments: [intRecord.key, intRecord.value, intRecord.updatedAt]
                )
            }
            let fetchedInt: SettingRecord? = try db.read { db in
                try SettingRecord.filter(Column("key") == "port").fetchOne(db)
            }
            #expect(fetchedInt?.decode(Int.self) == 2242)

            // String
            let strRecord = try SettingRecord.create(key: "username", value: "seeker42")
            try db.write { db in
                try db.execute(
                    sql: "INSERT OR REPLACE INTO settings (key, value, updatedAt) VALUES (?, ?, ?)",
                    arguments: [strRecord.key, strRecord.value, strRecord.updatedAt]
                )
            }
            let fetchedStr: SettingRecord? = try db.read { db in
                try SettingRecord.filter(Column("key") == "username").fetchOne(db)
            }
            #expect(fetchedStr?.decode(String.self) == "seeker42")

            // Array
            let arrayRecord = try SettingRecord.create(key: "tags", value: ["jazz", "blues", "folk"])
            try db.write { db in
                try db.execute(
                    sql: "INSERT OR REPLACE INTO settings (key, value, updatedAt) VALUES (?, ?, ?)",
                    arguments: [arrayRecord.key, arrayRecord.value, arrayRecord.updatedAt]
                )
            }
            let fetchedArray: SettingRecord? = try db.read { db in
                try SettingRecord.filter(Column("key") == "tags").fetchOne(db)
            }
            #expect(fetchedArray?.decode([String].self) == ["jazz", "blues", "folk"])
        }
    }
}
