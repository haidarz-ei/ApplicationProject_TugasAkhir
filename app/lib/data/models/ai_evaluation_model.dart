/// Model untuk hasil evaluasi AI di tabel ai_evaluations Supabase.
class AIEvaluationModel {
  final int? id;
  final String userId;
  final String section;
  final double nilaiKetepatan;
  final String? answer;
  final String? feedback;
  final DateTime? createdAt;

  const AIEvaluationModel({
    this.id,
    required this.userId,
    required this.section,
    required this.nilaiKetepatan,
    this.answer,
    this.feedback,
    this.createdAt,
  });

  factory AIEvaluationModel.fromJson(Map<String, dynamic> json) {
    return AIEvaluationModel(
      id: json['id'] as int?,
      userId: json['user_id']?.toString() ?? '',
      section: json['section']?.toString() ?? '',
      nilaiKetepatan: (json['nilai_ketepatan'] as num?)?.toDouble() ?? 0.0,
      answer: json['answer']?.toString(),
      feedback: json['feedback']?.toString(),
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'section': section,
      'nilai_ketepatan': nilaiKetepatan,
      if (answer != null) 'answer': answer,
      if (feedback != null) 'feedback': feedback,
      'created_at': (createdAt ?? DateTime.now()).toIso8601String(),
    };
  }
}
