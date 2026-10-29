import 'models.dart' show Json;

/// One turn of a 深度分析 (v10.0.0): what the master said, its question, and the answer once given.
class InquiryTurnView {
  const InquiryTurnView({required this.say, required this.question, this.answer});

  factory InquiryTurnView.fromJson(Json j) => InquiryTurnView(
        say: j['say'] as String? ?? '',
        question: j['question'] as String? ?? '',
        answer: j['answer'] as String?,
      );

  final String say;
  final String question;
  final String? answer;
}

/// A 深度分析 (`GET /v1/inquiries/<id>`, v10.0.0): the master's questions on a chart before its reading.
class InquiryView {
  const InquiryView({
    required this.id,
    required this.chartId,
    required this.status,
    required this.goal,
    required this.maxQuestions,
    required this.turns,
    this.planned,
    this.closing,
    this.understanding,
    this.reportId,
    this.message,
  });

  factory InquiryView.fromJson(Json j) => InquiryView(
        id: j['inquiry_id'] as String,
        chartId: j['chart_id'] as String,
        status: j['status'] as String,
        goal: j['goal'] as String? ?? '',
        maxQuestions: j['max_questions'] as int? ?? 6,
        planned: j['planned'] as int?,
        turns: ((j['turns'] as List?) ?? const []).cast<Json>().map(InquiryTurnView.fromJson).toList(),
        closing: j['closing'] as String?,
        understanding: j['understanding'] as String?,
        reportId: j['report_id'] as String?,
        message: j['message'] as String?,
      );

  final String id;
  final String chartId;

  /// thinking | asking | ready | failed | closed
  final String status;
  final String goal;
  final int maxQuestions;

  /// How many questions the master plans (1–6), once it has asked its first.
  final int? planned;
  final List<InquiryTurnView> turns;

  /// The master's last words, once it asks nothing more.
  final String? closing;

  /// What the master understood the user most wants to know, once it asks nothing more.
  final String? understanding;

  /// The reading made from it.
  final String? reportId;
  final String? message;

  bool get thinking => status == 'thinking';

  /// A question waits for its answer.
  bool get asking => status == 'asking';

  /// The master asks nothing more: the final reading can start.
  bool get ready => status == 'ready';
  bool get failed => status == 'failed';

  /// The answered turns.
  List<InquiryTurnView> get answered => turns.where((t) => t.answer != null).toList();

  /// The question waiting for an answer, while [asking].
  InquiryTurnView? get open => asking && turns.isNotEmpty && turns.last.answer == null ? turns.last : null;
}
