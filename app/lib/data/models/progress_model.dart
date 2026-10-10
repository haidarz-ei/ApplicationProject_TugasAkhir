/// Model untuk satu record di tabel progress Supabase.
class ProgressModel {
  final int? id;
  final String userId;
  final String section;
  final String phase;
  final int level;
  final DateTime? updatedAt;

  const ProgressModel({
    this.id,
    required this.userId,
    required this.section,
    required this.phase,
    this.level = 1,
    this.updatedAt,
  });

  factory ProgressModel.fromJson(Map<String, dynamic> json) {
    return ProgressModel(
      id: json['id'] as int?,
      userId: json['user_id']?.toString() ?? '',
      section: json['section']?.toString() ?? '',
      phase: json['phase']?.toString() ?? '',
      level: (json['level'] as num?)?.toInt() ?? 1,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'section': section,
      'phase': phase,
      'level': level,
      'updated_at': (updatedAt ?? DateTime.now()).toIso8601String(),
    };
  }

  ProgressModel copyWith({
    int? id,
    String? userId,
    String? section,
    String? phase,
    int? level,
    DateTime? updatedAt,
  }) {
    return ProgressModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      section: section ?? this.section,
      phase: phase ?? this.phase,
      level: level ?? this.level,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
