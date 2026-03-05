import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/payment.dart';

class QueueService {
  static Database? _db;

  static Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  static Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'payment_queue.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE pending_payments (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            source TEXT NOT NULL,
            reference_number TEXT NOT NULL,
            amount REAL NOT NULL,
            sender_phone TEXT,
            timestamp TEXT NOT NULL,
            sync_status TEXT NOT NULL DEFAULT 'pending',
            created_at TEXT NOT NULL,
            raw_sms TEXT NOT NULL
          )
        ''');
      },
    );
  }

  /// Insert a payment into the local queue with status=pending.
  static Future<Payment> enqueue(Payment payment) async {
    final db = await database;
    final map = payment.toMap()..remove('id');
    final id = await db.insert('pending_payments', map);
    return payment.copyWith(id: id);
  }

  /// Return all payments ordered by createdAt desc.
  static Future<List<Payment>> getAllPayments() async {
    final db = await database;
    final rows = await db.query('pending_payments', orderBy: 'created_at DESC');
    return rows.map(Payment.fromMap).toList();
  }

  /// Return only pending payments.
  static Future<List<Payment>> getPendingPayments() async {
    final db = await database;
    final rows = await db.query(
      'pending_payments',
      where: 'sync_status = ?',
      whereArgs: ['pending'],
      orderBy: 'created_at ASC',
    );
    return rows.map(Payment.fromMap).toList();
  }

  /// Count of payments that haven't been synced yet.
  static Future<int> getPendingCount() async {
    final db = await database;
    final result = await db.rawQuery(
      "SELECT COUNT(*) as cnt FROM pending_payments WHERE sync_status = 'pending'",
    );
    return (result.first['cnt'] as int?) ?? 0;
  }

  /// Update a payment's sync status by id.
  static Future<void> updateStatus(int id, SyncStatus status) async {
    final db = await database;
    await db.update(
      'pending_payments',
      {'sync_status': status.name},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Delete all synced records older than [days].
  static Future<void> cleanOldSynced({int days = 30}) async {
    final db = await database;
    final cutoff = DateTime.now()
        .subtract(Duration(days: days))
        .toIso8601String();
    await db.delete(
      'pending_payments',
      where: "sync_status = 'synced' AND created_at < ?",
      whereArgs: [cutoff],
    );
  }
}
