import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // <-- Necessário para capturar botões do controle/teclado
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
// MEMÓRIA DOS BOTÕES FÍSICOS (BLUETOOTH/TECLADO)
// ==========================================
class ControllerConfig {
  // Teclas padrão (Mapeamento comum de controles no Android/PC)
  static LogicalKeyboardKey attackKey =
      LogicalKeyboardKey.keyX; // Ex: Botão X / Quadrado
  static LogicalKeyboardKey jumpKey =
      LogicalKeyboardKey.space; // Ex: Botão A / X
  static LogicalKeyboardKey dashKey =
      LogicalKeyboardKey.keyC; // Ex: Botão B / Círculo
  static LogicalKeyboardKey parryKey =
      LogicalKeyboardKey.keyZ; // Ex: Botão Y / Triângulo ou L1
  static LogicalKeyboardKey specialKey = LogicalKeyboardKey.keyV; // Ex: R1 / RB
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

  // Variáveis para o Mapeamento Físico
  String _acaoEsperandoBotao =
      ""; // Guarda qual ação está esperando o jogador apertar um botão
  final FocusNode _focusNode =
      FocusNode(); // Foco para capturar o teclado/controle

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

  void _acionarRemapeamentoHUD() {
    if (_isClosing) return;
    _isClosing = true;
    widget.onRemap();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  // --- Função que escuta o Controle Físico ---
  void _iniciarEscutaBotao(String acao) {
    setState(() {
      _acaoEsperandoBotao = acao;
    });
    _focusNode
        .requestFocus(); // Puxa a atenção do celular para escutar o controle
  }

  // --- O que acontece quando o jogador aperta o botão físico ---
  void _aoApertarBotaoFisico(RawKeyEvent event) {
    if (event is RawKeyDownEvent && _acaoEsperandoBotao.isNotEmpty) {
      setState(() {
        // Salva a tecla apertada na configuração correta
        if (_acaoEsperandoBotao == "Ataque")
          ControllerConfig.attackKey = event.logicalKey;
        if (_acaoEsperandoBotao == "Pulo")
          ControllerConfig.jumpKey = event.logicalKey;
        if (_acaoEsperandoBotao == "Dash")
          ControllerConfig.dashKey = event.logicalKey;
        if (_acaoEsperandoBotao == "Defesa")
          ControllerConfig.parryKey = event.logicalKey;
        if (_acaoEsperandoBotao == "Especial")
          ControllerConfig.specialKey = event.logicalKey;

        // Finaliza a escuta
        _acaoEsperandoBotao = "";
      });
    }
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
      onTap: () {
        setState(() {
          _abaAtual = indice;
          _acaoEsperandoBotao = ""; // Cancela a escuta se trocar de aba
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
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
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildLinhaMapeamentoFisico(
    String acao,
    LogicalKeyboardKey chaveAtual,
    IconData icone,
    Color cor,
  ) {
    bool escutando = _acaoEsperandoBotao == acao;

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
              escutando
                  ? "Pressione..."
                  : chaveAtual.keyLabel.replaceAll(
                      'Key ',
                      '',
                    ), // Remove a palavra "Key" pra ficar mais limpo
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
    return RawKeyboardListener(
      focusNode: _focusNode,
      onKey:
          _aoApertarBotaoFisico, // Conecta a escuta global do teclado/controle aqui!
      autofocus: true,
      child: SlideTransition(
        position: _slideFundo,
        child: Container(
          color: Colors.black.withOpacity(0.7),
          child: Center(
            child: ScaleTransition(
              scale: _scaleQuadrado,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ABAS SUPERIORES
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildAba("🎵 ÁUDIO", 0),
                      const SizedBox(width: 5),
                      _buildAba("📱 HUD TELA", 1),
                      const SizedBox(width: 5),
                      _buildAba("🎮 CONTROLE", 2), // <-- NOVA ABA!
                    ],
                  ),

                  // CAIXA DE CONTEÚDO
                  Container(
                    width: 500, // Aumentei um pouquinho para caber as 3 abas
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
                                _buildSlider(
                                  "Música",
                                  AudioManager.musicVolume,
                                  (val) {
                                    setState(
                                      () => AudioManager.musicVolume = val,
                                    );
                                    AudioManager.updateBgmVolume();
                                  },
                                  Colors.blue,
                                ),
                                _buildSlider(
                                  "Efeitos (Pulo, Ataque)",
                                  AudioManager.sfxVolume,
                                  (val) {
                                    setState(
                                      () => AudioManager.sfxVolume = val,
                                    );
                                  },
                                  Colors.green,
                                ),
                                _buildSlider(
                                  "Sons do Boss",
                                  AudioManager.bossVolume,
                                  (val) {
                                    setState(
                                      () => AudioManager.bossVolume = val,
                                    );
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
                        // CONTEÚDO: ABA 2 (CONTROLE FÍSICO / BLUETOOTH)
                        else if (_abaAtual == 2)
                          Padding(
                            padding: const EdgeInsets.only(top: 35),
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
                      ],
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
