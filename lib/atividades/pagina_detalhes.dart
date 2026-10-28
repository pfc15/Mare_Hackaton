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
  child: LayoutBuilder(
    builder: (context, constraints) {
      final screenWidth = MediaQuery.sizeOf(context).width;

      final titleSize =
          (screenWidth * 0.065).clamp(23.0, 30.0);
      final bodySize =
          (screenWidth * 0.043).clamp(15.0, 18.0);

      return SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: 22,
          vertical: 20,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: constraints.maxHeight - 40,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 480,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [

                  Text(
                    'Escolha um pequeno passo e siga no seu ritmo.',
                    style: TextStyle(
                      color: MareColors.deep.withValues(
                        alpha: 0.8,
                      ),
                      fontSize: bodySize,
                      height: 1.5,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Cartão dinâmico da atividade
                  Material(
                    color: MareColors.foam,
                    borderRadius: BorderRadius.circular(28),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () =>
                          activity.onSugestion(context),
                      child: Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          borderRadius:
                              BorderRadius.circular(28),
                          border: Border.all(
                            color: const Color(0xFFC1D9DE),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.stretch,
                          children: [
                            // Ícone da atividade
                            Container(
                              width: 68,
                              height: 68,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: MareColors.mist,
                                borderRadius:
                                    BorderRadius.circular(22),
                              ),
                              child: Icon(
                                activity.icon,
                                size: 34,
                                color: MareColors.deep,
                              ),
                            ),

                            const SizedBox(height: 20),

                            // Título e subtítulo dinâmicos
                            Text(
                              activity.title,
                              style: TextStyle(
                                color: MareColors.deep,
                                fontSize: titleSize,
                                fontWeight: FontWeight.w800,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 8),

                            Text(
                              activity.subtitle,
                              style: TextStyle(
                                color: MareColors.water,
                                fontSize: bodySize,
                                fontWeight: FontWeight.w600,
                                height: 1.4,
                              ),
                            ),

                            const SizedBox(height: 22),
                            const Divider(
                              color: Color(0xFFDCEBEE),
                            ),
                            const SizedBox(height: 18),

                            // Descrição dinâmica
                            Text(
                              activity.description,
                              style: TextStyle(
                                color: MareColors.deep,
                                fontSize: bodySize,
                                height: 1.7,
                              ),
                            ),

                            const SizedBox(height: 24),

                            // Sugestão em destaque
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: MareColors.mist,
                                borderRadius:
                                    BorderRadius.circular(22),
                              ),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(
                                        Icons.spa_rounded,
                                        color: MareColors.deep,
                                        size: 23,
                                      ),
                                      SizedBox(width: 9),
                                      Expanded(
                                        child: Text(
                                          'Um começo possível',
                                          style: TextStyle(
                                            color: MareColors.deep,
                                            fontSize: 17,
                                            fontWeight:
                                                FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 13),
                                  Text(
                                    activity.suggestion,
                                    style: TextStyle(
                                      color: MareColors.deep,
                                      fontSize: bodySize,
                                      height: 1.65,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 18),

                            Text(
                              'Você pode fazer isso no seu próprio ritmo.',
                              style: TextStyle(
                                color: MareColors.deep.withValues(
                                  alpha: 0.7,
                                ),
                                fontSize: 13,
                                height: 1.5,
                                fontStyle: FontStyle.italic,
                              ),
                            ),

                            const SizedBox(height: 22),

                            // Ação principal
                            Container(
                              width: double.infinity,
                              padding:
                                  const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 16,
                              ),
                              decoration: BoxDecoration(
                                color: MareColors.deep,
                                borderRadius:
                                    BorderRadius.circular(18),
                              ),
                              child: const Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                children: [
                                  Flexible(
                                    child: Text(
                                      'Explorar esta atividade',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight:
                                            FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 10),
                                  Icon(
                                    Icons.arrow_forward_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 22),

                  // Rodapé da experiência
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.favorite_border_rounded,
                        size: 17,
                        color: MareColors.water,
                      ),
                      SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Sem cobrança. Um passo de cada vez.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: MareColors.deep,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  ),
),


);
  }
}
