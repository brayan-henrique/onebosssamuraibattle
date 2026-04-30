import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'menu_screen.dart'; // Importa a tela do menu que criamos

void main() async {
  // 1. Garante que os plugins nativos do Flutter/Android estejam prontos
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Coloca o jogo em modo imersivo (esconde a barra de notificações e botões do Android)
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  // 3. Trava a orientação na horizontal para garantir a experiência do jogo
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // 4. Inicia o aplicativo chamando APENAS o MenuScreen como tela principal
  runApp(
    const MaterialApp(
      home: MenuScreen(),
      debugShowCheckedModeBanner: false, // Remove a faixa de "DEBUG" da tela
    ),
  );
}
