import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'newborn_video_model.dart';

class NewbornEmbedPlayer extends StatefulWidget {
  final NewbornVideo video;
  final bool isActive;

  const NewbornEmbedPlayer({
    super.key,
    required this.video,
    this.isActive = true,
  });

  @override
  State<NewbornEmbedPlayer> createState() => _NewbornEmbedPlayerState();
}

class _NewbornEmbedPlayerState extends State<NewbornEmbedPlayer> {
  late final WebViewController _controller;
  bool _isLoading = !kIsWeb;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  @override
  void didUpdateWidget(covariant NewbornEmbedPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive != widget.isActive ||
        oldWidget.video.id != widget.video.id ||
        oldWidget.video.embedUrl != widget.video.embedUrl) {
      if (widget.isActive) {
        _loadVideo();
      } else {
        _unloadVideo();
      }
    }
  }

  void _initWebView() {
    _controller = WebViewController();

    if (!kIsWeb) {
      try {
        _controller
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setBackgroundColor(const Color(0xFF000000))
          ..setUserAgent(
              'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36');

        if (_controller.platform is AndroidWebViewController) {
          (_controller.platform as AndroidWebViewController)
              .setMediaPlaybackRequiresUserGesture(false);
        }
      } catch (_) {}

      try {
        _controller.setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (String url) {
              if (mounted) setState(() => _isLoading = true);
            },
            onPageFinished: (String url) {
              if (mounted) setState(() => _isLoading = false);
            },
            onWebResourceError: (WebResourceError error) {
              if (mounted && error.isForMainFrame == true) {
                setState(() {
                  _isLoading = false;
                  _errorMessage = 'Gagal memuat video.\nPeriksa koneksi internet Anda.';
                });
              }
            },
            onNavigationRequest: (NavigationRequest request) {
              final url = request.url;
              final uri = Uri.tryParse(url);
              if (uri != null) {
                if (uri.scheme != 'http' && uri.scheme != 'https' && uri.scheme != 'about') {
                  launchUrl(uri, mode: LaunchMode.externalApplication).ignore();
                  return NavigationDecision.prevent;
                }
                if (url.contains('tiktok.com/@') || url.contains('tiktok.com/video') || url.contains('tiktok.com/tag')) {
                  return NavigationDecision.prevent;
                }
              }
              return NavigationDecision.navigate;
            },
          ),
        );
      } catch (_) {}
    }

    if (widget.isActive) {
      _loadVideo();
    } else {
      _unloadVideo();
    }
  }

  void _unloadVideo() {
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _errorMessage = null;
    });
    try {
      _controller.loadHtmlString('<!DOCTYPE html><html><body style="background:#000;"></body></html>');
    } catch (_) {}
  }

  void _loadVideo() {
    if (!widget.isActive) return;
    setState(() {
      _isLoading = !kIsWeb;
      _errorMessage = null;
    });

    if (!kIsWeb) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && _isLoading) {
          setState(() => _isLoading = false);
        }
      });
    }

    final url = widget.video.embedUrl;
    if (url.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'URL video tidak valid.';
      });
      return;
    }

    try {
      if (widget.video.platform == 'tiktok') {
        final videoId = widget.video.videoId;
        final embedSrc = videoId.isNotEmpty
            ? 'https://www.tiktok.com/embed/v2/$videoId'
            : url;

        // CSS crop: iframe 150% tinggi, overflow hidden potong caption bawah
        final html = '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body, html { width: 100%; height: 100%; overflow: hidden; background: #000; }
    .crop { position: absolute; top: 0; left: 0; width: 100%; height: 100%; overflow: hidden; }
    .crop iframe { position: absolute; top: 0; left: 0; width: 100%; height: 150%; border: 0; }
  </style>
</head>
<body>
  <div class="crop">
    <iframe src="$embedSrc" allow="autoplay; encrypted-media; fullscreen" allowfullscreen></iframe>
  </div>
</body>
</html>
''';
        _controller.loadHtmlString(html, baseUrl: 'https://www.tiktok.com');
      } else {
        // YouTube Embed
        final videoId = widget.video.videoId;
        final embedSrc = videoId.isNotEmpty
            ? 'https://www.youtube-nocookie.com/embed/$videoId?autoplay=1&mute=0&playsinline=1&rel=0&controls=1'
            : url;

        final html = '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body, html { width: 100%; height: 100%; overflow: hidden; background: #000; }
    iframe { position: absolute; top: 0; left: 0; width: 100%; height: 100%; border: 0; }
  </style>
</head>
<body>
  <iframe src="$embedSrc" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture" allowfullscreen></iframe>
</body>
</html>
''';
        _controller.loadHtmlString(html, baseUrl: 'https://www.youtube.com');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Format link embed tidak dapat dibuka.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0F172A),
      child: Stack(
        children: [
          Positioned.fill(
            child: WebViewWidget(controller: _controller),
          ),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(color: Colors.amber),
            ),
          if (_errorMessage != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.wifi_off_rounded, color: Colors.redAccent, size: 40),
                    const SizedBox(height: 12),
                    Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton.icon(
                      onPressed: _loadVideo,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Coba Lagi'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
                        foregroundColor: Colors.black87,
                      ),
                    ),
                    if (widget.video.platform == 'tiktok') ...[
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: () {
                          final videoId = widget.video.videoId;
                          final tiktokUrl = videoId.isNotEmpty
                              ? 'https://www.tiktok.com/video/$videoId'
                              : widget.video.embedUrl;
                          final uri = Uri.tryParse(tiktokUrl);
                          if (uri != null) {
                            launchUrl(uri, mode: LaunchMode.externalApplication);
                          }
                        },
                        icon: const Icon(Icons.open_in_new_rounded, size: 16),
                        label: const Text('Buka di TikTok'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.cyanAccent,
                          side: const BorderSide(color: Colors.cyanAccent),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
