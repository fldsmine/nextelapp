import 'dart:convert';

import 'package:nextel_connect/games/utilities/user_scores.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

const String legacyHangmanScoresPreferenceKey = 'games.hangman.scores.v1';
const String _hangmanImportCompleteKey = 'games.hangman.sqlite_imported.v1';

/// Converts the native/legacy JSON score format into the source SQLite schema.
/// Keeping this parser pure makes the upgrade mapping straightforward to test.
List<Map<String, Object?>> decodeLegacyHangmanScores(String raw) {
  final decoded = jsonDecode(raw);
  if (decoded is! List) {
    throw const FormatException('Hangman scores must be a JSON list.');
  }

  final rows = <Map<String, Object?>>[];
  for (final value in decoded) {
    if (value is! Map) continue;
    final score = _asInt(value['userScore'] ?? value['score']);
    final rawDate = value['scoreDate'] ?? value['date'];
    final date = rawDate is DateTime ? rawDate.toIso8601String() : rawDate;
    if (date is! String || date.trim().isEmpty) continue;

    final row = <String, Object?>{
      'scoreDate': date,
      'userScore': score,
    };
    final id = _asInt(value['id']);
    if (id > 0) row['id'] = id;
    rows.add(row);
  }
  return rows;
}

int _asInt(Object? value) => switch (value) {
      int number => number,
      num number => number.toInt(),
      String text => int.tryParse(text) ?? 0,
      _ => 0,
    };

Future<Database> openDB() async {
  final database = await openDatabase(
    path.join(await getDatabasesPath(), 'scores_database.db'),
    onCreate: (db, version) => db.execute(
      'CREATE TABLE scores('
      'id INTEGER PRIMARY KEY AUTOINCREMENT, '
      'scoreDate TEXT, '
      'userScore INTEGER)',
    ),
    version: 1,
  );
  await _importLegacyScores(database);
  return database;
}

Future<void> _importLegacyScores(Database database) async {
  try {
    final preferences = await SharedPreferences.getInstance();
    if (preferences.getBool(_hangmanImportCompleteKey) ?? false) return;

    final raw = preferences.getString(legacyHangmanScoresPreferenceKey);
    if (raw == null || raw.trim().isEmpty) {
      await preferences.setBool(_hangmanImportCompleteKey, true);
      return;
    }

    final rows = decodeLegacyHangmanScores(raw);
    await database.transaction((transaction) async {
      for (final row in rows) {
        await transaction.insert(
          'scores',
          row,
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    });
    await preferences.setBool(_hangmanImportCompleteKey, true);
  } on FormatException {
    // A damaged old preference should not prevent opening the game database.
    // Leave the import marker unset so a later corrected payload can retry.
  } catch (_) {
    // Keep the source preference and retry if opening the database succeeds
    // on a later visit; the game itself should remain usable in the meantime.
  }
}

Future<void> insertScore(Score score, Future<Database> database) async {
  final db = await database;
  await db.insert(
    'scores',
    score.toMap(),
    conflictAlgorithm: ConflictAlgorithm.ignore,
  );
}

Future<List<Score>> scores(Future<Database> database) async {
  final db = await database;
  final maps = await db.query('scores');
  return maps
      .map(
        (row) => Score(
          id: row['id'] as int,
          scoreDate: row['scoreDate'] as String,
          userScore: row['userScore'] as int,
        ),
      )
      .toList();
}

Future<void> updateScore(Score score, Future<Database> database) async {
  final db = await database;
  await db.update(
    'scores',
    score.toMap(),
    where: 'id = ?',
    whereArgs: [score.id],
  );
}

Future<void> deleteScore(int id, Future<Database> database) async {
  final db = await database;
  await db.delete('scores', where: 'id = ?', whereArgs: [id]);
}

Future<void> manipulateDatabase(Score scoreObject, Future<Database> database) async {
  await insertScore(scoreObject, database);
}
