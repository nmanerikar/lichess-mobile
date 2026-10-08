import 'package:dartchess/dartchess.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lichess_mobile/src/model/common/chess.dart';
import 'package:lichess_mobile/src/widgets/move_notation_overlay.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  group('moveNotationOf', () {
    test('uses the destination square of the move', () {
      final notation = moveNotationOf(
        const SanMove('Nf3', NormalMove(from: Square.g1, to: Square.f3)),
        3,
      );
      expect(notation, (san: 'Nf3', square: Square.f3, ply: 3));
    });

    test('uses the king destination square when castling', () {
      expect(
        moveNotationOf(const SanMove('O-O', NormalMove(from: Square.e1, to: Square.h1)), 7)?.square,
        Square.g1,
      );
      expect(
        moveNotationOf(
          const SanMove('O-O-O+', NormalMove(from: Square.e8, to: Square.a8)),
          8,
        )?.square,
        Square.c8,
      );
    });

    test('returns null without a move', () {
      expect(moveNotationOf(null, 0), isNull);
    });
  });

  group('MoveNotationOverlay', () {
    const boardSize = 400.0;
    const squareSize = boardSize / 8;

    Future<ValueNotifier<MoveNotation?>> pumpOverlay(WidgetTester tester, Side orientation) async {
      final notifier = ValueNotifier<MoveNotation?>(null);
      addTearDown(notifier.dispose);
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: MoveNotationOverlay(
              notation: notifier,
              boardSize: boardSize,
              orientation: orientation,
            ),
          ),
        ),
      );
      return notifier;
    }

    testWidgets('centers the label on the target square', (WidgetTester tester) async {
      final notifier = await pumpOverlay(tester, Side.white);
      expect(find.text('e4'), findsNothing);

      notifier.value = (san: 'e4', square: Square.e4, ply: 1);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      final label = tester.getRect(find.text('e4'));
      // e-file is the 5th column, 4th rank is the 5th row from the top.
      expect(label.center.dx, closeTo(4.5 * squareSize, 0.5));
      expect(label.center.dy, closeTo(4.5 * squareSize, 0.5));

      // The label stays put while it fades out.
      await tester.pump(kMoveNotationDuration * 0.7);
      expect(tester.getRect(find.text('e4')).center, label.center);
    });

    testWidgets('flips the label position with the board orientation', (WidgetTester tester) async {
      final notifier = await pumpOverlay(tester, Side.black);

      notifier.value = (san: 'e4', square: Square.e4, ply: 1);
      await tester.pump();

      final label = tester.getRect(find.text('e4'));
      expect(label.center.dx, closeTo(3.5 * squareSize, 0.5));
      expect(label.center.dy, closeTo(3.5 * squareSize, 0.5));
    });

    testWidgets('keeps the label within the board', (WidgetTester tester) async {
      final notifier = await pumpOverlay(tester, Side.white);

      notifier.value = (san: 'Qxa8+', square: Square.a8, ply: 1);
      await tester.pump();
      await tester.pump(kMoveNotationDuration ~/ 2);

      final label = tester.getRect(find.byType(DecoratedBox));
      expect(label.left, greaterThanOrEqualTo(0.0));
      expect(label.top, greaterThanOrEqualTo(0.0));
    });

    testWidgets('fades out, and restarts on a new move', (WidgetTester tester) async {
      final notifier = await pumpOverlay(tester, Side.white);
      double opacity() => tester.widget<Opacity>(find.byType(Opacity)).opacity;

      notifier.value = (san: 'e4', square: Square.e4, ply: 1);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(opacity(), 1.0);

      await tester.pump(kMoveNotationDuration);
      expect(opacity(), 0.0);

      notifier.value = (san: 'e5', square: Square.e5, ply: 2);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('e5'), findsOneWidget);
      expect(find.text('e4'), findsNothing);
      expect(opacity(), 1.0);
    });

    testWidgets('hides the label when cleared', (WidgetTester tester) async {
      final notifier = await pumpOverlay(tester, Side.white);

      notifier.value = (san: 'e4', square: Square.e4, ply: 1);
      await tester.pump();
      expect(find.text('e4'), findsOneWidget);

      notifier.value = null;
      await tester.pump();
      expect(find.text('e4'), findsNothing);
    });
  });
}
