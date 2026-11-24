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
  String get appNameZh => 'Velatus';

  @override
  String get tagline => '该藏起来的，就藏好。';

  @override
  String get taglineSub => '本地优先的截图与照片打码工具。';

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
  String get featureLocalBody => '不上传、不登录、不统计。唯一的联网用途是检查更新，而且可以关掉。';

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
  String get boxHint => '拖动框选区域 · 圆角条可软化四角';

  @override
  String get selectHint => '点选一处打码来调整或删除';

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
  String get scanNone => '没有找到需要遮挡的内容';

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
  String get themeSystem => '跟随系统';

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
  String get privacyBody => '隐格完全在本机处理图片，没有账号、没有统计，图片永远不上传。联网权限只用在一处：检查和下载更新。';

  @override
  String get openSource => '开源';

  @override
  String get licenses => '开源许可';

  @override
  String get aboutBody => '一个安静的小工具，专门盖住不该被看见的东西。';

  @override
  String get openFailed => '无法打开这张图片';

  @override
  String get unsupportedFormat => '不支持的格式';

  @override
  String get storageDenied => '存储权限被拒绝';

  @override
  String imageInfo(int width, int height) {
    return '$width × $height';
  }

  @override
  String get languageEnglish => 'English';

  @override
  String get languageChinese => '简体中文';

  @override
  String get apply => '落地';

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
  String get footerNote => 'MIT · 无联网 · 无账号';

  @override
  String get leaveTitle => '还没导出，确定离开？';

  @override
  String get leaveBody => '这次的打码不会保存。想留下结果的话，请先导出图片。';

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
    return '已选 $count 处 · 四角只缩放你碰到的那个';
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
      'Android 会先让你允许「隐格」安装应用，然后弹出系统安装界面。正在编辑的内容不受影响。';

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
