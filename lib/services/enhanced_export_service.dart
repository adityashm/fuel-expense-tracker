// ignore_for_file: cascade_invocations

import 'dart:io';
import 'dart:math' as math;

import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import 'advanced_analytics_service.dart';
import 'database_service.dart';

/// Enhanced export service for generating PDF and Excel reports with charts
class EnhancedExportService {
  EnhancedExportService._internal() {
    _databaseService = DatabaseService.instance;
    _analyticsService = AdvancedAnalyticsService.instance;
  }

  factory EnhancedExportService() {
    return _instance;
  }
  static final EnhancedExportService _instance =
      EnhancedExportService._internal();
  late final DatabaseService _databaseService;
  late final AdvancedAnalyticsService _analyticsService;

  static EnhancedExportService get instance => _instance;

  /// Export household expenses to PDF with charts
  Future<File> exportHouseholdToPDF({
    required int householdId,
    required String householdName,
    required DateTime startDate,
    required DateTime endDate,
    bool includeCharts = true,
    bool includeInsights = true,
  }) async {
    final pdf = pw.Document();

    // Get data
    final expenses =
        await _getHouseholdExpenses(householdId, startDate, endDate);
    final patterns = await _analyticsService.getMemberSpendingPatterns(
      householdId,
      startDate: startDate,
      endDate: endDate,
    );
    final insights = await _analyticsService.getCategoryInsights(
      householdId,
      startDate: startDate,
      endDate: endDate,
    );

    // Page 1: Cover and Summary
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Header
            pw.Container(
              padding: const pw.EdgeInsets.all(20),
              decoration: pw.BoxDecoration(
                color: PdfColors.blue700,
                borderRadius: pw.BorderRadius.circular(10),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Expense Report',
                    style: pw.TextStyle(
                      fontSize: 28,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    householdName,
                    style: const pw.TextStyle(
                      fontSize: 18,
                      color: PdfColors.white,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    '${_formatDate(startDate)} to ${_formatDate(endDate)}',
                    style: const pw.TextStyle(
                      fontSize: 14,
                      color: PdfColors.white,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 30),

            // Summary Cards
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryCard(
                  'Total Expenses',
                  '₹${patterns.totalAmount.toStringAsFixed(2)}',
                  PdfColors.blue,
                ),
                _buildSummaryCard(
                  'Transactions',
                  patterns.transactionCount.toString(),
                  PdfColors.green,
                ),
                _buildSummaryCard(
                  'Average',
                  '₹${patterns.averageTransaction.toStringAsFixed(2)}',
                  PdfColors.orange,
                ),
              ],
            ),
            pw.SizedBox(height: 30),

            // Top Categories
            pw.Text(
              'Top Spending Categories',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 10),
            ...insights.take(5).map(
                  (insight) => pw.Container(
                    margin: const pw.EdgeInsets.only(bottom: 8),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(insight.category),
                        pw.Row(
                          children: [
                            pw.Text(
                              '₹${insight.totalAmount.toStringAsFixed(2)}',
                              style:
                                  pw.TextStyle(fontWeight: pw.FontWeight.bold),
                            ),
                            pw.SizedBox(width: 10),
                            pw.Container(
                              padding: const pw.EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4,),
                              decoration: pw.BoxDecoration(
                                color: _getTrendColor(insight.trend),
                                borderRadius: pw.BorderRadius.circular(4),
                              ),
                              child: pw.Text(
                                insight.trend,
                                style: const pw.TextStyle(
                                    fontSize: 10, color: PdfColors.white,),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
          ],
        ),
      ),
    );

    // Page 2: Charts
    if (includeCharts && patterns.categorySpending.isNotEmpty) {
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Spending Distribution',
                style:
                    pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 20),

              // Category pie chart
              pw.Container(
                height: 250,
                child: _buildPieChart(patterns.categorySpending),
              ),
              pw.SizedBox(height: 30),

              // Day of week bar chart
              pw.Text(
                'Spending by Day of Week',
                style:
                    pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 10),
              pw.Container(
                height: 150,
                child: _buildBarChart(
                  patterns.dayOfWeekSpending,
                  ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Page 3: Insights
    if (includeInsights) {
      final suggestions =
          await _analyticsService.getOptimizationSuggestions(householdId);

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Insights & Recommendations',
                style:
                    pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 20),
              ...suggestions.take(5).map(
                    (suggestion) => pw.Container(
                      margin: const pw.EdgeInsets.only(bottom: 15),
                      padding: const pw.EdgeInsets.all(12),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey400),
                        borderRadius: pw.BorderRadius.circular(8),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Row(
                            mainAxisAlignment:
                                pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text(
                                suggestion.title,
                                style: pw.TextStyle(
                                  fontSize: 14,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                              pw.Container(
                                padding: const pw.EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4,),
                                decoration: pw.BoxDecoration(
                                  color: _getPriorityColor(suggestion.priority),
                                  borderRadius: pw.BorderRadius.circular(4),
                                ),
                                child: pw.Text(
                                  suggestion.priority.toUpperCase(),
                                  style: const pw.TextStyle(
                                      fontSize: 10, color: PdfColors.white,),
                                ),
                              ),
                            ],
                          ),
                          pw.SizedBox(height: 6),
                          pw.Text(suggestion.description,
                              style: const pw.TextStyle(fontSize: 12),),
                          if (suggestion.potentialSavings > 0) ...[
                            pw.SizedBox(height: 6),
                            pw.Text(
                              'Potential Savings: ₹${suggestion.potentialSavings.toStringAsFixed(2)}',
                              style: pw.TextStyle(
                                fontSize: 12,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.green700,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
            ],
          ),
        ),
      );
    }

    // Page 4: Transaction Details
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Transaction Details',
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 15),

            // Table
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400),
              columnWidths: {
                0: const pw.FlexColumnWidth(2),
                1: const pw.FlexColumnWidth(2),
                2: const pw.FlexColumnWidth(1.5),
                3: const pw.FlexColumnWidth(1.5),
              },
              children: [
                // Header
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                  children: [
                    _buildTableCell('Date', isHeader: true),
                    _buildTableCell('Description', isHeader: true),
                    _buildTableCell('Category', isHeader: true),
                    _buildTableCell('Amount', isHeader: true),
                  ],
                ),
                // Data rows
                ...expenses.take(30).map(
                      (expense) => pw.TableRow(
                        children: [
                          _buildTableCell(_formatDate(
                              DateTime.parse(expense['date'] as String),),),
                          _buildTableCell(
                              expense['description'] as String? ?? '-',),
                          _buildTableCell(
                              expense['category'] as String? ?? '-',),
                          _buildTableCell(
                              '₹${(expense['amount'] as double).toStringAsFixed(2)}',),
                        ],
                      ),
                    ),
              ],
            ),

            if (expenses.length > 30) ...[
              pw.SizedBox(height: 10),
              pw.Text(
                '... and ${expenses.length - 30} more transactions',
                style:
                    const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
              ),
            ],
          ],
        ),
      ),
    );

    // Save PDF
    final output = await _getOutputFile(
        'expense_report_${DateTime.now().millisecondsSinceEpoch}.pdf',);
    await output.writeAsBytes(await pdf.save());

    return output;
  }

  /// Export household expenses to Excel with multiple sheets
  Future<File> exportHouseholdToExcel({
    required int householdId,
    required String householdName,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final excel = Excel.createExcel();

    // Get data
    final expenses =
        await _getHouseholdExpenses(householdId, startDate, endDate);
    final patterns = await _analyticsService.getMemberSpendingPatterns(
      householdId,
      startDate: startDate,
      endDate: endDate,
    );
    final insights = await _analyticsService.getCategoryInsights(
      householdId,
      startDate: startDate,
      endDate: endDate,
    );

    // Sheet 1: Summary
    final summarySheet = excel['Summary'];
    excel.setDefaultSheet('Summary');

    summarySheet.appendRow([TextCellValue('Household Expense Report')]);
    summarySheet.appendRow([TextCellValue(householdName)]);
    summarySheet.appendRow([
      TextCellValue('${_formatDate(startDate)} to ${_formatDate(endDate)}'),
    ]);
    summarySheet.appendRow([]);
    summarySheet.appendRow([TextCellValue('Metric'), TextCellValue('Value')]);
    summarySheet.appendRow([
      TextCellValue('Total Expenses'),
      TextCellValue('₹${patterns.totalAmount.toStringAsFixed(2)}'),
    ]);
    summarySheet.appendRow([
      TextCellValue('Transaction Count'),
      IntCellValue(patterns.transactionCount),
    ]);
    summarySheet.appendRow([
      TextCellValue('Average Transaction'),
      TextCellValue('₹${patterns.averageTransaction.toStringAsFixed(2)}'),
    ]);
    summarySheet.appendRow([]);

    // Sheet 2: Transactions
    final transactionsSheet = excel['Transactions'];
    transactionsSheet.appendRow([
      TextCellValue('Date'),
      TextCellValue('Description'),
      TextCellValue('Category'),
      TextCellValue('Amount'),
      TextCellValue('Member'),
    ]);

    for (final expense in expenses) {
      transactionsSheet.appendRow([
        TextCellValue(_formatDate(DateTime.parse(expense['date'] as String))),
        TextCellValue(expense['description'] as String? ?? '-'),
        TextCellValue(expense['category'] as String? ?? '-'),
        TextCellValue((expense['amount'] as double).toStringAsFixed(2)),
        TextCellValue(expense['member_name'] as String? ?? '-'),
      ]);
    }

    // Sheet 3: Category Analysis
    final categorySheet = excel['Categories'];
    categorySheet.appendRow([
      TextCellValue('Category'),
      TextCellValue('Total Amount'),
      TextCellValue('Transaction Count'),
      TextCellValue('Average'),
      TextCellValue('Trend'),
      TextCellValue('Change %'),
    ]);

    for (final insight in insights) {
      categorySheet.appendRow([
        TextCellValue(insight.category),
        TextCellValue(insight.totalAmount.toStringAsFixed(2)),
        IntCellValue(insight.transactionCount),
        TextCellValue(insight.averageAmount.toStringAsFixed(2)),
        TextCellValue(insight.trend),
        TextCellValue(insight.changePercent.toStringAsFixed(1)),
      ]);
    }

    // Sheet 4: Member Spending
    final memberSheet = excel['Members'];
    memberSheet
        .appendRow([TextCellValue('Member ID'), TextCellValue('Total Spent')]);

    patterns.memberSpending.forEach((memberId, amount) {
      memberSheet.appendRow([
        TextCellValue(memberId.toString()),
        TextCellValue(amount.toStringAsFixed(2)),
      ]);
    });

    // Save Excel
    final output = await _getOutputFile(
        'expense_report_${DateTime.now().millisecondsSinceEpoch}.xlsx',);
    await output.writeAsBytes(excel.encode()!);

    return output;
  }

  /// Share exported file via WhatsApp, Email, etc.
  Future<void> shareExportedFile(File file, String title) async {
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: title,
      text: 'Household Expense Report',
    );
  }

  /// Get household expenses for date range
  Future<List<Map<String, dynamic>>> _getHouseholdExpenses(
    int householdId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final db = await _databaseService.database;
    return db.rawQuery(
      '''
      SELECT e.*, m.name as member_name
      FROM household_expenses e
      LEFT JOIN family_members m ON e.member_id = m.id
      WHERE e.household_id = ? AND e.date >= ? AND e.date <= ?
      ORDER BY e.date DESC
    ''',
      [householdId, startDate.toIso8601String(), endDate.toIso8601String()],
    );
  }

  /// Build summary card for PDF
  pw.Widget _buildSummaryCard(String label, String value, PdfColor color) {
    return pw.Container(
      width: 150,
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        color: color.shade(0.1),
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: color),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 20,
              fontWeight: pw.FontWeight.bold,
              color: color,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            label,
            style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
          ),
        ],
      ),
    );
  }

  /// Build pie chart for category distribution
  pw.Widget _buildPieChart(Map<String, double> data) {
    final total = data.values.fold<double>(0, (sum, value) => sum + value);
    final sortedEntries = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final topEntries = sortedEntries.take(5).toList();
    final otherAmount = sortedEntries
        .skip(5)
        .fold<double>(0, (sum, entry) => sum + entry.value);

    if (otherAmount > 0) {
      topEntries.add(MapEntry('Others', otherAmount));
    }

    return pw.Row(
      children: [
        pw.Expanded(
          flex: 2,
          child: pw.Container(
            height: 200,
            child: pw.Stack(
              children: topEntries.asMap().entries.map((entry) {
                return pw.Positioned(
                  left: 20 + (entry.key * 15.0),
                  top: 20 + (entry.key * 15.0),
                  child: pw.Container(
                    width: 20,
                    height: 20,
                    decoration: pw.BoxDecoration(
                      color: _getColorForIndex(entry.key),
                      shape: pw.BoxShape.circle,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        pw.SizedBox(width: 20),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: topEntries.map((entry) {
              final percentage = (entry.value / total * 100).toStringAsFixed(1);
              return pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 8),
                child: pw.Row(
                  children: [
                    pw.Container(
                      width: 12,
                      height: 12,
                      color: _getColorForIndex(topEntries.indexOf(entry)),
                    ),
                    pw.SizedBox(width: 6),
                    pw.Expanded(
                      child: pw.Text(
                        '${entry.key} ($percentage%)',
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  /// Build bar chart for spending patterns
  pw.Widget _buildBarChart(List<double> data, List<String> labels) {
    final maxValue = data.reduce(math.max);

    return pw.Chart(
      grid: pw.CartesianGrid(
        xAxis: pw.FixedAxis(
          List.generate(labels.length, (i) => i.toDouble()),
          divisions: true,
        ),
        yAxis: pw.FixedAxis(
          [0, maxValue / 2, maxValue],
          format: (value) => '₹${value.toInt()}',
        ),
      ),
      datasets: [
        pw.BarDataSet(
          data: data
              .asMap()
              .entries
              .map(
                (e) => pw.PointChartValue(e.key.toDouble(), e.value),
              )
              .toList(),
          width: 20,
        ),
      ],
    );
  }

  /// Build table cell
  pw.Widget _buildTableCell(String text, {bool isHeader = false}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 11 : 10,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  /// Get output file path
  Future<File> _getOutputFile(String filename) async {
    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/$filename';
    return File(path);
  }

  /// Format date
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  /// Get color for chart index
  PdfColor _getColorForIndex(int index) {
    final colors = [
      PdfColors.blue,
      PdfColors.green,
      PdfColors.orange,
      PdfColors.purple,
      PdfColors.red,
      PdfColors.teal,
    ];
    return colors[index % colors.length];
  }

  /// Get trend color
  PdfColor _getTrendColor(String trend) {
    switch (trend) {
      case 'increasing':
        return PdfColors.red;
      case 'decreasing':
        return PdfColors.green;
      default:
        return PdfColors.blue;
    }
  }

  /// Get priority color
  PdfColor _getPriorityColor(String priority) {
    switch (priority) {
      case 'high':
        return PdfColors.red;
      case 'medium':
        return PdfColors.orange;
      default:
        return PdfColors.blue;
    }
  }
}
