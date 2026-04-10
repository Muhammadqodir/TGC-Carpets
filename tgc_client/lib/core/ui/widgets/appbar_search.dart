import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

class AppBarSearch extends StatefulWidget implements PreferredSizeWidget {
  const AppBarSearch({
    super.key,
    required this.title,
    this.backButton = false,
    this.actions,
    this.onChanged,
    required this.searchController,
  });

  final Widget title;
  final bool backButton;
  final List<Widget>? actions;
  final TextEditingController searchController;
  final Function(String)? onChanged;

  @override
  State<AppBarSearch> createState() => _AppBarSearchState();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _AppBarSearchState extends State<AppBarSearch> {
  bool isSearching = false;
  final FocusNode unitCodeCtrlFocusNode = FocusNode();

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: isSearching
          ? TextField(
              controller: widget.searchController,
              onChanged: widget.onChanged,
              focusNode: unitCodeCtrlFocusNode,
              cursorColor: Colors.white,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: Colors.white),
              decoration: InputDecoration(
                fillColor: Colors.transparent,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 0, vertical: 2),
                hintText: 'Search...',
                hintStyle: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(color: Colors.white),
                border: InputBorder.none,
              ),
            )
          : widget.title,
      leading: widget.backButton
          ? IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_ios_new_outlined, size: 20),
            )
          : null,
      titleSpacing: 0,
      actions: [
        IconButton(
          onPressed: () {
            setState(() => isSearching = !isSearching);
            if (!isSearching) {
              widget.searchController.clear();
              unitCodeCtrlFocusNode.unfocus();
            } else {
              unitCodeCtrlFocusNode.requestFocus();
            }
          },
          icon: HugeIcon(
              icon: isSearching
                  ? HugeIcons.strokeRoundedCancel01
                  : HugeIcons.strokeRoundedSearch01,
              strokeWidth: 2),
        ),
        ...widget.actions ?? [],
      ],
    );
  }
}
