import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// Jogo: equilibre o copo para a água não cair.
/// Incline o celular para girar o copo e compensar o desequilíbrio.
/// A cada 10 segundos o nível sobe e fica mais difícil.
class BalanceCupGame extends StatefulWidget {
  const BalanceCupGame({super.key});

  @override
  State<BalanceCupGame> createState() => _BalanceCupGameState();
}

enum _GameState { ready, playing, over }

class _Drop {
  _Drop(this.x, this.y, this.vx, this.vy, this.r);
  double x, y, vx, vy, r;
}

// Geometria do copo em unidades normalizadas (largura do topo = 1).
const double _cupH = 1.25;
const double _topHalf = 0.5;
const double _botHalf = 0.38;
const double _startFill = 0.85;
const double _loseFill = 0.30;
const Color _waterColor = Color(0xFF4FC3F7);

class _BalanceCupGameState extends State<BalanceCupGame>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final math.Random _rng = math.Random();

  // ---- Sensores ----
  StreamSubscription<AccelerometerEvent>? _accSub;
  StreamSubscription<GyroscopeEvent>? _gyroSub;
  final Stopwatch _clock = Stopwatch()..start();
  int _lastGyroUs = 0;
  int _lastGyroEventUs = -1000000;
  double _accAngle = 0; // ângulo (rad) estimado pelo acelerômetro
  double _phoneAngle = 0; // ângulo filtrado (giroscópio + acelerômetro)
  double _zero = 0; // calibração no início da partida
  bool _hasSensor = false;
  double _dragAngle = 0; // fallback por toque (emulador/desktop)

  // ---- Estado do jogo ----
  Duration _last = Duration.zero;
  _GameState _state = _GameState.ready;
  double _time = 0;
  int _level = 1;
  double _best = 0;
  double _fill = _startFill;
  double _cupAngle = 0;
  double _rel = 0; // inclinação do copo relativa à superfície da água
  double _omega = 0;
  double _slosh = 0, _sloshV = 0;
  double _gust = 0, _gustTimer = 3;
  double _p1 = 0, _p2 = 0;
  double _flash = 0;
  double _hapticTimer = 0;
  double _dropAcc = 0;
  final List<_Drop> _drops = [];

  // ---- Layout ----
  Offset _center = Offset.zero;
  double _scale = 150;
  double _height = 800;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _ticker = createTicker(_tick)..start();
    _startSensors();
  }

  void _startSensors() {
    try {
      _accSub = accelerometerEventStream(
        samplingPeriod: SensorInterval.gameInterval,
      ).listen(_onAcc, onError: (_) {});
      _gyroSub = gyroscopeEventStream(
        samplingPeriod: SensorInterval.gameInterval,
      ).listen(_onGyro, onError: (_) {});
    } catch (_) {
      // Sem sensores: o jogo cai para o controle por arrastar o dedo.
    }
  }

  // Acelerômetro: dá o ângulo absoluto (sem drift, porém ruidoso).
  void _onAcc(AccelerometerEvent e) {
    if (e.x == 0 && e.y == 0) return;
    // Rolagem no plano da tela; positivo = sentido horário.
    _accAngle = math.atan2(-e.x, e.y);
    if (!_hasSensor) {
      _hasSensor = true;
      _phoneAngle = _accAngle;
    }
    final gyroActive =
        (_clock.elapsedMicroseconds - _lastGyroEventUs) < 200000;
    if (!gyroActive) {
      // Dispositivo sem giroscópio: usa só o acelerômetro suavizado.
      _phoneAngle += (_accAngle - _phoneAngle) * 0.25;
    }
  }

  // Giroscópio: velocidade angular (rápido e suave, mas com drift).
  // Filtro complementar: integra o giroscópio e corrige com o acelerômetro.
  void _onGyro(GyroscopeEvent e) {
    final now = _clock.elapsedMicroseconds;
    final dt = ((now - _lastGyroUs) / 1e6).clamp(0.0, 0.1).toDouble();
    _lastGyroUs = now;
    _lastGyroEventUs = now;
    if (!_hasSensor) return;
    // gyro.z > 0 = anti-horário, então invertemos para horário positivo.
    final integrated = _phoneAngle + (-e.z) * dt;
    const alpha = 0.97;
    _phoneAngle = alpha * integrated + (1 - alpha) * _accAngle;
  }

  void _startGame() {
    setState(() {
      _state = _GameState.playing;
      _time = 0;
      _level = 1;
      _fill = _startFill;
      _cupAngle = 0;
      _rel = 0;
      _omega = 0;
      _slosh = 0;
      _sloshV = 0;
      _gust = 0;
      _gustTimer = 3;
      _p1 = _rng.nextDouble() * math.pi * 2;
      _p2 = _rng.nextDouble() * math.pi * 2;
      _dropAcc = 0;
      _dragAngle = 0;
      _drops.clear();
      _zero = _phoneAngle; // calibra: a posição atual do celular vira o "zero"
      _flash = 1.2;
    });
  }

  void _tick(Duration elapsed) {
    final dt =
        ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.05).toDouble();
    _last = elapsed;
    if (_state == _GameState.playing) {
      _update(dt);
    } else if (_state == _GameState.ready) {
      _cupAngle += (0 - _cupAngle) * math.min(1.0, dt * 6);
      _rel = _cupAngle;
    }
    _updateDrops(dt);
    if (_flash > 0) _flash = math.max(0, _flash - dt);
    if (mounted) setState(() {});
  }

  void _update(double dt) {
    if (dt <= 0) return;
    _time += dt;

    // Dificuldade progressiva
    final newLevel = 1 + _time ~/ 10;
    if (newLevel != _level) {
      _level = newLevel;
      _flash = 1.4;
      HapticFeedback.mediumImpact();
    }
    final lv = _level.toDouble();
    final amp = math.min(0.75, 0.10 + 0.045 * lv); // amplitude do desequilíbrio
    final f1 = 0.55 + 0.08 * lv;
    final f2 = 1.30 + 0.15 * lv;

    // "Rajadas" aleatórias que empurram o copo de repente
    _gust *= math.exp(-1.6 * dt);
    _gustTimer -= dt;
    if (_gustTimer <= 0) {
      _gust += (_rng.nextBool() ? 1 : -1) * (0.12 + 0.025 * lv);
      _gustTimer = (2.5 + _rng.nextDouble() * 2.5) / (1 + 0.08 * lv);
    }

    final grace = math.min(1.0, _time / 2.0); // 2s de aquecimento
    final disturbance = grace *
            amp *
            (0.6 * math.sin(f1 * _time + _p1) +
                0.4 * math.sin(f2 * _time + _p2)) +
        _gust * grace;

    final phone = (_hasSensor ? _phoneAngle - _zero : _dragAngle)
        .clamp(-1.0, 1.0)
        .toDouble();

    // O copo gira junto com o celular; o desequilíbrio é somado a isso.
    final target = disturbance + phone;
    final newAngle =
        _cupAngle + (target - _cupAngle) * math.min(1.0, dt * 16);
    final omega = (newAngle - _cupAngle) / dt;
    final domega = (omega - _omega).clamp(-30.0, 30.0).toDouble();
    _omega = omega;
    _cupAngle = newAngle.clamp(-1.3, 1.3).toDouble();

    // Balanço da água (mola amortecida)
    _sloshV += (-30 * _slosh - 3.5 * _sloshV) * dt - domega * 0.04;
    _sloshV = _sloshV.clamp(-6.0, 6.0).toDouble();
    _slosh = (_slosh + _sloshV * dt).clamp(-0.5, 0.5).toDouble();
    _rel = _cupAngle - _slosh;

    // Transbordo: depende da inclinação e do espaço livre no topo do copo
    final overflow =
        _topHalf * math.tan(_rel.abs().clamp(0.0, 1.4).toDouble()) -
            _cupH * (1 - _fill);
    if (overflow > 0) {
      _fill -= overflow * (0.7 + 0.06 * lv) * dt;
      _dropAcc += overflow * 120 * dt;
      while (_dropAcc >= 1 && _drops.length < 220) {
        _dropAcc -= 1;
        _spawnDrop(_rel.sign);
      }
      _hapticTimer -= dt;
      if (_hapticTimer <= 0) {
        HapticFeedback.selectionClick();
        _hapticTimer = 0.25;
      }
    } else {
      _dropAcc = 0;
    }

    if (_fill <= _loseFill) {
      _fill = _loseFill;
      _state = _GameState.over;
      _best = math.max(_best, _time);
      HapticFeedback.heavyImpact();
    }
  }

  void _spawnDrop(double sign) {
    // Borda do copo do lado que está mais baixo, em coordenadas de tela
    final lx = sign * _topHalf * _scale;
    final ly = -_cupH / 2 * _scale;
    final c = math.cos(_cupAngle), s = math.sin(_cupAngle);
    final wx = _center.dx + lx * c - ly * s;
    final wy = _center.dy + lx * s + ly * c;
    _drops.add(_Drop(
      wx + (_rng.nextDouble() - 0.5) * 6,
      wy,
      sign * (40 + _rng.nextDouble() * 90),
      _rng.nextDouble() * 40,
      2.5 + _rng.nextDouble() * 3,
    ));
  }

  void _updateDrops(double dt) {
    for (final d in _drops) {
      d.vy += 1100 * dt;
      d.x += d.vx * dt;
      d.y += d.vy * dt;
    }
    _drops.removeWhere((d) => d.y > _height + 20);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _accSub?.cancel();
    _gyroSub?.cancel();
    SystemChrome.setPreferredOrientations([]);
    super.dispose();
  }

  String _fmt(double t) => '${t.toStringAsFixed(1)}s';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF14213D),
      body: LayoutBuilder(builder: (context, c) {
        _height = c.maxHeight;
        _center = Offset(c.maxWidth / 2, c.maxHeight * 0.52);
        _scale = (c.maxWidth * 0.38).clamp(110.0, 220.0).toDouble();

        final waterLeft = ((_fill - _loseFill) / (_startFill - _loseFill))
            .clamp(0.0, 1.0)
            .toDouble();

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragUpdate: (d) {
            if (!_hasSensor) {
              _dragAngle =
                  (_dragAngle + d.delta.dx * 0.004).clamp(-1.0, 1.0).toDouble();
            }
          },
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _CupPainter(
                    center: _center,
                    scale: _scale,
                    angle: _cupAngle,
                    rel: _rel,
                    fill: _fill,
                    drops: _drops,
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _hud('NÍVEL', '$_level'),
                          _hud('TEMPO', _fmt(_time)),
                          _hud('RECORDE', _fmt(_best)),
                        ],
                      ),
                      const SizedBox(height: 14),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: waterLeft,
                          minHeight: 10,
                          backgroundColor: Colors.white12,
                          color: waterLeft > 0.35
                              ? _waterColor
                              : Colors.redAccent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_state == _GameState.playing && _flash > 0)
                Center(
                  child: Opacity(
                    opacity: math.min(1.0, _flash),
                    child: Text(
                      'NÍVEL $_level',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 44,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ),
              if (_state != _GameState.playing) _overlay(),
            ],
          ),
        );
      }),
    );
  }

  Widget _hud(String label, String value) => Column(
        children: [
          Text(label,
              style: const TextStyle(
                  color: Colors.white54, fontSize: 11, letterSpacing: 1.5)),
          const SizedBox(height: 2),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700)),
        ],
      );

  Widget _overlay() {
    final over = _state == _GameState.over;
    return Positioned.fill(
      child: Container(
        color: Colors.black54,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              over ? 'Derramou tudo!' : 'Equilibre o Copo',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Text(
              over
                  ? 'Você aguentou ${_fmt(_time)} e chegou ao nível $_level.'
                  : 'Incline o celular para girar o copo e compensar o '
                      'desequilíbrio. Segure o celular numa posição '
                      'confortável: ela será o ponto zero.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
            if (!_hasSensor) ...[
              const SizedBox(height: 8),
              const Text(
                'Sensores indisponíveis: arraste o dedo na horizontal.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.amberAccent, fontSize: 13),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _startGame,
              style: FilledButton.styleFrom(
                backgroundColor: _waterColor,
                foregroundColor: Colors.black,
                padding:
                    const EdgeInsets.symmetric(horizontal: 36, vertical: 14),
              ),
              child: Text(over ? 'Jogar de novo' : 'Começar',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}

class _CupPainter extends CustomPainter {
  _CupPainter({
    required this.center,
    required this.scale,
    required this.angle,
    required this.rel,
    required this.fill,
    required this.drops,
  });

  final Offset center;
  final double scale;
  final double angle; // rotação do copo na tela
  final double rel; // inclinação da superfície da água dentro do copo
  final double fill;
  final List<_Drop> drops;

  @override
  void paint(Canvas canvas, Size size) {
    // Fundo
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF14213D), Color(0xFF0B132B)],
        ).createShader(Offset.zero & size),
    );

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    canvas.scale(scale);

    final cup = Path()
      ..moveTo(-_topHalf, -_cupH / 2)
      ..lineTo(_topHalf, -_cupH / 2)
      ..lineTo(_botHalf, _cupH / 2)
      ..lineTo(-_botHalf, _cupH / 2)
      ..close();

    // Alça
    canvas.drawArc(
      Rect.fromCenter(center: const Offset(0.46, -0.02), width: 0.55, height: 0.5),
      -math.pi / 2,
      math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.06
        ..color = Colors.white.withAlpha(150),
    );

    // Vidro
    canvas.drawPath(cup, Paint()..color = Colors.white.withAlpha(25));

    // Água (superfície sempre horizontal no mundo => inclinada no copo)
    canvas.save();
    canvas.clipPath(cup);
    final ySurface = -_cupH / 2 + _cupH * (1 - fill);
    final t = math.tan(rel.clamp(-1.4, 1.4).toDouble());
    const big = 2.0;
    final water = Path()
      ..moveTo(-big, ySurface + big * t)
      ..lineTo(big, ySurface - big * t)
      ..lineTo(big, big)
      ..lineTo(-big, big)
      ..close();
    canvas.drawPath(water, Paint()..color = _waterColor.withAlpha(215));
    canvas.drawLine(
      Offset(-big, ySurface + big * t),
      Offset(big, ySurface - big * t),
      Paint()
        ..color = Colors.white.withAlpha(140)
        ..strokeWidth = 0.025,
    );
    canvas.restore();

    // Contorno e brilho
    canvas.drawPath(
      cup,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.04
        ..strokeJoin = StrokeJoin.round
        ..color = Colors.white.withAlpha(200),
    );
    canvas.drawLine(
      const Offset(-0.36, -0.5),
      const Offset(-0.29, 0.45),
      Paint()
        ..strokeWidth = 0.03
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withAlpha(90),
    );
    canvas.restore();

    // Gotas caindo
    final dropPaint = Paint()..color = _waterColor;
    for (final d in drops) {
      canvas.drawCircle(Offset(d.x, d.y), d.r, dropPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CupPainter old) => true;
}