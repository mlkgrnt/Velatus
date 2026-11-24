// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appName => '隐格';

  @override
  String get tagline => '该藏起来的，就藏好。';

  @override
  String get taglineSub => '给截图和照片打码，全程只在这台设备上完成。';

  @override
  String get cancel => '取消';

  @override
  String get delete => '删除';

  @override
  String get done => '完成';

  @override
  String get close => '关闭';

  @override
  String get save => '保存';

  @override
  String get share => '分享';

  @override
  String get settings => '设置';

  @override
  String get about => '关于';

  @override
  String get retry => '重试';

  @override
  String get openImage => '打开图片';

  @override
  String get pickFromGallery => '从相册选择';

  @override
  String get pickFromFiles => '选择文件';

  @override
  String get dropHint => '把图片拖到这里';

  @override
  String get dropSubtitle => '或点击浏览 · 支持 JPG、PNG、WebP、BMP';

  @override
  String get featureLocalTitle => '全程不出本机';

  @override
  String get featureLocalBody => '图片不会上传，也不做任何统计。唯一会联网的地方是检查更新，而且可以关掉。';

  @override
  String get featureLayersTitle => '打码可以反悔';

  @override
  String get featureLayersBody => '点一下就能选中某处遮挡，随时改大小或删掉，画上去的都能反悔。';

  @override
  String get featureOcrTitle => '自动找出该遮的地方';

  @override
  String get featureOcrBody => '文字、聊天头像、二维码都会先框出来，你自己挑要盖哪些，全部在本机完成。';

  @override
  String get recent => '最近打开';

  @override
  String get clearRecent => '清空';

  @override
  String get untitled => '未命名';

  @override
  String get editorTitle => '编辑';

  @override
  String get undo => '撤销';

  @override
  String get redo => '重做';

  @override
  String get compare => '按住对比';

  @override
  String get export => '导出';

  @override
  String get fitToScreen => '适应窗口';

  @override
  String get toolBrush => '涂抹';

  @override
  String get toolBox => '框';

  @override
  String get toolSelect => '选择';

  @override
  String get maskMosaic => '马赛克';

  @override
  String get maskBlur => '模糊';

  @override
  String get maskSolid => '色块';

  @override
  String get strength => '强度';

  @override
  String get size => '大小';

  @override
  String get color => '颜色';

  @override
  String get brushHint => '在需要遮住的区域上涂抹';

  @override
  String get boxHint => '拖动框出区域 · 圆角条可以把四角磨圆';

  @override
  String get selectHint => '点一下某处打码，就能调整或删掉';

  @override
  String get deleteMask => '删除这处打码';

  @override
  String maskCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 处打码',
      zero: '暂无打码',
    );
    return '$_temp0';
  }

  @override
  String get scanAction => '扫描';

  @override
  String scanFoundText(int count) {
    return '$count 处文字';
  }

  @override
  String scanFoundAvatar(int count) {
    return '$count 个头像';
  }

  @override
  String scanFoundQr(int count) {
    return '$count 个二维码';
  }

  @override
  String get scanNone => '没找到需要遮挡的东西';

  @override
  String get scanFailed => '扫描失败';

  @override
  String get pendingHint => '点选要盖住的框';

  @override
  String pendingCount(int selected, int total) {
    return '$selected/$total';
  }

  @override
  String get pendingAll => '全选';

  @override
  String get pendingClear => '全不选';

  @override
  String get compareHint => '按住查看原图';

  @override
  String get resetView => '复位视图';

  @override
  String get exportTitle => '导出';

  @override
  String get format => '格式';

  @override
  String get quality => '质量';

  @override
  String get metadata => '元数据';

  @override
  String get metadataNote => 'EXIF（位置、设备、时间）会被彻底移除。';

  @override
  String get resolution => '分辨率';

  @override
  String get originalSize => '原始尺寸';

  @override
  String get exportSave => '保存到本机';

  @override
  String get exportGallery => '保存到相册';

  @override
  String get exported => '图片已保存';

  @override
  String exportedTo(String path) {
    return '已保存到 $path';
  }

  @override
  String get exportFailed => '保存失败';

  @override
  String get exporting => '正在渲染…';

  @override
  String get appearance => '外观';

  @override
  String get themeSystem => '系统';

  @override
  String get themeLight => '浅色';

  @override
  String get themeDark => '深色';

  @override
  String get language => '语言';

  @override
  String get languageSystem => '跟随系统';

  @override
  String get privacy => '隐私';

  @override
  String get privacyBody => '隐格只在这台设备上处理图片，图片不会上传，也不做任何统计。会联网的只有一件事：检查和下载更新。';

  @override
  String get openSource => '开源';

  @override
  String get licenses => '开源许可';

  @override
  String get aboutBody => '一个安静的小工具，专门盖住不该被看见的东西。';

  @override
  String get openFailed => '打不开这张图片';

  @override
  String get unsupportedFormat => '不支持的格式';

  @override
  String get storageDenied => '存储权限被拒绝了';

  @override
  String imageInfo(int width, int height) {
    return '$width × $height';
  }

  @override
  String get apply => '确认';

  @override
  String get clearAll => '全部清除';

  @override
  String get clearAllConfirm => '要移除这张图上的所有打码吗？';

  @override
  String get maskStyle => '样式';

  @override
  String get brushSize => '笔刷大小';

  @override
  String get blurNote => '模糊强度会随图片尺寸缩放，导出与预览一致。';

  @override
  String get exifStripped => '已清除 EXIF';

  @override
  String get footerNote => 'MIT · 离线可用';

  @override
  String get leaveTitle => '还没导出，要离开吗？';

  @override
  String get leaveBody => '这次的打码还没保存，离开就没了。想留着的话，先导出图片吧。';

  @override
  String get leave => '离开';

  @override
  String get cornerRadius => '圆角';

  @override
  String get customColor => '颜色';

  @override
  String get selectionHint => '拖动移动 · 四角缩放';

  @override
  String selectionHintMulti(int count) {
    return '已选 $count 处 · 拖动和缩放都只作用在你碰到的那个';
  }

  @override
  String get moreActions => '更多';

  @override
  String get checkUpdate => '检查更新';

  @override
  String get checkUpdateNote => '在应用内下载并安装';

  @override
  String get updateChecking => '正在检查更新…';

  @override
  String updateLatest(String version) {
    return '已是最新版本（$version）。';
  }

  @override
  String updateAvailable(String version) {
    return '发现新版本 $version';
  }

  @override
  String get updateDownload => '下载并安装';

  @override
  String get updateLater => '稍后';

  @override
  String updateDownloading(int percent) {
    return '正在下载… $percent%';
  }

  @override
  String get updateInstallHint =>
      'Android 会先问你是否允许「隐格」安装应用，然后弹出系统安装界面。正在编辑的内容不受影响。';

  @override
  String updateDownloaded(String path) {
    return '已下载到 $path';
  }

  @override
  String get updateShowFile => '打开所在文件夹';

  @override
  String get updateFailedCheck => '所有更新源都连不上';

  @override
  String get updateFailedDownload => '下载失败';

  @override
  String get updateOpenReleases => '打开发布页';

  @override
  String updateSource(String host) {
    return '来源 $host';
  }

  @override
  String get repository => '仓库地址';

  @override
  String get featureExportTitle => '按原图导出';

  @override
  String get featureExportBody => '马赛克与模糊按原始像素重绘，不是把小图放大。';
}

/// The translations for Chinese, using the Han script (`zh_Hant`).
class AppLocalizationsZhHant extends AppLocalizationsZh {
  AppLocalizationsZhHant() : super('zh_Hant');

  @override
  String get appName => '隱格';

  @override
  String get tagline => '該藏起來的，就藏好。';

  @override
  String get taglineSub => '替截圖和照片打碼，全程只在這一台裝置上完成。';

  @override
  String get cancel => '取消';

  @override
  String get delete => '刪除';

  @override
  String get done => '完成';

  @override
  String get close => '關閉';

  @override
  String get save => '儲存';

  @override
  String get share => '分享';

  @override
  String get settings => '設定';

  @override
  String get about => '關於';

  @override
  String get retry => '重試';

  @override
  String get openImage => '開啟圖片';

  @override
  String get pickFromGallery => '從相簿選擇';

  @override
  String get pickFromFiles => '選擇檔案';

  @override
  String get dropHint => '把圖片拖到這裡';

  @override
  String get dropSubtitle => '或點一下瀏覽 · 支援 JPG、PNG、WebP、BMP';

  @override
  String get featureLocalTitle => '全程不出本機';

  @override
  String get featureLocalBody => '圖片不會上傳，也不做任何統計。唯一會連網的地方是檢查更新，而且可以關掉。';

  @override
  String get featureLayersTitle => '打碼可以反悔';

  @override
  String get featureLayersBody => '點一下就能選中某處遮擋，隨時改大小或刪掉，畫上去的都能反悔。';

  @override
  String get featureOcrTitle => '自動找出該遮的地方';

  @override
  String get featureOcrBody => '文字、聊天大頭貼、QR 碼都會先框出來，你自己挑要蓋哪些，全部在本機完成。';

  @override
  String get recent => '最近開啟';

  @override
  String get clearRecent => '清空';

  @override
  String get untitled => '未命名';

  @override
  String get editorTitle => '編輯';

  @override
  String get undo => '復原';

  @override
  String get redo => '重做';

  @override
  String get compare => '按住對比';

  @override
  String get export => '匯出';

  @override
  String get fitToScreen => '符合視窗';

  @override
  String get toolBrush => '塗抹';

  @override
  String get toolBox => '框';

  @override
  String get toolSelect => '選取';

  @override
  String get maskMosaic => '馬賽克';

  @override
  String get maskBlur => '模糊';

  @override
  String get maskSolid => '色塊';

  @override
  String get strength => '強度';

  @override
  String get size => '大小';

  @override
  String get color => '顏色';

  @override
  String get brushHint => '在需要遮住的區域上塗抹';

  @override
  String get boxHint => '拖曳框出區域 · 圓角條可以把四角磨圓';

  @override
  String get selectHint => '點一下某處打碼，就能調整或刪掉';

  @override
  String get deleteMask => '刪除這處打碼';

  @override
  String maskCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 處打碼',
      zero: '尚無打碼',
    );
    return '$_temp0';
  }

  @override
  String get scanAction => '掃描';

  @override
  String scanFoundText(int count) {
    return '$count 處文字';
  }

  @override
  String scanFoundAvatar(int count) {
    return '$count 個大頭貼';
  }

  @override
  String scanFoundQr(int count) {
    return '$count 個 QR 碼';
  }

  @override
  String get scanNone => '沒找到需要遮擋的東西';

  @override
  String get scanFailed => '掃描失敗';

  @override
  String get pendingHint => '點選要蓋住的框';

  @override
  String pendingCount(int selected, int total) {
    return '$selected/$total';
  }

  @override
  String get pendingAll => '全選';

  @override
  String get pendingClear => '全不選';

  @override
  String get compareHint => '按住查看原圖';

  @override
  String get resetView => '重設檢視';

  @override
  String get exportTitle => '匯出';

  @override
  String get format => '格式';

  @override
  String get quality => '品質';

  @override
  String get metadata => '中繼資料';

  @override
  String get metadataNote => 'EXIF（位置、裝置、時間）會被徹底移除。';

  @override
  String get resolution => '解析度';

  @override
  String get originalSize => '原始尺寸';

  @override
  String get exportSave => '存到本機';

  @override
  String get exportGallery => '存到相簿';

  @override
  String get exported => '圖片已儲存';

  @override
  String exportedTo(String path) {
    return '已儲存到 $path';
  }

  @override
  String get exportFailed => '儲存失敗';

  @override
  String get exporting => '正在算圖…';

  @override
  String get appearance => '外觀';

  @override
  String get themeSystem => '系統';

  @override
  String get themeLight => '淺色';

  @override
  String get themeDark => '深色';

  @override
  String get language => '語言';

  @override
  String get languageSystem => '跟隨系統';

  @override
  String get privacy => '隱私';

  @override
  String get privacyBody => '隱格只在這一台裝置上處理圖片，圖片不會上傳，也不做任何統計。會連網的只有一件事：檢查和下載更新。';

  @override
  String get openSource => '開源';

  @override
  String get licenses => '開源授權';

  @override
  String get aboutBody => '一個安靜的小工具，專門蓋住不該被看見的東西。';

  @override
  String get openFailed => '打不開這張圖片';

  @override
  String get unsupportedFormat => '不支援的格式';

  @override
  String get storageDenied => '儲存權限被拒絕了';

  @override
  String imageInfo(int width, int height) {
    return '$width × $height';
  }

  @override
  String get apply => '確認';

  @override
  String get clearAll => '全部清除';

  @override
  String get clearAllConfirm => '要移除這張圖上的所有打碼嗎？';

  @override
  String get maskStyle => '樣式';

  @override
  String get brushSize => '筆刷大小';

  @override
  String get blurNote => '模糊強度會隨圖片尺寸縮放，匯出與預覽一致。';

  @override
  String get exifStripped => '已清除 EXIF';

  @override
  String get footerNote => 'MIT · 離線可用';

  @override
  String get leaveTitle => '還沒匯出，要離開嗎？';

  @override
  String get leaveBody => '這次的打碼還沒儲存，離開就沒了。想留著的話，先匯出圖片吧。';

  @override
  String get leave => '離開';

  @override
  String get cornerRadius => '圓角';

  @override
  String get customColor => '顏色';

  @override
  String get selectionHint => '拖曳移動 · 四角縮放';

  @override
  String selectionHintMulti(int count) {
    return '已選 $count 處 · 拖曳和縮放都只作用在你碰到的那個';
  }

  @override
  String get moreActions => '更多';

  @override
  String get checkUpdate => '檢查更新';

  @override
  String get checkUpdateNote => '在應用程式內下載並安裝';

  @override
  String get updateChecking => '正在檢查更新…';

  @override
  String updateLatest(String version) {
    return '已是最新版本（$version）。';
  }

  @override
  String updateAvailable(String version) {
    return '發現新版本 $version';
  }

  @override
  String get updateDownload => '下載並安裝';

  @override
  String get updateLater => '稍後';

  @override
  String updateDownloading(int percent) {
    return '正在下載… $percent%';
  }

  @override
  String get updateInstallHint =>
      'Android 會先問你是否允許「隱格」安裝應用程式，然後跳出系統安裝畫面。正在編輯的內容不受影響。';

  @override
  String updateDownloaded(String path) {
    return '已下載到 $path';
  }

  @override
  String get updateShowFile => '開啟所在資料夾';

  @override
  String get updateFailedCheck => '所有更新來源都連不上';

  @override
  String get updateFailedDownload => '下載失敗';

  @override
  String get updateOpenReleases => '開啟發佈頁';

  @override
  String updateSource(String host) {
    return '來源 $host';
  }

  @override
  String get repository => '原始碼';

  @override
  String get featureExportTitle => '按原圖匯出';

  @override
  String get featureExportBody => '馬賽克與模糊按原始像素重繪，不是把小圖放大。';
}
