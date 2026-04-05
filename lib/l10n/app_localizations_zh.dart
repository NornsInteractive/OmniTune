// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'Flux Music';

  @override
  String get albumsTabLabel => '专辑';

  @override
  String get collectionTabLabel => '资料库';

  @override
  String get settingsTabLabel => '设置';

  @override
  String get settingsPageTitle => '设置';

  @override
  String get openSettingsAction => '打开设置';

  @override
  String get settingsCenterHeadline => '按你的习惯调整播放器';

  @override
  String get settingsCenterDescription => '把语言、主题、音源、缓存和播放偏好集中放到一个设置中心里管理。';

  @override
  String get appearanceSettingsTitle => '外观';

  @override
  String get librarySettingsTitle => '资料库与音源';

  @override
  String get languageSettingTitle => '语言设置';

  @override
  String get themeSettingTitle => '主题设置';

  @override
  String get interfaceSizeSettingTitle => '界面大小';

  @override
  String get fontSizeSettingTitle => '字体大小';

  @override
  String interfaceScaleSummary(int percent) {
    return '组件大小 $percent%';
  }

  @override
  String fontScaleSummary(int percent) {
    return '文字大小 $percent%';
  }

  @override
  String get interfaceSizeDialogDescription => '拖动滑杆来整体放大或缩小卡片、按钮、留白和界面密度。';

  @override
  String get fontSizeDialogDescription => '拖动滑杆来调整整个应用里的文字大小。';

  @override
  String scalePercentLabel(int percent) {
    return '$percent%';
  }

  @override
  String scaleRangeLabel(int min, int max) {
    return '可调范围：$min% - $max%';
  }

  @override
  String get sourceManagementSettingTitle => '音乐音源';

  @override
  String get sourceManagementDialogDescription =>
      '这里选择用于远程浏览的音源，同时可以继续添加多个音源，并把所有已保存音源一起扫描进同一个音乐库。';

  @override
  String get sourceManagementEmptyTitle => '还没有音乐音源';

  @override
  String get sourceManagementEmptySummary => '先添加一个音乐音源，才能开始浏览和扫描音乐库。';

  @override
  String sourceManagementSummary(Object sourceName, int count) {
    return '浏览音源：$sourceName · 共 $count 个';
  }

  @override
  String savedSourcesCountLabel(int count) {
    return '$count 个音源';
  }

  @override
  String get languageOptionSystem => '跟随系统';

  @override
  String get languageOptionEnglish => '英文';

  @override
  String get languageOptionChinese => '中文';

  @override
  String get themeOptionSystem => '跟随系统';

  @override
  String get themeOptionLight => '浅色';

  @override
  String get themeOptionDark => '深色';

  @override
  String get interfaceSizeOptionCompact => '紧凑';

  @override
  String get interfaceSizeOptionStandard => '标准';

  @override
  String get interfaceSizeOptionComfortable => '宽松';

  @override
  String get fontSizeOptionSmall => '小号';

  @override
  String get fontSizeOptionStandard => '标准';

  @override
  String get fontSizeOptionLarge => '大号';

  @override
  String get fontSizeOptionExtraLarge => '超大';

  @override
  String get libraryTitle => '音乐库';

  @override
  String get addSourceAction => '添加音源';

  @override
  String get playerTitle => '正在播放';

  @override
  String get savedSourcesTitle => '已保存音源';

  @override
  String get settingsHeadline => '音源与扫描设置';

  @override
  String get settingsDescription => '在这里添加远程音乐源、切换当前音源，并发起新的全库扫描来生成专辑和歌曲视图。';

  @override
  String get playbackCacheTitle => '播放缓存';

  @override
  String get playbackCacheDescription => '播放会先直接走远程流，后台再继续缓存，下一次播放时会优先命中缓存内容。';

  @override
  String get persistentPlaybackCacheLabel => '优先使用本地文件缓存';

  @override
  String get persistentPlaybackCacheDescription =>
      '开启后，已经完整缓存好的歌曲也会保存到本地，下次优先从本地缓存播放。';

  @override
  String get memoryCacheTrackLimitLabel => '内存缓存歌曲数量';

  @override
  String get memoryCacheTrackLimitDescription =>
      '应用会把最近播放过的歌曲和已经缓存到的字节范围保留在内存中，重复播放时会优先复用这些缓存，再对缺失部分继续走网络。';

  @override
  String get cacheSettingsEntryTitle => '缓存设置';

  @override
  String get cacheStorageModeLocal => '本地文件缓存';

  @override
  String get cacheStorageModeMemory => '仅内存缓存';

  @override
  String cacheSettingsSummary(Object storageMode, int count) {
    return '$storageMode · 内存保留 $count 首';
  }

  @override
  String get clearCachedFilesTitle => '管理已缓存文件';

  @override
  String get clearCachedFilesDescription => '打开缓存列表后可勾选删除指定歌曲，也可以一键清空。';

  @override
  String get clearCachedFilesConfirmDescription => '这会删除应用当前保存的全部歌曲缓存和字节范围缓存。';

  @override
  String get clearCacheAction => '清空缓存';

  @override
  String get cacheClearedMessage => '已清空缓存文件。';

  @override
  String get cachedTracksDialogDescription => '勾选需要删除的缓存歌曲，只删除你不想保留的那部分。';

  @override
  String get cachedTracksEmptyTitle => '还没有缓存歌曲';

  @override
  String get cachedTracksEmptyDescription => '先播放一些音乐，缓存列表里才会出现内容。';

  @override
  String selectedCacheCountLabel(int count) {
    return '已选择 $count 项';
  }

  @override
  String get cacheUnknownSourceLabel => '未知音源';

  @override
  String cacheCoverageLabel(int percent) {
    return '已缓存 $percent%';
  }

  @override
  String get cacheCoverageUnknownLabel => '已有缓存数据';

  @override
  String get cacheModeHybridLabel => '内存 + 本地文件';

  @override
  String get cacheModeLocalLabel => '本地文件';

  @override
  String get cacheModeMemoryLabel => '仅内存';

  @override
  String get deleteSelectedCacheAction => '删除所选';

  @override
  String selectedCacheDeletedMessage(int count) {
    return '已删除 $count 个缓存项目。';
  }

  @override
  String get selectAllAction => '全选';

  @override
  String get clearSelectionAction => '清除选择';

  @override
  String memoryCacheTrackLimitValue(int count) {
    return '$count 首';
  }

  @override
  String get architectureReadyTitle => '面向生产的音源框架';

  @override
  String get architectureReadyDescription =>
      '当前已完成 WebDAV 接入，同时保留了统一音源注册、播放管线和刮削链路，后续可以继续扩展 SFTP、网盘和元数据刮削能力。';

  @override
  String get webdavProtocol => 'WebDAV';

  @override
  String get sftpProtocol => 'SFTP';

  @override
  String get cloudDriveProtocol => '网盘';

  @override
  String get scraperPipelineLabel => '刮削管线';

  @override
  String get scanLibraryAction => '扫描音乐库';

  @override
  String get scanningAction => '扫描中';

  @override
  String get scanNotStartedLabel => '尚未扫描';

  @override
  String get scanReadyLabel => '已生成扫描结果';

  @override
  String scanningProgress(int directories, int tracks) {
    return '已扫描 $directories 个文件夹，发现 $tracks 首歌曲';
  }

  @override
  String get libraryEmptyTitle => '先连接第一个音乐音源';

  @override
  String get libraryEmptyDescription =>
      '添加一个 WebDAV 音源后，就可以在同一套界面中浏览远程目录、展示音乐文件并直接播放。';

  @override
  String get albumsHeadline => '专辑';

  @override
  String get albumsDescription => '扫描当前音源后，会按照远程目录里的音乐文件生成专辑墙。';

  @override
  String albumsDescriptionAllSources(int count) {
    return '专辑内容会从全部 $count 个已保存音源中汇总生成。';
  }

  @override
  String albumsDescriptionWithSource(Object sourceName) {
    return '来自 $sourceName 的专辑';
  }

  @override
  String get albumsEmptyTitle => '还没有专辑内容';

  @override
  String get albumsEmptyDescription => '先执行一次扫描，把远程音乐库整理成专辑视图。';

  @override
  String get tracksLabel => '首';

  @override
  String get collectionHeadline => '我的音乐资料库';

  @override
  String collectionDescription(Object sourceName) {
    return '浏览 $sourceName，扫描全部歌曲，并在收藏、喜欢、全部歌曲和远程目录之间快速切换。';
  }

  @override
  String collectionDescriptionAllSources(
    Object browserSourceName,
    int sourceCount,
  ) {
    return '远程浏览当前音源 $browserSourceName，并把全部 $sourceCount 个已保存音源扫描到同一个资料库中展示。';
  }

  @override
  String currentScanSourceLabel(Object sourceName) {
    return '当前扫描音源：$sourceName';
  }

  @override
  String get favoritesCollectionTitle => '我的收藏';

  @override
  String get likedCollectionTitle => '我喜欢';

  @override
  String get allSongsCollectionTitle => '所有歌曲';

  @override
  String get favoritesEmptyTitle => '还没有收藏歌曲';

  @override
  String get likedEmptyTitle => '还没有喜欢的歌曲';

  @override
  String get allSongsEmptyTitle => '还没有扫描到歌曲';

  @override
  String get collectionEmptyDescription => '这个列表现在还是空的，可以先收藏喜欢的歌曲，或者重新扫描一次。';

  @override
  String get scanLibraryHint => '执行一次扫描后，这里会把所有已保存音源中的音乐文件整理成歌曲和专辑集合。';

  @override
  String get browserTitle => '远程浏览';

  @override
  String get currentPathLabel => '当前位置';

  @override
  String get upAction => '上一级';

  @override
  String get refreshAction => '刷新';

  @override
  String get noFilesTitle => '当前文件夹为空';

  @override
  String get noFilesDescription => '可以切换路径，或者刷新当前目录。';

  @override
  String get browserDiagnosticsTitle => '浏览诊断信息';

  @override
  String get unsupportedFileMessage => '这个文件可以显示，但当前还不能直接播放。';

  @override
  String get loadFailedMessage => '当前音源加载失败。';

  @override
  String get retryAction => '重试';

  @override
  String get playerEmptyTitle => '还没有选择歌曲';

  @override
  String get playerEmptyDescription => '请先从音源浏览器中选择一个音乐文件开始播放。';

  @override
  String get lyricsEmptyLabel => '当前还没有找到这首歌对应的同步歌词。';

  @override
  String get playAction => '播放';

  @override
  String get pauseAction => '暂停';

  @override
  String get stopAction => '停止';

  @override
  String get openPlayerAction => '打开播放器';

  @override
  String get settingsAddSourceTitle => '添加音源';

  @override
  String get settingsEditSourceTitle => '编辑音源';

  @override
  String get sourceNameLabel => '音源名称';

  @override
  String get sourceNameHint => '我的 NAS 音乐库';

  @override
  String get serverUrlLabel => '服务器地址';

  @override
  String get serverUrlHint =>
      'https://dav.example.com/remote.php/dav/files/user/';

  @override
  String get usernameLabel => '用户名';

  @override
  String get passwordLabel => '密码或应用令牌';

  @override
  String get rootPathLabel => '根路径';

  @override
  String get rootPathHint => '/Music/';

  @override
  String get rootPathHelpText => '如果服务器地址已经直接指向目标目录，这里保持为 “/” 即可。';

  @override
  String get scanDirectoriesTitle => '扫描目录';

  @override
  String get scanDirectoriesDescription => '可以添加多个需要扫描的目录。留空时会默认从当前音源根目录开始扫描。';

  @override
  String get scanDirectoriesDefaultRootDescription =>
      '当前没有单独配置扫描目录，扫描时会从这个音源的根目录开始。';

  @override
  String get addScanDirectoryAction => '添加扫描目录';

  @override
  String get addScanDirectoryDialogTitle => '添加扫描目录';

  @override
  String get scanDirectoriesDialogDescription =>
      '输入一个相对当前音源根目录的目录路径，例如 /Jazz/ 或 /Live/Concerts/。';

  @override
  String get excludedScanDirectoriesTitle => '排除目录';

  @override
  String get excludedScanDirectoriesDescription => '这些目录会在扫描时被跳过，支持添加多个。';

  @override
  String get excludedScanDirectoriesEmptyDescription =>
      '当前没有排除目录，扫描时会包含根目录下的所有子目录。';

  @override
  String get addExcludedScanDirectoryAction => '添加排除目录';

  @override
  String get addExcludedScanDirectoryDialogTitle => '添加排除目录';

  @override
  String get excludedScanDirectoriesDialogDescription =>
      '输入一个需要跳过的目录路径，例如 /Temp/ 或 /Podcasts/。';

  @override
  String get directoryPathLabel => '目录路径';

  @override
  String get directoryPathHint => '/Albums/';

  @override
  String get directoryPathHelpText => '目录路径会相对于当前音源根目录生效，建议始终以 / 开头。';

  @override
  String get testConnectionAction => '测试连接';

  @override
  String get saveSourceAction => '保存音源';

  @override
  String get saveSourceChangesAction => '保存修改';

  @override
  String get editSourceAction => '编辑音源';

  @override
  String get requiredFieldError => '此项不能为空。';

  @override
  String get invalidUrlError => '请输入有效的服务器地址。';

  @override
  String get connectionTestSuccess => '连接测试成功。';

  @override
  String get sourceSavedSuccess => '音源保存成功。';

  @override
  String get sourceUpdatedSuccess => '音源配置已更新。';

  @override
  String get sourceNotFoundMessage => '没有找到要编辑的音源，可能已经被删除。';

  @override
  String get connectionFailedMessage => '连接失败，请检查 WebDAV 地址和凭证。';

  @override
  String get playbackFailedMessage => '当前文件无法启动播放。';

  @override
  String get folderAlbumsModeLabel => '按文件夹';

  @override
  String get scrapedAlbumsModeLabel => '按刮削分类';

  @override
  String get songDetailsTitle => '歌曲详情';

  @override
  String get filePathLabel => '文件路径';

  @override
  String get sourceLabel => '音源';

  @override
  String get artistLabel => '艺术家';

  @override
  String get albumLabel => '专辑';

  @override
  String get addToFavoritesAction => '添加到收藏';

  @override
  String get removeFromFavoritesAction => '从收藏移除';

  @override
  String get addToLikedAction => '标记为喜欢';

  @override
  String get removeFromLikedAction => '取消喜欢';

  @override
  String get moreOptionsAction => '更多选项';

  @override
  String get debugSettingsTitle => '开发者';

  @override
  String get debugModeLabel => '调试模式';

  @override
  String get debugModeDescription => '异常发生时显示错误对话框';
}
