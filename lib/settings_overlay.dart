import 'dart:async'; // Necessário para escutar o gamepad no menu
import 'package:flutter/material.dart';
import 'package:gamepads/gamepads.dart'; // Lendo direto do pacote novo!
import 'package:flame_audio/flame_audio.dart';
import 'my_game.dart';

// ==========================================
// CONFIGURAÇÕES DE ÁUDIO
// ==========================================
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

// ==========================================
// MEMÓRIA DOS BOTÕES FÍSICOS (AGORA 100% GAMEPAD)
// ==========================================
class ControllerConfig {
  // Salvamos como String (o ID puro do botão vindo do gamepad)
  static String attackKey = 'button.x';
  static String jumpKey = 'button.a';
  static String dashKey = 'button.b';
  static String parryKey = 'button.y';
  static String specialKey = 'button.r1';
}

// ==========================================
// TELA DE CONFIGURAÇÕES
// ==========================================
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
  bool _isClosing = false;

  String _acaoEsperandoBotao = "";
  StreamSubscription<GamepadEvent>? _mappingSub; // Escutador do Gamepad

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
    _mappingSub?.cancel(); // Para de escutar quando fecha
    await _controller.reverse();
    widget.onClose();
  }

  void _acionarRemapeamentoHUD() {
    if (_isClosing) return;
    _isClosing = true;
    _mappingSub?.cancel();
    widget.onRemap();
  }

  @override
  void dispose() {
    _mappingSub?.cancel();
    _controller.dispose();
    super.dispose();
  }

  // --- Função que escuta o Gamepad Diretamente ---
  void _iniciarEscutaBotao(String acao) {
    setState(() {
      _acaoEsperandoBotao = acao;
    });

    _mappingSub?.cancel(); // Cancela escutas anteriores
    _mappingSub = Gamepads.events.listen((GamepadEvent event) {
      // Captura apenas quando o botão é pressionado (value > 0)
      if (event.type == KeyType.button && event.value > 0) {
        setState(() {
          if (_acaoEsperandoBotao == "Ataque")
            ControllerConfig.attackKey = event.key;
          if (_acaoEsperandoBotao == "Pulo")
            ControllerConfig.jumpKey = event.key;
          if (_acaoEsperandoBotao == "Dash")
            ControllerConfig.dashKey = event.key;
          if (_acaoEsperandoBotao == "Defesa")
            ControllerConfig.parryKey = event.key;
          if (_acaoEsperandoBotao == "Especial")
            ControllerConfig.specialKey = event.key;

          _acaoEsperandoBotao = ""; // Finaliza a espera
        });
        _mappingSub
            ?.cancel(); // Para de escutar até o jogador clicar em outro mapeamento
      }
    });
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

  Widget _buildAba(
    String titulo,
    int indice, {
    bool isFirst = false,
    bool isLast = false,
  }) {
    bool isAtiva = _abaAtual == indice;
    return GestureDetector(
      onTap: () {
        setState(() {
          _abaAtual = indice;
          _acaoEsperandoBotao = "";
          _mappingSub?.cancel();
        });
      },
      child: Container(
        height: 45, // Altura fixa para as abas
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isAtiva ? Colors.grey[900] : Colors.grey[800],
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(isFirst ? 12 : 0),
            topRight: Radius.circular(isLast ? 12 : 0),
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
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildLinhaMapeamentoFisico(
    String acao,
    String chaveAtual,
    IconData icone,
    Color cor,
  ) {
    bool escutando = _acaoEsperandoBotao == acao;

    // Limpa o nome do botão para ficar bonito na tela (ex: "button.a" vira "A")
    String nomeBotaoDisplay = chaveAtual
        .replaceAll('button.', '')
        .toUpperCase();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icone, color: cor, size: 28),
              const SizedBox(width: 10),
              Text(
                acao,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: escutando
                  ? Colors.yellowAccent
                  : Colors.grey[800],
              foregroundColor: escutando ? Colors.black : Colors.white,
              minimumSize: const Size(140, 40),
            ),
            onPressed: () => _iniciarEscutaBotao(acao),
            child: Text(
              escutando ? "Pressione..." : nomeBotaoDisplay,
              style: TextStyle(
                fontWeight: escutando ? FontWeight.w900 : FontWeight.bold,
              ),
            ),
          ),
        ],
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
                // ABAS SUPERIORES ALINHADAS COM O CONTAINER (Width: 500)
                SizedBox(
                  width: 500,
                  child: Row(
                    children: [
                      Expanded(child: _buildAba("🎵 ÁUDIO", 0, isFirst: true)),
                      Expanded(child: _buildAba("📱 HUD TELA", 1)),
                      Expanded(
                        child: _buildAba("🎮 CONTROLE", 2, isLast: true),
                      ),
                    ],
                  ),
                ),

                // CAIXA DE CONTEÚDO
                Container(
                  width: 500,
                  height: 360,
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
                        top: 5,
                        right: 5,
                        child: IconButton(
                          icon: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 30,
                          ),
                          onPressed: _fecharMenu,
                        ),
                      ),

                      // CONTEÚDO: ABA 0 (ÁUDIO)
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
                      // CONTEÚDO: ABA 1 (HUD TOUCH)
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
                                "Arraste os botões pela tela para\npersonalizar a HUD do celular.",
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
                                  onPressed: _acionarRemapeamentoHUD,
                                  child: const Text(
                                    'REMAPEAR TELA',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      // CONTEÚDO: ABA 2 (CONTROLE FÍSICO / BLUETOOTH) COM SCROLL
                      else if (_abaAtual == 2)
                        Padding(
                          padding: const EdgeInsets.only(top: 40, bottom: 10),
                          child: SingleChildScrollView(
                            // <-- Deixou a lista rolável para caber todos os botões!
                            child: Column(
                              children: [
                                _buildLinhaMapeamentoFisico(
                                  "Ataque",
                                  ControllerConfig.attackKey,
                                  Icons.sports_martial_arts,
                                  Colors.red,
                                ),
                                _buildLinhaMapeamentoFisico(
                                  "Pulo",
                                  ControllerConfig.jumpKey,
                                  Icons.arrow_upward,
                                  Colors.green,
                                ),
                                _buildLinhaMapeamentoFisico(
                                  "Dash",
                                  ControllerConfig.dashKey,
                                  Icons.fast_forward,
                                  Colors.yellow,
                                ),
                                _buildLinhaMapeamentoFisico(
                                  "Defesa",
                                  ControllerConfig.parryKey,
                                  Icons.shield,
                                  Colors.blue,
                                ),
                                _buildLinhaMapeamentoFisico(
                                  "Especial",
                                  ControllerConfig.specialKey,
                                  Icons.flash_on,
                                  Colors.purple,
                                ),
                              ],
                            ),
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
