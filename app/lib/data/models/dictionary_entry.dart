/// Model untuk satu entry di tabel dictionary Supabase.
class DictionaryEntry {
  final int id;
  final String word;
  final String pos;
  final String definitionEn;
  final String definitionId;
  final String v1;
  final String v2;
  final String v3;

  const DictionaryEntry({
    required this.id,
    required this.word,
    required this.pos,
    required this.definitionEn,
    required this.definitionId,
    this.v1 = '',
    this.v2 = '',
    this.v3 = '',
  });

  /// Factory constructor dari JSON (row Supabase).
  factory DictionaryEntry.fromJson(Map<String, dynamic> json) {
    return DictionaryEntry(
      id: json['id'] as int,
      word: json['word'] as String? ?? '',
      pos: json['pos'] as String? ?? '',
      definitionEn: json['definition_en'] as String? ?? '',
      definitionId: json['definition_id'] as String? ?? '',
      v1: json['v1'] as String? ?? '',
      v2: json['v2'] as String? ?? '',
      v3: json['v3'] as String? ?? '',
    );
  }

  /// Konversi ke Map (untuk insert/update jika diperlukan nanti).
  Map<String, dynamic> toJson() {
    return {
      'word': word,
      'pos': pos,
      'definition_en': definitionEn,
      'definition_id': definitionId,
      'v1': v1,
      'v2': v2,
      'v3': v3,
    };
  }

  /// Apakah entry ini adalah verb (punya data v1/v2/v3).
  bool get isVerb => pos == 'verb';

  /// 3 bentuk kata kerja (V1 • V2 • V3)
  String get verbForms {
    final form1 = v1.isNotEmpty ? v1 : word;
    final form2 = v2.isNotEmpty ? v2 : '${word}ed';
    final form3 = v3.isNotEmpty ? v3 : form2;
    return '$form1 • $form2 • $form3';
  }

  /// Apakah entry ini irregular verb (v2 bukan sekedar word + "ed"/"d").
  bool get isIrregularVerb => isVerb && v2.isNotEmpty && v2 != '${word}ed' && v2 != '${word}d';

  @override
  String toString() => 'DictionaryEntry(word: $word, pos: $pos)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DictionaryEntry && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
