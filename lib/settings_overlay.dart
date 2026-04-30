import 'package:flutter/material.dart';
import 'package:flame_audio/flame_audio.dart';
import 'my_game.dart';

class AudioManager {
  static double masterVolume = 1.0;
  static double musicVolume = 1.0;
  static double sfxVolume = 1.0;
  static double bossVolume = 1.0;

  static double get bgm => musicVolume * masterVolume * 0.1;
  static double get deathBgm => musicVolume * masterVolume * 1.0;
  static double get pulo => sfxVolume * masterVolume * 0.8;
  static double get passo => sfxVolume * masterVolume * 0.5;

  static void updateBgmVolume() {
    FlameAudio.bgm.audioPlayer?.setVolume(bgm);
  }
}

class SettingsOverlay extends StatefulWidget {
  final VoidCallback onClose;
  final VoidCallback onRemap;
  final MyPixelGame? gameRef;

  const SettingsOverlay({
    Key? key,
    required this.onClose,
    required this.onRemap,
    this.gameRef,
  }) : super(key: key);

  @override
  State<SettingsOverlay> createState() => _SettingsOverlayState();
}

class _SettingsOverlayState extends State<SettingsOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideFundo;
  late Animation<double> _scaleQuadrado;

  int _abaAtual = 0;
  bool _isClosing = false; // Trava para evitar cliques duplos

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _slideFundo = Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
          ),
        );

    _scaleQuadrado = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.4, 1.0, curve: Curves.easeOutBack),
    );

    _controller.forward();
  }

  void _fecharMenu() async {
    if (_isClosing) return;
    _isClosing = true;
    await _controller.reverse();
    widget.onClose();
  }

  void _acionarRemapeamento() {
    if (_isClosing) return;
    _isClosing = true;
    // Removido o 'await _controller.reverse()' para ir instantaneamente e não dar tempo de clicar no X
    widget.onRemap();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildSlider(
    String label,
    double value,
    ValueChanged<double> onChanged,
    Color cor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: cor,
            inactiveTrackColor: Colors.grey[800],
            thumbColor: Colors.white,
            overlayColor: cor.withOpacity(0.2),
            trackHeight: 8.0,
          ),
          child: Slider(value: value, min: 0.0, max: 1.0, onChanged: onChanged),
        ),
      ],
    );
  }

  Widget _buildAba(String titulo, int indice) {
    bool isAtiva = _abaAtual == indice;
    return GestureDetector(
      onTap: () => setState(() => _abaAtual = indice),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
        decoration: BoxDecoration(
          color: isAtiva ? Colors.grey[900] : Colors.grey[800],
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(12),
            topRight: Radius.circular(12),
          ),
          border: Border.all(
            color: isAtiva ? Colors.blueAccent : Colors.transparent,
            width: 2,
          ),
        ),
        child: Text(
          titulo,
          style: TextStyle(
            color: isAtiva ? Colors.white : Colors.grey,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideFundo,
      child: Container(
        color: Colors.black.withOpacity(0.7),
        child: Center(
          child: ScaleTransition(
            scale: _scaleQuadrado,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildAba("🎵 ÁUDIO", 0),
                    const SizedBox(width: 5),
                    _buildAba("🎮 CONTROLES", 1),
                  ],
                ),
                Container(
                  width: 480,
                  height: 340,
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                    border: Border.all(color: Colors.blueAccent, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.8),
                        blurRadius: 15,
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        top: 10,
                        right: 10,
                        child: IconButton(
                          icon: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 30,
                          ),
                          onPressed: _fecharMenu,
                        ),
                      ),
                      if (_abaAtual == 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 30),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildSlider(
                                "Volume Geral (Master)",
                                AudioManager.masterVolume,
                                (val) {
                                  setState(
                                    () => AudioManager.masterVolume = val,
                                  );
                                  AudioManager.updateBgmVolume();
                                },
                                Colors.white,
                              ),
                              _buildSlider("Música", AudioManager.musicVolume, (
                                val,
                              ) {
                                setState(() => AudioManager.musicVolume = val);
                                AudioManager.updateBgmVolume();
                              }, Colors.blue),
                              _buildSlider(
                                "Efeitos (Pulo, Ataque)",
                                AudioManager.sfxVolume,
                                (val) {
                                  setState(() => AudioManager.sfxVolume = val);
                                },
                                Colors.green,
                              ),
                              _buildSlider(
                                "Sons do Boss",
                                AudioManager.bossVolume,
                                (val) {
                                  setState(() => AudioManager.bossVolume = val);
                                },
                                Colors.red,
                              ),
                            ],
                          ),
                        )
                      else if (_abaAtual == 1)
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.touch_app,
                                size: 60,
                                color: Colors.blueAccent,
                              ),
                              const SizedBox(height: 20),
                              const Text(
                                "Arraste os botões pela tela para\npersonalizar o seu layout.",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 30),
                              SizedBox(
                                width: 250,
                                height: 50,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blueAccent,
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed:
                                      _acionarRemapeamento, // Agora é instantâneo!
                                  child: const Text(
                                    'REMAPEAR HUD',
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
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

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
                  onPressed: () {},
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
                    gameRef.isEditingHUD = false;
                    gameRef.overlays.remove('RemapHUD');

                    // Lógica para saber pra qual tela voltar
                    if (gameRef.startInRemapMode) {
                      FlameAudio.bgm.stop();
                      gameRef.onBackToMenu?.call(); // Volta para o Menu Inicial
                    } else {
                      gameRef
                          .pauseEngine(); // Pausa a engine de novo para segurança
                      gameRef.overlays.add(
                        'SettingsMenu',
                      ); // Volta para as Configurações
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
