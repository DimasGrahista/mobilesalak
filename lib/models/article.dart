class Article {
  final int? id; // <- buat nullable agar aman
  final String slug;
  final String title;
  final String excerpt;
  final String? body;
  final String? thumbnailUrl;
  final bool isPublished;
  final DateTime? publishedAt;

  Article({
    required this.id,
    required this.slug,
    required this.title,
    required this.excerpt,
    this.body,
    this.thumbnailUrl,
    required this.isPublished,
    this.publishedAt,
  });

  factory Article.fromJson(Map<String, dynamic> json) {
    // id bisa int / string / null
    final dynamic idRaw = json['id'];
    final int? idParsed =
        (idRaw is int) ? idRaw : int.tryParse(idRaw?.toString() ?? '');

    // is_published bisa bool/int/string
    final dynamic pubRaw = json['is_published'];
    final bool isPublished = pubRaw == true || pubRaw == 1 || pubRaw == '1';

    // published_at bisa null/kosong
    DateTime? publishedAt;
    final pa = json['published_at'];
    if (pa != null && pa.toString().trim().isNotEmpty) {
      publishedAt = DateTime.tryParse(pa.toString());
    }

    return Article(
      id: idParsed,
      slug: (json['slug'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      excerpt: (json['excerpt'] ?? '').toString(),
      body: json['body']?.toString(),
      thumbnailUrl: json['thumbnail_url']?.toString(),
      isPublished: isPublished,
      publishedAt: publishedAt,
    );
  }
}
