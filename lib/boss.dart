import 'package:flame/components.dart';
import 'package:flame/collisions.dart';
import 'package:flame/effects.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flame/sprite.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
}

enum SpecialAttack { aerialDrop, kunaiRain }

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
      if (invocationTicker?.done() == true) {
        isInvoking = false;
      }
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
      if (invocationTicker != null) {
        invocationTicker!.getSprite().render(canvas, size: size);
      }
    } else {
      if (kunaiSprite != null) {
        kunaiSprite!.render(canvas, size: size);
      } else {
        canvas.drawRect(
          size.toRect(),
          Paint()..color = Colors.deepPurpleAccent.withOpacity(0.3),
        );
      }
    }
  }
}

class BossArm extends SpriteComponent with HasGameRef<MyPixelGame> {
  BossArm() : super(size: Vector2(110, 15), anchor: Anchor.centerLeft);

  @override
  Future<void> onLoad() async {
    try {
      sprite = await gameRef.loadSprite('espadada_boss.png');
    } catch (e) {
      debugPrint("Erro ao carregar espadada_boss.png: $e");
    }
  }

  @override
  void render(Canvas canvas) {
    if (sprite == null) {
      canvas.drawRect(size.toRect(), paint);
    }
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

  bool jaTocouSomImpacto = false;
  bool jaVibrouNoChao = false;

  double hurtTimer = 0.0;

  Sprite? spriteIdle;
  Sprite? spriteAtacando;
  SpriteAnimationTicker? parryTicker;
  SpriteAnimationTicker? machucadoTicker;

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
    } catch (e) {
      debugPrint("Erro ao carregar artes do boss: $e");
    }

    add(
      RectangleHitbox(size: Vector2(64, 96), position: Vector2(16, 0))
        ..paint.color = Colors.transparent,
    );

    armRight = BossArm();
    armRight.position = Vector2(size.x / 2, size.y / 2 - 10);
    add(armRight);
    armLeft = BossArm();
    armLeft.position = Vector2(size.x / 2, size.y / 2 + 10);
    add(armLeft);

    // CHAPÉU: Tamanho 3x (96x96)
    chapeuComponent = SpriteComponent(
      size: Vector2(96, 96),
      anchor: Anchor.bottomCenter,
      position: Vector2(
        size.x / 2,
        20,
      ), // Ajustado levemente para encaixar com o novo tamanho
    );
    chapeuComponent.paint.color = chapeuComponent.paint.color.withOpacity(0.0);
    add(chapeuComponent);

    // TOMO: Tamanho 2x (72x72), +10 X (frente), +10 Y (baixo)
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
    } catch (e) {
      debugPrint("Erro ao carregar chapeu ou tomo: $e");
    }
  }

  @override
  void render(Canvas canvas) {
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

    if (hurtTimer > 0) {
      hurtTimer -= dt;
    }

    if (currentHealth <= 0 && currentPhase != BossPhase.phase1) return;
    if (currentPhase == BossPhase.phase1)
      _updatePhase1(dt);
    else if (currentPhase == BossPhase.phase2)
      _updatePhase2(dt);
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

    if (currentState == BossState.windup ||
        currentState == BossState.swinging) {
      specialCooldown -= dt;
    }

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

  void _atirarKunai() {
    double kunaiY = [
      groundLevelY,
      groundLevelY - 50,
      groundLevelY - 100,
      groundLevelY - 150,
    ][Random().nextInt(4)];
    double dir = (position.x > 400) ? -1.0 : 1.0;

    // KUNAIS NA FRENTE DE TUDO: Criamos a Kunai e adicionamos priority = 20
    Kunai novaKunai = Kunai(
      player: player,
      direction: dir,
      position: Vector2(position.x + (dir * 40), kunaiY),
    );
    novaKunai.priority = 20;

    gameRef.world.add(novaKunai);
  }

  void receiveDamage(double damage) {
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
    } else {
      currentHealth -= damage;
      if (currentHealth <= 0) currentHealth = 0;
    }
  }
}
