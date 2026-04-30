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

  /// No description provided for @themeAccentColorSettingTitle.
  ///
  /// In en, this message translates to:
  /// **'Accent color'**
  String get themeAccentColorSettingTitle;

  /// No description provided for @themeAccentColorDefaultLabel.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get themeAccentColorDefaultLabel;

  /// No description provided for @themeBorderRadiusSettingTitle.
  ///
  /// In en, this message translates to:
  /// **'Corner radius'**
  String get themeBorderRadiusSettingTitle;

  /// No description provided for @themeCompactnessSettingTitle.
  ///
  /// In en, this message translates to:
  /// **'Density'**
  String get themeCompactnessSettingTitle;

  /// No description provided for @backgroundImageSettingTitle.
  ///
  /// In en, this message translates to:
  /// **'Background image'**
  String get backgroundImageSettingTitle;

  /// No description provided for @backgroundImageDefaultSummary.
  ///
  /// In en, this message translates to:
  /// **'Using the default gradient background'**
  String get backgroundImageDefaultSummary;

  /// No description provided for @backgroundImageConfiguredSummary.
  ///
  /// In en, this message translates to:
  /// **'Custom background image configured'**
  String get backgroundImageConfiguredSummary;

  /// No description provided for @backgroundImageDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Set background image'**
  String get backgroundImageDialogTitle;

  /// No description provided for @backgroundImageDialogDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose an image as the background for every page. The player keeps its cover-focused atmosphere while a track is playing.'**
  String get backgroundImageDialogDescription;

  /// No description provided for @backgroundImagePositionHelpText.
  ///
  /// In en, this message translates to:
  /// **'Drag the preview to choose which part of the image appears at the current screen ratio.'**
  String get backgroundImagePositionHelpText;

  /// No description provided for @backgroundImageChooseAction.
  ///
  /// In en, this message translates to:
  /// **'Choose image'**
  String get backgroundImageChooseAction;

  /// No description provided for @backgroundImageChangeAction.
  ///
  /// In en, this message translates to:
  /// **'Change image'**
  String get backgroundImageChangeAction;

  /// No description provided for @backgroundImageClearAction.
  ///
  /// In en, this message translates to:
  /// **'Clear background'**
  String get backgroundImageClearAction;

  /// No description provided for @backgroundImageCenterAction.
  ///
  /// In en, this message translates to:
  /// **'Center'**
  String get backgroundImageCenterAction;

  /// No description provided for @backgroundImageEmptyPreview.
  ///
  /// In en, this message translates to:
  /// **'No background image selected yet'**
  String get backgroundImageEmptyPreview;

  /// No description provided for @backgroundImageFileTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Images'**
  String get backgroundImageFileTypeLabel;

  /// No description provided for @themeColorDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose accent color'**
  String get themeColorDialogTitle;

  /// No description provided for @themeColorPresetLabel.
  ///
  /// In en, this message translates to:
  /// **'Preset colors'**
  String get themeColorPresetLabel;

  /// No description provided for @themeColorHexFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Hex color'**
  String get themeColorHexFieldLabel;

  /// No description provided for @themeColorHexFieldHint.
  ///
  /// In en, this message translates to:
  /// **'Enter a value like #FF5722'**
  String get themeColorHexFieldHint;

  /// No description provided for @themeBorderRadiusDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Corner radius'**
  String get themeBorderRadiusDialogTitle;

  /// No description provided for @themeBorderRadiusRangeLabel.
  ///
  /// In en, this message translates to:
  /// **'Range: 12.0 - 32.0px'**
  String get themeBorderRadiusRangeLabel;

  /// No description provided for @themeCompactnessDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Density'**
  String get themeCompactnessDialogTitle;

  /// No description provided for @themeCompactnessRangeLabel.
  ///
  /// In en, this message translates to:
  /// **'50% (compact) - 150% (comfortable)'**
  String get themeCompactnessRangeLabel;

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
  /// **'Cache to local files'**
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
  /// **'The app is structured around a unified source registry, playback pipeline, and scraper chain for WebDAV, SFTP, FTP, Samba, and cloud sources.'**
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

  /// No description provided for @ftpProtocol.
  ///
  /// In en, this message translates to:
  /// **'FTP'**
  String get ftpProtocol;

  /// No description provided for @sambaProtocol.
  ///
  /// In en, this message translates to:
  /// **'Samba'**
  String get sambaProtocol;

  /// No description provided for @cloudDriveProtocol.
  ///
  /// In en, this message translates to:
  /// **'Cloud drive'**
  String get cloudDriveProtocol;

  /// No description provided for @cloud189Protocol.
  ///
  /// In en, this message translates to:
  /// **'189 Cloud'**
  String get cloud189Protocol;

  /// No description provided for @sourceProtocolLabel.
  ///
  /// In en, this message translates to:
  /// **'Source type'**
  String get sourceProtocolLabel;

  /// No description provided for @sourceTypeSelectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a source type'**
  String get sourceTypeSelectionTitle;

  /// No description provided for @sourceTypeSelectionDescription.
  ///
  /// In en, this message translates to:
  /// **'Select the protocol first, then enter the connection details for that source.'**
  String get sourceTypeSelectionDescription;

  /// No description provided for @webdavSourceTypeTitle.
  ///
  /// In en, this message translates to:
  /// **'WebDAV source'**
  String get webdavSourceTypeTitle;

  /// No description provided for @webdavSourceDescription.
  ///
  /// In en, this message translates to:
  /// **'Connect to a NAS or server that exposes your music library through WebDAV.'**
  String get webdavSourceDescription;

  /// No description provided for @sftpSourceTypeTitle.
  ///
  /// In en, this message translates to:
  /// **'SFTP source'**
  String get sftpSourceTypeTitle;

  /// No description provided for @sftpSourceDescription.
  ///
  /// In en, this message translates to:
  /// **'Connect to an SSH/SFTP server and browse music files from a remote directory.'**
  String get sftpSourceDescription;

  /// No description provided for @ftpSourceTypeTitle.
  ///
  /// In en, this message translates to:
  /// **'FTP source'**
  String get ftpSourceTypeTitle;

  /// No description provided for @ftpSourceDescription.
  ///
  /// In en, this message translates to:
  /// **'Connect to FTP, FTPS, or FTPES servers. Playback downloads the file to temporary local cache first.'**
  String get ftpSourceDescription;

  /// No description provided for @sambaSourceTypeTitle.
  ///
  /// In en, this message translates to:
  /// **'Samba source'**
  String get sambaSourceTypeTitle;

  /// No description provided for @sambaSourceDescription.
  ///
  /// In en, this message translates to:
  /// **'Connect to SMB/Samba shares such as a NAS shared folder.'**
  String get sambaSourceDescription;

  /// No description provided for @cloud189SourceTypeTitle.
  ///
  /// In en, this message translates to:
  /// **'189 Cloud source'**
  String get cloud189SourceTypeTitle;

  /// No description provided for @cloud189SourceDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose the OpenList-compatible mount flow or use your own 189 Cloud app credentials for OAuth authorization.'**
  String get cloud189SourceDescription;

  /// No description provided for @cloud189DefaultSourceName.
  ///
  /// In en, this message translates to:
  /// **'189 Cloud'**
  String get cloud189DefaultSourceName;

  /// No description provided for @cloud189OpenListModeLabel.
  ///
  /// In en, this message translates to:
  /// **'OpenList mount'**
  String get cloud189OpenListModeLabel;

  /// No description provided for @cloud189AppAuthorizationModeLabel.
  ///
  /// In en, this message translates to:
  /// **'App authorization'**
  String get cloud189AppAuthorizationModeLabel;

  /// No description provided for @cloud189OpenListModeDescription.
  ///
  /// In en, this message translates to:
  /// **'Matches the OpenList 189Cloud driver: enter the phone number and password used for 189 Cloud login, then the app keeps the session for browsing files.'**
  String get cloud189OpenListModeDescription;

  /// No description provided for @cloud189AppAuthorizationModeDescription.
  ///
  /// In en, this message translates to:
  /// **'Use an appKey/appSecret issued by 189 Cloud. After the user authorizes this app, paste the returned code or refreshToken here.'**
  String get cloud189AppAuthorizationModeDescription;

  /// No description provided for @cloud189OpenAuthorizationAction.
  ///
  /// In en, this message translates to:
  /// **'Open 189 Cloud app authorization'**
  String get cloud189OpenAuthorizationAction;

  /// No description provided for @cloud189AuthorizationOpenedMessage.
  ///
  /// In en, this message translates to:
  /// **'Authorization opened. After approving this app in 189 Cloud, paste the returned code or refreshToken here.'**
  String get cloud189AuthorizationOpenedMessage;

  /// No description provided for @cloud189AuthorizationOpenFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Unable to open the 189 Cloud authorization page on this device.'**
  String get cloud189AuthorizationOpenFailedMessage;

  /// No description provided for @cloud189AppAuthorizationConfigRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter appKey and redirect URI before opening authorization.'**
  String get cloud189AppAuthorizationConfigRequired;

  /// No description provided for @cloud189RefreshTokenLabel.
  ///
  /// In en, this message translates to:
  /// **'189 Cloud refresh token'**
  String get cloud189RefreshTokenLabel;

  /// No description provided for @cloud189RefreshTokenHint.
  ///
  /// In en, this message translates to:
  /// **'Paste refreshToken from 189 Cloud authorization'**
  String get cloud189RefreshTokenHint;

  /// No description provided for @cloud189RefreshTokenHelpText.
  ///
  /// In en, this message translates to:
  /// **'The token is stored securely and used only to refresh your 189 Cloud session.'**
  String get cloud189RefreshTokenHelpText;

  /// No description provided for @cloud189OpenListRefreshTokenLabel.
  ///
  /// In en, this message translates to:
  /// **'OpenList refreshToken'**
  String get cloud189OpenListRefreshTokenLabel;

  /// No description provided for @cloud189OpenListRefreshTokenHint.
  ///
  /// In en, this message translates to:
  /// **'Paste the refreshToken used by OpenList 189CloudPC'**
  String get cloud189OpenListRefreshTokenHint;

  /// No description provided for @cloud189OpenListRefreshTokenHelpText.
  ///
  /// In en, this message translates to:
  /// **'This follows the OpenList-compatible PC session flow and does not require your own appKey.'**
  String get cloud189OpenListRefreshTokenHelpText;

  /// No description provided for @cloud189OpenListUsernameLabel.
  ///
  /// In en, this message translates to:
  /// **'189 Cloud username'**
  String get cloud189OpenListUsernameLabel;

  /// No description provided for @cloud189OpenListUsernameHint.
  ///
  /// In en, this message translates to:
  /// **'Phone number used to log in'**
  String get cloud189OpenListUsernameHint;

  /// No description provided for @cloud189OpenListUsernameHelpText.
  ///
  /// In en, this message translates to:
  /// **'Same as the Username field in OpenList 189Cloud.'**
  String get cloud189OpenListUsernameHelpText;

  /// No description provided for @cloud189OpenListPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'189 Cloud password'**
  String get cloud189OpenListPasswordLabel;

  /// No description provided for @cloud189OpenListPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Password used to log in'**
  String get cloud189OpenListPasswordHint;

  /// No description provided for @cloud189OpenListPasswordHelpText.
  ///
  /// In en, this message translates to:
  /// **'Same as the Password field in OpenList 189Cloud.'**
  String get cloud189OpenListPasswordHelpText;

  /// No description provided for @cloud189AppKeyLabel.
  ///
  /// In en, this message translates to:
  /// **'189 Cloud appKey'**
  String get cloud189AppKeyLabel;

  /// No description provided for @cloud189AppKeyHint.
  ///
  /// In en, this message translates to:
  /// **'AppKey issued by 189 Cloud'**
  String get cloud189AppKeyHint;

  /// No description provided for @cloud189AppKeyHelpText.
  ///
  /// In en, this message translates to:
  /// **'Apply for an appKey in the 189 Cloud developer platform before using app authorization.'**
  String get cloud189AppKeyHelpText;

  /// No description provided for @cloud189AppSecretLabel.
  ///
  /// In en, this message translates to:
  /// **'189 Cloud appSecret'**
  String get cloud189AppSecretLabel;

  /// No description provided for @cloud189AppSecretHint.
  ///
  /// In en, this message translates to:
  /// **'AppSecret issued with your appKey'**
  String get cloud189AppSecretHint;

  /// No description provided for @cloud189RedirectUriLabel.
  ///
  /// In en, this message translates to:
  /// **'Redirect URI'**
  String get cloud189RedirectUriLabel;

  /// No description provided for @cloud189RedirectUriHint.
  ///
  /// In en, this message translates to:
  /// **'music://cloud189/callback'**
  String get cloud189RedirectUriHint;

  /// No description provided for @cloud189RedirectUriHelpText.
  ///
  /// In en, this message translates to:
  /// **'Use the redirect URI configured for your 189 Cloud application.'**
  String get cloud189RedirectUriHelpText;

  /// No description provided for @cloud189AuthorizationCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Authorization code'**
  String get cloud189AuthorizationCodeLabel;

  /// No description provided for @cloud189AuthorizationCodeHint.
  ///
  /// In en, this message translates to:
  /// **'Paste the code returned by app authorization'**
  String get cloud189AuthorizationCodeHint;

  /// No description provided for @cloud189AuthorizationCodeHelpText.
  ///
  /// In en, this message translates to:
  /// **'Leave this empty only if you already have a refreshToken for the same appKey.'**
  String get cloud189AuthorizationCodeHelpText;

  /// No description provided for @cloud189AppRefreshTokenLabel.
  ///
  /// In en, this message translates to:
  /// **'App refreshToken'**
  String get cloud189AppRefreshTokenLabel;

  /// No description provided for @cloud189AppRefreshTokenHint.
  ///
  /// In en, this message translates to:
  /// **'Optional refreshToken for this appKey'**
  String get cloud189AppRefreshTokenHint;

  /// No description provided for @cloud189AppRefreshTokenHelpText.
  ///
  /// In en, this message translates to:
  /// **'If provided, the app uses it directly instead of exchanging an authorization code.'**
  String get cloud189AppRefreshTokenHelpText;

  /// No description provided for @cloud189AuthorizationCredentialRequiredError.
  ///
  /// In en, this message translates to:
  /// **'Enter an authorization code or refreshToken.'**
  String get cloud189AuthorizationCredentialRequiredError;

  /// No description provided for @cloud189RootPathHint.
  ///
  /// In en, this message translates to:
  /// **'/Music/'**
  String get cloud189RootPathHint;

  /// No description provided for @cloud189RootPathHelpText.
  ///
  /// In en, this message translates to:
  /// **'Use a folder path in 189 Cloud. Leave \'/\' to start at the cloud root.'**
  String get cloud189RootPathHelpText;

  /// No description provided for @cloud189ConnectionFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'189 Cloud connection failed. Check the credentials; enable debug mode to view the request log.'**
  String get cloud189ConnectionFailedMessage;

  /// No description provided for @cloud189DebugLogDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'189 Cloud debug log'**
  String get cloud189DebugLogDialogTitle;

  /// No description provided for @cloud189DebugLogDialogDescription.
  ///
  /// In en, this message translates to:
  /// **'Request URLs, parameters, and response summaries from this source setup are shown with sensitive values redacted.'**
  String get cloud189DebugLogDialogDescription;

  /// No description provided for @cloud189CaptchaDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter 189 Cloud captcha'**
  String get cloud189CaptchaDialogTitle;

  /// No description provided for @cloud189CaptchaDialogDescription.
  ///
  /// In en, this message translates to:
  /// **'Automatic recognition is temporarily unavailable. Enter the characters from the image to continue login.'**
  String get cloud189CaptchaDialogDescription;

  /// No description provided for @cloud189CaptchaCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Captcha'**
  String get cloud189CaptchaCodeLabel;

  /// No description provided for @cloud189CaptchaCodeHint.
  ///
  /// In en, this message translates to:
  /// **'Enter the characters in the image'**
  String get cloud189CaptchaCodeHint;

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
  /// **'Add a music source to browse remote folders, list music files, and start playback from the same library interface.'**
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
  /// **'Browse {sourceName}, scan all songs, and jump between all songs, liked songs, and favorites.'**
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

  /// No description provided for @showLyricsAction.
  ///
  /// In en, this message translates to:
  /// **'Show lyrics'**
  String get showLyricsAction;

  /// No description provided for @hideLyricsAction.
  ///
  /// In en, this message translates to:
  /// **'Hide lyrics'**
  String get hideLyricsAction;

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

  /// No description provided for @closeAction.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get closeAction;

  /// No description provided for @previousTrackAction.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get previousTrackAction;

  /// No description provided for @nextTrackAction.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get nextTrackAction;

  /// No description provided for @playNextAction.
  ///
  /// In en, this message translates to:
  /// **'Play next'**
  String get playNextAction;

  /// No description provided for @playlistTitle.
  ///
  /// In en, this message translates to:
  /// **'Playlist'**
  String get playlistTitle;

  /// No description provided for @playlistEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'The playlist is empty.'**
  String get playlistEmptyTitle;

  /// No description provided for @removeFromPlaylistAction.
  ///
  /// In en, this message translates to:
  /// **'Remove from playlist'**
  String get removeFromPlaylistAction;

  /// No description provided for @currentTrackLabel.
  ///
  /// In en, this message translates to:
  /// **'Now playing'**
  String get currentTrackLabel;

  /// No description provided for @playbackModeList.
  ///
  /// In en, this message translates to:
  /// **'List play'**
  String get playbackModeList;

  /// No description provided for @playbackModeRepeatOne.
  ///
  /// In en, this message translates to:
  /// **'Repeat one'**
  String get playbackModeRepeatOne;

  /// No description provided for @playbackModeShuffle.
  ///
  /// In en, this message translates to:
  /// **'Shuffle'**
  String get playbackModeShuffle;

  /// No description provided for @playlistCountLabel.
  ///
  /// In en, this message translates to:
  /// **'{count} in queue'**
  String playlistCountLabel(int count);

  /// No description provided for @addedToPlayNextMessage.
  ///
  /// In en, this message translates to:
  /// **'Added to play next: {title}'**
  String addedToPlayNextMessage(Object title);

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

  /// No description provided for @sftpServerUrlHint.
  ///
  /// In en, this message translates to:
  /// **'sftp://server.example.com:22/home/user'**
  String get sftpServerUrlHint;

  /// No description provided for @ftpServerUrlHint.
  ///
  /// In en, this message translates to:
  /// **'ftp://server.example.com/Music'**
  String get ftpServerUrlHint;

  /// No description provided for @sambaServerUrlHint.
  ///
  /// In en, this message translates to:
  /// **'smb://server.example.com/share'**
  String get sambaServerUrlHint;

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

  /// No description provided for @sambaPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get sambaPasswordLabel;

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

  /// No description provided for @sambaRootPathHint.
  ///
  /// In en, this message translates to:
  /// **'/Music/'**
  String get sambaRootPathHint;

  /// No description provided for @rootPathHelpText.
  ///
  /// In en, this message translates to:
  /// **'If the server URL already points to the target folder, keep this as \'/\'.'**
  String get rootPathHelpText;

  /// No description provided for @sftpRootPathHelpText.
  ///
  /// In en, this message translates to:
  /// **'The path is relative to the SFTP URL path. Use \'/\' to start at that base directory.'**
  String get sftpRootPathHelpText;

  /// No description provided for @ftpRootPathHelpText.
  ///
  /// In en, this message translates to:
  /// **'The path is relative to the FTP URL path. Use \'/\' to start at that base directory.'**
  String get ftpRootPathHelpText;

  /// No description provided for @sambaRootPathHelpText.
  ///
  /// In en, this message translates to:
  /// **'The path is relative to the SMB share in the server URL. Use \'/\' to start at the share root.'**
  String get sambaRootPathHelpText;

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
  /// **'Connection failed. Check the server address, root path, and credentials.'**
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

  /// No description provided for @songDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Track details'**
  String get songDetailsTitle;

  /// No description provided for @filePathLabel.
  ///
  /// In en, this message translates to:
  /// **'File path'**
  String get filePathLabel;

  /// No description provided for @sourceLabel.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get sourceLabel;

  /// No description provided for @artistLabel.
  ///
  /// In en, this message translates to:
  /// **'Artist'**
  String get artistLabel;

  /// No description provided for @albumLabel.
  ///
  /// In en, this message translates to:
  /// **'Album'**
  String get albumLabel;

  /// No description provided for @addToFavoritesAction.
  ///
  /// In en, this message translates to:
  /// **'Add to favorites'**
  String get addToFavoritesAction;

  /// No description provided for @removeFromFavoritesAction.
  ///
  /// In en, this message translates to:
  /// **'Remove from favorites'**
  String get removeFromFavoritesAction;

  /// No description provided for @addToLikedAction.
  ///
  /// In en, this message translates to:
  /// **'Add to liked'**
  String get addToLikedAction;

  /// No description provided for @removeFromLikedAction.
  ///
  /// In en, this message translates to:
  /// **'Remove from liked'**
  String get removeFromLikedAction;

  /// No description provided for @moreOptionsAction.
  ///
  /// In en, this message translates to:
  /// **'More options'**
  String get moreOptionsAction;

  /// No description provided for @debugSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Developer'**
  String get debugSettingsTitle;

  /// No description provided for @debugModeLabel.
  ///
  /// In en, this message translates to:
  /// **'Debug mode'**
  String get debugModeLabel;

  /// No description provided for @debugModeDescription.
  ///
  /// In en, this message translates to:
  /// **'Show error dialogs when exceptions occur'**
  String get debugModeDescription;

  /// No description provided for @debugModeEnabledMessage.
  ///
  /// In en, this message translates to:
  /// **'🔍 Debug mode enabled - check console for detailed logs'**
  String get debugModeEnabledMessage;

  /// No description provided for @manualScrapingTitle.
  ///
  /// In en, this message translates to:
  /// **'Manual Scraping'**
  String get manualScrapingTitle;

  /// No description provided for @manualScrapingActionLabel.
  ///
  /// In en, this message translates to:
  /// **'Scrape metadata'**
  String get manualScrapingActionLabel;

  /// No description provided for @scrapingSongName.
  ///
  /// In en, this message translates to:
  /// **'Song name'**
  String get scrapingSongName;

  /// No description provided for @scrapingArtistName.
  ///
  /// In en, this message translates to:
  /// **'Artist name'**
  String get scrapingArtistName;

  /// No description provided for @scrapingSearchButton.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get scrapingSearchButton;

  /// No description provided for @scrapingSearchingLabel.
  ///
  /// In en, this message translates to:
  /// **'Searching...'**
  String get scrapingSearchingLabel;

  /// No description provided for @scrapingSearchResultsTitle.
  ///
  /// In en, this message translates to:
  /// **'Search Results'**
  String get scrapingSearchResultsTitle;

  /// No description provided for @scrapingNoResultsMessage.
  ///
  /// In en, this message translates to:
  /// **'No results found'**
  String get scrapingNoResultsMessage;

  /// No description provided for @scrapingMatchScoreLabel.
  ///
  /// In en, this message translates to:
  /// **'Match: {score}%'**
  String scrapingMatchScoreLabel(int score);

  /// No description provided for @scrapingSelectButtonLabel.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get scrapingSelectButtonLabel;

  /// No description provided for @scrapingCoverLabel.
  ///
  /// In en, this message translates to:
  /// **'Cover'**
  String get scrapingCoverLabel;

  /// No description provided for @scrapingLyricsLabel.
  ///
  /// In en, this message translates to:
  /// **'Lyrics'**
  String get scrapingLyricsLabel;

  /// No description provided for @scrapingUpdateCoverAction.
  ///
  /// In en, this message translates to:
  /// **'Update cover'**
  String get scrapingUpdateCoverAction;

  /// No description provided for @scrapingUpdateLyricsAction.
  ///
  /// In en, this message translates to:
  /// **'Get lyrics'**
  String get scrapingUpdateLyricsAction;

  /// No description provided for @scrapingResultApplied.
  ///
  /// In en, this message translates to:
  /// **'Metadata applied successfully'**
  String get scrapingResultApplied;

  /// No description provided for @scrapingErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'Scraping failed'**
  String get scrapingErrorMessage;

  /// No description provided for @scrapingRetryAction.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get scrapingRetryAction;

  /// No description provided for @automaticScrapingLabel.
  ///
  /// In en, this message translates to:
  /// **'Automatic'**
  String get automaticScrapingLabel;

  /// No description provided for @manualScrapingLabel.
  ///
  /// In en, this message translates to:
  /// **'Manual'**
  String get manualScrapingLabel;

  /// No description provided for @autoScrapedLabel.
  ///
  /// In en, this message translates to:
  /// **'Auto-scraped'**
  String get autoScrapedLabel;

  /// No description provided for @manuallyScrapedLabel.
  ///
  /// In en, this message translates to:
  /// **'Manually scraped'**
  String get manuallyScrapedLabel;

  /// No description provided for @debugLogsTitle.
  ///
  /// In en, this message translates to:
  /// **'Debug logs'**
  String get debugLogsTitle;

  /// No description provided for @debugLogsTabLabel.
  ///
  /// In en, this message translates to:
  /// **'Debug logs'**
  String get debugLogsTabLabel;

  /// No description provided for @clearAction.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clearAction;

  /// No description provided for @autoScrollLabel.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get autoScrollLabel;

  /// No description provided for @noLogsAvailable.
  ///
  /// In en, this message translates to:
  /// **'No logs'**
  String get noLogsAvailable;

  /// No description provided for @logsExportedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Logs copied to clipboard'**
  String get logsExportedToClipboard;

  /// No description provided for @exportAction.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get exportAction;

  /// No description provided for @copyLogsAction.
  ///
  /// In en, this message translates to:
  /// **'Copy logs'**
  String get copyLogsAction;
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
