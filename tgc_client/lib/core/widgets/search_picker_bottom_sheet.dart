import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// A generic, reusable bottom sheet that provides debounced search + a
/// scrollable list of results. Pops with the selected item.
///
/// Usage:
/// ```dart
/// final ProductEntity? picked = await SearchPickerBottomSheet.show<ProductEntity>(
///   context,
///   title: 'Mahsulot tanlash',
///   searchHint: 'Nom yoki SKU...',
///   onSearch: (query) => datasource.getProducts(search: query),
///   itemBuilder: (context, product) => _ProductTile(product),
/// );
/// ```
class SearchPickerBottomSheet<T> extends StatefulWidget {
  final String title;
  final String searchHint;
  final Future<List<T>> Function(String query) onSearch;

  /// Builds the visual content for each result row. The sheet itself handles
  /// the tap and closes with the selected item.
  final Widget Function(BuildContext context, T item) itemBuilder;

  final String emptyText;
  final String errorText;

  const SearchPickerBottomSheet({
    super.key,
    required this.title,
    this.searchHint = 'Qidirish...',
    required this.onSearch,
    required this.itemBuilder,
    this.emptyText = 'Natija topilmadi.',
    this.errorText = 'Xatolik yuz berdi.',
  });

  /// Convenience helper that opens the sheet and returns the selected item.
  static Future<T?> show<T>(
    BuildContext context, {
    required String title,
    String searchHint = 'Qidirish...',
    required Future<List<T>> Function(String query) onSearch,
    required Widget Function(BuildContext context, T item) itemBuilder,
    String emptyText = 'Natija topilmadi.',
    String errorText = 'Xatolik yuz berdi.',
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SearchPickerBottomSheet<T>(
        title: title,
        searchHint: searchHint,
        onSearch: onSearch,
        itemBuilder: itemBuilder,
        emptyText: emptyText,
        errorText: errorText,
      ),
    );
  }

  @override
  State<SearchPickerBottomSheet<T>> createState() =>
      _SearchPickerBottomSheetState<T>();
}

class _SearchPickerBottomSheetState<T>
    extends State<SearchPickerBottomSheet<T>> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  List<T> _results = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchResults('');
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _fetchResults(query.trim());
    });
  }

  Future<void> _fetchResults(String query) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await widget.onSearch(query);
      if (!mounted) return;
      setState(() {
        _results = results;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = widget.errorText;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: screenHeight * 0.88),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Handle bar ─────────────────────────────────────────────
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // ── Title ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ],
            ),
          ),

          // ── Search field ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              autofocus: true,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: widget.searchHint,
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
                suffixIcon: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _searchCtrl,
                  builder: (_, val, __) => val.text.isEmpty
                      ? const SizedBox.shrink()
                      : IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchCtrl.clear();
                            _onSearchChanged('');
                          },
                        ),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                      color: AppColors.primaryLight, width: 1.5),
                ),
              ),
            ),
          ),

          // const Divider(height: 1),

          // ── Results ────────────────────────────────────────────────
          Flexible(
            child: _buildBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: AppColors.error, size: 32),
              const SizedBox(height: 8),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => _fetchResults(_searchCtrl.text.trim()),
                child: const Text('Qayta urinish'),
              ),
            ],
          ),
        ),
      );
    }

    if (_results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            widget.emptyText,
            style: const TextStyle(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: _results.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, indent: 16, endIndent: 16),
      itemBuilder: (context, index) {
        final item = _results[index];
        return InkWell(
          onTap: () => Navigator.of(context).pop(item),
          child: widget.itemBuilder(context, item),
        );
      },
    );
  }
}
