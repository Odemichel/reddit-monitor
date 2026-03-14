class RedditThread {
  final String id;
  final String title;
  final String author;
  final String subreddit;
  final String selftext;
  final int score;
  final int numComments;
  final DateTime createdUtc;
  final String permalink;
  final String url;
  final int relevanceScore;

  RedditThread({
    required this.id,
    required this.title,
    required this.author,
    required this.subreddit,
    required this.selftext,
    required this.score,
    required this.numComments,
    required this.createdUtc,
    required this.permalink,
    required this.url,
    required this.relevanceScore,
  });

  factory RedditThread.fromJson(
    Map<String, dynamic> json,
    Map<String, int> keywords,
  ) {
    final data = json['data'] as Map<String, dynamic>;
    final title = data['title'] as String? ?? '';
    final selftext = data['selftext'] as String? ?? '';
    final combined = '${title.toLowerCase()} ${selftext.toLowerCase()}';

    int relevance = 0;
    for (final entry in keywords.entries) {
      if (combined.contains(entry.key.toLowerCase())) {
        relevance += entry.value;
      }
    }

    return RedditThread(
      id: data['id'] as String? ?? '',
      title: title,
      author: data['author'] as String? ?? '',
      subreddit: data['subreddit'] as String? ?? '',
      selftext: selftext,
      score: (data['score'] as num?)?.toInt() ?? 0,
      numComments: (data['num_comments'] as num?)?.toInt() ?? 0,
      createdUtc: DateTime.fromMillisecondsSinceEpoch(
        ((data['created_utc'] as num?)?.toInt() ?? 0) * 1000,
        isUtc: true,
      ),
      permalink: data['permalink'] as String? ?? '',
      url: data['url'] as String? ?? '',
      relevanceScore: relevance,
    );
  }

  Map<String, dynamic> toCacheJson() => {
    'id': id,
    'title': title,
    'author': author,
    'subreddit': subreddit,
    'selftext': selftext,
    'score': score,
    'numComments': numComments,
    'createdUtc': createdUtc.millisecondsSinceEpoch,
    'permalink': permalink,
    'url': url,
    'relevanceScore': relevanceScore,
  };

  factory RedditThread.fromCacheJson(Map<String, dynamic> json) => RedditThread(
    id: json['id'] as String,
    title: json['title'] as String,
    author: json['author'] as String? ?? '',
    subreddit: json['subreddit'] as String,
    selftext: json['selftext'] as String,
    score: json['score'] as int,
    numComments: json['numComments'] as int,
    createdUtc: DateTime.fromMillisecondsSinceEpoch(json['createdUtc'] as int),
    permalink: json['permalink'] as String,
    url: json['url'] as String,
    relevanceScore: json['relevanceScore'] as int,
  );

  String get redditUrl => 'https://www.reddit.com$permalink';
}
