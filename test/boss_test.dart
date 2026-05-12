import 'package:flutter_test/flutter_test.dart';
import 'package:flame_test/flame_test.dart'; // O pacote oficial que resolve o ciclo de vida
import 'package:flame/components.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:onebosssamuraibattle/boss.dart';
import 'package:onebosssamuraibattle/my_game.dart';
import 'package:onebosssamuraibattle/player.dart';

@GenerateNiceMocks([MockSpec<Player>()])
import 'boss_test.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWithGame<MyPixelGame>(
    "Deve utilizar o arquivo 'estaca.png' ao carregar",
    MyPixelGame.new,
    (game) async {
      final mockPlayer = MockPlayer();

      final spike = Spike(
        player: mockPlayer,
        position: Vector2.zero(),
        targetScale: 1.0,
      );

      await game.ensureAdd(spike);

      expect(game.images.containsKey('estaca.png'), isTrue);
    },
  );
}
