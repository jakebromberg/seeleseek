import Testing
@testable import SeeleseekCore

@Suite("FileTypes")
struct FileTypesTests {

    @Test("isAudio returns true for all audio extensions", arguments: [
        "mp3", "flac", "ogg", "m4a", "aac", "wav", "aiff", "aif", "alac", "wma", "ape"
    ])
    func audioExtensions(ext: String) {
        #expect(FileTypes.isAudio(ext))
    }

    @Test("isAudio returns false for non-audio extensions", arguments: [
        "jpg", "mp4", "zip", "txt", "", "doc", "pdf"
    ])
    func nonAudioExtensions(ext: String) {
        #expect(!FileTypes.isAudio(ext))
    }

    @Test("isLossless returns true for all lossless extensions", arguments: [
        "flac", "wav", "aiff", "aif", "alac", "ape"
    ])
    func losslessExtensions(ext: String) {
        #expect(FileTypes.isLossless(ext))
    }

    @Test("isLossless returns false for lossy audio", arguments: ["mp3", "ogg", "m4a", "aac", "wma"])
    func lossyNotLossless(ext: String) {
        #expect(!FileTypes.isLossless(ext))
    }

    @Test("isImage returns true for all image extensions", arguments: [
        "jpg", "jpeg", "png", "gif", "bmp", "webp"
    ])
    func imageExtensions(ext: String) {
        #expect(FileTypes.isImage(ext))
    }

    @Test("isVideo returns true for all video extensions", arguments: [
        "mp4", "mkv", "avi", "mov", "wmv"
    ])
    func videoExtensions(ext: String) {
        #expect(FileTypes.isVideo(ext))
    }

    @Test("isArchive returns true for all archive extensions", arguments: [
        "zip", "rar", "7z", "tar", "gz"
    ])
    func archiveExtensions(ext: String) {
        #expect(FileTypes.isArchive(ext))
    }

    @Test("Extensions are case-sensitive — uppercase not recognized")
    func caseSensitivity() {
        #expect(!FileTypes.isAudio("MP3"))
        #expect(!FileTypes.isAudio("Flac"))
        #expect(!FileTypes.isImage("JPG"))
        #expect(!FileTypes.isVideo("MP4"))
        #expect(!FileTypes.isArchive("ZIP"))
    }

    @Test("Empty string returns false for all type checks")
    func emptyString() {
        #expect(!FileTypes.isAudio(""))
        #expect(!FileTypes.isLossless(""))
        #expect(!FileTypes.isImage(""))
        #expect(!FileTypes.isVideo(""))
        #expect(!FileTypes.isArchive(""))
    }

    @Test("Categories are mutually exclusive for representative extensions")
    func mutualExclusivity() {
        // mp3 is audio but not image, video, or archive
        #expect(FileTypes.isAudio("mp3"))
        #expect(!FileTypes.isImage("mp3"))
        #expect(!FileTypes.isVideo("mp3"))
        #expect(!FileTypes.isArchive("mp3"))

        // jpg is image but not audio, video, or archive
        #expect(FileTypes.isImage("jpg"))
        #expect(!FileTypes.isAudio("jpg"))
        #expect(!FileTypes.isVideo("jpg"))
        #expect(!FileTypes.isArchive("jpg"))
    }
}
