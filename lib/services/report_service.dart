import 'dart:io';

import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../models/fuel_expense.dart';
import '../models/general_expense.dart';
import '../models/vehicle.dart';

class ReportService {
  ReportService._init();
  static final ReportService instance = ReportService._init();

  final _dateFormat = DateFormat('dd/MM/yyyy');

  // Generate PDF report (offloaded to isolate for performance)
  Future<File> generatePDFReport({
    required String title,
    required DateTime startDate,
    required DateTime endDate,
    required List<FuelExpense> fuelExpenses,
    required List<GeneralExpense> generalExpenses,
    required List<Vehicle> vehicles,
  }) async {
    // Offload PDF building to background isolate to prevent UI jank
    final pdfBytes = await compute(
      _buildPDFInIsolate,
      _PDFGenerationInput(
        title: title,
        startDate: startDate,
        endDate: endDate,
        fuelExpenses: fuelExpenses,
        generalExpenses: generalExpenses,
        vehicles: vehicles,
      ),
    );

    // Save to file on main isolate
    final output = await getTemporaryDirectory();
    final file = File(
        '${output.path}/expense_report_${DateTime.now().millisecondsSinceEpoch}.pdf',);
    await file.writeAsBytes(pdfBytes);

    return file;
  }

  // Print PDF
  Future<void> printPDF(File pdfFile) async {
    final bytes = await pdfFile.readAsBytes();
    await Printing.layoutPdf(onLayout: (_) => bytes);
  }

  // Share PDF
  Future<void> sharePDF(File pdfFile) async {
    await Share.shareXFiles([XFile(pdfFile.path)], text: 'Expense Report');
  }

  // Generate CSV export
  Future<File> generateCSVReport({
    required List<FuelExpense> fuelExpenses,
    required List<GeneralExpense> generalExpenses,
    required List<Vehicle> vehicles,
  }) async {
    final rows = <List<String>>[
      // Add fuel expenses header
      [
        'Type',
        'Date',
        'Vehicle',
        'Category',
        'Description',
        'Amount',
        'Liters',
        'Pump',
      ],
    ];

    for (final expense in fuelExpenses) {
      final vehicle = vehicles.firstWhere(
        (v) => v.id == expense.vehicleId,
        orElse: () => vehicles.first,
      );
      rows.add([
        'Fuel',
        _dateFormat.format(expense.date),
        vehicle.name,
        expense.fuelType.name,
        expense.notes ?? '',
        expense.amountPaid.toString(),
        expense.liters.toString(),
        expense.pumpName ?? '',
      ]);
    }

    for (final expense in generalExpenses) {
      rows.add([
        'General',
        _dateFormat.format(expense.date),
        '',
        expense.category.name,
        expense.description,
        expense.amount.toString(),
        '',
        '',
      ]);
    }

    final csv = const ListToCsvConverter().convert(rows);

    final output = await getTemporaryDirectory();
    final file = File(
      '${output.path}/expenses_${DateTime.now().millisecondsSinceEpoch}.csv',
    );
    await file.writeAsString(csv);

    return file;
  }

  // Generate Excel report
  Future<File> generateExcelReport({
    required List<FuelExpense> fuelExpenses,
    required List<GeneralExpense> generalExpenses,
    required List<Vehicle> vehicles,
  }) async {
    final excel = Excel.createExcel();

    // Fuel expenses sheet
    final fuelSheet = excel['Fuel Expenses']
      ..appendRow([
        TextCellValue('Date'),
        TextCellValue('Vehicle'),
        TextCellValue('Fuel Type'),
        TextCellValue('Amount'),
        TextCellValue('Liters'),
        TextCellValue('Pump'),
        TextCellValue('Notes'),
      ]);

    for (final expense in fuelExpenses) {
      final vehicle = vehicles.firstWhere(
        (v) => v.id == expense.vehicleId,
        orElse: () => vehicles.first,
      );
      fuelSheet.appendRow([
        TextCellValue(_dateFormat.format(expense.date)),
        TextCellValue(vehicle.name),
        TextCellValue(expense.fuelType.name),
        TextCellValue(expense.amountPaid.toString()),
        TextCellValue(expense.liters.toString()),
        TextCellValue(expense.pumpName ?? ''),
        TextCellValue(expense.notes ?? ''),
      ]);
    }

    // General expenses sheet
    final generalSheet = excel['General Expenses']
      ..appendRow([
        TextCellValue('Date'),
        TextCellValue('Category'),
        TextCellValue('Description'),
        TextCellValue('Amount'),
      ]);

    for (final expense in generalExpenses) {
      generalSheet.appendRow([
        TextCellValue(_dateFormat.format(expense.date)),
        TextCellValue(expense.category.name),
        TextCellValue(expense.description),
        TextCellValue(expense.amount.toString()),
      ]);
    }

    // Save to file
    final output = await getTemporaryDirectory();
    final file = File(
      '${output.path}/expenses_${DateTime.now().millisecondsSinceEpoch}.xlsx',
    );
    await file.writeAsBytes(excel.encode()!);

    return file;
  }
}

// Top-level class for passing data to PDF isolate
class _PDFGenerationInput {
  const _PDFGenerationInput({
    required this.title,
    required this.startDate,
    required this.endDate,
    required this.fuelExpenses,
    required this.generalExpenses,
    required this.vehicles,
  });

  final String title;
  final DateTime startDate;
  final DateTime endDate;
  final List<FuelExpense> fuelExpenses;
  final List<GeneralExpense> generalExpenses;
  final List<Vehicle> vehicles;
}

// Top-level isolate function for PDF generation (Phase 6: Move heavy operations to isolates)
Future<Uint8List> _buildPDFInIsolate(_PDFGenerationInput input) async {
  final dateFormat = DateFormat('dd/MM/yyyy');
  final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 2);

  final pdf = pw.Document();

  // Calculate summary
  final totalFuelExpense = input.fuelExpenses.fold<double>(
    0,
    (sum, expense) => sum + expense.amountPaid,
  );
  final totalGeneralExpense = input.generalExpenses.fold<double>(
    0,
    (sum, expense) => sum + expense.amount,
  );
  final totalExpense = totalFuelExpense + totalGeneralExpense;

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (context) => [
        // Title
        pw.Header(
          level: 0,
          child: pw.Text(
            input.title,
            style: pw.TextStyle(
              fontSize: 24,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
        pw.SizedBox(height: 10),

        // Date range
        pw.Text(
          'Period: ${dateFormat.format(input.startDate)} - ${dateFormat.format(input.endDate)}',
          style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
        ),
        pw.Divider(),
        pw.SizedBox(height: 20),

        // Summary section
        pw.Header(text: 'Summary'),
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey300),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildSummaryRowIsolate(
                  'Total Fuel Expenses', totalFuelExpense, currencyFormat,),
              _buildSummaryRowIsolate('Total General Expenses',
                  totalGeneralExpense, currencyFormat,),
              pw.Divider(),
              _buildSummaryRowIsolate(
                  'Total Expenses', totalExpense, currencyFormat,
                  isBold: true,),
              pw.SizedBox(height: 10),
              pw.Text('Fuel Entries: ${input.fuelExpenses.length}'),
              pw.Text('General Entries: ${input.generalExpenses.length}'),
              pw.Text(
                  'Total Entries: ${input.fuelExpenses.length + input.generalExpenses.length}',),
            ],
          ),
        ),
        pw.SizedBox(height: 20),

        // Fuel expenses table
        if (input.fuelExpenses.isNotEmpty) ...[
          pw.Header(text: 'Fuel Expenses'),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  _buildTableHeaderIsolate('Date'),
                  _buildTableHeaderIsolate('Vehicle'),
                  _buildTableHeaderIsolate('Liters'),
                  _buildTableHeaderIsolate('Amount'),
                ],
              ),
              ...input.fuelExpenses.map((expense) {
                final vehicle = input.vehicles.firstWhere(
                  (v) => v.id == expense.vehicleId,
                  orElse: () => input.vehicles.first,
                );
                return pw.TableRow(
                  children: [
                    _buildTableCellIsolate(dateFormat.format(expense.date)),
                    _buildTableCellIsolate(vehicle.name),
                    _buildTableCellIsolate(
                        '${expense.liters.toStringAsFixed(2)} L',),
                    _buildTableCellIsolate(
                        currencyFormat.format(expense.amountPaid),),
                  ],
                );
              }),
            ],
          ),
          pw.SizedBox(height: 20),
        ],

        // General expenses table
        if (input.generalExpenses.isNotEmpty) ...[
          pw.Header(text: 'General Expenses'),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  _buildTableHeaderIsolate('Date'),
                  _buildTableHeaderIsolate('Category'),
                  _buildTableHeaderIsolate('Description'),
                  _buildTableHeaderIsolate('Amount'),
                ],
              ),
              ...input.generalExpenses.map((expense) {
                return pw.TableRow(
                  children: [
                    _buildTableCellIsolate(dateFormat.format(expense.date)),
                    _buildTableCellIsolate(expense.category.name),
                    _buildTableCellIsolate(expense.description),
                    _buildTableCellIsolate(
                        currencyFormat.format(expense.amount),),
                  ],
                );
              }),
            ],
          ),
        ],

        pw.SizedBox(height: 40),

        // Footer
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Generated on ${dateFormat.format(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey),
          ),
        ),
      ],
    ),
  );

  return pdf.save();
}

// Helper functions for isolate PDF building
pw.Widget _buildSummaryRowIsolate(
    String label, double amount, NumberFormat currencyFormat,
    {bool isBold = false,}) {
  return pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [
      pw.Text(
        label,
        style: pw.TextStyle(
          fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
      pw.Text(
        currencyFormat.format(amount),
        style: pw.TextStyle(
          fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    ],
  );
}

pw.Widget _buildTableHeaderIsolate(String text) {
  return pw.Container(
    padding: const pw.EdgeInsets.all(5),
    child: pw.Text(
      text,
      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
    ),
  );
}

pw.Widget _buildTableCellIsolate(String text) {
  return pw.Container(
    padding: const pw.EdgeInsets.all(5),
    child: pw.Text(text, style: const pw.TextStyle(fontSize: 10)),
  );
}
