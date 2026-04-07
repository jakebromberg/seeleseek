import Testing
import SwiftUI
@testable import seeleseek
@testable import SeeleseekCore

@Suite("DesignSystem and Settings Rendering Tests")
@MainActor
struct DesignSystemRenderingTests {

    // MARK: - Helper

    @MainActor
    private func renderView<V: View>(_ view: V) {
        let renderer = ImageRenderer(content: view.frame(width: 800, height: 600))
        let _ = renderer.cgImage
    }

    // MARK: - Theme: Colors

    @Test("SeeleColors static properties are accessible")
    func seeleColorsAccessible() {
        let _ = SeeleColors.background
        let _ = SeeleColors.surface
        let _ = SeeleColors.surfaceSecondary
        let _ = SeeleColors.surfaceElevated
        let _ = SeeleColors.accent
        let _ = SeeleColors.textPrimary
        let _ = SeeleColors.textSecondary
        let _ = SeeleColors.textTertiary
        let _ = SeeleColors.textOnAccent
        let _ = SeeleColors.success
        let _ = SeeleColors.warning
        let _ = SeeleColors.error
        let _ = SeeleColors.info
        let _ = SeeleColors.selectionBackground
        let _ = SeeleColors.selectionBorder
        let _ = SeeleColors.border
        let _ = SeeleColors.divider
        let _ = SeeleColors.shadowColor
        let _ = SeeleColors.shadowColorStrong
        let _ = SeeleColors.alphaSubtle
        let _ = SeeleColors.alphaLight
        let _ = SeeleColors.alphaMedium
        let _ = SeeleColors.alphaStrong
        let _ = SeeleColors.alphaHalf
    }

    @Test("Color hex initializer produces valid colors")
    func colorHexInit() {
        let color = Color(hex: 0xFF0B55)
        let _ = color
        let colorWithAlpha = Color(hex: 0x0D0D0D, alpha: 0.5)
        let _ = colorWithAlpha
    }

    // MARK: - Theme: Typography

    @Test("SeeleTypography static properties are accessible")
    func seeleTypographyAccessible() {
        let _ = SeeleTypography.logo
        let _ = SeeleTypography.largeTitle
        let _ = SeeleTypography.title
        let _ = SeeleTypography.title2
        let _ = SeeleTypography.title3
        let _ = SeeleTypography.headline
        let _ = SeeleTypography.body
        let _ = SeeleTypography.callout
        let _ = SeeleTypography.subheadline
        let _ = SeeleTypography.footnote
        let _ = SeeleTypography.caption
        let _ = SeeleTypography.caption2
        let _ = SeeleTypography.mono
        let _ = SeeleTypography.monoSmall
        let _ = SeeleTypography.monoXSmall
        let _ = SeeleTypography.monoXXSmall
        let _ = SeeleTypography.badgeText
        let _ = SeeleTypography.statusText
    }

    @Test("Typography view modifiers render")
    func typographyModifiers() {
        renderView(Text("Logo").seeleLogo())
        renderView(Text("Title").seeleTitle())
        renderView(Text("Headline").seeleHeadline())
        renderView(Text("Body").seeleBody())
        renderView(Text("Secondary").seeleSecondary())
        renderView(Text("Mono").seeleMono())
    }

    // MARK: - Theme: Spacing

    @Test("SeeleSpacing static properties are accessible")
    func seeleSpacingAccessible() {
        let _ = SeeleSpacing.xxs
        let _ = SeeleSpacing.xs
        let _ = SeeleSpacing.sm
        let _ = SeeleSpacing.md
        let _ = SeeleSpacing.lg
        let _ = SeeleSpacing.xl
        let _ = SeeleSpacing.xxl
        let _ = SeeleSpacing.xxxl
        let _ = SeeleSpacing.rowVertical
        let _ = SeeleSpacing.rowHorizontal
        let _ = SeeleSpacing.cardPadding
        let _ = SeeleSpacing.listRowPadding
        let _ = SeeleSpacing.sectionSpacing
        let _ = SeeleSpacing.tagSpacing
        let _ = SeeleSpacing.dividerSpacing
        let _ = SeeleSpacing.iconSizeXS
        let _ = SeeleSpacing.iconSizeSmall
        let _ = SeeleSpacing.iconSize
        let _ = SeeleSpacing.iconSizeMedium
        let _ = SeeleSpacing.iconSizeLarge
        let _ = SeeleSpacing.iconSizeXL
        let _ = SeeleSpacing.iconSizeHero
        let _ = SeeleSpacing.statusDotSmall
        let _ = SeeleSpacing.statusDot
        let _ = SeeleSpacing.statusDotLarge
        let _ = SeeleSpacing.radiusXS
        let _ = SeeleSpacing.radiusSM
        let _ = SeeleSpacing.radiusMD
        let _ = SeeleSpacing.radiusLG
        let _ = SeeleSpacing.radiusXL
        let _ = SeeleSpacing.rowHeight
        let _ = SeeleSpacing.inputHeight
        let _ = SeeleSpacing.buttonHeight
        let _ = SeeleSpacing.tabBarHeight
        let _ = SeeleSpacing.progressBarHeight
        let _ = SeeleSpacing.toggleWidth
        let _ = SeeleSpacing.toggleHeight
        let _ = SeeleSpacing.toggleCornerRadius
        let _ = SeeleSpacing.toggleKnobSize
        let _ = SeeleSpacing.toggleKnobOffset
        let _ = SeeleSpacing.strokeThin
        let _ = SeeleSpacing.strokeMedium
        let _ = SeeleSpacing.strokeThick
        let _ = SeeleSpacing.animationFast
        let _ = SeeleSpacing.animationStandard
        let _ = SeeleSpacing.animationSlow
        let _ = SeeleSpacing.scaleSmall
        let _ = SeeleSpacing.scaleMedium
        let _ = SeeleSpacing.scaleLarge
        let _ = SeeleSpacing.scaleHover
        let _ = SeeleSpacing.trackingWide
    }

    @Test("RoundedRectangle convenience shapes are accessible")
    func roundedRectConvenience() {
        let _ = RoundedRectangle.cardShape
        let _ = RoundedRectangle.buttonShape
        let _ = RoundedRectangle.badgeShape
        let _ = RoundedRectangle.tinyShape
        let _ = RoundedRectangle.continuous(8)
    }

    @Test("EdgeInsets presets are accessible")
    func edgeInsetsPresets() {
        let _ = EdgeInsets.seeleCard
        let _ = EdgeInsets.seeleListRow
    }

    @Test("View corner clipping modifiers render")
    func cornerClippingModifiers() {
        renderView(Color.red.continuousCorners(12))
        renderView(Color.red.cardCorners())
        renderView(Color.red.buttonCorners())
    }

    // MARK: - Theme: Shadows

    @Test("SeeleShadows static properties are accessible")
    func seeleShadowsAccessible() {
        let card = SeeleShadows.card
        #expect(card.radius == 8)
        let elevated = SeeleShadows.elevated
        #expect(elevated.radius == 16)
        let subtle = SeeleShadows.subtle
        #expect(subtle.radius == 4)
    }

    @Test("Shadow view modifiers render")
    func shadowModifiers() {
        renderView(Color.red.frame(width: 100, height: 100).seeleShadow(SeeleShadows.card))
        renderView(Color.red.frame(width: 100, height: 100).cardShadow())
        renderView(Color.red.frame(width: 100, height: 100).elevatedShadow())
    }

    // MARK: - Modifiers: CardStyle and HoverStyle

    @Test("CardStyle modifier renders")
    func cardStyleModifier() {
        renderView(
            Text("Card content")
                .cardStyle()
        )
    }

    @Test("CardStyle with custom parameters renders")
    func cardStyleCustomParams() {
        renderView(
            Text("Custom card")
                .cardStyle(padding: .seeleCard, cornerRadius: SeeleSpacing.radiusXL)
        )
    }

    @Test("HoverStyle modifier renders")
    func hoverStyleModifier() {
        renderView(
            Text("Hoverable")
                .hoverStyle()
        )
    }

    // MARK: - Buttons: PrimaryButton

    @Test("PrimaryButton renders")
    func primaryButton() {
        renderView(PrimaryButton("Connect") {})
    }

    @Test("PrimaryButton with icon renders")
    func primaryButtonWithIcon() {
        renderView(PrimaryButton("Connect", icon: "network") {})
    }

    @Test("PrimaryButton loading state renders")
    func primaryButtonLoading() {
        renderView(PrimaryButton("Loading...", isLoading: true) {})
    }

    // MARK: - Buttons: SecondaryButton

    @Test("SecondaryButton renders")
    func secondaryButton() {
        renderView(SecondaryButton("Cancel") {})
    }

    @Test("SecondaryButton with icon renders")
    func secondaryButtonWithIcon() {
        renderView(SecondaryButton("Cancel", icon: "xmark") {})
    }

    // MARK: - Buttons: IconButton

    @Test("IconButton renders")
    func iconButton() {
        renderView(IconButton(icon: "gear") {})
    }

    @Test("IconButton with custom size renders")
    func iconButtonCustomSize() {
        renderView(IconButton(icon: "magnifyingglass", size: 24) {})
    }

    // MARK: - Forms: SeeleTextFieldStyle

    @Test("SeeleTextFieldStyle renders")
    func seeleTextFieldStyle() {
        renderView(
            TextField("Placeholder", text: .constant("test"))
                .textFieldStyle(SeeleTextFieldStyle())
        )
    }

    // MARK: - Forms: SeeleToggleStyle

    @Test("SeeleToggleStyle on renders")
    func seeleToggleStyleOn() {
        renderView(
            Toggle("Toggle on", isOn: .constant(true))
                .toggleStyle(SeeleToggleStyle())
        )
    }

    @Test("SeeleToggleStyle off renders")
    func seeleToggleStyleOff() {
        renderView(
            Toggle("Toggle off", isOn: .constant(false))
                .toggleStyle(SeeleToggleStyle())
        )
    }

    // MARK: - Forms: SeeleFormSection

    @Test("SeeleFormSection renders")
    func seeleFormSection() {
        renderView(
            SeeleFormSection("Section Title") {
                Text("Content")
            }
        )
    }

    // MARK: - Forms: SeeleFormRow

    @Test("SeeleFormRow with divider renders")
    func seeleFormRowWithDivider() {
        renderView(
            SeeleFormRow {
                Text("Row content")
            }
        )
    }

    @Test("SeeleFormRow without divider renders")
    func seeleFormRowNoDivider() {
        renderView(
            SeeleFormRow(showDivider: false) {
                Text("Row content")
            }
        )
    }

    // MARK: - Layout: StandardCard

    @Test("StandardCard renders")
    func standardCard() {
        renderView(
            StandardCard {
                Text("Card content")
            }
        )
    }

    // MARK: - Layout: StandardEmptyState

    @Test("StandardEmptyState renders")
    func standardEmptyState() {
        renderView(
            StandardEmptyState(
                icon: "music.note.list",
                title: "No Results",
                subtitle: "Try a different search term"
            )
        )
    }

    @Test("StandardEmptyState with action renders")
    func standardEmptyStateWithAction() {
        renderView(
            StandardEmptyState(
                icon: "magnifyingglass",
                title: "No Results",
                subtitle: "Try a different query",
                actionTitle: "Clear Search"
            ) {}
        )
    }

    // MARK: - Layout: StandardListRow

    @Test("StandardListRow renders")
    func standardListRow() {
        renderView(
            StandardListRow {
                Text("Row content")
            }
        )
    }

    // MARK: - Layout: StandardMetadataBadge

    @Test("StandardMetadataBadge renders")
    func standardMetadataBadge() {
        renderView(StandardMetadataBadge("320 kbps"))
    }

    @Test("StandardMetadataBadge with color renders")
    func standardMetadataBadgeWithColor() {
        renderView(StandardMetadataBadge("FLAC", color: SeeleColors.success))
    }

    // MARK: - Layout: StandardProgressBar

    @Test("StandardProgressBar renders")
    func standardProgressBar() {
        renderView(StandardProgressBar(progress: 0.65))
    }

    @Test("StandardProgressBar with custom color renders")
    func standardProgressBarCustomColor() {
        renderView(StandardProgressBar(progress: 0.3, color: SeeleColors.success))
    }

    // MARK: - Layout: StandardSearchField

    @Test("StandardSearchField empty renders")
    func standardSearchFieldEmpty() {
        renderView(
            StandardSearchField(text: .constant(""), placeholder: "Search files...")
        )
    }

    @Test("StandardSearchField with text renders")
    func standardSearchFieldWithText() {
        renderView(
            StandardSearchField(text: .constant("Beatles"), placeholder: "Search files...")
        )
    }

    @Test("StandardSearchField loading renders")
    func standardSearchFieldLoading() {
        renderView(
            StandardSearchField(text: .constant("query"), isLoading: true)
        )
    }

    // MARK: - Layout: StandardSectionHeader

    @Test("StandardSectionHeader renders")
    func standardSectionHeader() {
        renderView(StandardSectionHeader("Downloads"))
    }

    @Test("StandardSectionHeader with count renders")
    func standardSectionHeaderWithCount() {
        renderView(StandardSectionHeader("Downloads", count: 42))
    }

    @Test("StandardSectionHeader with trailing renders")
    func standardSectionHeaderWithTrailing() {
        renderView(
            StandardSectionHeader("Uploads") {
                Text("Clear")
            }
        )
    }

    // MARK: - Layout: StandardStatBadge

    @Test("StandardStatBadge renders")
    func standardStatBadge() {
        renderView(StandardStatBadge("Downloads", value: "42"))
    }

    @Test("StandardStatBadge with icon and color renders")
    func standardStatBadgeWithIconAndColor() {
        renderView(StandardStatBadge("Uploads", value: "17", icon: "arrow.up", color: SeeleColors.accent))
    }

    // MARK: - Layout: StandardStatusDot

    @Test("StandardStatusDot online renders")
    func standardStatusDotOnline() {
        renderView(StandardStatusDot(isOnline: true))
    }

    @Test("StandardStatusDot offline renders")
    func standardStatusDotOffline() {
        renderView(StandardStatusDot(isOnline: false))
    }

    @Test("StandardStatusDot with BuddyStatus renders")
    func standardStatusDotBuddyStatus() {
        renderView(StandardStatusDot(status: .online))
        renderView(StandardStatusDot(status: .away))
        renderView(StandardStatusDot(status: .offline))
    }

    // MARK: - Layout: StandardToolbar

    @Test("StandardToolbar renders")
    func standardToolbar() {
        renderView(
            StandardToolbar {
                Text("Leading")
            } center: {
                Text("Center")
            } trailing: {
                Text("Trailing")
            }
        )
    }

    @Test("StandardToolbar empty renders")
    func standardToolbarEmpty() {
        renderView(StandardToolbar())
    }

    // MARK: - Layout: UnreadCountBadge

    @Test("UnreadCountBadge with count renders")
    func unreadCountBadgeWithCount() {
        renderView(UnreadCountBadge(count: 5))
    }

    @Test("UnreadCountBadge with zero renders")
    func unreadCountBadgeZero() {
        renderView(UnreadCountBadge(count: 0))
    }

    // MARK: - Layout: UserContextMenuItems

    @Test("UserContextMenuItems renders")
    func userContextMenuItems() {
        let appState = AppState()
        renderView(
            VStack {
                UserContextMenuItems(username: "testuser")
            }
            .environment(\.appState, appState)
        )
    }

    // MARK: - Status: ConnectionBadge

    @Test("ConnectionBadge renders all statuses")
    func connectionBadgeAllStatuses() {
        for status in ConnectionStatus.allCases {
            renderView(ConnectionBadge(status: status))
        }
    }

    @Test("ConnectionBadge without label renders")
    func connectionBadgeNoLabel() {
        renderView(ConnectionBadge(status: .connected, showLabel: false))
    }

    // MARK: - Status: DownloadStatusIcon

    @Test("DownloadStatusIcon renders all statuses")
    func downloadStatusIconAllStatuses() {
        renderView(DownloadStatusIcon(status: nil))
        renderView(DownloadStatusIcon(status: .queued))
        renderView(DownloadStatusIcon(status: .connecting))
        renderView(DownloadStatusIcon(status: .transferring))
        renderView(DownloadStatusIcon(status: .completed))
        renderView(DownloadStatusIcon(status: .failed))
        renderView(DownloadStatusIcon(status: .cancelled))
        renderView(DownloadStatusIcon(status: .waiting))
    }

    @Test("DownloadStatusIcon helpText returns correct text")
    func downloadStatusIconHelpText() {
        #expect(DownloadStatusIcon(status: nil).helpText == "Download file")
        #expect(DownloadStatusIcon(status: .transferring).helpText == "Downloading...")
        #expect(DownloadStatusIcon(status: .queued).helpText == "Queued for download")
        #expect(DownloadStatusIcon(status: .connecting).helpText == "Connecting...")
        #expect(DownloadStatusIcon(status: .completed).helpText == "Download complete")
        #expect(DownloadStatusIcon(status: .failed).helpText == "Download failed - click to retry")
        #expect(DownloadStatusIcon(status: .cancelled).helpText == "Download cancelled - click to retry")
    }

    @Test("DownloadStatusIcon isInProgress computed property")
    func downloadStatusIconIsInProgress() {
        #expect(DownloadStatusIcon(status: .transferring).isInProgress == true)
        #expect(DownloadStatusIcon(status: .queued).isInProgress == true)
        #expect(DownloadStatusIcon(status: .connecting).isInProgress == true)
        #expect(DownloadStatusIcon(status: .waiting).isInProgress == true)
        #expect(DownloadStatusIcon(status: .completed).isInProgress == false)
        #expect(DownloadStatusIcon(status: .failed).isInProgress == false)
        #expect(DownloadStatusIcon(status: nil).isInProgress == false)
    }

    @Test("DownloadStatusIcon hovered renders")
    func downloadStatusIconHovered() {
        renderView(DownloadStatusIcon(status: nil, isHovered: true))
    }

    // MARK: - Status: ProgressIndicator

    @Test("ProgressIndicator renders")
    func progressIndicator() {
        renderView(ProgressIndicator(progress: 0.65))
    }

    @Test("ProgressIndicator with percentage renders")
    func progressIndicatorWithPercentage() {
        renderView(ProgressIndicator(progress: 0.42, showPercentage: true))
    }

    // MARK: - Status: SpeedBadge

    @Test("SpeedBadge download renders")
    func speedBadgeDownload() {
        renderView(SpeedBadge(bytesPerSecond: 1_500_000, direction: .download))
    }

    @Test("SpeedBadge upload renders")
    func speedBadgeUpload() {
        renderView(SpeedBadge(bytesPerSecond: 256_000, direction: .upload))
    }

    // MARK: - Visualizations: AudioWaveform

    @Test("AudioWaveform playing renders")
    func audioWaveformPlaying() {
        renderView(
            AudioWaveform(isPlaying: true)
                .frame(width: 200, height: 40)
        )
    }

    @Test("AudioWaveform paused renders")
    func audioWaveformPaused() {
        renderView(
            AudioWaveform(isPlaying: false)
                .frame(width: 200, height: 40)
        )
    }

    // MARK: - Visualizations: BitrateDistribution

    @Test("BitrateDistribution empty renders")
    func bitrateDistributionEmpty() {
        renderView(
            BitrateDistribution(files: [])
                .frame(width: 400)
        )
    }

    @Test("BitrateDistribution with files renders")
    func bitrateDistributionWithFiles() {
        let files = [
            SharedFile(filename: "song.mp3", size: 8_000_000, bitrate: 320, duration: 240),
            SharedFile(filename: "song2.mp3", size: 4_000_000, bitrate: 128, duration: 180),
            SharedFile(filename: "song3.flac", size: 30_000_000, bitrate: 1411, duration: 300),
        ]
        renderView(
            BitrateDistribution(files: files)
                .frame(width: 400)
        )
    }

    // MARK: - Visualizations: FileTreemap

    @Test("FileTreemap empty renders")
    func fileTreemapEmpty() {
        renderView(
            FileTreemap(files: [])
                .frame(width: 400, height: 300)
        )
    }

    @Test("FileTreemap with files renders")
    func fileTreemapWithFiles() {
        let files = [
            SharedFile(filename: "Music\\song.mp3", size: 8_000_000, bitrate: 320, duration: 240),
            SharedFile(filename: "Music\\song.flac", size: 30_000_000, bitrate: 1411, duration: 300),
            SharedFile(filename: "Music\\image.jpg", size: 500_000),
        ]
        renderView(
            FileTreemap(files: files)
                .frame(width: 400, height: 300)
        )
    }

    // MARK: - Visualizations: FileTypeDistribution

    @Test("FileTypeDistribution empty renders")
    func fileTypeDistributionEmpty() {
        renderView(
            FileTypeDistribution(files: [])
                .frame(width: 400)
        )
    }

    @Test("FileTypeDistribution with files renders")
    func fileTypeDistributionWithFiles() {
        let files = [
            SharedFile(filename: "song.mp3", size: 8_000_000, bitrate: 320, duration: 240),
            SharedFile(filename: "song.flac", size: 30_000_000, bitrate: 1411, duration: 300),
            SharedFile(filename: "video.mp4", size: 500_000_000),
        ]
        renderView(
            FileTypeDistribution(files: files)
                .frame(width: 400)
        )
    }

    // MARK: - Visualizations: SizeComparisonBars

    @Test("SizeComparisonBars renders")
    func sizeComparisonBars() {
        renderView(
            SizeComparisonBars(items: [
                (label: "Music", size: 1_500_000_000),
                (label: "Videos", size: 800_000_000),
                (label: "Images", size: 200_000_000),
            ])
            .frame(width: 400)
        )
    }

    @Test("SizeComparisonBars empty renders")
    func sizeComparisonBarsEmpty() {
        renderView(
            SizeComparisonBars(items: [])
                .frame(width: 400)
        )
    }

    // MARK: - Visualizations: FlowLayout

    @Test("FlowLayout renders")
    func flowLayout() {
        renderView(
            FlowLayout(spacing: 8) {
                Text("Rock")
                Text("Jazz")
                Text("Electronic")
            }
            .frame(width: 300)
        )
    }

    // MARK: - Settings Components (shared functions)

    @Test("settingsHeader renders")
    func settingsHeaderRenders() {
        renderView(settingsHeader("General"))
    }

    @Test("settingsGroup renders")
    func settingsGroupRenders() {
        renderView(
            settingsGroup("Section") {
                Text("Content")
            }
        )
    }

    @Test("settingsRow renders")
    func settingsRowRenders() {
        renderView(
            settingsRow {
                Text("Row content")
            }
        )
    }

    @Test("settingsToggle renders")
    func settingsToggleRenders() {
        renderView(settingsToggle("Enable feature", isOn: .constant(true)))
    }

    @Test("settingsNumberField renders")
    func settingsNumberFieldRenders() {
        renderView(settingsNumberField("Port", value: .constant(2234), range: 1024...65535))
    }

    @Test("settingsStepper renders")
    func settingsStepperRenders() {
        renderView(settingsStepper("Max Slots", value: .constant(5), range: 1...20))
    }

    // MARK: - Settings: AboutSettingsSection

    @Test("AboutSettingsSection renders")
    func aboutSettingsSection() {
        renderView(AboutSettingsSection())
    }

    // MARK: - Settings: ChatSettingsSection

    @Test("ChatSettingsSection renders")
    func chatSettingsSection() {
        let settings = SettingsState()
        renderView(ChatSettingsSection(settings: settings))
    }

    // MARK: - Settings: GeneralSettingsSection

    @Test("GeneralSettingsSection renders")
    func generalSettingsSection() {
        let settings = SettingsState()
        renderView(GeneralSettingsSection(settings: settings))
    }

    // MARK: - Settings: MetadataSettingsSection

    @Test("MetadataSettingsSection renders")
    func metadataSettingsSection() {
        let settings = SettingsState()
        renderView(MetadataSettingsSection(settings: settings))
    }

    // MARK: - Settings: NetworkSettingsSection

    @Test("NetworkSettingsSection renders")
    func networkSettingsSection() {
        let settings = SettingsState()
        renderView(NetworkSettingsSection(settings: settings))
    }

    // MARK: - Settings: NotificationSettingsSection

    @Test("NotificationSettingsSection renders")
    func notificationSettingsSection() {
        let settings = SettingsState()
        renderView(NotificationSettingsSection(settings: settings))
    }

    // MARK: - Settings: PrivacySettingsSection

    @Test("PrivacySettingsSection renders")
    func privacySettingsSection() {
        let appState = AppState()
        renderView(
            PrivacySettingsSection(settings: appState.settings)
                .environment(\.appState, appState)
        )
    }

    // MARK: - Settings: SharesSettingsSection

    @Test("SharesSettingsSection renders")
    func sharesSettingsSection() {
        let appState = AppState()
        renderView(
            SharesSettingsSection(settings: appState.settings)
                .environment(\.appState, appState)
        )
    }

    // MARK: - Settings: DiagnosticsSection

    @Test("DiagnosticsSection renders")
    func diagnosticsSection() {
        let appState = AppState()
        renderView(
            DiagnosticsSection()
                .environment(\.appState, appState)
        )
    }

    // MARK: - Settings: SettingsView

    @Test("SettingsView renders")
    func settingsView() {
        let appState = AppState()
        renderView(
            SettingsView()
                .environment(\.appState, appState)
        )
    }

    // MARK: - Update: UpdateSettingsSection

    @Test("UpdateSettingsSection renders")
    func updateSettingsSection() {
        let updateState = UpdateState()
        renderView(UpdateSettingsSection(updateState: updateState))
    }

    // MARK: - Statistics: StatRow

    @Test("StatRow renders")
    func statRow() {
        renderView(StatRow(label: "Downloads", value: "42", color: SeeleColors.success))
    }

    // MARK: - Statistics: SpeedGaugeView

    @Test("SpeedGaugeView renders")
    func speedGaugeView() {
        renderView(
            SpeedGaugeView(
                title: "Download",
                currentSpeed: 500_000,
                maxSpeed: 1_000_000,
                color: SeeleColors.success
            )
        )
    }

    @Test("SpeedGaugeView zero speed renders")
    func speedGaugeViewZero() {
        renderView(
            SpeedGaugeView(
                title: "Upload",
                currentSpeed: 0,
                maxSpeed: 1_000_000,
                color: SeeleColors.accent
            )
        )
    }

    // MARK: - Statistics: SpeedChartView

    @Test("SpeedChartView empty renders")
    func speedChartViewEmpty() {
        renderView(
            SpeedChartView(samples: [], timeRange: 60)
                .frame(height: 200)
        )
    }

    @Test("SpeedChartView with data renders")
    func speedChartViewWithData() {
        let now = Date()
        let samples = (0..<10).map { i in
            StatisticsState.SpeedSample(
                timestamp: now.addingTimeInterval(-Double(10 - i)),
                downloadSpeed: Double.random(in: 50000...200000),
                uploadSpeed: Double.random(in: 10000...80000)
            )
        }
        renderView(
            SpeedChartView(samples: samples, timeRange: 60)
                .frame(height: 200)
        )
    }

    // MARK: - Statistics: ConnectionRingView

    @Test("ConnectionRingView renders")
    func connectionRingView() {
        renderView(
            ConnectionRingView(active: 5, total: 20, maxDisplay: 50)
                .frame(width: 80, height: 80)
        )
    }

    @Test("ConnectionRingView zero total renders")
    func connectionRingViewZeroTotal() {
        renderView(
            ConnectionRingView(active: 0, total: 0, maxDisplay: 50)
                .frame(width: 80, height: 80)
        )
    }

    // MARK: - Statistics: TransferRatioView

    @Test("TransferRatioView renders")
    func transferRatioView() {
        renderView(
            TransferRatioView(downloaded: 30, uploaded: 10)
                .frame(width: 80, height: 80)
        )
    }

    @Test("TransferRatioView zero renders")
    func transferRatioViewZero() {
        renderView(
            TransferRatioView(downloaded: 0, uploaded: 0)
                .frame(width: 80, height: 80)
        )
    }

    // MARK: - Statistics: PeerActivityHeatmap

    @Test("PeerActivityHeatmap empty renders")
    func peerActivityHeatmapEmpty() {
        renderView(
            PeerActivityHeatmap(downloadHistory: [], uploadHistory: [])
                .frame(height: 100)
        )
    }

    // MARK: - Statistics: NetworkTopologyView

    @Test("NetworkTopologyView empty renders")
    func networkTopologyViewEmpty() {
        renderView(
            NetworkTopologyView(connections: [], centerUsername: "TestUser")
                .frame(width: 400, height: 300)
        )
    }

    @Test("NetworkTopologyView with connections renders")
    func networkTopologyViewWithConnections() {
        let connections = [
            PeerConnectionPool.PeerConnectionInfo(
                id: "peer1",
                username: "musiclover",
                ip: "192.168.1.100",
                port: 2234,
                state: .connected,
                connectionType: .peer,
                bytesReceived: 1_000_000,
                bytesSent: 500_000,
                connectedAt: Date()
            ),
        ]
        renderView(
            NetworkTopologyView(connections: connections, centerUsername: "Me")
                .frame(width: 400, height: 300)
        )
    }

    // MARK: - Statistics: ConnectionLine

    @Test("ConnectionLine renders")
    func connectionLine() {
        renderView(
            ConnectionLine(
                from: CGPoint(x: 100, y: 100),
                to: CGPoint(x: 300, y: 300),
                isActive: true,
                traffic: 500_000
            )
            .frame(width: 400, height: 400)
        )
    }

    // MARK: - Statistics: CenterNode

    @Test("CenterNode renders")
    func centerNode() {
        renderView(CenterNode(username: "TestUser"))
    }

    // MARK: - Statistics: PeerNode

    @Test("PeerNode renders")
    func peerNode() {
        let info = PeerConnectionPool.PeerConnectionInfo(
            id: "peer1",
            username: "musiclover",
            ip: "192.168.1.100",
            port: 2234,
            state: .connected,
            connectionType: .peer,
            bytesReceived: 5_000_000
        )
        renderView(PeerNode(info: info, isSelected: false))
    }

    @Test("PeerNode selected renders")
    func peerNodeSelected() {
        let info = PeerConnectionPool.PeerConnectionInfo(
            id: "peer2",
            username: "jazzfan",
            ip: "10.0.0.55",
            port: 2235,
            state: .connecting,
            connectionType: .file
        )
        renderView(PeerNode(info: info, isSelected: true))
    }

    // MARK: - Statistics: PeerDetailPopover

    @Test("PeerDetailPopover renders")
    func peerDetailPopover() {
        let appState = AppState()
        let info = PeerConnectionPool.PeerConnectionInfo(
            id: "peer1",
            username: "musiclover",
            ip: "192.168.1.100",
            port: 2234,
            state: .connected,
            connectionType: .peer,
            bytesReceived: 45_000_000,
            bytesSent: 12_000_000,
            connectedAt: Date().addingTimeInterval(-3600),
            lastActivity: Date(),
            currentSpeed: 125_000
        )
        renderView(
            PeerDetailPopover(info: info)
                .environment(\.appState, appState)
        )
    }

    // MARK: - Statistics: PeerInfoPopover

    @Test("PeerInfoPopover renders")
    func peerInfoPopover() {
        let appState = AppState()
        let peer = PeerConnectionPool.PeerConnectionInfo(
            id: "peer1",
            username: "vinylcollector",
            ip: "10.0.0.55",
            port: 2235,
            state: .connected,
            connectionType: .peer,
            bytesReceived: 23_000_000,
            bytesSent: 5_000_000,
            connectedAt: Date().addingTimeInterval(-1800),
            lastActivity: Date().addingTimeInterval(-60),
            currentSpeed: 85_000
        )
        renderView(
            PeerInfoPopover(peer: peer)
                .environment(\.appState, appState)
        )
    }

    // MARK: - Statistics: PeerRow

    @Test("PeerRow renders")
    func peerRow() {
        let peer = PeerConnectionPool.PeerConnectionInfo(
            id: "peer1",
            username: "musiclover42",
            ip: "192.168.1.100",
            port: 2234,
            state: .connected,
            connectionType: .peer,
            bytesReceived: 45_000_000,
            bytesSent: 12_000_000,
            connectedAt: Date().addingTimeInterval(-3600),
            lastActivity: Date(),
            currentSpeed: 125_000
        )
        renderView(PeerRow(peer: peer))
    }

    // MARK: - Statistics: DetailRow

    @Test("DetailRow renders")
    func detailRow() {
        renderView(DetailRow(label: "IP Address", value: "192.168.1.100"))
    }

    // MARK: - Statistics: MonitorTabButton

    @Test("MonitorTabButton selected renders")
    func monitorTabButtonSelected() {
        renderView(MonitorTabButton(title: "Overview", icon: "gauge.with.dots.needle.bottom.50percent", isSelected: true, action: {}))
    }

    @Test("MonitorTabButton unselected renders")
    func monitorTabButtonUnselected() {
        renderView(MonitorTabButton(title: "Peers", icon: "person.2", isSelected: false, action: {}))
    }

    // MARK: - Statistics: MonitorLiveStatsBadge

    @Test("MonitorLiveStatsBadge renders")
    func monitorLiveStatsBadge() {
        renderView(
            MonitorLiveStatsBadge(downloadSpeed: 1_500_000, uploadSpeed: 300_000, peerCount: 12)
        )
    }

    // MARK: - Statistics: MonitorMetricCard

    @Test("MonitorMetricCard renders")
    func monitorMetricCard() {
        renderView(
            MonitorMetricCard(
                title: "Peers",
                value: "12",
                subtitle: "active connections",
                icon: "person.2.fill",
                color: SeeleColors.info
            )
        )
    }

    // MARK: - Statistics: HealthStatRow

    @Test("HealthStatRow renders")
    func healthStatRow() {
        renderView(HealthStatRow(label: "Active", value: "5", color: SeeleColors.success))
    }

    // MARK: - Statistics: QuickPeerRow

    @Test("QuickPeerRow renders")
    func quickPeerRow() {
        let peer = PeerConnectionPool.PeerConnectionInfo(
            id: "peer1",
            username: "musiclover",
            ip: "192.168.1.100",
            port: 2234,
            state: .connected,
            connectionType: .peer,
            bytesReceived: 5_000_000,
            bytesSent: 2_000_000
        )
        renderView(QuickPeerRow(peer: peer))
    }

    // MARK: - Statistics: LegendItem

    @Test("LegendItem renders")
    func legendItem() {
        renderView(LegendItem(color: SeeleColors.success, label: "Connected"))
    }

    // MARK: - Statistics: StatPill

    @Test("StatPill renders")
    func statPill() {
        renderView(StatPill(label: "Active", value: "12", color: SeeleColors.success))
    }

    // MARK: - Statistics: TransferHistoryRow

    @Test("TransferHistoryRow download renders")
    func transferHistoryRowDownload() {
        let entry = StatisticsState.TransferHistoryEntry(
            timestamp: Date(),
            filename: "Music\\Albums\\Artist\\01 - Track.flac",
            username: "musiclover",
            size: 30_000_000,
            duration: 15,
            averageSpeed: 2_000_000,
            isDownload: true
        )
        renderView(TransferHistoryRow(entry: entry))
    }

    @Test("TransferHistoryRow upload renders")
    func transferHistoryRowUpload() {
        let entry = StatisticsState.TransferHistoryEntry(
            timestamp: Date(),
            filename: "Music\\song.mp3",
            username: "jazzfan",
            size: 8_000_000,
            duration: 10,
            averageSpeed: 800_000,
            isDownload: false
        )
        renderView(TransferHistoryRow(entry: entry))
    }

    // MARK: - Statistics: Views with AppState environment

    @Test("StatisticsView renders")
    func statisticsView() {
        let appState = AppState()
        renderView(
            StatisticsView()
                .environment(\.appState, appState)
        )
    }

    @Test("NetworkMonitorView renders")
    func networkMonitorView() {
        let appState = AppState()
        renderView(
            NetworkMonitorView()
                .environment(\.appState, appState)
        )
    }

    @Test("NetworkOverviewTab renders")
    func networkOverviewTab() {
        let appState = AppState()
        renderView(
            NetworkOverviewTab()
                .environment(\.appState, appState)
        )
    }

    @Test("MonitorBandwidthChartCard renders")
    func monitorBandwidthChartCard() {
        let appState = AppState()
        renderView(
            MonitorBandwidthChartCard()
                .environment(\.appState, appState)
        )
    }

    @Test("MonitorConnectionHealthCard renders")
    func monitorConnectionHealthCard() {
        let appState = AppState()
        renderView(
            MonitorConnectionHealthCard()
                .environment(\.appState, appState)
        )
    }

    @Test("MonitorQuickPeersCard renders")
    func monitorQuickPeersCard() {
        let appState = AppState()
        renderView(
            MonitorQuickPeersCard()
                .environment(\.appState, appState)
        )
    }

    @Test("LiveActivityFeed renders")
    func liveActivityFeed() {
        let appState = AppState()
        renderView(
            LiveActivityFeed()
                .environment(\.appState, appState)
        )
    }

    @Test("LivePeersView renders")
    func livePeersView() {
        let appState = AppState()
        renderView(
            LivePeersView()
                .environment(\.appState, appState)
        )
    }

    @Test("PeerWorldMap renders")
    func peerWorldMap() {
        let appState = AppState()
        renderView(
            PeerWorldMap()
                .environment(\.appState, appState)
        )
    }

    @Test("SearchActivityView renders")
    func searchActivityView() {
        let appState = AppState()
        renderView(
            SearchActivityView()
                .environment(\.appState, appState)
        )
    }

    @Test("MonitorTransfersTab renders")
    func monitorTransfersTab() {
        let appState = AppState()
        renderView(
            MonitorTransfersTab()
                .environment(\.appState, appState)
        )
    }

    @Test("NetworkVisualizationView renders")
    func networkVisualizationView() {
        let appState = AppState()
        renderView(
            NetworkVisualizationView()
                .environment(\.appState, appState)
        )
    }

    // MARK: - Metadata: MetadataEditorSheet

    @Test("MetadataEditorSheet renders")
    func metadataEditorSheet() {
        let state = MetadataState()
        renderView(MetadataEditorSheet(state: state))
    }

    // MARK: - Metadata: CoverArtEditView

    @Test("CoverArtEditView empty state renders")
    func coverArtEditViewEmpty() {
        let state = MetadataState()
        renderView(
            CoverArtEditView(state: state)
                .frame(width: 300)
        )
    }

    // MARK: - Metadata: RecordingSearchResults

    @Test("RecordingSearchResults empty renders")
    func recordingSearchResultsEmpty() {
        let state = MetadataState()
        renderView(
            RecordingSearchResults(state: state)
                .frame(width: 400, height: 300)
        )
    }

    // MARK: - Statistics: SearchTimelineView

    @Test("SearchTimelineView empty renders")
    func searchTimelineViewEmpty() {
        renderView(
            SearchTimelineView(events: [])
                .frame(width: 400, height: 60)
        )
    }

    // MARK: - Statistics: NetworkRadialView

    @Test("NetworkRadialView empty renders")
    func networkRadialViewEmpty() {
        renderView(
            NetworkRadialView(peers: [])
                .frame(width: 400, height: 300)
        )
    }

    @Test("NetworkRadialView with peers renders")
    func networkRadialViewWithPeers() {
        let peers = [
            PeerConnectionPool.PeerConnectionInfo(
                id: "peer1",
                username: "musiclover",
                ip: "192.168.1.100",
                port: 2234,
                state: .connected,
                connectionType: .peer,
                bytesReceived: 5_000_000
            ),
            PeerConnectionPool.PeerConnectionInfo(
                id: "peer2",
                username: "jazzfan",
                ip: "10.0.0.55",
                port: 2235,
                state: .connecting,
                connectionType: .file
            ),
        ]
        renderView(
            NetworkRadialView(peers: peers)
                .frame(width: 400, height: 300)
        )
    }
}
