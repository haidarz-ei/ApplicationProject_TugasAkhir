import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app/data/models/ai_evaluation_model.dart';

/// Repository untuk tabel ai_evaluations di Supabase.
class AIEvaluationRepository {
  final SupabaseClient _client;
  static const String _tableName = 'ai_evaluations';

  AIEvaluationRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  /// Simpan hasil evaluasi AI.
  Future<AIEvaluationModel> saveEvaluation({
    required String userId,
    required String section,
    required String answer,
    required String feedback,
    required double score,
  }) async {
    final response = await _client
        .from(_tableName)
        .insert({
          'user_id': userId,
          'section': section,
          'answer': answer,
          'feedback': feedback,
          'nilai_ketepatan': score,
          'created_at': DateTime.now().toIso8601String(),
        })
        .select()
        .single();

    return AIEvaluationModel.fromJson(Map<String, dynamic>.from(response));
  }

  /// Ambil riwayat evaluasi untuk section tertentu.
  Future<List<AIEvaluationModel>> getHistory(String userId, String section) async {
    final response = await _client
        .from(_tableName)
        .select()
        .eq('user_id', userId)
        .eq('section', section)
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => AIEvaluationModel.fromJson(Map<String, dynamic>.from(json as Map)))
        .toList();
  }
}
