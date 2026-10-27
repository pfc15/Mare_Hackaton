import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// Jogo 3D "manual": o copo é uma malha de anéis 3D projetada em perspectiva
/// com CustomPainter (sem engine 3D).
///
/// Segure o celular deitado, como uma bandeja, e incline nos DOIS eixos
/// (esquerda/direita e frente/trás) para manter a água dentro do copo.
/// A cada 10 segundos o nível sobe e fica mais difícil.
class BalanceCup3DGame extends StatefulWidget {
  const BalanceCup3DGame({super.key});

  @override
  State<BalanceCup3DGame> createState() => _BalanceCup3DGameState();
}

// ---------------------------------------------------------------------------
// Constantes
// ---------------------------------------------------------------------------

// Mundo: x = direita, y = cima, z = para longe da câmera. Copo na origem.
const double _cupH = 1.25;
const double _rTop = 0.5;
const double _rBot = 0.38;
const double _startFill = 0.85;
const double _loseFill = 0.30;
const double _floorY = -1.7;
const double _gravity = 9.0;

// Câmera olhando de cima/frente para o copo.
const double _camTilt = 0.5; // rad
const double _camDist = 4.0;
final double _cc = math.cos(_camTilt);
final double _sn = math.sin(_camTilt);

// Se algum eixo ficar invertido no seu aparelho, troque o sinal (1 <-> -1).
const double _rollSign = 1;
const double _pitchSign = 1;

const Color _waterLight = Color(0xFF4FC3F7);
const Color _waterDark = Color(0xFF0277BD);

double _radiusAt(double y) => _rBot + (_rTop - _rBot) * (y + _cupH / 2) / _cupH;

// ---------------------------------------------------------------------------
// Tipos auxiliares
// ---------------------------------------------------------------------------

enum _GameState { ready, playing, over }

class _V3 {
  const _V3(this.x, this.y, this.z);
  final double x, y, z;
}

class _Drop {
  _Drop(this.x, this.y, this.z, this.vx, this.vy, this.vz, this.r);
  double x, y, z, vx, vy, vz, r;
}

class _Ripple {
  _Ripple(this.x, this.z);
  final double x, z;
  double t = 0;
}

/// Rotação do copo: primeiro inclina para +x (ângulo a), depois para +z (b).
class _Pose {
  _Pose(double a, double b)
      : ca = math.cos(a),
        sa = math.sin(a),
        cb = math.cos(b),
        sb = math.sin(b);
  final double ca, sa, cb, sb;

  _V3 apply(double x, double y, double z) {
    final x1 = x * ca + y * sa;
    final y1 = -x * sa + y * ca;
    return _V3(x1, y1 * cb - z * sb, y1 * sb + z * cb);
  }
}

// ---------------------------------------------------------------------------
// Estado do jogo
// ---------------------------------------------------------------------------

class _BalanceCup3DGameState extends State<BalanceCup3DGame>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final math.Random _rng = math.Random();

  // ---- Sensores ----
  StreamSubscription<AccelerometerEvent>? _accSub;
  StreamSubscription<GyroscopeEvent>? _gyroSub;
  final Stopwatch _clock = Stopwatch()..start();
  int _lastGyroUs = 0;
  int _lastGyroEventUs = -1000000;
  double _accRoll = 0, _accPitch = 0; // ângulos do acelerômetro
  double _roll = 0, _pitch = 0; // ângulos filtrados (giroscópio + acelerômetro)
  double _zeroRoll = 0, _zeroPitch = 0; // calibração
  bool _hasSensor = false;
  double _dragRoll = 0, _dragPitch = 0; // fallback por toque

  // ---- Jogo ----
  Duration _last = Duration.zero;
  _GameState _state = _GameState.ready;
  double _time = 0;
  int _level = 1;
  double _best = 0;
  double _fill = _startFill;
  final List<double> _ang = [0, 0]; // [a (para +x), b (para +z)]
  final List<double> _om = [0, 0];
  final List<double> _s = [0, 0]; // balanço da água
  final List<double> _sv = [0, 0];
  double _relA = 0, _relB = 0;
  double _gustA = 0, _gustB = 0, _gustTimer = 3;
  double _pa1 = 0, _pa2 = 0, _pb1 = 0, _pb2 = 0;
  double _flash = 0;
  double _hapticTimer = 0;
  double _dropAcc = 0;
  final List<_Drop> _drops = [];
  final List<_Ripple> _ripples = [];

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
      // Sem sensores: usa o arrastar do dedo.
    }
  }

  // Acelerômetro: ângulo absoluto (sem drift, mas ruidoso).
  void _onAcc(AccelerometerEvent e) {
    final g = math.sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
    if (g < 1) return; // queda livre / leitura inválida
    // roll  > 0: lado direito do celular desce
    // pitch > 0: borda de cima do celular desce
    _accRoll = _rollSign * math.atan2(-e.x, math.sqrt(e.y * e.y + e.z * e.z));
    _accPitch = _pitchSign * math.atan2(-e.y, e.z);
    if (!_hasSensor) {
      _hasSensor = true;
      _roll = _accRoll;
      _pitch = _accPitch;
    }
    final gyroActive =
        (_clock.elapsedMicroseconds - _lastGyroEventUs) < 200000;
    if (!gyroActive) {
      // Sem giroscópio: usa só o acelerômetro suavizado.
      _roll += (_accRoll - _roll) * 0.25;
      _pitch += (_accPitch - _pitch) * 0.25;
    }
  }

  // Giroscópio: velocidade angular (suave, mas com drift).
  // Filtro complementar: integra o giroscópio e corrige com o acelerômetro.
  void _onGyro(GyroscopeEvent e) {
    final now = _clock.elapsedMicroseconds;
    final dt = ((now - _lastGyroUs) / 1e6).clamp(0.0, 0.1).toDouble();
    _lastGyroUs = now;
    _lastGyroEventUs = now;
    if (!_hasSensor) return;
    const alpha = 0.97;
    final r = _roll + _rollSign * e.y * dt;
    final p = _pitch + _pitchSign * (-e.x) * dt;
    _roll = alpha * r + (1 - alpha) * _accRoll;
    _pitch = alpha * p + (1 - alpha) * _accPitch;
  }

  void _startGame() {
    setState(() {
      _state = _GameState.playing;
      _time = 0;
      _level = 1;
      _fill = _startFill;
      for (var i = 0; i < 2; i++) {
        _ang[i] = 0;
        _om[i] = 0;
        _s[i] = 0;
        _sv[i] = 0;
      }
      _relA = 0;
      _relB = 0;
      _gustA = 0;
      _gustB = 0;
      _gustTimer = 3;
      _pa1 = _rng.nextDouble() * math.pi * 2;
      _pa2 = _rng.nextDouble() * math.pi * 2;
      _pb1 = _rng.nextDouble() * math.pi * 2;
      _pb2 = _rng.nextDouble() * math.pi * 2;
      _dropAcc = 0;
      _dragRoll = 0;
      _dragPitch = 0;
      _drops.clear();
      _ripples.clear();
      _zeroRoll = _roll; // a posição atual do celular vira o "zero"
      _zeroPitch = _pitch;
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
      for (var i = 0; i < 2; i++) {
        _ang[i] += (0 - _ang[i]) * math.min(1.0, dt * 6);
      }
      _relA = _ang[0];
      _relB = _ang[1];
    }
    _updateParticles(dt);
    if (_flash > 0) _flash = math.max(0, _flash - dt);
    if (mounted) setState(() {});
  }

  void _update(double dt) {
    if (dt <= 0) return;
    _time += dt;

    // ---- Dificuldade progressiva ----
    final newLevel = 1 + _time ~/ 10;
    if (newLevel != _level) {
      _level = newLevel;
      _flash = 1.4;
      HapticFeedback.mediumImpact();
    }
    final lv = _level.toDouble();
    final amp = math.min(0.7, 0.09 + 0.04 * lv);
    // O segundo eixo (frente/trás) vai entrando aos poucos nos níveis iniciais.
    final mixB = math.min(1.0, 0.35 + 0.2 * (lv - 1));
    final f1 = 0.55 + 0.07 * lv;
    final f2 = 1.25 + 0.13 * lv;

    // ---- Rajadas em direção aleatória ----
    final decay = math.exp(-1.6 * dt);
    _gustA *= decay;
    _gustB *= decay;
    _gustTimer -= dt;
    if (_gustTimer <= 0) {
      final dir = _rng.nextDouble() * math.pi * 2;
      final mag = 0.12 + 0.022 * lv;
      _gustA += math.cos(dir) * mag;
      _gustB += math.sin(dir) * mag;
      _gustTimer = (2.5 + _rng.nextDouble() * 2.5) / (1 + 0.08 * lv);
    }

    final grace = math.min(1.0, _time / 2.0); // 2s de aquecimento
    final dA = grace *
        (amp *
                (0.6 * math.sin(f1 * _time + _pa1) +
                    0.4 * math.sin(f2 * _time + _pa2)) +
            _gustA);
    final dB = grace *
        (amp *
                mixB *
                (0.6 * math.sin(f1 * 0.83 * _time + _pb1) +
                    0.4 * math.sin(f2 * 1.17 * _time + _pb2)) +
            _gustB * mixB);

    final pr = (_hasSensor ? _roll - _zeroRoll : _dragRoll)
        .clamp(-1.0, 1.0)
        .toDouble();
    final pp = (_hasSensor ? _pitch - _zeroPitch : _dragPitch)
        .clamp(-1.0, 1.0)
        .toDouble();

    // O copo gira junto com o celular; o desequilíbrio é somado a isso.
    final target = [dA + pr, dB + pp];
    final k = math.min(1.0, dt * 16);
    for (var i = 0; i < 2; i++) {
      final na = _ang[i] + (target[i] - _ang[i]) * k;
      final om = (na - _ang[i]) / dt;
      final dom = (om - _om[i]).clamp(-30.0, 30.0).toDouble();
      _om[i] = om;
      _ang[i] = na.clamp(-1.2, 1.2).toDouble();
      // Balanço da água (mola amortecida)
      _sv[i] += (-30 * _s[i] - 3.5 * _sv[i]) * dt - dom * 0.04;
      _sv[i] = _sv[i].clamp(-6.0, 6.0).toDouble();
      _s[i] = (_s[i] + _sv[i] * dt).clamp(-0.5, 0.5).toDouble();
    }
    _relA = _ang[0] - _s[0];
    _relB = _ang[1] - _s[1];

    // ---- Transbordo ----
    final n = _waterNormal();
    final tilt = math.sqrt(n.x * n.x + n.z * n.z) / n.y;
    final overflow = _rTop * tilt - _cupH * (1 - _fill);
    if (overflow > 0) {
      _fill -= overflow * (0.7 + 0.06 * lv) * dt;
      _dropAcc += overflow * 120 * dt;
      while (_dropAcc >= 1 && _drops.length < 220) {
        _dropAcc -= 1;
        _spawnDrop(n.x, n.z);
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

  /// Normal do plano da água no referencial do copo.
  _V3 _waterNormal() {
    final cb = math.cos(_relB);
    final nx = -cb * math.sin(_relA);
    final ny = math.max(0.05, cb * math.cos(_relA));
    final nz = -math.sin(_relB);
    return _V3(nx, ny, nz);
  }

  void _spawnDrop(double nx, double nz) {
    final l = math.sqrt(nx * nx + nz * nz);
    if (l < 1e-6) return;
    // Ponto da borda onde a água está mais alta (é por onde ela escapa).
    final p = _Pose(_ang[0], _ang[1])
        .apply(-_rTop * nx / l, _cupH / 2, -_rTop * nz / l);
    final hl = math.sqrt(p.x * p.x + p.z * p.z);
    final dx = hl > 1e-6 ? p.x / hl : 0.0;
    final dz = hl > 1e-6 ? p.z / hl : 0.0;
    final sp = 0.3 + _rng.nextDouble() * 0.7;
    _drops.add(_Drop(
      p.x + (_rng.nextDouble() - 0.5) * 0.04,
      p.y,
      p.z + (_rng.nextDouble() - 0.5) * 0.04,
      dx * sp + (_rng.nextDouble() - 0.5) * 0.2,
      _rng.nextDouble() * 0.5,
      dz * sp + (_rng.nextDouble() - 0.5) * 0.2,
      0.025 + _rng.nextDouble() * 0.03, 
    ));
  }

  void _updateParticles(double dt) {
    for (final d in _drops) {
      d.vy -= _gravity * dt;
      d.x += d.vx * dt;
      d.y += d.vy * dt;
      d.z += d.vz * dt;
      if (d.y < _floorY && _ripples.length < 40) {
        _ripples.add(_Ripple(d.x, d.z));
      }
    }
    _drops.removeWhere((d) => d.y < _floorY);
    for (final r in _ripples) {
      r.t += dt * 1.8;
    }
    _ripples.removeWhere((r) => r.t >= 1);
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
        final center = Offset(c.maxWidth / 2, c.maxHeight * 0.46);
        final scale = (c.maxWidth * 0.42).clamp(120.0, 260.0).toDouble();

        final waterLeft = ((_fill - _loseFill) / (_startFill - _loseFill))
            .clamp(0.0, 1.0)
            .toDouble();

        // Nível de bolha: onde a água "quer" escapar e quão perto do limite.
        final n = _waterNormal();
        final thr = math.max(0.05, _cupH * (1 - _fill) / _rTop);
        final bubble = Offset(-n.x / n.y / thr, n.z / n.y / thr);

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanUpdate: (d) {
            if (!_hasSensor) {
              _dragRoll =
                  (_dragRoll + d.delta.dx * 0.004).clamp(-1.0, 1.0).toDouble();
              _dragPitch =
                  (_dragPitch + d.delta.dy * 0.004).clamp(-1.0, 1.0).toDouble();
            }
          },
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _CupPainter(
                    center: center,
                    scale: scale,
                    a: _ang[0],
                    b: _ang[1],
                    relA: _relA,
                    relB: _relB,
                    fill: _fill,
                    drops: _drops,
                    ripples: _ripples,
                    bubble: bubble,
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
                              ? _waterLight
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
              over ? 'Derramou tudo!' : 'Equilibre o Copo 3D',
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
                  : 'Segure o celular deitado, como uma bandeja, e incline '
                      'em qualquer direção para compensar o copo. '
                      'A posição atual vira o ponto zero. '
                      'O indicador embaixo mostra para onde a água quer '
                      'escapar: mantenha a bolha dentro do círculo.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
            if (!_hasSensor) ...[
              const SizedBox(height: 8),
              const Text(
                'Sensores indisponíveis: arraste o dedo na tela.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.amberAccent, fontSize: 13),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _startGame,
              style: FilledButton.styleFrom(
                backgroundColor: _waterLight,
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

// ---------------------------------------------------------------------------
// Renderização 3D
// ---------------------------------------------------------------------------

class _CupPainter extends CustomPainter {
  _CupPainter({
    required this.center,
    required this.scale,
    required this.a,
    required this.b,
    required this.relA,
    required this.relB,
    required this.fill,
    required this.drops,
    required this.ripples,
    required this.bubble,
  });

  final Offset center;
  final double scale;
  final double a, b; // rotação real do copo
  final double relA, relB; // inclinação da água relativa ao copo
  final double fill;
  final List<_Drop> drops;
  final List<_Ripple> ripples;
  final Offset bubble;

  static const int _n = 40;

  // Luz vindo de cima, da esquerda e da frente.
  static final _V3 _light = _norm(const _V3(-0.5, 0.9, -0.6));

  static _V3 _norm(_V3 v) {
    final l = math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z);
    return _V3(v.x / l, v.y / l, v.z / l);
  }

  static double _dot(_V3 p, _V3 q) => p.x * q.x + p.y * q.y + p.z * q.z;

  // ---- Projeção em perspectiva ----
  double _depth(double y, double z) => _camDist + z * _cc - y * _sn;

  Offset _proj(double x, double y, double z) {
    final k = _camDist / _depth(y, z) * scale;
    final v = y * _cc + z * _sn;
    return Offset(center.dx + x * k, center.dy - v * k);
  }

  Offset _projV(_V3 p) => _proj(p.x, p.y, p.z);

  double _pxPerUnit(double y, double z) => _camDist / _depth(y, z) * scale;

  @override
  void paint(Canvas canvas, Size size) {
    _paintBackground(canvas, size);
    _paintFloor(canvas, size);

    // Gotas atrás do copo
    for (final d in drops) {
      if (d.z > 0.3) _paintDrop(canvas, d);
    }
    _paintCup(canvas);
    // Gotas na frente do copo
    for (final d in drops) {
      if (d.z <= 0.3) _paintDrop(canvas, d);
    }
    _paintBubble(canvas, size);
  }

  void _paintBackground(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF14213D), Color(0xFF0B132B)],
        ).createShader(Offset.zero & size),
    );
  }

  void _paintFloor(Canvas canvas, Size size) {
    // Horizonte do chão
    final horizonY = _proj(0, _floorY, 60).dy;
    if (horizonY < size.height) {
      final rect = Rect.fromLTRB(0, horizonY, size.width, size.height);
      canvas.drawRect(
        rect,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0B132B), Color(0xFF1C2B52)],
          ).createShader(rect),
      );
    }

    // Grade no chão
    final grid = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var zi = -1; zi <= 14; zi++) {
      final z = zi.toDouble() - 0.8;
      grid.color = Colors.white.withAlpha((34 * (1 - zi / 16)).round());
      canvas.drawLine(
          _proj(-8, _floorY, z), _proj(8, _floorY, z), grid);
    }
    for (var xi = -8; xi <= 8; xi++) {
      final x = xi.toDouble();
      grid.color = Colors.white.withAlpha(22);
      canvas.drawLine(
          _proj(x, _floorY, -1.8), _proj(x, _floorY, 14), grid);
    }

    // Sombra do copo
    final sc = _proj(0, _floorY, 0);
    final sr = 0.55 * _pxPerUnit(_floorY, 0);
    canvas.drawOval(
      Rect.fromCenter(center: sc, width: sr * 2, height: sr * 2 * _sn),
      Paint()..color = Colors.black.withAlpha(90),
    );

    // Marolas das gotas que caem no chão
    final rp = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    for (final r in ripples) {
      final pc = _proj(r.x, _floorY, r.z);
      final rad = (0.04 + 0.28 * r.t) * _pxPerUnit(_floorY, r.z);
      rp.color = _waterLight.withAlpha((200 * (1 - r.t)).round());
      canvas.drawOval(
        Rect.fromCenter(center: pc, width: rad * 2, height: rad * 2 * _sn),
        rp,
      );
    }
  }

  void _paintDrop(Canvas canvas, _Drop d) {
    final p = _proj(d.x, d.y, d.z);
    final rad = d.r * _pxPerUnit(d.y, d.z);
    canvas.drawCircle(p, rad, Paint()..color = _waterLight);
    canvas.drawCircle(
      p + Offset(-rad * 0.3, -rad * 0.3),
      rad * 0.35,
      Paint()..color = Colors.white.withAlpha(180),
    );
  }

  void _paintCup(Canvas canvas) {
    final pose = _Pose(a, b);
    final ySurf = -_cupH / 2 + _cupH * fill;

    // Normal do plano da água (no referencial do copo)
    final cb = math.cos(relB);
    final nx = -cb * math.sin(relA);
    final ny = math.max(0.05, cb * math.cos(relA));
    final nz = -math.sin(relB);

    // ---- Malha: anéis de baixo, de cima e da superfície da água ----
    final botW = <_V3>[], topW = <_V3>[], watW = <_V3>[];
    for (var i = 0; i < _n; i++) {
      final t = i * 2 * math.pi / _n;
      final c = math.cos(t), s = math.sin(t);
      botW.add(pose.apply(_rBot * c, -_cupH / 2, _rBot * s));
      topW.add(pose.apply(_rTop * c, _cupH / 2, _rTop * s));

      // Altura da água neste ângulo: plano inclinado cortando o cone do copo
      var y = ySurf;
      for (var it = 0; it < 3; it++) {
        final r = _radiusAt(y);
        y = (ySurf - (nx * r * c + nz * r * s) / ny)
            .clamp(-_cupH / 2, _cupH / 2)
            .toDouble();
      }
      final r = _radiusAt(y);
      watW.add(pose.apply(r * c, y, r * s));
    }
    final botS = botW.map(_projV).toList();
    final topS = topW.map(_projV).toList();
    final watS = watW.map(_projV).toList();

    // ---- Faces: frente ou verso para a câmera, e iluminação ----
    final camPos = const _V3(0, _camDist * 0.4794, -_camDist * 0.8776);
    final slope = -(_rTop - _rBot) / _cupH;
    final front = List<bool>.filled(_n, false);
    final diffuse = List<double>.filled(_n, 0);
    final spec = List<double>.filled(_n, 0);
    for (var i = 0; i < _n; i++) {
      final j = (i + 1) % _n;
      final tm = (i + 0.5) * 2 * math.pi / _n;
      final nl = _norm(_V3(math.cos(tm), slope, math.sin(tm)));
      final nw = pose.apply(nl.x, nl.y, nl.z);
      final mid = _V3(
        (botW[i].x + botW[j].x + topW[i].x + topW[j].x) / 4,
        (botW[i].y + botW[j].y + topW[i].y + topW[j].y) / 4,
        (botW[i].z + botW[j].z + topW[i].z + topW[j].z) / 4,
      );
      final toCam = _norm(_V3(camPos.x - mid.x, camPos.y - mid.y, camPos.z - mid.z));
      final isFront = _dot(nw, toCam) > 0;
      front[i] = isFront;
      final sgn = isFront ? 1.0 : -1.0;
      final nn = _V3(nw.x * sgn, nw.y * sgn, nw.z * sgn);
      diffuse[i] = math.max(0.0, _dot(nn, _light));
      if (isFront) {
        final hv = _norm(_V3(_light.x + toCam.x, _light.y + toCam.y, _light.z + toCam.z));
        spec[i] = math.pow(math.max(0.0, _dot(nw, hv)), 24).toDouble();
      }
    }

    Path quad(Offset p0, Offset p1, Offset p2, Offset p3) => Path()
      ..moveTo(p0.dx, p0.dy)
      ..lineTo(p1.dx, p1.dy)
      ..lineTo(p2.dx, p2.dy)
      ..lineTo(p3.dx, p3.dy)
      ..close();

    Path ring(List<Offset> pts) {
      final p = Path()..moveTo(pts[0].dx, pts[0].dy);
      for (var i = 1; i < pts.length; i++) {
        p.lineTo(pts[i].dx, pts[i].dy);
      }
      return p..close();
    }

    // Sem antialias nas faces para não aparecerem "costuras" entre os quads.
    final fillPaint = Paint()..isAntiAlias = false;

    // 1) Fundo do copo + parede de trás (vista por dentro)
    fillPaint.color = Colors.white.withAlpha(26);
    canvas.drawPath(ring(botS), fillPaint);
    for (var i = 0; i < _n; i++) {
      if (front[i]) continue;
      final j = (i + 1) % _n;
      fillPaint.color = Colors.white.withAlpha((14 + 30 * diffuse[i]).round());
      canvas.drawPath(quad(botS[i], botS[j], topS[j], topS[i]), fillPaint);
    }

    // 2) Água: parede de trás
    for (var i = 0; i < _n; i++) {
      if (front[i]) continue;
      final j = (i + 1) % _n;
      fillPaint.color = _waterDark.withAlpha(170);
      canvas.drawPath(quad(botS[i], botS[j], watS[j], watS[i]), fillPaint);
    }

    // 3) Superfície da água
    canvas.drawPath(
      ring(watS),
      Paint()..color = const Color(0xFF81D4FA).withAlpha(235),
    );
    canvas.drawPath(
      ring(watS),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = Colors.white.withAlpha(170),
    );

    // 4) Água: parede da frente (com luz)
    for (var i = 0; i < _n; i++) {
      if (!front[i]) continue;
      final j = (i + 1) % _n;
      final col = Color.lerp(_waterDark, _waterLight, 0.35 + 0.65 * diffuse[i])!;
      fillPaint.color = col.withAlpha(230);
      canvas.drawPath(quad(botS[i], botS[j], watS[j], watS[i]), fillPaint);
    }

    // 5) Vidro da frente (translúcido) com brilho especular
    for (var i = 0; i < _n; i++) {
      if (!front[i]) continue;
      final j = (i + 1) % _n;
      final alpha = (16 + 28 * diffuse[i] + 190 * spec[i]).clamp(0, 255).round();
      fillPaint.color = Colors.white.withAlpha(alpha);
      canvas.drawPath(quad(botS[i], botS[j], topS[j], topS[i]), fillPaint);
    }

    // 6) Contornos: silhueta, borda de baixo e borda de cima
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withAlpha(200);
    for (var i = 0; i < _n; i++) {
      final prev = (i - 1 + _n) % _n;
      if (front[i] != front[prev]) {
        canvas.drawLine(botS[i], topS[i], edge);
      }
    }
    canvas.drawPath(
      ring(botS),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Colors.white.withAlpha(70),
    );
    canvas.drawPath(
      ring(topS),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeJoin = StrokeJoin.round
        ..color = Colors.white.withAlpha(230),
    );
  }

  /// Indicador de bolha: mostra para onde a água quer escapar.
  /// A bolha sai do círculo quando passa do limite e começa a derramar.
  void _paintBubble(Canvas canvas, Size size) {
    final bc = Offset(size.width / 2, size.height - 64);
    const r = 34.0;
    final dist = bubble.distance;
    final over = dist > 1;

    canvas.drawCircle(bc, r, Paint()..color = Colors.white.withAlpha(20));
    canvas.drawCircle(
      bc,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = over ? Colors.redAccent : Colors.white54,
    );
    final cross = Paint()
      ..strokeWidth = 1
      ..color = Colors.white.withAlpha(60);
    canvas.drawLine(bc + const Offset(-r, 0), bc + const Offset(r, 0), cross);
    canvas.drawLine(bc + const Offset(0, -r), bc + const Offset(0, r), cross);

    final clamped = dist > 1.5 ? bubble * (1.5 / dist) : bubble;
    canvas.drawCircle(
      bc + clamped * r,
      7,
      Paint()..color = over ? Colors.redAccent : _waterLight,
    );
  }

  @override
  bool shouldRepaint(covariant _CupPainter old) => true;
}