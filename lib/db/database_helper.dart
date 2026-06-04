import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/attachment.dart';
import '../models/client.dart';
import '../models/contract.dart';
import '../models/legal_case.dart';
import '../models/office_settings.dart';
import '../models/payment.dart';
import '../models/session.dart';

/// Singleton SQLite helper for the Legal ERP system.
/// All persistence (clients, cases, sessions, contracts, payments,
/// attachments, office settings) flows through here.
class DatabaseHelper {
  DatabaseHelper._internal();
  static final DatabaseHelper instance = DatabaseHelper._internal();

  static const _dbName = 'lawer_system.db';
  static const _dbVersion = 2;
  Database? _db;

  /// Initialise the desktop FFI loader on Windows / Linux / macOS so the
  /// same code base works on mobile and desktop without manual config.
  static void initPlatform() {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
  }

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _open();
    return _db!;
  }

  /// Windows → Roaming AppData via [getApplicationSupportDirectory].
  /// Android / iOS / tablets → application documents directory.
  static Future<Directory> databaseDirectory() async {
    if (Platform.isWindows) {
      return getApplicationSupportDirectory();
    }
    return getApplicationDocumentsDirectory();
  }

  Future<Database> _open() async {
    final docs = await databaseDirectory();
    final path = p.join(docs.path, _dbName);

    if (Platform.isWindows) {
      final legacyDocs = await getApplicationDocumentsDirectory();
      final legacyPath = p.join(legacyDocs.path, _dbName);
      final legacyFile = File(legacyPath);
      final newFile = File(path);
      if (await legacyFile.exists() && !await newFile.exists()) {
        await legacyFile.copy(path);
      }
    }

    return openDatabase(
      path,
      version: _dbVersion,
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE clients (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        full_name TEXT NOT NULL,
        national_id TEXT,
        phone TEXT,
        email TEXT,
        address TEXT,
        notes TEXT,
        created_at TEXT NOT NULL
      );
    ''');

    await db.execute('''
      CREATE TABLE cases (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        client_id INTEGER NOT NULL,
        case_number TEXT NOT NULL,
        title TEXT NOT NULL,
        court_name TEXT,
        case_type TEXT,
        opponent TEXT,
        status TEXT NOT NULL,
        fees REAL NOT NULL DEFAULT 0,
        paid REAL NOT NULL DEFAULT 0,
        next_session_date TEXT,
        notes TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (client_id) REFERENCES clients(id) ON DELETE CASCADE
      );
    ''');

    await db.execute('''
      CREATE TABLE sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        case_id INTEGER NOT NULL,
        session_date TEXT NOT NULL,
        notes TEXT,
        decision TEXT,
        status TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (case_id) REFERENCES cases(id) ON DELETE CASCADE
      );
    ''');

    await db.execute('''
      CREATE TABLE contracts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        client_id INTEGER,
        case_id INTEGER,
        title TEXT NOT NULL,
        body TEXT NOT NULL,
        amount REAL NOT NULL DEFAULT 0,
        contract_date TEXT NOT NULL,
        created_at TEXT NOT NULL,
        is_certification INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (client_id) REFERENCES clients(id) ON DELETE SET NULL,
        FOREIGN KEY (case_id) REFERENCES cases(id) ON DELETE SET NULL
      );
    ''');

    await db.execute('''
      CREATE TABLE payments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        case_id INTEGER NOT NULL,
        amount REAL NOT NULL,
        payment_date TEXT NOT NULL,
        method TEXT,
        notes TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (case_id) REFERENCES cases(id) ON DELETE CASCADE
      );
    ''');

    await db.execute('''
      CREATE TABLE attachments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        client_id INTEGER,
        case_id INTEGER,
        file_name TEXT NOT NULL,
        local_path TEXT NOT NULL,
        mime_type TEXT,
        size_bytes INTEGER,
        created_at TEXT NOT NULL,
        FOREIGN KEY (client_id) REFERENCES clients(id) ON DELETE CASCADE,
        FOREIGN KEY (case_id) REFERENCES cases(id) ON DELETE CASCADE
      );
    ''');

    await db.execute('''
      CREATE TABLE office_settings (
        id INTEGER PRIMARY KEY,
        lawyer_name TEXT NOT NULL,
        office_name TEXT NOT NULL,
        logo_path TEXT,
        phone TEXT,
        address TEXT,
        license TEXT
      );
    ''');

    await db.insert('office_settings', const OfficeSettings().toMap());
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
        'ALTER TABLE contracts ADD COLUMN is_certification INTEGER NOT NULL DEFAULT 0',
      );
    }
  }

  // ─────────────────────────────────────────── Clients ───────────────
  Future<int> insertClient(Client c) async {
    final db = await database;
    return db.insert('clients', c.toMap()..remove('id'));
  }

  Future<int> updateClient(Client c) async {
    final db = await database;
    return db.update('clients', c.toMap(), where: 'id = ?', whereArgs: [c.id]);
  }

  Future<int> deleteClient(int id) async {
    final db = await database;
    return db.delete('clients', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Client>> getClients({String? search}) async {
    final db = await database;
    final rows = await db.query(
      'clients',
      where: search != null && search.isNotEmpty
          ? 'full_name LIKE ? OR phone LIKE ? OR national_id LIKE ?'
          : null,
      whereArgs: search != null && search.isNotEmpty
          ? ['%$search%', '%$search%', '%$search%']
          : null,
      orderBy: 'full_name COLLATE NOCASE',
    );
    return rows.map(Client.fromMap).toList();
  }

  Future<Client?> getClient(int id) async {
    final db = await database;
    final rows = await db.query('clients', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Client.fromMap(rows.first);
  }

  // ─────────────────────────────────────────── Cases ─────────────────
  Future<int> insertCase(LegalCase c) async {
    final db = await database;
    final id = await db.insert('cases', c.toMap()..remove('id'));
    if (c.nextSessionDate != null && c.nextSessionDate!.isNotEmpty) {
      await _ensurePendingSession(id, c.nextSessionDate!);
    }
    return id;
  }

  /// Updates a case AND keeps the session-loop in sync.
  /// If [next_session_date] changes, a new pending session row is created
  /// and the case status is bumped to "قيد النظر" if it was just opened.
  Future<int> updateCase(LegalCase c) async {
    final db = await database;
    final existing = await getCase(c.id!);
    final result = await db.update(
      'cases',
      c.toMap(),
      where: 'id = ?',
      whereArgs: [c.id],
    );

    final newDate = c.nextSessionDate;
    if (newDate != null &&
        newDate.isNotEmpty &&
        newDate != existing?.nextSessionDate) {
      await _ensurePendingSession(c.id!, newDate);
      if (c.status == LegalCase.statusOpen) {
        await db.update(
          'cases',
          {'status': LegalCase.statusInProgress},
          where: 'id = ?',
          whereArgs: [c.id],
        );
      }
    }
    return result;
  }

  Future<void> _ensurePendingSession(int caseId, String date) async {
    final db = await database;
    final exists = await db.query(
      'sessions',
      where: 'case_id = ? AND session_date = ? AND status = ?',
      whereArgs: [caseId, date, CaseSession.statusPending],
      limit: 1,
    );
    if (exists.isEmpty) {
      await db.insert(
        'sessions',
        CaseSession(caseId: caseId, sessionDate: date).toMap()..remove('id'),
      );
    }
  }

  Future<int> deleteCase(int id) async {
    final db = await database;
    return db.delete('cases', where: 'id = ?', whereArgs: [id]);
  }

  Future<LegalCase?> getCase(int id) async {
    final db = await database;
    final rows = await db.query('cases', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return LegalCase.fromMap(rows.first);
  }

  Future<List<LegalCase>> getCases({int? clientId, String? search}) async {
    final db = await database;
    final whereParts = <String>[];
    final args = <Object?>[];
    if (clientId != null) {
      whereParts.add('client_id = ?');
      args.add(clientId);
    }
    if (search != null && search.isNotEmpty) {
      whereParts.add(
        '(case_number LIKE ? OR title LIKE ? OR court_name LIKE ?)',
      );
      args.addAll(['%$search%', '%$search%', '%$search%']);
    }
    final rows = await db.query(
      'cases',
      where: whereParts.isEmpty ? null : whereParts.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'created_at DESC',
    );
    return rows.map(LegalCase.fromMap).toList();
  }

  /// Joined view for the finance drill-down screen.
  Future<List<Map<String, dynamic>>> getCasesWithClient() async {
    final db = await database;
    return db.rawQuery('''
      SELECT cases.*, clients.full_name AS client_name
      FROM cases
      INNER JOIN clients ON clients.id = cases.client_id
      ORDER BY cases.created_at DESC
    ''');
  }

  // ─────────────────────────────────────────── Sessions ──────────────
  Future<int> insertSession(CaseSession s) async {
    final db = await database;
    return db.insert('sessions', s.toMap()..remove('id'));
  }

  Future<int> updateSession(CaseSession s) async {
    final db = await database;
    return db.update('sessions', s.toMap(), where: 'id = ?', whereArgs: [s.id]);
  }

  Future<int> deleteSession(int id) async {
    final db = await database;
    return db.delete('sessions', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<CaseSession>> getSessions({int? caseId}) async {
    final db = await database;
    final rows = await db.query(
      'sessions',
      where: caseId != null ? 'case_id = ?' : null,
      whereArgs: caseId != null ? [caseId] : null,
      orderBy: 'session_date ASC',
    );
    return rows.map(CaseSession.fromMap).toList();
  }

  /// Court agenda: every session joined with its case + client.
  Future<List<Map<String, dynamic>>> getAgenda({
    DateTime? from,
    DateTime? to,
    String? statusFilter,
  }) async {
    final db = await database;
    final where = <String>[];
    final args = <Object?>[];
    if (from != null) {
      where.add('sessions.session_date >= ?');
      args.add(from.toIso8601String());
    }
    if (to != null) {
      where.add('sessions.session_date <= ?');
      args.add(to.toIso8601String());
    }
    if (statusFilter != null) {
      where.add('sessions.status = ?');
      args.add(statusFilter);
    }
    final whereSql = where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}';
    return db.rawQuery('''
      SELECT sessions.*, cases.case_number, cases.title AS case_title,
             cases.court_name, clients.full_name AS client_name
      FROM sessions
      INNER JOIN cases   ON cases.id   = sessions.case_id
      INNER JOIN clients ON clients.id = cases.client_id
      $whereSql
      ORDER BY sessions.session_date ASC
    ''', args);
  }

  // ─────────────────────────────────────────── Contracts ─────────────
  Future<int> insertContract(Contract c) async {
    final db = await database;
    return db.insert('contracts', c.toMap()..remove('id'));
  }

  Future<int> updateContract(Contract c) async {
    final db = await database;
    return db.update(
      'contracts',
      c.toMap(),
      where: 'id = ?',
      whereArgs: [c.id],
    );
  }

  Future<int> deleteContract(int id) async {
    final db = await database;
    return db.delete('contracts', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Contract>> getContracts() async {
    final db = await database;
    final rows = await db.query('contracts', orderBy: 'created_at DESC');
    return rows.map(Contract.fromMap).toList();
  }

  Future<Contract?> getContract(int id) async {
    final db = await database;
    final rows = await db.query('contracts', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Contract.fromMap(rows.first);
  }

  // ─────────────────────────────────────────── Payments ──────────────
  /// Records a payment AND increments cases.paid in the same transaction.
  Future<int> insertPayment(Payment p) async {
    final db = await database;
    return db.transaction((txn) async {
      final id = await txn.insert('payments', p.toMap()..remove('id'));
      await txn.rawUpdate('UPDATE cases SET paid = paid + ? WHERE id = ?', [
        p.amount,
        p.caseId,
      ]);
      return id;
    });
  }

  Future<int> deletePayment(Payment p) async {
    final db = await database;
    return db.transaction((txn) async {
      final affected = await txn.delete(
        'payments',
        where: 'id = ?',
        whereArgs: [p.id],
      );
      await txn.rawUpdate(
        'UPDATE cases SET paid = MAX(0, paid - ?) WHERE id = ?',
        [p.amount, p.caseId],
      );
      return affected;
    });
  }

  Future<List<Payment>> getPayments({int? caseId, int? clientId}) async {
    final db = await database;
    if (clientId != null) {
      final rows = await db.rawQuery(
        '''
        SELECT payments.*
        FROM payments
        INNER JOIN cases ON cases.id = payments.case_id
        WHERE cases.client_id = ?
        ORDER BY payments.payment_date DESC
      ''',
        [clientId],
      );
      return rows.map(Payment.fromMap).toList();
    }
    final rows = await db.query(
      'payments',
      where: caseId != null ? 'case_id = ?' : null,
      whereArgs: caseId != null ? [caseId] : null,
      orderBy: 'payment_date DESC',
    );
    return rows.map(Payment.fromMap).toList();
  }

  // ─────────────────────────────────────────── Attachments ───────────
  Future<int> insertAttachment(Attachment a) async {
    final db = await database;
    return db.insert('attachments', a.toMap()..remove('id'));
  }

  Future<int> deleteAttachment(int id) async {
    final db = await database;
    return db.delete('attachments', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Attachment>> getAttachments({int? clientId, int? caseId}) async {
    final db = await database;
    final where = <String>[];
    final args = <Object?>[];
    if (clientId != null) {
      where.add('client_id = ?');
      args.add(clientId);
    }
    if (caseId != null) {
      where.add('case_id = ?');
      args.add(caseId);
    }
    final rows = await db.query(
      'attachments',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'created_at DESC',
    );
    return rows.map(Attachment.fromMap).toList();
  }

  // ─────────────────────────────────────────── Office Settings ───────
  Future<OfficeSettings> getSettings() async {
    final db = await database;
    final rows = await db.query('office_settings', limit: 1);
    if (rows.isEmpty) {
      const defaults = OfficeSettings();
      await db.insert('office_settings', defaults.toMap());
      return defaults;
    }
    return OfficeSettings.fromMap(rows.first);
  }

  Future<void> updateSettings(OfficeSettings s) async {
    final db = await database;
    await db.update(
      'office_settings',
      s.toMap(),
      where: 'id = ?',
      whereArgs: [s.id ?? 1],
    );
  }

  // ─────────────────────────────────────────── Analytics ─────────────
  Future<Map<String, double>> getFinanceTotals() async {
    final db = await database;
    final r = await db.rawQuery('''
      SELECT
        COALESCE(SUM(fees), 0)               AS total_fees,
        COALESCE(SUM(paid), 0)               AS total_paid,
        COALESCE(SUM(MAX(fees - paid, 0)),0) AS total_outstanding
      FROM cases
    ''');
    final row = r.first;
    return {
      'fees': (row['total_fees'] as num).toDouble(),
      'paid': (row['total_paid'] as num).toDouble(),
      'outstanding': (row['total_outstanding'] as num).toDouble(),
    };
  }

  Future<Map<String, int>> getCounters() async {
    final db = await database;
    final clients =
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM clients'),
        ) ??
        0;
    final cases =
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM cases'),
        ) ??
        0;
    final openCases =
        Sqflite.firstIntValue(
          await db.rawQuery("SELECT COUNT(*) FROM cases WHERE status != ?", [
            LegalCase.statusClosed,
          ]),
        ) ??
        0;
    final upcoming =
        Sqflite.firstIntValue(
          await db.rawQuery(
            '''
      SELECT COUNT(*) FROM sessions
      WHERE status = ? AND session_date >= ?
    ''',
            [CaseSession.statusPending, DateTime.now().toIso8601String()],
          ),
        ) ??
        0;
    final contracts =
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM contracts'),
        ) ??
        0;
    return {
      'clients': clients,
      'cases': cases,
      'openCases': openCases,
      'upcoming': upcoming,
      'contracts': contracts,
    };
  }
}
