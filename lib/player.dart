import 'package:flame/components.dart';
import 'package:flame/sprite.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flame/collisions.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'my_game.dart';
import 'boss.dart';
import 'settings_overlay.dart';

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
    if (!isFacingRight) flipHorizontallyAroundCenter();
  }
}

class UltimateSlash extends PositionComponent with HasGameRef<MyPixelGame> {
  final double direction;
  final Boss boss;
  final Player player;
  bool hasHit = false;
  Sprite? slashSprite;

  UltimateSlash({
    required Vector2 position,
    required this.direction,
    required this.boss,
    required this.player,
  }) : super(
         position: position,
         size: Vector2(50, 100),
         anchor: Anchor.center,
         priority: 15,
       );

  @override
  Future<void> onLoad() async {
    try {
      slashSprite = await gameRef.loadSprite('ataque_especial.png');
    } catch (e) {}
    add(RectangleHitbox()..paint.color = Colors.transparent);
    scale = Vector2.all(0.2);
    add(ScaleEffect.to(Vector2(2.5, 3.0), EffectController(duration: 0.3)));
  }

  @override
  void update(double dt) {
    super.update(dt);
    position.x += 1000 * direction * dt;
    if (position.x < -400 || position.x > 1400) removeFromParent();

    if (!hasHit && position.distanceTo(boss.position) < 300) {
      boss.receiveDamage(120.0 * player.damageMultiplier, isUnblockable: true);
      player.specialMeter += (20.0 * player.comboMultiplier);
      if (player.specialMeter > 100.0) player.specialMeter = 100.0;
      hasHit = true;
    }
  }

  @override
  void render(Canvas canvas) {
    if (direction < 0) {
      canvas.save();
      canvas.translate(size.x, 0);
      canvas.scale(-1, 1);
    }
    if (slashSprite != null)
      slashSprite!.render(canvas, size: size);
    else
      canvas.drawRect(size.toRect(), Paint()..color = Colors.cyanAccent);
    if (direction < 0) {
      canvas.restore();
    }
  }
}

class CinematicBackground extends PositionComponent
    with HasGameRef<MyPixelGame> {
  CinematicBackground() : super(priority: 8);
  @override
  void render(Canvas canvas) {
    canvas.drawRect(
      Rect.fromLTWH(-1000, -1000, 3000, 3000),
      Paint()..color = Colors.black.withOpacity(0.85),
    );
  }
}

class Player extends PositionComponent with HasGameRef<MyPixelGame> {
  final JoystickComponent joystick;
  Boss? boss;

  bool isInvincibleCheat = false;
  double damageMultiplier = 1.0;

  double paralyzeTimer = 0.0;
  bool get isParalyzed => paralyzeTimer > 0;

  double damageInvulnerabilityTimer = 0.0;
  final double invulnerabilityDuration = 1.0;

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

  bool isParrying = false;
  double parryTimer = 0.0;
  final double parryWindow = 0.08;

  double health = 5.0;

  double specialMeter = 0.0;
  int comboMultiplier = 1;
  int hitCount = 0;
  double continuousHitTimer = 0.0;
  double timeSinceLastHit = 0.0;
  double decayTimer = 0.0;

  bool isHoldingSpecial = false;
  double specialHoldTimer = 0.0;
  final double specialHoldThreshold = 0.5;

  bool isDashing = false;
  double dashTimer = 0.0;
  double dashCooldownTimer = 0.0;
  final double tempoTotalDash = 0.3;
  final double tempoDoImpulso = 0.08;
  final double tempoDeRecargaDash = 1.175;

  bool isJumping = false;
  bool isFacingRight = true;
  bool isWalking = false;

  bool isAttacking = false;
  int currentAttackStep = 0;
  int comboTarget = 0;
  bool hasDealtDamageThisStep = false;

  bool isParrySuccessAnim = false;
  bool isParryFailAnim = false;

  bool isCinematicPhase1 = false;
  bool isCinematicPhase2 = false;
  bool _hasVibratedForCinematic = false;
  CinematicBackground? cinematicBg;

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
  SpriteAnimationTicker? stunTicker;
  SpriteAnimationTicker? starStunTicker;
  SpriteAnimationTicker? specialStartTicker;
  SpriteAnimationTicker? specialAttackTicker;

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
      final stunAnim = await gameRef.loadSpriteAnimation(
        'player_stunado.png',
        SpriteAnimationData.sequenced(
          amount: 12,
          stepTime: 0.15,
          textureSize: Vector2.all(32),
        ),
      );
      stunTicker = stunAnim.createTicker();
      final starAnim = await gameRef.loadSpriteAnimation(
        'estrela_stun.png',
        SpriteAnimationData.sequenced(
          amount: 5,
          stepTime: 0.1,
          textureSize: Vector2.all(96),
        ),
      );
      starStunTicker = starAnim.createTicker();
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
      final specStartAnim = await gameRef.loadSpriteAnimation(
        'player_iniciando_especial.png',
        SpriteAnimationData.sequenced(
          amount: 11,
          stepTime: 0.15,
          textureSize: Vector2.all(32),
          loop: false,
        ),
      );
      specialStartTicker = specStartAnim.createTicker();
      final specAtkAnim = await gameRef.loadSpriteAnimation(
        'player_ataque-especial.png',
        SpriteAnimationData.sequenced(
          amount: 3,
          stepTime: 0.1,
          textureSize: Vector2.all(32),
          loop: false,
        ),
      );
      specialAttackTicker = specAtkAnim.createTicker();
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
    position = Vector2(108, groundLevelY); // <-- NASCE A 108 AGORA!
    stepTimer = stepInterval;
  }

  void _cancelActions() {
    if (isAttacking) {
      isAttacking = false;
      currentAttackStep = 0;
      comboTarget = 0;
      hasDealtDamageThisStep = false;
    }
    isParrying = false;
    isParrySuccessAnim = false;
  }

  void applyParalysis(double duration) {
    if (isInvincibleCheat || isCinematicPhase1 || isCinematicPhase2) return;
    paralyzeTimer = duration;
    velocity = Vector2.zero();
    isWalking = false;
    isHoldingSpecial = false;
    _cancelActions();
    stunTicker?.reset();
    starStunTicker?.reset();
  }

  void jump() {
    if (gameRef.introState != IntroState.finished) return;
    if (isDashing ||
        isParrying ||
        isParalyzed ||
        isParryFailAnim ||
        isCinematicPhase1 ||
        isCinematicPhase2)
      return;
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
    if (gameRef.introState != IntroState.finished) return;
    if (isInvincible ||
        isParrying ||
        dashCooldownTimer > 0 ||
        isParalyzed ||
        isParryFailAnim ||
        isCinematicPhase1 ||
        isCinematicPhase2)
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
    if (gameRef.introState != IntroState.finished) return;
    if (isParalyzed ||
        isDashing ||
        isParrying ||
        isParryFailAnim ||
        isCinematicPhase1 ||
        isCinematicPhase2)
      return;
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

  void startSpecial() {
    if (gameRef.introState != IntroState.finished) return;
    if (isParalyzed ||
        isParryFailAnim ||
        isCinematicPhase1 ||
        isCinematicPhase2)
      return;
    isHoldingSpecial = true;
    specialHoldTimer = 0.0;
  }

  void releaseSpecial() {
    if (!isHoldingSpecial) return;
    isHoldingSpecial = false;

    if (specialHoldTimer < specialHoldThreshold) {
      if (specialMeter >= 100.0 && boss != null) {
        _cancelActions();
        specialMeter = 0.0;

        isCinematicPhase1 = true;
        _hasVibratedForCinematic = false;
        specialStartTicker?.reset();

        boss!.isFrozen = true;

        cinematicBg = CinematicBackground();
        gameRef.world.add(cinematicBg!);

        double zoomLevel = 1.6;

        double visibleWidth = 800 / zoomLevel;
        double visibleHeight = 360 / zoomLevel;

        double targetX = position.x - (visibleWidth / 2);
        double targetY = position.y - (visibleHeight / 2);

        targetX = targetX.clamp(0.0, 800.0 - visibleWidth);
        targetY = targetY.clamp(0.0, 360.0 - visibleHeight);

        Vector2 cameraTarget = Vector2(targetX, targetY);

        gameRef.camera.viewfinder.add(
          ScaleEffect.to(
            Vector2.all(zoomLevel),
            EffectController(duration: 0.3),
          ),
        );
        gameRef.camera.viewfinder.add(
          MoveEffect.to(cameraTarget, EffectController(duration: 0.3)),
        );
      }
    }
  }

  void tentarParry() {
    if (gameRef.introState != IntroState.finished) return;
    if (isDashing ||
        isParalyzed ||
        isParryFailAnim ||
        isParrying ||
        isCinematicPhase1 ||
        isCinematicPhase2)
      return;
    _cancelActions();
    isParrying = true;
    parryTimer = 0.0;
    isParrySuccessAnim = true;
    parrySuccessTicker?.reset();
  }

  void _ativarTelaPulsando() {
    gameRef.camera.viewfinder.add(
      ScaleEffect.by(
        Vector2.all(1.03),
        EffectController(duration: 0.1, alternate: true, repeatCount: 5),
      ),
    );
  }

  void receiveAttack(double bossDamage) {
    if (isInvincibleCheat ||
        gameRef.bossDamageDisabled ||
        isInvincible ||
        damageInvulnerabilityTimer > 0 ||
        isCinematicPhase1 ||
        isCinematicPhase2 ||
        gameRef.introState != IntroState.finished)
      return;

    if (isParrying) {
      if (parryTimer <= parryWindow) {
        _cancelActions();
        isParrying = true;
        isParrySuccessAnim = true;
        parrySuccessTicker?.reset();
        specialMeter += 15.0;
        if (specialMeter > 100.0) specialMeter = 100.0;
        return;
      } else {
        _cancelActions();
        health -= (bossDamage * 0.5);
        isParryFailAnim = true;
        parryFailTicker?.reset();
        HapticFeedback.heavyImpact();
        damageInvulnerabilityTimer = invulnerabilityDuration;
        _ativarTelaPulsando();
      }
    } else {
      _cancelActions();
      health -= bossDamage;
      HapticFeedback.heavyImpact();
      damageInvulnerabilityTimer = invulnerabilityDuration;
      _ativarTelaPulsando();
    }

    hitCount = 0;
    continuousHitTimer = 0.0;
    timeSinceLastHit = 99.0;
    decayTimer = 0.0;
    isHoldingSpecial = false;

    if (health <= 0) {
      health = 0;
      speed = 250;
      isDashing = false;
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

    if (isCinematicPhase1) {
      specialStartTicker?.update(dt);

      if (specialStartTicker!.currentIndex == 8 && !_hasVibratedForCinematic) {
        HapticFeedback.heavyImpact();
        _hasVibratedForCinematic = true;
      }

      if (specialStartTicker?.done() == true) {
        isCinematicPhase1 = false;
        isCinematicPhase2 = true;
        specialAttackTicker?.reset();
        boss?.isFrozen = false;
        cinematicBg?.removeFromParent();

        gameRef.camera.viewfinder.add(
          ScaleEffect.to(Vector2.all(1.0), EffectController(duration: 0.2)),
        );
        gameRef.camera.viewfinder.add(
          MoveEffect.to(Vector2(0, 0), EffectController(duration: 0.2)),
        );

        double dir = isFacingRight ? 1.0 : -1.0;
        gameRef.world.add(
          UltimateSlash(
            position: position.clone(),
            direction: dir,
            boss: boss!,
            player: this,
          ),
        );
      }
      return;
    }

    if (isCinematicPhase2) {
      specialAttackTicker?.update(dt);
      if (specialAttackTicker?.done() == true) {
        isCinematicPhase2 = false;
      }
      return;
    }

    if (damageInvulnerabilityTimer > 0) damageInvulnerabilityTimer -= dt;

    if (isHoldingSpecial) {
      specialHoldTimer += dt;
      if (specialHoldTimer >= specialHoldThreshold) {
        if (specialMeter >= 100.0) {
          health += 4.0;
          if (health > 5.0) health = 5.0;
          specialMeter = 0.0;
          isHoldingSpecial = false;
          HapticFeedback.lightImpact();
        } else if (specialMeter >= 50.0) {
          health += 2.0;
          if (health > 5.0) health = 5.0;
          specialMeter -= 50.0;
          isHoldingSpecial = false;
          HapticFeedback.lightImpact();
        }
      }
    }

    if (isParalyzed) {
      paralyzeTimer -= dt;
      stunTicker?.update(dt);
      starStunTicker?.update(dt);
      velocity.x = 0;
      if (position.y < groundLevelY)
        velocity.y += gravity * dt;
      else {
        velocity.y = 0;
        position.y = groundLevelY;
      }
      position += velocity * dt;
      position.x = position.x.clamp(53.0, 747.0); // <-- CLAMP DAS ÁRVORES AQUI
      return;
    }

    if (isParryFailAnim) {
      parryFailTicker?.update(dt);
      if (parryFailTicker?.done() == true) isParryFailAnim = false;
      velocity.x = 0;
      if (position.y < groundLevelY)
        velocity.y += gravity * dt;
      else {
        velocity.y = 0;
        position.y = groundLevelY;
      }
      position += velocity * dt;
      return;
    }

    if (isParrying) {
      parryTimer += dt;
      parrySuccessTicker?.update(dt);
      if (parrySuccessTicker?.done() == true) {
        isParrying = false;
        isParrySuccessAnim = false;
      }
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
        bool acertouAlgo = false;
        if (boss != null &&
            boss!.currentHealth > 0 &&
            position.distanceTo(boss!.position) < 120) {
          boss!.receiveDamage(40.0 * damageMultiplier);
          hitCount++;
          specialMeter += (2.0 * comboMultiplier);
          if (specialMeter > 100.0) specialMeter = 100.0;
          timeSinceLastHit = 0.0;
          decayTimer = 0.0;
          acertouAlgo = true;
        }
        final botoes = gameRef.world.children.query<VictoryButton>();
        for (final botao in botoes) {
          if (position.distanceTo(botao.position) < 120) {
            botao.receiveDamage(1.0);
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
            )..priority = 100,
          );
        }
      }
    }

    if (!joystick.delta.isZero() &&
        !isParrying &&
        !isParryFailAnim &&
        gameRef.introState == IntroState.finished) {
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
    position.x = position.x.clamp(
      53.0,
      747.0,
    ); // <-- CLAMP DAS ÁRVORES AQUI TAMBÉM

    if (isWalking && position.y >= groundLevelY && !isDashing && !isParrying) {
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

    Paint? piscaDano;
    if (damageInvulnerabilityTimer > 0 &&
        !isCinematicPhase1 &&
        !isCinematicPhase2) {
      if ((damageInvulnerabilityTimer * 15).floor() % 2 == 0)
        piscaDano = Paint()
          ..colorFilter = ColorFilter.mode(
            Colors.red.withOpacity(0.7),
            BlendMode.srcATop,
          );
      else
        piscaDano = Paint()..color = Colors.white.withOpacity(0.5);
    }

    if (isCinematicPhase1 && specialStartTicker != null) {
      specialStartTicker!.getSprite().render(canvas, size: size);
    } else if (isCinematicPhase2 && specialAttackTicker != null) {
      specialAttackTicker!.getSprite().render(canvas, size: size);
    } else if (isParalyzed) {
      if (stunTicker != null)
        stunTicker!.getSprite().render(
          canvas,
          size: size,
          overridePaint: piscaDano,
        );
      if (starStunTicker != null) {
        final starSize = Vector2.all(48);
        final starPos = Vector2((size.x / 2) - (starSize.x / 2), -15);
        starStunTicker!.getSprite().render(
          canvas,
          position: starPos,
          size: starSize,
        );
      }
    } else if (isParryFailAnim && parryFailTicker != null)
      parryFailTicker!.getSprite().render(
        canvas,
        size: size,
        overridePaint: piscaDano,
      );
    else if (isParrySuccessAnim && parrySuccessTicker != null)
      parrySuccessTicker!.getSprite().render(
        canvas,
        size: size,
        overridePaint: piscaDano,
      );
    else if (isAttacking) {
      if (currentAttackStep == 1 && attack1Ticker != null)
        attack1Ticker!.getSprite().render(
          canvas,
          size: size,
          overridePaint: piscaDano,
        );
      else if (currentAttackStep == 2 && attack2Ticker != null)
        attack2Ticker!.getSprite().render(
          canvas,
          size: size,
          overridePaint: piscaDano,
        );
      else if (currentAttackStep == 3 && attack3Ticker != null)
        attack3Ticker!.getSprite().render(
          canvas,
          size: size,
          overridePaint: piscaDano,
        );
    } else if (isDashing) {
      if (dashTimer < tempoDoImpulso && dashImpulseTicker != null)
        dashImpulseTicker!.getSprite().render(
          canvas,
          size: size,
          overridePaint: piscaDano,
        );
      else if (dashRunTicker != null)
        dashRunTicker!.getSprite().render(
          canvas,
          size: size,
          overridePaint: piscaDano,
        );
    } else if (isJumping && jumpTicker != null)
      jumpTicker!.getSprite().render(
        canvas,
        size: size,
        overridePaint: piscaDano,
      );
    else {
      if (isWalking && walkTicker != null)
        walkTicker!.getSprite().render(
          canvas,
          size: size,
          overridePaint: piscaDano,
        );
      else if (idleTicker != null)
        idleTicker!.getSprite().render(
          canvas,
          size: size,
          overridePaint: piscaDano,
        );
      else
        canvas.drawRect(size.toRect(), Paint()..color = Colors.red);
    }

    if (!isFacingRight) canvas.restore();
  }
}
