/// Model untuk satu entry di tabel journals Supabase.
class JournalEntry {
  final int? id;
  final int? remoteId;
  final String title;
  final String story;
  final String imageUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool isSynced;

  const JournalEntry({
    this.id,
    this.remoteId,
    required this.title,
    required this.story,
    this.imageUrl = '',
    this.createdAt,
    this.updatedAt,
    this.isSynced = true,
  });

  /// Factory constructor dari JSON (row Supabase atau SQLite).
  factory JournalEntry.fromJson(Map<dynamic, dynamic> json) {
    final rawId = json['id'];
    int? parsedId;
    if (rawId is int) {
      parsedId = rawId;
    } else if (rawId is num) {
      parsedId = rawId.toInt();
    } else if (rawId != null) {
      parsedId = int.tryParse(rawId.toString());
    }

    final rawRemoteId = json['remote_id'];
    int? parsedRemoteId;
    if (rawRemoteId is int) {
      parsedRemoteId = rawRemoteId;
    } else if (rawRemoteId is num) {
      parsedRemoteId = rawRemoteId.toInt();
    } else if (rawRemoteId != null) {
      parsedRemoteId = int.tryParse(rawRemoteId.toString());
    }

    final rawSynced = json['is_synced'];
    final bool synced = rawSynced == null || rawSynced == 1 || rawSynced == true || rawSynced == '1';

    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is DateTime) return value;
      return DateTime.tryParse(value.toString());
    }

    return JournalEntry(
      id: parsedId,
      remoteId: parsedRemoteId,
      title: json['title']?.toString() ?? '',
      story: json['story']?.toString() ?? '',
      imageUrl: json['image_url']?.toString() ?? '',
      createdAt: parseDate(json['created_at']),
      updatedAt: parseDate(json['updated_at']),
      isSynced: synced,
    );
  }

  /// Konversi ke Map untuk insert.
  Map<String, dynamic> toInsertJson() {
    return {
      'title': title,
      'story': story,
      'image_url': imageUrl,
    };
  }

  /// Konversi ke Map untuk update.
  Map<String, dynamic> toUpdateJson() {
    return {
      'title': title,
      'story': story,
      'image_url': imageUrl,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  /// Tanggal yang diformat untuk tampilan (contoh: "May 20, 2024").
  String get formattedDate {
    final date = updatedAt ?? createdAt ?? DateTime.now();
    final months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final month = months[date.month];
    return '$month ${date.day}, ${date.year}';
  }

  /// Preview cerita (max 100 karakter).
  String get storyPreview {
    final trimmed = story.trim();
    if (trimmed.length <= 100) return trimmed;
    return '${trimmed.substring(0, 100)}...';
  }

  /// Jumlah kata di story.
  int get wordCount {
    final trimmed = story.trim();
    if (trimmed.isEmpty) return 0;
    return trimmed.split(RegExp(r'\s+')).length;
  }

  @override
  String toString() => 'JournalEntry(id: $id, title: $title)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is JournalEntry && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
