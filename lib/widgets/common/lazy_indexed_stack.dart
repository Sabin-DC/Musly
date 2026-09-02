import 'package:flutter/material.dart';

class LazyIndexedStack extends StatefulWidget {
  final int index;
  final List<Widget> children;
  final AlignmentGeometry alignment;
  final TextDirection? textDirection;
  final StackFit sizing;

  const LazyIndexedStack({
    super.key,
    required this.index,
    required this.children,
    this.alignment = AlignmentDirectional.topStart,
    this.textDirection,
    this.sizing = StackFit.loose,
  });

  @override
  State<LazyIndexedStack> createState() => _LazyIndexedStackState();
}

class _LazyIndexedStackState extends State<LazyIndexedStack> {
  late final List<bool> _activated = List.generate(
    widget.children.length,
    (i) => i == widget.index,
  );
  late int _displayedIndex = widget.index;
  int? _pendingIndex;

  @override
  void didUpdateWidget(LazyIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    final target = widget.index;
    if (target < 0 || target >= _activated.length) return;

    if (_activated[target]) {
      _pendingIndex = null;
      _displayedIndex = target;
      return;
    }

    // Build a newly requested tab offstage for one frame before exposing it.
    // Changing both the render subtree and IndexedStack's visible semantics
    // child in one frame can leave an incomplete semantics fragment on recent
    // Flutter versions (the `node.built` scheduler assertion).
    _activated[target] = true;
    _pendingIndex = target;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _pendingIndex != target || widget.index != target) return;
      setState(() {
        _displayedIndex = target;
        _pendingIndex = null;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      index: _displayedIndex,
      alignment: widget.alignment,
      textDirection: widget.textDirection,
      sizing: widget.sizing,
      children: List.generate(widget.children.length, (i) {
        return _activated[i] ? widget.children[i] : const SizedBox.shrink();
      }),
    );
  }
}
