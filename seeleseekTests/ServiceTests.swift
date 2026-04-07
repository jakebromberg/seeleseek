import Testing
import Foundation
@testable import SeeleseekCore
@testable import seeleseek

// MARK: - URLResolverClient Tests

@Suite
struct URLResolverClientTests {

    // MARK: - detectService

    @Test("detectService: Spotify track URL")
    func detectSpotify() {
        let service = URLResolverClient.detectService(from: "https://open.spotify.com/track/abc123")
        #expect(service == .spotify)
    }

    @Test("detectService: Spotify track with locale")
    func detectSpotifyLocale() {
        let service = URLResolverClient.detectService(from: "https://open.spotify.com/intl-de/track/abc123")
        #expect(service == .spotify)
    }

    @Test("detectService: Apple Music track with i= parameter")
    func detectAppleMusicTrack() {
        let service = URLResolverClient.detectService(from: "https://music.apple.com/us/album/song-name/123?i=456")
        #expect(service == .appleMusic)
    }

    @Test("detectService: Apple Music song URL")
    func detectAppleMusicSong() {
        let service = URLResolverClient.detectService(from: "https://music.apple.com/us/song/track-name/123")
        #expect(service == .appleMusic)
    }

    @Test("detectService: Apple Music album-only URL returns nil")
    func detectAppleMusicAlbumOnly() {
        let service = URLResolverClient.detectService(from: "https://music.apple.com/us/album/album-name/123")
        #expect(service == nil)
    }

    @Test("detectService: YouTube watch URL")
    func detectYouTubeWatch() {
        let service = URLResolverClient.detectService(from: "https://www.youtube.com/watch?v=dQw4w9WgXcQ")
        #expect(service == .youtube)
    }

    @Test("detectService: YouTube short URL")
    func detectYouTubeShort() {
        let service = URLResolverClient.detectService(from: "https://youtu.be/dQw4w9WgXcQ")
        #expect(service == .youtube)
    }

    @Test("detectService: YouTube Music URL")
    func detectYouTubeMusic() {
        let service = URLResolverClient.detectService(from: "https://music.youtube.com/watch?v=abc123")
        #expect(service == .youtube)
    }

    @Test("detectService: SoundCloud track URL")
    func detectSoundCloud() {
        let service = URLResolverClient.detectService(from: "https://soundcloud.com/artist-name/track-name")
        #expect(service == .soundcloud)
    }

    @Test("detectService: SoundCloud profile (no track) returns nil")
    func detectSoundCloudProfileOnly() {
        let service = URLResolverClient.detectService(from: "https://soundcloud.com/artist-name")
        #expect(service == nil)
    }

    @Test("detectService: SoundCloud sets/playlists returns nil")
    func detectSoundCloudPlaylist() {
        let service = URLResolverClient.detectService(from: "https://soundcloud.com/artist-name/sets/playlist-name")
        #expect(service == nil)
    }

    @Test("detectService: Bandcamp track URL")
    func detectBandcamp() {
        let service = URLResolverClient.detectService(from: "https://artist.bandcamp.com/track/song-name")
        #expect(service == .bandcamp)
    }

    @Test("detectService: Bandcamp album (no track) returns nil")
    func detectBandcampAlbum() {
        let service = URLResolverClient.detectService(from: "https://artist.bandcamp.com/album/album-name")
        #expect(service == nil)
    }

    @Test("detectService: unsupported URL returns nil")
    func detectUnsupported() {
        #expect(URLResolverClient.detectService(from: "https://example.com") == nil)
        #expect(URLResolverClient.detectService(from: "https://google.com/search?q=music") == nil)
        #expect(URLResolverClient.detectService(from: "not even a url") == nil)
    }

    @Test("detectService: case-insensitive")
    func detectCaseInsensitive() {
        let service = URLResolverClient.detectService(from: "HTTPS://OPEN.SPOTIFY.COM/TRACK/ABC123")
        #expect(service == .spotify)
    }

    @Test("detectService: trims whitespace")
    func detectTrimsWhitespace() {
        let service = URLResolverClient.detectService(from: "  https://open.spotify.com/track/abc123  ")
        #expect(service == .spotify)
    }

    // MARK: - buildSearchQuery

    @Test("buildSearchQuery combines artist and title")
    func buildSearchQueryBasic() {
        let query = URLResolverClient.buildSearchQuery(artist: "Pink Floyd", title: "Comfortably Numb")
        #expect(query == "Pink Floyd Comfortably Numb")
    }

    @Test("buildSearchQuery strips feat. from title")
    func buildSearchQueryStripsFeat() {
        let query = URLResolverClient.buildSearchQuery(artist: "Artist", title: "Song (feat. Other)")
        #expect(query == "Artist Song")
    }

    @Test("buildSearchQuery strips ft. from title")
    func buildSearchQueryStripsFt() {
        let query = URLResolverClient.buildSearchQuery(artist: "Artist", title: "Song (ft. Other)")
        #expect(query == "Artist Song")
    }

    @Test("buildSearchQuery strips [feat. ...] brackets")
    func buildSearchQueryStripsBrackets() {
        let query = URLResolverClient.buildSearchQuery(artist: "Artist", title: "Song [feat. Other Artist]")
        #expect(query == "Artist Song")
    }

    @Test("buildSearchQuery strips featuring from title")
    func buildSearchQueryStripsFeaturing() {
        let query = URLResolverClient.buildSearchQuery(artist: "Artist", title: "Song (featuring Other)")
        #expect(query == "Artist Song")
    }

    @Test("buildSearchQuery handles empty artist")
    func buildSearchQueryEmptyArtist() {
        let query = URLResolverClient.buildSearchQuery(artist: "", title: "Just a Title")
        #expect(query == "Just a Title")
    }

    @Test("buildSearchQuery handles empty title")
    func buildSearchQueryEmptyTitle() {
        let query = URLResolverClient.buildSearchQuery(artist: "Artist", title: "")
        #expect(query == "Artist")
    }

    // MARK: - cleanTitle

    @Test("cleanTitle strips Official Music Video")
    func cleanTitleOfficialMusicVideo() {
        #expect(URLResolverClient.cleanTitle("Song (Official Music Video)") == "Song")
    }

    @Test("cleanTitle strips Official Video")
    func cleanTitleOfficialVideo() {
        #expect(URLResolverClient.cleanTitle("Song (Official Video)") == "Song")
    }

    @Test("cleanTitle strips Official Audio")
    func cleanTitleOfficialAudio() {
        #expect(URLResolverClient.cleanTitle("Song [Official Audio]") == "Song")
    }

    @Test("cleanTitle strips Lyric Video")
    func cleanTitleLyricVideo() {
        #expect(URLResolverClient.cleanTitle("Song (Lyric Video)") == "Song")
    }

    @Test("cleanTitle strips Official Lyric Video")
    func cleanTitleOfficialLyricVideo() {
        #expect(URLResolverClient.cleanTitle("Song [Official Lyric Video]") == "Song")
    }

    @Test("cleanTitle strips Official Visualizer")
    func cleanTitleOfficialVisualizer() {
        #expect(URLResolverClient.cleanTitle("Song (Official Visualizer)") == "Song")
    }

    @Test("cleanTitle strips Audio")
    func cleanTitleAudio() {
        #expect(URLResolverClient.cleanTitle("Song (Audio)") == "Song")
    }

    @Test("cleanTitle strips HD")
    func cleanTitleHD() {
        #expect(URLResolverClient.cleanTitle("Song (HD)") == "Song")
    }

    @Test("cleanTitle strips HQ")
    func cleanTitleHQ() {
        #expect(URLResolverClient.cleanTitle("Song [HQ]") == "Song")
    }

    @Test("cleanTitle strips 4K")
    func cleanTitle4K() {
        #expect(URLResolverClient.cleanTitle("Song (4K)") == "Song")
    }

    @Test("cleanTitle strips 4K Remastered")
    func cleanTitle4KRemastered() {
        #expect(URLResolverClient.cleanTitle("Song (4K Remastered)") == "Song")
    }

    @Test("cleanTitle strips 4K Remaster")
    func cleanTitle4KRemaster() {
        #expect(URLResolverClient.cleanTitle("Song [4K Remaster]") == "Song")
    }

    @Test("cleanTitle strips Music Video")
    func cleanTitleMusicVideo() {
        #expect(URLResolverClient.cleanTitle("Song [Music Video]") == "Song")
    }

    @Test("cleanTitle strips Explicit")
    func cleanTitleExplicit() {
        #expect(URLResolverClient.cleanTitle("Song (Explicit)") == "Song")
    }

    @Test("cleanTitle strips Visualizer")
    func cleanTitleVisualizer() {
        #expect(URLResolverClient.cleanTitle("Song [Visualizer]") == "Song")
    }

    @Test("cleanTitle is case-insensitive")
    func cleanTitleCaseInsensitive() {
        #expect(URLResolverClient.cleanTitle("Song (official music video)") == "Song")
        #expect(URLResolverClient.cleanTitle("Song (OFFICIAL AUDIO)") == "Song")
    }

    @Test("cleanTitle preserves unrelated parenthetical content")
    func cleanTitlePreservesOther() {
        let result = URLResolverClient.cleanTitle("Song (Remix)")
        #expect(result == "Song (Remix)")
    }

    @Test("cleanTitle strips multiple suffixes")
    func cleanTitleMultiple() {
        let result = URLResolverClient.cleanTitle("Song (Official Video) (HD)")
        #expect(result == "Song")
    }

    @Test("cleanTitle handles no suffixes gracefully")
    func cleanTitleNoSuffix() {
        #expect(URLResolverClient.cleanTitle("Just a Song") == "Just a Song")
    }

    // MARK: - MusicService rawValue

    @Test("MusicService raw values")
    func musicServiceRawValues() {
        #expect(URLResolverClient.MusicService.spotify.rawValue == "Spotify")
        #expect(URLResolverClient.MusicService.appleMusic.rawValue == "Apple Music")
        #expect(URLResolverClient.MusicService.youtube.rawValue == "YouTube")
        #expect(URLResolverClient.MusicService.soundcloud.rawValue == "SoundCloud")
        #expect(URLResolverClient.MusicService.bandcamp.rawValue == "Bandcamp")
    }

    // MARK: - ResolveError descriptions

    @Test("ResolveError descriptions are non-empty")
    func resolveErrorDescriptions() {
        let errors: [URLResolverClient.ResolveError] = [
            .unsupportedURL,
            .notATrack,
            .parseFailed("details"),
            .networkError(NSError(domain: "test", code: 0)),
        ]

        for error in errors {
            #expect(error.errorDescription != nil)
            #expect(!error.errorDescription!.isEmpty)
        }
    }

    @Test("ResolveError parseFailed includes detail")
    func resolveErrorParseFailed() {
        let error = URLResolverClient.ResolveError.parseFailed("no og:title")
        #expect(error.errorDescription!.contains("no og:title"))
    }
}

// MARK: - GitHubUpdateClient Tests

@Suite
struct GitHubUpdateClientTests {

    // MARK: - isVersion(_:newerThan:)

    @Test("isVersion: newer version returns true")
    func isVersionNewer() {
        #expect(GitHubUpdateClient.isVersion("v2.0.0", newerThan: "1.0.0"))
        #expect(GitHubUpdateClient.isVersion("v1.1.0", newerThan: "1.0.0"))
        #expect(GitHubUpdateClient.isVersion("v1.0.1", newerThan: "1.0.0"))
    }

    @Test("isVersion: same version returns false")
    func isVersionSame() {
        #expect(!GitHubUpdateClient.isVersion("v1.0.0", newerThan: "1.0.0"))
        #expect(!GitHubUpdateClient.isVersion("1.0.0", newerThan: "1.0.0"))
    }

    @Test("isVersion: older version returns false")
    func isVersionOlder() {
        #expect(!GitHubUpdateClient.isVersion("v0.9.0", newerThan: "1.0.0"))
        #expect(!GitHubUpdateClient.isVersion("v1.0.0", newerThan: "1.0.1"))
    }

    @Test("isVersion: strips v prefix")
    func isVersionStripsPrefix() {
        #expect(GitHubUpdateClient.isVersion("v2.0.0", newerThan: "v1.0.0"))
        #expect(GitHubUpdateClient.isVersion("2.0.0", newerThan: "v1.0.0"))
    }

    @Test("isVersion: handles different segment counts")
    func isVersionDifferentSegments() {
        #expect(GitHubUpdateClient.isVersion("v1.0.1", newerThan: "1.0"))
        #expect(!GitHubUpdateClient.isVersion("v1.0", newerThan: "1.0.1"))
    }

    @Test("isVersion: handles build numbers (4 segments)")
    func isVersionBuildNumbers() {
        #expect(GitHubUpdateClient.isVersion("v1.0.11.2", newerThan: "1.0.11.1"))
        #expect(!GitHubUpdateClient.isVersion("v1.0.11.1", newerThan: "1.0.11.2"))
    }

    @Test("isVersion: major version bump")
    func isVersionMajorBump() {
        #expect(GitHubUpdateClient.isVersion("v10.0.0", newerThan: "9.99.99"))
    }
}

// MARK: - UpdateError Tests

@Suite
struct UpdateErrorTests {

    @Test("all error cases have descriptions")
    func errorDescriptions() {
        let errors: [UpdateError] = [
            .invalidURL,
            .invalidResponse,
            .httpError(500),
            .noReleasesFound,
            .noStableRelease,
            .noPkgAsset,
            .downloadFailed,
        ]

        for error in errors {
            #expect(error.errorDescription != nil)
            #expect(!error.errorDescription!.isEmpty)
        }
    }

    @Test("httpError includes status code")
    func httpErrorCode() {
        let error = UpdateError.httpError(403)
        #expect(error.errorDescription!.contains("403"))
    }
}

// MARK: - MetadataError Tests

@Suite
struct MetadataErrorTests {

    @Test("all error cases have descriptions")
    func errorDescriptions() {
        let errors: [MetadataError] = [
            .invalidURL,
            .invalidResponse,
            .apiError(404),
            .noResults,
            .networkError(NSError(domain: "test", code: 0, userInfo: [NSLocalizedDescriptionKey: "timeout"])),
        ]

        for error in errors {
            #expect(error.errorDescription != nil)
            #expect(!error.errorDescription!.isEmpty)
        }
    }

    @Test("apiError includes code")
    func apiErrorCode() {
        let error = MetadataError.apiError(503)
        #expect(error.errorDescription!.contains("503"))
    }

    @Test("networkError includes underlying description")
    func networkErrorDescription() {
        let error = MetadataError.networkError(NSError(domain: "test", code: 0, userInfo: [NSLocalizedDescriptionKey: "timed out"]))
        #expect(error.errorDescription!.contains("timed out"))
    }
}

// MARK: - MusicBrainzClient Type Tests

@Suite
struct MusicBrainzClientTypeTests {

    @Test("MBRecording durationSeconds converts milliseconds")
    func mbRecordingDurationSeconds() {
        let recording = MusicBrainzClient.MBRecording(
            id: "abc",
            title: "Song",
            artist: "Artist",
            artistMBID: nil,
            releaseTitle: nil,
            releaseMBID: nil,
            duration: 240_000,
            score: 95
        )

        #expect(recording.durationSeconds == 240)
    }

    @Test("MBRecording durationSeconds nil when duration is nil")
    func mbRecordingDurationSecondsNil() {
        let recording = MusicBrainzClient.MBRecording(
            id: "abc",
            title: "Song",
            artist: "Artist",
            artistMBID: nil,
            releaseTitle: nil,
            releaseMBID: nil,
            duration: nil,
            score: 50
        )

        #expect(recording.durationSeconds == nil)
    }

    @Test("MBRecording is Identifiable")
    func mbRecordingIdentifiable() {
        let recording = MusicBrainzClient.MBRecording(
            id: "unique-id",
            title: "Song",
            artist: "Artist",
            artistMBID: "artist-id",
            releaseTitle: "Album",
            releaseMBID: "release-id",
            duration: 180_000,
            score: 80
        )

        #expect(recording.id == "unique-id")
        #expect(recording.title == "Song")
        #expect(recording.artist == "Artist")
        #expect(recording.artistMBID == "artist-id")
        #expect(recording.releaseTitle == "Album")
        #expect(recording.releaseMBID == "release-id")
        #expect(recording.score == 80)
    }

    @Test("MBRelease stores all fields")
    func mbRelease() {
        let track = MusicBrainzClient.MBTrack(
            id: "track-1",
            position: 1,
            title: "Track One",
            duration: 200_000
        )

        let release = MusicBrainzClient.MBRelease(
            id: "release-id",
            title: "Album Name",
            artist: "Artist",
            artistMBID: "artist-id",
            date: "2024-01-15",
            country: "US",
            trackCount: 12,
            tracks: [track]
        )

        #expect(release.id == "release-id")
        #expect(release.title == "Album Name")
        #expect(release.artist == "Artist")
        #expect(release.date == "2024-01-15")
        #expect(release.country == "US")
        #expect(release.trackCount == 12)
        #expect(release.tracks.count == 1)
    }

    @Test("MBTrack stores all fields")
    func mbTrack() {
        let track = MusicBrainzClient.MBTrack(
            id: "track-1",
            position: 3,
            title: "Track Three",
            duration: 180_000
        )

        #expect(track.id == "track-1")
        #expect(track.position == 3)
        #expect(track.title == "Track Three")
        #expect(track.duration == 180_000)
    }

    @Test("MBTrack with nil duration")
    func mbTrackNilDuration() {
        let track = MusicBrainzClient.MBTrack(
            id: "track-1",
            position: 1,
            title: "Track",
            duration: nil
        )

        #expect(track.duration == nil)
    }

    // MARK: - SearchResponse Decodable

    @Test("SearchResponse decodes from JSON")
    func searchResponseDecode() throws {
        let json = """
        {
            "count": 1,
            "recordings": [
                {
                    "id": "abc-123",
                    "title": "Comfortably Numb",
                    "score": 95,
                    "length": 382000,
                    "artist-credit": [
                        {
                            "name": "Pink Floyd",
                            "artist": { "id": "artist-1", "name": "Pink Floyd" }
                        }
                    ],
                    "releases": [
                        { "id": "release-1", "title": "The Wall" }
                    ]
                }
            ]
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(MusicBrainzClient.SearchResponse.self, from: json)

        #expect(response.count == 1)
        #expect(response.recordings?.count == 1)
        #expect(response.recordings?[0].title == "Comfortably Numb")
        #expect(response.recordings?[0].score == 95)
        #expect(response.recordings?[0].length == 382000)
        #expect(response.recordings?[0].artistCredit?.first?.name == "Pink Floyd")
        #expect(response.recordings?[0].releases?.first?.title == "The Wall")
    }

    @Test("SearchResponse decodes with nil recordings")
    func searchResponseDecodeNilRecordings() throws {
        let json = """
        { "count": 0 }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(MusicBrainzClient.SearchResponse.self, from: json)

        #expect(response.count == 0)
        #expect(response.recordings == nil)
    }

    // MARK: - ReleaseResponse Decodable

    @Test("ReleaseResponse decodes from JSON")
    func releaseResponseDecode() throws {
        let json = """
        {
            "id": "release-1",
            "title": "The Wall",
            "date": "1979-11-30",
            "country": "GB",
            "artist-credit": [
                {
                    "name": "Pink Floyd",
                    "artist": { "id": "artist-1", "name": "Pink Floyd" }
                }
            ],
            "media": [
                {
                    "position": 1,
                    "tracks": [
                        { "id": "track-1", "position": 1, "title": "In the Flesh?", "length": 195000 },
                        { "id": "track-2", "position": 2, "title": "The Thin Ice", "length": 146000 }
                    ]
                }
            ]
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(MusicBrainzClient.ReleaseResponse.self, from: json)

        #expect(response.id == "release-1")
        #expect(response.title == "The Wall")
        #expect(response.date == "1979-11-30")
        #expect(response.country == "GB")
        #expect(response.artistCredit?.first?.name == "Pink Floyd")
        #expect(response.media?.count == 1)
        #expect(response.media?[0].tracks?.count == 2)
        #expect(response.media?[0].tracks?[0].title == "In the Flesh?")
    }
}

// MARK: - CoverArtArchive Type Tests

@Suite
struct CoverArtArchiveTypeTests {

    @Test("CoverArtResponse decodes from JSON")
    func coverArtResponseDecode() throws {
        let json = """
        {
            "release": "https://musicbrainz.org/release/abc",
            "images": [
                {
                    "id": 12345,
                    "image": "https://coverartarchive.org/release/abc/12345.jpg",
                    "front": true,
                    "back": false,
                    "types": ["Front"],
                    "thumbnails": {
                        "small": "https://coverartarchive.org/release/abc/12345-250.jpg",
                        "large": "https://coverartarchive.org/release/abc/12345-500.jpg",
                        "250": "https://coverartarchive.org/release/abc/12345-250.jpg",
                        "500": "https://coverartarchive.org/release/abc/12345-500.jpg",
                        "1200": "https://coverartarchive.org/release/abc/12345-1200.jpg"
                    }
                }
            ]
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(CoverArtArchive.CoverArtResponse.self, from: json)

        #expect(response.release == "https://musicbrainz.org/release/abc")
        #expect(response.images.count == 1)
        #expect(response.images[0].id == 12345)
        #expect(response.images[0].front == true)
        #expect(response.images[0].back == false)
        #expect(response.images[0].types == ["Front"])
        #expect(response.images[0].thumbnails.small != nil)
        #expect(response.images[0].thumbnails.large != nil)
        #expect(response.images[0].thumbnails._250 != nil)
        #expect(response.images[0].thumbnails._500 != nil)
        #expect(response.images[0].thumbnails._1200 != nil)
    }

    @Test("CoverArtResponse decodes with minimal thumbnails")
    func coverArtResponseMinimalThumbnails() throws {
        let json = """
        {
            "release": "https://musicbrainz.org/release/abc",
            "images": [
                {
                    "id": 99,
                    "image": "https://example.com/full.jpg",
                    "front": false,
                    "back": true,
                    "types": ["Back"],
                    "thumbnails": {}
                }
            ]
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(CoverArtArchive.CoverArtResponse.self, from: json)

        #expect(response.images[0].thumbnails.small == nil)
        #expect(response.images[0].thumbnails.large == nil)
        #expect(response.images[0].thumbnails._250 == nil)
        #expect(response.images[0].thumbnails._500 == nil)
        #expect(response.images[0].thumbnails._1200 == nil)
    }

    @Test("ImageSize enum variants exist")
    func imageSizeVariants() {
        // Just confirm they compile and can be used
        let sizes: [CoverArtArchive.ImageSize] = [.small, .medium, .large, .full]
        #expect(sizes.count == 4)
    }
}

// MARK: - GitHubRelease / GitHubAsset Tests

@Suite
struct GitHubReleaseTests {

    @Test("GitHubRelease decodes from JSON")
    func decodable() throws {
        let json = """
        {
            "tag_name": "v1.0.11",
            "name": "SeeleSeek v1.0.11",
            "body": "Bug fixes and performance improvements",
            "html_url": "https://github.com/bretth18/seeleseek/releases/tag/v1.0.11",
            "prerelease": false,
            "draft": false,
            "assets": [
                {
                    "name": "SeeleSeek-1.0.11.pkg",
                    "browser_download_url": "https://github.com/bretth18/seeleseek/releases/download/v1.0.11/SeeleSeek-1.0.11.pkg",
                    "size": 15000000,
                    "content_type": "application/x-newton-compatible-pkg"
                }
            ]
        }
        """.data(using: .utf8)!

        let release = try JSONDecoder().decode(GitHubRelease.self, from: json)

        #expect(release.tagName == "v1.0.11")
        #expect(release.name == "SeeleSeek v1.0.11")
        #expect(release.body == "Bug fixes and performance improvements")
        #expect(release.htmlUrl == "https://github.com/bretth18/seeleseek/releases/tag/v1.0.11")
        #expect(!release.prerelease)
        #expect(!release.draft)
        #expect(release.assets.count == 1)
    }

    @Test("GitHubRelease encodes and decodes round-trip")
    func roundTrip() throws {
        let original = GitHubRelease(
            tagName: "v2.0.0",
            name: "v2.0.0",
            body: "Major update",
            htmlUrl: "https://example.com",
            assets: [],
            prerelease: false,
            draft: false
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(GitHubRelease.self, from: data)

        #expect(decoded.tagName == original.tagName)
        #expect(decoded.name == original.name)
        #expect(decoded.body == original.body)
        #expect(decoded.htmlUrl == original.htmlUrl)
        #expect(decoded.prerelease == original.prerelease)
        #expect(decoded.draft == original.draft)
    }

    @Test("GitHubRelease with nil body")
    func nilBody() throws {
        let json = """
        {
            "tag_name": "v1.0.0",
            "name": "v1.0.0",
            "body": null,
            "html_url": "https://example.com",
            "prerelease": true,
            "draft": true,
            "assets": []
        }
        """.data(using: .utf8)!

        let release = try JSONDecoder().decode(GitHubRelease.self, from: json)

        #expect(release.body == nil)
        #expect(release.prerelease)
        #expect(release.draft)
        #expect(release.assets.isEmpty)
    }
}

@Suite
struct GitHubAssetTests {

    @Test("GitHubAsset decodes from JSON")
    func decodable() throws {
        let json = """
        {
            "name": "SeeleSeek-1.0.11.pkg",
            "browser_download_url": "https://github.com/download/SeeleSeek.pkg",
            "size": 15728640,
            "content_type": "application/x-newton-compatible-pkg"
        }
        """.data(using: .utf8)!

        let asset = try JSONDecoder().decode(GitHubAsset.self, from: json)

        #expect(asset.name == "SeeleSeek-1.0.11.pkg")
        #expect(asset.browserDownloadUrl == "https://github.com/download/SeeleSeek.pkg")
        #expect(asset.size == 15728640)
        #expect(asset.contentType == "application/x-newton-compatible-pkg")
    }

    @Test("GitHubAsset encodes and decodes round-trip")
    func roundTrip() throws {
        let original = GitHubAsset(
            name: "test.dmg",
            browserDownloadUrl: "https://example.com/test.dmg",
            size: 1024,
            contentType: "application/x-apple-diskimage"
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(GitHubAsset.self, from: data)

        #expect(decoded.name == original.name)
        #expect(decoded.browserDownloadUrl == original.browserDownloadUrl)
        #expect(decoded.size == original.size)
        #expect(decoded.contentType == original.contentType)
    }

    @Test("GitHubRelease finding pkg asset")
    func findPkgAsset() throws {
        let json = """
        {
            "tag_name": "v1.0.0",
            "name": "v1.0.0",
            "body": null,
            "html_url": "https://example.com",
            "prerelease": false,
            "draft": false,
            "assets": [
                { "name": "source.tar.gz", "browser_download_url": "https://example.com/source.tar.gz", "size": 1000, "content_type": "application/gzip" },
                { "name": "SeeleSeek-1.0.0.pkg", "browser_download_url": "https://example.com/SeeleSeek.pkg", "size": 5000, "content_type": "application/pkg" }
            ]
        }
        """.data(using: .utf8)!

        let release = try JSONDecoder().decode(GitHubRelease.self, from: json)
        let pkgAsset = release.assets.first { $0.name.hasSuffix(".pkg") }

        #expect(pkgAsset != nil)
        #expect(pkgAsset?.name == "SeeleSeek-1.0.0.pkg")
    }
}

// MARK: - ConnectionStatus+UI Tests

@Suite
struct ConnectionStatusUITests {

    @Test("all statuses have non-empty label and icon")
    func allStatusesHaveLabelAndIcon() {
        for status in ConnectionStatus.allCases {
            #expect(!status.label.isEmpty)
            #expect(!status.icon.isEmpty)
        }
    }

    @Test("specific labels are correct")
    func specificLabels() {
        #expect(ConnectionStatus.disconnected.label == "Disconnected")
        #expect(ConnectionStatus.connecting.label == "Connecting...")
        #expect(ConnectionStatus.connected.label == "Connected")
        #expect(ConnectionStatus.reconnecting.label == "Reconnecting...")
        #expect(ConnectionStatus.error.label == "Error")
    }

    @Test("specific icons are correct")
    func specificIcons() {
        #expect(ConnectionStatus.disconnected.icon == "circle.slash")
        #expect(ConnectionStatus.connecting.icon == "arrow.triangle.2.circlepath")
        #expect(ConnectionStatus.connected.icon == "checkmark.circle.fill")
        #expect(ConnectionStatus.reconnecting.icon == "arrow.triangle.2.circlepath")
        #expect(ConnectionStatus.error.icon == "exclamationmark.triangle.fill")
    }
}

// MARK: - SharedFile+UI Tests

@Suite
struct SharedFileUITests {

    @Test("directory icon is folder.fill")
    func directoryIcon() {
        let file = SharedFile(filename: "Music", isDirectory: true)
        #expect(file.icon == "folder.fill")
    }

    @Test("audio file icon is music.note")
    func audioFileIcon() {
        let file = SharedFile(filename: "song.mp3")
        #expect(file.icon == "music.note")
    }

    @Test("image file icon is photo")
    func imageFileIcon() {
        let file = SharedFile(filename: "cover.jpg")
        #expect(file.icon == "photo")
    }

    @Test("video file icon is film")
    func videoFileIcon() {
        let file = SharedFile(filename: "video.mp4")
        #expect(file.icon == "film")
    }

    @Test("archive file icon is archivebox")
    func archiveFileIcon() {
        let file = SharedFile(filename: "archive.zip")
        #expect(file.icon == "archivebox")
    }

    @Test("generic file icon is doc")
    func genericFileIcon() {
        let file = SharedFile(filename: "readme.txt")
        #expect(file.icon == "doc")
    }
}

// MARK: - Transfer+UI Tests

@Suite
struct TransferUITests {

    @Test("transfer statusColor exists for all statuses")
    func statusColorExists() {
        let statuses: [Transfer.TransferStatus] = [
            .queued, .waiting, .connecting, .transferring, .completed, .failed, .cancelled
        ]
        for status in statuses {
            let transfer = Transfer(
                username: "alice",
                filename: "song.mp3",
                size: 1000,
                direction: .download,
                status: status
            )
            // Just verify it doesn't crash
            _ = transfer.statusColor
        }
    }

    @Test("TransferStatus icon for all statuses")
    func statusIcons() {
        #expect(Transfer.TransferStatus.queued.icon == "clock")
        #expect(Transfer.TransferStatus.connecting.icon == "arrow.triangle.2.circlepath")
        #expect(Transfer.TransferStatus.transferring.icon == "arrow.down")
        #expect(Transfer.TransferStatus.completed.icon == "checkmark.circle.fill")
        #expect(Transfer.TransferStatus.failed.icon == "exclamationmark.triangle.fill")
        #expect(Transfer.TransferStatus.cancelled.icon == "xmark.circle")
        #expect(Transfer.TransferStatus.waiting.icon == "hourglass")
    }

    @Test("TransferStatus displayText for all statuses")
    func statusDisplayText() {
        #expect(Transfer.TransferStatus.queued.displayText == "Queued")
        #expect(Transfer.TransferStatus.connecting.displayText == "Connecting to peer...")
        #expect(Transfer.TransferStatus.transferring.displayText == "Transferring")
        #expect(Transfer.TransferStatus.completed.displayText == "Completed")
        #expect(Transfer.TransferStatus.failed.displayText == "Failed")
        #expect(Transfer.TransferStatus.cancelled.displayText == "Cancelled")
        #expect(Transfer.TransferStatus.waiting.displayText == "Waiting in remote queue")
    }
}

// MARK: - User+UI Tests

@Suite
struct UserUITests {

    @Test("statusIcon for offline")
    func statusIconOffline() {
        let user = User(username: "alice", status: .offline)
        #expect(user.statusIcon == "circle.slash")
    }

    @Test("statusIcon for away")
    func statusIconAway() {
        let user = User(username: "alice", status: .away)
        #expect(user.statusIcon == "moon.fill")
    }

    @Test("statusIcon for online")
    func statusIconOnline() {
        let user = User(username: "alice", status: .online)
        #expect(user.statusIcon == "circle.fill")
    }
}

// MARK: - ResolvedTrack Tests

@Suite
struct ResolvedTrackTests {

    @Test("ResolvedTrack stores all fields")
    func storesFields() {
        let track = URLResolverClient.ResolvedTrack(
            artist: "Pink Floyd",
            title: "Comfortably Numb",
            source: .spotify
        )

        #expect(track.artist == "Pink Floyd")
        #expect(track.title == "Comfortably Numb")
        #expect(track.source == .spotify)
    }
}
