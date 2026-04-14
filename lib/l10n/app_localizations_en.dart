// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Flux Music';

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
  String get browserTitle => 'Remote browser';

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
  String get playerEmptyTitle => 'No track selected';

  @override
  String get playerEmptyDescription =>
      'Choose a music file from your source browser to start playback.';

  @override
  String get lyricsEmptyLabel =>
      'No synced lyrics were found for this track yet.';

  @override
  String get showLyricsAction => 'Show lyrics';

  @override
  String get hideLyricsAction => 'Hide lyrics';

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
  String get addScanDirectoryDialogTitle => 'Add scan directory';

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
  String get addExcludedScanDirectoryDialogTitle => 'Add excluded directory';

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
  String get scrapedAlbumsModeLabel => 'By scraped data';

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
}
