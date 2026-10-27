
import 'package:flutter/material.dart';
import 'package:mare/env.dart';
import 'atividade_card.dart';
import 'pagina_detalhes.dart';



class ActivitiesPage extends StatelessWidget {
  const ActivitiesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(
              Icons.water,
              color: MareColors.water,
              size: 28,
            ),
            const SizedBox(width: 8),
            const Text(
              'maré',
              style: TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.8,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: MareColors.deep,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.waves_rounded,
                    color: MareColors.sand,
                    size: 30,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Um próximo passo, '
                    'no seu ritmo.',
                    style: TextStyle(
                      color: MareColors.foam,
                      fontSize: 25,
                      height: 1.2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Escolha algo simples para fazer '
                    'na vida real. Você não precisa '
                    'resolver tudo agora.',
                    style: TextStyle(
                      color: MareColors.foam.withAlpha(230),
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              'Caminhos para hoje',
              style: TextStyle(
                color: MareColors.deep,
                fontSize: 21,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Pequenas atividades, sem pressa.',
              style: TextStyle(
                color: MareColors.deep,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            ...activities.map(
              (activity) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: ActivityCard(
                  activity: activity,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ActivityDetailsPage(
                          activity: activity,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'O Maré é um apoio complementar '
              'e não substitui o acompanhamento '
              'de profissionais.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: MareColors.deep,
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}



