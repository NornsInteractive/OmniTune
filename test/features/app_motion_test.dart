import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music/core/widgets/studio_chrome.dart';

double _pressableScale(WidgetTester tester) {
  final finder = find.descendant(
    of: find.byType(StudioPressable),
    matching: find.byType(Transform),
  );
  expect(finder, findsWidgets);
  final matrix = tester.widget<Transform>(finder.first).transform;
  final scale = matrix.storage[0];
  expect(matrix.storage[5], moreOrLessEquals(scale));
  return scale;
}

double _entranceOpacity(WidgetTester tester) {
  final finder = find.descendant(
    of: find.byType(StudioEntranceTransition),
    matching: find.byType(Opacity),
  );
  expect(finder, findsOneWidget);
  return tester.widget<Opacity>(finder).opacity;
}

Offset _entranceTranslation(WidgetTester tester) {
  final finder = find.descendant(
    of: find.byType(StudioEntranceTransition),
    matching: find.byType(Transform),
  );
  expect(finder, findsOneWidget);
  final translation = tester
      .widget<Transform>(finder)
      .transform
      .getTranslation();
  return Offset(translation.x, translation.y);
}

void main() {
  testWidgets(
    'StudioEntranceTransition fades, slides, settles, and stays settled under reduced motion',
    (tester) async {
      Widget animatedTree(String label) => Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: StudioEntranceTransition(
            child: Text(label, key: ValueKey<String>(label)),
          ),
        ),
      );

      await tester.pumpWidget(animatedTree('motion-a'));
      expect(find.byType(StudioEntranceTransition), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 100));
      final partialOpacity = _entranceOpacity(tester);
      expect(partialOpacity, greaterThan(0.0));
      expect(partialOpacity, lessThan(1.0));
      final partialTranslation = _entranceTranslation(tester);
      expect(partialTranslation.dy, greaterThan(0.0));
      expect(partialTranslation.dy, lessThan(10.0));
      expect(partialTranslation.dx, moreOrLessEquals(0.0));
      expect(tester.binding.transientCallbackCount, greaterThan(0));

      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump();
      expect(_entranceOpacity(tester), moreOrLessEquals(1.0));
      expect(_entranceTranslation(tester), Offset.zero);
      expect(tester.binding.transientCallbackCount, 0);

      Widget disabledTree(String label) => MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: animatedTree(label),
      );

      await tester.pumpWidget(disabledTree('motion-a'));
      expect(_entranceOpacity(tester), moreOrLessEquals(1.0));
      expect(_entranceTranslation(tester), Offset.zero);
      expect(tester.binding.transientCallbackCount, 0);

      await tester.pumpWidget(disabledTree('motion-b'));
      expect(_entranceOpacity(tester), moreOrLessEquals(1.0));
      expect(_entranceTranslation(tester), Offset.zero);
      expect(tester.binding.transientCallbackCount, 0);

      await tester.pumpWidget(disabledTree('motion-c'));
      expect(_entranceOpacity(tester), moreOrLessEquals(1.0));
      expect(_entranceTranslation(tester), Offset.zero);
      expect(tester.binding.transientCallbackCount, 0);
    },
  );

  testWidgets(
    'entrance keeps ListView scroll state across dynamic reduced-motion toggles',
    (tester) async {
      final disableAnimations = ValueNotifier<bool>(false);
      addTearDown(disableAnimations.dispose);

      Widget build() => ValueListenableBuilder<bool>(
        valueListenable: disableAnimations,
        builder: (context, disabled, child) => MediaQuery(
          data: MediaQueryData(disableAnimations: disabled),
          child: child!,
        ),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: StudioEntranceTransition(
            child: ListView.builder(
              itemCount: 80,
              itemBuilder: (context, index) =>
                  SizedBox(height: 40, child: Text('item-$index')),
            ),
          ),
        ),
      );

      await tester.pumpWidget(build());
      await tester.pumpAndSettle();

      final scrollableFinder = find.descendant(
        of: find.byType(ListView),
        matching: find.byType(Scrollable),
      );
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pumpAndSettle();

      final ScrollableState scrollable = tester.state<ScrollableState>(
        scrollableFinder,
      );
      final double pixels = scrollable.position.pixels;
      expect(pixels, greaterThan(0.0));

      disableAnimations.value = true;
      await tester.pump();
      expect(tester.state<ScrollableState>(scrollableFinder), same(scrollable));
      expect(scrollable.position.pixels, pixels);
      expect(tester.binding.transientCallbackCount, 0);

      disableAnimations.value = false;
      await tester.pump();
      expect(tester.state<ScrollableState>(scrollableFinder), same(scrollable));
      expect(scrollable.position.pixels, pixels);
      expect(tester.binding.transientCallbackCount, 0);
    },
  );

  testWidgets(
    'pressable presses, taps, activates by key, and snaps under reduced motion',
    (tester) async {
      int parentCalls = 0;
      int childCalls = 0;
      final childFocusNode = FocusNode();
      addTearDown(childFocusNode.dispose);

      Widget build({required bool disableAnimations}) => MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 320,
                height: 320,
                child: StudioPressable(
                  pressedScale: 0.98,
                  onTap: () => parentCalls++,
                  child: SizedBox.expand(
                    child: Column(
                      children: [
                        const Expanded(
                          child: SizedBox(key: Key('pressable-blank')),
                        ),
                        TextButton(
                          focusNode: childFocusNode,
                          onPressed: () => childCalls++,
                          child: const Text('pressable-child'),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpWidget(build(disableAnimations: false));
      await tester.pumpAndSettle();

      final blankFinder = find.byKey(const Key('pressable-blank'));
      final childFinder = find.byType(TextButton);

      final gesture = await tester.startGesture(tester.getCenter(blankFinder));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      final midScale = _pressableScale(tester);
      expect(midScale, lessThan(1.0));
      expect(midScale, greaterThan(0.98));

      await gesture.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(_pressableScale(tester), moreOrLessEquals(1.0));
      expect(parentCalls, 1);
      await tester.pump(const Duration(milliseconds: 700));
      expect(_pressableScale(tester), moreOrLessEquals(1.0));
      expect(tester.binding.transientCallbackCount, 0);

      await tester.tap(childFinder);
      await tester.pump(const Duration(milliseconds: 300));
      expect(childCalls, 1);
      expect(parentCalls, 1);

      childFocusNode.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump(const Duration(milliseconds: 300));
      expect(childCalls, 2);
      expect(parentCalls, 1);

      await tester.pumpAndSettle();
      await tester.pumpWidget(build(disableAnimations: true));
      await tester.pump();

      final reducedGesture = await tester.startGesture(
        tester.getCenter(blankFinder),
      );
      await tester.pump();
      await tester.pump();
      expect(_pressableScale(tester), moreOrLessEquals(0.98));

      await reducedGesture.up();
      await tester.pump();
      await tester.pump();
      expect(_pressableScale(tester), moreOrLessEquals(1.0));
      await tester.pump(const Duration(milliseconds: 700));
      expect(_pressableScale(tester), moreOrLessEquals(1.0));
      expect(tester.binding.transientCallbackCount, 0);
    },
  );
}
