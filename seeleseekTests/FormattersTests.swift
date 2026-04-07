import Testing
import Foundation
@testable import SeeleseekCore

@Suite("Formatters")
struct FormattersTests {

    // MARK: - ByteFormatter.format

    @Test("format bytes shows 0 B")
    func formatZeroBytes() {
        #expect(ByteFormatter.format(0) == "0 B")
    }

    @Test("format bytes below 1 KB shows bytes")
    func formatSmallBytes() {
        #expect(ByteFormatter.format(512) == "512 B")
    }

    @Test("format bytes at 1 KB boundary")
    func formatOneKB() {
        #expect(ByteFormatter.format(1024) == "1.0 KB")
    }

    @Test("format bytes at 1 MB")
    func formatOneMB() {
        #expect(ByteFormatter.format(1_048_576) == "1.0 MB")
    }

    @Test("format bytes at 1 GB")
    func formatOneGB() {
        #expect(ByteFormatter.format(1_073_741_824) == "1.0 GB")
    }

    @Test("format bytes at 1 TB")
    func formatOneTB() {
        #expect(ByteFormatter.format(1_099_511_627_776) == "1.0 TB")
    }

    @Test("format bytes with fractional value")
    func formatFractionalMB() {
        // 1.5 MB = 1,572,864
        #expect(ByteFormatter.format(1_572_864) == "1.5 MB")
    }

    // MARK: - ByteFormatter.formatSpeed

    @Test("formatSpeed shows 0 B/s")
    func formatZeroSpeed() {
        #expect(ByteFormatter.formatSpeed(Int64(0)) == "0 B/s")
    }

    @Test("formatSpeed shows KB/s")
    func formatKBSpeed() {
        #expect(ByteFormatter.formatSpeed(Int64(102_400)) == "100.0 KB/s")
    }

    @Test("formatSpeed UInt32 overload delegates correctly")
    func formatSpeedUInt32() {
        let result = ByteFormatter.formatSpeed(UInt32(102_400))
        #expect(result == "100.0 KB/s")
    }

    // MARK: - DateTimeFormatters.formatDuration

    @Test("formatDuration 0 seconds")
    func formatDurationZero() {
        #expect(DateTimeFormatters.formatDuration(0) == "0s")
    }

    @Test("formatDuration seconds only")
    func formatDurationSecondsOnly() {
        #expect(DateTimeFormatters.formatDuration(45) == "45s")
    }

    @Test("formatDuration minutes and seconds")
    func formatDurationMinutes() {
        #expect(DateTimeFormatters.formatDuration(65) == "1m 5s")
    }

    @Test("formatDuration hours and minutes")
    func formatDurationHours() {
        #expect(DateTimeFormatters.formatDuration(3661) == "1h 1m")
    }

    // MARK: - DateTimeFormatters.formatAudioDuration

    @Test("formatAudioDuration 0 seconds")
    func formatAudioZero() {
        #expect(DateTimeFormatters.formatAudioDuration(0) == "0:00")
    }

    @Test("formatAudioDuration 65 seconds")
    func formatAudio65s() {
        #expect(DateTimeFormatters.formatAudioDuration(65) == "1:05")
    }

    @Test("formatAudioDuration 3600 seconds (1 hour)")
    func formatAudio1h() {
        #expect(DateTimeFormatters.formatAudioDuration(3600) == "60:00")
    }

    @Test("formatAudioDuration single-digit seconds get zero-padded")
    func formatAudioPadding() {
        #expect(DateTimeFormatters.formatAudioDuration(61) == "1:01")
    }

    // MARK: - DateTimeFormatters locale-independent checks

    @Test("formatTime produces non-empty string")
    func formatTimeNonEmpty() {
        #expect(!DateTimeFormatters.formatTime(Date()).isEmpty)
    }

    @Test("formatDate produces non-empty string")
    func formatDateNonEmpty() {
        #expect(!DateTimeFormatters.formatDate(Date()).isEmpty)
    }

    @Test("formatDateTime produces non-empty string")
    func formatDateTimeNonEmpty() {
        #expect(!DateTimeFormatters.formatDateTime(Date()).isEmpty)
    }

    @Test("formatRelative produces non-empty string")
    func formatRelativeNonEmpty() {
        let oneHourAgo = Date().addingTimeInterval(-3600)
        #expect(!DateTimeFormatters.formatRelative(oneHourAgo).isEmpty)
    }

    @Test("formatDurationSince produces non-empty string")
    func formatDurationSinceNonEmpty() {
        let fiveMinAgo = Date().addingTimeInterval(-300)
        #expect(!DateTimeFormatters.formatDurationSince(fiveMinAgo).isEmpty)
    }

    // MARK: - CountryFormatter

    @Test("flag for US returns US flag emoji")
    func flagUS() {
        #expect(CountryFormatter.flag(for: "US") == "🇺🇸")
    }

    @Test("flag for GB returns GB flag emoji")
    func flagGB() {
        #expect(CountryFormatter.flag(for: "GB") == "🇬🇧")
    }

    @Test("flag for empty string returns empty")
    func flagEmpty() {
        #expect(CountryFormatter.flag(for: "") == "")
    }

    @Test("flag for single char returns empty")
    func flagSingleChar() {
        #expect(CountryFormatter.flag(for: "U") == "")
    }

    @Test("flag for three chars returns empty")
    func flagThreeChars() {
        #expect(CountryFormatter.flag(for: "USA") == "")
    }

    @Test("flag handles lowercase input by uppercasing")
    func flagLowercase() {
        #expect(CountryFormatter.flag(for: "us") == "🇺🇸")
    }

    // MARK: - NumberFormatters

    @Test("NumberFormatters.format Int produces non-empty string")
    func formatIntNonEmpty() {
        #expect(!NumberFormatters.format(1000).isEmpty)
    }

    @Test("NumberFormatters.format UInt32 produces non-empty string")
    func formatUInt32NonEmpty() {
        #expect(!NumberFormatters.format(UInt32(0)).isEmpty)
    }

    @Test("NumberFormatters.format UInt64 produces non-empty string")
    func formatUInt64NonEmpty() {
        #expect(!NumberFormatters.format(UInt64(1_000_000)).isEmpty)
    }
}
