import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart' as intl;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../models/client.dart';
import '../models/contract.dart';
import '../models/legal_case.dart';
import '../models/office_settings.dart';
import '../models/payment.dart';

/// Reusable PDF engine. Produces A4 documents with:
///   - Branded header (lawyer name + office name + logo placeholder)
///   - Professional border
///   - Automatic page numbers and printing date
///   - Full RTL Arabic typography (Cairo via google_fonts)
class PdfService {
  PdfService._();
  static final PdfService instance = PdfService._();

  pw.Font? _cairoRegular;
  pw.Font? _cairoBold;

  Future<void> _ensureFonts() async {
    _cairoRegular ??= await PdfGoogleFonts.cairoRegular();
    _cairoBold ??= await PdfGoogleFonts.cairoBold();
  }

  Future<pw.ThemeData> _theme() async {
    await _ensureFonts();
    return pw.ThemeData.withFont(
      base: _cairoRegular!,
      bold: _cairoBold!,
      fontFallback: [
        await PdfGoogleFonts.notoSansArabicRegular(),
        await PdfGoogleFonts.notoSansArabicBold(),
      ],
    );
  }

  // ────────────────────────────────────────── PUBLIC API ──────────────────

  Future<Uint8List> buildContractPdf({
    required OfficeSettings settings,
    required Contract contract,
    Client? client,
    LegalCase? legalCase,
  }) async {
    final theme = await _theme();
    final doc = pw.Document(theme: theme, title: contract.title);
    final logoImage = await _loadLogo(settings.logoPath);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(36, 36, 36, 48),
        textDirection: pw.TextDirection.rtl,
        theme: theme,
        header: (ctx) => _buildHeader(settings, logoImage),
        footer: (ctx) => _buildFooter(ctx),
        build: (ctx) => [
          pw.SizedBox(height: 8),
          pw.Center(
            child: pw.Text(
              contract.title,
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromInt(0xFF001F3F),
              ),
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Center(
            child: pw.Text(
              'تاريخ العقد: ${_formatDate(contract.contractDate)}',
              style: const pw.TextStyle(fontSize: 11),
            ),
          ),
          pw.SizedBox(height: 16),
          if (client != null) _buildPartiesBox(client, contract),
          if (legalCase != null) ...[
            pw.SizedBox(height: 8),
            _buildCaseBox(legalCase),
          ],
          pw.SizedBox(height: 16),
          ..._buildContractBody(contract.body),
          pw.SizedBox(height: 20),
          if (contract.amount > 0)
            pw.Text(
              'قيمة العقد: ${_formatMoney(contract.amount)}',
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
            ),
          pw.SizedBox(height: 40),
          _buildSignatures(settings, client),
        ],
      ),
    );
    return doc.save();
  }

  Future<Uint8List> buildCertificationPdf({
    required String title,
    required String body,
  }) async {
    final theme = await _theme();
    final doc = pw.Document(theme: theme, title: title);

    final paragraphs = body
        .split(RegExp(r'\n\s*\n'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(36, 36, 36, 48),
        textDirection: pw.TextDirection.rtl,
        theme: theme,
        footer: (ctx) => _buildFooter(ctx),
        build: (ctx) => [
          pw.SizedBox(height: 6),
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: const PdfColor.fromInt(0xFF001F3F),
            ),
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: 14),
          ...paragraphs.map(
            (para) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 8),
              child: pw.Text(
                para,
                style: const pw.TextStyle(fontSize: 12, lineSpacing: 4),
                textAlign: pw.TextAlign.justify,
              ),
            ),
          ),
        ],
      ),
    );

    return doc.save();
  }

  Future<Uint8List> buildFinanceReportPdf({
    required OfficeSettings settings,
    required List<Map<String, dynamic>> rows,
    required Map<String, double> totals,
  }) async {
    final theme = await _theme();
    final doc = pw.Document(theme: theme, title: 'تقرير مالي شامل');
    final logoImage = await _loadLogo(settings.logoPath);

    final tableHeaders = [
      '#',
      'العميل',
      'رقم القضية',
      'العنوان',
      'الأتعاب',
      'المسدد',
      'المتبقي',
      'الحالة',
    ];

    int idx = 1;
    final tableData = rows.map((r) {
      final fees = (r['fees'] as num?)?.toDouble() ?? 0;
      final paid = (r['paid'] as num?)?.toDouble() ?? 0;
      final outstanding = (fees - paid).clamp(0, double.infinity);
      return [
        '${idx++}',
        (r['client_name'] ?? '') as String,
        (r['case_number'] ?? '') as String,
        (r['title'] ?? '') as String,
        _formatMoney(fees),
        _formatMoney(paid),
        _formatMoney(outstanding.toDouble()),
        (r['status'] ?? '') as String,
      ];
    }).toList();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(28, 28, 28, 44),
        textDirection: pw.TextDirection.rtl,
        theme: theme,
        header: (ctx) => _buildHeader(settings, logoImage),
        footer: (ctx) => _buildFooter(ctx),
        build: (ctx) => [
          pw.SizedBox(height: 8),
          pw.Center(
            child: pw.Text(
              'التقرير المالي الشامل للقضايا',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromInt(0xFF001F3F),
              ),
            ),
          ),
          pw.SizedBox(height: 12),
          _buildTotalsBox(totals),
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            headers: tableHeaders,
            data: tableData,
            cellAlignment: pw.Alignment.center,
            headerDecoration: const pw.BoxDecoration(
              color: PdfColor.fromInt(0xFF001F3F),
            ),
            headerStyle: pw.TextStyle(
              color: PdfColors.white,
              fontWeight: pw.FontWeight.bold,
              fontSize: 10,
            ),
            cellStyle: const pw.TextStyle(fontSize: 10),
            border: pw.TableBorder.all(
              color: PdfColor.fromInt(0xFFD4AF37),
              width: 0.5,
            ),
            oddRowDecoration: const pw.BoxDecoration(
              color: PdfColor.fromInt(0xFFF8F9FA),
            ),
          ),
        ],
      ),
    );
    return doc.save();
  }

  Future<Uint8List> buildClientStatementPdf({
    required OfficeSettings settings,
    required Client client,
    required List<LegalCase> cases,
    required List<Payment> payments,
  }) async {
    final theme = await _theme();
    final doc = pw.Document(
      theme: theme,
      title: 'كشف حساب - ${client.fullName}',
    );
    final logoImage = await _loadLogo(settings.logoPath);

    final totalFees = cases.fold<double>(0, (s, c) => s + c.fees);
    final totalPaid = cases.fold<double>(0, (s, c) => s + c.paid);
    final totalOutstanding = (totalFees - totalPaid).clamp(0, double.infinity);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(32, 32, 32, 44),
        textDirection: pw.TextDirection.rtl,
        theme: theme,
        header: (ctx) => _buildHeader(settings, logoImage),
        footer: (ctx) => _buildFooter(ctx),
        build: (ctx) => [
          pw.SizedBox(height: 8),
          pw.Center(
            child: pw.Text(
              'كشف حساب موكّل',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromInt(0xFF001F3F),
              ),
            ),
          ),
          pw.SizedBox(height: 12),
          _kvRow('اسم الموكّل', client.fullName),
          if (client.nationalId?.isNotEmpty ?? false)
            _kvRow('رقم الهوية', client.nationalId!),
          if (client.phone?.isNotEmpty ?? false)
            _kvRow('الهاتف', client.phone!),
          pw.SizedBox(height: 10),
          _buildTotalsBox({
            'fees': totalFees,
            'paid': totalPaid,
            'outstanding': totalOutstanding.toDouble(),
          }),
          pw.SizedBox(height: 12),
          pw.Text(
            'القضايا',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13),
          ),
          pw.SizedBox(height: 4),
          pw.TableHelper.fromTextArray(
            headers: [
              'رقم القضية',
              'العنوان',
              'الأتعاب',
              'المسدد',
              'المتبقي',
              'الحالة',
            ],
            data: cases
                .map(
                  (c) => [
                    c.caseNumber,
                    c.title,
                    _formatMoney(c.fees),
                    _formatMoney(c.paid),
                    _formatMoney(c.outstanding),
                    c.status,
                  ],
                )
                .toList(),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColor.fromInt(0xFF001F3F),
            ),
            headerStyle: pw.TextStyle(
              color: PdfColors.white,
              fontWeight: pw.FontWeight.bold,
              fontSize: 10,
            ),
            cellStyle: const pw.TextStyle(fontSize: 10),
            cellAlignment: pw.Alignment.center,
            border: pw.TableBorder.all(
              color: PdfColor.fromInt(0xFFD4AF37),
              width: 0.5,
            ),
          ),
          pw.SizedBox(height: 14),
          pw.Text(
            'سجل المدفوعات',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13),
          ),
          pw.SizedBox(height: 4),
          pw.TableHelper.fromTextArray(
            headers: ['التاريخ', 'المبلغ', 'الطريقة', 'ملاحظات'],
            data: payments
                .map(
                  (p) => [
                    _formatDate(p.paymentDate),
                    _formatMoney(p.amount),
                    p.method ?? '-',
                    p.notes ?? '-',
                  ],
                )
                .toList(),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColor.fromInt(0xFF001F3F),
            ),
            headerStyle: pw.TextStyle(
              color: PdfColors.white,
              fontWeight: pw.FontWeight.bold,
              fontSize: 10,
            ),
            cellStyle: const pw.TextStyle(fontSize: 10),
            cellAlignment: pw.Alignment.center,
            border: pw.TableBorder.all(
              color: PdfColor.fromInt(0xFFD4AF37),
              width: 0.5,
            ),
          ),
        ],
      ),
    );
    return doc.save();
  }

  Future<Uint8List> buildAgendaPdf({
    required OfficeSettings settings,
    required List<Map<String, dynamic>> agenda,
  }) async {
    final theme = await _theme();
    final doc = pw.Document(theme: theme, title: 'أجندة المحكمة');
    final logoImage = await _loadLogo(settings.logoPath);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(32, 32, 32, 44),
        textDirection: pw.TextDirection.rtl,
        theme: theme,
        header: (ctx) => _buildHeader(settings, logoImage),
        footer: (ctx) => _buildFooter(ctx),
        build: (ctx) => [
          pw.SizedBox(height: 8),
          pw.Center(
            child: pw.Text(
              'أجندة الجلسات',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromInt(0xFF001F3F),
              ),
            ),
          ),
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            headers: ['التاريخ', 'العميل', 'القضية', 'المحكمة', 'الحالة'],
            data: agenda
                .map(
                  (r) => [
                    _formatDate((r['session_date'] ?? '') as String),
                    (r['client_name'] ?? '') as String,
                    '${r['case_number']} - ${r['case_title']}',
                    (r['court_name'] ?? '-') as String,
                    (r['status'] ?? '') as String,
                  ],
                )
                .toList(),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColor.fromInt(0xFF001F3F),
            ),
            headerStyle: pw.TextStyle(
              color: PdfColors.white,
              fontWeight: pw.FontWeight.bold,
              fontSize: 10,
            ),
            cellStyle: const pw.TextStyle(fontSize: 10),
            cellAlignment: pw.Alignment.center,
            border: pw.TableBorder.all(
              color: PdfColor.fromInt(0xFFD4AF37),
              width: 0.5,
            ),
          ),
        ],
      ),
    );
    return doc.save();
  }

  /// Opens the system print preview / dialog (desktop).
  Future<void> printDocument(Uint8List bytes, {String? jobName}) async {
    await Printing.layoutPdf(
      onLayout: (_) async => bytes,
      name: jobName ?? 'مستند قانوني',
    );
  }

  /// Mobile/tablet: native share sheet (WhatsApp, email, etc.).
  /// Desktop: print / save dialog via [printing].
  Future<void> exportPdf(
    Uint8List bytes, {
    required String fileName,
    String? jobName,
    String? shareText,
  }) async {
    final useShareSheet = !kIsWeb && (Platform.isAndroid || Platform.isIOS);
    if (useShareSheet) {
      await _shareViaSharePlus(
        bytes,
        fileName,
        shareText: shareText ?? jobName ?? 'مستند قانوني',
      );
    } else {
      await printDocument(bytes, jobName: jobName ?? fileName);
    }
  }

  Future<void> _shareViaSharePlus(
    Uint8List bytes,
    String fileName, {
    required String shareText,
  }) async {
    final safeName = fileName.endsWith('.pdf') ? fileName : '$fileName.pdf';
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$safeName');
    await file.writeAsBytes(bytes, flush: true);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/pdf', name: safeName)],
      text: shareText,
      subject: shareText,
    );
  }

  /// Legacy helper — delegates to [exportPdf] on mobile or [printDocument] on desktop.
  Future<void> sharePdf(Uint8List bytes, String fileName) async {
    await exportPdf(bytes, fileName: fileName);
  }

  // ────────────────────────────────────────── INTERNAL ────────────────────

  Future<pw.MemoryImage?> _loadLogo(String? path) async {
    if (path == null || path.isEmpty) return null;
    try {
      final f = File(path);
      if (await f.exists()) {
        return pw.MemoryImage(await f.readAsBytes());
      }
    } catch (_) {}
    return null;
  }

  pw.Widget _buildHeader(OfficeSettings settings, pw.MemoryImage? logo) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 8),
      padding: const pw.EdgeInsets.only(bottom: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(
            color: PdfColor.fromInt(0xFFD4AF37),
            width: 1.5,
          ),
        ),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Container(
            width: 60,
            height: 60,
            decoration: pw.BoxDecoration(
              border: pw.Border.all(
                color: const PdfColor.fromInt(0xFF001F3F),
                width: 1,
              ),
              borderRadius: pw.BorderRadius.circular(6),
              color: const PdfColor.fromInt(0xFFF8F9FA),
            ),
            alignment: pw.Alignment.center,
            child: logo != null
                ? pw.Image(logo, fit: pw.BoxFit.contain)
                : pw.Text(
                    'الشعار',
                    style: pw.TextStyle(
                      fontSize: 9,
                      color: PdfColor.fromInt(0xFF001F3F),
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
          ),
          pw.SizedBox(width: 10),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text(
                  settings.officeName,
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: const PdfColor.fromInt(0xFF001F3F),
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  settings.lawyerName,
                  style: pw.TextStyle(
                    fontSize: 11,
                    color: const PdfColor.fromInt(0xFFD4AF37),
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                if ((settings.address ?? '').isNotEmpty ||
                    (settings.phone ?? '').isNotEmpty)
                  pw.Text(
                    [
                      if ((settings.address ?? '').isNotEmpty) settings.address,
                      if ((settings.phone ?? '').isNotEmpty)
                        'هاتف: ${settings.phone}',
                    ].whereType<String>().join('  •  '),
                    style: const pw.TextStyle(fontSize: 9),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildFooter(pw.Context ctx) {
    final printedAt = intl.DateFormat(
      'yyyy/MM/dd HH:mm',
      'ar',
    ).format(DateTime.now());
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: PdfColor.fromInt(0xFFD4AF37), width: 0.8),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'تاريخ الطباعة: $printedAt',
            style: const pw.TextStyle(fontSize: 9),
          ),
          pw.Text(
            'صفحة ${ctx.pageNumber} من ${ctx.pagesCount}',
            style: pw.TextStyle(
              fontSize: 9,
              color: const PdfColor.fromInt(0xFF001F3F),
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  /// Splits the contract body into per-paragraph widgets so that
  /// MultiPage can break between paragraphs. Avoids the
  /// "widget won't fit into the page" exception for long contracts.
  List<pw.Widget> _buildContractBody(String body) {
    final paragraphs = body
        .split(RegExp(r'\n\s*\n'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();

    if (paragraphs.isEmpty) return const [];

    final widgets = <pw.Widget>[];
    for (var i = 0; i < paragraphs.length; i++) {
      final para = paragraphs[i];
      final isHeading =
          para.startsWith('البند') ||
          para.startsWith('تمهيد') ||
          para.startsWith('إنه في');

      widgets.add(
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 4),
          child: pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: pw.BoxDecoration(
              color: isHeading
                  ? const PdfColor.fromInt(0xFFF1E9D2)
                  : const PdfColor.fromInt(0xFFF8F9FA),
              border: pw.Border(
                right: pw.BorderSide(
                  color: const PdfColor.fromInt(0xFFD4AF37),
                  width: isHeading ? 3 : 1.5,
                ),
              ),
            ),
            child: pw.Text(
              para,
              style: pw.TextStyle(
                fontSize: 12,
                lineSpacing: 4,
                fontWeight: isHeading
                    ? pw.FontWeight.bold
                    : pw.FontWeight.normal,
                color: isHeading
                    ? const PdfColor.fromInt(0xFF001F3F)
                    : const PdfColor.fromInt(0xFF1A1A1A),
              ),
              textAlign: pw.TextAlign.justify,
            ),
          ),
        ),
      );
    }
    return widgets;
  }

  pw.Widget _buildPartiesBox(Client client, Contract contract) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: const PdfColor.fromInt(0xFF001F3F)),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'بيانات الموكّل (الطرف الأول)',
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: const PdfColor.fromInt(0xFF001F3F),
            ),
          ),
          pw.SizedBox(height: 4),
          _kvRow('الاسم', client.fullName),
          if ((client.nationalId ?? '').isNotEmpty)
            _kvRow('رقم الهوية', client.nationalId!),
          if ((client.phone ?? '').isNotEmpty) _kvRow('الهاتف', client.phone!),
          if ((client.address ?? '').isNotEmpty)
            _kvRow('العنوان', client.address!),
        ],
      ),
    );
  }

  pw.Widget _buildCaseBox(LegalCase legalCase) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: const PdfColor.fromInt(0xFFD4AF37)),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'القضية المرتبطة',
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: const PdfColor.fromInt(0xFF001F3F),
            ),
          ),
          pw.SizedBox(height: 4),
          _kvRow('رقم القضية', legalCase.caseNumber),
          _kvRow('العنوان', legalCase.title),
          if ((legalCase.courtName ?? '').isNotEmpty)
            _kvRow('المحكمة', legalCase.courtName!),
        ],
      ),
    );
  }

  pw.Widget _buildSignatures(OfficeSettings settings, Client? client) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        _signature(
          'الطرف الأول (الموكّل)',
          client?.fullName ?? '________________',
        ),
        _signature('الطرف الثاني (المحامي)', settings.lawyerName),
      ],
    );
  }

  pw.Widget _signature(String label, String name) {
    return pw.Container(
      width: 220,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
          ),
          pw.SizedBox(height: 36),
          pw.Container(
            width: 200,
            decoration: const pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(width: 0.8)),
            ),
            padding: const pw.EdgeInsets.only(top: 4),
            child: pw.Center(
              child: pw.Text(name, style: const pw.TextStyle(fontSize: 11)),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildTotalsBox(Map<String, double> totals) {
    pw.Widget box(String label, double value, PdfColor color) {
      return pw.Expanded(
        child: pw.Container(
          margin: const pw.EdgeInsets.symmetric(horizontal: 4),
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: color,
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Column(
            children: [
              pw.Text(
                label,
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 11,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                _formatMoney(value),
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return pw.Row(
      children: [
        box(
          'إجمالي الأتعاب',
          totals['fees'] ?? 0,
          const PdfColor.fromInt(0xFF001F3F),
        ),
        box(
          'إجمالي المسدد',
          totals['paid'] ?? 0,
          const PdfColor.fromInt(0xFF1B5E20),
        ),
        box(
          'إجمالي المتبقي',
          totals['outstanding'] ?? 0,
          const PdfColor.fromInt(0xFFB71C1C),
        ),
      ],
    );
  }

  pw.Widget _kvRow(String k, String v) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 2),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          width: 90,
          child: pw.Text(
            '$k:',
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: const PdfColor.fromInt(0xFF001F3F),
            ),
          ),
        ),
        pw.Expanded(child: pw.Text(v)),
      ],
    ),
  );

  String _formatDate(String iso) {
    try {
      final d = DateTime.parse(iso);
      return intl.DateFormat('yyyy/MM/dd', 'ar').format(d);
    } catch (_) {
      return iso;
    }
  }

  String _formatMoney(double v) {
    final f = intl.NumberFormat('#,##0.00', 'ar');
    return f.format(v);
  }

  // Allows callers to preload fonts during boot if desired.
  Future<void> warmUp() async {
    await _ensureFonts();
    // Keep API symmetrical for future asset preloading.
    // ignore: unused_local_variable
    final _ = rootBundle;
  }
}
