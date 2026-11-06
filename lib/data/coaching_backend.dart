import 'dart:convert';

import 'package:sembast/sembast.dart';

/// Storage for coaching data shared between a coach and their clients.
///
/// Every record is a JSON document in a named collection, which maps directly
/// onto Firestore (collection → documents). Today [LocalCoachingBackend]
/// keeps everything on this phone; a cloud implementation can replace it
/// without touching the screens.
abstract class CoachingBackend {
  Future<List<Map<String, Object?>>> list(String collection);
  Future<void> put(String collection, String id, Map<String, Object?> doc);
  Future<void> delete(String collection, String id);
  Future<void> clear();

  /// True when data is only on this device (no sync between phones).
  bool get isLocalOnly;
}

class Collections {
  static const centers = 'centers';
  static const coaches = 'coaches';
  static const clients = 'clients';
  static const requests = 'requests';
  static const goals = 'goals';
  static const mealPlans = 'meal_plans';
  static const reminders = 'reminders';
  static const comments = 'comments';
  static const notifications = 'notifications';
  static const meta = 'coaching_meta';

  static const all = [centers, coaches, clients, requests, goals, mealPlans, reminders, comments, notifications, meta];
}

class LocalCoachingBackend implements CoachingBackend {
  final Database db;
  LocalCoachingBackend(this.db);

  StoreRef<String, Map<String, Object?>> _store(String c) => stringMapStoreFactory.store('coaching_$c');

  @override
  bool get isLocalOnly => true;

  @override
  Future<List<Map<String, Object?>>> list(String collection) async => (await _store(collection).find(db))
      .map((r) => Map<String, Object?>.from(jsonDecode(jsonEncode(r.value)) as Map))
      .toList();

  @override
  Future<void> put(String collection, String id, Map<String, Object?> doc) =>
      _store(collection).record(id).put(db, doc);

  @override
  Future<void> delete(String collection, String id) => _store(collection).record(id).delete(db);

  @override
  Future<void> clear() async {
    await db.transaction((txn) async {
      for (final c in Collections.all) {
        await _store(c).delete(txn);
      }
    });
  }
}
