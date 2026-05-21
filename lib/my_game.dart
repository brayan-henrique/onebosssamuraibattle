import 'dart:math';
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/input.dart';
import 'package:flame/events.dart';
import 'package:flame/sprite.dart';
import 'package:flame/effects.dart';
import 'package:flame/collisions.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'player.dart';
import 'boss.dart';
import 'settings_overlay.dart';

class HudConfig {
  static Vector2 joystickPos = Vector2(90, 270);
  static Vector2 attackBtnPos = Vector2(745, 305);
  static Vector2 jumpBtnPos = Vector2(745, 245);
  static Vector2 dashBtnPos = Vector2(685, 305);
  static Vector2 parryBtnPos = Vector2(685, 245);
  static Vector2 specialBtnPos = Vector2(720, 190);

  static void resetToDefault() {
    joystickPos = Vector2(90, 270);
    attackBtnPos = Vector2(745, 305);
    jumpBtnPos = Vector2(745, 245);
    dashBtnPos = Vector2(685, 305);
    parryBtnPos = Vector2(685, 245);
    specialBtnPos = Vector2(720, 190);
  }
}

// ESTADOS DA CINEMÁTICA INICIAL
enum IntroState {
  initialShake,
  playingGate,
  waitingForBoss,
  bossFalling,
  fadingHud,
  finished,
}

class RemappableButton extends PositionComponent
    with TapCallbacks, DragCallbacks, HasGameRef<MyPixelGame> {
  final VoidCallback onPressed;
  final VoidCallback? onReleased;
  final Color debugColor;
  final CircleComponent fundoBotao;
  final SpriteComponent? iconeSprite;
  final Color corOriginal;

  RemappableButton({
    required Vector2 position,
    required Vector2 size,
    required this.onPressed,
    this.onReleased,
    required this.fundoBotao,
    this.iconeSprite,
    required this.corOriginal,
    required Component content,
    this.debugColor = Colors.green,
  }) : super(position: position, size: size, anchor: Anchor.center) {
    add(content);
  }

  void atualizarOpacidade(double opacidade) {
    fundoBotao.paint.color = corOriginal.withOpacity(0.7 * opacidade);
    iconeSprite?.paint.color = Colors.white.withOpacity(opacidade);
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

class BossHealthBar extends PositionComponent with HasGameRef<MyPixelGame> {
  final Boss boss;
  BossHealthBar(this.boss)
    : super(position: Vector2(200, 20), size: Vector2(400, 20));

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    canvas.drawRect(
      size.toRect(),
      Paint()..color = Colors.grey.withOpacity(0.6 * gameRef.hudOpacity),
    );
    double healthRatio = boss.currentHealth / boss.maxHealth;
    if (healthRatio > 0) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.x * healthRatio, size.y),
        Paint()..color = Colors.red.withOpacity(gameRef.hudOpacity),
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
  final double posGotasY = 5.0;
  final double espacamentoGotas = 36.0;
  final Vector2 tamanhoGota = Vector2.all(32);
  final double posBarraX = 52.0;
  final double posBarraY = 40.0;
  final double larguraBarra = 200.0;
  final double alturaBarra = 12.0;
  final double posTextosX = 5.0;
  final double posHitsY = 75.0;
  final double posComboY = 105.0;

  double shakeTimer = 0.0;
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
    if (player.specialMeter >= 100.0) {
      shakeTimer += dt;
    } else {
      shakeTimer = 0.0;
    }
  }

  @override
  void render(Canvas canvas) {
    if (gameRef.hudOpacity <= 0) return;
    canvas.save();

    if (player.specialMeter >= 100.0) {
      double offsetX = (Random().nextDouble() - 0.5) * 5;
      double offsetY = (Random().nextDouble() - 0.5) * 5;
      canvas.translate(offsetX, offsetY);
    }

    super.render(canvas);

    if (fundoHud != null) {
      fundoHud!.render(
        canvas,
        position: Vector2.zero(),
        size: tamanhoFundo,
        overridePaint: Paint()
          ..color = Colors.white.withOpacity(gameRef.hudOpacity),
      );
    }

    for (int i = 0; i < 5; i++) {
      double xAtual = posGotasX + (i * espacamentoGotas);
      Vector2 pos = Vector2(xAtual, posGotasY);
      if (player.health >= i + 1) {
        if (gotaCheia != null)
          gotaCheia!.render(
            canvas,
            position: pos,
            size: tamanhoGota,
            overridePaint: Paint()
              ..color = Colors.white.withOpacity(gameRef.hudOpacity),
          );
      } else if (player.health > i && player.health < i + 1) {
        if (gotaMetadeTicker != null)
          gotaMetadeTicker!.getSprite().render(
            canvas,
            position: pos,
            size: tamanhoGota,
            overridePaint: Paint()
              ..color = Colors.white.withOpacity(gameRef.hudOpacity),
          );
      } else {
        if (gotaVazia != null)
          gotaVazia!.render(
            canvas,
            position: pos,
            size: tamanhoGota,
            overridePaint: Paint()
              ..color = Colors.white.withOpacity(gameRef.hudOpacity),
          );
      }
    }

    double gap = 4.0;
    double halfWidth = (larguraBarra - gap) / 2;
    canvas.drawRect(
      Rect.fromLTWH(posBarraX, posBarraY, halfWidth, alturaBarra),
      Paint()..color = Colors.grey.withOpacity(0.6 * gameRef.hudOpacity),
    );
    canvas.drawRect(
      Rect.fromLTWH(
        posBarraX + halfWidth + gap,
        posBarraY,
        halfWidth,
        alturaBarra,
      ),
      Paint()..color = Colors.grey.withOpacity(0.6 * gameRef.hudOpacity),
    );

    Paint specialPaint = Paint()
      ..color = Colors.blueAccent.withOpacity(gameRef.hudOpacity);
    if (player.specialMeter >= 100.0) {
      if ((shakeTimer * 10).floor() % 2 == 0)
        specialPaint.color = Colors.purpleAccent.withOpacity(
          gameRef.hudOpacity,
        );
      else
        specialPaint.color = Colors.redAccent.withOpacity(gameRef.hudOpacity);
    }

    if (player.specialMeter > 0) {
      double bar1Ratio = (player.specialMeter >= 50.0)
          ? 1.0
          : (player.specialMeter / 50.0);
      canvas.drawRect(
        Rect.fromLTWH(posBarraX, posBarraY, halfWidth * bar1Ratio, alturaBarra),
        specialPaint,
      );
      if (player.specialMeter > 50.0) {
        double bar2Ratio = (player.specialMeter - 50.0) / 50.0;
        canvas.drawRect(
          Rect.fromLTWH(
            posBarraX + halfWidth + gap,
            posBarraY,
            halfWidth * bar2Ratio,
            alturaBarra,
          ),
          specialPaint,
        );
      }
    }

    if (player.hitCount >= 2)
      TextPaint(
        style: TextStyle(
          color: Colors.white.withOpacity(gameRef.hudOpacity),
          fontSize: 26,
          fontWeight: FontWeight.bold,
          fontStyle: FontStyle.italic,
        ),
      ).render(
        canvas,
        '${player.hitCount} HITS!',
        Vector2(posTextosX, posHitsY),
      );
    if (player.comboMultiplier > 1)
      TextPaint(
        style: TextStyle(
          color: Colors.yellowAccent.withOpacity(gameRef.hudOpacity),
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ).render(
        canvas,
        'Combo ${player.comboMultiplier}x',
        Vector2(posTextosX, posComboY),
      );

    canvas.restore();
  }
}

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

  // VARIÁVEIS DA CINEMÁTICA
  IntroState introState = IntroState.initialShake;
  double introTimer = 0.0;
  bool hasVibratedGate = false;
  double hudOpacity = 0.0;
  SpriteAnimationComponent? gateComponent;

  List<RemappableButton> hudButtons = [];
  late HudButtonComponent pauseButton;

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
    pauseEngine();
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
      if (!startInRemapMode)
        FlameAudio.bgm.play('musica_padrao.mp3', volume: AudioManager.bgm);
    } catch (e) {}

    try {
      world.add(
        SpriteComponent(
          sprite: await loadSprite('ceu_limpo.png'),
          size: Vector2(800, 360),
          priority: 0,
        ),
      );
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
          priority: 0,
        ),
      );
      world.add(
        SpriteComponent(
          sprite: await loadSprite('chão_default_v2.png'),
          size: Vector2(800, 360),
          priority: 0,
        ),
      );

      world.add(
        PositionComponent(position: Vector2(0, 0), size: Vector2(5, 360))
          ..add(RectangleHitbox()),
      );
      world.add(
        PositionComponent(position: Vector2(795, 0), size: Vector2(5, 360))
          ..add(RectangleHitbox()),
      );

      // ANIMAÇÃO DO PORTÃO
      try {
        final gateAnim = await loadSpriteAnimation(
          'animacao_portao.png',
          SpriteAnimationData.sequenced(
            amount: 7,
            stepTime: 0.05,
            textureSize: Vector2(267, 120),
            loop: false,
          ),
        );
        gateComponent = SpriteAnimationComponent(
          animation: gateAnim,
          size: Vector2(800, 360),
          priority: 1,
        );

        // CORREÇÃO: Usamos o atributo "playing" do componente para pausar a animação
        gateComponent!.playing = false;

        world.add(gateComponent!);
      } catch (e) {
        debugPrint(
          'Aviso: animacao_portao.png não carregada ou tamanho incorreto. Pulando animação do portão.',
        );
      }
    } catch (e) {}

    joystick = JoystickComponent(
      knob: CircleComponent(
        radius: 20,
        paint: Paint()..color = Colors.white.withOpacity(0.0),
      ),
      background: CircleComponent(
        radius: 50,
        paint: Paint()..color = Colors.white.withOpacity(0.0),
      ),
      position: HudConfig.joystickPos,
    );
    camera.viewport.add(joystick);
    joystickHandle = JoystickDragHandle(joystick);

    player = Player(joystick: joystick)..priority = 10;
    boss = Boss(player: player)..priority = 5;

    player.position = Vector2(108, 312);
    boss.position = Vector2(592, -200);
    player.boss = boss;

    world.add(player);
    world.add(boss);

    camera.viewport.add(BossHealthBar(boss));
    camera.viewport.add(PlayerHealthBar(player));

    camera.viewport.add(
      HudButtonComponent(
        button: RectangleComponent(
          size: Vector2(80, 80),
          paint: Paint()..color = Colors.transparent,
        ),
        position: Vector2(700, 32),
        onPressed: () {
          if (!isEditingHUD &&
              cheatUnlocked &&
              !overlays.isActive('CheatMenu')) {
            pauseEngine();
            overlays.add('CheatMenu');
          }
        },
      ),
    );

    final pFundo = CircleComponent(
      radius: 20,
      paint: Paint()..color = Colors.black.withOpacity(0),
    );
    try {
      final spr = await loadSprite('icone_pause.png');
      final pIcone = SpriteComponent(
        sprite: spr,
        size: Vector2.all(24),
        anchor: Anchor.center,
        position: Vector2(20, 20),
      );
      pIcone.paint.color = Colors.white.withOpacity(0);
      pFundo.add(pIcone);
    } catch (e) {}
    pauseButton = HudButtonComponent(
      button: pFundo,
      margin: const EdgeInsets.only(top: 20, right: 20),
      onPressed: () {
        if (isEditingHUD) return;
        pauseEngine();
        FlameAudio.bgm.pause();
        overlays.add('PauseMenu');
      },
    );
    camera.viewport.add(pauseButton);

    hudButtons.add(
      await _criarBotaoRemapeavel(
        imagem: 'icone_ataque_basico-1.png',
        corFundo: Colors.red,
        raio: 25,
        posicao: HudConfig.attackBtnPos,
        onPressed: () => player.basicAttack(),
        debugColor: Colors.red,
      ),
    );
    hudButtons.add(
      await _criarBotaoRemapeavel(
        imagem: 'icone_pulo-1.png',
        corFundo: Colors.green,
        raio: 25,
        posicao: HudConfig.jumpBtnPos,
        onPressed: () => player.jump(),
        debugColor: Colors.green,
      ),
    );
    hudButtons.add(
      await _criarBotaoRemapeavel(
        imagem: 'icon_dash-1.png',
        corFundo: Colors.yellow,
        raio: 25,
        posicao: HudConfig.dashBtnPos,
        onPressed: () => player.dash(),
        debugColor: Colors.yellow,
      ),
    );
    hudButtons.add(
      await _criarBotaoRemapeavel(
        imagem: 'Escudo_icone-1.png',
        corFundo: Colors.blue,
        raio: 25,
        posicao: HudConfig.parryBtnPos,
        onPressed: () => player.tentarParry(),
        debugColor: Colors.blue,
      ),
    );

    final sFundo = CircleComponent(
      radius: 20,
      paint: Paint()..color = Colors.purple.withOpacity(0),
    );
    hudButtons.add(
      RemappableButton(
        fundoBotao: sFundo,
        iconeSprite: null,
        corOriginal: Colors.purple,
        content: sFundo,
        position: HudConfig.specialBtnPos,
        size: Vector2.all(40),
        onPressed: () => player.startSpecial(),
        onReleased: () => player.releaseSpecial(),
        debugColor: Colors.purple,
      ),
    );

    for (var btn in hudButtons) {
      camera.viewport.add(btn);
    }

    if (startInRemapMode) {
      isEditingHUD = true;
      introState = IntroState.finished;
      hudOpacity = 1.0;
      _atualizarOpacidadeHUD();
      overlays.add('RemapHUD');
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (introState == IntroState.initialShake) {
      introTimer += dt;
      // Tremor apenas horizontal, curto e bem rápido!
      double shakeX = (Random().nextDouble() - 0.5) * 8.0;
      camera.viewfinder.position = Vector2(shakeX, 0);

      if (introTimer >= 3.0) {
        camera.viewfinder.position = Vector2.zero(); // Estabiliza a câmera
        introTimer = 0.0;
        introState = IntroState.playingGate;
        hasVibratedGate = false;

        // CORREÇÃO: Usamos o atributo "playing" do componente para dar o play na animação
        gateComponent?.playing = true;
      }
    } else if (introState == IntroState.playingGate) {
      if (gateComponent != null) {
        if (gateComponent!.animationTicker?.currentIndex == 5 &&
            !hasVibratedGate) {
          HapticFeedback.vibrate(); // Vibração mais forte no penúltimo frame
          hasVibratedGate = true;
        }
        if (gateComponent!.animationTicker?.done() == true) {
          introTimer = 0.0;
          introState = IntroState.waitingForBoss;
        }
      } else {
        introState = IntroState.waitingForBoss;
      }
    } else if (introState == IntroState.waitingForBoss) {
      introTimer += dt;
      if (introTimer >= 1.3) {
        boss.startIntroFall();
        introState = IntroState.bossFalling;
      }
    } else if (introState == IntroState.fadingHud) {
      hudOpacity += dt * 2.0;
      if (hudOpacity >= 1.0) {
        hudOpacity = 1.0;
        introState = IntroState.finished;
      }
      _atualizarOpacidadeHUD();
    }
  }

  void _atualizarOpacidadeHUD() {
    (joystick.knob as CircleComponent).paint.color = Colors.white.withOpacity(
      0.5 * hudOpacity,
    );
    (joystick.background as CircleComponent).paint.color = Colors.white
        .withOpacity(0.2 * hudOpacity);

    if (pauseButton.button is CircleComponent) {
      (pauseButton.button as CircleComponent).paint.color = Colors.black
          .withOpacity(0.7 * hudOpacity);
      if (pauseButton.button!.children.isNotEmpty) {
        final child = pauseButton.button!.children.first;
        if (child is SpriteComponent)
          child.paint.color = Colors.white.withOpacity(hudOpacity);
      }
    }

    for (var btn in hudButtons) {
      btn.atualizarOpacidade(hudOpacity);
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
    player.velocity = Vector2.zero();
    player.isInvincible = false;
    player.isParrying = false;
    player.isJumping = false;
    player.isDashing = false;
    player.dashCooldownTimer = 0.0;
    player.isParryFailAnim = false;
    player.isHoldingSpecial = false;
    player.specialHoldTimer = 0.0;
    player.speed = 250;

    introState = IntroState.finished;
    hudOpacity = 1.0;
    _atualizarOpacidadeHUD();
    player.position = Vector2(108, player.groundLevelY);
    boss.resetBoss();
    boss.position = Vector2(592, 278);

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

  Future<RemappableButton> _criarBotaoRemapeavel({
    required String imagem,
    required Color corFundo,
    required double raio,
    required Vector2 posicao,
    required VoidCallback onPressed,
    VoidCallback? onReleased,
    required Color debugColor,
  }) async {
    final fundo = CircleComponent(
      radius: raio,
      paint: Paint()..color = corFundo.withOpacity(0),
    );
    SpriteComponent? icone;

    try {
      final spr = await loadSprite(imagem);
      icone = SpriteComponent(
        sprite: spr,
        size: Vector2.all(raio * 1.2),
        anchor: Anchor.center,
        position: Vector2(raio, raio),
      );
      icone.paint.color = Colors.white.withOpacity(0);
      fundo.add(icone);
    } catch (e) {
      debugPrint('Aviso: $imagem não encontrada no pubspec.yaml');
    }

    return RemappableButton(
      fundoBotao: fundo,
      iconeSprite: icone,
      corOriginal: corFundo,
      content: fundo,
      position: posicao,
      size: Vector2.all(raio * 2),
      onPressed: onPressed,
      onReleased: onReleased,
      debugColor: debugColor,
    );
  }
}
