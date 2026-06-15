import 'dart:io';

import 'package:edtech/global/core/services/logger_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class UploadQueueItem {
  final int? id;
  final String filePath;
  final String title;
  final int videoDuration;
  final int fileSize;
  final String? uploadUrl;
  final String? fileUrl;
  final String status;
  final int bytesUploaded;
  final String? errorMessage;
  final String createdAt;

  UploadQueueItem({
    this.id,
    required this.filePath,
    required this.title,
    required this.videoDuration,
    required this.fileSize,
    this.uploadUrl,
    this.fileUrl,
    this.status = 'pending',
    this.bytesUploaded = 0,
    this.errorMessage,
    String? createdAt,
  }) : createdAt = createdAt ?? DateTime.now().toIso8601String();

  UploadQueueItem copyWith({
    int? id,
    String? filePath,
    String? title,
    int? videoDuration,
    int? fileSize,
    String? uploadUrl,
    String? fileUrl,
    String? status,
    int? bytesUploaded,
    String? errorMessage,
    String? createdAt,
  }) {
    return UploadQueueItem(
      id: id ?? this.id,
      filePath: filePath ?? this.filePath,
      title: title ?? this.title,
      videoDuration: videoDuration ?? this.videoDuration,
      fileSize: fileSize ?? this.fileSize,
      uploadUrl: uploadUrl ?? this.uploadUrl,
      fileUrl: fileUrl ?? this.fileUrl,
      status: status ?? this.status,
      bytesUploaded: bytesUploaded ?? this.bytesUploaded,
      errorMessage: errorMessage ?? this.errorMessage,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'filePath': filePath,
      'title': title,
      'videoDuration': videoDuration,
      'fileSize': fileSize,
      'uploadUrl': uploadUrl,
      'fileUrl': fileUrl,
      'status': status,
      'bytesUploaded': bytesUploaded,
      'errorMessage': errorMessage,
      'createdAt': createdAt,
    };
  }

  factory UploadQueueItem.fromMap(Map<String, dynamic> map) {
    return UploadQueueItem(
      id: map['id'] as int?,
      filePath: map['filePath'] as String,
      title: map['title'] as String,
      videoDuration: map['videoDuration'] as int,
      fileSize: map['fileSize'] as int,
      uploadUrl: map['uploadUrl'] as String?,
      fileUrl: map['fileUrl'] as String?,
      status: map['status'] as String? ?? 'pending',
      bytesUploaded: map['bytesUploaded'] as int? ?? 0,
      errorMessage: map['errorMessage'] as String?,
      createdAt: map['createdAt'] as String?,
    );
  }
}

class UploadQueueRepository {
  static Database? _db;

  static Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  static Future<Database> _initDb() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}${Platform.pathSeparator}upload_queue.db';
    AppLogger.i('UploadQueueRepository: opening database at $path');
    return openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE upload_queue (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            filePath TEXT NOT NULL,
            title TEXT NOT NULL,
            videoDuration INTEGER NOT NULL DEFAULT 0,
            fileSize INTEGER NOT NULL DEFAULT 0,
            uploadUrl TEXT,
            fileUrl TEXT,
            status TEXT NOT NULL DEFAULT 'pending',
            bytesUploaded INTEGER NOT NULL DEFAULT 0,
            errorMessage TEXT,
            createdAt TEXT NOT NULL
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_upload_queue_status ON upload_queue(status)',
        );
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('DROP TABLE IF EXISTS upload_queue');
          await db.execute('''
            CREATE TABLE upload_queue (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              filePath TEXT NOT NULL,
              title TEXT NOT NULL,
              videoDuration INTEGER NOT NULL DEFAULT 0,
              fileSize INTEGER NOT NULL DEFAULT 0,
              uploadUrl TEXT,
              fileUrl TEXT,
              status TEXT NOT NULL DEFAULT 'pending',
              bytesUploaded INTEGER NOT NULL DEFAULT 0,
              errorMessage TEXT,
              createdAt TEXT NOT NULL
            )
          ''');
          await db.execute(
            'CREATE INDEX idx_upload_queue_status ON upload_queue(status)',
          );
        }
      },
    );
  }

  static Future<int> insert(UploadQueueItem item) async {
    final db = await database;
    final id = await db.insert('upload_queue', item.toMap());
    AppLogger.i('UploadQueueRepository: inserted item id=$id, title=${item.title}');
    return id;
  }

  static Future<UploadQueueItem?> getNextPending() async {
    final db = await database;
    final maps = await db.query(
      'upload_queue',
      where: 'status = ?',
      whereArgs: ['pending'],
      orderBy: 'id ASC',
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return UploadQueueItem.fromMap(maps.first);
  }

  static Future<List<UploadQueueItem>> getAll() async {
    final db = await database;
    final maps = await db.query(
      'upload_queue',
      orderBy: 'id ASC',
    );
    return maps.map((m) => UploadQueueItem.fromMap(m)).toList();
  }

  static Future<List<UploadQueueItem>> getActive() async {
    final db = await database;
    final maps = await db.query(
      'upload_queue',
      where: 'status != ? AND status != ?',
      whereArgs: ['completed', 'failed'],
      orderBy: 'id ASC',
    );
    return maps.map((m) => UploadQueueItem.fromMap(m)).toList();
  }

  static Future<void> updateUrls({
    required int id,
    required String uploadUrl,
    required String fileUrl,
  }) async {
    final db = await database;
    await db.update(
      'upload_queue',
      {
        'uploadUrl': uploadUrl,
        'fileUrl': fileUrl,
        'status': 'uploading',
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static Future<void> updateProgress({
    required int id,
    required int bytesUploaded,
  }) async {
    final db = await database;
    await db.update(
      'upload_queue',
      {'bytesUploaded': bytesUploaded},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static Future<void> markCompleted(int id) async {
    final db = await database;
    await db.update(
      'upload_queue',
      {'status': 'completed', 'bytesUploaded': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static Future<void> markFailed(int id, String error) async {
    final db = await database;
    await db.update(
      'upload_queue',
      {'status': 'failed', 'errorMessage': error},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static Future<void> updateStatus({
    required int id,
    required String status,
    int? bytesUploaded,
    String? errorMessage,
  }) async {
    final db = await database;
    final values = <String, dynamic>{'status': status};
    if (bytesUploaded != null) values['bytesUploaded'] = bytesUploaded;
    if (errorMessage != null) values['errorMessage'] = errorMessage;
    await db.update('upload_queue', values, where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> deleteItem(int id) async {
    final db = await database;
    await db.delete('upload_queue', where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> clearCompleted() async {
    final db = await database;
    await db.delete('upload_queue', where: 'status = ?', whereArgs: ['completed']);
  }

  static Future<int> countPending() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM upload_queue WHERE status = ?',
      ['pending'],
    );
    return (result.first['cnt'] as int?) ?? 0;
  }

  static Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
