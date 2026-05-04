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

  Kunai({
    required this.player,
    required this.direction,
    required Vector2 position,
  }) : super(size: Vector2(30, 34), position: position, anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    add(RectangleHitbox()..paint.color = Colors.transparent);
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (gameRef.isEditingHUD) return;

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
    canvas.drawRect(size.toRect(), Paint()..color = Colors.deepPurpleAccent);
  }
}

class BossArm extends PositionComponent {
  Paint armPaint = Paint()..color = Colors.black;
  BossArm() : super(size: Vector2(110, 15), anchor: Anchor.centerLeft);

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    canvas.drawRect(size.toRect(), armPaint);
  }
}

class Boss extends PositionComponent with HasGameRef<MyPixelGame> {
  final Player player;

  double maxHealth = 1000.0;
  double currentHealth = 1000.0;

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

  bool jaTocouSomImpacto = false;
  bool jaVibrouNoChao = false;

  // DECLARAÇÃO DAS HITBOXES
  late RectangleHitbox bodyHitbox;
  late RectangleHitbox rightSwordHitbox;
  late RectangleHitbox leftSwordHitbox;

  SpriteAnimationTicker? idleTicker;

  Boss({required this.player})
    // ==========================================
    // 1. ESPICHADA DE 3X (100 * 3 = 300)
    // ==========================================
    : super(size: Vector2.all(300), anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    try {
      final idleAnim = await gameRef.loadSpriteAnimation(
        'boss_idle.png',
        SpriteAnimationData.sequenced(
          amount: 1, // <-- 2. APENAS 1 FRAME PARA PARAR DE PISCAR!
          stepTime: 0.15,
          textureSize: Vector2.all(
            100,
          ), // A textura lida continua sendo 100x100
        ),
      );
      idleTicker = idleAnim.createTicker();
    } catch (e) {
      debugPrint('Erro ao carregar boss_idle.png: $e');
    }

    // ==========================================
    // AJUSTE MANUAL DE HITBOXES (Valores já multiplicados por 3)
    // ==========================================

    // 1. HITBOX DO CORPO (Verde)
    final Vector2 posicaoCorpo = Vector2(75, 30);
    final Vector2 tamanhoCorpo = Vector2(150, 270);

    // 2. HITBOX DA ESPADA DIREITA (Vermelho)
    final Vector2 posicaoEspadaDir = Vector2(240, 135);
    final Vector2 tamanhoEspadaDir = Vector2(120, 45);

    // 3. HITBOX DA ESPADA ESQUERDA (Azul)
    final Vector2 posicaoEspadaEsq = Vector2(-60, 135);
    final Vector2 tamanhoEspadaEsq = Vector2(120, 45);

    // ==========================================
    // 3. RENDER SHAPE = TRUE PARA VER AS CORES
    // ==========================================

    bodyHitbox = RectangleHitbox(position: posicaoCorpo, size: tamanhoCorpo)
      ..paint = (Paint()
        ..color = Colors.green.withOpacity(0.5)
        ..style = PaintingStyle.fill)
      ..renderShape = true; // <-- ISSO FORÇA A HITBOX A APARECER!

    rightSwordHitbox =
        RectangleHitbox(position: posicaoEspadaDir, size: tamanhoEspadaDir)
          ..paint = (Paint()
            ..color = Colors.red.withOpacity(0.5)
            ..style = PaintingStyle.fill)
          ..renderShape = true; // <-- ISSO FORÇA A HITBOX A APARECER!

    leftSwordHitbox =
        RectangleHitbox(position: posicaoEspadaEsq, size: tamanhoEspadaEsq)
          ..paint = (Paint()
            ..color = Colors.blue.withOpacity(0.5)
            ..style = PaintingStyle.fill)
          ..renderShape = true; // <-- ISSO FORÇA A HITBOX A APARECER!

    add(bodyHitbox);
    add(rightSwordHitbox);
    add(leftSwordHitbox);

    armRight = BossArm();
    armRight.position = Vector2(size.x / 2, size.y / 2 - 10);
    add(armRight);

    armLeft = BossArm();
    armLeft.position = Vector2(size.x / 2, size.y / 2 + 10);
    add(armLeft);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    if (idleTicker != null) {
      idleTicker!.getSprite().render(canvas, size: size);
    } else {
      canvas.drawRect(size.toRect(), Paint()..color = Colors.red);
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (gameRef.isEditingHUD) return;

    idleTicker?.update(dt);

    if (currentHealth <= 0 && currentPhase != BossPhase.phase1) return;

    if (currentPhase == BossPhase.phase1) {
      _updatePhase1(dt);
    } else if (currentPhase == BossPhase.phase2) {
      _updatePhase2(dt);
    }
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
        double pLeft = player.position.x - 15;
        double pRight = player.position.x + 15;
        double pTop = player.position.y - 17;
        double pBottom = player.position.y + 17;

        for (double raio = 20.0; raio <= 110.0; raio += 10.0) {
          double pointX = position.x + cos(armRight.angle) * raio;
          double pointY = position.y + sin(armRight.angle) * raio;

          if (pointX >= pLeft &&
              pointX <= pRight &&
              pointY >= pTop &&
              pointY <= pBottom) {
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

        if (stateTimer >= 0.8) {
          if (Random().nextDouble() < 0.4)
            currentState = BossState.parryStance;
          else
            currentState = BossState.chasing;
          stateTimer = 0.0;
        }
        break;

      case BossState.parryStance:
        double parryAngle = (attackDirection == 1.0)
            ? (pi / 4)
            : ((3 * pi) / 4);
        armRight.angle = lerpDouble(armRight.angle, parryAngle, 10.0 * dt)!;
        armLeft.angle = armRight.angle + 0.5;

        if (stateTimer >= 1.5) {
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

    bool isAttacking =
        (currentState == BossState.windup ||
        currentState == BossState.swinging);

    if (isAttacking) {
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

      specialCooldown = Random().nextDouble() * 4.0 + 4.0;

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

        if ((position.x - targetX).abs() > 10) {
          position.x += (targetX > position.x ? 1 : -1) * moveSpeed * dt;
        } else {
          if (queuedSpecial == SpecialAttack.aerialDrop) {
            saltosRestantes = Random().nextInt(4) + 3;
            currentState = BossState.jumpingUp;
          } else if (queuedSpecial == SpecialAttack.kunaiRain) {
            currentState = BossState.kunaiAttack;
            kunaisAtiradas = 0;
          } else {
            currentState = BossState.chasing;
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
          } else {
            if (stateTimer >= 1.5) {
              currentState = BossState.chasing;
              stateTimer = 0.0;
            }
          }
        }
        break;

      case BossState.jumpingUp:
        jaTocouSomImpacto = false;
        jaVibrouNoChao = false;

        armRight.angle = pi / 2;
        armLeft.angle = pi / 2;
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
        armRight.angle = pi / 2;
        armLeft.angle = pi / 2;
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

          if (position.distanceTo(player.position) < 100) {
            player.receiveAttack(2.0);
          }
          saltosRestantes--;
          if (saltosRestantes > 0) {
            currentState = BossState.jumpingUp;
          } else {
            currentState = BossState.chasing;
          }
          stateTimer = 0.0;
        }
        break;

      default:
        _updatePhase1(dt);
        break;
    }
  }

  void _atirarKunai() {
    List<double> alturas = [
      groundLevelY,
      groundLevelY - 50,
      groundLevelY - 100,
      groundLevelY - 150,
    ];

    int lane = Random().nextInt(4);
    double kunaiY = alturas[lane];

    double dir = (position.x > 400) ? -1.0 : 1.0;
    Vector2 kunaiPos = Vector2(position.x + (dir * 40), kunaiY);

    gameRef.world.add(
      Kunai(player: player, direction: dir, position: kunaiPos),
    );
  }

  void receiveDamage(double damage) {
    if (currentState == BossState.transitioning ||
        currentState == BossState.jumpingUp ||
        currentState == BossState.hovering ||
        currentState == BossState.falling) {
      return;
    }

    if (currentPhase == BossPhase.phase1) {
      if (currentState == BossState.parryStance) {
        if (Random().nextInt(100) < 65) {
          debugPrint("💥 PARRY DO BOSS!");
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

        debugPrint("!!! FASE 2 INICIADA !!!");
      }
    } else {
      currentHealth -= damage;
      if (currentHealth <= 0) {
        currentHealth = 0;
        debugPrint("BOSS FINALMENTE DERROTADO!");
      }
    }
  }
}
