// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'OmniTune';

  @override
  String get homeTabLabel => 'Home';

  @override
  String get albumsTabLabel => 'Albums';

  @override
  String get collectionTabLabel => 'Collection';

  @override
  String get settingsTabLabel => 'Settings';

  @override
  String get settingsPageTitle => 'Settings';

  @override
  String get openSettingsAction => 'Open settings';

  @override
  String get settingsCenterHeadline => 'Tune the app your way';

  @override
  String get settingsCenterDescription =>
      'Adjust appearance, language, sources, cache behavior, and playback preferences from one control center.';

  @override
  String get appearanceSettingsTitle => 'Appearance';

  @override
  String get librarySettingsTitle => 'Library and sources';

  @override
  String get languageSettingTitle => 'Language';

  @override
  String get themeSettingTitle => 'Theme';

  @override
  String get themeAccentColorSettingTitle => 'Accent color';

  @override
  String get themeAccentColorDefaultLabel => 'System default';

  @override
  String get themeBorderRadiusSettingTitle => 'Corner radius';

  @override
  String get themeCompactnessSettingTitle => 'Density';

  @override
  String get backgroundImageSettingTitle => 'Background image';

  @override
  String get backgroundImageDefaultSummary =>
      'Using the default gradient background';

  @override
  String get backgroundImageConfiguredSummary =>
      'Custom background image configured';

  @override
  String get backgroundImageDialogTitle => 'Set background image';

  @override
  String get backgroundImageDialogDescription =>
      'Choose an image as the background for every page. The player keeps its cover-focused atmosphere while a track is playing.';

  @override
  String get backgroundImagePositionHelpText =>
      'Drag the preview to choose which part of the image appears at the current screen ratio.';

  @override
  String get backgroundImageChooseAction => 'Choose image';

  @override
  String get backgroundImageChangeAction => 'Change image';

  @override
  String get backgroundImageClearAction => 'Clear background';

  @override
  String get backgroundImageCenterAction => 'Center';

  @override
  String get backgroundImageEmptyPreview => 'No background image selected yet';

  @override
  String get backgroundImageFileTypeLabel => 'Images';

  @override
  String get themeColorDialogTitle => 'Choose accent color';

  @override
  String get themeColorPresetLabel => 'Preset colors';

  @override
  String get themeColorHexFieldLabel => 'Hex color';

  @override
  String get themeColorHexFieldHint => 'Enter a value like #FF5722';

  @override
  String get themeBorderRadiusDialogTitle => 'Corner radius';

  @override
  String get themeBorderRadiusRangeLabel => 'Range: 12.0 - 32.0px';

  @override
  String get themeCompactnessDialogTitle => 'Density';

  @override
  String get themeCompactnessRangeLabel => '50% (compact) - 150% (comfortable)';

  @override
  String get interfaceSizeSettingTitle => 'Interface size';

  @override
  String get fontSizeSettingTitle => 'Font size';

  @override
  String interfaceScaleSummary(int percent) {
    return '$percent% component size';
  }

  @override
  String fontScaleSummary(int percent) {
    return '$percent% text size';
  }

  @override
  String get interfaceSizeDialogDescription =>
      'Drag to enlarge or shrink cards, buttons, spacing, and overall interface density.';

  @override
  String get fontSizeDialogDescription =>
      'Drag to adjust text size across the whole app.';

  @override
  String scalePercentLabel(int percent) {
    return '$percent%';
  }

  @override
  String scaleRangeLabel(int min, int max) {
    return 'Range: $min% - $max%';
  }

  @override
  String get sourceManagementSettingTitle => 'Music sources';

  @override
  String get songFolderArtworkSettingTitle =>
      'Use folder image for song covers';

  @override
  String get songFolderArtworkSettingDescription =>
      'When a song has no embedded artwork, use cover or folder images from the same directory.';

  @override
  String get groupAlbumsByArtistSettingTitle =>
      'Group album-tag view by artist';

  @override
  String get groupAlbumsByArtistSettingDescription =>
      'When enabled, album-tag mode groups by album name and artist. When disabled, it groups only by album name.';

  @override
  String get sourceManagementDialogDescription =>
      'Choose the source used by remote browsing, keep adding more sources, and scan every saved source into one shared library.';

  @override
  String get sourceManagementEmptyTitle => 'No music sources yet';

  @override
  String get sourceManagementEmptySummary =>
      'Add a music source to start browsing and scanning your library.';

  @override
  String sourceManagementSummary(Object sourceName, int count) {
    return 'Browser: $sourceName · $count saved';
  }

  @override
  String savedSourcesCountLabel(int count) {
    return '$count sources';
  }

  @override
  String get languageOptionSystem => 'Follow system';

  @override
  String get languageOptionEnglish => 'English';

  @override
  String get languageOptionChinese => 'Chinese';

  @override
  String get themeOptionSystem => 'Follow system';

  @override
  String get themeOptionLight => 'Light';

  @override
  String get themeOptionDark => 'Dark';

  @override
  String get interfaceSizeOptionCompact => 'Compact';

  @override
  String get interfaceSizeOptionStandard => 'Standard';

  @override
  String get interfaceSizeOptionComfortable => 'Comfortable';

  @override
  String get fontSizeOptionSmall => 'Small';

  @override
  String get fontSizeOptionStandard => 'Standard';

  @override
  String get fontSizeOptionLarge => 'Large';

  @override
  String get fontSizeOptionExtraLarge => 'Extra large';

  @override
  String get libraryTitle => 'Library';

  @override
  String get addSourceAction => 'Add source';

  @override
  String get playerTitle => 'Now playing';

  @override
  String get savedSourcesTitle => 'Saved sources';

  @override
  String get settingsHeadline => 'Sources and scan settings';

  @override
  String get settingsDescription =>
      'Add remote music sources, switch the active library, and start a fresh scan for albums and songs.';

  @override
  String get webApkBannerTitle => 'Need the full version?';

  @override
  String get webApkBannerDescription =>
      'The Android APK includes fuller protocol support than the web build. Download it for FTP, SFTP, Samba, and the best playback experience.';

  @override
  String get webApkBannerUnavailableLabel =>
      'The web build is ready, but the APK download link has not been configured for this deployment yet.';

  @override
  String get webApkBannerDownloadAction => 'Download APK';

  @override
  String get webApkBannerLaunchFailedMessage =>
      'Unable to open the APK download link on this device.';

  @override
  String get landingBadge => 'Web preview for your self-hosted music library';

  @override
  String get landingHeroTitle => 'One calm place for every album you keep.';

  @override
  String get landingHeroSubtitle =>
      'OmniTune brings remote sources, local-style browsing, metadata cleanup, lyrics, and playback cache into a single cross-platform music player.';

  @override
  String get landingPrimaryAction => 'Enter app';

  @override
  String get landingApkUnavailableAction => 'APK link unavailable';

  @override
  String get landingSignalSources => 'WebDAV, SFTP, FTP, Samba, cloud drive';

  @override
  String get landingSignalMetadata => 'Metadata and lyrics scraping';

  @override
  String get landingSignalPlatforms => 'Web, mobile, desktop, TV';

  @override
  String get landingPreviewKicker => 'Interface preview';

  @override
  String get landingPreviewTitle =>
      'Browse, scan, and play without losing context.';

  @override
  String get landingPreviewScanStatus => 'Scanning library';

  @override
  String get landingPreviewAlbumOne => 'Late Night Analog';

  @override
  String get landingPreviewAlbumTwo => 'Aerial Drift';

  @override
  String get landingPreviewAlbumThree => 'Rain Room Sessions';

  @override
  String get landingPreviewSourceWebDav => 'WebDAV source';

  @override
  String get landingPreviewSourceCloud => 'Cloud drive source';

  @override
  String get landingPreviewSourceLocal => 'Local collection';

  @override
  String get landingPreviewNowPlaying => 'Now playing';

  @override
  String get landingPreviewTrackTitle => 'Signals across the archive';

  @override
  String get landingDownloadTitle => 'Choose how you want to listen';

  @override
  String get landingDownloadDescription =>
      'Start instantly in the browser, or install the Android APK when you need fuller protocol support and the most complete playback experience.';

  @override
  String get landingDownloadWebTitle => 'Open the Web app';

  @override
  String get landingDownloadWebDescription =>
      'Use the hosted Web build for quick access from this browser. It keeps the existing app interface behind a dedicated /app entry point.';

  @override
  String get landingDownloadApkTitle => 'Android APK';

  @override
  String get landingDownloadApkDescription =>
      'Install the Android build for broader protocol coverage, background playback, and a native mobile experience.';

  @override
  String get landingFeaturesTitle =>
      'Built for music libraries that live everywhere';

  @override
  String get landingFeaturesDescription =>
      'The main app stays focused on connecting your own sources, organizing the library, and keeping playback smooth across devices.';

  @override
  String get landingFeatureSourcesTitle => 'Bring your own source';

  @override
  String get landingFeatureSourcesDescription =>
      'Connect WebDAV, SFTP, FTP, Samba, cloud drive, or local files depending on the platform you are using.';

  @override
  String get landingFeatureLibraryTitle => 'Unified library views';

  @override
  String get landingFeatureLibraryDescription =>
      'Scan saved sources into album, collection, favorites, and liked-song views without locking your files into a service.';

  @override
  String get landingFeatureMetadataTitle => 'Cleaner metadata';

  @override
  String get landingFeatureMetadataDescription =>
      'Use scraper integrations to fill in cover art, lyrics, and track details when folders or tags are incomplete.';

  @override
  String get landingFeaturePlaybackTitle => 'Playback that keeps up';

  @override
  String get landingFeaturePlaybackDescription =>
      'Remote streaming starts quickly, while cache settings help repeated plays avoid unnecessary network work.';

  @override
  String get landingClosingTitle => 'Ready to try the real app?';

  @override
  String get landingClosingDescription =>
      'Jump into the existing OmniTune interface. Existing deep links such as albums, collection, browser, and settings still point to the app shell.';

  @override
  String get landingFooterNote =>
      'The Web landing page is promotional only; the full player remains available through the app routes.';

  @override
  String get playbackCacheTitle => 'Playback cache';

  @override
  String get playbackCacheDescription =>
      'Start playback immediately from the remote stream, then keep caching in the background for future replays.';

  @override
  String get persistentPlaybackCacheLabel => 'Cache to local files';

  @override
  String get persistentPlaybackCacheDescription =>
      'When enabled, fully cached tracks are also saved to local disk and replayed from the local cache first.';

  @override
  String get memoryCacheTrackLimitLabel => 'Memory cache track limit';

  @override
  String get memoryCacheTrackLimitDescription =>
      'The app keeps the most recently played tracks and byte ranges in memory so repeated playback can reuse cached data before falling back to the network.';

  @override
  String get cacheSettingsEntryTitle => 'Cache settings';

  @override
  String get cacheStorageModeLocal => 'Local file cache';

  @override
  String get cacheStorageModeMemory => 'Memory cache only';

  @override
  String cacheSettingsSummary(Object storageMode, int count) {
    return '$storageMode · $count in memory';
  }

  @override
  String get clearCachedFilesTitle => 'Manage cached files';

  @override
  String get clearCachedFilesDescription =>
      'Open the cache list and remove selected tracks or clear everything.';

  @override
  String get clearCachedFilesConfirmDescription =>
      'This removes every cached track and byte range stored by the app.';

  @override
  String get clearCacheAction => 'Clear cache';

  @override
  String get cacheClearedMessage => 'Cached files were cleared.';

  @override
  String get cachedTracksDialogDescription =>
      'Select cached tracks and remove only the ones you no longer want to keep.';

  @override
  String get cachedTracksEmptyTitle => 'No cached tracks yet';

  @override
  String get cachedTracksEmptyDescription =>
      'Play music first and cached tracks will appear here.';

  @override
  String selectedCacheCountLabel(int count) {
    return '$count selected';
  }

  @override
  String get cacheUnknownSourceLabel => 'Unknown source';

  @override
  String cacheCoverageLabel(int percent) {
    return '$percent% cached';
  }

  @override
  String get cacheCoverageUnknownLabel => 'Cached data available';

  @override
  String get cacheModeHybridLabel => 'Memory + local file';

  @override
  String get cacheModeLocalLabel => 'Local file';

  @override
  String get cacheModeMemoryLabel => 'Memory only';

  @override
  String get deleteSelectedCacheAction => 'Delete selected';

  @override
  String selectedCacheDeletedMessage(int count) {
    return 'Deleted $count cached tracks.';
  }

  @override
  String get selectAllAction => 'Select all';

  @override
  String get clearSelectionAction => 'Clear selection';

  @override
  String memoryCacheTrackLimitValue(int count) {
    return '$count tracks';
  }

  @override
  String get architectureReadyTitle => 'Production-ready source framework';

  @override
  String get architectureReadyDescription =>
      'The app is structured around a unified source registry, playback pipeline, and scraper chain for WebDAV, SFTP, FTP, Samba, and cloud sources.';

  @override
  String get webdavProtocol => 'WebDAV';

  @override
  String get sftpProtocol => 'SFTP';

  @override
  String get ftpProtocol => 'FTP';

  @override
  String get sambaProtocol => 'Samba';

  @override
  String get cloudDriveProtocol => 'Cloud drive';

  @override
  String get cloud189Protocol => '189 Cloud';

  @override
  String get sourceProtocolLabel => 'Source type';

  @override
  String get sourceTypeSelectionTitle => 'Choose a source type';

  @override
  String get sourceTypeSelectionDescription =>
      'Select the protocol first, then enter the connection details for that source.';

  @override
  String get webdavSourceTypeTitle => 'WebDAV source';

  @override
  String get webdavSourceDescription =>
      'Connect to a NAS or server that exposes your music library through WebDAV.';

  @override
  String get sftpSourceTypeTitle => 'SFTP source';

  @override
  String get sftpSourceDescription =>
      'Connect to an SSH/SFTP server and browse music files from a remote directory.';

  @override
  String get ftpSourceTypeTitle => 'FTP source';

  @override
  String get ftpSourceDescription =>
      'Connect to FTP, FTPS, or FTPES servers. Playback downloads the file to temporary local cache first.';

  @override
  String get sambaSourceTypeTitle => 'Samba source';

  @override
  String get sambaSourceDescription =>
      'Connect to SMB/Samba shares such as a NAS shared folder.';

  @override
  String get cloud189SourceTypeTitle => '189 Cloud source';

  @override
  String get cloud189SourceDescription =>
      'Choose the OpenList-compatible mount flow or use your own 189 Cloud app credentials for OAuth authorization.';

  @override
  String get cloud189DefaultSourceName => '189 Cloud';

  @override
  String get cloud189OpenListModeLabel => 'OpenList mount';

  @override
  String get cloud189AppAuthorizationModeLabel => 'App authorization';

  @override
  String get cloud189OpenListModeDescription =>
      'Matches the OpenList 189Cloud driver: enter the phone number and password used for 189 Cloud login, then the app keeps the session for browsing files.';

  @override
  String get cloud189AppAuthorizationModeDescription =>
      'Use an appKey/appSecret issued by 189 Cloud. After the user authorizes this app, paste the returned code or refreshToken here.';

  @override
  String get cloud189OpenAuthorizationAction =>
      'Open 189 Cloud app authorization';

  @override
  String get cloud189AuthorizationOpenedMessage =>
      'Authorization opened. After approving this app in 189 Cloud, paste the returned code or refreshToken here.';

  @override
  String get cloud189AuthorizationOpenFailedMessage =>
      'Unable to open the 189 Cloud authorization page on this device.';

  @override
  String get cloud189AppAuthorizationConfigRequired =>
      'Enter appKey and redirect URI before opening authorization.';

  @override
  String get cloud189RefreshTokenLabel => '189 Cloud refresh token';

  @override
  String get cloud189RefreshTokenHint =>
      'Paste refreshToken from 189 Cloud authorization';

  @override
  String get cloud189RefreshTokenHelpText =>
      'The token is stored securely and used only to refresh your 189 Cloud session.';

  @override
  String get cloud189OpenListRefreshTokenLabel => 'OpenList refreshToken';

  @override
  String get cloud189OpenListRefreshTokenHint =>
      'Paste the refreshToken used by OpenList 189CloudPC';

  @override
  String get cloud189OpenListRefreshTokenHelpText =>
      'This follows the OpenList-compatible PC session flow and does not require your own appKey.';

  @override
  String get cloud189OpenListUsernameLabel => '189 Cloud username';

  @override
  String get cloud189OpenListUsernameHint => 'Phone number used to log in';

  @override
  String get cloud189OpenListUsernameHelpText =>
      'Same as the Username field in OpenList 189Cloud.';

  @override
  String get cloud189OpenListPasswordLabel => '189 Cloud password';

  @override
  String get cloud189OpenListPasswordHint => 'Password used to log in';

  @override
  String get cloud189OpenListPasswordHelpText =>
      'Same as the Password field in OpenList 189Cloud.';

  @override
  String get cloud189AppKeyLabel => '189 Cloud appKey';

  @override
  String get cloud189AppKeyHint => 'AppKey issued by 189 Cloud';

  @override
  String get cloud189AppKeyHelpText =>
      'Apply for an appKey in the 189 Cloud developer platform before using app authorization.';

  @override
  String get cloud189AppSecretLabel => '189 Cloud appSecret';

  @override
  String get cloud189AppSecretHint => 'AppSecret issued with your appKey';

  @override
  String get cloud189RedirectUriLabel => 'Redirect URI';

  @override
  String get cloud189RedirectUriHint => 'music://cloud189/callback';

  @override
  String get cloud189RedirectUriHelpText =>
      'Use the redirect URI configured for your 189 Cloud application.';

  @override
  String get cloud189AuthorizationCodeLabel => 'Authorization code';

  @override
  String get cloud189AuthorizationCodeHint =>
      'Paste the code returned by app authorization';

  @override
  String get cloud189AuthorizationCodeHelpText =>
      'Leave this empty only if you already have a refreshToken for the same appKey.';

  @override
  String get cloud189AppRefreshTokenLabel => 'App refreshToken';

  @override
  String get cloud189AppRefreshTokenHint =>
      'Optional refreshToken for this appKey';

  @override
  String get cloud189AppRefreshTokenHelpText =>
      'If provided, the app uses it directly instead of exchanging an authorization code.';

  @override
  String get cloud189AuthorizationCredentialRequiredError =>
      'Enter an authorization code or refreshToken.';

  @override
  String get cloud189RootPathHint => '/Music/';

  @override
  String get cloud189RootPathHelpText =>
      'Use a folder path in 189 Cloud. Leave \'/\' to start at the cloud root.';

  @override
  String get cloud189ConnectionFailedMessage =>
      '189 Cloud connection failed. Check the credentials; enable debug mode to view the request log.';

  @override
  String get cloud189DebugLogDialogTitle => '189 Cloud debug log';

  @override
  String get cloud189DebugLogDialogDescription =>
      'Request URLs, parameters, and response summaries from this source setup are shown with sensitive values redacted.';

  @override
  String get cloud189CaptchaDialogTitle => 'Enter 189 Cloud captcha';

  @override
  String get cloud189CaptchaDialogDescription =>
      'Automatic recognition is temporarily unavailable. Enter the characters from the image to continue login.';

  @override
  String get cloud189CaptchaCodeLabel => 'Captcha';

  @override
  String get cloud189CaptchaCodeHint => 'Enter the characters in the image';

  @override
  String get scraperPipelineLabel => 'Scraper pipeline';

  @override
  String get lyricsScrapingServiceUrlLabel => 'Lyrics service URL';

  @override
  String get lyricsScrapingServiceUrlDescription =>
      'Enter the base URL for your lyrics service (for example: https://lrclib.net/api). Leave empty to disable lyrics scraping.';

  @override
  String get lyricsScrapingServiceUrlNotConfigured => 'Not configured';

  @override
  String get lyricsScrapingServiceUrlConfigured => 'Configured';

  @override
  String get lyricsScrapingServiceUrlDialogTitle => 'Lyrics service';

  @override
  String get lyricsScrapingServiceUrlHint => 'https://lrclib.net/api';

  @override
  String get lyricsScrapingServiceUrlRequiredMessage =>
      'Configure a lyrics scraping service URL in Settings first.';

  @override
  String get lyricsScrapingDisabledMessage =>
      'Enable lyrics scraping in Settings first.';

  @override
  String get enableLyricsScrapingLabel => 'Enable lyrics scraping';

  @override
  String get enableLyricsScrapingDescription =>
      'When enabled, the app connects to your configured lyrics service to complete lyrics. This will generate network traffic.';

  @override
  String get enableDeezerCoverScrapingLabel => 'Enable Deezer cover completion';

  @override
  String get enableDeezerCoverScrapingDescription =>
      'When enabled, the app connects to Deezer to complete track cover art. This will generate network traffic.';

  @override
  String get enableItunesMetadataScrapingLabel => 'Use iTunes for metadata';

  @override
  String get enableItunesMetadataScrapingDescription =>
      'When enabled, the app connects to third-party metadata services (such as iTunes) to complete cover art and track names. This will generate network traffic. Check the third-party service terms for details.';

  @override
  String get scanLibraryAction => 'Scan library';

  @override
  String get scanningAction => 'Scanning';

  @override
  String get scanNotStartedLabel => 'Not scanned yet';

  @override
  String get scanReadyLabel => 'Scan available';

  @override
  String scanningProgress(int directories, int tracks) {
    return 'Scanned $directories folders and found $tracks tracks';
  }

  @override
  String get libraryEmptyTitle => 'Connect your first music source';

  @override
  String get libraryEmptyDescription =>
      'Add a music source to browse remote folders, list music files, and start playback from the same library interface.';

  @override
  String get albumsHeadline => 'Albums';

  @override
  String get albumsDescription =>
      'Scan your active source to build an album wall from the remote music library.';

  @override
  String albumsDescriptionAllSources(int count) {
    return 'Albums collected from all $count saved sources.';
  }

  @override
  String albumsDescriptionWithSource(Object sourceName) {
    return 'Albums collected from $sourceName';
  }

  @override
  String get albumsEmptyTitle => 'No albums yet';

  @override
  String get albumsEmptyDescription =>
      'Run a scan to collect albums from your remote music source.';

  @override
  String get tracksLabel => 'tracks';

  @override
  String get collectionHeadline => 'Your music library';

  @override
  String get homeGreetingMorning => 'Good morning';

  @override
  String get homeGreetingAfternoon => 'Good afternoon';

  @override
  String get homeGreetingEvening => 'Good evening';

  @override
  String homeWelcomeDescriptionReady(int sourceCount) {
    return 'Connected to $sourceCount music sources. Your cloud library is ready to play.';
  }

  @override
  String get homeWelcomeDescriptionPending =>
      'Your sources are connected. Run a scan to build albums and song collections.';

  @override
  String get homeSourcesSectionTitle => 'Cloud sources';

  @override
  String get homeRecentAlbumsSectionTitle => 'Recently added';

  @override
  String get homeRecentAlbumsEmptyDescription =>
      'Once you scan your sources, newly discovered albums will show up here.';

  @override
  String collectionDescription(Object sourceName) {
    return 'Browse $sourceName, scan all songs, and jump between all songs, liked songs, and favorites.';
  }

  @override
  String collectionDescriptionAllSources(
    Object browserSourceName,
    int sourceCount,
  ) {
    return 'Browse $browserSourceName and show scanned songs from all $sourceCount saved sources in one library.';
  }

  @override
  String currentScanSourceLabel(Object sourceName) {
    return 'Scanning source: $sourceName';
  }

  @override
  String get favoritesCollectionTitle => 'Favorites';

  @override
  String get likedCollectionTitle => 'Liked';

  @override
  String get favoritesCollectionDescription =>
      'Your bookmarked songs live here.';

  @override
  String get likedCollectionDescription =>
      'Songs you marked as liked live here.';

  @override
  String get allSongsCollectionTitle => 'All songs';

  @override
  String get favoritesEmptyTitle => 'No favorites yet';

  @override
  String get likedEmptyTitle => 'No liked songs yet';

  @override
  String get allSongsEmptyTitle => 'No scanned songs yet';

  @override
  String get collectionEmptyDescription =>
      'This section is empty right now. Pick songs you love or run another scan.';

  @override
  String get scanLibraryHint =>
      'Run a scan to index every music file from all saved sources into albums and song collections.';

  @override
  String get browserTitle => 'File browser';

  @override
  String get currentPathLabel => 'Current path';

  @override
  String get upAction => 'Up';

  @override
  String get refreshAction => 'Refresh';

  @override
  String get noFilesTitle => 'This folder is empty';

  @override
  String get noFilesDescription =>
      'Try a different path or refresh the current directory.';

  @override
  String get browserDiagnosticsTitle => 'Browser diagnostics';

  @override
  String get unsupportedFileMessage =>
      'This file can be listed, but it is not playable yet.';

  @override
  String get loadFailedMessage => 'Unable to load the current source.';

  @override
  String get retryAction => 'Retry';

  @override
  String get resetToDefaultAction => 'Reset to default';

  @override
  String get playerEmptyTitle => 'No track selected';

  @override
  String get playerEmptyDescription =>
      'Choose a music file from your source browser to start playback.';

  @override
  String get lyricsEmptyLabel =>
      'No synced lyrics were found for this track yet.';

  @override
  String get untimedLyricsNotice => 'Timed lyrics unavailable';

  @override
  String get showLyricsAction => 'Show lyrics';

  @override
  String get hideLyricsAction => 'Hide lyrics';

  @override
  String get lyricsSourceSidecarLabel => 'Local LRC';

  @override
  String get lyricsSourceEmbeddedLabel => 'Embedded lyrics';

  @override
  String get lyricsSourceScrapedLabel => 'Scraped lyrics';

  @override
  String get playAction => 'Play';

  @override
  String get pauseAction => 'Pause';

  @override
  String get stopAction => 'Stop';

  @override
  String get closeAction => 'Close';

  @override
  String get previousTrackAction => 'Previous';

  @override
  String get nextTrackAction => 'Next';

  @override
  String get playNextAction => 'Play next';

  @override
  String get playlistTitle => 'Playlist';

  @override
  String get playlistEmptyTitle => 'The playlist is empty.';

  @override
  String get removeFromPlaylistAction => 'Remove from playlist';

  @override
  String get currentTrackLabel => 'Now playing';

  @override
  String get playbackModeList => 'List play';

  @override
  String get playbackModeRepeatOne => 'Repeat one';

  @override
  String get playbackModeShuffle => 'Shuffle';

  @override
  String playlistCountLabel(int count) {
    return '$count in queue';
  }

  @override
  String addedToPlayNextMessage(Object title) {
    return 'Added to play next: $title';
  }

  @override
  String get openPlayerAction => 'Open player';

  @override
  String get settingsAddSourceTitle => 'Add source';

  @override
  String get settingsEditSourceTitle => 'Edit source';

  @override
  String get sourceNameLabel => 'Source name';

  @override
  String get sourceNameHint => 'My NAS library';

  @override
  String get serverUrlLabel => 'Server URL';

  @override
  String get serverUrlHint =>
      'https://dav.example.com/remote.php/dav/files/user/';

  @override
  String get sftpServerUrlHint => 'sftp://server.example.com:22/home/user';

  @override
  String get ftpServerUrlHint => 'ftp://server.example.com/Music';

  @override
  String get sambaServerUrlHint => 'smb://server.example.com/share';

  @override
  String get usernameLabel => 'Username';

  @override
  String get passwordLabel => 'Password or app token';

  @override
  String get sambaPasswordLabel => 'Password';

  @override
  String get rootPathLabel => 'Root path';

  @override
  String get rootPathHint => '/Music/';

  @override
  String get sambaRootPathHint => '/Music/';

  @override
  String get rootPathHelpText =>
      'If the server URL already points to the target folder, keep this as \'/\'.';

  @override
  String get sftpRootPathHelpText =>
      'The path is relative to the SFTP URL path. Use \'/\' to start at that base directory.';

  @override
  String get ftpRootPathHelpText =>
      'The path is relative to the FTP URL path. Use \'/\' to start at that base directory.';

  @override
  String get sambaRootPathHelpText =>
      'The path is relative to the SMB share in the server URL. Use \'/\' to start at the share root.';

  @override
  String get scanDirectoriesTitle => 'Scan directories';

  @override
  String get scanDirectoriesDescription =>
      'Add multiple directories to scan. If left empty, scanning starts from the source root by default.';

  @override
  String get scanDirectoriesDefaultRootDescription =>
      'No scan directories are configured yet, so this source will scan from its root directory.';

  @override
  String get addScanDirectoryAction => 'Add scan directory';

  @override
  String get addScanDirectoryDialogTitle => 'Add directory to scan';

  @override
  String get scanDirectoriesDialogDescription =>
      'Enter a directory path relative to the current source root, such as /Jazz/ or /Live/Concerts/.';

  @override
  String get excludedScanDirectoriesTitle => 'Excluded directories';

  @override
  String get excludedScanDirectoriesDescription =>
      'Directories listed here are skipped during scanning. You can add more than one.';

  @override
  String get excludedScanDirectoriesEmptyDescription =>
      'No excluded directories yet, so every subdirectory under the source root will be scanned.';

  @override
  String get addExcludedScanDirectoryAction => 'Add excluded directory';

  @override
  String get addExcludedScanDirectoryDialogTitle => 'Add directory to exclude';

  @override
  String get excludedScanDirectoriesDialogDescription =>
      'Enter a directory path to skip, such as /Temp/ or /Podcasts/.';

  @override
  String get directoryPathLabel => 'Directory path';

  @override
  String get directoryPathHint => '/Albums/';

  @override
  String get directoryPathHelpText =>
      'Directory paths are applied relative to the current source root. Start them with \'/\'.';

  @override
  String get testConnectionAction => 'Test connection';

  @override
  String get saveSourceAction => 'Save source';

  @override
  String get saveSourceChangesAction => 'Save changes';

  @override
  String get editSourceAction => 'Edit source';

  @override
  String get requiredFieldError => 'This field is required.';

  @override
  String get invalidUrlError => 'Enter a valid server URL.';

  @override
  String get connectionTestSuccess => 'Connection succeeded.';

  @override
  String get sourceSavedSuccess => 'Source saved successfully.';

  @override
  String get sourceUpdatedSuccess => 'Source settings updated.';

  @override
  String get sourceNotFoundMessage =>
      'The source you tried to edit could not be found.';

  @override
  String get connectionFailedMessage =>
      'Connection failed. Check the server address, root path, and credentials.';

  @override
  String get playbackFailedMessage =>
      'Playback could not be started for this file.';

  @override
  String get folderAlbumsModeLabel => 'By folder';

  @override
  String get scrapedAlbumsModeLabel => 'By album tag';

  @override
  String get songDetailsTitle => 'Track details';

  @override
  String get filePathLabel => 'File path';

  @override
  String get sourceLabel => 'Source';

  @override
  String get artistLabel => 'Artist';

  @override
  String get albumLabel => 'Album';

  @override
  String get addToFavoritesAction => 'Add to favorites';

  @override
  String get removeFromFavoritesAction => 'Remove from favorites';

  @override
  String get addToLikedAction => 'Add to liked';

  @override
  String get removeFromLikedAction => 'Remove from liked';

  @override
  String get moreOptionsAction => 'More options';

  @override
  String get debugSettingsTitle => 'Developer';

  @override
  String get debugModeLabel => 'Debug mode';

  @override
  String get debugModeDescription => 'Show error dialogs when exceptions occur';

  @override
  String get debugModeEnabledMessage =>
      '🔍 Debug mode enabled - check console for detailed logs';

  @override
  String get manualScrapingTitle => 'Manual Scraping';

  @override
  String get manualScrapingActionLabel => 'Scrape metadata';

  @override
  String get scrapingSongName => 'Song name';

  @override
  String get scrapingArtistName => 'Artist name';

  @override
  String get scrapingSearchButton => 'Search';

  @override
  String get scrapingSearchingLabel => 'Searching...';

  @override
  String get scrapingSearchResultsTitle => 'Search Results';

  @override
  String get scrapingNoResultsMessage => 'No results found';

  @override
  String scrapingMatchScoreLabel(int score) {
    return 'Match: $score%';
  }

  @override
  String get scrapingSelectButtonLabel => 'Select';

  @override
  String get scrapingCoverLabel => 'Cover';

  @override
  String get scrapingLyricsLabel => 'Lyrics';

  @override
  String get scrapingUpdateCoverAction => 'Update cover';

  @override
  String get scrapingUpdateLyricsAction => 'Get lyrics';

  @override
  String get scrapingResultApplied => 'Metadata applied successfully';

  @override
  String get scrapingErrorMessage => 'Scraping failed';

  @override
  String get scrapingRetryAction => 'Retry';

  @override
  String get automaticScrapingLabel => 'Automatic';

  @override
  String get manualScrapingLabel => 'Manual';

  @override
  String get autoScrapedLabel => 'Auto-scraped';

  @override
  String get manuallyScrapedLabel => 'Manually scraped';

  @override
  String get debugLogsTitle => 'Debug logs';

  @override
  String get debugLogsTabLabel => 'Debug logs';

  @override
  String get clearAction => 'Clear';

  @override
  String get autoScrollLabel => 'Auto';

  @override
  String get noLogsAvailable => 'No logs';

  @override
  String get logsExportedToClipboard => 'Logs copied to clipboard';

  @override
  String get exportAction => 'Export';

  @override
  String get copyLogsAction => 'Copy logs';

  @override
  String get playbackModeRepeatAll => 'Repeat all';

  @override
  String get librarySearchTitle => 'Search library';

  @override
  String get librarySearchHint => 'Song, artist or album';

  @override
  String get allSourcesLabel => 'All sources';

  @override
  String get sortTitleLabel => 'Title';

  @override
  String get sortArtistLabel => 'Artist';

  @override
  String get sortAlbumLabel => 'Album';

  @override
  String get searchNoResults => 'No matching songs';

  @override
  String get scanCancelledLabel => 'Scan cancelled. Saved songs are kept.';

  @override
  String get cancelScanAction => 'Cancel scan';

  @override
  String get retryFailedScanAction => 'Retry failed sources';

  @override
  String get scanFailedSourcesLabel => 'Failed sources';

  @override
  String get playbackSettingsTitle => 'Playback & cache';

  @override
  String get advancedSettingsTitle => 'Advanced';

  @override
  String get resumeLyricsFollow => 'Follow current line';

  @override
  String get playbackBufferingLabel => 'Buffering';

  @override
  String get playbackPausedLabel => 'Paused';

  @override
  String get playbackLoadingLabel => 'Loading audio';

  @override
  String get playbackPlayingLabel => 'Playing';

  @override
  String get playbackCacheNotice =>
      'Playback cache may be evicted automatically. It is not an offline download.';

  @override
  String get clearSourceCacheAction => 'Clear this source cache';

  @override
  String get cachedBytesLabel => 'Cached';

  @override
  String get memoryCacheUsageLabel => 'Memory cache';

  @override
  String get systemPlaybackChannel => 'Music playback';

  @override
  String get showCoverAction => 'Show cover';

  @override
  String get discardChangesConfirmationTitle => 'Discard unsaved changes?';

  @override
  String get discardChangesConfirmationDescription =>
      'You have unsaved changes. Are you sure you want to discard them?';

  @override
  String get discardChangesAction => 'Discard';

  @override
  String get continueEditingAction => 'Continue editing';

  @override
  String get aboutAndUpdatesSettingTitle => 'About & updates';

  @override
  String get appUpdateCurrentVersionLabel => 'Current version';

  @override
  String get appUpdateCheckAction => 'Check for updates';

  @override
  String get appUpdateCheckingStatus => 'Checking for updates...';

  @override
  String get appUpdateUpToDateStatus => 'You are on the latest version';

  @override
  String get appUpdateAvailableTitle => 'New version available';

  @override
  String get appUpdateReleaseNotesTitle => 'Release notes';

  @override
  String get appUpdatePackageSizeLabel => 'Package size';

  @override
  String get appUpdateActionDownloadAndInstall => 'Download and install';

  @override
  String get appUpdateActionDownloadLatest => 'Download latest version';

  @override
  String get appUpdateDownloadingLabel => 'Downloading update...';

  @override
  String get appUpdateCancelAction => 'Cancel download';

  @override
  String get appUpdateAwaitingInstallTitle => 'System installer opened';

  @override
  String get appUpdateAwaitingInstallDescription =>
      'The system package installer has opened. Please confirm installation in the system prompt. If the installer was closed or dismissed, tap below to re-download and verify.';

  @override
  String get appUpdateReopenInstallerAction => 'Re-download & verify';

  @override
  String get appUpdateRetryDownloadAction => 'Re-download & verify';

  @override
  String get appUpdateCheckAgainAction => 'Check again';

  @override
  String get appUpdateCanceledStatus => 'Update download was canceled';

  @override
  String get appUpdateUnsupportedPlatform =>
      'No compatible update package found for your platform or architecture.';

  @override
  String get appUpdateErrorNetwork =>
      'Network error while checking for updates. Please verify your connection.';

  @override
  String get appUpdateErrorInvalidResponse =>
      'Invalid response received from the update server.';

  @override
  String get appUpdateErrorChecksumMissing =>
      'The update package is missing security checksum and cannot be installed safely.';

  @override
  String get appUpdateErrorChecksumMismatch =>
      'Package checksum verification failed. The update file cannot be installed.';

  @override
  String get appUpdateErrorDownloadFailed =>
      'Download failed. Please check your network and try again.';

  @override
  String get appUpdateErrorPermissionDenied =>
      'Install permission was denied. Please allow unknown apps installation in system settings.';

  @override
  String get appUpdateErrorInstallationFailed =>
      'System package installer failed to start.';

  @override
  String get appUpdateErrorUnknown =>
      'An unexpected error occurred during update.';

  @override
  String appUpdateVersionFormat(String version, int build) {
    return 'v$version ($build)';
  }

  @override
  String appUpdateVersionOnly(String version) {
    return 'v$version';
  }

  @override
  String get appUpdateVersionUnknown => 'Unknown';

  @override
  String appUpdateSizeMB(String size) {
    return '$size MB';
  }

  @override
  String appUpdateSizeKB(String size) {
    return '$size KB';
  }

  @override
  String appUpdateSizeB(String size) {
    return '$size B';
  }

  @override
  String appUpdateProgressPercent(int percent) {
    return '$percent%';
  }

  @override
  String get aboutOrganizationLabel => 'Organization';

  @override
  String get aboutOrganizationValue => 'Norns Interactive';

  @override
  String get aboutRepositoryLabel => 'Repository';

  @override
  String get aboutRepositoryAction => 'GitHub';
}
