class NewbornVideo {
  final String id;
  final String category;
  final String platform;
  final String videoId;
  final String embedUrl;
  final String? title;
  final int orderIndex;
  final DateTime? createdAt;

  const NewbornVideo({
    required this.id,
    required this.category,
    required this.platform,
    required this.videoId,
    required this.embedUrl,
    this.title,
    this.orderIndex = 0,
    this.createdAt,
  });

  factory NewbornVideo.fromMap(Map<String, dynamic> map) {
    final rawPlatform = (map['platform'] as String? ?? 'youtube').toLowerCase().trim();
    final rawVideoId = (map['video_id'] as String? ?? '').trim();
    final rawEmbedUrl = (map['embed_url'] as String? ?? '').trim();

    // Parsing otomatis agar user bisa input link biasa maupun ID
    final parsed = _parseVideoInfo(
      platform: rawPlatform,
      videoId: rawVideoId,
      rawUrl: rawEmbedUrl,
    );

    return NewbornVideo(
      id: map['id'] as String? ?? '',
      category: map['category'] as String? ?? '',
      platform: parsed['platform'] ?? rawPlatform,
      videoId: parsed['videoId'] ?? rawVideoId,
      embedUrl: parsed['embedUrl'] ?? rawEmbedUrl,
      title: map['title'] as String?,
      orderIndex: (map['order_index'] as num?)?.toInt() ?? 0,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'category': category,
      'platform': platform,
      'video_id': videoId,
      'embed_url': embedUrl,
      'title': title,
      'order_index': orderIndex,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }

  /// Helper untuk mengekstrak ID dan mengubah link biasa menjadi URL Embed resmi
  static Map<String, String> _parseVideoInfo({
    required String platform,
    required String videoId,
    required String rawUrl,
  }) {
    String detectedPlatform = platform;
    String cleanId = videoId;
    String targetUrl = rawUrl;

    // Jika targetUrl berisi tag <iframe>, ambil URL di dalam src="..."
    if (targetUrl.contains('<iframe') && targetUrl.contains('src="')) {
      final match = RegExp(r'src="([^"]+)"').firstMatch(targetUrl);
      if (match != null) {
        targetUrl = match.group(1)!;
      }
    }

    final combinedText = '$cleanId $targetUrl';

    // Deteksi Platform otomatis
    if (combinedText.contains('tiktok.com')) {
      detectedPlatform = 'tiktok';
    } else if (combinedText.contains('youtube.com') ||
        combinedText.contains('youtu.be')) {
      detectedPlatform = 'youtube';
    }

    if (detectedPlatform == 'tiktok') {
      // 1. Ekstrak ID TikTok dari URL jika ada
      if (cleanId.isEmpty || cleanId.contains('http')) {
        final urlToParse = targetUrl.isNotEmpty ? targetUrl : cleanId;
        final match = RegExp(r'(?:video/|embed/v2/|embed/|v2/)(\d+)').firstMatch(urlToParse);
        if (match != null) {
          cleanId = match.group(1)!;
        }
      }

      // Jika ada ID angka bersih, buat format embed resmi
      if (cleanId.isNotEmpty && RegExp(r'^\d+$').hasMatch(cleanId)) {
        targetUrl = 'https://www.tiktok.com/embed/v2/$cleanId';
      } else if (targetUrl.isEmpty && cleanId.isNotEmpty) {
        targetUrl = cleanId.startsWith('http')
            ? cleanId
            : 'https://www.tiktok.com/embed/v2/$cleanId';
      }
    } else {
      // YouTube
      detectedPlatform = 'youtube';

      // 2. Ekstrak ID YouTube dari berbagai format URL
      if (cleanId.isEmpty || cleanId.contains('http')) {
        final urlToParse = targetUrl.isNotEmpty ? targetUrl : cleanId;
        
        final vMatch = RegExp(r'[?&]v=([a-zA-Z0-9_-]+)').firstMatch(urlToParse);
        final shortMatch = RegExp(r'youtu\.be/([a-zA-Z0-9_-]+)').firstMatch(urlToParse);
        final shortsMatch = RegExp(r'shorts/([a-zA-Z0-9_-]+)').firstMatch(urlToParse);
        final embedMatch = RegExp(r'embed/([a-zA-Z0-9_-]+)').firstMatch(urlToParse);

        if (vMatch != null) {
          cleanId = vMatch.group(1)!;
        } else if (shortMatch != null) {
          cleanId = shortMatch.group(1)!;
        } else if (shortsMatch != null) {
          cleanId = shortsMatch.group(1)!;
        } else if (embedMatch != null) {
          cleanId = embedMatch.group(1)!;
        }
      }

      if (cleanId.isNotEmpty && !cleanId.startsWith('http')) {
        targetUrl = 'https://www.youtube.com/embed/$cleanId?autoplay=1&playsinline=1';
      } else if (targetUrl.isEmpty && cleanId.isNotEmpty) {
        targetUrl = cleanId;
      }
    }

    return {
      'platform': detectedPlatform,
      'videoId': cleanId,
      'embedUrl': targetUrl,
    };
  }
}
