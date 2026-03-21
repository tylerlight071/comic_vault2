// lib/theme/services/comic_vine_service.dart

import 'dart:convert';
import 'dart:math' show sqrt;
import 'package:flutter/foundation.dart' show compute;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/comic.dart';
import 'database_service.dart';
import 'encryption_service.dart';

class SearchResult {
  final List<Comic> comics;
  final int total;
  final int offset;
  final int limit;

  const SearchResult({
    required this.comics,
    required this.total,
    required this.offset,
    required this.limit,
  });

  bool get hasMore => offset + comics.length < total;
  int get showing => offset + comics.length;
}

// ── Top-level function required by compute() ─────────────────────────────────
//
// compute() spawns a background isolate and requires a top-level (or static)
// function — it cannot capture instance state. This wrapper unpacks the args
// map and calls the static _filterAndRank method.

List<Comic> _filterAndRankIsolate(Map<String, dynamic> args) {
  final comics = (args['comics'] as List).cast<Comic>();
  final query  = args['query'] as String;
  return ComicVineService._filterAndRank(comics, query);
}

class ComicVineService {
  static final ComicVineService instance = ComicVineService._();
  ComicVineService._();

  static const String _base = 'https://comicvine.gamespot.com/api';
  static const String _issueFields =
      'id,name,volume,issue_number,cover_date,image,description,person_credits';
  static const String _runFields =
      'id,name,volume,issue_number,cover_date,image,description,person_credits';
  static const int _defaultPageSize = 20;

  // Injected at build time via --dart-define-from-file=dart_defines.env
  // Never hardcode a real key here — keep this empty and provide the key
  // through dart_defines.env (gitignored) or the in-app Settings → API field.
  static const String _envApiKey =
      String.fromEnvironment('COMIC_VINE_API_KEY', defaultValue: '');

  static const _apiKeyStorageKey = 'comic_vine_api_key';

  Future<String> _apiKey() async {
    // Prefer the key from secure storage (user-entered via Settings).
    // On first run after the M1 migration, move any key still sitting in
    // SharedPreferences into secure storage and remove it from there.
    var custom = await EncryptionService.secureRead(_apiKeyStorageKey);
    if (custom == null || custom.isEmpty) {
      // Migration: check legacy SharedPreferences location.
      final prefs = await SharedPreferences.getInstance();
      final legacy = prefs.getString('comic_vine_api_key')?.trim();
      if (legacy != null && legacy.isNotEmpty) {
        await EncryptionService.secureWrite(_apiKeyStorageKey, legacy);
        await prefs.remove('comic_vine_api_key');
        custom = legacy;
      }
    }
    if (custom != null && custom.trim().isNotEmpty) return custom.trim();
    if (_envApiKey.isNotEmpty) return _envApiKey;
    throw Exception(
      'No Comic Vine API key configured. '
      'Add one in Settings → API, or run the app with --dart-define-from-file=dart_defines.env.',
    );
  }

  Future<Map<String, dynamic>> _get(Uri uri) async {
    final response = await http
        .get(uri, headers: {'User-Agent': 'ComicVault/1.0'})
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) throw Exception('HTTP ${response.statusCode}');
    final body = json.decode(response.body) as Map<String, dynamic>;
    if ((body['status_code'] as int?) != null &&
        (body['status_code'] as int) != 1) {
      throw Exception('Comic Vine: ${body["error"]}');
    }
    return body;
  }

  // ── Result quality filtering & ranking ────────────────────────────────────
  //
  // Declared static so it can be referenced by the top-level
  // _filterAndRankIsolate function used with compute().

  static List<Comic> _filterAndRank(List<Comic> comics, String query) {
    final q = query.trim().toLowerCase();
    final queryWords =
        q.split(RegExp(r'\s+')).where((w) => w.length > 2).toList();

    // ── 0. Hard pre-filter ────────────────────────────────────────────────
    final cleaned = comics.where((c) {
      if (c.title.trim().isEmpty)                  return false;
      if (c.title.trim() == 'Unknown Issue')       return false;
      if (c.seriesName.trim().isEmpty)             return false;
      if (c.seriesName.trim() == 'Unknown Series') return false;
      return true;
    }).toList();

    // ── 1. Score ──────────────────────────────────────────────────────────
    final scored = <({Comic comic, double score})>[];

    for (final comic in cleaned) {
      double score = 0;
      final title  = comic.title.toLowerCase();
      final series = comic.seriesName.toLowerCase();

      if (title == q || series == q) {
        score += 6;
      } else if (title.startsWith(q) || series.startsWith(q)) {
        score += 4;
      } else if (title.contains(q) || series.contains(q)) {
        score += 2.5;
      } else {
        final matchCount = queryWords
            .where((w) => title.contains(w) || series.contains(w))
            .length;
        score += matchCount * 0.8;
      }

      if (comic.coverImageUrl != null && comic.coverImageUrl!.isNotEmpty) score += 2.0;
      if (comic.issueNumber   != null && comic.issueNumber!.isNotEmpty)   score += 1.5;
      if (comic.publicationYear != null)                                    score += 1.0;
      if (comic.description   != null && comic.description!.length > 30)  score += 1.0;
      if (comic.writers       != null && comic.writers!.isNotEmpty)        score += 0.5;
      if (comic.artists       != null && comic.artists!.isNotEmpty)        score += 0.5;
      if (comic.publisher     != null && comic.publisher!.isNotEmpty)      score += 0.5;

      if (comic.coverImageUrl == null) score -= 2;
      if (comic.issueNumber   == null) score -= 1.5;

      scored.add((comic: comic, score: score));
    }

    // ── 2a. Deduplicate by comicVineId ────────────────────────────────────
    final byId = <String, ({Comic comic, double score})>{};
    for (final entry in scored) {
      final id = entry.comic.comicVineId;
      if (!byId.containsKey(id) || byId[id]!.score < entry.score) {
        byId[id] = entry;
      }
    }

    // ── 2b. Deduplicate by series + issue + year ──────────────────────────
    final bySeries = <String, ({Comic comic, double score})>{};
    for (final entry in byId.values) {
      final c = entry.comic;
      if (c.issueNumber != null && c.issueNumber!.isNotEmpty) {
        final key = [
          c.seriesName.trim().toLowerCase(),
          c.issueNumber!.trim(),
          '${c.publicationYear ?? ""}',
        ].join('|');
        if (!bySeries.containsKey(key) || bySeries[key]!.score < entry.score) {
          bySeries[key] = entry;
        }
      } else {
        bySeries[c.comicVineId] = entry;
      }
    }

    // ── 3. Discard low-quality ────────────────────────────────────────────
    const discardThreshold = 0.5;
    final filtered = bySeries.values
        .where((e) => e.score > discardThreshold)
        .toList();

    // ── 4. Sort ───────────────────────────────────────────────────────────
    filtered.sort((a, b) => b.score.compareTo(a.score));

    return filtered.map((e) => e.comic).toList();
  }

  // ── Public API ────────────────────────────────────────────────────────────

  // ── Barcode → exact comic ─────────────────────────────────────────────────
  //
  // Uses the 5-digit supplement (if present) to extract the issue number, then
  // does a structured Comic Vine volumes + issues query for a precise match
  // rather than a fuzzy text search.

  Future<Comic?> lookupByBarcode(String rawBarcode) async {
    final clean = rawBarcode.replaceAll(RegExp(r'[^\d]'), '');

    // Split into main UPC and optional 5-digit supplement
    String mainBarcode = clean;
    String? supplement;
    if (clean.length == 17) {
      mainBarcode = clean.substring(0, 12);
      supplement  = clean.substring(12);
    } else if (clean.length == 18) {
      mainBarcode = clean.substring(0, 13);
      supplement  = clean.substring(13);
    }

    // Local DB first
    final local = await DatabaseService.instance.getComicByBarcode(mainBarcode);
    if (local != null) {
      await DatabaseService.instance
          .addBarcodeScan(mainBarcode, comicVineId: local.comicVineId);
      return local;
    }

    await DatabaseService.instance.addBarcodeScan(mainBarcode);

    // Extract issue number from supplement — format is IIIxx where III = issue
    String? issueNumber;
    if (supplement != null && supplement.length == 5) {
      final n = int.tryParse(supplement.substring(0, 3));
      if (n != null) issueNumber = n.toString(); // strips leading zeros
    }

    // UPC lookup for series name
    final seriesName = await lookupUPC(mainBarcode);

    if (seriesName != null && issueNumber != null) {
      // Most precise path: find the volume then filter issues by number
      final comic = await _lookupExactIssue(seriesName, issueNumber);
      if (comic != null) return comic;
    }

    if (seriesName != null) {
      // Fallback: ranked text search using the series name
      final result = await search(seriesName, limit: 1);
      return result.comics.isNotEmpty ? result.comics.first : null;
    }

    return null; // Could not resolve — caller should show search screen
  }

  /// Searches Comic Vine for a volume matching [seriesName], then queries
  /// the issues endpoint filtered by [issueNumber] to get the exact issue.
  Future<Comic?> _lookupExactIssue(
      String seriesName, String issueNumber) async {
    final key = await _apiKey();

    // Step 1 — find matching volumes
    final volUri =
        Uri.parse('$_base/search/').replace(queryParameters: {
      'api_key':    key,
      'format':     'json',
      'query':      seriesName,
      'resources':  'volume',
      'field_list': 'id,name',
      'limit':      '5',
    });

    final volBody   = await _get(volUri);
    final volumes   = (volBody['results'] as List<dynamic>)
        .where((r) => r['resource_type'] == 'volume')
        .toList();

    if (volumes.isEmpty) return null;

    // Step 2 — for each volume (up to 3) look for the issue
    for (final vol in volumes.take(3)) {
      final volumeId = vol['id'].toString();
      final issueUri =
          Uri.parse('$_base/issues/').replace(queryParameters: {
        'api_key':    key,
        'format':     'json',
        'filter':     'volume:$volumeId,issue_number:$issueNumber',
        'field_list': _issueFields,
        'limit':      '1',
      });

      final issueBody = await _get(issueUri);
      final results   = issueBody['results'] as List<dynamic>;
      if (results.isNotEmpty) {
        return _parseIssue(results.first as Map<String, dynamic>);
      }
    }

    return null;
  }

  Future<String?> lookupUPC(String upc) async {
    try {
      final uri = Uri.parse('https://api.upcitemdb.com/prod/trial/lookup')
          .replace(queryParameters: {'upc': upc});
      final body = await _get(uri);
      final items = body['items'] as List<dynamic>?;
      if (items != null && items.isNotEmpty) {
        final item  = items.first as Map<String, dynamic>;
        final title = item['title'] as String?;
        final brand = item['brand'] as String?;
        if (title != null) return brand != null ? '$title $brand' : title;
      }
    } catch (_) {}
    return null;
  }

  Future<int> getVolumeIssueCount(String volumeId) async {
    final key = await _apiKey();
    final uri = Uri.parse('$_base/issues/').replace(queryParameters: {
      'api_key':    key,
      'format':     'json',
      'filter':     'volume:$volumeId',
      'field_list': 'id',
      'limit':      '1',
      'offset':     '0',
    });
    final body = await _get(uri);
    return body['number_of_total_results'] as int? ?? 0;
  }

  static const int _fetchMultiplier = 2;

  Future<SearchResult> search(
    String query, {
    int offset = 0,
    int limit = _defaultPageSize,
  }) async {
    final trimmedQuery = query.trim();
    final isBarcode = RegExp(r'^\d{12,13}$').hasMatch(trimmedQuery);

    if (isBarcode && offset == 0) {
      final localComic =
          await DatabaseService.instance.getComicByBarcode(trimmedQuery);
      if (localComic != null) {
        await DatabaseService.instance
            .addBarcodeScan(trimmedQuery, comicVineId: localComic.comicVineId);
        return SearchResult(
            comics: [localComic], total: 1, offset: 0, limit: limit);
      }
    }

    final key = await _apiKey();
    String searchQuery = trimmedQuery;

    if (isBarcode && offset == 0) {
      final productName = await lookupUPC(trimmedQuery);
      if (productName != null) searchQuery = productName;
      await DatabaseService.instance.addBarcodeScan(trimmedQuery);
    }

    final rawLimit = (limit * _fetchMultiplier).clamp(limit, 100);

    final uri = Uri.parse('$_base/search/').replace(queryParameters: {
      'api_key':    key,
      'format':     'json',
      'query':      searchQuery,
      'resources':  'issue',
      'field_list': _issueFields,
      'limit':      '$rawLimit',
      'offset':     '$offset',
    });

    final body       = await _get(uri);
    final rawResults = (body['results'] as List<dynamic>)
        .where((r) => r['resource_type'] == 'issue')
        .map((r) => _parseIssue(r as Map<String, dynamic>))
        .toList();

    final total = body['number_of_total_results'] as int? ?? rawResults.length;

    // Run in a background isolate — keeps the UI thread free during the
    // score / dedup / sort pass which can be non-trivial for large result sets.
    final ranked = await compute(_filterAndRankIsolate, {
      'comics': rawResults,
      'query':  trimmedQuery,
    });

    final trimmed       = ranked.take(limit).toList();
    final filterRatio   = rawResults.isEmpty ? 1.0 : ranked.length / rawResults.length;
    final adjustedTotal = (total * filterRatio).ceil();

    return SearchResult(
      comics: trimmed,
      total:  adjustedTotal,
      offset: offset,
      limit:  limit,
    );
  }

  Future<Comic?> fetchIssueById(String comicVineId) async {
    final key = await _apiKey();
    final uri = Uri.parse('$_base/issue/4000-$comicVineId/')
        .replace(queryParameters: {
      'api_key':    key,
      'format':     'json',
      'field_list': _issueFields,
    });
    try {
      final body   = await _get(uri);
      final result = body['results'] as Map<String, dynamic>?;
      if (result == null) return null;
      return _parseIssue(result);
    } catch (_) {
      return null;
    }
  }

  // In-memory cache for volume issue lists — avoids redundant API calls when
  // the user navigates in/out of the same series repeatedly.
  final Map<String, (List<Comic>, DateTime)> _volumeIssuesCache = {};
  static const Duration _volumeCacheTtl = Duration(minutes: 15);

  Future<List<Comic>> getVolumeIssues(String volumeId,
      {void Function(int loaded, int total)? onProgress}) async {
    final cached = _volumeIssuesCache[volumeId];
    if (cached != null && DateTime.now().difference(cached.$2) < _volumeCacheTtl) {
      return cached.$1;
    }

    final key       = await _apiKey();
    final allIssues = <Comic>[];
    int offset      = 0;
    const limit     = 100;
    // Hard cap at 1 200 issues (~12 pages) to prevent runaway fetches for
    // long-running series like Action Comics (1 000+ issues).
    const maxIssues = 1200;

    while (allIssues.length < maxIssues) {
      final uri = Uri.parse('$_base/issues/').replace(queryParameters: {
        'api_key':    key,
        'format':     'json',
        'filter':     'volume:$volumeId',
        'field_list': _runFields,
        'sort':       'issue_number:asc',
        'limit':      '$limit',
        'offset':     '$offset',
      });
      final body    = await _get(uri);
      final results = (body['results'] as List<dynamic>)
          .map((r) => _parseIssue(r as Map<String, dynamic>))
          .toList();
      allIssues.addAll(results);
      final total = body['number_of_total_results'] as int? ?? 0;
      onProgress?.call(allIssues.length.clamp(0, total), total);
      offset += limit;
      if (offset >= total || results.isEmpty) break;
    }

    _volumeIssuesCache[volumeId] = (allIssues, DateTime.now());
    return allIssues;
  }

  Comic _parseIssue(Map<String, dynamic> d) {
    final volume  = d['volume']  as Map<String, dynamic>?;
    final image   = d['image']   as Map<String, dynamic>?;
    final credits = d['person_credits'] as List<dynamic>? ?? [];

    String joinRole(bool Function(String) test) => credits
        .where((p) => test((p['role'] as String? ?? '').toLowerCase()))
        .map((p) => p['name'] as String)
        .join(', ');

    final writers   = joinRole((r) => r.contains('writer'));
    final artists   = joinRole((r) =>
        r.contains('pencil') || r.contains('artist') || r.contains('ink'));
    final publisher =
        (volume?['publisher'] as Map<String, dynamic>?)?['name'] as String?;
    final coverDate = d['cover_date'] as String?;
    final year      = (coverDate != null && coverDate.length >= 4)
        ? int.tryParse(coverDate.substring(0, 4))
        : null;

    String? desc = d['description'] as String?;
    if (desc != null) {
      desc = desc
          .replaceAll(RegExp(r'<[^>]*>'), '')
          // Named HTML entities
          .replaceAll('&amp;',   '&')
          .replaceAll('&lt;',    '<')
          .replaceAll('&gt;',    '>')
          .replaceAll('&quot;',  '"')
          .replaceAll('&apos;',  "'")
          .replaceAll('&#39;',   "'")
          .replaceAll('&nbsp;',  ' ')
          .replaceAll('&mdash;', '—')
          .replaceAll('&ndash;', '–')
          .replaceAll('&lsquo;', '\u2018')
          .replaceAll('&rsquo;', '\u2019')
          .replaceAll('&ldquo;', '\u201C')
          .replaceAll('&rdquo;', '\u201D')
          .replaceAll('&hellip;', '…')
          // Numeric decimal entities (e.g. &#160; &#8212;)
          .replaceAllMapped(RegExp(r'&#(\d+);'),
              (m) => String.fromCharCode(int.parse(m[1]!)))
          // Numeric hex entities (e.g. &#xA0; &#x2014;)
          .replaceAllMapped(RegExp(r'&#x([0-9a-fA-F]+);'),
              (m) => String.fromCharCode(int.parse(m[1]!, radix: 16)))
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (desc.isEmpty) desc = null;
    }

    return Comic(
      comicVineId:     d['id'].toString(),
      volumeId:        volume?['id']?.toString(),
      title:           d['name'] as String? ?? 'Unknown Issue',
      seriesName:      volume?['name'] as String? ?? 'Unknown Series',
      issueNumber:     d['issue_number'] as String?,
      publicationYear: year,
      publisher:       publisher,
      description:     desc,
      coverImageUrl:   image?['medium_url'] as String?,
      writers:         writers.isEmpty ? null : writers,
      artists:         artists.isEmpty ? null : artists,
    );
  }
}