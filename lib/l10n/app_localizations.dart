import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Flux Music'**
  String get appTitle;

  /// No description provided for @albumsTabLabel.
  ///
  /// In en, this message translates to:
  /// **'Albums'**
  String get albumsTabLabel;

  /// No description provided for @collectionTabLabel.
  ///
  /// In en, this message translates to:
  /// **'Collection'**
  String get collectionTabLabel;

  /// No description provided for @settingsTabLabel.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTabLabel;

  /// No description provided for @settingsPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsPageTitle;

  /// No description provided for @openSettingsAction.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get openSettingsAction;

  /// No description provided for @settingsCenterHeadline.
  ///
  /// In en, this message translates to:
  /// **'Tune the app your way'**
  String get settingsCenterHeadline;

  /// No description provided for @settingsCenterDescription.
  ///
  /// In en, this message translates to:
  /// **'Adjust appearance, language, sources, cache behavior, and playback preferences from one control center.'**
  String get settingsCenterDescription;

  /// No description provided for @appearanceSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearanceSettingsTitle;

  /// No description provided for @librarySettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Library and sources'**
  String get librarySettingsTitle;

  /// No description provided for @languageSettingTitle.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageSettingTitle;

  /// No description provided for @themeSettingTitle.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get themeSettingTitle;

  /// No description provided for @interfaceSizeSettingTitle.
  ///
  /// In en, this message translates to:
  /// **'Interface size'**
  String get interfaceSizeSettingTitle;

  /// No description provided for @fontSizeSettingTitle.
  ///
  /// In en, this message translates to:
  /// **'Font size'**
  String get fontSizeSettingTitle;

  /// No description provided for @interfaceScaleSummary.
  ///
  /// In en, this message translates to:
  /// **'{percent}% component size'**
  String interfaceScaleSummary(int percent);

  /// No description provided for @fontScaleSummary.
  ///
  /// In en, this message translates to:
  /// **'{percent}% text size'**
  String fontScaleSummary(int percent);

  /// No description provided for @interfaceSizeDialogDescription.
  ///
  /// In en, this message translates to:
  /// **'Drag to enlarge or shrink cards, buttons, spacing, and overall interface density.'**
  String get interfaceSizeDialogDescription;

  /// No description provided for @fontSizeDialogDescription.
  ///
  /// In en, this message translates to:
  /// **'Drag to adjust text size across the whole app.'**
  String get fontSizeDialogDescription;

  /// No description provided for @scalePercentLabel.
  ///
  /// In en, this message translates to:
  /// **'{percent}%'**
  String scalePercentLabel(int percent);

  /// No description provided for @scaleRangeLabel.
  ///
  /// In en, this message translates to:
  /// **'Range: {min}% - {max}%'**
  String scaleRangeLabel(int min, int max);

  /// No description provided for @sourceManagementSettingTitle.
  ///
  /// In en, this message translates to:
  /// **'Music sources'**
  String get sourceManagementSettingTitle;

  /// No description provided for @sourceManagementDialogDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose the source used by remote browsing, keep adding more sources, and scan every saved source into one shared library.'**
  String get sourceManagementDialogDescription;

  /// No description provided for @sourceManagementEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No music sources yet'**
  String get sourceManagementEmptyTitle;

  /// No description provided for @sourceManagementEmptySummary.
  ///
  /// In en, this message translates to:
  /// **'Add a music source to start browsing and scanning your library.'**
  String get sourceManagementEmptySummary;

  /// No description provided for @sourceManagementSummary.
  ///
  /// In en, this message translates to:
  /// **'Browser: {sourceName} · {count} saved'**
  String sourceManagementSummary(Object sourceName, int count);

  /// No description provided for @savedSourcesCountLabel.
  ///
  /// In en, this message translates to:
  /// **'{count} sources'**
  String savedSourcesCountLabel(int count);

  /// No description provided for @languageOptionSystem.
  ///
  /// In en, this message translates to:
  /// **'Follow system'**
  String get languageOptionSystem;

  /// No description provided for @languageOptionEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageOptionEnglish;

  /// No description provided for @languageOptionChinese.
  ///
  /// In en, this message translates to:
  /// **'Chinese'**
  String get languageOptionChinese;

  /// No description provided for @themeOptionSystem.
  ///
  /// In en, this message translates to:
  /// **'Follow system'**
  String get themeOptionSystem;

  /// No description provided for @themeOptionLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeOptionLight;

  /// No description provided for @themeOptionDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeOptionDark;

  /// No description provided for @interfaceSizeOptionCompact.
  ///
  /// In en, this message translates to:
  /// **'Compact'**
  String get interfaceSizeOptionCompact;

  /// No description provided for @interfaceSizeOptionStandard.
  ///
  /// In en, this message translates to:
  /// **'Standard'**
  String get interfaceSizeOptionStandard;

  /// No description provided for @interfaceSizeOptionComfortable.
  ///
  /// In en, this message translates to:
  /// **'Comfortable'**
  String get interfaceSizeOptionComfortable;

  /// No description provided for @fontSizeOptionSmall.
  ///
  /// In en, this message translates to:
  /// **'Small'**
  String get fontSizeOptionSmall;

  /// No description provided for @fontSizeOptionStandard.
  ///
  /// In en, this message translates to:
  /// **'Standard'**
  String get fontSizeOptionStandard;

  /// No description provided for @fontSizeOptionLarge.
  ///
  /// In en, this message translates to:
  /// **'Large'**
  String get fontSizeOptionLarge;

  /// No description provided for @fontSizeOptionExtraLarge.
  ///
  /// In en, this message translates to:
  /// **'Extra large'**
  String get fontSizeOptionExtraLarge;

  /// No description provided for @libraryTitle.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get libraryTitle;

  /// No description provided for @addSourceAction.
  ///
  /// In en, this message translates to:
  /// **'Add source'**
  String get addSourceAction;

  /// No description provided for @playerTitle.
  ///
  /// In en, this message translates to:
  /// **'Now playing'**
  String get playerTitle;

  /// No description provided for @savedSourcesTitle.
  ///
  /// In en, this message translates to:
  /// **'Saved sources'**
  String get savedSourcesTitle;

  /// No description provided for @settingsHeadline.
  ///
  /// In en, this message translates to:
  /// **'Sources and scan settings'**
  String get settingsHeadline;

  /// No description provided for @settingsDescription.
  ///
  /// In en, this message translates to:
  /// **'Add remote music sources, switch the active library, and start a fresh scan for albums and songs.'**
  String get settingsDescription;

  /// No description provided for @playbackCacheTitle.
  ///
  /// In en, this message translates to:
  /// **'Playback cache'**
  String get playbackCacheTitle;

  /// No description provided for @playbackCacheDescription.
  ///
  /// In en, this message translates to:
  /// **'Start playback immediately from the remote stream, then keep caching in the background for future replays.'**
  String get playbackCacheDescription;

  /// No description provided for @persistentPlaybackCacheLabel.
  ///
  /// In en, this message translates to:
  /// **'Prefer local file cache'**
  String get persistentPlaybackCacheLabel;

  /// No description provided for @persistentPlaybackCacheDescription.
  ///
  /// In en, this message translates to:
  /// **'When enabled, fully cached tracks are also saved to local disk and replayed from the local cache first.'**
  String get persistentPlaybackCacheDescription;

  /// No description provided for @memoryCacheTrackLimitLabel.
  ///
  /// In en, this message translates to:
  /// **'Memory cache track limit'**
  String get memoryCacheTrackLimitLabel;

  /// No description provided for @memoryCacheTrackLimitDescription.
  ///
  /// In en, this message translates to:
  /// **'The app keeps the most recently played tracks and byte ranges in memory so repeated playback can reuse cached data before falling back to the network.'**
  String get memoryCacheTrackLimitDescription;

  /// No description provided for @cacheSettingsEntryTitle.
  ///
  /// In en, this message translates to:
  /// **'Cache settings'**
  String get cacheSettingsEntryTitle;

  /// No description provided for @cacheStorageModeLocal.
  ///
  /// In en, this message translates to:
  /// **'Local file cache'**
  String get cacheStorageModeLocal;

  /// No description provided for @cacheStorageModeMemory.
  ///
  /// In en, this message translates to:
  /// **'Memory cache only'**
  String get cacheStorageModeMemory;

  /// No description provided for @cacheSettingsSummary.
  ///
  /// In en, this message translates to:
  /// **'{storageMode} · {count} in memory'**
  String cacheSettingsSummary(Object storageMode, int count);

  /// No description provided for @clearCachedFilesTitle.
  ///
  /// In en, this message translates to:
  /// **'Manage cached files'**
  String get clearCachedFilesTitle;

  /// No description provided for @clearCachedFilesDescription.
  ///
  /// In en, this message translates to:
  /// **'Open the cache list and remove selected tracks or clear everything.'**
  String get clearCachedFilesDescription;

  /// No description provided for @clearCachedFilesConfirmDescription.
  ///
  /// In en, this message translates to:
  /// **'This removes every cached track and byte range stored by the app.'**
  String get clearCachedFilesConfirmDescription;

  /// No description provided for @clearCacheAction.
  ///
  /// In en, this message translates to:
  /// **'Clear cache'**
  String get clearCacheAction;

  /// No description provided for @cacheClearedMessage.
  ///
  /// In en, this message translates to:
  /// **'Cached files were cleared.'**
  String get cacheClearedMessage;

  /// No description provided for @cachedTracksDialogDescription.
  ///
  /// In en, this message translates to:
  /// **'Select cached tracks and remove only the ones you no longer want to keep.'**
  String get cachedTracksDialogDescription;

  /// No description provided for @cachedTracksEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No cached tracks yet'**
  String get cachedTracksEmptyTitle;

  /// No description provided for @cachedTracksEmptyDescription.
  ///
  /// In en, this message translates to:
  /// **'Play music first and cached tracks will appear here.'**
  String get cachedTracksEmptyDescription;

  /// No description provided for @selectedCacheCountLabel.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String selectedCacheCountLabel(int count);

  /// No description provided for @cacheUnknownSourceLabel.
  ///
  /// In en, this message translates to:
  /// **'Unknown source'**
  String get cacheUnknownSourceLabel;

  /// No description provided for @cacheCoverageLabel.
  ///
  /// In en, this message translates to:
  /// **'{percent}% cached'**
  String cacheCoverageLabel(int percent);

  /// No description provided for @cacheCoverageUnknownLabel.
  ///
  /// In en, this message translates to:
  /// **'Cached data available'**
  String get cacheCoverageUnknownLabel;

  /// No description provided for @cacheModeHybridLabel.
  ///
  /// In en, this message translates to:
  /// **'Memory + local file'**
  String get cacheModeHybridLabel;

  /// No description provided for @cacheModeLocalLabel.
  ///
  /// In en, this message translates to:
  /// **'Local file'**
  String get cacheModeLocalLabel;

  /// No description provided for @cacheModeMemoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Memory only'**
  String get cacheModeMemoryLabel;

  /// No description provided for @deleteSelectedCacheAction.
  ///
  /// In en, this message translates to:
  /// **'Delete selected'**
  String get deleteSelectedCacheAction;

  /// No description provided for @selectedCacheDeletedMessage.
  ///
  /// In en, this message translates to:
  /// **'Deleted {count} cached tracks.'**
  String selectedCacheDeletedMessage(int count);

  /// No description provided for @selectAllAction.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get selectAllAction;

  /// No description provided for @clearSelectionAction.
  ///
  /// In en, this message translates to:
  /// **'Clear selection'**
  String get clearSelectionAction;

  /// No description provided for @memoryCacheTrackLimitValue.
  ///
  /// In en, this message translates to:
  /// **'{count} tracks'**
  String memoryCacheTrackLimitValue(int count);

  /// No description provided for @architectureReadyTitle.
  ///
  /// In en, this message translates to:
  /// **'Production-ready source framework'**
  String get architectureReadyTitle;

  /// No description provided for @architectureReadyDescription.
  ///
  /// In en, this message translates to:
  /// **'The app is already structured for WebDAV today, while keeping the source registry, playback pipeline, and scraper chain ready for SFTP, cloud drives, and metadata enrichment.'**
  String get architectureReadyDescription;

  /// No description provided for @webdavProtocol.
  ///
  /// In en, this message translates to:
  /// **'WebDAV'**
  String get webdavProtocol;

  /// No description provided for @sftpProtocol.
  ///
  /// In en, this message translates to:
  /// **'SFTP'**
  String get sftpProtocol;

  /// No description provided for @cloudDriveProtocol.
  ///
  /// In en, this message translates to:
  /// **'Cloud drive'**
  String get cloudDriveProtocol;

  /// No description provided for @scraperPipelineLabel.
  ///
  /// In en, this message translates to:
  /// **'Scraper pipeline'**
  String get scraperPipelineLabel;

  /// No description provided for @scanLibraryAction.
  ///
  /// In en, this message translates to:
  /// **'Scan library'**
  String get scanLibraryAction;

  /// No description provided for @scanningAction.
  ///
  /// In en, this message translates to:
  /// **'Scanning'**
  String get scanningAction;

  /// No description provided for @scanNotStartedLabel.
  ///
  /// In en, this message translates to:
  /// **'Not scanned yet'**
  String get scanNotStartedLabel;

  /// No description provided for @scanReadyLabel.
  ///
  /// In en, this message translates to:
  /// **'Scan available'**
  String get scanReadyLabel;

  /// No description provided for @scanningProgress.
  ///
  /// In en, this message translates to:
  /// **'Scanned {directories} folders and found {tracks} tracks'**
  String scanningProgress(int directories, int tracks);

  /// No description provided for @libraryEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Connect your first music source'**
  String get libraryEmptyTitle;

  /// No description provided for @libraryEmptyDescription.
  ///
  /// In en, this message translates to:
  /// **'Add a WebDAV source to browse remote folders, list music files, and start playback from the same library interface.'**
  String get libraryEmptyDescription;

  /// No description provided for @albumsHeadline.
  ///
  /// In en, this message translates to:
  /// **'Albums'**
  String get albumsHeadline;

  /// No description provided for @albumsDescription.
  ///
  /// In en, this message translates to:
  /// **'Scan your active source to build an album wall from the remote music library.'**
  String get albumsDescription;

  /// No description provided for @albumsDescriptionAllSources.
  ///
  /// In en, this message translates to:
  /// **'Albums collected from all {count} saved sources.'**
  String albumsDescriptionAllSources(int count);

  /// No description provided for @albumsDescriptionWithSource.
  ///
  /// In en, this message translates to:
  /// **'Albums collected from {sourceName}'**
  String albumsDescriptionWithSource(Object sourceName);

  /// No description provided for @albumsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No albums yet'**
  String get albumsEmptyTitle;

  /// No description provided for @albumsEmptyDescription.
  ///
  /// In en, this message translates to:
  /// **'Run a scan to collect albums from your remote music source.'**
  String get albumsEmptyDescription;

  /// No description provided for @tracksLabel.
  ///
  /// In en, this message translates to:
  /// **'tracks'**
  String get tracksLabel;

  /// No description provided for @collectionHeadline.
  ///
  /// In en, this message translates to:
  /// **'Your music library'**
  String get collectionHeadline;

  /// No description provided for @collectionDescription.
  ///
  /// In en, this message translates to:
  /// **'Browse {sourceName}, scan all songs, and jump between favorites, liked songs, and the raw remote folders.'**
  String collectionDescription(Object sourceName);

  /// No description provided for @collectionDescriptionAllSources.
  ///
  /// In en, this message translates to:
  /// **'Browse {browserSourceName} and show scanned songs from all {sourceCount} saved sources in one library.'**
  String collectionDescriptionAllSources(
    Object browserSourceName,
    int sourceCount,
  );

  /// No description provided for @currentScanSourceLabel.
  ///
  /// In en, this message translates to:
  /// **'Scanning source: {sourceName}'**
  String currentScanSourceLabel(Object sourceName);

  /// No description provided for @favoritesCollectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get favoritesCollectionTitle;

  /// No description provided for @likedCollectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Liked'**
  String get likedCollectionTitle;

  /// No description provided for @allSongsCollectionTitle.
  ///
  /// In en, this message translates to:
  /// **'All songs'**
  String get allSongsCollectionTitle;

  /// No description provided for @favoritesEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No favorites yet'**
  String get favoritesEmptyTitle;

  /// No description provided for @likedEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No liked songs yet'**
  String get likedEmptyTitle;

  /// No description provided for @allSongsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No scanned songs yet'**
  String get allSongsEmptyTitle;

  /// No description provided for @collectionEmptyDescription.
  ///
  /// In en, this message translates to:
  /// **'This section is empty right now. Pick songs you love or run another scan.'**
  String get collectionEmptyDescription;

  /// No description provided for @scanLibraryHint.
  ///
  /// In en, this message translates to:
  /// **'Run a scan to index every music file from all saved sources into albums and song collections.'**
  String get scanLibraryHint;

  /// No description provided for @browserTitle.
  ///
  /// In en, this message translates to:
  /// **'Remote browser'**
  String get browserTitle;

  /// No description provided for @currentPathLabel.
  ///
  /// In en, this message translates to:
  /// **'Current path'**
  String get currentPathLabel;

  /// No description provided for @upAction.
  ///
  /// In en, this message translates to:
  /// **'Up'**
  String get upAction;

  /// No description provided for @refreshAction.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refreshAction;

  /// No description provided for @noFilesTitle.
  ///
  /// In en, this message translates to:
  /// **'This folder is empty'**
  String get noFilesTitle;

  /// No description provided for @noFilesDescription.
  ///
  /// In en, this message translates to:
  /// **'Try a different path or refresh the current directory.'**
  String get noFilesDescription;

  /// No description provided for @browserDiagnosticsTitle.
  ///
  /// In en, this message translates to:
  /// **'Browser diagnostics'**
  String get browserDiagnosticsTitle;

  /// No description provided for @unsupportedFileMessage.
  ///
  /// In en, this message translates to:
  /// **'This file can be listed, but it is not playable yet.'**
  String get unsupportedFileMessage;

  /// No description provided for @loadFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Unable to load the current source.'**
  String get loadFailedMessage;

  /// No description provided for @retryAction.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retryAction;

  /// No description provided for @playerEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No track selected'**
  String get playerEmptyTitle;

  /// No description provided for @playerEmptyDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose a music file from your source browser to start playback.'**
  String get playerEmptyDescription;

  /// No description provided for @lyricsEmptyLabel.
  ///
  /// In en, this message translates to:
  /// **'No synced lyrics were found for this track yet.'**
  String get lyricsEmptyLabel;

  /// No description provided for @playAction.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get playAction;

  /// No description provided for @pauseAction.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pauseAction;

  /// No description provided for @stopAction.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stopAction;

  /// No description provided for @openPlayerAction.
  ///
  /// In en, this message translates to:
  /// **'Open player'**
  String get openPlayerAction;

  /// No description provided for @settingsAddSourceTitle.
  ///
  /// In en, this message translates to:
  /// **'Add source'**
  String get settingsAddSourceTitle;

  /// No description provided for @settingsEditSourceTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit source'**
  String get settingsEditSourceTitle;

  /// No description provided for @sourceNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Source name'**
  String get sourceNameLabel;

  /// No description provided for @sourceNameHint.
  ///
  /// In en, this message translates to:
  /// **'My NAS library'**
  String get sourceNameHint;

  /// No description provided for @serverUrlLabel.
  ///
  /// In en, this message translates to:
  /// **'Server URL'**
  String get serverUrlLabel;

  /// No description provided for @serverUrlHint.
  ///
  /// In en, this message translates to:
  /// **'https://dav.example.com/remote.php/dav/files/user/'**
  String get serverUrlHint;

  /// No description provided for @usernameLabel.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get usernameLabel;

  /// No description provided for @passwordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password or app token'**
  String get passwordLabel;

  /// No description provided for @rootPathLabel.
  ///
  /// In en, this message translates to:
  /// **'Root path'**
  String get rootPathLabel;

  /// No description provided for @rootPathHint.
  ///
  /// In en, this message translates to:
  /// **'/Music/'**
  String get rootPathHint;

  /// No description provided for @rootPathHelpText.
  ///
  /// In en, this message translates to:
  /// **'If the server URL already points to the target folder, keep this as \'/\'.'**
  String get rootPathHelpText;

  /// No description provided for @scanDirectoriesTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan directories'**
  String get scanDirectoriesTitle;

  /// No description provided for @scanDirectoriesDescription.
  ///
  /// In en, this message translates to:
  /// **'Add multiple directories to scan. If left empty, scanning starts from the source root by default.'**
  String get scanDirectoriesDescription;

  /// No description provided for @scanDirectoriesDefaultRootDescription.
  ///
  /// In en, this message translates to:
  /// **'No scan directories are configured yet, so this source will scan from its root directory.'**
  String get scanDirectoriesDefaultRootDescription;

  /// No description provided for @addScanDirectoryAction.
  ///
  /// In en, this message translates to:
  /// **'Add scan directory'**
  String get addScanDirectoryAction;

  /// No description provided for @addScanDirectoryDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Add scan directory'**
  String get addScanDirectoryDialogTitle;

  /// No description provided for @scanDirectoriesDialogDescription.
  ///
  /// In en, this message translates to:
  /// **'Enter a directory path relative to the current source root, such as /Jazz/ or /Live/Concerts/.'**
  String get scanDirectoriesDialogDescription;

  /// No description provided for @excludedScanDirectoriesTitle.
  ///
  /// In en, this message translates to:
  /// **'Excluded directories'**
  String get excludedScanDirectoriesTitle;

  /// No description provided for @excludedScanDirectoriesDescription.
  ///
  /// In en, this message translates to:
  /// **'Directories listed here are skipped during scanning. You can add more than one.'**
  String get excludedScanDirectoriesDescription;

  /// No description provided for @excludedScanDirectoriesEmptyDescription.
  ///
  /// In en, this message translates to:
  /// **'No excluded directories yet, so every subdirectory under the source root will be scanned.'**
  String get excludedScanDirectoriesEmptyDescription;

  /// No description provided for @addExcludedScanDirectoryAction.
  ///
  /// In en, this message translates to:
  /// **'Add excluded directory'**
  String get addExcludedScanDirectoryAction;

  /// No description provided for @addExcludedScanDirectoryDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Add excluded directory'**
  String get addExcludedScanDirectoryDialogTitle;

  /// No description provided for @excludedScanDirectoriesDialogDescription.
  ///
  /// In en, this message translates to:
  /// **'Enter a directory path to skip, such as /Temp/ or /Podcasts/.'**
  String get excludedScanDirectoriesDialogDescription;

  /// No description provided for @directoryPathLabel.
  ///
  /// In en, this message translates to:
  /// **'Directory path'**
  String get directoryPathLabel;

  /// No description provided for @directoryPathHint.
  ///
  /// In en, this message translates to:
  /// **'/Albums/'**
  String get directoryPathHint;

  /// No description provided for @directoryPathHelpText.
  ///
  /// In en, this message translates to:
  /// **'Directory paths are applied relative to the current source root. Start them with \'/\'.'**
  String get directoryPathHelpText;

  /// No description provided for @testConnectionAction.
  ///
  /// In en, this message translates to:
  /// **'Test connection'**
  String get testConnectionAction;

  /// No description provided for @saveSourceAction.
  ///
  /// In en, this message translates to:
  /// **'Save source'**
  String get saveSourceAction;

  /// No description provided for @saveSourceChangesAction.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get saveSourceChangesAction;

  /// No description provided for @editSourceAction.
  ///
  /// In en, this message translates to:
  /// **'Edit source'**
  String get editSourceAction;

  /// No description provided for @requiredFieldError.
  ///
  /// In en, this message translates to:
  /// **'This field is required.'**
  String get requiredFieldError;

  /// No description provided for @invalidUrlError.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid server URL.'**
  String get invalidUrlError;

  /// No description provided for @connectionTestSuccess.
  ///
  /// In en, this message translates to:
  /// **'Connection succeeded.'**
  String get connectionTestSuccess;

  /// No description provided for @sourceSavedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Source saved successfully.'**
  String get sourceSavedSuccess;

  /// No description provided for @sourceUpdatedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Source settings updated.'**
  String get sourceUpdatedSuccess;

  /// No description provided for @sourceNotFoundMessage.
  ///
  /// In en, this message translates to:
  /// **'The source you tried to edit could not be found.'**
  String get sourceNotFoundMessage;

  /// No description provided for @connectionFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Connection failed. Check your WebDAV address and credentials.'**
  String get connectionFailedMessage;

  /// No description provided for @playbackFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Playback could not be started for this file.'**
  String get playbackFailedMessage;

  /// No description provided for @folderAlbumsModeLabel.
  ///
  /// In en, this message translates to:
  /// **'By folder'**
  String get folderAlbumsModeLabel;

  /// No description provided for @scrapedAlbumsModeLabel.
  ///
  /// In en, this message translates to:
  /// **'By scraped data'**
  String get scrapedAlbumsModeLabel;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
