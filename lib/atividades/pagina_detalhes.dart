import 'package:flutter/material.dart';
import 'atividade_card.dart';
import 'package:mare/env.dart';

class ActivityDetailsPage extends StatelessWidget {
  final Activity activity;

  const ActivityDetailsPage({
    super.key,
    required this.activity,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Um caminho para hoje'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(22),
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: MareColors.foam,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: const Color(0xFFC1D9DE),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: MareColors.mist,
                      borderRadius: BorderRadius.circular(26),
                    ),
                    child: Icon(
                      activity.icon,
                      size: 44,
                      color: MareColors.deep,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    activity.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: MareColors.deep,
                      fontSize: 25,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    activity.subtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: MareColors.deep,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    activity.description,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: MareColors.deep,
                      fontSize: 16,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Um começo possível',
              style: TextStyle(
                color: MareColors.deep,
                fontSize: 19,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              activity.suggestion,
              style: const TextStyle(
                color: MareColors.deep,
                fontSize: 16,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 26),
            SizedBox(
              height: 54,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: MareColors.deep,
                  foregroundColor: MareColors.foam,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text(
                  'Voltar aos caminhos',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
