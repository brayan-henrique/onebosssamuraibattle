import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame_audio/flame_audio.dart';
import 'my_game.dart';
import 'settings_overlay.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({Key? key}) : super(key: key);
  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

// Adicionamos o TickerProviderStateMixin para controlar a animação
class _MenuScreenState extends State<MenuScreen> with TickerProviderStateMixin {
  bool _jogoIniciado = false;
  bool _mostrarConfiguracoes = false;
  bool _iniciarComoRemap = false;

  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  MyPixelGame? _gameInstance; // Guardamos a instância do jogo aqui

  @override
  void initState() {
    super.initState();
    // Controlador de 1 segundo
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    // Anima a tela descendo (Offset Y vai de 0 para 1, ou seja, 100% da tela para baixo)
    _slideAnimation = Tween<Offset>(begin: Offset.zero, end: const Offset(0, 1))
        .animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeInOut),
        );
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  void _iniciarJogo() {
    setState(() {
      _iniciarComoRemap = false;
      _jogoIniciado = true;

      // Cria a instância do jogo
      _gameInstance = MyPixelGame(
        startInRemapMode: _iniciarComoRemap,
        onBackToMenu: () {
          setState(() {
            _jogoIniciado = false;
            _slideController.reverse(); // Menu sobe de volta
          });
        },
      );
    });

    // Inicia a animação e SÓ DEPOIS despausa o jogo
    _slideController.forward().then((_) {
      _gameInstance?.resumeEngine();
    });
  }

  void _iniciarJogoEmModoRemap() {
    setState(() {
      _iniciarComoRemap = true;
      _jogoIniciado = true;

      _gameInstance = MyPixelGame(
        startInRemapMode: _iniciarComoRemap,
        onBackToMenu: () {
          setState(() {
            _jogoIniciado = false;
            _slideController.reverse(); // Menu sobe de volta
          });
        },
      );
    });

    // Inicia a animação e SÓ DEPOIS despausa o jogo
    _slideController.forward().then((_) {
      _gameInstance?.resumeEngine();
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      body: Stack(
        children: [
          // JOGO NO FUNDO
          if (_jogoIniciado && _gameInstance != null)
            SizedBox(
              width: screenWidth,
              height: screenHeight,
              child: GameWidget(
                game: _gameInstance!,
                overlayBuilderMap: {
                  'GameOver': (BuildContext context, MyPixelGame gameRef) {
                    return GameOverOverlay(gameRef: gameRef);
                  },

                  'PauseMenu': (BuildContext context, MyPixelGame gameRef) {
                    int cliquesNoSol = 0;

                    return Stack(
                      children: [
                        Container(color: Colors.black.withOpacity(0.6)),
                        Positioned(
                          left: 801,
                          top: 40,
                          child: GestureDetector(
                            onTap: () {
                              if (!gameRef.cheatUnlocked) {
                                cliquesNoSol++;
                                if (cliquesNoSol >= 10) {
                                  gameRef.cheatUnlocked = true;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        "🟢 HACKS DESBLOQUEADOS!",
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      backgroundColor: Colors.purple,
                                      duration: Duration(seconds: 3),
                                    ),
                                  );
                                }
                              }
                            },
                            child: Container(
                              width: 80,
                              height: 80,
                              color: Colors.transparent,
                            ),
                          ),
                        ),
                        Center(
                          child: Container(
                            width: 320,
                            height: 360,
                            decoration: BoxDecoration(
                              color: Colors.grey[900],
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white24,
                                width: 3,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.8),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  'JOGO PAUSADO',
                                  style: TextStyle(
                                    fontSize: 26,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 2,
                                  ),
                                ),
                                const SizedBox(height: 30),
                                SizedBox(
                                  width: 220,
                                  height: 45,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                    ),
                                    onPressed: () {
                                      gameRef.overlays.remove('PauseMenu');
                                      gameRef.resumeEngine();
                                      FlameAudio.bgm.resume();
                                    },
                                    child: const Text(
                                      'RETOMAR',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 15),
                                SizedBox(
                                  width: 220,
                                  height: 45,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.orange[800],
                                      foregroundColor: Colors.white,
                                    ),
                                    onPressed: () {
                                      gameRef.overlays.remove('PauseMenu');
                                      gameRef.resetGame();
                                      FlameAudio.bgm.stop();
                                      FlameAudio.bgm.play(
                                        'musica_padrao.mp3',
                                        volume: AudioManager.bgm,
                                      );
                                    },
                                    child: const Text(
                                      'RECOMEÇAR',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 15),
                                SizedBox(
                                  width: 220,
                                  height: 45,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.grey[700],
                                      foregroundColor: Colors.white,
                                    ),
                                    onPressed: () {
                                      gameRef.overlays.remove('PauseMenu');
                                      gameRef.overlays.add('SettingsMenu');
                                    },
                                    child: const Text(
                                      'CONFIGURAÇÕES',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 15),
                                SizedBox(
                                  width: 220,
                                  height: 45,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red[800],
                                      foregroundColor: Colors.white,
                                    ),
                                    onPressed: () {
                                      gameRef.overlays.remove('PauseMenu');
                                      FlameAudio.bgm.stop();
                                      gameRef.resetGame();
                                      gameRef.onBackToMenu?.call();
                                    },
                                    child: const Text(
                                      'SAIR',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },

                  'SettingsMenu': (BuildContext context, MyPixelGame gameRef) {
                    return SettingsOverlay(
                      gameRef: gameRef,
                      onClose: () {
                        gameRef.overlays.remove('SettingsMenu');
                        gameRef.overlays.add('PauseMenu');
                      },
                      onRemap: () {
                        gameRef.overlays.remove('SettingsMenu');
                        gameRef.isEditingHUD = true;
                        gameRef.resumeEngine();
                        FlameAudio.bgm.pause();
                        gameRef.overlays.add('RemapHUD');
                      },
                    );
                  },

                  'RemapHUD': (BuildContext context, MyPixelGame gameRef) {
                    return RemapOverlay(gameRef: gameRef);
                  },

                  'CheatMenu': (BuildContext context, MyPixelGame gameRef) {
                    return StatefulBuilder(
                      builder: (context, setStateOverlay) {
                        return Container(
                          color: Colors.purple.withOpacity(0.4),
                          child: Center(
                            child: Container(
                              width: 350,
                              height: 350,
                              decoration: BoxDecoration(
                                color: Colors.grey[900],
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.yellowAccent,
                                  width: 3,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text(
                                    'DEVELOPER HACKS',
                                    style: TextStyle(
                                      fontSize: 24,
                                      color: Colors.yellowAccent,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 5,
                                    ),
                                    child: SizedBox(
                                      width: 250,
                                      height: 40,
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              gameRef.player.isInvincibleCheat
                                              ? Colors.green
                                              : Colors.grey,
                                        ),
                                        onPressed: () {
                                          setStateOverlay(() {
                                            gameRef.player.isInvincibleCheat =
                                                !gameRef
                                                    .player
                                                    .isInvincibleCheat;
                                          });
                                        },
                                        child: Text(
                                          gameRef.player.isInvincibleCheat
                                              ? "GOD MODE: ON"
                                              : "GOD MODE: OFF",
                                          style: const TextStyle(
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 5,
                                    ),
                                    child: SizedBox(
                                      width: 250,
                                      height: 40,
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              gameRef.bossDamageDisabled
                                              ? Colors.red
                                              : Colors.grey,
                                        ),
                                        onPressed: () {
                                          setStateOverlay(() {
                                            gameRef.bossDamageDisabled =
                                                !gameRef.bossDamageDisabled;
                                          });
                                        },
                                        child: Text(
                                          gameRef.bossDamageDisabled
                                              ? "BOSS DAMAGE: OFF"
                                              : "BOSS DAMAGE: ON",
                                          style: const TextStyle(
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Text(
                                        "DANO: ",
                                        style: TextStyle(color: Colors.white),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.remove,
                                          color: Colors.white,
                                        ),
                                        onPressed: () => setStateOverlay(() {
                                          gameRef.player.damageMultiplier -= 1;
                                          if (gameRef.player.damageMultiplier <
                                              1) {
                                            gameRef.player.damageMultiplier = 1;
                                          }
                                        }),
                                      ),
                                      Text(
                                        "${gameRef.player.damageMultiplier.toInt()}x",
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 20,
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.add,
                                          color: Colors.white,
                                        ),
                                        onPressed: () => setStateOverlay(() {
                                          gameRef.player.damageMultiplier += 1;
                                        }),
                                      ),
                                    ],
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 5,
                                    ),
                                    child: SizedBox(
                                      width: 250,
                                      height: 40,
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.blue,
                                        ),
                                        onPressed: () {
                                          setStateOverlay(() {
                                            gameRef.player.specialMeter = 100.0;
                                          });
                                        },
                                        child: const Text(
                                          "RECARREGAR ESPECIAL",
                                          style: TextStyle(color: Colors.white),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  TextButton(
                                    onPressed: () {
                                      gameRef.overlays.remove('CheatMenu');
                                      gameRef.resumeEngine();
                                    },
                                    child: const Text(
                                      "VOLTAR AO JOGO",
                                      style: TextStyle(
                                        color: Colors.yellowAccent,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                },
              ),
            ),

          // TELA DO MENU (DESLIZANDO COM CONTROLLER)
          SlideTransition(
            position: _slideAnimation,
            child: Container(
              width: screenWidth,
              height: screenHeight,
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/images/background_menu.png'),
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.none,
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(
                    top: screenHeight * 0.15,
                    child: SizedBox(
                      width: 400,
                      height: 150,
                      child: Image.asset(
                        'assets/images/titulo.png',
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.none,
                      ),
                    ),
                  ),
                  Positioned(
                    top: screenHeight * 0.55,
                    child: SizedBox(
                      width: 200,
                      height: 60,
                      child: ElevatedButton(
                        onPressed: _iniciarJogo,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[700],
                          foregroundColor: Colors.white,
                          elevation: 5,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'PLAY',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: (screenHeight * 0.55) + 60 + 15,
                    child: SizedBox(
                      width: 200,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _mostrarConfiguracoes = true;
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[800],
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'CONFIGURAÇÕES',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (_mostrarConfiguracoes && !_jogoIniciado)
            SettingsOverlay(
              onClose: () {
                setState(() => _mostrarConfiguracoes = false);
              },
              onRemap: () {
                setState(() {
                  _mostrarConfiguracoes = false;
                  _iniciarJogoEmModoRemap();
                });
              },
            ),
        ],
      ),
    );
  }
}

// ==========================================
// OVERLAY DO REMAPEAMENTO
// ==========================================
class RemapOverlay extends StatelessWidget {
  final MyPixelGame gameRef;

  const RemapOverlay({Key? key, required this.gameRef}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Stack(
        children: [
          const Center(
            child: Text(
              "MODO EDIÇÃO",
              style: TextStyle(
                color: Colors.white54,
                fontSize: 40,
                fontWeight: FontWeight.bold,
                letterSpacing: 10,
              ),
            ),
          ),
          Positioned(
            top: 20,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[800],
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                  icon: const Icon(Icons.restore, color: Colors.white),
                  label: const Text(
                    'PADRÃO',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onPressed: () {
                    HudConfig.resetToDefault();
                    gameRef.joystick.position = HudConfig.joystickPos.clone();
                    final botoes = gameRef.camera.viewport.children
                        .whereType<RemappableButton>();
                    for (var botao in botoes) {
                      if (botao.debugColor == Colors.red)
                        botao.position = HudConfig.attackBtnPos.clone();
                      else if (botao.debugColor == Colors.green)
                        botao.position = HudConfig.jumpBtnPos.clone();
                      else if (botao.debugColor == Colors.yellow)
                        botao.position = HudConfig.dashBtnPos.clone();
                      else if (botao.debugColor == Colors.blue)
                        botao.position = HudConfig.parryBtnPos.clone();
                      else if (botao.debugColor == Colors.purple)
                        botao.position = HudConfig.specialBtnPos.clone();
                    }
                  },
                ),
                const SizedBox(width: 40),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                  icon: const Icon(Icons.check, color: Colors.white),
                  label: const Text(
                    'APLICAR E VOLTAR',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onPressed: () {
                    HudConfig.joystickPos = gameRef.joystick.position.clone();
                    final botoes = gameRef.camera.viewport.children
                        .whereType<RemappableButton>();
                    for (var botao in botoes) {
                      if (botao.debugColor == Colors.red)
                        HudConfig.attackBtnPos = botao.position.clone();
                      else if (botao.debugColor == Colors.green)
                        HudConfig.jumpBtnPos = botao.position.clone();
                      else if (botao.debugColor == Colors.yellow)
                        HudConfig.dashBtnPos = botao.position.clone();
                      else if (botao.debugColor == Colors.blue)
                        HudConfig.parryBtnPos = botao.position.clone();
                      else if (botao.debugColor == Colors.purple)
                        HudConfig.specialBtnPos = botao.position.clone();
                    }

                    gameRef.isEditingHUD = false;
                    gameRef.overlays.remove('RemapHUD');

                    if (gameRef.startInRemapMode) {
                      FlameAudio.bgm.stop();
                      gameRef.onBackToMenu?.call();
                    } else {
                      gameRef.pauseEngine();
                      gameRef.overlays.add('SettingsMenu');
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class GameOverOverlay extends StatefulWidget {
  final MyPixelGame gameRef;
  const GameOverOverlay({Key? key, required this.gameRef}) : super(key: key);
  @override
  State<GameOverOverlay> createState() => _GameOverOverlayState();
}

class _GameOverOverlayState extends State<GameOverOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideFundo;
  late Animation<double> _scaleQuadrado;
  late Animation<double> _scaleTitulo;
  late Animation<double> _scaleBtn1;
  late Animation<double> _scaleBtn2;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _slideFundo = Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.0, 0.4, curve: Curves.easeOutCubic),
          ),
        );
    _scaleQuadrado = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.4, 0.6, curve: Curves.easeOutBack),
    );
    _scaleTitulo = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.6, 0.75, curve: Curves.easeOutBack),
    );
    _scaleBtn1 = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.75, 0.85, curve: Curves.easeOutBack),
    );
    _scaleBtn2 = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.85, 1.0, curve: Curves.easeOutBack),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideFundo,
      child: Container(
        color: Colors.red.withOpacity(0.8),
        child: Center(
          child: ScaleTransition(
            scale: _scaleQuadrado,
            child: Container(
              width: 380,
              height: 320,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.85),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.redAccent, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.8),
                    blurRadius: 15,
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ScaleTransition(
                    scale: _scaleTitulo,
                    child: const Text(
                      'GAME OVER',
                      style: TextStyle(
                        fontSize: 50,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 4,
                        shadows: [Shadow(color: Colors.red, blurRadius: 10)],
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  ScaleTransition(
                    scale: _scaleBtn1,
                    child: SizedBox(
                      width: 250,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.red,
                          elevation: 5,
                        ),
                        onPressed: () {
                          widget.gameRef.overlays.remove('GameOver');
                          widget.gameRef.resetGame();
                          FlameAudio.bgm.play(
                            'musica_padrao.mp3',
                            volume: AudioManager.bgm,
                          );
                        },
                        child: const Text(
                          'RECOMEÇAR',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  ScaleTransition(
                    scale: _scaleBtn2,
                    child: SizedBox(
                      width: 250,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[900],
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () {
                          widget.gameRef.overlays.remove('GameOver');
                          widget.gameRef.resetGame();
                          FlameAudio.bgm.stop();
                          widget.gameRef.onBackToMenu?.call();
                        },
                        child: const Text(
                          'VOLTAR PARA O MENU',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
