import 'dart:convert';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:google_fonts/google_fonts.dart';

const String kBaseHost = 'https://www.jkan.app';
const String kDefaultListUrl = 'https://www.jkan.app/show/1--------1---.html';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
      title: '即看影视',
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
    _loadPage(_currentUrl);
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
        _error = '加载失败：$e';
        _loading = false;
      });
    }
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

    return Scaffold(
      body: Stack(
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
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Row(
        children: [
          const Text(
            '即看影视',
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
  bool _loading = true;
  String? _error;
  File? _cachedFile;
  Directory? _cacheDir;
  HlsProxyServer? _proxyServer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initPlayer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    _deleteCache();
    super.dispose();
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
      final playUrl = await fetchPlayUrl(widget.item.detailUrl);
      if (playUrl == null) {
        throw Exception('未解析到播放地址');
      }
      final isHls = playUrl.toLowerCase().contains('.m3u8');
      if (isHls) {
        _proxyServer = await HlsProxyServer.start(playUrl);
        _cacheDir = _proxyServer!.cacheDir;
      } else {
        _cachedFile = await downloadToTemp(playUrl);
      }
      final controller = _cachedFile != null
          ? VideoPlayerController.file(_cachedFile!)
          : VideoPlayerController.networkUrl(
              Uri.parse(isHls ? _proxyServer!.indexUrl : playUrl),
            );
      await controller.initialize();
      await controller.play();
      if (!mounted) return;
      setState(() {
        _controller = controller;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '播放失败：$e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(widget.item.title),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                )
              : _controller == null
                  ? const Center(child: Text('播放器未就绪'))
                  : Column(
                      children: [
                        AspectRatio(
                          aspectRatio: _controller!.value.aspectRatio,
                          child: VideoPlayer(_controller!),
                        ),
                        const SizedBox(height: 12),
                        VideoProgressIndicator(
                          _controller!,
                          allowScrubbing: true,
                          colors: const VideoProgressColors(
                            playedColor: Color(0xFFF06292),
                            bufferedColor: Colors.white24,
                            backgroundColor: Colors.white12,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: Icon(
                                _controller!.value.isPlaying
                                    ? Icons.pause_circle_filled
                                    : Icons.play_circle_fill,
                                color: Colors.white,
                                size: 48,
                              ),
                              onPressed: () async {
                                if (_controller!.value.isPlaying) {
                                  await _controller!.pause();
                                } else {
                                  await _controller!.play();
                                }
                                setState(() {});
                              },
                            ),
                          ],
                        ),
                      ],
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

Future<PageData> fetchPage(String url) async {
  final resp = await http.get(Uri.parse(url));
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

Future<String?> fetchPlayUrl(String detailUrl) async {
  final resp = await http.get(Uri.parse(detailUrl));
  if (resp.statusCode != 200) return null;
  final html = resp.body;
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

  final videoMatch = RegExp(r'https?:\\/\\/[^\s\"\']+\.(m3u8|mp4|mkv|flv|mov)', caseSensitive: false).firstMatch(html);
  if (videoMatch != null) return videoMatch.group(0);

  return null;
}

String? _extractField(String obj, String field) {
  final match = RegExp('"$field"\\s*:\\s*"(.*?)"|\'$field\'\\s*:\\s*\'(.*?)\'').firstMatch(obj);
  return match?.group(1) ?? match?.group(2);
}

String? _decodeUrl(String url, String? encrypt) {
  var value = url.replaceAll('\\/', '/');
  if (encrypt == '1') {
    value = Uri.decodeFull(value);
  } else if (encrypt == '2') {
    try {
      value = utf8.decode(base64.decode(value));
    } catch (_) {
      return null;
    }
  }
  if (value.startsWith('http')) return value;
  return toAbsUrl(value);
}

Future<File> downloadToTemp(String url) async {
  final dir = await getTemporaryDirectory();
  final safeName = base64Url.encode(utf8.encode(url));
  final file = File('${dir.path}/cache_$safeName');
  if (await file.exists()) return file;
  final dio = Dio();
  await dio.download(url, file.path);
  return file;
}

class HlsSegment {
  HlsSegment({required this.remote, required this.file});
  final Uri remote;
  final File file;
}

class HlsProxyServer {
  HlsProxyServer._(this.server, this.cacheDir, this.indexUrl);

  final HttpServer server;
  final Directory cacheDir;
  final String indexUrl;
  final Dio _dio = Dio();
  final Map<String, HlsSegment> _segments = {};
  final Map<String, Uri> _playlists = {};
  final Map<String, String> _playlistContent = {};
  bool _prefetching = false;
  int _segCounter = 0;
  int _playlistCounter = 0;

  static Future<HlsProxyServer> start(String url) async {
    final tempDir = await getTemporaryDirectory();
    final safeName = base64Url.encode(utf8.encode(url));
    final cacheDir = Directory('${tempDir.path}/hls_$safeName');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }

    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final proxy = HlsProxyServer._(server, cacheDir, 'http://127.0.0.1:${server.port}/index.m3u8');
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
        await _dio.download(seg.remote.toString(), seg.file.path);
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
    final resp = await _dio.get<String>(url, options: Options(responseType: ResponseType.plain));
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
          await _dio.download(seg.remote.toString(), seg.file.path);
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
