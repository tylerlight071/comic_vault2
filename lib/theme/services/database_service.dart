// lib/theme/services/database_service.dart

// ignore_for_file: deprecated_member_use

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:path/path.dart';
import '../models/comic.dart';
import 'comic_vine_service.dart';
import 'encryption_service.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._();
  DatabaseService._();

  Database? _db;
  bool _ftsAvailable = false;

  Future<void> init() async {
    final dbPath   = await getDatabasesPath();
    final fullPath = join(dbPath, 'comic_vault.db');

    // Retrieve (or generate) the SQLCipher AES-256 encryption key.
    final dbKey = await EncryptionService.getOrCreateDbKey();

    // One-time migration: encrypt any pre-existing plain SQLite database.
    await _encryptExistingDbIfNeeded(fullPath, dbKey);

    _db = await openDatabase(
      fullPath,
      password: dbKey,
      version: 9,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE comics (
            id              INTEGER PRIMARY KEY AUTOINCREMENT,
            comicVineId     TEXT    NOT NULL,
            volumeId        TEXT,
            title           TEXT    NOT NULL,
            seriesName      TEXT    NOT NULL,
            issueNumber     TEXT,
            publicationYear INTEGER,
            publisher       TEXT,
            description     TEXT,
            coverImageUrl   TEXT,
            writers         TEXT,
            artists         TEXT,
            barcode         TEXT,
            isRead          INTEGER NOT NULL DEFAULT 0,
            starRating      INTEGER NOT NULL DEFAULT 0,
            isWishlisted    INTEGER NOT NULL DEFAULT 0,
            addedDate       TEXT    NOT NULL,
            readDate        TEXT,
            isReading       INTEGER NOT NULL DEFAULT 0,
            notes           TEXT,
            condition       TEXT,
            purchasePrice   REAL,
            loanedTo        TEXT,
            tags            TEXT
          )
        ''');

        // ── Indexes ──────────────────────────────────────────────────────
        // These turn full table scans into O(log n) lookups for the most
        // common query patterns.
        await _createIndexes(db);

        // FTS for fast text search
        try {
          await db.execute('''
            CREATE VIRTUAL TABLE comics_fts USING fts4(
              title, seriesName, issueNumber, publisher, description,
              writers, artists, barcode,
              content='comics',
              content_rowid='id'
            )
          ''');
        } catch (_) {}

        await db.execute('''
          CREATE TABLE search_history (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            query       TEXT    NOT NULL,
            timestamp   TEXT    NOT NULL,
            resultCount INTEGER NOT NULL DEFAULT 0,
            isFavorite  INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_search_history_ts ON search_history(timestamp DESC)');

        await db.execute('''
          CREATE TABLE barcode_history (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            barcode     TEXT    NOT NULL UNIQUE,
            timestamp   TEXT    NOT NULL,
            comicVineId TEXT
          )
        ''');
      },
      onOpen: (db) async {
        final rows = await db.rawQuery(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='comics_fts'");
        _ftsAvailable = rows.isNotEmpty;
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          try { await db.execute('ALTER TABLE comics ADD COLUMN volumeId TEXT'); } catch (_) {}
          try { await db.execute('ALTER TABLE comics ADD COLUMN isWishlisted INTEGER NOT NULL DEFAULT 0'); } catch (_) {}
        }
        if (oldVersion < 3) {
          try {
            await db.execute('''
              CREATE VIRTUAL TABLE comics_fts USING fts4(
                title, seriesName, issueNumber, publisher, description,
                writers, artists, barcode,
                content='comics',
                content_rowid='id'
              )
            ''');
            final comics = await db.query('comics');
            for (final comic in comics) {
              await db.insert('comics_fts', {
                'rowid': comic['id'],
                'title': comic['title'] ?? '',
                'seriesName': comic['seriesName'] ?? '',
                'issueNumber': comic['issueNumber'] ?? '',
                'publisher': comic['publisher'] ?? '',
                'description': comic['description'] ?? '',
                'writers': comic['writers'] ?? '',
                'artists': comic['artists'] ?? '',
                'barcode': comic['barcode'] ?? '',
              }, conflictAlgorithm: ConflictAlgorithm.replace);
            }
          } catch (_) {}

          try {
            await db.execute('''
              CREATE TABLE search_history (
                id          INTEGER PRIMARY KEY AUTOINCREMENT,
                query       TEXT    NOT NULL,
                timestamp   TEXT    NOT NULL,
                resultCount INTEGER NOT NULL DEFAULT 0,
                isFavorite  INTEGER NOT NULL DEFAULT 0
              )
            ''');
            await db.execute(
              'CREATE INDEX IF NOT EXISTS idx_search_history_ts ON search_history(timestamp DESC)');
          } catch (_) {}

          try {
            await db.execute('''
              CREATE TABLE barcode_history (
                id          INTEGER PRIMARY KEY AUTOINCREMENT,
                barcode     TEXT    NOT NULL UNIQUE,
                timestamp   TEXT    NOT NULL,
                comicVineId TEXT
              )
            ''');
          } catch (_) {}
        }
        if (oldVersion < 4) {
          // Add indexes to existing databases upgrading from v1–v3
          await _createIndexes(db);
        }
        if (oldVersion < 5) {
          // Add barcode + composite series indexes, and search_history timestamp index
          await _createIndexes(db);
          try {
            await db.execute(
              'CREATE INDEX IF NOT EXISTS idx_search_history_ts ON search_history(timestamp DESC)');
          } catch (_) {}
        }
        if (oldVersion < 6) {
          // Create FTS table if it was missed by earlier migrations, then populate it
          try {
            await db.execute('''
              CREATE VIRTUAL TABLE IF NOT EXISTS comics_fts USING fts4(
                title, seriesName, issueNumber, publisher, description,
                writers, artists, barcode,
                content='comics',
                content_rowid='id'
              )
            ''');
            // Populate from existing comics
            final comics = await db.query('comics');
            for (final comic in comics) {
              await db.insert('comics_fts', {
                'rowid': comic['id'],
                'title': comic['title'] ?? '',
                'seriesName': comic['seriesName'] ?? '',
                'issueNumber': comic['issueNumber'] ?? '',
                'publisher': comic['publisher'] ?? '',
                'description': comic['description'] ?? '',
                'writers': comic['writers'] ?? '',
                'artists': comic['artists'] ?? '',
                'barcode': comic['barcode'] ?? '',
              }, conflictAlgorithm: ConflictAlgorithm.replace);
            }
          } catch (_) {}
        }
        if (oldVersion < 7) {
          try { await db.execute('ALTER TABLE comics ADD COLUMN readDate TEXT'); } catch (_) {}
          try { await db.execute('ALTER TABLE comics ADD COLUMN isReading INTEGER NOT NULL DEFAULT 0'); } catch (_) {}
          try { await db.execute('ALTER TABLE comics ADD COLUMN notes TEXT'); } catch (_) {}
          try { await db.execute('ALTER TABLE comics ADD COLUMN condition TEXT'); } catch (_) {}
        }
        if (oldVersion < 8) {
          try { await db.execute('ALTER TABLE comics ADD COLUMN purchasePrice REAL'); } catch (_) {}
          try { await db.execute('ALTER TABLE comics ADD COLUMN loanedTo TEXT'); } catch (_) {}
          try { await db.execute('ALTER TABLE comics ADD COLUMN tags TEXT'); } catch (_) {}
        }
        if (oldVersion < 9) {
          // Encrypt existing plaintext notes and loanedTo values.
          final enc = EncryptionService.instance;
          final rows = await db.query('comics',
              columns: ['id', 'notes', 'loanedTo']);
          for (final row in rows) {
            final notes    = row['notes']    as String?;
            final loanedTo = row['loanedTo'] as String?;
            final updates  = <String, dynamic>{};
            if (notes    != null && !notes.startsWith('__enc__'))
              updates['notes']    = enc.encrypt(notes);
            if (loanedTo != null && !loanedTo.startsWith('__enc__'))
              updates['loanedTo'] = enc.encrypt(loanedTo);
            if (updates.isNotEmpty) {
              await db.update('comics', updates,
                  where: 'id = ?', whereArgs: [row['id']]);
            }
          }
        }
      },
    );
  }

  /// Creates indexes on the columns most commonly used in WHERE clauses and
  /// ORDER BY expressions. Safe to call on both new and upgraded databases —
  /// uses IF NOT EXISTS so it never throws on re-run.
  static Future<void> _createIndexes(Database db) async {
    // isWishlisted — every getAllComics / getWishlist query filters on this
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_comics_wishlisted ON comics(isWishlisted)');
    // addedDate — default sort order for getAllComics
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_comics_added ON comics(addedDate DESC)');
    // comicVineId — used by comicExists, getComicByVineId, moveWishlistToLibrary
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_comics_vine_id ON comics(comicVineId)');
    // seriesName — used by series tracker grouping and wishlist A-Z sort
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_comics_series ON comics(seriesName)');
    // Composite for the most common combined filter
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_comics_wishlisted_added ON comics(isWishlisted, addedDate DESC)');
    // barcode — scanned on every barcode lookup, previously unindexed
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_comics_barcode ON comics(barcode)');
    // Composite series+issue for grouped list view sorting
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_comics_series_issue ON comics(seriesName, issueNumber)');
  }

  Database get _database {
    if (_db == null) throw StateError('Database not initialised.');
    return _db!;
  }

  // ── SQLCipher migration ────────────────────────────────────────────────────
  //
  // Encrypts an existing plain-text SQLite database in place using SQLCipher's
  // PRAGMA rekey. The original file is backed up before the operation; if
  // anything goes wrong the backup is restored so no data is ever lost.
  // A flag in secure storage prevents re-running the migration on every launch.

  static Future<void> _encryptExistingDbIfNeeded(
      String path, String key) async {
    const flagKey = 'db_sqlcipher_migrated';
    if (await EncryptionService.secureRead(flagKey) == '1') return;

    final file = File(path);
    if (!await file.exists()) {
      // Fresh install — DB will be created encrypted; nothing to migrate.
      await EncryptionService.secureWrite(flagKey, '1');
      return;
    }

    final backup = File('$path.bak');
    try {
      // Backup the original before touching it.
      await file.copy(backup.path);

      // Open without a password: SQLCipher treats this as plain-text mode,
      // which is backwards-compatible with standard SQLite files.
      final db = await openDatabase(path);

      // Re-key encrypts the database in place with AES-256.
      await db.execute("PRAGMA rekey = '$key'");
      await db.close();

      await backup.delete().catchError((_) => backup);
      await EncryptionService.secureWrite(flagKey, '1');
    } catch (e) {
      // Migration failed — restore the original file so data is preserved.
      // The app continues with the unencrypted DB; field-level encryption
      // (notes, loanedTo) still protects the most sensitive columns.
      debugPrint('[DB] SQLCipher migration failed: $e — restoring backup');
      if (await backup.exists()) {
        try {
          if (await file.exists()) await file.delete();
          await backup.rename(path);
        } catch (restoreErr) {
          debugPrint('[DB] Backup restore also failed: $restoreErr');
        }
      }
      // Leave the flag unset so we retry on the next launch.
    }
  }

  // ── Field-level encryption helpers ────────────────────────────────────────

  static Map<String, dynamic> _encryptRow(Map<String, dynamic> map) {
    final enc = EncryptionService.instance;
    final result = Map<String, dynamic>.from(map);
    if (result['notes']    case final String v) result['notes']    = enc.encrypt(v);
    if (result['loanedTo'] case final String v) result['loanedTo'] = enc.encrypt(v);
    return result;
  }

  static Map<String, dynamic> _decryptRow(Map<String, dynamic> row) {
    final enc = EncryptionService.instance;
    final result = Map<String, dynamic>.from(row);
    if (result['notes']    case final String v) result['notes']    = enc.decrypt(v);
    if (result['loanedTo'] case final String v) result['loanedTo'] = enc.decrypt(v);
    return result;
  }

  // ── Library CRUD ──────────────────────────────────────────────────────────

  Future<int> insertComic(Comic comic) async {
    final id = await _database.insert('comics', _encryptRow(comic.toMap()),
        conflictAlgorithm: ConflictAlgorithm.replace);
    try {
      await _database.insert('comics_fts', {
        'rowid': id,
        'title': comic.title,
        'seriesName': comic.seriesName,
        'issueNumber': comic.issueNumber ?? '',
        'publisher': comic.publisher ?? '',
        'description': comic.description ?? '',
        'writers': comic.writers ?? '',
        'artists': comic.artists ?? '',
        'barcode': comic.barcode ?? '',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (e) {
      debugPrint('[DB] FTS insert failed for comic $id: $e');
    }
    return id;
  }

  Future<List<Comic>> getAllComics() async {
    final rows = await _database.query(
      'comics',
      where: 'isWishlisted = 0',
      orderBy: 'addedDate DESC',
    );
    return rows.map((r) => Comic.fromMap(_decryptRow(r))).toList();
  }

  Future<void> updateComic(Comic comic) async {
    await _database.update('comics', _encryptRow(comic.toMap()),
        where: 'id = ?', whereArgs: [comic.id]);
    try {
      await _database.insert('comics_fts', {
        'rowid': comic.id,
        'title': comic.title,
        'seriesName': comic.seriesName,
        'issueNumber': comic.issueNumber ?? '',
        'publisher': comic.publisher ?? '',
        'description': comic.description ?? '',
        'writers': comic.writers ?? '',
        'artists': comic.artists ?? '',
        'barcode': comic.barcode ?? '',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (e) {
      debugPrint('[DB] FTS update failed for comic ${comic.id}: $e');
    }
  }

  Future<void> deleteComic(int id) async {
    await _database.delete('comics', where: 'id = ?', whereArgs: [id]);
    try {
      await _database.delete('comics_fts', where: 'rowid = ?', whereArgs: [id]);
    } catch (e) {
      debugPrint('[DB] FTS delete failed for comic $id: $e');
    }
  }

  Future<void> deleteAllComics() async {
    await _database.delete('comics');
    try {
      await _database.delete('comics_fts');
    } catch (e) {
      debugPrint('[DB] FTS clear failed: $e');
    }
  }

  Future<bool> comicExists(String comicVineId) async {
    final rows = await _database.query('comics',
        columns: ['id'],
        where: 'comicVineId = ? AND isWishlisted = 0',
        whereArgs: [comicVineId],
        limit: 1);
    return rows.isNotEmpty;
  }

  /// Returns `(inLibrary, inWishlist)` in a single DB round-trip.
  Future<({bool inLibrary, bool inWishlist})> checkComicStatus(
      String comicVineId) async {
    final rows = await _database.query('comics',
        columns: ['isWishlisted'],
        where: 'comicVineId = ?',
        whereArgs: [comicVineId]);
    bool inLibrary  = false;
    bool inWishlist = false;
    for (final r in rows) {
      if ((r['isWishlisted'] as int) == 0) inLibrary  = true;
      if ((r['isWishlisted'] as int) == 1) inWishlist = true;
    }
    return (inLibrary: inLibrary, inWishlist: inWishlist);
  }

  Future<Comic?> getComicByVineId(String comicVineId) async {
    final rows = await _database.query('comics',
        where: 'comicVineId = ? AND isWishlisted = 0',
        whereArgs: [comicVineId],
        limit: 1);
    if (rows.isEmpty) return null;
    return Comic.fromMap(_decryptRow(rows.first));
  }

  // ── Wishlist ──────────────────────────────────────────────────────────────

  Future<List<Comic>> getWishlist() async {
    final rows = await _database.query('comics',
        where: 'isWishlisted = 1',
        orderBy: 'seriesName ASC, CAST(issueNumber AS REAL) ASC');
    return rows.map((r) => Comic.fromMap(_decryptRow(r))).toList();
  }

  Future<bool> isOnWishlist(String comicVineId) async {
    final rows = await _database.query('comics',
        columns: ['id'],
        where: 'comicVineId = ? AND isWishlisted = 1',
        whereArgs: [comicVineId],
        limit: 1);
    return rows.isNotEmpty;
  }

  Future<int> getWishlistCount() async {
    final rows = await _database.rawQuery(
        'SELECT COUNT(*) AS cnt FROM comics WHERE isWishlisted = 1');
    return (rows.first['cnt'] as int?) ?? 0;
  }

  Future<void> addToWishlist(Comic comic) async {
    // Single-query check + insert inside a transaction to avoid TOCTOU races.
    await _database.transaction((txn) async {
      final existing = await txn.query('comics',
          columns: ['id'],
          where: 'comicVineId = ?',
          whereArgs: [comic.comicVineId],
          limit: 1);
      if (existing.isNotEmpty) return; // already in library or wishlist
      await txn.insert('comics', comic.copyWith(isWishlisted: true).toMap(),
          conflictAlgorithm: ConflictAlgorithm.ignore);
    });
  }

  Future<void> removeFromWishlist(String comicVineId) async {
    await _database.delete('comics',
        where: 'comicVineId = ? AND isWishlisted = 1',
        whereArgs: [comicVineId]);
  }

  Future<void> moveWishlistToLibrary(String comicVineId) async {
    await _database.update('comics', {'isWishlisted': 0},
        where: 'comicVineId = ? AND isWishlisted = 1',
        whereArgs: [comicVineId]);
  }

  // ── Status helpers ────────────────────────────────────────────────────────

  Future<Set<String>> getOwnedIds() async {
    final rows = await _database.query('comics',
        columns: ['comicVineId'], where: 'isWishlisted = 0');
    return rows.map((r) => r['comicVineId'] as String).toSet();
  }

  Future<Set<String>> getWishlistIds() async {
    final rows = await _database.query('comics',
        columns: ['comicVineId'], where: 'isWishlisted = 1');
    return rows.map((r) => r['comicVineId'] as String).toSet();
  }

  Future<Set<String>> getReadIds() async {
    final rows = await _database.query('comics',
        columns: ['comicVineId'],
        where: 'isWishlisted = 0 AND isRead = 1');
    return rows.map((r) => r['comicVineId'] as String).toSet();
  }

  // ── Data Refresh ──────────────────────────────────────────────────────────

  Future<void> refreshAllComics({
    void Function(int done, int total)? onProgress,
  }) async {
    final rows = await _database.query('comics',
        columns: ['id', 'comicVineId', 'barcode']);
    final total = rows.length;

    // Process up to 3 comics concurrently to keep total refresh time reasonable
    // while staying within Comic Vine API rate limits.
    const batchSize = 3;
    var done = 0;

    for (var start = 0; start < rows.length; start += batchSize) {
      final batch = rows.sublist(start,
          (start + batchSize).clamp(0, rows.length));

      await Future.wait(batch.map((row) async {
        final rowId       = row['id'] as int;
        final comicVineId = row['comicVineId'] as String;
        try {
          final fresh = await ComicVineService.instance.fetchIssueById(comicVineId);
          if (fresh != null) {
            await _database.transaction((txn) async {
              await txn.update('comics', {
                'volumeId':        fresh.volumeId,
                'title':           fresh.title,
                'seriesName':      fresh.seriesName,
                'issueNumber':     fresh.issueNumber,
                'publicationYear': fresh.publicationYear,
                'publisher':       fresh.publisher,
                'description':     fresh.description,
                'coverImageUrl':   fresh.coverImageUrl,
                'writers':         fresh.writers,
                'artists':         fresh.artists,
              }, where: 'comicVineId = ?', whereArgs: [comicVineId]);
              await txn.insert('comics_fts', {
                'rowid':       rowId,
                'title':       fresh.title,
                'seriesName':  fresh.seriesName,
                'issueNumber': fresh.issueNumber ?? '',
                'publisher':   fresh.publisher ?? '',
                'description': fresh.description ?? '',
                'writers':     fresh.writers ?? '',
                'artists':     fresh.artists ?? '',
                'barcode':     row['barcode'] as String? ?? '',
              }, conflictAlgorithm: ConflictAlgorithm.replace);
            });
          }
        } catch (e) {
          debugPrint('[DB] Refresh failed for $comicVineId: $e');
        }
        onProgress?.call(++done, total);
      }));

      // Brief pause between batches to avoid hammering the API.
      if (start + batchSize < rows.length) {
        await Future.delayed(const Duration(milliseconds: 250));
      }
    }
  }

  // ── Local Search ──────────────────────────────────────────────────────────

  /// Appends optional filter clauses to [conditions] and their bind values to
  /// [args]. Extracted to avoid duplicating the same logic across the FTS path
  /// and the LIKE fallback path inside [searchComics].
  static void _applySearchFilters(
    List<String> conditions,
    List<dynamic> args, {
    required bool includeWishlist,
    required int? minRating,
    required bool? isRead,
    required String? publisher,
    required int? publicationYear,
  }) {
    if (!includeWishlist) {
      conditions.add('isWishlisted = 0');
    }
    if (minRating != null) {
      conditions.add('starRating >= ?');
      args.add(minRating);
    }
    if (isRead != null) {
      conditions.add('isRead = ?');
      args.add(isRead ? 1 : 0);
    }
    if (publisher != null && publisher.isNotEmpty) {
      conditions.add('publisher LIKE ?');
      args.add('%$publisher%');
    }
    if (publicationYear != null) {
      conditions.add('publicationYear = ?');
      args.add(publicationYear);
    }
  }

  Future<List<Comic>> searchComics(String query, {
    bool includeWishlist = true,
    int? minRating,
    bool? isRead,
    String? publisher,
    int? publicationYear,
    int limit = 50,
    int offset = 0,
  }) async {
    if (query.trim().isEmpty) {
      final where = includeWishlist ? null : 'isWishlisted = 0';
      final rows = await _database.query(
        'comics',
        where: where,
        orderBy: 'addedDate DESC',
        limit: limit,
        offset: offset,
      );
      return rows.map((r) => Comic.fromMap(_decryptRow(r))).toList();
    }

    final trimmedQuery = query.trim();
    List<Map<String, dynamic>> rows;

    try {
      if (!_ftsAvailable) throw Exception('FTS unavailable');
      final ftsQuery = trimmedQuery.split(' ').map((word) => '"$word"*').join(' OR ');
      final ftsRows = await _database.rawQuery('''
        SELECT rowid, rank
        FROM comics_fts
        WHERE comics_fts MATCH ?
        ORDER BY rank
        LIMIT ? OFFSET ?
      ''', [ftsQuery, limit, offset]);

      if (ftsRows.isNotEmpty) {
        final ids = ftsRows.map((r) => r['rowid'] as int).toList();
        final placeholders = List.filled(ids.length, '?').join(',');
        final whereConditions = <String>['id IN ($placeholders)'];
        final whereArgs = <dynamic>[...ids];

        _applySearchFilters(whereConditions, whereArgs,
            includeWishlist: includeWishlist,
            minRating: minRating,
            isRead: isRead,
            publisher: publisher,
            publicationYear: publicationYear);

        rows = await _database.query(
          'comics',
          where: whereConditions.join(' AND '),
          whereArgs: whereArgs,
          orderBy: 'addedDate DESC',
        );
      } else {
        rows = [];
      }
    } catch (_) {
      final whereConditions = <String>[];
      final whereArgs = <dynamic>[];
      final searchFields = ['title', 'seriesName', 'issueNumber', 'publisher',
          'description', 'writers', 'artists', 'barcode'];
      final likeConditions = searchFields.map((f) => '$f LIKE ?').toList();
      whereConditions.add('(${likeConditions.join(' OR ')})');
      whereArgs.addAll(List.filled(searchFields.length, '%$trimmedQuery%'));

      _applySearchFilters(whereConditions, whereArgs,
          includeWishlist: includeWishlist,
          minRating: minRating,
          isRead: isRead,
          publisher: publisher,
          publicationYear: publicationYear);

      rows = await _database.query(
        'comics',
        where: whereConditions.join(' AND '),
        whereArgs: whereArgs,
        orderBy: 'addedDate DESC',
        limit: limit,
        offset: offset,
      );
    }

    return rows.map((r) => Comic.fromMap(_decryptRow(r))).toList();
  }

  // ── Barcode Lookup ────────────────────────────────────────────────────────

  Future<Comic?> getComicByBarcode(String barcode) async {
    final normalized = _normalizeBarcode(barcode);

    // Build a deduplicated list of candidates to try in order:
    // 1. The normalised form (digits-only, validated length).
    // 2. The raw input as-is (scanner may include dashes / spaces).
    // 3. EAN-13 → UPC-A: if the normalised form is 13 digits starting with '0',
    //    drop the leading zero to get the 12-digit UPC-A equivalent, because the
    //    comic may have been stored under one encoding and scanned in the other.
    final candidates = <String>[normalized];
    if (barcode != normalized) candidates.add(barcode);
    if (normalized.length == 13 && normalized.startsWith('0')) {
      final upcA = normalized.substring(1);
      if (!candidates.contains(upcA)) candidates.add(upcA);
    }

    for (final candidate in candidates) {
      final rows = await _database.query('comics',
          where: 'barcode = ? AND isWishlisted = 0',
          whereArgs: [candidate],
          limit: 1);
      if (rows.isNotEmpty) return Comic.fromMap(_decryptRow(rows.first));
    }
    return null;
  }

  Future<List<Comic>> getComicsByBarcodePrefix(String prefix) async {
    final rows = await _database.query('comics',
        where: 'barcode LIKE ? AND isWishlisted = 0',
        whereArgs: ['$prefix%']);
    return rows.map((r) => Comic.fromMap(_decryptRow(r))).toList();
  }

  String _normalizeBarcode(String barcode) {
    final clean = barcode.replaceAll(RegExp(r'[^\d]'), '');
    if (clean.length == 12) return clean;
    if (clean.length == 13) return clean;
    if (clean.length == 8)  return clean;
    return barcode;
  }

  // ── Search History ────────────────────────────────────────────────────────

  Future<void> addSearchHistory(String query, int resultCount) async {
    final trimmed = query.trim();
    // Remove any existing entry for the same query so the new one sorts to
    // the top of recent history and gets an updated timestamp + result count.
    await _database.delete('search_history',
        where: 'query = ?', whereArgs: [trimmed]);
    await _database.insert('search_history', {
      'query': trimmed,
      'timestamp': DateTime.now().toIso8601String(),
      'resultCount': resultCount,
    });
  }

  Future<List<Map<String, dynamic>>> getSearchHistory({int limit = 20}) async {
    return _database.query('search_history',
        orderBy: 'timestamp DESC', limit: limit);
  }

  Future<void> toggleSearchFavorite(String query, bool isFavorite) async {
    await _database.update('search_history',
        {'isFavorite': isFavorite ? 1 : 0},
        where: 'query = ?', whereArgs: [query]);
  }

  Future<List<String>> getFavoriteSearches() async {
    final rows = await _database.query('search_history',
        columns: ['query'],
        where: 'isFavorite = 1',
        orderBy: 'timestamp DESC');
    return rows.map((r) => r['query'] as String).toList();
  }

  Future<void> clearSearchHistory() async =>
      _database.delete('search_history');

  // ── Barcode History ───────────────────────────────────────────────────────

  Future<void> addBarcodeScan(String barcode, {String? comicVineId}) async {
    await _database.insert('barcode_history', {
      'barcode': barcode,
      'timestamp': DateTime.now().toIso8601String(),
      'comicVineId': comicVineId,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getBarcodeHistory({int limit = 20}) async {
    return _database.query('barcode_history',
        orderBy: 'timestamp DESC', limit: limit);
  }

  Future<Comic?> getComicFromBarcodeHistory(String barcode) async {
    final rows = await _database.query('barcode_history',
        columns: ['comicVineId'],
        where: 'barcode = ?',
        whereArgs: [barcode],
        limit: 1);
    if (rows.isEmpty || rows.first['comicVineId'] == null) return null;
    return getComicByVineId(rows.first['comicVineId'] as String);
  }

  Future<void> clearBarcodeHistory() async =>
      _database.delete('barcode_history');

  /// Records a user-confirmed barcode → comic mapping.
  /// Updates barcode_history and, if the comic is already in the library,
  /// stamps the barcode onto the comics row so future scans resolve instantly.
  Future<void> mapBarcodeToComic(String barcode, String comicVineId) async {
    // Update / insert the barcode_history entry with the confirmed comicVineId
    await addBarcodeScan(barcode, comicVineId: comicVineId);

    // If the comic is already owned, stamp the barcode onto it
    await _database.update(
      'comics',
      {'barcode': barcode},
      where: 'comicVineId = ? AND (barcode IS NULL OR barcode = "")',
      whereArgs: [comicVineId],
    );
  }
}