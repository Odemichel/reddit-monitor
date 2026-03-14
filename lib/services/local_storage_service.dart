import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/item_status.dart';
import '../models/reddit_thread.dart';
import '../models/reddit_comment.dart';

class LocalStorageService {
  static const _threadsKey = 'cached_threads';
  static const _commentsKey = 'cached_comments';
  static const _statusesKey = 'item_statuses';
  static const _bannedUsersKey = 'banned_users';
  static const _lastScanKey = 'last_scan_date';

  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // --- Statuses ---

  Map<String, ItemStatus> loadStatuses() {
    final raw = _prefs.getString(_statusesKey);
    if (raw == null) return {};
    final map = json.decode(raw) as Map<String, dynamic>;
    return map.map((k, v) => MapEntry(k, ItemStatus.values[v as int]));
  }

  Future<void> saveStatuses(Map<String, ItemStatus> statuses) async {
    final map = statuses.map((k, v) => MapEntry(k, v.index));
    await _prefs.setString(_statusesKey, json.encode(map));
  }

  // --- Threads cache ---

  List<RedditThread> loadCachedThreads() {
    final raw = _prefs.getString(_threadsKey);
    if (raw == null) return [];
    final list = json.decode(raw) as List<dynamic>;
    return list
        .map((e) => RedditThread.fromCacheJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveCachedThreads(List<RedditThread> threads) async {
    final list = threads.map((t) => t.toCacheJson()).toList();
    await _prefs.setString(_threadsKey, json.encode(list));
  }

  // --- Comments cache ---

  List<RedditComment> loadCachedComments() {
    final raw = _prefs.getString(_commentsKey);
    if (raw == null) return [];
    final list = json.decode(raw) as List<dynamic>;
    return list
        .map((e) => RedditComment.fromCacheJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveCachedComments(List<RedditComment> comments) async {
    final list = comments.map((c) => c.toCacheJson()).toList();
    await _prefs.setString(_commentsKey, json.encode(list));
  }

  // --- Banned users ---

  Set<String> loadBannedUsers() {
    final list = _prefs.getStringList(_bannedUsersKey);
    return list?.toSet() ?? {};
  }

  Future<void> saveBannedUsers(Set<String> users) async {
    await _prefs.setStringList(_bannedUsersKey, users.toList());
  }

  // --- Last scan date ---

  DateTime? loadLastScanDate() {
    final ms = _prefs.getInt(_lastScanKey);
    return ms != null ? DateTime.fromMillisecondsSinceEpoch(ms) : null;
  }

  Future<void> saveLastScanDate(DateTime date) async {
    await _prefs.setInt(_lastScanKey, date.millisecondsSinceEpoch);
  }

  // --- Clear all cache ---

  Future<void> clearAll() async {
    await _prefs.remove(_threadsKey);
    await _prefs.remove(_commentsKey);
    await _prefs.remove(_statusesKey);
    await _prefs.remove(_bannedUsersKey);
    await _prefs.remove(_lastScanKey);
  }
}
