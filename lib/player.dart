import 'package:flame/components.dart';
import 'package:flame/sprite.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flame/collisions.dart';
import 'package:flutter/material.dart';
import 'my_game.dart';
import 'boss.dart';
import 'settings_overlay.dart';

// ==========================================
// EFEITOS VISUAIS
// ==========================================
class JumpPuffEffect extends SpriteAnimationComponent
    with HasGameRef<MyPixelGame> {
  JumpPuffEffect({required Vector2 position, required Vector2 size})
    : super(
        position: position,
        size: size,
        anchor: Anchor.center,
        removeOnFinish: true,
      );

  @override
  Future<void> onLoad() async {
    animation = await gameRef.loadSpriteAnimation(
      'air_puff.png',
      SpriteAnimationData.sequenced(
        amount: 4,
        stepTime: 0.08,
        textureSize: Vector2.all(32),
        loop: false,
      ),
    );
  }
}

class SlashEffect extends SpriteAnimationComponent
    with HasGameRef<MyPixelGame> {
  final String spriteName;
  final bool isFacingRight;
  final int frameAmount;

  SlashEffect({
    required this.spriteName,
    required Vector2 position,
    required this.isFacingRight,
    required this.frameAmount,
    double effectScale = 1.5,
  }) : super(
         position: position,
         size: Vector2(45 * effectScale, 32 * effectScale),
         anchor: Anchor.center,
         removeOnFinish: true,
       );

  @override
  Future<void> onLoad() async {
    animation = await gameRef.loadSpriteAnimation(
      spriteName,
      SpriteAnimationData.sequenced(
        amount: frameAmount,
        stepTime: 0.08,
        textureSize: Vector2(45, 32),
        loop: false,
      ),
    );

    if (!isFacingRight) {
      flipHorizontallyAroundCenter();
    }
  }
}

// ==========================================
// CLASSE PLAYER
// ==========================================
class Player extends PositionComponent with HasGameRef<MyPixelGame> {
  final JoystickComponent joystick;
  Boss? boss;

  bool isInvincibleCheat = false;
  double damageMultiplier = 1.0;

  double paralyzeTimer = 0.0;
  bool get isParalyzed => paralyzeTimer > 0;

  final String arquivoPasso = 'andar.mp3';
  final String arquivoPulo = 'som_pulo_chao.mp3';

  late AudioPool poolPulo;
  late AudioPool poolPasso;

  double stepTimer = 0.0;
  final double stepInterval = 0.35;

  double speed = 250;
  Vector2 velocity = Vector2.zero();

  final double groundLevelY = 312.0;

  int jumpCount = 0;
  bool isInvincible = false;
  double gravity = 800;
  bool isBlocking = false;
  double blockTimer = 0.0;
  final double parryWindow = 0.2;
  double health = 5.0;

  double specialMeter = 0.0;
  int comboMultiplier = 1;
  int hitCount = 0;
  double continuousHitTimer = 0.0;
  double timeSinceLastHit = 0.0;
  double decayTimer = 0.0;

  bool isDashing = false;
  double dashTimer = 0.0;
  double dashCooldownTimer = 0.0;
  final double tempoTotalDash = 0.3;
  final double tempoDoImpulso = 0.08;
  final double tempoDeRecargaDash = 1.275;

  bool isJumping = false;
  bool isFacingRight = true;
  bool isWalking = false;

  // SISTEMA DE ATAQUE
  bool isAttacking = false;
  int currentAttackStep = 0;
  int comboTarget = 0;
  bool hasDealtDamageThisStep = false;

  // SISTEMA DE DEFESA (PARRY)
  bool isParrySuccessAnim = false;
  bool isParryFailAnim = false;

  SpriteAnimationTicker? walkTicker;
  SpriteAnimationTicker? idleTicker;
  SpriteAnimationTicker? jumpTicker;
  SpriteAnimationTicker? dashImpulseTicker;
  SpriteAnimationTicker? dashRunTicker;

  SpriteAnimationTicker? attack1Ticker;
  SpriteAnimationTicker? attack2Ticker;
  SpriteAnimationTicker? attack3Ticker;

  SpriteAnimationTicker? parrySuccessTicker;
  SpriteAnimationTicker? parryFailTicker;

  Player({required this.joystick})
    : super(size: Vector2.all(96), anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    final hitbox = RectangleHitbox(
      size: Vector2(30, 34),
      position: Vector2(33, 32),
    );
    hitbox.paint.color = Colors.transparent;
    add(hitbox);

    try {
      final walkAnim = await gameRef.loadSpriteAnimation(
        'player_walk.png',
        SpriteAnimationData.sequenced(
          amount: 12,
          stepTime: 0.1,
          textureSize: Vector2.all(32),
        ),
      );
      walkTicker = walkAnim.createTicker();
      final idleAnim = await gameRef.loadSpriteAnimation(
        'player_idle.png',
        SpriteAnimationData.sequenced(
          amount: 1,
          stepTime: 0.1,
          textureSize: Vector2.all(32),
        ),
      );
      idleTicker = idleAnim.createTicker();
      final jumpAnim = await gameRef.loadSpriteAnimation(
        'pulo_fixo_1.png',
        SpriteAnimationData.sequenced(
          amount: 9,
          stepTime: 0.1,
          textureSize: Vector2.all(32),
        ),
      );
      jumpTicker = jumpAnim.createTicker();
      final impulseAnim = await gameRef.loadSpriteAnimation(
        'player_dash(etap1).png',
        SpriteAnimationData.sequenced(
          amount: 1,
          stepTime: 0.1,
          textureSize: Vector2.all(32),
        ),
      );
      dashImpulseTicker = impulseAnim.createTicker();
      final runAnim = await gameRef.loadSpriteAnimation(
        'player_dash(etap2).png',
        SpriteAnimationData.sequenced(
          amount: 1,
          stepTime: 0.1,
          textureSize: Vector2.all(32),
        ),
      );
      dashRunTicker = runAnim.createTicker();

      final atk1Anim = await gameRef.loadSpriteAnimation(
        'player_ataque-1.png',
        SpriteAnimationData.sequenced(
          amount: 5,
          stepTime: 0.1,
          textureSize: Vector2.all(32),
          loop: false,
        ),
      );
      attack1Ticker = atk1Anim.createTicker();
      final atk2Anim = await gameRef.loadSpriteAnimation(
        'player_ataque-2.png',
        SpriteAnimationData.sequenced(
          amount: 5,
          stepTime: 0.1,
          textureSize: Vector2.all(32),
          loop: false,
        ),
      );
      attack2Ticker = atk2Anim.createTicker();
      final atk3Anim = await gameRef.loadSpriteAnimation(
        'player_ataque-3.png',
        SpriteAnimationData.sequenced(
          amount: 5,
          stepTime: 0.1,
          textureSize: Vector2.all(32),
          loop: false,
        ),
      );
      attack3Ticker = atk3Anim.createTicker();

      final parrySucessoAnim = await gameRef.loadSpriteAnimation(
        'player_deflection_sucesso.png',
        SpriteAnimationData.sequenced(
          amount: 5,
          stepTime: 0.1,
          textureSize: Vector2.all(32),
          loop: false,
        ),
      );
      parrySuccessTicker = parrySucessoAnim.createTicker();

      final parryFalhaAnim = await gameRef.loadSpriteAnimation(
        'player_deflection_falha.png',
        SpriteAnimationData.sequenced(
          amount: 11,
          stepTime: 0.1,
          textureSize: Vector2.all(32),
          loop: false,
        ),
      );
      parryFailTicker = parryFalhaAnim.createTicker();
    } catch (e) {}

    try {
      poolPulo = await FlameAudio.createPool(
        arquivoPulo,
        minPlayers: 1,
        maxPlayers: 2,
      );
      poolPasso = await FlameAudio.createPool(
        arquivoPasso,
        minPlayers: 1,
        maxPlayers: 3,
      );
    } catch (e) {}

    position = Vector2(100, groundLevelY);
    stepTimer = stepInterval;
  }

  void _cancelActions() {
    if (isAttacking) {
      isAttacking = false;
      currentAttackStep = 0;
      comboTarget = 0;
      hasDealtDamageThisStep = false;
    }
    isParrySuccessAnim = false;
    isParryFailAnim = false;
  }

  void applyParalysis(double duration) {
    if (isInvincibleCheat) return;
    paralyzeTimer = duration;
    velocity = Vector2.zero();
    isWalking = false;
    _cancelActions();
  }

  void jump() {
    if (isDashing || isBlocking || isParalyzed) return;
    _cancelActions();

    if (position.y >= groundLevelY) {
      try {
        poolPulo.start(volume: AudioManager.pulo * 0.4);
      } catch (e) {}
      velocity.y = -400;
      jumpCount = 1;
      isJumping = true;
    } else if (jumpCount < 2) {
      velocity.y = -350;
      jumpCount = 2;
      isJumping = true;
      Vector2 posFumaca = position + Vector2(0, 18);
      gameRef.world.add(
        JumpPuffEffect(position: posFumaca, size: Vector2.all(80)),
      );
    }
  }

  void dash() {
    if (isInvincible || isBlocking || dashCooldownTimer > 0 || isParalyzed)
      return;
    _cancelActions();

    isInvincible = true;
    isDashing = true;
    isJumping = false;
    dashTimer = 0.0;
    dashCooldownTimer = tempoDeRecargaDash;
    speed = 800;
  }

  void basicAttack() {
    if (isParalyzed || isDashing || isBlocking) return;
    if (comboTarget < 3) comboTarget++;
    if (!isAttacking) _startNextAttack();
  }

  void _startNextAttack() {
    if (comboTarget > currentAttackStep) {
      isAttacking = true;
      currentAttackStep++;
      hasDealtDamageThisStep = false;
      if (currentAttackStep == 1)
        attack1Ticker?.reset();
      else if (currentAttackStep == 2)
        attack2Ticker?.reset();
      else if (currentAttackStep == 3)
        attack3Ticker?.reset();
    } else {
      _cancelActions();
    }
  }

  void specialAttack() {
    if (isParalyzed) return;
    _cancelActions();

    if (specialMeter >= 100.0 &&
        boss != null &&
        position.distanceTo(boss!.position) < 200) {
      boss!.receiveDamage(200.0 * damageMultiplier);
      specialMeter = 0.0;
    }
  }

  void startBlocking() {
    if (isDashing || isParalyzed) return;
    _cancelActions();

    isBlocking = true;
    isJumping = false;
    blockTimer = 0.0;
  }

  void stopBlocking() => isBlocking = false;

  void receiveAttack(double bossDamage) {
    if (isInvincibleCheat || gameRef.bossDamageDisabled || isInvincible) return;

    _cancelActions();

    if (isBlocking) {
      if (blockTimer <= parryWindow) {
        isParrySuccessAnim = true;
        parrySuccessTicker?.reset();
        return;
      } else {
        health -= (bossDamage * 0.5);
        isParryFailAnim = true;
        parryFailTicker?.reset();
      }
    } else {
      health -= bossDamage;
    }

    hitCount = 0;
    continuousHitTimer = 0.0;
    timeSinceLastHit = 99.0;
    decayTimer = 0.0;

    if (health <= 0) {
      health = 0;
      gameRef.pauseEngine();
      _transicaoDeMusicaMorte();
      gameRef.overlays.add('GameOver');
    }
  }

  void _transicaoDeMusicaMorte() async {
    try {
      double vol = AudioManager.bgm;
      while (vol > 0.0) {
        vol -= 0.02;
        if (vol < 0) vol = 0;
        FlameAudio.bgm.audioPlayer?.setVolume(vol);
        await Future.delayed(const Duration(milliseconds: 100));
      }
      FlameAudio.bgm.stop();
      FlameAudio.bgm.play('musica_morte.mp3', volume: AudioManager.deathBgm);
    } catch (e) {
      FlameAudio.bgm.stop();
      FlameAudio.bgm.play('musica_morte.mp3', volume: AudioManager.deathBgm);
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (gameRef.isEditingHUD) return;

    if (isParalyzed) {
      paralyzeTimer -= dt;
      if (position.y < groundLevelY)
        velocity.y += gravity * dt;
      else {
        velocity.y = 0;
        position.y = groundLevelY;
      }
      position += velocity * dt;
      position.x = position.x.clamp(16.0, 784.0);
      return;
    }

    if (isParrySuccessAnim) {
      parrySuccessTicker?.update(dt);
      if (parrySuccessTicker?.done() == true) isParrySuccessAnim = false;
    }
    if (isParryFailAnim) {
      parryFailTicker?.update(dt);
      if (parryFailTicker?.done() == true) isParryFailAnim = false;
    }

    timeSinceLastHit += dt;
    if (timeSinceLastHit < 1.0) {
      continuousHitTimer += dt;
      if (continuousHitTimer >= 2.3) {
        comboMultiplier *= 2;
        continuousHitTimer = 0.0;
      }
    } else {
      continuousHitTimer = 0.0;
      hitCount = 0;
    }

    if (comboMultiplier > 1) {
      double targetDecayTime = 3.0;
      int tempMult = comboMultiplier;
      while (tempMult > 2) {
        targetDecayTime *= 0.66;
        tempMult ~/= 2;
      }
      decayTimer += dt;
      if (decayTimer >= targetDecayTime) {
        comboMultiplier ~/= 2;
        decayTimer = 0.0;
      }
    } else {
      decayTimer = 0.0;
    }

    if (isAttacking) {
      SpriteAnimationTicker? activeTicker;
      String effectName = '';
      int effectAmount = 4;
      double scaleEfeito = 1.5;
      Vector2 deslocamentoManual = Vector2.zero();

      if (currentAttackStep == 1) {
        attack1Ticker?.update(dt);
        activeTicker = attack1Ticker;
        effectName = 'corte_subindo_effect.png';
        effectAmount = 4;
        scaleEfeito = 2.5;
        deslocamentoManual = Vector2(45.0, -10.0);
        if (attack1Ticker?.done() == true) _startNextAttack();
      } else if (currentAttackStep == 2) {
        attack2Ticker?.update(dt);
        activeTicker = attack2Ticker;
        effectName = 'corte_estocada_effect.png';
        effectAmount = 3;
        scaleEfeito = 3.0;
        deslocamentoManual = Vector2(45.0, -10.0);
        if (attack2Ticker?.done() == true) _startNextAttack();
      } else if (currentAttackStep == 3) {
        attack3Ticker?.update(dt);
        activeTicker = attack3Ticker;
        effectName = 'corte_vertical_effect.png';
        effectAmount = 5;
        scaleEfeito = 3.0;
        deslocamentoManual = Vector2(30.0, -30.0);
        if (attack3Ticker?.done() == true) _startNextAttack();
      }

      if (activeTicker != null &&
          activeTicker.currentIndex >= 2 &&
          !hasDealtDamageThisStep) {
        hasDealtDamageThisStep = true;

        bool acertouAlgo = false; // Flag para desenhar o rastro da espada

        // CORREÇÃO: O Player agora confere se a vida do boss é > 0. Se a vida for 0 (morte), não bate/comba mais.
        if (boss != null &&
            boss!.currentHealth > 0 &&
            position.distanceTo(boss!.position) < 120) {
          boss!.receiveDamage(10.0 * damageMultiplier);
          hitCount++;
          specialMeter += (1.0 * comboMultiplier);
          if (specialMeter > 100.0) specialMeter = 100.0;
          timeSinceLastHit = 0.0;
          decayTimer = 0.0;
          acertouAlgo = true;
        }

        // NOVO: A ESPADA CONFERE SE TEM ALGUM BOTÃO DE VITÓRIA PERTO PARA ACERTÁ-LO!
        final botoes = gameRef.world.children.query<VictoryButton>();
        for (final botao in botoes) {
          if (position.distanceTo(botao.position) < 120) {
            botao.receiveDamage(
              1.0,
            ); // O botão "sofre o dano" e chama a função dele
            acertouAlgo = true;
          }
        }

        if (acertouAlgo) {
          double finalX = isFacingRight
              ? deslocamentoManual.x
              : -deslocamentoManual.x;
          Vector2 effectPos = position + Vector2(finalX, deslocamentoManual.y);

          gameRef.world.add(
            SlashEffect(
              spriteName: effectName,
              position: effectPos,
              isFacingRight: isFacingRight,
              frameAmount: effectAmount,
              effectScale: scaleEfeito,
            )..priority = 100, // Cortes da espada sempre na frente!
          );
        }
      }
    }

    if (!joystick.delta.isZero() && !isBlocking) {
      velocity.x = joystick.relativeDelta.x * speed;
      isWalking = true;
      if (joystick.relativeDelta.x < 0)
        isFacingRight = false;
      else if (joystick.relativeDelta.x > 0)
        isFacingRight = true;
    } else {
      if (isDashing)
        velocity.x = (scale.x > 0 ? 1 : -1) * speed;
      else {
        velocity.x = 0;
        isWalking = false;
      }
    }

    if (position.y < groundLevelY)
      velocity.y += gravity * dt;
    else if (velocity.y >= 0) {
      velocity.y = 0;
      position.y = groundLevelY;
      jumpCount = 0;
      isJumping = false;
    }

    position += velocity * dt;
    position.x = position.x.clamp(16.0, 784.0);

    if (isWalking && position.y >= groundLevelY && !isDashing && !isBlocking) {
      stepTimer += dt;
      if (stepTimer >= stepInterval) {
        try {
          poolPasso.start(volume: AudioManager.passo * 0.15);
        } catch (e) {}
        stepTimer = 0.0;
      }
    } else {
      stepTimer = stepInterval;
    }

    if (dashCooldownTimer > 0) dashCooldownTimer -= dt;
    if (isBlocking) blockTimer += dt;
    if (isDashing) {
      dashTimer += dt;
      dashImpulseTicker?.update(dt);
      dashRunTicker?.update(dt);
      if (dashTimer >= tempoTotalDash) {
        isDashing = false;
        isInvincible = false;
        speed = 250;
      }
    }
    walkTicker?.update(dt);
    idleTicker?.update(dt);
    jumpTicker?.update(dt);
  }

  @override
  void render(Canvas canvas) {
    if (!isFacingRight) {
      canvas.save();
      canvas.translate(size.x, 0);
      canvas.scale(-1, 1);
    }

    if (isParalyzed && idleTicker != null) {
      idleTicker!.getSprite().render(canvas, size: size);
    } else if (isParrySuccessAnim && parrySuccessTicker != null) {
      parrySuccessTicker!.getSprite().render(canvas, size: size);
    } else if (isParryFailAnim && parryFailTicker != null) {
      parryFailTicker!.getSprite().render(canvas, size: size);
    } else if (isAttacking) {
      if (currentAttackStep == 1 && attack1Ticker != null)
        attack1Ticker!.getSprite().render(canvas, size: size);
      else if (currentAttackStep == 2 && attack2Ticker != null)
        attack2Ticker!.getSprite().render(canvas, size: size);
      else if (currentAttackStep == 3 && attack3Ticker != null)
        attack3Ticker!.getSprite().render(canvas, size: size);
    } else if (isDashing) {
      if (dashTimer < tempoDoImpulso && dashImpulseTicker != null)
        dashImpulseTicker!.getSprite().render(canvas, size: size);
      else if (dashRunTicker != null)
        dashRunTicker!.getSprite().render(canvas, size: size);
    } else if (isJumping && jumpTicker != null) {
      jumpTicker!.getSprite().render(canvas, size: size);
    } else {
      if (isWalking && walkTicker != null)
        walkTicker!.getSprite().render(canvas, size: size);
      else if (idleTicker != null)
        idleTicker!.getSprite().render(canvas, size: size);
      else
        canvas.drawRect(size.toRect(), Paint()..color = Colors.red);
    }

    if (!isFacingRight) canvas.restore();
  }
}
