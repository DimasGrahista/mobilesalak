import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kebunsalak_app/models/article.dart';
import 'package:kebunsalak_app/service/api_service.dart';
import 'package:kebunsalak_app/config/config.dart';
import 'package:kebunsalak_app/page/artikelPage/article_detail_page.dart';

class PanduanPage extends StatefulWidget {
  const PanduanPage({super.key});

  @override
  State<PanduanPage> createState() => _PanduanPageState();
}

class _PanduanPageState extends State<PanduanPage> {
  String nama = '';
  String jabatan = '';
  late Future<List<Article>> _futureArticles;

  String? _lastErrorText;
  StackTrace? _lastStack;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _loadArticles();
  }

  Future<void> _loadArticles() async {
    dev.log('Memuat artikel dari: ${Config.apiUrl}/api/articles', name: 'PanduanPage');
    setState(() {
      _futureArticles = ApiService.fetchArticles().then((value) {
        _lastErrorText = null;
        _lastStack = null;
        dev.log('Berhasil memuat ${value.length} artikel', name: 'PanduanPage');
        return value;
      }).catchError((e, st) {
        _lastErrorText = e.toString();
        _lastStack = st;
        dev.log('Gagal memuat artikel', error: e, stackTrace: st, name: 'PanduanPage');
        throw e;
      });
    });
  }

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      nama = prefs.getString('nama') ?? 'User';
      jabatan = prefs.getString('jabatan') ?? '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Container(
          color: Colors.white,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF5E762F),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Halo, $nama 👋',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      jabatan,
                      style: const TextStyle(fontSize: 14, color: Colors.white70),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Daftar Artikel / Error / Loading
              Expanded(
                child: FutureBuilder<List<Article>>(
                  future: _futureArticles,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    } else if (snapshot.hasError) {
                      return _ErrorView(
                        errorText: _lastErrorText ?? snapshot.error.toString(),
                        stack: _lastStack ?? snapshot.stackTrace,
                        onRetry: _loadArticles,
                      );
                    } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Center(child: Text('Belum ada artikel.'));
                    }

                    final articles = snapshot.data!;
                    return ListView.builder(
                      itemCount: articles.length,
                      itemBuilder: (context, index) {
                        final a = articles[index];

                        // Navigasi ke detail artikel
                        return InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ArticleDetailPage(
                                  slug: a.slug,
                                  titlePreview: a.title,
                                ),
                              ),
                            );
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.article, color: Color.fromARGB(255, 110, 147, 37)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(a.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                      const SizedBox(height: 4),
                                      Text(
                                        a.excerpt,
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ],
                                  ),
                                )
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Widget error view
class _ErrorView extends StatelessWidget {
  final String errorText;
  final StackTrace? stack;
  final VoidCallback onRetry;

  const _ErrorView({
    required this.errorText,
    required this.onRetry,
    this.stack,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 40),
          const SizedBox(height: 8),
          const Text('Gagal memuat artikel', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          SelectableText(errorText, style: const TextStyle(color: Colors.red)),
          if (stack != null) ...[
            const SizedBox(height: 8),
            ExpansionTile(
              title: const Text('Lihat stacktrace'),
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SelectableText(stack.toString(), style: const TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          ElevatedButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text('Coba lagi'),
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}


