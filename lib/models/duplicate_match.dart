import 'report_model.dart';

class DuplicateMatch {
  const DuplicateMatch({required this.report, required this.confidence});

  final ReportModel report;
  final double confidence;
}
