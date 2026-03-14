class RedditComment {
  final String id;
  final String author;
  final String body;
  final int score;
  final DateTime createdUtc;
  final String postTitle;
  final String postPermalink;

  RedditComment({
    required this.id,
    required this.author,
    required this.body,
    required this.score,
    required this.createdUtc,
    required this.postTitle,
    required this.postPermalink,
  });

  factory RedditComment.fromJson(
    Map<String, dynamic> json, {
    required String postTitle,
    required String postPermalink,
  }) {
    final data = json['data'] as Map<String, dynamic>;
    return RedditComment(
      id: data['id'] as String? ?? '',
      author: data['author'] as String? ?? '[deleted]',
      body: data['body'] as String? ?? '',
      score: (data['score'] as num?)?.toInt() ?? 0,
      createdUtc: DateTime.fromMillisecondsSinceEpoch(
        ((data['created_utc'] as num?)?.toInt() ?? 0) * 1000,
        isUtc: true,
      ),
      postTitle: postTitle,
      postPermalink: postPermalink,
    );
  }

  Map<String, dynamic> toCacheJson() => {
    'id': id,
    'author': author,
    'body': body,
    'score': score,
    'createdUtc': createdUtc.millisecondsSinceEpoch,
    'postTitle': postTitle,
    'postPermalink': postPermalink,
  };

  factory RedditComment.fromCacheJson(Map<String, dynamic> json) =>
      RedditComment(
        id: json['id'] as String,
        author: json['author'] as String,
        body: json['body'] as String,
        score: json['score'] as int,
        createdUtc: DateTime.fromMillisecondsSinceEpoch(
          json['createdUtc'] as int,
        ),
        postTitle: json['postTitle'] as String,
        postPermalink: json['postPermalink'] as String,
      );

  String get postUrl => 'https://www.reddit.com$postPermalink';
  String get authorProfileUrl => 'https://www.reddit.com/user/$author';
}
