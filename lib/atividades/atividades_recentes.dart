
import 'package:flutter/material.dart';
import 'package:mare/env.dart';
import 'package:mare/atividades/atividade_card.dart';

class RecentActivitiesCard extends StatelessWidget {
  final List<Activity> activities;

  const RecentActivitiesCard({
    super.key,
    required this.activities,
  });

  @override
  Widget build(BuildContext context) {
    final recent = activities.take(3).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: MareColors.foam,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFC1D9DE),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Seus últimos recursos',
            style: TextStyle(
              color: MareColors.deep,
              fontSize: 19,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Retome de onde quiser, no seu ritmo.',
            style: TextStyle(
              color: MareColors.deep.withValues(alpha: 0.75),
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),

          if (recent.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                vertical: 18,
                horizontal: 12,
              ),
              decoration: BoxDecoration(
                color: MareColors.mist,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Text(
                'As atividades que você utilizar '
                'aparecerão aqui.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: MareColors.deep,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: recent.map((activity) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                    ),
                    child: Material(
                      color: MareColors.mist,
                      borderRadius: BorderRadius.circular(18),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => {
                          activity.onSugestion(context)
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 14,
                            horizontal: 4,
                          ),
                          child: Column(
                            children: [
                              Icon(
                                activity.icon,
                                color: MareColors.deep,
                                size: 27,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                activity.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: MareColors.deep,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}
