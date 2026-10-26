import 'dart:convert';

import 'package:http/http.dart' as http;

class HackerNewsStory {
  const HackerNewsStory({
    required this.id,
    required this.title,
    required this.author,
    required this.score,
    required this.commentCount,
    required this.time,
    this.url,
  });

  final int id;
  final String title;
  final String author;
  final int score;
  final int commentCount;
  final DateTime time;
  final String? url;

  String get storyUrl => url ?? commentsUrl;

  String get commentsUrl => 'https://news.ycombinator.com/item?id=$id';

  factory HackerNewsStory.fromJson(Map<String, dynamic> json) {
    final seconds = json['time'] as int? ?? 0;

    return HackerNewsStory(
      id: json['id'] as int,
      title: json['title'] as String? ?? 'Untitled Hacker News story',
      author: json['by'] as String? ?? 'unknown',
      score: json['score'] as int? ?? 0,
      commentCount: json['descendants'] as int? ?? 0,
      time: DateTime.fromMillisecondsSinceEpoch(seconds * 1000),
      url: json['url'] as String?,
    );
  }
}

class HackerNewsService {
  HackerNewsService._();
  static final HackerNewsService instance = HackerNewsService._();

  static const _baseUrl = 'https://hacker-news.firebaseio.com/v0';

  Future<List<HackerNewsStory>> getTopStories({int limit = 6}) async {
    final response = await http
        .get(Uri.parse('$_baseUrl/topstories.json'))
        .timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) {
      throw Exception('Unable to load Hacker News stories.');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw Exception('Unexpected Hacker News response.');
    }

    final ids = decoded.whereType<int>();
    final storyResponses = await Future.wait(
      ids.take(limit * 2).map(_getStory),
    );

    return storyResponses.whereType<HackerNewsStory>().take(limit).toList();
  }

  Future<HackerNewsStory?> _getStory(int id) async {
    final response = await http
        .get(Uri.parse('$_baseUrl/item/$id.json'))
        .timeout(const Duration(seconds: 12));
    if (response.statusCode != 200 || response.body == 'null') return null;

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) return null;

    final data = decoded;
    if (data['type'] != 'story' ||
        data['deleted'] == true ||
        data['dead'] == true) {
      return null;
    }

    return HackerNewsStory.fromJson(data);
  }
}
