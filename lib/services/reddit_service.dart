import 'dart:convert';
import 'dart:developer' as dev;
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:http/http.dart' as http;
import '../config.dart';
import '../models/reddit_thread.dart';
import '../models/reddit_comment.dart';

class RedditService {
  String _buildUrl(String redditUrl) {
    if (kIsWeb) {
      if (kDebugMode) {
        // Local CORS proxy (run: node proxy.js)
        return 'http://localhost:8888/?url=${Uri.encodeComponent(redditUrl)}';
      }
      // Vercel serverless function in production
      return '/api/reddit?url=${Uri.encodeComponent(redditUrl)}';
    }
    return redditUrl;
  }

  Future<Map<String, dynamic>> _fetchJson(String url) async {
    final response = await http.get(
      Uri.parse(_buildUrl(url)),
      headers: {'User-Agent': 'AeroXMonitor/1.0 (personal dashboard)'},
    );
    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}: ${response.reasonPhrase}');
    }
    return json.decode(response.body) as Map<String, dynamic>;
  }

  Future<List<dynamic>> _fetchJsonList(String url) async {
    final response = await http.get(
      Uri.parse(_buildUrl(url)),
      headers: {'User-Agent': 'AeroXMonitor/1.0 (personal dashboard)'},
    );
    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}: ${response.reasonPhrase}');
    }
    return json.decode(response.body) as List<dynamic>;
  }

  /// Streams threads progressively, one keyword×subreddit at a time.
  /// [onUpdate] is called each time new matching threads are found.
  Stream<List<RedditThread>> streamInterestingThreads() async* {
    final cutoff = DateTime.now().subtract(
      const Duration(days: maxPostAgeDays),
    );
    final Map<String, RedditThread> threadsMap = {};

    for (final keyword in keywords.keys) {
      for (final subreddit in subreddits) {
        try {
          final url =
              'https://www.reddit.com/r/$subreddit/search.json?q=${Uri.encodeComponent(keyword)}&sort=new&limit=10&restrict_sr=on';
          final data = await _fetchJson(url);
          final children = (data['data']?['children'] as List<dynamic>?) ?? [];

          var hasNew = false;
          for (final child in children) {
            final thread = RedditThread.fromJson(
              child as Map<String, dynamic>,
              keywords,
            );
            if (thread.createdUtc.isAfter(cutoff) &&
                thread.relevanceScore > 3) {
              if (!threadsMap.containsKey(thread.id) ||
                  threadsMap[thread.id]!.relevanceScore <
                      thread.relevanceScore) {
                threadsMap[thread.id] = thread;
                hasNew = true;
              }
            }
          }

          if (hasNew) {
            final sorted = threadsMap.values.toList()
              ..sort((a, b) => b.relevanceScore.compareTo(a.relevanceScore));
            yield sorted;
          }
        } catch (_) {
          // Skip failed requests silently
        }
        // Throttle to avoid Reddit rate-limiting (429)
        await Future.delayed(const Duration(milliseconds: 800));
      }
    }
  }

  Future<List<RedditComment>> fetchMyPostComments() async {
    final List<RedditComment> allComments = [];

    try {
      final url =
          'https://www.reddit.com/user/$redditUsername/submitted.json?limit=10';
      final data = await _fetchJson(url);
      final posts = (data['data']?['children'] as List<dynamic>?) ?? [];

      for (final post in posts) {
        final postData = post['data'] as Map<String, dynamic>;
        final postTitle = postData['title'] as String? ?? '';
        final postPermalink = postData['permalink'] as String? ?? '';

        try {
          final permalink = postPermalink.endsWith('/')
              ? postPermalink.substring(0, postPermalink.length - 1)
              : postPermalink;
          final commentsUrl = 'https://www.reddit.com$permalink.json';
          dev.log('Fetching comments: $commentsUrl');
          final commentData = await _fetchJsonList(commentsUrl);
          dev.log('Got ${commentData.length} listings for $permalink');

          if (commentData.length >= 2) {
            final commentListing = commentData[1] as Map<String, dynamic>;
            final comments =
                (commentListing['data']?['children'] as List<dynamic>?) ?? [];
            dev.log('Found ${comments.length} comments for "$postTitle"');

            for (final comment in comments) {
              final commentMap = comment as Map<String, dynamic>;
              if (commentMap['kind'] != 't1') continue;

              final cData = commentMap['data'] as Map<String, dynamic>;
              final author = cData['author'] as String? ?? '';
              final score = (cData['score'] as num?)?.toInt() ?? 0;

              if (author.toLowerCase() == redditUsername.toLowerCase()) {
                continue;
              }
              if (author == '[deleted]') continue;
              if (score < minCommentScore) continue;

              allComments.add(
                RedditComment.fromJson(
                  commentMap,
                  postTitle: postTitle,
                  postPermalink: postPermalink,
                ),
              );
            }
          }
        } catch (e) {
          dev.log('Error fetching comments for "$postTitle": $e');
        }
      }
    } catch (e) {
      dev.log('Error fetching user posts: $e');
    }

    allComments.sort((a, b) => b.createdUtc.compareTo(a.createdUtc));
    return allComments;
  }
}
