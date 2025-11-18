import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:kebunsalak_app/models/article.dart';
import 'package:kebunsalak_app/service/api_service.dart';

class ArticleDetailPage extends StatefulWidget {
  final String slug;
  final String? titlePreview;

  const ArticleDetailPage({super.key, required this.slug, this.titlePreview});

  @override
  State<ArticleDetailPage> createState() => _ArticleDetailPageState();
}

class _ArticleDetailPageState extends State<ArticleDetailPage> {
  late Future<Article> _future;
  String? _errorText;
  StackTrace? _errorStack;
  DateTime? _lastFetchAt;

  @override
  void initState() {
    super.initState();
    dev.log('Memuat detail: ${widget.slug}', name: 'ArticleDetail');
    _loadDetail();
  }

  void _loadDetail() {
    setState(() {
      _future = ApiService.fetchDetail(widget.slug).then((article) {
        _errorText = null;
        _errorStack = null;
        _lastFetchAt = DateTime.now();
        dev.log('Berhasil memuat detail: ${article.slug}', name: 'ArticleDetail');
        return article;
      }).catchError((e, st) {
        _errorText = e.toString();
        _errorStack = st;
        _lastFetchAt = DateTime.now();
        dev.log('Gagal memuat detail', error: e, stackTrace: st, name: 'ArticleDetail');
        throw e;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.titlePreview ?? 'Detail Artikel')),
      body: FutureBuilder<Article>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snap.hasError) {
            return _ErrorView(
              errorText: _errorText ?? snap.error.toString(),
              stack: _errorStack ?? snap.stackTrace,
              onRetry: _loadDetail,
              slug: widget.slug,
              lastFetch: _lastFetchAt,
            );
          }

          final a = snap.data!;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a.title, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                if ((a.body ?? '').trim().isEmpty)
                  const Text('Konten tidak tersedia.')
                else
                  Html(data: a.body!),
              ],
            ),
          );
        },
      ),
    );
  }
}

// 🔹 Widget untuk menampilkan error detail
class _ErrorView extends StatelessWidget {
  final String errorText;
  final StackTrace? stack;
  final VoidCallback onRetry;
  final String slug;
  final DateTime? lastFetch;

  const _ErrorView({
    required this.errorText,
    required this.onRetry,
    this.stack,
    required this.slug,
    this.lastFetch,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 50),
          const SizedBox(height: 8),
          Text('Gagal memuat artikel ($slug)',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          if (lastFetch != null)
            Text('Terakhir percobaan: $lastFetch',
                style: const TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(height: 12),
          SelectableText(
            errorText,
            style: const TextStyle(color: Colors.red),
          ),
          if (stack != null) ...[
            const SizedBox(height: 12),
            ExpansionTile(
              title: const Text('Lihat stacktrace'),
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SelectableText(stack.toString(),
                      style: const TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          Center(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Coba Lagi'),
              onPressed: onRetry,
            ),
          ),
        ],
      ),
    );
  }
}
