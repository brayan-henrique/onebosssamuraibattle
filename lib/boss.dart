import 'package:flame/components.dart';
import 'package:flame/collisions.dart';
import 'package:flame/effects.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flame/sprite.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/animation.dart';
import 'package:flame/text.dart';
import 'dart:math';
import 'dart:ui';
import 'player.dart';
import 'my_game.dart';

enum BossPhase { phase1, phase2, phase3 }

enum BossState {
  chasing,
  windup,
  swinging,
  vulnerable,
  parryStance,
  transitioning,
  jumpingAway,
  jumpingUp,
  hovering,
  falling,
  kunaiAttack,

  jumpingToCenter,
  dying,
  exploding,
  dead,
}

enum SpecialAttack { aerialDrop, kunaiRain }

// ==========================================
// TELA DE VITÓRIA
// ==========================================

class VictoryLetter extends TextComponent with HasGameRef<MyPixelGame> {
  final double targetY;
  final double delay;

  VictoryLetter({
    required String letter,
    required Vector2 startPos,
    required this.targetY,
    required this.delay,
  }) : super(
         text: letter,
         position: startPos,
         anchor: Anchor.center,
         priority: 1000,
       ); // PRIORIDADE MÁXIMA

  @override
  Future<void> onLoad() async {
    textRenderer = TextPaint(
      style: const TextStyle(
        color: Colors.yellow,
        fontSize: 56,
        fontWeight: FontWeight.w900,
        fontFamily: 'monospace',
        shadows: [
          Shadow(color: Colors.black, blurRadius: 4, offset: Offset(3, 3)),
        ],
      ),
    );

    add(
      MoveEffect.to(
        Vector2(position.x, targetY),
        EffectController(
          duration: 1.2,
          startDelay: delay,
          curve: Curves.easeOutCubic,
        ),
      ),
    );
  }
}

// BOTÃO TOTALMENTE FÍSICO E ATACÁVEL
class VictoryButton extends PositionComponent with HasGameRef<MyPixelGame> {
  final String label;
  final double targetY;
  final double delay;
  final VoidCallback onHit;
  bool jaFoiAtingido = false;

  VictoryButton({
    required this.label,
    required Vector2 startPos,
    required this.targetY,
    required this.delay,
    required this.onHit,
  }) : super(
         position: startPos,
         size: Vector2(220, 55),
         anchor: Anchor.center,
         priority: 1000,
       ); // PRIORIDADE MÁXIMA

  @override
  Future<void> onLoad() async {
    final textComp = TextComponent(
      text: label,
      anchor: Anchor.center,
      position: size / 2,
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    add(textComp);

    add(
      MoveEffect.to(
        Vector2(position.x, targetY),
        EffectController(
          duration: 1.2,
          startDelay: delay,
          curve: Curves.easeOutCubic,
        ),
      ),
    );
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final rect = size.toRect();

    // Feedback visual quando a espada bater
    Color borderColor = jaFoiAtingido ? Colors.green : Colors.yellow;

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(8)),
      Paint()..color = Colors.black87,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(8)),
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  void receiveDamage(double damage) {
    if (jaFoiAtingido) return;
    jaFoiAtingido = true;

    HapticFeedback.lightImpact();
    add(
      ScaleEffect.to(
        Vector2.all(0.9),
        EffectController(duration: 0.1, alternate: true),
      ),
    );

    onHit();
  }
}

// ==========================================
// CLASSES DA LUTA
// ==========================================

class BossExplosion extends SpriteAnimationComponent
    with HasGameRef<MyPixelGame> {
  final String spriteName;
  final int frameAmount;

  BossExplosion({
    required this.spriteName,
    required this.frameAmount,
    required Vector2 position,
    required Vector2 size,
    int priority = 0,
  }) : super(
         position: position,
         size: size,
         anchor: Anchor.center,
         removeOnFinish: true,
         priority: priority,
       );

  @override
  Future<void> onLoad() async {
    try {
      animation = await gameRef.loadSpriteAnimation(
        spriteName,
        SpriteAnimationData.sequenced(
          amount: frameAmount,
          stepTime: 0.1,
          textureSize: Vector2.all(96),
          loop: false,
        ),
      );
    } catch (e) {
      debugPrint("Erro ao carregar explosão: $e");
    }
  }
}

class Kunai extends PositionComponent with HasGameRef<MyPixelGame> {
  final Player player;
  final double direction;
  final double speed = 423.0;
  bool hasHit = false;

  bool isInvoking = true;

  SpriteAnimationTicker? invocationTicker;
  Sprite? kunaiSprite;

  Kunai({
    required this.player,
    required this.direction,
    required Vector2 position,
  }) : super(size: Vector2(30, 34), position: position, anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    add(RectangleHitbox()..paint.color = Colors.transparent);

    bool bossNaEsquerda = direction == 1.0;

    try {
      if (bossNaEsquerda) {
        final anim = await gameRef.loadSpriteAnimation(
          'ivocacao_esquerda.png',
          SpriteAnimationData.sequenced(
            amount: 6,
            stepTime: 0.1,
            textureSize: Vector2(30, 34),
            loop: false,
          ),
        );
        invocationTicker = anim.createTicker();
        kunaiSprite = await gameRef.loadSprite('ataque_kunai_esquerda.png');
      } else {
        final anim = await gameRef.loadSpriteAnimation(
          'ivocacao_direita.png',
          SpriteAnimationData.sequenced(
            amount: 6,
            stepTime: 0.1,
            textureSize: Vector2(30, 34),
            loop: false,
          ),
        );
        invocationTicker = anim.createTicker();
        kunaiSprite = await gameRef.loadSprite('ataque_kunai_direita.png');
      }
    } catch (e) {
      debugPrint("Erro ao carregar sprites da kunai: $e");
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (gameRef.isEditingHUD) return;

    if (isInvoking) {
      invocationTicker?.update(dt);
      if (invocationTicker?.done() == true) isInvoking = false;
      return;
    }

    position.x += speed * direction * dt;

    if (position.x < -100 || position.x > 900) {
      removeFromParent();
      return;
    }

    if (!hasHit && position.distanceTo(player.position) < 30) {
      player.receiveAttack(1.0);
      hasHit = true;
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    if (isInvoking) {
      if (invocationTicker != null)
        invocationTicker!.getSprite().render(canvas, size: size);
    } else {
      if (kunaiSprite != null)
        kunaiSprite!.render(canvas, size: size);
      else
        canvas.drawRect(
          size.toRect(),
          Paint()..color = Colors.deepPurpleAccent.withOpacity(0.3),
        );
    }
  }
}

class BossArm extends SpriteComponent with HasGameRef<MyPixelGame> {
  BossArm() : super(size: Vector2(110, 15), anchor: Anchor.centerLeft);

  @override
  Future<void> onLoad() async {
    try {
      sprite = await gameRef.loadSprite('espadada_boss.png');
    } catch (e) {}
  }

  @override
  void render(Canvas canvas) {
    if (sprite == null) canvas.drawRect(size.toRect(), paint);
    super.render(canvas);
  }
}

class Boss extends PositionComponent with HasGameRef<MyPixelGame> {
  final Player player;

  double maxHealth = 500.0;
  double currentHealth = 500.0;

  BossPhase currentPhase = BossPhase.phase1;
  BossState currentState = BossState.chasing;
  double stateTimer = 0.0;
  late double attackTargetAngle;
  late double attackDirection;
  int saltosRestantes = 0;
  int kunaisAtiradas = 0;
  final double groundLevelY = 278.0;
  double specialCooldown = 1.5;
  SpecialAttack? queuedSpecial;
  List<SpecialAttack> attackPool = [];

  late BossArm armRight;
  late BossArm armLeft;

  late SpriteComponent chapeuComponent;
  late SpriteComponent tomoComponent;
  late RectangleHitbox bossHitbox;

  bool jaTocouSomImpacto = false;
  bool jaVibrouNoChao = false;
  bool victoryScreenSpawned = false;

  double hurtTimer = 0.0;
  double jumpStartX = 0.0;

  Sprite? spriteIdle;
  Sprite? spriteAtacando;
  SpriteAnimationTicker? parryTicker;
  SpriteAnimationTicker? machucadoTicker;
  SpriteAnimationTicker? morrendoTicker;

  Boss({required this.player})
    : super(size: Vector2.all(96), anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    try {
      spriteIdle = await gameRef.loadSprite('boss_reserva.png');
      spriteAtacando = await gameRef.loadSprite('boss_reserva_atacando.png');

      final parryAnim = await gameRef.loadSpriteAnimation(
        'boss_reserva_parry.png',
        SpriteAnimationData.variable(
          amount: 6,
          textureSize: Vector2.all(96),
          loop: false,
          stepTimes: [0.05, 0.05, 0.05, 0.05, 0.05, 1.25],
        ),
      );
      parryTicker = parryAnim.createTicker();

      final machucadoAnim = await gameRef.loadSpriteAnimation(
        'boss_reserva_machucado.png',
        SpriteAnimationData.sequenced(
          amount: 2,
          stepTime: 0.25,
          textureSize: Vector2.all(96),
        ),
      );
      machucadoTicker = machucadoAnim.createTicker();

      final morrendoAnim = await gameRef.loadSpriteAnimation(
        'boss_morrendo.png',
        SpriteAnimationData.sequenced(
          amount: 6,
          stepTime: 1.0,
          textureSize: Vector2.all(100),
          loop: false,
        ),
      );
      morrendoTicker = morrendoAnim.createTicker();
    } catch (e) {
      debugPrint("Erro ao carregar artes do boss: $e");
    }

    bossHitbox = RectangleHitbox(
      size: Vector2(64, 96),
      position: Vector2(16, 0),
    )..paint.color = Colors.transparent;
    add(bossHitbox);

    armRight = BossArm();
    armRight.position = Vector2(size.x / 2, size.y / 2 - 10);
    add(armRight);
    armLeft = BossArm();
    armLeft.position = Vector2(size.x / 2, size.y / 2 + 10);
    add(armLeft);

    chapeuComponent = SpriteComponent(
      size: Vector2(96, 96),
      anchor: Anchor.bottomCenter,
      position: Vector2(size.x / 2, 20),
    );
    chapeuComponent.paint.color = chapeuComponent.paint.color.withOpacity(0.0);
    add(chapeuComponent);

    tomoComponent = SpriteComponent(
      size: Vector2(72, 72),
      anchor: Anchor.center,
      position: Vector2((size.x / 2) + 10, (size.y / 2) + 10),
    );
    tomoComponent.paint.color = tomoComponent.paint.color.withOpacity(0.0);
    add(tomoComponent);

    try {
      chapeuComponent.sprite = await gameRef.loadSprite('chapeu_mago.png');
      tomoComponent.sprite = await gameRef.loadSprite('tomo.png');
    } catch (e) {}
  }

  @override
  void render(Canvas canvas) {
    if (currentState == BossState.dead) return;

    // CORREÇÃO: Pula TOTALMENTE o corpo base, braços e chapéu e foca só na morte.
    if (currentPhase == BossPhase.phase3 &&
        (currentState == BossState.dying ||
            currentState == BossState.exploding)) {
      if (morrendoTicker != null) {
        morrendoTicker!.getSprite().render(canvas, size: size);
      }
      return;
    }

    super.render(canvas);

    if (hurtTimer > 0) {
      if (machucadoTicker != null) {
        machucadoTicker!.getSprite().render(canvas, size: size);
        return;
      }
    }

    if (currentState == BossState.windup ||
        currentState == BossState.swinging) {
      if (spriteAtacando != null)
        spriteAtacando!.render(canvas, size: size);
      else
        canvas.drawRect(size.toRect(), Paint()..color = Colors.red);
    } else if (currentState == BossState.parryStance) {
      if (parryTicker != null)
        parryTicker!.getSprite().render(canvas, size: size);
      else
        canvas.drawRect(size.toRect(), Paint()..color = Colors.blue);
    } else if (currentState == BossState.vulnerable) {
      if (spriteIdle != null)
        spriteIdle!.render(canvas, size: size);
      else
        canvas.drawRect(size.toRect(), Paint()..color = Colors.green);
    } else if (currentState == BossState.hovering) {
      // Invisível
    } else {
      if (spriteIdle != null)
        spriteIdle!.render(canvas, size: size);
      else
        canvas.drawRect(size.toRect(), Paint()..color = Colors.grey);
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (gameRef.isEditingHUD) return;

    parryTicker?.update(dt);
    machucadoTicker?.update(dt);

    if (hurtTimer > 0) hurtTimer -= dt;

    if (currentPhase == BossPhase.phase1)
      _updatePhase1(dt);
    else if (currentPhase == BossPhase.phase2)
      _updatePhase2(dt);
    else if (currentPhase == BossPhase.phase3)
      _updatePhase3(dt);
  }

  double _normalizeAngle(double angle) {
    angle = angle % (2 * pi);
    if (angle > pi) angle -= 2 * pi;
    if (angle <= -pi) angle += 2 * pi;
    return angle;
  }

  void _updatePhase1(double dt) {
    stateTimer += dt;
    final double baseSpeed = 130.0;
    double percentHealthLost = (1.0 - (currentHealth / maxHealth)) * 100;
    double speedMultiplier = 1.0 + ((percentHealthLost / 10).floor() * 0.02);
    double currentSpeed = baseSpeed * speedMultiplier;
    final double combatRotationSpeed = 12.0;

    switch (currentState) {
      case BossState.chasing:
        double targetAngle = atan2(
          player.position.y - position.y,
          player.position.x - position.x,
        );
        double angleDiff = _normalizeAngle(targetAngle - armRight.angle);
        armRight.angle += angleDiff * combatRotationSpeed * dt;
        armLeft.angle = armRight.angle;
        if (player.position.x > position.x)
          position.x += currentSpeed * dt;
        else
          position.x -= currentSpeed * dt;
        if (position.distanceTo(player.position) <= 120.0) {
          currentState = BossState.windup;
          stateTimer = 0.0;
          attackTargetAngle = targetAngle;
          attackDirection = (player.position.x > position.x) ? 1.0 : -1.0;
        }
        break;
      case BossState.windup:
        double windupTarget = attackTargetAngle - (1.5 * attackDirection);
        double diff = _normalizeAngle(windupTarget - armRight.angle);
        armRight.angle += diff * 15.0 * dt;
        armLeft.angle = armRight.angle;
        if (stateTimer >= 0.4) {
          currentState = BossState.swinging;
          stateTimer = 0.0;
        }
        break;
      case BossState.swinging:
        double windupTarget = attackTargetAngle - (1.5 * attackDirection);
        double swingTarget = attackTargetAngle + (1.8 * attackDirection);
        double progress = stateTimer / 0.2;
        if (progress > 1.0) progress = 1.0;
        armRight.angle = lerpDouble(windupTarget, swingTarget, progress)!;
        armLeft.angle = armRight.angle;
        bool acertou = false;
        for (double raio = 20.0; raio <= 110.0; raio += 10.0) {
          double pointX = position.x + cos(armRight.angle) * raio;
          double pointY = position.y + sin(armRight.angle) * raio;
          if (pointX >= player.position.x - 15 &&
              pointX <= player.position.x + 15 &&
              pointY >= player.position.y - 17 &&
              pointY <= player.position.y + 17) {
            acertou = true;
            break;
          }
        }
        if (acertou) {
          player.receiveAttack(1.5);
          currentState = BossState.vulnerable;
          stateTimer = 0.0;
        } else if (stateTimer >= 0.2) {
          currentState = BossState.vulnerable;
          stateTimer = 0.0;
        }
        break;
      case BossState.vulnerable:
        armRight.angle = lerpDouble(armRight.angle, pi / 2, 5.0 * dt)!;
        armLeft.angle = armRight.angle;
        if (stateTimer >= 1.6) {
          if (Random().nextDouble() < 0.4) {
            currentState = BossState.parryStance;
            parryTicker?.reset();
          } else {
            currentState = BossState.chasing;
          }
          stateTimer = 0.0;
        }
        break;
      case BossState.parryStance:
        double parryAngle = (attackDirection == 1.0)
            ? (pi / 4)
            : ((3 * pi) / 4);
        armRight.angle = lerpDouble(armRight.angle, parryAngle, 10.0 * dt)!;
        armLeft.angle = armRight.angle + 0.5;
        if (stateTimer >= 2.5) {
          currentState = BossState.chasing;
          stateTimer = 0.0;
        }
        break;
      default:
        break;
    }
  }

  void _updatePhase2(double dt) {
    stateTimer += dt;
    double percentHealthLost = (1.0 - (currentHealth / maxHealth)) * 100;
    double speedMultiplier = 1.0 + ((percentHealthLost / 10).floor() * 0.04);

    if (currentState == BossState.windup || currentState == BossState.swinging)
      specialCooldown -= dt;

    if (specialCooldown <= 0 &&
        (currentState == BossState.chasing ||
            currentState == BossState.vulnerable)) {
      if (attackPool.isEmpty) {
        attackPool = [SpecialAttack.aerialDrop, SpecialAttack.kunaiRain];
        attackPool.shuffle();
      }
      queuedSpecial = attackPool.removeLast();
      specialCooldown = Random().nextDouble() * 2.0 + 2.0;
      currentState = BossState.jumpingAway;
      stateTimer = 0.0;
      return;
    }

    switch (currentState) {
      case BossState.transitioning:
        if (stateTimer >= 2.0) {
          currentState = BossState.chasing;
          stateTimer = 0.0;
        }
        break;
      case BossState.jumpingAway:
        double targetX = (player.position.x > 400) ? 80 : 720;
        double moveSpeed = 500 * speedMultiplier;
        if ((position.x - targetX).abs() > 10)
          position.x += (targetX > position.x ? 1 : -1) * moveSpeed * dt;
        else {
          if (queuedSpecial == SpecialAttack.aerialDrop) {
            saltosRestantes = Random().nextInt(4) + 3;
            currentState = BossState.jumpingUp;
          } else if (queuedSpecial == SpecialAttack.kunaiRain) {
            currentState = BossState.kunaiAttack;
            kunaisAtiradas = 0;
            armRight.add(
              OpacityEffect.fadeOut(EffectController(duration: 0.5)),
            );
            armLeft.add(OpacityEffect.fadeOut(EffectController(duration: 0.5)));
            chapeuComponent.add(
              OpacityEffect.fadeIn(EffectController(duration: 0.5)),
            );
            tomoComponent.add(
              OpacityEffect.fadeIn(EffectController(duration: 0.5)),
            );
          }
          queuedSpecial = null;
          stateTimer = 0.0;
        }
        break;
      case BossState.kunaiAttack:
        armRight.angle = pi / 2;
        armLeft.angle = pi / 2;
        double tempoDeTiro = 0.35 / speedMultiplier;
        if (tempoDeTiro < 0.10) tempoDeTiro = 0.10;
        if (stateTimer >= tempoDeTiro) {
          if (kunaisAtiradas < 30) {
            _atirarKunai();
            kunaisAtiradas++;
            stateTimer = 0.0;
          } else if (stateTimer >= 2.5) {
            currentState = BossState.chasing;
            stateTimer = 0.0;
            armRight.add(OpacityEffect.fadeIn(EffectController(duration: 0.5)));
            armLeft.add(OpacityEffect.fadeIn(EffectController(duration: 0.5)));
            chapeuComponent.add(
              OpacityEffect.fadeOut(EffectController(duration: 0.5)),
            );
            tomoComponent.add(
              OpacityEffect.fadeOut(EffectController(duration: 0.5)),
            );
          }
        }
        break;
      case BossState.jumpingUp:
        jaTocouSomImpacto = false;
        jaVibrouNoChao = false;
        position.y -= (1500 * speedMultiplier) * dt;
        if (position.y < -300) {
          currentState = BossState.hovering;
          stateTimer = 0.0;
        }
        break;
      case BossState.hovering:
        position.x = player.position.x;
        if (stateTimer >= (0.8 / speedMultiplier)) {
          currentState = BossState.falling;
          stateTimer = 0.0;
        }
        break;
      case BossState.falling:
        position.y += (2500 * speedMultiplier) * dt;
        if (position.y >= (groundLevelY - 25) && !jaTocouSomImpacto) {
          try {
            FlameAudio.play('impacto_boss.mp3', volume: 0.6);
          } catch (e) {}
          jaTocouSomImpacto = true;
        }
        if (position.y >= groundLevelY) {
          position.y = groundLevelY;
          if (!jaVibrouNoChao) {
            HapticFeedback.vibrate();
            gameRef.camera.viewfinder.add(
              MoveEffect.by(
                Vector2(0, 15),
                EffectController(
                  duration: 0.1,
                  reverseDuration: 0.1,
                  repeatCount: 2,
                ),
              ),
            );
            jaVibrouNoChao = true;
          }
          if (position.distanceTo(player.position) < 100)
            player.receiveAttack(2.0);
          saltosRestantes--;
          if (saltosRestantes > 0)
            currentState = BossState.jumpingUp;
          else
            currentState = BossState.chasing;
          stateTimer = 0.0;
        }
        break;
      default:
        _updatePhase1(dt);
        break;
    }
  }

  void _updatePhase3(double dt) {
    stateTimer += dt;

    switch (currentState) {
      case BossState.jumpingToCenter:
        double jumpDuration = 0.6;
        double progress = stateTimer / jumpDuration;

        if (progress >= 1.0) {
          position.x = 400.0;
          position.y = groundLevelY;
          currentState = BossState.dying;
          stateTimer = 0.0;

          HapticFeedback.vibrate();
          gameRef.camera.viewfinder.add(
            MoveEffect.by(
              Vector2(0, 15),
              EffectController(
                duration: 0.1,
                reverseDuration: 0.1,
                repeatCount: 4,
              ),
            ),
          );

          add(
            MoveEffect.by(
              Vector2(8, 0),
              EffectController(
                duration: 0.05,
                reverseDuration: 0.05,
                repeatCount: 60,
              ),
            ),
          );
          morrendoTicker?.reset();
        } else {
          position.x = lerpDouble(jumpStartX, 400.0, progress)!;
          position.y = groundLevelY - (sin(progress * pi) * 100);
        }
        break;

      case BossState.dying:
        morrendoTicker?.update(dt);
        if (stateTimer >= 6.0) currentState = BossState.exploding;
        break;

      case BossState.exploding:
        HapticFeedback.vibrate();
        gameRef.camera.viewfinder.add(
          MoveEffect.by(
            Vector2(25, 25),
            EffectController(
              duration: 0.08,
              reverseDuration: 0.08,
              repeatCount: 10,
            ),
          ),
        );
        gameRef.world.add(
          BossExplosion(
            spriteName: 'explosão_boss.png',
            frameAmount: 6,
            position: position.clone(),
            size: Vector2.all(150),
            priority: 15,
          ),
        );
        gameRef.world.add(
          BossExplosion(
            spriteName: 'corpo_explodindo.png',
            frameAmount: 6,
            position: position.clone(),
            size: Vector2.all(120),
            priority: 25,
          ),
        );

        currentState = BossState.dead;
        debugPrint("BOSS FINALMENTE DERROTADO E EXPLODIU!");
        break;

      case BossState.dead:
        if (!victoryScreenSpawned) {
          victoryScreenSpawned = true;
          _spawnVictoryScreen();
        }
        break;

      default:
        break;
    }
  }

  void _spawnVictoryScreen() {
    String text = "YOU WIN!";
    double startX = 400 - ((text.length - 1) * 20);

    for (int i = 0; i < text.length; i++) {
      gameRef.world.add(
        VictoryLetter(
          letter: text[i],
          startPos: Vector2(startX + (i * 40), -100),
          targetY: groundLevelY - 200,
          delay: i * 0.15,
        ),
      );
    }

    double tempoAteTerminarLetras = (text.length * 0.15) + 0.5;

    // BOTÃO ATACÁVEL DE RESTART
    gameRef.world.add(
      VictoryButton(
        label: "RESTART",
        startPos: Vector2(400, -100),
        targetY: groundLevelY - 80,
        delay: tempoAteTerminarLetras,
        onHit: () {
          debugPrint("Botão RESTART atacado!");
          // gameRef.resetGame(); // Substitua pela sua função de reinício
        },
      ),
    );

    // BOTÃO ATACÁVEL DE MENU
    gameRef.world.add(
      VictoryButton(
        label: "MENU",
        startPos: Vector2(400, -100),
        targetY: groundLevelY - 10,
        delay: tempoAteTerminarLetras + 0.3,
        onHit: () {
          debugPrint("Botão MENU atacado!");
          gameRef.overlays.add('Menu'); // Abre a sua overlay de Menu!
        },
      ),
    );
  }

  void _atirarKunai() {
    double kunaiY = [
      groundLevelY,
      groundLevelY - 50,
      groundLevelY - 100,
      groundLevelY - 150,
    ][Random().nextInt(4)];
    double dir = (position.x > 400) ? -1.0 : 1.0;
    Kunai novaKunai = Kunai(
      player: player,
      direction: dir,
      position: Vector2(position.x + (dir * 40), kunaiY),
    );
    novaKunai.priority = 20;
    gameRef.world.add(novaKunai);
  }

  void receiveDamage(double damage) {
    if (currentPhase == BossPhase.phase3) return;
    if (currentState == BossState.transitioning ||
        currentState == BossState.jumpingUp ||
        currentState == BossState.hovering ||
        currentState == BossState.falling)
      return;

    hurtTimer = 0.4;
    machucadoTicker?.reset();

    if (currentPhase == BossPhase.phase1) {
      if (currentState == BossState.parryStance && Random().nextInt(100) < 65) {
        player.applyParalysis(1.875);
        currentState = BossState.windup;
        stateTimer = 0.0;
        attackTargetAngle = atan2(
          player.position.y - position.y,
          player.position.x - position.x,
        );
        attackDirection = (player.position.x > position.x) ? 1.0 : -1.0;
        return;
      }
      currentHealth -= (damage / 1.5);
      if (currentHealth <= 0) {
        currentPhase = BossPhase.phase2;
        currentHealth = 1200.0;
        maxHealth = 1200.0;
        currentState = BossState.transitioning;
        stateTimer = 0.0;
        attackPool.clear();
        specialCooldown = 1.5;
      }
    } else if (currentPhase == BossPhase.phase2) {
      currentHealth -= damage;
      if (currentHealth <= 0) {
        currentHealth = 0;
        currentPhase = BossPhase.phase3;
        currentState = BossState.jumpingToCenter;
        jumpStartX = position.x;
        stateTimer = 0.0;

        // CORREÇÃO: Remove a hitbox para não ser mais possível combar no corpo do boss
        if (bossHitbox.isMounted) {
          bossHitbox.removeFromParent();
        }

        armRight.add(OpacityEffect.fadeOut(EffectController(duration: 0.5)));
        armLeft.add(OpacityEffect.fadeOut(EffectController(duration: 0.5)));
        chapeuComponent.add(
          OpacityEffect.fadeOut(EffectController(duration: 0.5)),
        );
        tomoComponent.add(
          OpacityEffect.fadeOut(EffectController(duration: 0.5)),
        );
      }
    }
  }
}
