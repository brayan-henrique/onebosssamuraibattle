import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/input.dart';
import 'package:flame/events.dart';
import 'package:flame/sprite.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/material.dart';
import 'player.dart';
import 'boss.dart';
import 'settings_overlay.dart';

// ==========================================
// CLASSES PARA O REMAPEAMENTO (SINCRONIZADAS)
// ==========================================

class RemappableButton extends PositionComponent
    with TapCallbacks, DragCallbacks, HasGameRef<MyPixelGame> {
  final VoidCallback onPressed;
  final VoidCallback? onReleased;
  final Color debugColor;

  RemappableButton({
    required Vector2 position,
    required Vector2 size,
    required this.onPressed,
    this.onReleased,
    required Component content,
    this.debugColor = Colors.green,
  }) : super(position: position, size: size, anchor: Anchor.center) {
    add(content);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (gameRef.isEditingHUD) {
      canvas.drawRect(
        size.toRect(),
        Paint()
          ..color = debugColor.withOpacity(0.4)
          ..style = PaintingStyle.fill,
      );
    }
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (gameRef.isEditingHUD) return;
    scale.setAll(0.9);
    onPressed();
  }

  @override
  void onTapUp(TapUpEvent event) {
    if (gameRef.isEditingHUD) return;
    scale.setAll(1.0);
    onReleased?.call();
  }

  @override
  void onTapCancel(TapCancelEvent event) {
    if (gameRef.isEditingHUD) return;
    scale.setAll(1.0);
    onReleased?.call();
  }

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    if (!gameRef.isEditingHUD) return;
    scale.setAll(1.2);
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    super.onDragUpdate(event);
    if (!gameRef.isEditingHUD) return;
    position.add(event.localDelta);
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    if (!gameRef.isEditingHUD) return;
    scale.setAll(1.0);
  }
}

class JoystickDragHandle extends PositionComponent with DragCallbacks {
  final JoystickComponent target;

  JoystickDragHandle(this.target)
    : super(size: Vector2(120, 120), anchor: Anchor.center);

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    canvas.drawCircle(
      (size / 2).toOffset(),
      size.x / 2,
      Paint()..color = Colors.blue.withOpacity(0.3),
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    position.setFrom(target.position);
  }

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    target.scale.setAll(1.2);
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    super.onDragUpdate(event);
    target.position.add(event.localDelta);
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    target.scale.setAll(1.0);
  }
}

// ==========================================
// COMPONENTES DE HUD (BARRAS DE VIDA)
// ==========================================

class BossHealthBar extends PositionComponent with HasGameRef<MyPixelGame> {
  final Boss boss;
  BossHealthBar(this.boss)
    : super(position: Vector2(200, 20), size: Vector2(400, 20));

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    canvas.drawRect(size.toRect(), Paint()..color = Colors.grey.withAlpha(150));
    double healthRatio = boss.currentHealth / boss.maxHealth;
    if (healthRatio > 0) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.x * healthRatio, size.y),
        Paint()..color = Colors.red,
      );
    }
  }
}

class PlayerHealthBar extends PositionComponent with HasGameRef<MyPixelGame> {
  final Player player;
  Sprite? gotaCheia;
  Sprite? gotaVazia;
  SpriteAnimationTicker? gotaMetadeTicker;
  Sprite? fundoHud;

  final Vector2 tamanhoFundo = Vector2(258, 58);
  final double posGotasX = 60.0;
  final double posBarraX = 52.0;
  final double posGotasY = 5.0;
  final double espacamentoGotas = 36.0;
  final Vector2 tamanhoGota = Vector2.all(32);
  final double posBarraY = 40.0;
  final double larguraBarra = 200.0;
  final double alturaBarra = 12.0;
  final double posTextosX = 5.0;
  final double posHitsY = 75.0;
  final double posComboY = 105.0;

  final TextPaint hitCountPaint = TextPaint(
    style: const TextStyle(
      color: Colors.white,
      fontSize: 26,
      fontWeight: FontWeight.bold,
      fontStyle: FontStyle.italic,
      shadows: [
        Shadow(color: Colors.redAccent, blurRadius: 4, offset: Offset(2, 2)),
      ],
    ),
  );
  final TextPaint comboPaint = TextPaint(
    style: const TextStyle(
      color: Colors.yellowAccent,
      fontSize: 18,
      fontWeight: FontWeight.bold,
      letterSpacing: 1.0,
      shadows: [
        Shadow(color: Colors.black, blurRadius: 4, offset: Offset(2, 2)),
      ],
    ),
  );

  PlayerHealthBar(this.player)
    : super(position: Vector2(20, 50), size: Vector2(258, 150));

  @override
  Future<void> onLoad() async {
    try {
      fundoHud = await gameRef.loadSprite('hud_vida.png');
    } catch (e) {}
    try {
      gotaCheia = await gameRef.loadSprite('gota_cheia.png');
    } catch (e) {}
    try {
      gotaVazia = await gameRef.loadSprite('gota_vazia.png');
    } catch (e) {}
    try {
      final anim = await gameRef.loadSpriteAnimation(
        'gota_metade.png',
        SpriteAnimationData.sequenced(
          amount: 9,
          stepTime: 0.1,
          textureSize: Vector2.all(16),
        ),
      );
      gotaMetadeTicker = anim.createTicker();
    } catch (e) {}
  }

  @override
  void update(double dt) {
    super.update(dt);
    gotaMetadeTicker?.update(dt);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (fundoHud != null) {
      fundoHud!.render(canvas, position: Vector2.zero(), size: tamanhoFundo);
    } else {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, tamanhoFundo.x, tamanhoFundo.y),
        Paint()..color = Colors.black.withOpacity(0.5),
      );
    }
    for (int i = 0; i < 5; i++) {
      double xAtual = posGotasX + (i * espacamentoGotas);
      Vector2 pos = Vector2(xAtual, posGotasY);
      if (player.health >= i + 1) {
        if (gotaCheia != null)
          gotaCheia!.render(canvas, position: pos, size: tamanhoGota);
      } else if (player.health > i && player.health < i + 1) {
        if (gotaMetadeTicker != null)
          gotaMetadeTicker!.getSprite().render(
            canvas,
            position: pos,
            size: tamanhoGota,
          );
      } else {
        if (gotaVazia != null)
          gotaVazia!.render(canvas, position: pos, size: tamanhoGota);
      }
    }
    canvas.drawRect(
      Rect.fromLTWH(posBarraX, posBarraY, larguraBarra, alturaBarra),
      Paint()..color = Colors.grey.withAlpha(150),
    );
    if (player.specialMeter > 0) {
      double fillRatio = player.specialMeter / 100.0;
      canvas.drawRect(
        Rect.fromLTWH(
          posBarraX,
          posBarraY,
          larguraBarra * fillRatio,
          alturaBarra,
        ),
        Paint()..color = Colors.blueAccent,
      );
    }
    if (player.hitCount >= 2)
      hitCountPaint.render(
        canvas,
        '${player.hitCount} HITS!',
        Vector2(posTextosX, posHitsY),
      );
    if (player.comboMultiplier > 1)
      comboPaint.render(
        canvas,
        'Combo ${player.comboMultiplier}x',
        Vector2(posTextosX, posComboY),
      );
  }
}

// ==========================================
// CLASSE PRINCIPAL DO JOGO
// ==========================================

class MyPixelGame extends FlameGame with HasCollisionDetection {
  late final JoystickComponent joystick;
  late final JoystickDragHandle joystickHandle;
  late final Player player;
  late final Boss boss;
  final VoidCallback? onBackToMenu;
  final bool startInRemapMode;

  int sunClickCount = 0;
  bool cheatUnlocked = false;
  bool bossDamageDisabled = false;

  bool _isEditingHUD = false;
  bool get isEditingHUD => _isEditingHUD;
  set isEditingHUD(bool value) {
    _isEditingHUD = value;
    if (value) {
      camera.viewport.add(joystickHandle);
    } else {
      if (joystickHandle.parent != null) joystickHandle.removeFromParent();
    }
  }

  MyPixelGame({this.onBackToMenu, this.startInRemapMode = false})
    : super(
        camera: CameraComponent.withFixedResolution(width: 800, height: 360),
      );

  @override
  Future<void> onLoad() async {
    camera.viewfinder.anchor = Anchor.topLeft;

    try {
      await FlameAudio.audioCache.loadAll([
        'musica_padrao.mp3',
        'musica_morte.mp3',
        'andar.mp3',
        'som_pulo_chao.mp3',
        'impacto_boss.mp3',
      ]);
      FlameAudio.bgm.initialize();
      if (!startInRemapMode) {
        FlameAudio.bgm.play('musica_padrao.mp3', volume: AudioManager.bgm);
      }
    } catch (e) {}

    try {
      world.add(
        SpriteComponent(
          sprite: await loadSprite('ceu_limpo.png'),
          size: Vector2(800, 360),
        ),
      );
    } catch (e) {}
    try {
      final nuvensAnim = await loadSpriteAnimation(
        'nuvens_dafault.png',
        SpriteAnimationData.sequenced(
          amount: 52,
          stepTime: 0.15,
          textureSize: Vector2(267, 120),
        ),
      );
      world.add(
        SpriteAnimationComponent(
          animation: nuvensAnim,
          size: Vector2(800, 360),
        ),
      );
    } catch (e) {}
    try {
      world.add(
        SpriteComponent(
          sprite: await loadSprite('chao_default.png'),
          size: Vector2(800, 360),
        ),
      );
    } catch (e) {}

    camera.viewport.add(
      HudButtonComponent(
        button: RectangleComponent(
          size: Vector2(80, 80),
          paint: Paint()..color = Colors.transparent,
        ),
        position: Vector2(700, 32),
        onPressed: () {
          if (isEditingHUD) return;
          if (cheatUnlocked && !overlays.isActive('CheatMenu')) {
            pauseEngine();
            overlays.add('CheatMenu');
          }
        },
      ),
    );

    joystick = JoystickComponent(
      knob: CircleComponent(
        radius: 20,
        paint: Paint()..color = Colors.white.withAlpha(128),
      ),
      background: CircleComponent(
        radius: 50,
        paint: Paint()..color = Colors.white.withAlpha(51),
      ),
      position: Vector2(90, 270),
    );
    camera.viewport.add(joystick);
    joystickHandle = JoystickDragHandle(joystick);

    player = Player(joystick: joystick)..priority = 10;
    boss = Boss(player: player)..priority = 5;

    boss.position = Vector2(600, 278);
    player.boss = boss;

    world.add(player);
    world.add(boss);

    camera.viewport.add(BossHealthBar(boss));
    camera.viewport.add(PlayerHealthBar(player));

    camera.viewport.add(
      await _criarBotaoPause(
        imagem: 'icone_pause.png',
        corFundo: Colors.black,
        raio: 20,
        margem: const EdgeInsets.only(top: 20, right: 20),
        onPressed: () {
          if (isEditingHUD) return;
          pauseEngine();
          FlameAudio.bgm.pause();
          overlays.add('PauseMenu');
        },
      ),
    );

    camera.viewport.add(
      await _criarBotaoRemapeavel(
        imagem: 'icone_ataque_basico-1.png',
        corFundo: Colors.red,
        raio: 25,
        posicao: Vector2(745, 305),
        onPressed: () => player.basicAttack(),
        debugColor: Colors.red,
      ),
    );

    camera.viewport.add(
      await _criarBotaoRemapeavel(
        imagem: 'icone_pulo-1.png',
        corFundo: Colors.green,
        raio: 25,
        posicao: Vector2(745, 245),
        onPressed: () => player.jump(),
        debugColor: Colors.green,
      ),
    );

    camera.viewport.add(
      await _criarBotaoRemapeavel(
        imagem: 'icon_dash-1.png',
        corFundo: Colors.yellow,
        raio: 25,
        posicao: Vector2(685, 305),
        onPressed: () => player.dash(),
        debugColor: Colors.yellow,
      ),
    );

    // MÁGICA AQUI: O botão não é mais segurado. É apenas um trigger (Aperto rápido).
    camera.viewport.add(
      await _criarBotaoRemapeavel(
        imagem: 'Escudo_icone-1.png',
        corFundo: Colors.blue,
        raio: 25,
        posicao: Vector2(685, 245),
        onPressed: () => player.tentarParry(),
        // NOTA: O onReleased foi removido de propósito aqui!
        debugColor: Colors.blue,
      ),
    );

    camera.viewport.add(
      RemappableButton(
        content: CircleComponent(
          radius: 20,
          paint: Paint()..color = Colors.purple.withAlpha(200),
        ),
        position: Vector2(720, 190),
        size: Vector2.all(40),
        onPressed: () => player.specialAttack(),
        debugColor: Colors.purple,
      ),
    );

    if (startInRemapMode) {
      isEditingHUD = true;
      overlays.add('RemapHUD');
    }
  }

  void resetGame() {
    player.health = 5.0;
    player.specialMeter = 0.0;
    player.comboMultiplier = 1;
    player.hitCount = 0;
    player.continuousHitTimer = 0.0;
    player.timeSinceLastHit = 0.0;
    player.decayTimer = 0.0;
    player.position = Vector2(100, player.groundLevelY);
    player.velocity = Vector2.zero();
    player.isInvincible = false;
    player.isParrying = false; // Reset atualizado!
    player.isJumping = false;
    player.isDashing = false;
    player.dashCooldownTimer = 0.0;
    player.isParryFailAnim = false; // Tira ele do stagger

    boss.resetBoss();

    world.children.whereType<Kunai>().forEach(
      (kunai) => kunai.removeFromParent(),
    );
    world.children.whereType<VictoryLetter>().forEach(
      (c) => c.removeFromParent(),
    );
    world.children.whereType<VictoryButton>().forEach(
      (c) => c.removeFromParent(),
    );
    world.children.whereType<BossExplosion>().forEach(
      (c) => c.removeFromParent(),
    );

    resumeEngine();
  }

  Future<HudButtonComponent> _criarBotaoPause({
    required String imagem,
    required Color corFundo,
    required double raio,
    required EdgeInsets margem,
    required VoidCallback onPressed,
  }) async {
    final fundoBotao = CircleComponent(
      radius: raio,
      paint: Paint()..color = corFundo.withAlpha(180),
    );
    try {
      final sprite = await loadSprite(imagem);
      fundoBotao.add(
        SpriteComponent(
          sprite: sprite,
          size: Vector2.all(raio * 1.2),
          anchor: Anchor.center,
          position: Vector2(raio, raio),
        ),
      );
    } catch (e) {}

    return HudButtonComponent(
      button: fundoBotao,
      margin: margem,
      onPressed: onPressed,
    );
  }

  Future<RemappableButton> _criarBotaoRemapeavel({
    required String imagem,
    required Color corFundo,
    required double raio,
    required Vector2 posicao,
    required VoidCallback onPressed,
    VoidCallback? onReleased,
    required Color debugColor,
  }) async {
    final fundoBotao = CircleComponent(
      radius: raio,
      paint: Paint()..color = corFundo.withAlpha(180),
    );
    try {
      final sprite = await loadSprite(imagem);
      fundoBotao.add(
        SpriteComponent(
          sprite: sprite,
          size: Vector2.all(raio * 1.2),
          anchor: Anchor.center,
          position: Vector2(raio, raio),
        ),
      );
    } catch (e) {}

    return RemappableButton(
      content: fundoBotao,
      position: posicao,
      size: Vector2.all(raio * 2),
      onPressed: onPressed,
      onReleased:
          onReleased, // No botão do escudo, ele vai enviar "nulo" e ignorar
      debugColor: debugColor,
    );
  }
}
