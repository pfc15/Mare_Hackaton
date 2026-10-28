import 'package:flutter/material.dart';
import 'package:mare/env.dart';
import 'package:mare/jogo_copo/jogo_copo_3d.dart';


class Activity {
  final IconData icon;
  final String title;
  final String subtitle;
  final String description;
  final String suggestion;
  final void Function(BuildContext context ) onSugestion;

  const Activity({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.suggestion,
    required this.onSugestion
  });
}

class ActivityCard extends StatelessWidget {
  final Activity activity;
  final VoidCallback onTap;

  const ActivityCard({
    super.key,
    required this.activity,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      color: MareColors.foam,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(
          color: Color(0xFFC1D9DE),
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: MareColors.mist,
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: Icon(
                  activity.icon,
                  size: 28,
                  color: MareColors.deep,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activity.title,
                      style: const TextStyle(
                        color: MareColors.deep,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      activity.subtitle,
                      style: const TextStyle(
                        color: MareColors.deep,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      activity.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: MareColors.deep,
                        fontSize: 14,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right_rounded,
                color: MareColors.deep,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void fazNada(BuildContext context){
  return;
}

void vaiParaJogo(BuildContext context) {
  Navigator.push(context, MaterialPageRoute(builder: (context) => const BalanceCup3DGame(),));
}

const activities = [
  Activity(
    icon: Icons.directions_walk_rounded,
    title: 'Dar uma caminhada',
    subtitle: 'Movimento e ar livre',
    description:
        'Faça uma caminhada tranquila, no seu ritmo, '
        'e observe o que existe ao seu redor.'
        'Faça uma caminhada tranquila, no seu ritmo, '
        'e observe o que existe ao seu redor.'
        'Faça uma caminhada tranquila, no seu ritmo, '
        'e observe o que existe ao seu redor.'
        'Faça uma caminhada tranquila, no seu ritmo, '
        'e observe o que existe ao seu redor.'
        'Faça uma caminhada tranquila, no seu ritmo, '
        'e observe o que existe ao seu redor.',
    suggestion: 'Que tal caminhar por 10 minutos?',
    onSugestion: vaiParaJogo
  ),
  Activity(
    icon: Icons.menu_book_rounded,
    title: 'Ler algumas páginas',
    subtitle: 'Um momento de pausa',
    description:
        'Escolha um livro, uma revista ou um texto '
        'que desperte sua curiosidade.',
    suggestion: 'Escolha algo que você goste de ler.',
    onSugestion: fazNada
  ),
  Activity(
    icon: Icons.chat_bubble_outline_rounded,
    title: 'Conversar com alguém',
    subtitle: 'Conexão e companhia',
    description:
        'Mande uma mensagem para alguém de confiança '
        'ou retome contato com uma pessoa querida.',
    suggestion: 'Uma conversa simples já é um começo.',
    onSugestion: fazNada
  ),
  Activity(
    icon: Icons.spa_outlined,
    title: 'Fazer uma pausa',
    subtitle: 'Respirar com tranquilidade',
    description:
        'Encontre uma posição confortável e reserve '
        'alguns minutos para respirar naturalmente.',
    suggestion: 'Comece com dois minutos de pausa.',
    onSugestion: fazNada
  ),
  Activity(
    icon: Icons.brush_outlined,
    title: 'Criar alguma coisa',
    subtitle: 'Expressão e criatividade',
    description:
        'Desenhe, escreva, cuide de uma planta ou '
        'experimente uma atividade manual.',
    suggestion: 'Não precisa ficar perfeito.',
    onSugestion: fazNada
  ),
  Activity(
    icon: Icons.park_outlined,
    title: 'Estar ao ar livre',
    subtitle: 'Um tempo para você',
    description:
        'Se for possível, passe um tempo em uma praça, '
        'na varanda ou em outro lugar agradável.',
    suggestion: 'Escolha um lugar em que se sinta bem.',
    onSugestion: fazNada
  ),
];
