import 'package:flutter/material.dart';
import 'package:mare/jogo_copo/jogo_copo_3d.dart';
import 'package:mare/atividades/atividades.dart';
import 'package:mare/env.dart';
import 'package:mare/perguntas/perguntas.dart';



void main() => runApp(const MaterialApp(home: MareFeelingScale()));


class MareApp extends StatelessWidget {
  const MareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Maré',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: MareColors.mist,
        colorScheme: ColorScheme.fromSeed(
          seedColor: MareColors.water,
          primary: MareColors.deep,
          surface: MareColors.foam,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: MareColors.mist,
          foregroundColor: MareColors.deep,
          elevation: 0,
          centerTitle: false,
        ),
      ),
      home: const ActivitiesPage(),
      // home: const MareFeelingScale(),
    );
  }
}

