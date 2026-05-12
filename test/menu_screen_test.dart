import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flame/game.dart'; // Necessário para achar o GameWidget
import 'package:onebosssamuraibattle/menu_screen.dart';
import 'package:onebosssamuraibattle/settings_overlay.dart';
import 'package:onebosssamuraibattle/my_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Deve abrir configurações, alterar volume e iniciar modo remap', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: MenuScreen()));

    final btnConfig = find.widgetWithText(ElevatedButton, 'CONFIGURAÇÕES');
    expect(btnConfig, findsOneWidget);
    await tester.tap(btnConfig);

    await tester.pumpAndSettle();

    expect(find.byType(SettingsOverlay), findsOneWidget);

    expect(AudioManager.masterVolume, equals(1.0));

    final sliderMaster = find.byType(Slider).first;

    await tester.drag(sliderMaster, const Offset(-100.0, 0.0));
    await tester.pumpAndSettle();

    expect(AudioManager.masterVolume, lessThan(1.0));

    final abaControles = find.text("🎮 CONTROLES");
    await tester.tap(abaControles);
    await tester.pumpAndSettle();

    final btnRemap = find.widgetWithText(ElevatedButton, 'REMAPEAR HUD');
    expect(btnRemap, findsOneWidget);
    await tester.tap(btnRemap);
    await tester.pumpAndSettle();

    expect(find.byType(SettingsOverlay), findsNothing);

    expect(find.byType(GameWidget<MyPixelGame>), findsOneWidget);
  });
}
