import 'package:dartchess/dartchess.dart';
import 'package:flutter/foundation.dart';
import 'package:lichess_mobile/src/model/common/chess.dart';
import 'package:material_ui/material_ui.dart';

/// A move to flash on the board: its notation (e.g. `e4`, `Nxf3+`, `O-O`) and the square the
/// label is shown on.
///
/// [ply] tells apart two otherwise identical moves, so that each new move restarts the animation.
typedef MoveNotation = ({String san, Square square, int ply});

/// Builds the [MoveNotation] of the move that led to the position at [ply], or null if there is
/// no such move.
MoveNotation? moveNotationOf(SanMove? sanMove, int ply) {
  if (sanMove == null) return null;
  final san = sanMove.san;
  final to = sanMove.move.to;
  // Castling moves are encoded king-to-rook: show the label on the king's destination instead.
  final square = san.startsWith('O-O')
      ? Square.fromCoords(san.startsWith('O-O-O') ? File.c : File.g, to.rank)
      : to;
  return (san: san, square: square, ply: ply);
}

/// Total duration of the notation label animation.
const kMoveNotationDuration = Duration(milliseconds: 1500);

/// Shows the notation of the last move centered on its target square, then fades it out.
///
/// Meant to be stacked on top of a board of the same [boardSize]. It does not intercept pointer
/// events.
class const MoveNotationOverlay({
  /// The move to show. A new non-null value starts the animation again.
  required final ValueListenable<MoveNotation?> notation,
  required final double boardSize,
  required final Side orientation,
  super.key,
}) extends StatefulWidget {
  @override
  State<MoveNotationOverlay> createState() => _MoveNotationOverlayState();
}

class _MoveNotationOverlayState()
    extends State<MoveNotationOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: kMoveNotationDuration,
  );

  /// Quick fade in, hold, then a slow fade out.
  late final Animation<double> _opacity = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 8),
    TweenSequenceItem(tween: ConstantTween(1.0), weight: 47),
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 45),
  ]).animate(_controller);

  MoveNotation? _current;

  @override
  void initState() {
    super.initState();
    widget.notation.addListener(_onNotationChanged);
  }

  @override
  void didUpdateWidget(MoveNotationOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.notation != widget.notation) {
      oldWidget.notation.removeListener(_onNotationChanged);
      widget.notation.addListener(_onNotationChanged);
    }
  }

  @override
  void dispose() {
    widget.notation.removeListener(_onNotationChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onNotationChanged() {
    final notation = widget.notation.value;
    if (notation == null) {
      _controller.reset();
    } else {
      _controller.forward(from: 0.0);
    }
    setState(() {
      _current = notation;
    });
  }

  @override
  Widget build(BuildContext context) {
    final notation = _current;
    if (notation == null) return const SizedBox.shrink();

    final squareSize = widget.boardSize / 8;
    final file = notation.square.file;
    final rank = notation.square.rank;
    final column = widget.orientation == Side.white ? file : 7 - file;
    final row = widget.orientation == Side.white ? 7 - rank : rank;

    return IgnorePointer(
      child: SizedBox.square(
        dimension: widget.boardSize,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) => Opacity(opacity: _opacity.value, child: child),
          child: CustomSingleChildLayout(
            delegate: _NotationLayoutDelegate(
              anchor: Offset((column + 0.5) * squareSize, (row + 0.5) * squareSize),
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.all(Radius.circular(squareSize * 0.2)),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: squareSize * 0.15,
                  vertical: squareSize * 0.04,
                ),
                child: Text(
                  notation.san,
                  maxLines: 1,
                  softWrap: false,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: squareSize * 0.4,
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Centers the label on [anchor], keeping it within the board (e.g. long notations on the edge
/// files).
class const _NotationLayoutDelegate({required final Offset anchor})
    extends SingleChildLayoutDelegate {
  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) => constraints.loosen();

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final x = (anchor.dx - childSize.width / 2).clamp(0.0, size.width - childSize.width);
    final y = (anchor.dy - childSize.height / 2).clamp(0.0, size.height - childSize.height);
    return Offset(x, y);
  }

  @override
  bool shouldRelayout(_NotationLayoutDelegate oldDelegate) => oldDelegate.anchor != anchor;
}
