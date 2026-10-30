class CopilotResponseModel {
  final String answer;
  final String periodAnalyzed;
  final List<String> dataUsed;
  final String? calculationDefinition;
  final List<String> caveats;
  final String recommendedNextStep;
  final String dataFreshness;
  final bool isAvailable;
  final Map<String, dynamic>? deterministicFigures;

  const CopilotResponseModel({
    required this.answer,
    required this.periodAnalyzed,
    required this.dataUsed,
    this.calculationDefinition,
    required this.caveats,
    required this.recommendedNextStep,
    required this.dataFreshness,
    required this.isAvailable,
    this.deterministicFigures,
  });

  factory CopilotResponseModel.fromJson(Map<String, dynamic> json) {
    return CopilotResponseModel(
      answer: json['answer'] as String? ?? '',
      periodAnalyzed: json['periodAnalyzed'] as String? ?? 'N/A',
      dataUsed: (json['dataUsed'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      calculationDefinition: json['calculationDefinition'] as String?,
      caveats: (json['caveats'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      recommendedNextStep: json['recommendedNextStep'] as String? ?? '',
      dataFreshness: json['dataFreshness'] as String? ?? '',
      isAvailable: json['isAvailable'] as bool? ?? false,
      deterministicFigures: json['deterministicFigures'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'answer': answer,
      'periodAnalyzed': periodAnalyzed,
      'dataUsed': dataUsed,
      'calculationDefinition': calculationDefinition,
      'caveats': caveats,
      'recommendedNextStep': recommendedNextStep,
      'dataFreshness': dataFreshness,
      'isAvailable': isAvailable,
      'deterministicFigures': deterministicFigures,
    };
  }
}

