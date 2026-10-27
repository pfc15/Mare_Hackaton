import 'package:flutter/material.dart';
import 'package:mare/jogo_copo/jogo_copo_3d.dart';

import 'package:flutter/material.dart';

class MareFeelingScale extends StatefulWidget {
  final ValueChanged<String>? onChanged;

  const MareFeelingScale({
    super.key,
    this.onChanged,
  });

  @override
  State<MareFeelingScale> createState() => _MareFeelingScaleState();
}

class _MareFeelingScaleState extends State<MareFeelingScale> {
  final TextEditingController controller = TextEditingController();
  final FocusNode focusNode = FocusNode();

  static const deep = Color(0xFF17323B);
  static const water = Color(0xFF3F9FB8);
  static const mist = Color(0xFFDCEBEE);
  static const foam = Color(0xFFF5FBFC);
  static const sand = Color(0xFFE7D3B0);

  @override
  void dispose() {
    controller.dispose();
    focusNode.dispose();
    super.dispose();
  }

  void onSelected() {
    Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const BalanceCup3DGame(),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: foam,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Cabeçalho
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: mist,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.waves_rounded,
                          color: water,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'maré',
                        style: TextStyle(
                          color: deep,
                          fontSize: 25,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 34),

                  const Text(
                    'O que está passando pela sua cabeça?',
                    style: TextStyle(
                      color: deep,
                      fontSize: 29,
                      height: 1.2,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 14),

                  Text(
                    'Se quiser, escreva como você está se sentindo '
                    'agora. Não precisa encontrar as palavras perfeitas.',
                    style: TextStyle(
                      color: deep.withValues(alpha: 0.8),
                      fontSize: 16,
                      height: 1.6,
                    ),
                  ),

                  const SizedBox(height: 26),

                  // Campo de texto grande
                  Container(
                    decoration: BoxDecoration(
                      color: mist,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: focusNode.hasFocus ? water : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      onChanged: widget.onChanged,
                      minLines: 8,
                      maxLines: 12,
                      maxLength: 1000,
                      keyboardType: TextInputType.multiline,
                      textCapitalization: TextCapitalization.sentences,
                      style: const TextStyle(
                        color: deep,
                        fontSize: 16,
                        height: 1.6,
                      ),
                      decoration: InputDecoration(
                        hintText:
                            'Estou sentindo...\n\n'
                            'O que está pesando para mim é...\n\n'
                            'Neste momento, eu preciso de...',
                        hintStyle: TextStyle(
                          color: deep.withValues(alpha: 0.55),
                          fontSize: 15,
                          height: 1.6,
                        ),
                        contentPadding: const EdgeInsets.all(20),
                        border: InputBorder.none,
                        counterStyle: TextStyle(
                          color: deep.withValues(alpha: 0.65),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  const SizedBox(height: 24),

                  // Botão de ação
                  SizedBox(
                    height: 54,
                    child: ElevatedButton(
                      onPressed: () {
                        FocusScope.of(context).unfocus();
                        widget.onChanged?.call(controller.text);
                        onSelected();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: deep,
                        foregroundColor: foam,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: const Text(
                        'Continuar',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  Text(
                    'O que você escrever é uma forma de observar '
                    'como está se sentindo, sem julgamentos.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: deep.withValues(alpha: 0.65),
                      fontSize: 12,
                      height: 1.5,
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
