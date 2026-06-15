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
  String get homeTabLabel => '首页';

  @override
  String get albumsTabLabel => '专辑';

  @override
  String get collectionTabLabel => '音乐库';

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
  String get themeAccentColorSettingTitle => '主题强调色';

  @override
  String get themeAccentColorDefaultLabel => '使用系统默认';

  @override
  String get themeBorderRadiusSettingTitle => '圆角大小';

  @override
  String get themeCompactnessSettingTitle => '界面紧凑度';

  @override
  String get backgroundImageSettingTitle => '背景图片';

  @override
  String get backgroundImageDefaultSummary => '使用默认渐变背景';

  @override
  String get backgroundImageConfiguredSummary => '已设置自定义背景图片';

  @override
  String get backgroundImageDialogTitle => '设置背景图片';

  @override
  String get backgroundImageDialogDescription =>
      '选择一张图片作为所有界面的背景。播放器界面正在播放时会优先使用封面氛围，不叠加该背景。';

  @override
  String get backgroundImagePositionHelpText => '拖动预览图来选择当前屏幕比例下显示图片的哪个位置。';

  @override
  String get backgroundImageChooseAction => '选择图片';

  @override
  String get backgroundImageChangeAction => '更换图片';

  @override
  String get backgroundImageClearAction => '清除背景';

  @override
  String get backgroundImageCenterAction => '居中';

  @override
  String get backgroundImageEmptyPreview => '还没有选择背景图片';

  @override
  String get backgroundImageFileTypeLabel => '图片';

  @override
  String get themeColorDialogTitle => '选择主题强调色';

  @override
  String get themeColorPresetLabel => '预设颜色';

  @override
  String get themeColorHexFieldLabel => 'Hex 颜色值';

  @override
  String get themeColorHexFieldHint => '输入类似 #FF5722 的值';

  @override
  String get themeBorderRadiusDialogTitle => '圆角大小';

  @override
  String get themeBorderRadiusRangeLabel => '可调范围：12.0 - 32.0px';

  @override
  String get themeCompactnessDialogTitle => '界面紧凑度';

  @override
  String get themeCompactnessRangeLabel => '50%（紧凑）- 150%（宽松）';

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
  String get webApkBannerTitle => '需要完整功能版？';

  @override
  String get webApkBannerDescription =>
      'Android APK 比 Web 版支持更多协议。若你需要 FTP、SFTP、Samba 和更完整的播放体验，请下载 APK。';

  @override
  String get webApkBannerUnavailableLabel =>
      '当前 Web 版已经可用，但这次部署还没有配置 APK 下载链接。';

  @override
  String get webApkBannerDownloadAction => '下载 APK';

  @override
  String get webApkBannerLaunchFailedMessage => '无法在当前设备打开 APK 下载链接。';

  @override
  String get playbackCacheTitle => '播放缓存';

  @override
  String get playbackCacheDescription => '播放会先直接走远程流，后台再继续缓存，下一次播放时会优先命中缓存内容。';

  @override
  String get persistentPlaybackCacheLabel => '缓存到本地文件';

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
      '当前通过统一音源注册、播放管线和刮削链路接入 WebDAV、SFTP、FTP、Samba 与网盘音源。';

  @override
  String get webdavProtocol => 'WebDAV';

  @override
  String get sftpProtocol => 'SFTP';

  @override
  String get ftpProtocol => 'FTP';

  @override
  String get sambaProtocol => 'Samba';

  @override
  String get cloudDriveProtocol => '网盘';

  @override
  String get cloud189Protocol => '天翼网盘';

  @override
  String get sourceProtocolLabel => '音源类型';

  @override
  String get sourceTypeSelectionTitle => '选择音源类型';

  @override
  String get sourceTypeSelectionDescription => '先选择要添加的协议，再进入对应的连接配置页面。';

  @override
  String get webdavSourceTypeTitle => 'WebDAV 音源';

  @override
  String get webdavSourceDescription => '连接通过 WebDAV 暴露音乐目录的 NAS 或服务器。';

  @override
  String get sftpSourceTypeTitle => 'SFTP 音源';

  @override
  String get sftpSourceDescription => '连接 SSH/SFTP 服务器，从远程目录中浏览和播放音乐文件。';

  @override
  String get ftpSourceTypeTitle => 'FTP 音源';

  @override
  String get ftpSourceDescription =>
      '连接 FTP、FTPS 或 FTPES 服务器。播放时会先把文件下载到临时本地缓存。';

  @override
  String get sambaSourceTypeTitle => 'Samba 音源';

  @override
  String get sambaSourceDescription => '连接 NAS 共享文件夹等 SMB/Samba 音源。';

  @override
  String get cloud189SourceTypeTitle => '天翼网盘音源';

  @override
  String get cloud189SourceDescription =>
      '可选择 OpenList 兼容挂载方式，也可以使用你申请到的天翼网盘应用凭证进行 OAuth 授权。';

  @override
  String get cloud189DefaultSourceName => '天翼网盘';

  @override
  String get cloud189OpenListModeLabel => 'OpenList 挂载';

  @override
  String get cloud189AppAuthorizationModeLabel => '应用授权';

  @override
  String get cloud189OpenListModeDescription =>
      '与 OpenList 的 189Cloud 驱动一致：填写用于登录天翼网盘的手机号和密码，然后应用保持会话来浏览文件。';

  @override
  String get cloud189AppAuthorizationModeDescription =>
      '使用天翼网盘分配的 appKey/appSecret。用户在天翼网盘中授权该应用后，把返回的 code 或 refreshToken 粘贴到这里。';

  @override
  String get cloud189OpenAuthorizationAction => '打开天翼网盘应用授权';

  @override
  String get cloud189AuthorizationOpenedMessage =>
      '已打开授权入口。请在天翼网盘中授权该应用后，把返回的 code 或 refreshToken 粘贴到这里。';

  @override
  String get cloud189AuthorizationOpenFailedMessage => '无法在当前设备打开天翼网盘授权页面。';

  @override
  String get cloud189AppAuthorizationConfigRequired =>
      '请先填写 appKey 和回调地址，再打开授权。';

  @override
  String get cloud189RefreshTokenLabel => '天翼网盘 refreshToken';

  @override
  String get cloud189RefreshTokenHint => '粘贴天翼网盘授权得到的 refreshToken';

  @override
  String get cloud189RefreshTokenHelpText => 'Token 会安全保存，仅用于刷新天翼网盘会话。';

  @override
  String get cloud189OpenListRefreshTokenLabel => 'OpenList refreshToken';

  @override
  String get cloud189OpenListRefreshTokenHint =>
      '粘贴 OpenList 189CloudPC 使用的 refreshToken';

  @override
  String get cloud189OpenListRefreshTokenHelpText =>
      '该方式沿用 OpenList 兼容的 PC 会话流程，不需要你自己的 appKey。';

  @override
  String get cloud189OpenListUsernameLabel => '天翼网盘用户名';

  @override
  String get cloud189OpenListUsernameHint => '用于登录的手机号';

  @override
  String get cloud189OpenListUsernameHelpText =>
      '对应 OpenList 189Cloud 的 Username 字段。';

  @override
  String get cloud189OpenListPasswordLabel => '天翼网盘密码';

  @override
  String get cloud189OpenListPasswordHint => '用于登录的密码';

  @override
  String get cloud189OpenListPasswordHelpText =>
      '对应 OpenList 189Cloud 的 Password 字段。';

  @override
  String get cloud189AppKeyLabel => '天翼网盘 appKey';

  @override
  String get cloud189AppKeyHint => '天翼网盘分配的应用 Key';

  @override
  String get cloud189AppKeyHelpText => '使用应用授权前，需要先在天翼网盘开放平台申请 appKey。';

  @override
  String get cloud189AppSecretLabel => '天翼网盘 appSecret';

  @override
  String get cloud189AppSecretHint => '与 appKey 配套的应用密钥';

  @override
  String get cloud189RedirectUriLabel => '回调地址';

  @override
  String get cloud189RedirectUriHint => 'music://cloud189/callback';

  @override
  String get cloud189RedirectUriHelpText => '填写你在天翼网盘应用配置中的回调地址。';

  @override
  String get cloud189AuthorizationCodeLabel => '授权 code';

  @override
  String get cloud189AuthorizationCodeHint => '粘贴应用授权返回的 code';

  @override
  String get cloud189AuthorizationCodeHelpText =>
      '如果你已经有同一 appKey 对应的 refreshToken，可以留空。';

  @override
  String get cloud189AppRefreshTokenLabel => '应用 refreshToken';

  @override
  String get cloud189AppRefreshTokenHint => '可选，填写该 appKey 对应的 refreshToken';

  @override
  String get cloud189AppRefreshTokenHelpText => '填写后会直接使用它刷新会话，不再交换授权 code。';

  @override
  String get cloud189AuthorizationCredentialRequiredError =>
      '请填写授权 code 或 refreshToken。';

  @override
  String get cloud189RootPathHint => '/音乐/';

  @override
  String get cloud189RootPathHelpText => '填写天翼网盘中的目录路径；保留 \'/\' 表示从网盘根目录开始。';

  @override
  String get cloud189ConnectionFailedMessage =>
      '天翼网盘连接失败。请检查凭据；开启调试模式后可查看请求日志。';

  @override
  String get cloud189DebugLogDialogTitle => '天翼网盘调试日志';

  @override
  String get cloud189DebugLogDialogDescription => '已脱敏显示本次添加音源时的请求地址、参数和响应摘要。';

  @override
  String get cloud189CaptchaDialogTitle => '输入天翼网盘验证码';

  @override
  String get cloud189CaptchaDialogDescription => '自动识别服务暂时不可用，请输入图片中的验证码后继续登录。';

  @override
  String get cloud189CaptchaCodeLabel => '验证码';

  @override
  String get cloud189CaptchaCodeHint => '输入图片中的字符';

  @override
  String get scraperPipelineLabel => '刮削管线';

  @override
  String get lyricsScrapingServiceUrlLabel => '歌词刮削服务地址';

  @override
  String get lyricsScrapingServiceUrlDescription =>
      '输入歌词服务的 Base URL（例如：https://lrclib.net/api）。留空将禁用歌词刮削。';

  @override
  String get lyricsScrapingServiceUrlNotConfigured => '未配置';

  @override
  String get lyricsScrapingServiceUrlConfigured => '已配置';

  @override
  String get lyricsScrapingServiceUrlDialogTitle => '歌词服务';

  @override
  String get lyricsScrapingServiceUrlHint => 'https://lrclib.net/api';

  @override
  String get lyricsScrapingServiceUrlRequiredMessage => '请先在设置中配置歌词刮削服务地址';

  @override
  String get lyricsScrapingDisabledMessage => '请先在设置中开启歌词刮削';

  @override
  String get enableLyricsScrapingLabel => '启用歌词刮削';

  @override
  String get enableLyricsScrapingDescription =>
      '开启后，App 将连接你配置的歌词服务地址以补全歌词。该操作将产生网络流量。';

  @override
  String get enableDeezerCoverScrapingLabel => '启用 Deezer 封面补全';

  @override
  String get enableDeezerCoverScrapingDescription =>
      '开启后，App 将连接 Deezer 获取歌曲封面。该操作将产生网络流量。';

  @override
  String get enableItunesMetadataScrapingLabel => '使用 iTunes 刮削元数据';

  @override
  String get enableItunesMetadataScrapingDescription =>
      '开启后，App 将连接第三方元数据服务（如 iTunes）以补全封面和歌曲名。该操作将产生网络流量，详情请查阅第三方服务条款。';

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
      '添加一个音乐音源后，就可以在同一套界面中浏览远程目录、展示音乐文件并直接播放。';

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
  String get homeGreetingMorning => '早上好';

  @override
  String get homeGreetingAfternoon => '下午好';

  @override
  String get homeGreetingEvening => '晚上好';

  @override
  String homeWelcomeDescriptionReady(int sourceCount) {
    return '当前已连接 $sourceCount 个音乐音源，你的云端音乐库已经准备就绪。';
  }

  @override
  String get homeWelcomeDescriptionPending => '音源已经连接完成，执行一次扫描后就能生成专辑和歌曲集合。';

  @override
  String get homeSourcesSectionTitle => '云端音源';

  @override
  String get homeRecentAlbumsSectionTitle => '最近加入';

  @override
  String get homeRecentAlbumsEmptyDescription => '扫描音源之后，新发现的专辑会出现在这里。';

  @override
  String collectionDescription(Object sourceName) {
    return '浏览 $sourceName，扫描全部歌曲，并在全部歌曲、我喜欢和我收藏之间快速切换。';
  }

  @override
  String collectionDescriptionAllSources(
    Object browserSourceName,
    int sourceCount,
  ) {
    return '当前音源为 $browserSourceName，并把全部 $sourceCount 个已保存音源扫描到同一个资料库中展示。';
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
  String get favoritesCollectionDescription => '你收藏的歌曲会显示在这里。';

  @override
  String get likedCollectionDescription => '你标记为喜欢的歌曲会显示在这里。';

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
  String get browserTitle => '文件浏览';

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
  String get resetToDefaultAction => '恢复默认值';

  @override
  String get playerEmptyTitle => '还没有选择歌曲';

  @override
  String get playerEmptyDescription => '请先从音源浏览器中选择一个音乐文件开始播放。';

  @override
  String get lyricsEmptyLabel => '当前还没有找到这首歌对应的同步歌词。';

  @override
  String get showLyricsAction => '显示歌词';

  @override
  String get hideLyricsAction => '收起歌词';

  @override
  String get playAction => '播放';

  @override
  String get pauseAction => '暂停';

  @override
  String get stopAction => '停止';

  @override
  String get closeAction => '关闭';

  @override
  String get previousTrackAction => '上一首';

  @override
  String get nextTrackAction => '下一首';

  @override
  String get playNextAction => '下一首播放';

  @override
  String get playlistTitle => '播放列表';

  @override
  String get playlistEmptyTitle => '播放列表为空。';

  @override
  String get removeFromPlaylistAction => '从播放列表移除';

  @override
  String get currentTrackLabel => '正在播放';

  @override
  String get playbackModeList => '列表播放';

  @override
  String get playbackModeRepeatOne => '单曲循环';

  @override
  String get playbackModeShuffle => '随机播放';

  @override
  String playlistCountLabel(int count) {
    return '播放列表 $count 首';
  }

  @override
  String addedToPlayNextMessage(Object title) {
    return '已添加到下一首播放：$title';
  }

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
  String get sftpServerUrlHint => 'sftp://server.example.com:22/home/user';

  @override
  String get ftpServerUrlHint => 'ftp://server.example.com/Music';

  @override
  String get sambaServerUrlHint => 'smb://server.example.com/share';

  @override
  String get usernameLabel => '用户名';

  @override
  String get passwordLabel => '密码或应用令牌';

  @override
  String get sambaPasswordLabel => '密码';

  @override
  String get rootPathLabel => '根路径';

  @override
  String get rootPathHint => '/Music/';

  @override
  String get sambaRootPathHint => '/Music/';

  @override
  String get rootPathHelpText => '如果服务器地址已经直接指向目标目录，这里保持为 “/” 即可。';

  @override
  String get sftpRootPathHelpText => '该路径相对于 SFTP 地址中的路径生效；填写 “/” 表示从该基准目录开始。';

  @override
  String get ftpRootPathHelpText => '该路径相对于 FTP 地址中的路径生效；填写 “/” 表示从该基准目录开始。';

  @override
  String get sambaRootPathHelpText =>
      '该路径相对于服务器地址中的 SMB 共享目录生效；填写 “/” 表示从共享根目录开始。';

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
  String get connectionFailedMessage => '连接失败，请检查服务器地址、根路径和凭证。';

  @override
  String get playbackFailedMessage => '当前文件无法启动播放。';

  @override
  String get folderAlbumsModeLabel => '按文件夹';

  @override
  String get scrapedAlbumsModeLabel => '按专辑字段';

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

  @override
  String get debugModeEnabledMessage => '🔍 调试模式已启用 - 查看控制台查看详细日志';

  @override
  String get manualScrapingTitle => '手动刮削';

  @override
  String get manualScrapingActionLabel => '手动刮削';

  @override
  String get scrapingSongName => '歌名';

  @override
  String get scrapingArtistName => '艺术家';

  @override
  String get scrapingSearchButton => '搜索';

  @override
  String get scrapingSearchingLabel => '搜索中...';

  @override
  String get scrapingSearchResultsTitle => '搜索结果';

  @override
  String get scrapingNoResultsMessage => '未找到结果';

  @override
  String scrapingMatchScoreLabel(int score) {
    return '匹配度：$score%';
  }

  @override
  String get scrapingSelectButtonLabel => '选择';

  @override
  String get scrapingCoverLabel => '封面';

  @override
  String get scrapingLyricsLabel => '歌词';

  @override
  String get scrapingUpdateCoverAction => '更新封面';

  @override
  String get scrapingUpdateLyricsAction => '获取歌词';

  @override
  String get scrapingResultApplied => '元数据已应用';

  @override
  String get scrapingErrorMessage => '刮削失败';

  @override
  String get scrapingRetryAction => '重试';

  @override
  String get automaticScrapingLabel => '自动';

  @override
  String get manualScrapingLabel => '手动';

  @override
  String get autoScrapedLabel => '已自动刮削';

  @override
  String get manuallyScrapedLabel => '已手动刮削';

  @override
  String get debugLogsTitle => '调试日志';

  @override
  String get debugLogsTabLabel => '调试日志';

  @override
  String get clearAction => '清空';

  @override
  String get autoScrollLabel => '自动';

  @override
  String get noLogsAvailable => '暂无日志';

  @override
  String get logsExportedToClipboard => '日志已复制到剪贴板';

  @override
  String get exportAction => '导出';

  @override
  String get copyLogsAction => '复制日志';
}
