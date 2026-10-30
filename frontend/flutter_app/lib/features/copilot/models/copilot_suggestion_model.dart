class CopilotSuggestionModel {
  final String id;
  final String category;
  final String question;

  const CopilotSuggestionModel({
    required this.id,
    required this.category,
    required this.question,
  });

  factory CopilotSuggestionModel.fromJson(Map<String, dynamic> json) {
    return CopilotSuggestionModel(
      id: json['id'] as String? ?? '',
      category: json['category'] as String? ?? 'GENERAL',
      question: json['question'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'category': category,
      'question': question,
    };
  }
}

