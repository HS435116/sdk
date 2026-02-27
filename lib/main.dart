import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:cached_network_image/cached_network_image.dart';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/material.dart';

import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:html/dom.dart' as dom;

import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_vlc_player/flutter_vlc_player.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:google_fonts/google_fonts.dart';





const String kBaseHost = 'https://www.jkan.app';
const String kDefaultListUrl = 'https://www.jkan.app/show/1--------1---.html';

class _TrustAllHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.badCertificateCallback = (cert, host, port) => true;
    return client;
  }
}


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = _TrustAllHttpOverrides();

  await DeviceProfileManager.instance.init();

  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);


  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.black,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '晨曦影视',

      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF1E1E1E),
        useMaterial3: true,
        textTheme: GoogleFonts.manropeTextTheme(ThemeData.dark().textTheme),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ScrollController _scrollController = ScrollController();
  late final bool _isDesktop;
  double? _debugWidth;

  final List<TopTab> _topTabs = const [
    TopTab('电影', 'https://www.jkan.app/show/1-----------.html', '/show/1'),
    TopTab('电视剧', 'https://www.jkan.app/show/2-----------.html', '/show/2'),
    TopTab('动漫', 'https://www.jkan.app/show/4-----------.html', '/show/4'),
    TopTab('综艺', 'https://www.jkan.app/show/3-----------.html', '/show/3'),
  ];

  bool _loading = true;
  String _currentUrl = kDefaultListUrl;
  String? _error;
  PageData? _pageData;

  @override
  void initState() {
    super.initState();
    _isDesktop = _detectDesktop();
    _debugWidth = _isDesktop ? 420 : null;
    _loadPage(_currentUrl);
    if (_isDesktop) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openDebugDialog();
      });
    }
  }


  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadPage(String url) async {
    setState(() {
      _loading = true;
      _error = null;
      _currentUrl = url;
    });
    try {
      final data = await fetchPage(url);
      if (!mounted) return;
      setState(() {
        _pageData = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _safeErrorMessage(e, isPlay: false);
        _loading = false;
      });

    }
  }

  bool _detectDesktop() {
    if (kIsWeb) return true;
    return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
  }

  void _openDebugDialog() {
    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('桌面调试模式'),
          content: const Text('当前为桌面运行，将启用模拟移动端宽度。你可以在右侧按钮中随时调整。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('知道了'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = _loading

        ? const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CircularProgressIndicator()),
          )
        : (_error != null)
            ? SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ),
              )
            : _buildContent();

    final page = Stack(
      children: [
        SafeArea(
          child: RefreshIndicator(
            onRefresh: () => _loadPage(_currentUrl),
            child: CustomScrollView(
              controller: _scrollController,
              slivers: [
                SliverToBoxAdapter(child: _buildHeader()),
                SliverToBoxAdapter(child: _buildFilters()),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: content,
                ),
                const SliverToBoxAdapter(child: _Footer()),
              ],
            ),
          ),
        ),
        Positioned(
          right: 18,
          bottom: 24,
          child: _buildFloatingActions(),
        ),
      ],
    );

    return Scaffold(
      body: _isDesktop
          ? Center(
              child: SizedBox(
                width: _debugWidth ?? 420,
                child: page,
              ),
            )
          : page,
    );

  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Row(
        children: [
          const Text(
            '晨曦影视',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),

          const SizedBox(width: 12),
          Expanded(
            child: Wrap(
              spacing: 10,
              runSpacing: 6,
              children: _topTabs.map((tab) {
                final selected = _currentUrl.contains(tab.token);
                return GestureDetector(
                  onTap: () => _loadPage(tab.url),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected ? const Color(0xFF3A3A3A) : const Color(0xFF2B2B2B),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected ? const Color(0xFFF06292) : Colors.transparent,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      tab.title,
                      style: TextStyle(
                        color: selected ? const Color(0xFFF06292) : Colors.white70,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () => _loadPage(_currentUrl),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    if (_pageData == null) return const SizedBox.shrink();
    return Column(
      children: _pageData!.filters.map((group) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                margin: const EdgeInsets.only(top: 6),
                child: Text(
                  group.label,
                  style: const TextStyle(color: Colors.white60),
                ),
              ),
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemBuilder: (context, index) {
                      final item = group.items[index];
                      return GestureDetector(
                        onTap: item.url.isEmpty ? null : () => _loadPage(item.url),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: item.selected ? const Color(0xFF3A3A3A) : const Color(0xFF2A2A2A),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: item.selected ? const Color(0xFFF06292) : Colors.transparent,
                            ),
                          ),
                          child: Text(
                            item.title,
                            style: TextStyle(
                              color: item.selected ? const Color(0xFFF06292) : Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      );
                    },
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemCount: group.items.length,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  SliverGrid _buildContent() {
    final items = _pageData?.items ?? [];
    return SliverGrid(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final item = items[index];
          return _VideoCard(
            item: item,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PlayerPage(item: item),
                ),
              );
            },
          );
        },
        childCount: items.length,
      ),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.66,
      ),
    );
  }

  Widget _buildFloatingActions() {
    return Column(
      children: [
        if (_isDesktop) ...[
          _CircleAction(
            icon: Icons.bug_report_rounded,
            onTap: _openDebugPanel,
          ),
          const SizedBox(height: 12),
        ],
        _CircleAction(
          icon: Icons.filter_list_rounded,
          onTap: () {
            if (_pageData?.filters.isNotEmpty ?? false) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('滑动筛选区选择分类条件')),
              );
            }
          },
        ),
        const SizedBox(height: 12),
        _CircleAction(
          icon: Icons.keyboard_arrow_up_rounded,
          onTap: () {
            _scrollController.animateTo(
              0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          },
        ),
      ],
    );
  }

  void _openDebugPanel() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF242424),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('模拟调试窗口', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                children: [
                  _debugSizeChip('420px', 420),
                  _debugSizeChip('480px', 480),
                  _debugSizeChip('600px', 600),
                  _debugSizeChip('全宽', null),
                ],
              ),
              const SizedBox(height: 12),
              Text('当前宽度：${_debugWidth == null ? '全宽' : '${_debugWidth!.toInt()}px'}',
                  style: const TextStyle(color: Colors.white60)),
            ],
          ),
        );
      },
    );
  }

  Widget _debugSizeChip(String label, double? width) {
    final selected = _debugWidth == width || (width == null && _debugWidth == null);
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) {
        setState(() {
          _debugWidth = width;
        });
        Navigator.of(context).pop();
      },
    );
  }
}


class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 26),
      child: Center(
        child: Text(
          ' 2026  ©  晨曦微光 ',
          style: TextStyle(color: Colors.white38, fontSize: 12),
        ),
      ),
    );
  }
}

class _VideoCard extends StatefulWidget {

  const _VideoCard({required this.item, required this.onTap});

  final VideoItem item;
  final VoidCallback onTap;

  @override
  State<_VideoCard> createState() => _VideoCardState();
}

class _VideoCardState extends State<_VideoCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1,
        duration: const Duration(milliseconds: 120),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          decoration: BoxDecoration(
            color: const Color(0xFF262626),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF2F2F2F)),
            boxShadow: const [
              BoxShadow(color: Colors.black45, blurRadius: 10, offset: Offset(0, 6)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: item.coverUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(color: const Color(0xFF333333)),
                        errorWidget: (context, url, error) => Container(color: const Color(0xFF333333)),
                      ),
                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black54],
                          ),
                        ),
                      ),
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            item.badge,
                            style: const TextStyle(fontSize: 10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 2),
                child: Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                child: Text(
                  item.subTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white60, fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PlayerPage extends StatefulWidget {
  const PlayerPage({super.key, required this.item});

  final VideoItem item;

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  VlcPlayerController? _vlcController;
  bool _useVlcPlayer = false;
  bool _isHarmonyDevice = false;
  DecoderPreference _decoderPreference = DecoderPreference.native;
  bool _preferVlcSoftware = false;
  bool _harmonyTriedHardware = false;
  bool _harmonyTriedSoftware = false;
  bool _loading = true;
  bool _waitingForFirstFrame = false;
  bool _vlcBroken = false;








  String? _error;
  File? _cachedFile;
  Directory? _cacheDir;
  HlsProxyServer? _proxyServer;
  List<PlaySource> _sources = [];
  final Map<String, List<EpisodeItem>> _sourceEpisodes = {};
  List<EpisodeItem> _episodes = [];
  EpisodeItem? _currentEpisode;
  PlaySource? _currentSource;
  String? _currentPlayPageUrl;

  late final bool _isDesktop;

  CancelToken? _downloadCancelToken;
  Timer? _playbackWatchdog;
  int _playRequestId = 0;
  int _autoSwitchCount = 0;


  @override
  void initState() {

    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _isDesktop = _detectDesktop();
    WakelockPlus.enable();
    _initDeviceProfile().whenComplete(_initPlayer);
  }






  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _playbackWatchdog?.cancel();
    _controller?.dispose();
    _vlcController?.dispose();
    WakelockPlus.disable();
    _deleteCache();
    super.dispose();
  }






  bool _detectDesktop() {
    if (kIsWeb) return true;
    return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
  }

  Future<void> _initDeviceProfile() async {
    final profile = DeviceProfileManager.instance.profile;
    if (profile == null || !profile.isAndroid) return;
    _isHarmonyDevice = profile.isHarmony;
    _decoderPreference = profile.decoderPreference;
    _preferVlcSoftware = profile.decoderPreference == DecoderPreference.vlcSoftware;
    if (_isHarmonyDevice) {
      _vlcBroken = false;
      _useVlcPlayer = false;
      _decoderPreference = DecoderPreference.native;
      return;
    }
    if (_decoderPreference != DecoderPreference.native) {
      _useVlcPlayer = true;
    }
  }



  Future<void> _deleteCache() async {


    try {
      await _proxyServer?.close();
      if (_cachedFile != null && await _cachedFile!.exists()) {
        await _cachedFile!.delete();
      }
      if (_cacheDir != null && await _cacheDir!.exists()) {
        await _cacheDir!.delete(recursive: true);
      }
    } catch (_) {}
  }



  Future<void> _initPlayer() async {

    try {
      setState(() {
        _loading = true;
        _error = null;
      });
      final meta = await fetchPlayMeta(widget.item.detailUrl);
      _sources = meta.sources;
      _sourceEpisodes
        ..clear()
        ..addAll(meta.sourceEpisodes);
      _episodes = meta.episodes;
      if (_sources.isEmpty && _episodes.isEmpty) {
        throw Exception('未解析到播放地址');
      }
      if (_episodes.isNotEmpty) {
        _currentEpisode = _episodes.first;
        await _playEpisode(_currentEpisode!);
        return;
      }
      final preferred = _sources.firstWhere(
        (s) => s.mediaUrl != null,
        orElse: () => _sources.first,
      );
      await _playSource(preferred);

    } catch (e) {
      _stopPlaybackWatchdog();
      final switched = await _tryAutoSwitchSourceOnDecode(e);
      if (switched) return;
      if (!mounted) return;
      final message = e is UnimplementedError
          ? '当前平台暂不支持视频播放，请在安卓设备运行'
          : _safeErrorMessage(e, isPlay: true);
      setState(() {
        _waitingForFirstFrame = false;
        _error = message;
        _loading = false;
      });


    }











  }


  Future<void> _playSource(PlaySource source) async {
    String? playUrl;
    try {
      await _resetPlayer();
      playUrl = source.mediaUrl;

      final playPageUrl = source.playPageUrl;
      _currentPlayPageUrl = playPageUrl ?? widget.item.detailUrl;
      if (playUrl == null && playPageUrl != null && _isValidPlayPageUrl(playPageUrl)) {


        final playResp = await http.get(
          Uri.parse(toAbsUrl(playPageUrl)),
          headers: _defaultHeaders(playPageUrl),
        );
        if (playResp.statusCode == 200) {
          playUrl = _parsePlayUrlFromHtml(playResp.body);
        }
      }

      if (playUrl != null && !playUrl.startsWith('http')) {
        playUrl = toAbsUrl(playUrl);
      }

      if (playUrl == null) {
        throw Exception('未解析到播放地址');
      }
      final updated = source.mediaUrl == playUrl ? source : source.copyWith(mediaUrl: playUrl);
      final idx = _sources.indexOf(source);
      if (idx >= 0) {
        _sources[idx] = updated;
      }
      _currentSource = updated;

      final preferVlc = !_vlcBroken && (_useVlcPlayer || _decoderPreference != DecoderPreference.native);

      if (preferVlc) {
        _waitingForFirstFrame = true;
        _startPlaybackWatchdog(playUrl, usingVlc: true, preferSoftware: _preferVlcSoftware);
        await _playWithVlc(playUrl, preferSoftware: _preferVlcSoftware);
        if (!mounted) return;
        setState(() {
          _autoSwitchCount = 0;
          _loading = false;
          _error = null;
        });
        return;
      }




      _startPlaybackWatchdog(playUrl, usingVlc: false, preferSoftware: false);
      final isHls = playUrl.toLowerCase().contains('.m3u8');

      final controller = isHls
          ? await _prepareHlsController(playUrl)
          : await _prepareProgressiveController(playUrl);

      await controller.initialize();
      await controller.play();
      _stopPlaybackWatchdog();
      if (!mounted) return;
      setState(() {
        _controller = controller;
        _autoSwitchCount = 0;
        _waitingForFirstFrame = false;
        _loading = false;
        _error = null;
      });





    } catch (e) {
      _stopPlaybackWatchdog();
      final switched = await _tryAutoSwitchSourceOnDecode(e);
      if (switched) return;
      if (!mounted) return;
      final message = e is UnimplementedError
          ? '当前平台暂不支持视频播放，请在安卓设备运行'
          : _safeErrorMessage(e, isPlay: true);
      setState(() {
        _waitingForFirstFrame = false;
        _error = message;
        _loading = false;
      });


    }











  }

  Future<void> _playEpisode(EpisodeItem episode) async {
    _currentEpisode = episode;
    final isMedia = _looksLikeMediaUrl(episode.playUrl);
    _currentPlayPageUrl = isMedia ? widget.item.detailUrl : episode.playUrl;

    await _playSource(

      PlaySource(
        name: _currentSource?.name ?? episode.name,
        playPageUrl: isMedia ? null : episode.playUrl,
        mediaUrl: isMedia ? episode.playUrl : null,
      ),
    );
  }


  Future<VideoPlayerController> _prepareHlsController(String playUrl) async {
    final headers = _defaultHeaders(_currentPlayPageUrl ?? playUrl);
    _proxyServer = await HlsProxyServer.start(playUrl, headers: headers);
    _cacheDir = _proxyServer!.cacheDir;
    return VideoPlayerController.networkUrl(Uri.parse(_proxyServer!.indexUrl), httpHeaders: headers);
  }

  Future<VideoPlayerController> _prepareProgressiveController(String playUrl) async {
    final headers = _defaultHeaders(_currentPlayPageUrl ?? playUrl);
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(playUrl),
      httpHeaders: headers,
    );

    _downloadCancelToken = CancelToken();
    unawaited(_downloadToTempInBackground(playUrl, _downloadCancelToken!));
    return controller;
  }

  bool _shouldFallbackToVlc(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('mediacodec') ||
        message.contains('videorenderer') ||
        message.contains('decoder') ||
        message.contains('videoerror');
  }

  bool _shouldForceSoftware(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('mediacodec') ||
        message.contains('decoder') ||
        message.contains('hardware') ||
        message.contains('codec');
  }

  Future<void> _playWithVlc(String playUrl, {bool preferSoftware = false}) async {

    final url = playUrl;
    _waitingForFirstFrame = true;
    _vlcController?.dispose();
    if (_isHarmonyDevice) {
      if (preferSoftware) {
        _harmonyTriedSoftware = true;
      } else {
        _harmonyTriedHardware = true;
      }
    }

    final advanced = <String>[
      '--network-caching=1500',
      '--file-caching=1500',
      '--live-caching=1500',
      '--clock-jitter=0',
      '--clock-synchro=0',
    ];
    if (preferSoftware) {
      advanced.add('--avcodec-hw=none');
    }
    final headers = _defaultHeaders(_currentPlayPageUrl ?? kBaseHost);
    final referrer = _currentPlayPageUrl ?? headers['Referer'] ?? kBaseHost;
    final userAgent = headers['User-Agent'] ?? 'Mozilla/5.0';
    final extras = <String>[];
    if (_isHarmonyDevice) {
      extras.addAll(['--vout=android-display', '--aout=opensles']);
    }
    final options = VlcPlayerOptions(
      advanced: VlcAdvancedOptions(advanced),
      http: VlcHttpOptions([
        VlcHttpOptions.httpReconnect(true),
        VlcHttpOptions.httpContinuous(true),
        VlcHttpOptions.httpForwardCookies(true),
        VlcHttpOptions.httpReferrer(referrer),
        VlcHttpOptions.httpUserAgent(userAgent),
      ]),
      extras: extras.isEmpty ? null : extras,
    );
    final controller = VlcPlayerController.network(

      url,
      hwAcc: preferSoftware ? HwAcc.disabled : HwAcc.auto,
      autoPlay: true,
      autoInitialize: false,
      options: options,
    );

    controller.addListener(() {
      if (!mounted) return;
      final value = controller.value;
      if (value.isInitialized || value.isPlaying) {
        _stopPlaybackWatchdog();
        if (_loading || _waitingForFirstFrame) {
          setState(() {
            _waitingForFirstFrame = false;
            _loading = false;
            _error = null;
          });
        }

      }
      if (value.hasError && value.errorDescription.isNotEmpty) {
        _stopPlaybackWatchdog();
        if (!mounted) return;
        setState(() {
          _waitingForFirstFrame = false;
          _loading = false;
          _error = _safeErrorMessage(value.errorDescription, isPlay: true);
        });
      }
    });
    _vlcController = controller;

    _useVlcPlayer = true;

    await _initializeVlcController(controller, url);
  }

  Future<void> _initializeVlcController(VlcPlayerController controller, String playUrl) async {
    final ready = await _waitForVlcReady(controller);
    if (!ready) {
      await _handleVlcInitError(Exception('vlc view not ready'), playUrl);
      return;
    }
    try {
      await controller.initialize();
    } catch (e) {
      await _handleVlcInitError(e, playUrl);
    }
  }

  Future<bool> _waitForVlcReady(VlcPlayerController controller) async {
    for (var i = 0; i < 50; i++) {
      if (controller.isReadyToInitialize == true) return true;
      await Future.delayed(const Duration(milliseconds: 100));
    }
    return controller.isReadyToInitialize == true;
  }

  Future<void> _handleVlcInitError(Object error, String playUrl) async {
    final message = error.toString().toLowerCase();
    if (message.contains('channel-error') || message.contains('unable to establish connection on channel')) {
      _vlcBroken = true;
    }
    if (_vlcBroken) {
      _useVlcPlayer = false;
      _decoderPreference = DecoderPreference.native;
      _vlcController?.dispose();
      _vlcController = null;
      await _playNativeFallback(playUrl);
      return;
    }
    if (_isHarmonyDevice && !_harmonyTriedSoftware) {
      _preferVlcSoftware = true;
      _decoderPreference = DecoderPreference.vlcSoftware;
      await _playWithVlc(playUrl, preferSoftware: true);
      return;
    }
    if (!mounted) return;
    setState(() {
      _waitingForFirstFrame = false;
      _loading = false;
      _error = _safeErrorMessage(error, isPlay: true);
    });
  }

  Future<void> _playNativeFallback(String playUrl) async {
    try {
      _waitingForFirstFrame = true;
      _startPlaybackWatchdog(playUrl, usingVlc: false, preferSoftware: false);
      final isHls = playUrl.toLowerCase().contains('.m3u8');
      final controller = isHls
          ? await _prepareHlsController(playUrl)
          : await _prepareProgressiveController(playUrl);
      await controller.initialize();
      await controller.play();
      _stopPlaybackWatchdog();
      if (!mounted) return;
      setState(() {
        _controller = controller;
        _autoSwitchCount = 0;
        _waitingForFirstFrame = false;
        _loading = false;
        _error = null;
      });

    } catch (e) {
      _stopPlaybackWatchdog();
      if (!mounted) return;
      setState(() {
        _waitingForFirstFrame = false;
        _loading = false;
        _error = _safeErrorMessage(e, isPlay: true);
      });
    }
  }

  bool _isDecodeError(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('mediacodec') ||
        message.contains('videorenderer') ||
        message.contains('decoder') ||
        message.contains('codec') ||
        message.contains('videoerror');
  }

  PlaySource? _pickNextSourceForAutoSwitch() {
    if (_sources.isEmpty) return null;
    final current = _currentSource;
    final currentIndex = current == null
        ? -1
        : _sources.indexWhere(
            (s) => s.name == current.name && s.playPageUrl == current.playPageUrl,
          );
    for (var i = 1; i <= _sources.length; i++) {
      final idx = (currentIndex + i) % _sources.length;
      final candidate = _sources[idx];
      if (current != null && candidate.name == current.name && candidate.playPageUrl == current.playPageUrl) {
        continue;
      }
      return candidate;
    }
    return null;
  }

  Future<bool> _tryAutoSwitchSourceOnDecode(Object error) async {
    if (!_isHarmonyDevice) return false;
    if (!_isDecodeError(error)) return false;
    if (_autoSwitchCount >= 2) return false;
    final next = _pickNextSourceForAutoSwitch();
    if (next == null) return false;
    _autoSwitchCount++;
    if (!mounted) return false;
    setState(() {
      _loading = true;
      _error = null;
    });
    final episodes = _sourceEpisodes[next.name];
    if (episodes != null && episodes.isNotEmpty) {
      _episodes = episodes;
      _currentSource = next;
      _currentEpisode = episodes.first;
      await _playEpisode(episodes.first);
      return true;
    }
    await _playSource(next);
    return true;
  }

  Future<bool> _tryVlcFallback(String? playUrl, Object error) async {


    if (!Platform.isAndroid) return false;
    if (_vlcBroken) return false;
    if (playUrl == null || playUrl.isEmpty) return false;
    if (!_shouldFallbackToVlc(error)) return false;

    final preferSoftware = _preferVlcSoftware || _shouldForceSoftware(error) || (_isHarmonyDevice && _harmonyTriedHardware);
    _decoderPreference = preferSoftware ? DecoderPreference.vlcSoftware : DecoderPreference.vlcHardware;
    await _playWithVlc(playUrl, preferSoftware: preferSoftware);
    return true;
  }


  Future<void> _downloadToTempInBackground(String url, CancelToken token) async {

    try {
      final dir = await getTemporaryDirectory();
      final safeName = base64Url.encode(utf8.encode(url));
      final file = File('${dir.path}/cache_$safeName');
      _cachedFile = file;
      if (await file.exists()) return;
      final dio = createDio(headers: _defaultHeaders(url));
      await dio.download(url, file.path, cancelToken: token);
    } catch (_) {}
  }

  void _startPlaybackWatchdog(String playUrl, {required bool usingVlc, required bool preferSoftware}) {
    _playbackWatchdog?.cancel();
    final requestId = ++_playRequestId;
    final timeout = _isHarmonyDevice ? 25 : 15;
    _playbackWatchdog = Timer(Duration(seconds: timeout), () async {

      if (!mounted || requestId != _playRequestId) return;
      if (!_waitingForFirstFrame) return;
      if (usingVlc) {
        if (!preferSoftware) {
          _preferVlcSoftware = true;
          _decoderPreference = DecoderPreference.vlcSoftware;
          _waitingForFirstFrame = true;
          await _playWithVlc(playUrl, preferSoftware: true);
          return;
        }
      } else {
        if (Platform.isAndroid) {
          _waitingForFirstFrame = true;
          await _playWithVlc(
            playUrl,
            preferSoftware: _preferVlcSoftware || (_isHarmonyDevice && _harmonyTriedHardware),
          );
          if (!mounted) return;
          setState(() {
            _loading = false;
            _error = null;
          });
          return;
        }
      }
      if (!mounted) return;
      setState(() {
        _waitingForFirstFrame = false;
        _loading = false;
        _error = '播放超时，请重试或切换视频源';
      });
    });

  }

  void _stopPlaybackWatchdog() {
    _playbackWatchdog?.cancel();
  }

  Future<void> _resetPlayer() async {
    _stopPlaybackWatchdog();
    _waitingForFirstFrame = false;
    if (_isHarmonyDevice) {
      _harmonyTriedHardware = false;
      _harmonyTriedSoftware = false;
    }

    try {
      await _proxyServer?.close();
    } catch (_) {}
    _proxyServer = null;

    _controller?.dispose();
    _controller = null;
    _vlcController?.dispose();
    _vlcController = null;
    await _deleteCache();

    _cachedFile = null;
    _cacheDir = null;
  }



  void _showSourceSheet() {
    if (_sources.isEmpty && _episodes.isEmpty) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF242424),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return ListView(
              controller: scrollController,
              padding: const EdgeInsets.all(16),
              children: [
                const Text('切换视频源', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                if (_sources.isNotEmpty) ..._sources.map(_sourceTile),
                if (_episodes.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text('选集', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _episodes.map(_episodeChip).toList(),
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }


  void _openPlayerDebugPanel() {
    if (!_isDesktop) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF242424),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return ListView(
              controller: scrollController,
              padding: const EdgeInsets.all(16),
              children: [
                const Text('播放调试面板', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                const Text('切换视频源', style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 8),
                if (_sources.isNotEmpty) ..._sources.map(_sourceTile),
                if (_episodes.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text('选集', style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _episodes.map(_episodeChip).toList(),
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }


  Widget _sourceTile(PlaySource source) {
    final selected = identical(source, _currentSource) ||
        (_currentSource?.name == source.name && _currentSource?.playPageUrl == source.playPageUrl);
    final episodes = _sourceEpisodes[source.name];
    final subtitleText = source.mediaUrl != null
        ? source.mediaUrl!
        : (episodes != null && episodes.isNotEmpty)
            ? '共${episodes.length}集'
            : '待解析';
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(selected ? Icons.check_circle : Icons.play_circle_outline, color: Colors.white70),
      title: Text(source.name, style: const TextStyle(color: Colors.white)),
      subtitle: Text(subtitleText, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white38)),
      onTap: () async {
        Navigator.of(context).pop();
        setState(() {
          _loading = true;
          _error = null;
        });
        if (episodes != null && episodes.isNotEmpty) {
          setState(() {
            _episodes = episodes;
            _currentSource = source;
          });
          final next = _pickEpisodeForSource(episodes);
          _currentEpisode = next;
          await _playEpisode(next);
          return;
        }
        await _playSource(source);
      },
    );
  }


  Widget _episodeChip(EpisodeItem episode) {
    final selected = _currentEpisode?.playUrl == episode.playUrl;
    return ChoiceChip(
      label: Text(episode.name),
      selected: selected,
      onSelected: (_) {
        setState(() {
          _loading = true;
          _error = null;
        });
        _playEpisode(episode);
      },
    );
  }

  EpisodeItem _pickEpisodeForSource(List<EpisodeItem> episodes) {
    final current = _currentEpisode;
    if (current != null) {
      final byName = episodes.indexWhere((e) => e.name == current.name);
      if (byName >= 0) return episodes[byName];
      final byUrl = episodes.indexWhere((e) => e.playUrl == current.playUrl);
      if (byUrl >= 0) return episodes[byUrl];
    }
    return episodes.first;
  }

  Future<void> _openFullscreen() async {
    final vlc = _vlcController;
    if (_useVlcPlayer && vlc != null) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => _FullscreenVlcPlayerPage(
            controller: vlc,
            title: widget.item.title,
            virtualDisplay: !_isHarmonyDevice,
          ),

        ),
      );
      if (mounted) setState(() {});
      return;
    }
    final controller = _controller;
    if (controller == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _FullscreenPlayerPage(
          controller: controller,
          title: widget.item.title,
        ),
      ),
    );
    if (mounted) setState(() {});
  }



  @override
  Widget build(BuildContext context) {
    final useVlc = _useVlcPlayer && !_vlcBroken && _vlcController != null;

    final vlcAspect = useVlc && _vlcController!.value.aspectRatio > 0
        ? _vlcController!.value.aspectRatio
        : 16 / 9;

    return Scaffold(


      backgroundColor: Colors.black,

      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(widget.item.title),
        actions: [
          IconButton(
            tooltip: '切换视频源',
            onPressed: _showSourceSheet,
            icon: const Icon(Icons.swap_horiz_rounded),
          ),
          if (_isDesktop)
            IconButton(
              tooltip: '调试面板',
              onPressed: _openPlayerDebugPanel,
              icon: const Icon(Icons.bug_report_rounded),
            ),
        ],
      ),

      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () {
                          _controller?.dispose();
                          _controller = null;
                          _vlcController?.dispose();
                          _vlcController = null;
                          setState(() {
                            _loading = true;
                            _error = null;
                          });
                          _initPlayer();
                        },

                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('重试'),
                      ),

                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: _showSourceSheet,
                        icon: const Icon(Icons.swap_horiz_rounded),
                        label: const Text('切换视频源'),
                      ),

                    ],
                  ),
                )
              : (useVlc ? _vlcController == null : _controller == null)
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('播放器未就绪'),
                          const SizedBox(height: 10),
                          ElevatedButton.icon(
                            onPressed: () {
                              setState(() {
                                _loading = true;
                                _error = null;
                              });
                              _initPlayer();
                            },
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('重试'),
                          ),
                        ],
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      children: [
                        AspectRatio(
                          aspectRatio: useVlc ? vlcAspect : _controller!.value.aspectRatio,
                          child: useVlc
                              ? VlcPlayer(
                                  controller: _vlcController!,
                                  aspectRatio: vlcAspect,
                                  virtualDisplay: !_isHarmonyDevice,
                                  placeholder: const Center(child: CircularProgressIndicator()),
                                )

                              : VideoPlayer(_controller!),
                        ),
                        const SizedBox(height: 8),
                        useVlc
                            ? _VlcControls(
                                controller: _vlcController!,
                                onToggleFullscreen: _openFullscreen,
                                isFullscreen: false,
                              )
                            : _PlayerControls(
                                controller: _controller!,
                                onToggleFullscreen: _openFullscreen,
                                isFullscreen: false,
                              ),


                        if (_episodes.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 44,
                            child: ListView.separated(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              scrollDirection: Axis.horizontal,
                              itemBuilder: (context, index) => _episodeChip(_episodes[index]),
                              separatorBuilder: (_, __) => const SizedBox(width: 8),
                              itemCount: _episodes.length,
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        const Center(
                          child: Text(
                            '2026 © 晨曦微光',
                            style: TextStyle(color: Colors.white38, fontSize: 12),
                          ),
                        ),
                      ],
                    ),



    );
  }
}

class _PlayerControls extends StatelessWidget {
  const _PlayerControls({
    required this.controller,
    required this.onToggleFullscreen,
    required this.isFullscreen,
  });

  final VideoPlayerController controller;
  final VoidCallback onToggleFullscreen;
  final bool isFullscreen;

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }

  String _formatSpeed(double speed) {
    final whole = speed % 1 == 0;
    return whole ? speed.toStringAsFixed(0) : speed.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        if (!value.isInitialized) return const SizedBox.shrink();
        final duration = value.duration;
        final position = value.position;
        final totalMs = duration.inMilliseconds;
        final posMs = position.inMilliseconds.clamp(0, totalMs);
        final volume = value.volume.clamp(0.0, 1.0);
        final speed = value.playbackSpeed;
        return Column(
          children: [
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                activeTrackColor: const Color(0xFFF06292),
                inactiveTrackColor: Colors.white24,
                thumbColor: const Color(0xFFF06292),
                overlayColor: const Color(0x33F06292),
              ),
              child: Slider(
                value: totalMs == 0 ? 0 : posMs.toDouble(),
                max: totalMs == 0 ? 1 : totalMs.toDouble(),
                onChanged: totalMs == 0
                    ? null
                    : (v) => controller.seekTo(Duration(milliseconds: v.toInt())),
              ),
            ),
            Row(
              children: [
                IconButton(
                  icon: Icon(
                    value.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
                    color: Colors.white,
                    size: 36,
                  ),
                  onPressed: () async {
                    if (value.isPlaying) {
                      await controller.pause();
                    } else {
                      await controller.play();
                    }
                  },
                ),
                Text(
                  '${_formatDuration(position)} / ${_formatDuration(duration)}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.replay_10_rounded, color: Colors.white70),
                  onPressed: () {
                    final target = position - const Duration(seconds: 10);
                    controller.seekTo(target < Duration.zero ? Duration.zero : target);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.forward_10_rounded, color: Colors.white70),
                  onPressed: () {
                    final target = position + const Duration(seconds: 10);
                    controller.seekTo(target > duration ? duration : target);
                  },
                ),
                IconButton(
                  icon: Icon(
                    isFullscreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
                    color: Colors.white70,
                  ),
                  onPressed: onToggleFullscreen,
                ),
              ],
            ),
            Row(
              children: [
                PopupMenuButton<double>(
                  initialValue: speed,
                  onSelected: (v) => controller.setPlaybackSpeed(v),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 0.5, child: Text('0.5x')),
                    PopupMenuItem(value: 0.75, child: Text('0.75x')),
                    PopupMenuItem(value: 1.0, child: Text('1.0x')),
                    PopupMenuItem(value: 1.25, child: Text('1.25x')),
                    PopupMenuItem(value: 1.5, child: Text('1.5x')),
                    PopupMenuItem(value: 2.0, child: Text('2.0x')),
                  ],
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A2A2A),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF3A3A3A)),
                    ),
                    child: Text(
                      '${_formatSpeed(speed)}x',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Icon(Icons.volume_up_rounded, color: Colors.white70, size: 18),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 2.5,
                      activeTrackColor: Colors.white70,
                      inactiveTrackColor: Colors.white24,
                      thumbColor: Colors.white,
                      overlayColor: const Color(0x33FFFFFF),
                    ),
                    child: Slider(
                      value: volume,
                      min: 0,
                      max: 1,
                      onChanged: (v) => controller.setVolume(v),
                    ),
                  ),
                ),
                SizedBox(
                  width: 48,
                  child: Text(
                    '${(volume * 100).round()}%',
                    textAlign: TextAlign.right,
                    style: const TextStyle(color: Colors.white60, fontSize: 11),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _VlcControls extends StatelessWidget {
  const _VlcControls({
    required this.controller,
    required this.onToggleFullscreen,
    required this.isFullscreen,
  });

  final VlcPlayerController controller;
  final VoidCallback onToggleFullscreen;
  final bool isFullscreen;

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }

  String _formatSpeed(double speed) {
    final whole = speed % 1 == 0;
    return whole ? speed.toStringAsFixed(0) : speed.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<VlcPlayerValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        if (!value.isInitialized) return const SizedBox.shrink();
        final duration = value.duration;
        final position = value.position;
        final totalMs = duration.inMilliseconds;
        final posMs = position.inMilliseconds.clamp(0, totalMs);
        final volume = (value.volume / 100).clamp(0.0, 1.0);
        final speed = value.playbackSpeed;
        return Column(
          children: [
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                activeTrackColor: const Color(0xFFF06292),
                inactiveTrackColor: Colors.white24,
                thumbColor: const Color(0xFFF06292),
                overlayColor: const Color(0x33F06292),
              ),
              child: Slider(
                value: totalMs == 0 ? 0 : posMs.toDouble(),
                max: totalMs == 0 ? 1 : totalMs.toDouble(),
                onChanged: totalMs == 0
                    ? null
                    : (v) => controller.seekTo(Duration(milliseconds: v.toInt())),
              ),
            ),
            Row(
              children: [
                IconButton(
                  icon: Icon(
                    value.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
                    color: Colors.white,
                    size: 36,
                  ),
                  onPressed: () async {
                    if (value.isPlaying) {
                      await controller.pause();
                    } else {
                      await controller.play();
                    }
                  },
                ),
                Text(
                  '${_formatDuration(position)} / ${_formatDuration(duration)}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.replay_10_rounded, color: Colors.white70),
                  onPressed: () {
                    final target = position - const Duration(seconds: 10);
                    controller.seekTo(target < Duration.zero ? Duration.zero : target);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.forward_10_rounded, color: Colors.white70),
                  onPressed: () {
                    final target = position + const Duration(seconds: 10);
                    controller.seekTo(target > duration ? duration : target);
                  },
                ),
                IconButton(
                  icon: Icon(
                    isFullscreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
                    color: Colors.white70,
                  ),
                  onPressed: onToggleFullscreen,
                ),
              ],
            ),
            Row(
              children: [
                PopupMenuButton<double>(
                  initialValue: speed,
                  onSelected: (v) => controller.setPlaybackSpeed(v),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 0.5, child: Text('0.5x')),
                    PopupMenuItem(value: 0.75, child: Text('0.75x')),
                    PopupMenuItem(value: 1.0, child: Text('1.0x')),
                    PopupMenuItem(value: 1.25, child: Text('1.25x')),
                    PopupMenuItem(value: 1.5, child: Text('1.5x')),
                    PopupMenuItem(value: 2.0, child: Text('2.0x')),
                  ],
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A2A2A),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF3A3A3A)),
                    ),
                    child: Text(
                      '${_formatSpeed(speed)}x',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Icon(Icons.volume_up_rounded, color: Colors.white70, size: 18),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 2.5,
                      activeTrackColor: Colors.white70,
                      inactiveTrackColor: Colors.white24,
                      thumbColor: Colors.white,
                      overlayColor: const Color(0x33FFFFFF),
                    ),
                    child: Slider(
                      value: volume,
                      min: 0,
                      max: 1,
                      onChanged: (v) => controller.setVolume((v * 100).round()),
                    ),
                  ),
                ),
                SizedBox(
                  width: 48,
                  child: Text(
                    '${(volume * 100).round()}%',
                    textAlign: TextAlign.right,
                    style: const TextStyle(color: Colors.white60, fontSize: 11),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _FullscreenVlcPlayerPage extends StatefulWidget {
  const _FullscreenVlcPlayerPage({
    required this.controller,
    required this.title,
    required this.virtualDisplay,
  });

  final VlcPlayerController controller;
  final String title;
  final bool virtualDisplay;


  @override
  State<_FullscreenVlcPlayerPage> createState() => _FullscreenVlcPlayerPageState();
}

class _FullscreenVlcPlayerPageState extends State<_FullscreenVlcPlayerPage> {
  Timer? _hideTimer;
  bool _controlsVisible = true;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _startHideTimer();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    super.dispose();
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _controlsVisible = false;
        });
      }
    });
  }

  void _showControls() {
    if (!_controlsVisible) {
      setState(() {
        _controlsVisible = true;
      });
    }
    _startHideTimer();
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.controller.value;
    final aspect = value.aspectRatio > 0 ? value.aspectRatio : 16 / 9;
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _showControls,
        child: SafeArea(
          child: Stack(
            children: [
              Center(
                child: AspectRatio(
                  aspectRatio: aspect,
                  child: VlcPlayer(
                    controller: widget.controller,
                    aspectRatio: aspect,
                    virtualDisplay: widget.virtualDisplay,
                    placeholder: const Center(child: CircularProgressIndicator()),
                  ),

                ),
              ),
              if (_controlsVisible)
                Positioned(
                  left: 8,
                  top: 8,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white70),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              if (_controlsVisible)
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: _VlcControls(
                    controller: widget.controller,
                    onToggleFullscreen: () => Navigator.of(context).pop(),
                    isFullscreen: true,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FullscreenPlayerPage extends StatefulWidget {
  const _FullscreenPlayerPage({required this.controller, required this.title});


  final VideoPlayerController controller;
  final String title;

  @override
  State<_FullscreenPlayerPage> createState() => _FullscreenPlayerPageState();
}

class _FullscreenPlayerPageState extends State<_FullscreenPlayerPage> {
  Timer? _hideTimer;
  bool _controlsVisible = true;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _startHideTimer();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    super.dispose();
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _controlsVisible = false;
        });
      }
    });
  }

  void _showControls() {
    if (!_controlsVisible) {
      setState(() {
        _controlsVisible = true;
      });
    }
    _startHideTimer();
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.controller.value;
    final aspect = value.isInitialized && value.aspectRatio > 0 ? value.aspectRatio : 16 / 9;
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _showControls,
        child: SafeArea(
          child: Stack(
            children: [
              Center(
                child: AspectRatio(
                  aspectRatio: aspect,
                  child: VideoPlayer(widget.controller),
                ),
              ),
              if (_controlsVisible)
                Positioned(
                  left: 8,
                  top: 8,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white70),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              if (_controlsVisible)
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: _PlayerControls(
                    controller: widget.controller,
                    onToggleFullscreen: () => Navigator.of(context).pop(),
                    isFullscreen: true,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}



class _CircleAction extends StatelessWidget {

  const _CircleAction({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFF2C2C2C),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF3A3A3A)),
        ),
        child: Icon(icon, color: Colors.white70),
      ),
    );
  }
}

class TopTab {
  const TopTab(this.title, this.url, this.token);
  final String title;
  final String url;
  final String token;
}

class PageData {
  PageData({required this.items, required this.filters});
  final List<VideoItem> items;
  final List<FilterGroup> filters;
}

class FilterGroup {
  FilterGroup(this.label, this.items);
  final String label;
  final List<FilterItem> items;
}

class FilterItem {
  FilterItem({required this.title, required this.url, required this.selected});
  final String title;
  final String url;
  final bool selected;
}

class VideoItem {
  VideoItem({
    required this.title,
    required this.detailUrl,
    required this.coverUrl,
    required this.subTitle,
    required this.badge,
  });

  final String title;
  final String detailUrl;
  final String coverUrl;
  final String subTitle;
  final String badge;
}

class PlaySource {
  PlaySource({
    required this.name,
    this.playPageUrl,
    this.mediaUrl,
  });

  final String name;
  final String? playPageUrl;
  final String? mediaUrl;

  PlaySource copyWith({String? mediaUrl}) {
    return PlaySource(
      name: name,
      playPageUrl: playPageUrl,
      mediaUrl: mediaUrl ?? this.mediaUrl,
    );
  }
}

class EpisodeItem {
  EpisodeItem({required this.name, required this.playUrl});
  final String name;
  final String playUrl;
}

class PlayMeta {
  PlayMeta({required this.sources, required this.episodes, required this.sourceEpisodes});
  final List<PlaySource> sources;
  final List<EpisodeItem> episodes;
  final Map<String, List<EpisodeItem>> sourceEpisodes;
}

class _SourceEpisodeBundle {
  _SourceEpisodeBundle({required this.sources, required this.sourceEpisodes, required this.activeIndex});
  final List<PlaySource> sources;
  final Map<String, List<EpisodeItem>> sourceEpisodes;
  final int activeIndex;
}










enum DecoderPreference { native, vlcHardware, vlcSoftware }

class DeviceProfile {
  DeviceProfile({
    required this.isAndroid,
    required this.sdkInt,
    required this.supportedAbis,
    required this.brand,
    required this.manufacturer,
    required this.device,
    required this.model,
    required this.product,
    required this.hardware,
    required this.display,
    required this.isHarmony,
    required this.isTvBox,
    required this.isLowEnd,
    required this.recommendedApkTag,
    required this.decoderPreference,
  });

  final bool isAndroid;
  final int? sdkInt;
  final List<String> supportedAbis;
  final String brand;
  final String manufacturer;
  final String device;
  final String model;
  final String product;
  final String hardware;
  final String display;
  final bool isHarmony;
  final bool isTvBox;
  final bool isLowEnd;
  final String recommendedApkTag;
  final DecoderPreference decoderPreference;

  bool get isOldAndroid => sdkInt != null && sdkInt! < 24;
  bool get hasInstallParseRisk => sdkInt != null && sdkInt! < 21;
}

class DeviceProfileManager {
  DeviceProfileManager._();

  static final DeviceProfileManager instance = DeviceProfileManager._();

  DeviceProfile? _profile;

  DeviceProfile? get profile => _profile;

  Future<void> init() async {
    if (_profile != null) return;
    if (!Platform.isAndroid) {
      _profile = DeviceProfile(
        isAndroid: false,
        sdkInt: null,
        supportedAbis: const [],
        brand: '',
        manufacturer: '',
        device: '',
        model: '',
        product: '',
        hardware: '',
        display: '',
        isHarmony: false,
        isTvBox: false,
        isLowEnd: false,
        recommendedApkTag: 'universal',
        decoderPreference: DecoderPreference.native,
      );
      return;
    }
    try {
      final info = await DeviceInfoPlugin().androidInfo;
      final lower = (String? v) => (v ?? '').toLowerCase();
      final brand = lower(info.brand);
      final manufacturer = lower(info.manufacturer);
      final device = lower(info.device);
      final model = lower(info.model);
      final product = lower(info.product);
      final hardware = lower(info.hardware);
      final display = lower(info.display);
      final abis = info.supportedAbis.map((e) => e.toLowerCase()).toList();
      final sdkInt = info.version.sdkInt;

      final isHuawei = [brand, manufacturer, device, model, product].any(
        (v) => v.contains('huawei') || v.contains('honor'),
      );
      final isHarmony = display.contains('harmony') ||
          display.contains('hongmeng') ||
          display.contains('hm') ||
          isHuawei;

      final deviceHints = '$brand $manufacturer $model $device $product $hardware'.toLowerCase();
      final isTvBox = _containsAny(deviceHints, [
        'tv',
        'box',
        'androidtv',
        'mibox',
        'mi box',
        'x96',
        'x98',
        'x88',
        'rk',
        'rockchip',
        'amlogic',
        'mstar',
        'allwinner',
        'skyworth',
        'hisense',
        'konka',
        'coocaa',
        'changhong',
        'tcl',
        'philips',
        'sony',
      ]);

      final is32Only = abis.isNotEmpty && !abis.any((a) => a.contains('arm64') || a.contains('x86_64'));
      final isLowEnd = (sdkInt <= 25) || is32Only || _containsAny(deviceHints, ['amlogic', 'rockchip', 'mstar', 'allwinner']);

      DecoderPreference decoderPreference = DecoderPreference.native;
      if (isHarmony) {
        decoderPreference = DecoderPreference.native;
      } else if (isLowEnd) {
        decoderPreference = DecoderPreference.vlcSoftware;
      } else if (isTvBox) {
        decoderPreference = DecoderPreference.vlcHardware;
      }

      _profile = DeviceProfile(
        isAndroid: true,
        sdkInt: sdkInt,
        supportedAbis: abis,
        brand: brand,
        manufacturer: manufacturer,
        device: device,
        model: model,
        product: product,
        hardware: hardware,
        display: display,
        isHarmony: isHarmony,
        isTvBox: isTvBox,
        isLowEnd: isLowEnd,
        recommendedApkTag: _pickApkTag(abis),
        decoderPreference: decoderPreference,
      );
    } catch (_) {
      _profile = DeviceProfile(
        isAndroid: true,
        sdkInt: null,
        supportedAbis: const [],
        brand: '',
        manufacturer: '',
        device: '',
        model: '',
        product: '',
        hardware: '',
        display: '',
        isHarmony: false,
        isTvBox: false,
        isLowEnd: false,
        recommendedApkTag: 'universal',
        decoderPreference: DecoderPreference.native,
      );
    }
  }
}

bool _containsAny(String source, List<String> keys) {
  for (final key in keys) {
    if (source.contains(key)) return true;
  }
  return false;
}

String _pickApkTag(List<String> abis) {
  if (abis.any((a) => a.contains('arm64'))) return 'arm64-v8a';
  if (abis.any((a) => a.contains('armeabi-v7a'))) return 'armeabi-v7a';
  if (abis.any((a) => a.contains('x86_64'))) return 'x86_64';
  if (abis.any((a) => a.contains('x86'))) return 'x86';
  return abis.isNotEmpty ? abis.first : 'universal';
}

String _safeErrorMessage(Object error, {required bool isPlay}) {
  final message = error.toString().toLowerCase();
  final isNetwork = message.contains('socketexception') ||
      message.contains('failed host lookup') ||
      message.contains('network') ||
      message.contains('timed out') ||
      message.contains('connection') ||
      message.contains('http');
  if (isNetwork) {
    return '连接服务器失败，请检查网络';
  }
  if (isPlay) {
    if (message.contains('mediacodec') || message.contains('videorenderer') || message.contains('decoder')) {
      return '当前设备解码失败，请切换视频源或重试';
    }
    return '播放失败，请重试或切换视频源';
  }
  return '连接服务器失败，请检查网络';
}


Future<PageData> fetchPage(String url) async {

  final resp = await http.get(Uri.parse(url), headers: _defaultHeaders(url));
  if (resp.statusCode != 200) {
    throw Exception('HTTP ${resp.statusCode}');
  }

  final doc = html_parser.parse(resp.body);
  final items = <VideoItem>[];
  final listNodes = doc.querySelectorAll('ul.vodlist li.vodlist_item');
  for (final node in listNodes) {
    final anchor = node.querySelector('a.vodlist_thumb');
    final title = anchor?.attributes['title'] ?? node.querySelector('p.vodlist_title a')?.text.trim();
    if (title == null || title.isEmpty) continue;
    final detailHref = anchor?.attributes['href'] ?? node.querySelector('p.vodlist_title a')?.attributes['href'] ?? '';
    final cover = anchor?.attributes['data-background-image'] ?? '';
    final subTitle = node.querySelector('p.vodlist_sub')?.text.trim() ?? '';
    final badge = node.querySelector('.xszxj')?.text.trim() ?? '';
    items.add(VideoItem(
      title: title,
      detailUrl: toAbsUrl(detailHref),
      coverUrl: cover.startsWith('http') ? cover : toAbsUrl(cover),
      subTitle: subTitle,
      badge: badge,
    ));
  }

  final filters = <FilterGroup>[];
  filters.add(FilterGroup('分类', _parseFilterGroup(doc, 'hl01', url)));
  filters.add(FilterGroup('类型', _parseFilterGroup(doc, 'hl02', url)));
  filters.add(FilterGroup('地区', _parseFilterGroup(doc, 'hl03', url)));
  filters.add(FilterGroup('年份', _parseFilterGroup(doc, 'hl04', url)));

  return PageData(items: items, filters: filters);
}

List<FilterItem> _parseFilterGroup(dom.Document doc, String id, String currentUrl) {
  final result = <FilterItem>[];
  final section = doc.querySelector('#$id .screen_list');
  if (section == null) return result;
  final items = section.querySelectorAll('li');
  for (final li in items) {
    final a = li.querySelector('a');
    if (a == null) continue;
    final title = a.text.trim();
    if (title.isEmpty) continue;
    final href = a.attributes['href'];
    final url = href == null || href.isEmpty ? currentUrl : toAbsUrl(href);
    final selected = li.classes.contains('hl');
    result.add(FilterItem(title: title, url: url, selected: selected));
  }
  return result;
}

String toAbsUrl(String url) {
  if (url.isEmpty) return url;
  if (url.startsWith('http')) return url;
  if (url.startsWith('//')) return 'https:$url';
  return '$kBaseHost$url';
}

Future<PlayMeta> fetchPlayMeta(String detailUrl) async {
  final detailResp = await http.get(Uri.parse(detailUrl), headers: _defaultHeaders(detailUrl));
  if (detailResp.statusCode != 200) {
    return PlayMeta(sources: [], episodes: [], sourceEpisodes: {});
  }

  final detailHtml = detailResp.body;

  final sources = <PlaySource>[];
  final direct = _parsePlayUrlFromHtml(detailHtml);
  if (direct != null) {
    sources.add(PlaySource(name: '默认线路', mediaUrl: direct));
  }

  final doc = html_parser.parse(detailHtml);
  final bundle = _parseSourceEpisodes(doc);
  final sourceEpisodes = <String, List<EpisodeItem>>{}..addAll(bundle.sourceEpisodes);

  for (final link in bundle.sources) {
    final exists = sources.indexWhere((s) => s.name == link.name && s.playPageUrl == link.playPageUrl) >= 0;
    if (!exists) sources.add(link);
  }

  if (sources.isEmpty) {
    final playLinks = _findPlayPageUrls(doc);
    for (final link in playLinks) {
      if (sources.indexWhere((s) => s.playPageUrl == link.playPageUrl) >= 0) continue;
      sources.add(link);
    }
  }

  List<EpisodeItem> episodes = [];
  if (bundle.sources.isNotEmpty) {
    final activeName = bundle.sources[bundle.activeIndex.clamp(0, bundle.sources.length - 1)].name;
    episodes = sourceEpisodes[activeName] ?? [];
  }
  if (episodes.isEmpty) {
    episodes = _extractEpisodes(doc);
    if (episodes.isNotEmpty && sourceEpisodes.isEmpty) {
      sourceEpisodes['默认线路'] = episodes;
      if (sources.indexWhere((s) => s.name == '默认线路') < 0) {
        sources.add(PlaySource(name: '默认线路'));
      }
    }
  }

  return PlayMeta(sources: sources, episodes: episodes, sourceEpisodes: sourceEpisodes);
}



String? _parsePlayUrlFromHtml(String html) {
  final playerMatch = RegExp(r'player_data\s*=\s*(\{.*?\})\s*;', dotAll: true).firstMatch(html);
  if (playerMatch != null) {
    final obj = playerMatch.group(1)!;
    final url = _extractField(obj, 'url');
    final encrypt = _extractField(obj, 'encrypt');
    if (url != null) {
      final decoded = _decodeUrl(url, encrypt);
      if (decoded != null) return decoded;
    }
  }

  final urlField = RegExp(r'''["']url["']\s*:\s*["']([^"']+)["']''').firstMatch(html);
  if (urlField != null) {
    final url = urlField.group(1)!;
    final encrypt = RegExp(r'''["']encrypt["']\s*:\s*["']?(\d+)''').firstMatch(html)?.group(1);
    final decoded = _decodeUrl(url, encrypt);
    if (decoded != null) return decoded;
  }

  final attrField = RegExp(r'''(?:data-url|data-src|data-play)\s*=\s*["']([^"']+)["']''', caseSensitive: false).firstMatch(html);
  if (attrField != null) {
    final url = attrField.group(1)!;
    final decoded = _decodeUrl(url, null);
    if (decoded != null) return decoded;
  }

  final videoMatch = RegExp(r'''https?:\/\/[^\s"']+\.(m3u8|mp4|mkv|flv|mov)''', caseSensitive: false).firstMatch(html);
  if (videoMatch != null) return videoMatch.group(0);

  return null;
}

List<PlaySource> _findPlayPageUrls(dom.Document doc) {
  final results = <PlaySource>[];
  final selectors = [
    'a[href*="/play/"]',
    'a[href*="/player/"]',
    'a.play',
    'a.btn_play',
  ];
  for (final selector in selectors) {
    final links = doc.querySelectorAll(selector);
    for (final link in links) {
      final href = link.attributes['href'];
      if (href == null || href.isEmpty) continue;
      final title = link.text.trim().isNotEmpty
          ? link.text.trim()
          : (link.attributes['title'] ?? link.attributes['data-name'] ?? '线路');
      results.add(PlaySource(name: title, playPageUrl: toAbsUrl(href)));
    }
  }

  const attrs = ['data-play', 'data-url', 'data-href'];
  for (final attr in attrs) {
    final els = doc.querySelectorAll('[$attr]');
    for (final el in els) {
      final val = el.attributes[attr];
      if (val == null || val.isEmpty) continue;
      final title = el.attributes['data-name'] ?? el.attributes['title'] ?? '线路';
      results.add(PlaySource(name: title, playPageUrl: toAbsUrl(val)));
    }
  }
  return results;
}

String? _findPlayPageUrl(dom.Document doc) {
  final list = _findPlayPageUrls(doc);
  return list.isEmpty ? null : list.first.playPageUrl;
}

List<EpisodeItem> _extractEpisodes(dom.Document doc) {
  const containerSelectors = [
    '.playlist',
    '.play_list',
    '.play-list',
    '.playerlist',
    '.play-num',
    '.playNum',
    '.episode_list',
    '.playlists',
    '#playlist',
    '.play_list_box',
    '.play-episode',
  ];
  final containers = <dom.Element>[];
  for (final selector in containerSelectors) {
    containers.addAll(doc.querySelectorAll(selector));
  }
  for (final container in containers) {
    final eps = _extractEpisodesFromContainer(container);
    if (eps.isNotEmpty) return eps;
  }

  final results = <EpisodeItem>[];
  final seen = <String>{};
  final candidates = doc.querySelectorAll('a');
  for (final link in candidates) {
    final raw = _extractPlayLink(link);
    if (raw == null) continue;
    if (!_isPlayableLink(raw)) continue;
    final url = _normalizePlayUrl(raw);
    if (seen.contains(url)) continue;
    final name = _extractEpisodeName(link);
    if (name == null || name.isEmpty) continue;
    seen.add(url);
    results.add(EpisodeItem(name: name, playUrl: url));
  }
  return results;
}







_SourceEpisodeBundle _parseSourceEpisodes(dom.Document doc) {
  const tabSelectors = [
    '.play_source li',
    '.play_source a',
    '.play_source_box li',
    '.play_source_box a',
    '.play_source_list li',
    '.play_source_list a',
    '.vod_play_tab li',
    '.vod_play_tab a',
    '.play-source li',
    '.play-source a',
  ];
  final tabElements = <dom.Element>[];
  for (final selector in tabSelectors) {
    tabElements.addAll(doc.querySelectorAll(selector));
  }

  final sources = <PlaySource>[];
  final seenNames = <String>{};
  var activeIndex = 0;
  for (final el in tabElements) {
    final node = el.querySelector('a') ?? el;
    final name = node.text.trim().isNotEmpty
        ? node.text.trim()
        : (node.attributes['title'] ?? node.attributes['data-name'] ?? '');
    if (name.isEmpty || seenNames.contains(name)) continue;
    final raw = _extractPlayLink(node) ?? _extractPlayLink(el);
    final playUrl = raw != null && _isPlayableLink(raw) ? _normalizePlayUrl(raw) : null;
    sources.add(PlaySource(name: name, playPageUrl: playUrl));
    seenNames.add(name);
    final classSet = <String>{...el.classes, ...node.classes};
    if (classSet.contains('active') || classSet.contains('on') || classSet.contains('hl') || classSet.contains('current')) {
      activeIndex = sources.length - 1;
    }
  }

  const playlistSelectors = [
    '.playlist',
    '.play_list',
    '.play-list',
    '.playerlist',
    '.play-num',
    '.playNum',
    '.episode_list',
    '.playlists',
    '#playlist',
    '.play_list_box',
    '.play-episode',
  ];
  final playlists = <dom.Element>[];
  for (final selector in playlistSelectors) {
    playlists.addAll(doc.querySelectorAll(selector));
  }

  final sourceEpisodes = <String, List<EpisodeItem>>{};
  if (playlists.isNotEmpty) {
    if (sources.isEmpty) {
      final eps = _extractEpisodesFromContainer(playlists.first);
      if (eps.isNotEmpty) {
        sources.add(PlaySource(name: '默认线路'));
        sourceEpisodes['默认线路'] = eps;
        activeIndex = 0;
      }
    } else {
      final count = playlists.length < sources.length ? playlists.length : sources.length;
      for (var i = 0; i < count; i++) {
        final eps = _extractEpisodesFromContainer(playlists[i]);
        if (eps.isNotEmpty) {
          sourceEpisodes[sources[i].name] = eps;
        }
      }
    }
  }

  return _SourceEpisodeBundle(sources: sources, sourceEpisodes: sourceEpisodes, activeIndex: activeIndex);
}

List<EpisodeItem> _extractEpisodesFromContainer(dom.Element container) {
  final results = <EpisodeItem>[];
  final seen = <String>{};
  final links = container.querySelectorAll('a');
  for (final link in links) {
    final raw = _extractPlayLink(link);
    if (raw == null || !_isPlayableLink(raw)) continue;
    final url = _normalizePlayUrl(raw);
    if (seen.contains(url)) continue;
    final name = _extractEpisodeName(link);
    if (name == null || name.isEmpty) continue;
    if (name.contains('立即播放') && name.length <= 4) continue;
    seen.add(url);
    results.add(EpisodeItem(name: name, playUrl: url));
  }
  return results;
}

String? _extractPlayLink(dom.Element el) {
  const keys = ['data-url', 'data-play', 'data-href', 'data-src', 'href'];
  for (final key in keys) {
    final val = el.attributes[key];
    if (val == null || val.isEmpty) continue;
    final lower = val.toLowerCase().trim();
    if (lower == '#' || lower.startsWith('javascript') || lower.startsWith('void(')) {
      continue;
    }
    return val;
  }
  return null;
}

String? _extractEpisodeName(dom.Element el) {
  final text = el.text.trim();
  if (text.isNotEmpty) return text;
  final name = el.attributes['title'] ?? el.attributes['data-name'] ?? el.attributes['data-title'];
  return name?.trim();
}

String _normalizePlayUrl(String url) {
  final trimmed = url.trim();
  final decoded = _tryDecodePercent(trimmed);
  if (decoded.startsWith('http') || decoded.startsWith('//') || decoded.startsWith('/')) {
    return toAbsUrl(decoded);
  }
  return toAbsUrl(decoded);
}

bool _isPlayableLink(String url) {
  final lower = url.toLowerCase();
  return _looksLikeMediaUrl(lower) || lower.contains('/play/') || lower.contains('/player/');
}

bool _looksLikeMediaUrl(String url) {
  final lower = url.toLowerCase();
  return lower.contains('.m3u8') ||
      lower.contains('.mp4') ||
      lower.contains('.mkv') ||
      lower.contains('.flv') ||
      lower.contains('.mov') ||
      lower.contains('.avi') ||
      lower.contains('.m4v') ||
      lower.contains('.webm');
}

bool _isValidPlayPageUrl(String url) {
  final lower = url.trim().toLowerCase();
  if (lower.isEmpty) return false;
  if (lower == '#' || lower.startsWith('javascript') || lower.startsWith('void(')) return false;
  return true;
}


String? _extractField(String obj, String field) {

  final match = RegExp('"$field"\\s*:\\s*"(.*?)"|\'$field\'\\s*:\\s*\'(.*?)\'').firstMatch(obj);
  return match?.group(1) ?? match?.group(2);
}

String? _decodeUrl(String url, String? encrypt) {
  var value = url.replaceAll('\\/', '/');
  value = _tryDecodePercent(value);

  if (encrypt == '1') {
    value = _tryDecodePercent(value);
  } else if (encrypt == '2') {
    try {
      value = utf8.decode(base64.decode(value));
      value = _tryDecodePercent(value);
    } catch (_) {
      return null;
    }
  }

  value = value.trim();
  final idx = value.indexOf('http');
  if (idx != -1) {
    value = value.substring(idx);
  }
  if (value.startsWith('//')) {
    value = 'https:$value';
  }
  if (value.startsWith('http')) return value;
  return toAbsUrl(value);
}

String _tryDecodePercent(String input) {
  var out = input;
  for (var i = 0; i < 2; i++) {
    if (!out.contains('%')) break;
    try {
      out = Uri.decodeFull(out);
    } catch (_) {
      break;
    }
  }
  return out;
}




Map<String, String> _defaultHeaders([String? referer]) {
  final ref = referer == null || referer.isEmpty ? kBaseHost : referer;
  return {
    'User-Agent': 'Mozilla/5.0 (Linux; Android 10; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36',
    'Referer': ref,
    'Origin': kBaseHost,
    'Accept': '*/*',
    'Accept-Language': 'zh-CN,zh;q=0.9',
  };
}

Future<File> downloadToTemp(String url) async {
  final dir = await getTemporaryDirectory();
  final safeName = base64Url.encode(utf8.encode(url));
  final file = File('${dir.path}/cache_$safeName');
  if (await file.exists()) return file;
  final dio = createDio(headers: _defaultHeaders(url));
  await dio.download(url, file.path);
  return file;
}

Dio createDio({Map<String, String>? headers}) {
  final dio = Dio();
  if (headers != null) {
    dio.options.headers.addAll(headers);
  }
  final adapter = dio.httpClientAdapter;
  if (adapter is IOHttpClientAdapter) {
    adapter.createHttpClient = () {
      final client = HttpClient();
      client.badCertificateCallback = (cert, host, port) => true;
      return client;
    };
  }
  return dio;
}


class HlsSegment {

  HlsSegment({required this.remote, required this.file});
  final Uri remote;
  final File file;
}

class HlsProxyServer {
  HlsProxyServer._(this.server, this.cacheDir, this.indexUrl, this._headers)
      : _dio = createDio(headers: _headers);

  final HttpServer server;
  final Directory cacheDir;
  final String indexUrl;
  final Map<String, String> _headers;
  final Dio _dio;


  final Map<String, HlsSegment> _segments = {};
  final Map<String, Uri> _playlists = {};
  final Map<String, String> _playlistContent = {};
  bool _prefetching = false;
  int _segCounter = 0;
  int _playlistCounter = 0;

  static Future<HlsProxyServer> start(String url, {Map<String, String>? headers}) async {
    final tempDir = await getTemporaryDirectory();
    final safeName = base64Url.encode(utf8.encode(url));
    final cacheDir = Directory('${tempDir.path}/hls_$safeName');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }

    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final headerMap = headers ?? _defaultHeaders(url);
    final proxy = HlsProxyServer._(server, cacheDir, 'http://127.0.0.1:${server.port}/index.m3u8', headerMap);
    await proxy._buildPlaylist(url, key: 'index');
    proxy._listen();
    proxy._prefetchSegments();
    return proxy;
  }


  void _listen() {
    server.listen((request) async {
      final path = request.uri.path;
      if (path == '/' || path.endsWith('index.m3u8')) {
        await _respondPlaylist(request, 'index');
        return;
      }
      if (path.startsWith('/p/')) {
        final name = request.uri.pathSegments.last;
        final id = name.replaceAll('.m3u8', '');
        await _respondPlaylist(request, id);
        return;
      }
      if (path.startsWith('/s/')) {
        final name = request.uri.pathSegments.last;
        final id = name.split('.').first;
        await _respondSegment(request, id);
        return;
      }
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
    });
  }

  Future<void> _respondPlaylist(HttpRequest request, String key) async {
    try {
      if (!_playlistContent.containsKey(key)) {
        final remote = _playlists[key];
        if (remote == null) {
          request.response.statusCode = HttpStatus.notFound;
          await request.response.close();
          return;
        }
        await _buildPlaylist(remote.toString(), key: key);
        _prefetchSegments();
      }
      request.response.headers.contentType = ContentType('application', 'vnd.apple.mpegurl');
      request.response.write(_playlistContent[key]);
      await request.response.close();
    } catch (_) {
      request.response.statusCode = HttpStatus.internalServerError;
      await request.response.close();
    }
  }

  Future<void> _respondSegment(HttpRequest request, String id) async {
    final seg = _segments[id];
    if (seg == null) {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }
    try {
      if (!await seg.file.exists()) {
        await _dio.download(
          seg.remote.toString(),
          seg.file.path,
          options: Options(headers: {..._headers, 'Referer': seg.remote.toString()}),
        );
      }
      request.response.headers.contentType = ContentType.binary;
      await request.response.addStream(seg.file.openRead());
      await request.response.close();
    } catch (_) {
      request.response.statusCode = HttpStatus.internalServerError;
      await request.response.close();
    }
  }

  Future<void> _buildPlaylist(String url, {required String key}) async {
    final resp = await _dio.get<String>(
      url,
      options: Options(
        responseType: ResponseType.plain,
        headers: {..._headers, 'Referer': url},
      ),
    );
    final content = resp.data ?? '';
    if (content.isEmpty) throw Exception('HLS 清单为空');


    final baseUri = Uri.parse(url);
    final lines = LineSplitter.split(content).toList();
    final List<String> outputLines = [];

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) {
        outputLines.add(line);
        continue;
      }
      final resolved = baseUri.resolve(trimmed);
      final isPlaylist = resolved.path.toLowerCase().endsWith('.m3u8');
      if (isPlaylist) {
        final id = 'p${_playlistCounter.toString().padLeft(5, '0')}';
        _playlistCounter++;
        _playlists[id] = resolved;
        outputLines.add('http://127.0.0.1:${server.port}/p/$id.m3u8');
      } else {
        final ext = resolved.pathSegments.isNotEmpty && resolved.pathSegments.last.contains('.')
            ? resolved.pathSegments.last.split('.').last
            : 'ts';
        final id = 's${_segCounter.toString().padLeft(6, '0')}';
        _segCounter++;
        final file = File('${cacheDir.path}/$id.$ext');
        _segments[id] = HlsSegment(remote: resolved, file: file);
        outputLines.add('http://127.0.0.1:${server.port}/s/$id.$ext');
      }
    }

    _playlistContent[key] = outputLines.join('\n');
  }

  Future<void> _prefetchSegments() async {
    if (_prefetching) return;
    _prefetching = true;
    try {
      for (final seg in _segments.values) {
        if (!await seg.file.exists()) {
          await _dio.download(
            seg.remote.toString(),
            seg.file.path,
            options: Options(headers: {..._headers, 'Referer': seg.remote.toString()}),
          );
        }
      }
    } finally {
      _prefetching = false;
    }
  }


  Future<void> close() async {
    await server.close(force: true);
  }
}
