import 'dart:async';
import 'package:flutter/material.dart';
import 'package:epubx/epubx.dart';
import 'package:html/parser.dart' as htmlparser;

class SearchResult {
  final int chapterIndex;
  final String snippet;
  SearchResult({required this.chapterIndex, required this.snippet});
}

class SearchScreen extends StatefulWidget {
  final List<EpubChapter> chapters;
  const SearchScreen({Key? key, required this.chapters}) : super(key: key);

  @override
  _SearchScreenState createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<SearchResult> _results = [];
  bool _isLoading = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    // Controller ko listen karein taaki clear button ko manage kar sakein
    _searchController.addListener(() {
      setState(() {}); 
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _performSearch() async {
    final query = _searchController.text.trim();
    if (query.length < 3) {
      if (mounted) {
        setState(() {
          _results = [];
          _isLoading = false;
        });
      }
      return;
    }

    if (mounted) setState(() => _isLoading = true);

    final List<SearchResult> foundResults = [];
    for (int i = 0; i < widget.chapters.length; i++) {
      final chapter = widget.chapters[i];
      if (chapter.HtmlContent == null) continue;
      final document = htmlparser.parse(chapter.HtmlContent);
      final String plainText = document.body?.text ?? '';
      if (plainText.toLowerCase().contains(query.toLowerCase())) {
        final index = plainText.toLowerCase().indexOf(query.toLowerCase());
        int start = index - 30 < 0 ? 0 : index - 30;
        int end = start + 100 > plainText.length ? plainText.length : start + 100;
        final snippet = plainText.substring(start, end);
        foundResults.add(SearchResult(chapterIndex: i, snippet: '...$snippet...'));
      }
    }

    if (mounted) {
      setState(() {
        _results = foundResults;
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _performSearch();
    });
  }
  
  void _clearSearch() {
    _searchController.clear();
    // Results ko bhi turant clear karein
    setState(() {
      _results = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // === YAHAN UI MEIN BADE BADLAV KIYE GAYE HAIN ===
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1.0,
        // Back button ka color set karein
        iconTheme: const IconThemeData(color: Colors.black54),
        // Title mein ek saaf search bar banayein
        title: Container(
          height: 45,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(25.0),
          ),
          child: TextField(
            controller: _searchController,
            autofocus: true,
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: 'Search in book...',
              hintStyle: TextStyle(color: Colors.grey[600]),
              // Search icon field ke andar
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              // Clear button (tabhi dikhega jab text ho)
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.grey),
                      onPressed: _clearSearch,
                    )
                  : null,
            ),
            onChanged: _onSearchChanged,
            onSubmitted: (_) => _performSearch(),
          ),
        ),
      ),
      // =================================================

      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_searchController.text.trim().isEmpty) {
      return const Center(child: Text('Enter a term to search in the book.'));
    }
    if (_results.isEmpty) {
      return const Center(child: Text('No results found.'));
    }
    return ListView.builder(
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final result = _results[index];
        final chapterTitle = widget.chapters[result.chapterIndex].Title ?? 'Chapter ${result.chapterIndex + 1}';
        return ListTile(
          title: Text(chapterTitle),
          subtitle: Text(
            result.snippet,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () {
            Navigator.pop(context, result.chapterIndex);
          },
        );
      },
    );
  }
}