import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';


class _Stroke {
  final List<Offset> pts = [];
}

/// Uma onda: tempos, alcance (0..1 da altura da tela) e formato próprios.
class _Wave {
  final double start; // quando começa (inclui a pausa inicial)
  final double idle; // pausa antes da onda
  final double advance; // avanço
  final double hold; // pico
  final double recede; // recuo
  final double reach; // alcance: 1.0 = cobre a tela inteira
  final double amp; // ondulação da borda
  final double k; // frequência lateral da borda
  final double phase; // fase lateral (cada onda tem um formato)

  const _Wave({
    required this.start,
    required this.idle,
    required this.advance,
    required this.hold,
    required this.recede,
    required this.reach,
    required this.amp,
    required this.k,
    required this.phase,
  });

  double get end => start + idle + advance + hold + recede;
}

class SandDrawingWidget extends StatefulWidget {
  const SandDrawingWidget({super.key});

  @override
  State<SandDrawingWidget> createState() => _SandDrawingWidgetState();
}

class _SandDrawingWidgetState extends State<SandDrawingWidget>
    with SingleTickerProviderStateMixin {
  static const double _wetFade = 12; // segundos para a areia secar
  static const double _step = 8; // resolução horizontal da onda
  static const double _fullWipeChance = 0.28; // chance de onda total

  final _rng = math.Random();
  final _tick = ValueNotifier<int>(0);
  final _strokes = <_Stroke>[];
  final _active = <int, _Stroke?>{};

  late final Ticker _ticker;
  late _Wave _wave;
  Duration _last = Duration.zero;
  Size _size = Size.zero;

  double _t = 0; // tempo (s)
  double _p = 0; // progresso da onda atual 0..1
  double _base = 0; // altura base da água (px)
  double _vel = 0; // velocidade da água (px/s), suavizada
  bool _hint = true;

  // Estado por coluna (amostras ao longo da largura)
  List<double> _wetY = []; // até onde a areia está molhada
  List<double> _wetA = []; // intensidade da umidade
  List<double> _foamY = []; // posição da renda de espuma deixada
  List<double> _foamA = []; // intensidade da espuma
  List<double> _jit = []; // ruído fixo para a espuma
  List<Offset> _grainDark = [];
  List<Offset> _grainLight = [];

  @override
  void initState() {
    super.initState();
    _wave = _nextWave(0, first: true);
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _tick.dispose();
    super.dispose();
  }

  // ------------------------------ ondas ------------------------------------

  _Wave _nextWave(double start, {bool first = false}) {
    final full = !first && _rng.nextDouble() < _fullWipeChance;
    // a primeira é média, pra mostrar que nem toda onda leva tudo
    final reach = first
        ? 0.42
        : full
            ? 1.0
            : 0.15 + _rng.nextDouble() * 0.6;

    return _Wave(
      start: start,
      idle: first ? 5 : 1.8 + _rng.nextDouble() * 5.5,
      advance: 2.4 + _rng.nextDouble() * 1.4 + reach * 0.8,
      hold: 0.2 + _rng.nextDouble() * 0.5,
      recede: 3.2 + _rng.nextDouble() * 2.4 + reach * 1.2,
      reach: reach,
      amp: 0.8 + _rng.nextDouble() * 0.6,
      k: 0.010 + _rng.nextDouble() * 0.010,
      phase: _rng.nextDouble() * math.pi * 2,
    );
  }

  double _waveProgress(_Wave w, double t) {
    var c = t - w.start;
    if (c < w.idle) return 0;
    c -= w.idle;
    // avanço: arranca rápido e vai perdendo força (como uma onda de verdade)
    if (c < w.advance) return Curves.easeOutCubic.transform(c / w.advance);
    c -= w.advance;
    if (c < w.hold) return 1;
    c -= w.hold;
    // recuo: começa devagar e a água escorre de volta
    if (c < w.recede) {
      return 1 - Curves.easeInOutSine.transform(c / w.recede);
    }
    return 0;
  }

  double get _restY => _size.height * 0.08;

  /// y da linha d'água em determinado x. Acima dela é mar.
  double _front(double x) {
    final amp = (6 + 9 * math.sin(_p * math.pi)) * _wave.amp;
    return _base +
        math.sin(x * _wave.k + _wave.phase + _t * 0.9) * amp +
        math.sin(x * _wave.k * 2.2 - _wave.phase * 1.7 - _t * 1.3) *
            amp *
            0.4 +
        math.sin(_t * 0.6) * 4 * (1 - _p);
  }

  int get _samples => (_size.width / _step).ceil() + 1;
  double _sampleX(int i) => math.min(i * _step, _size.width);

  void _onTick(Duration elapsed) {
    if (_size == Size.zero) return;
    var dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    if (dt > 0.05) dt = 0.05;
    if (dt <= 0) return;

    _t = elapsed.inMicroseconds / 1e6;
    while (_t >= _wave.end) {
      _wave = _nextWave(_wave.end);
    }
    _p = _waveProgress(_wave, _t);

    final h = _size.height;
    final rest = _restY;
    final newBase = rest + (h + 44 - rest) * _wave.reach * _p;
    final v = (newBase - _base) / dt;
    _base = newBase;
    _vel += (v - _vel) * math.min(1, dt * 6);

    for (var i = 0; i < _samples; i++) {
      final f = _front(_sampleX(i));

      // areia molhada
      if (f > rest + 20 && f > _wetY[i]) {
        _wetY[i] = f;
        _wetA[i] = 1;
      } else if (f > rest + 36) {
        _wetA[i] = math.min(1, _wetA[i] + dt * 0.6); // ainda sendo molhada
      } else {
        _wetA[i] = math.max(0, _wetA[i] - dt / _wetFade);
        if (_wetA[i] <= 0.01) _wetY[i] = 0;
      }

      // renda de espuma que a onda deixa no ponto mais alto
      if (_vel > 20 && f > rest + 10) {
        _foamY[i] = f;
        _foamA[i] = 1;
      } else {
        _foamA[i] = math.max(0, _foamA[i] - dt / 5);
      }
    }

    _eraseUnderWater();
    _tick.value++;
  }

  /// Remove os pedaços do desenho que a água já cobriu.
  void _eraseUnderWater() {
    if (_strokes.isEmpty) return;
    final result = <_Stroke>[];
    var changed = false;

    for (final s in _strokes) {
      var anyWet = false;
      for (final p in s.pts) {
        if (p.dy < _front(p.dx)) {
          anyWet = true;
          break;
        }
      }
      if (!anyWet) {
        result.add(s);
        continue;
      }

      changed = true;
      _active.updateAll((k, v) => identical(v, s) ? null : v);

      var cur = <Offset>[];
      for (final p in s.pts) {
        if (p.dy < _front(p.dx)) {
          if (cur.isNotEmpty) {
            result.add(_Stroke()..pts.addAll(cur));
            cur = [];
          }
        } else {
          cur.add(p);
        }
      }
      if (cur.isNotEmpty) result.add(_Stroke()..pts.addAll(cur));
    }

    if (changed) {
      _strokes
        ..clear()
        ..addAll(result);
    }
  }

  // ---------------------------- interação ----------------------------------

  void _addPoint(int pointer, Offset pos, {bool isDown = false}) {
    if (_size == Size.zero) return;

    if (pos.dy < _front(pos.dx)) {
      _active[pointer] = null; // não dá pra desenhar dentro da água
      return;
    }

    var s = _active[pointer];
    if (s == null || isDown) {
      s = _Stroke();
      _strokes.add(s);
      _active[pointer] = s;
      s.pts.add(pos);
      if (_strokes.length > 300) _strokes.removeAt(0);
    } else if ((s.pts.last - pos).distance >= 3) {
      s.pts.add(pos);
    }

    if (_hint) setState(() => _hint = false);
  }

  // -------------------------------- UI -------------------------------------

  void _prepare(Size size) {
    _size = size;
    final n = _samples;
    _wetY = List<double>.filled(n, 0);
    _wetA = List<double>.filled(n, 0);
    _foamY = List<double>.filled(n, 0);
    _foamA = List<double>.filled(n, 0);
    _base = _restY;

    final r = math.Random(11);
    _jit = List.generate(n * 4, (_) => r.nextDouble() * 2 - 1);

    final count = (size.width * size.height / 260).clamp(300, 2500).toInt();
    _grainDark = List.generate(
      count,
      (_) => Offset(r.nextDouble() * size.width, r.nextDouble() * size.height),
    );
    _grainLight = List.generate(
      count,
      (_) => Offset(r.nextDouble() * size.width, r.nextDouble() * size.height),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final size = Size(c.maxWidth, c.maxHeight);
        if (size != _size) _prepare(size);

        return Stack(
          children: [
            Positioned.fill(
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: (e) =>
                    _addPoint(e.pointer, e.localPosition, isDown: true),
                onPointerMove: (e) => _addPoint(e.pointer, e.localPosition),
                onPointerUp: (e) => _active.remove(e.pointer),
                onPointerCancel: (e) => _active.remove(e.pointer),
                child: CustomPaint(painter: _SandPainter(this)),
              ),
            ),
            Positioned(
              left: 24,
              right: 24,
              bottom: 40,
              child: IgnorePointer(
                child: AnimatedOpacity(
                  opacity: _hint ? 1 : 0,
                  duration: const Duration(milliseconds: 1500),
                  child: const Text(
                    'Desenhe na areia com o dedo…\no mar vai e vem 🌊',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF7A6340),
                      fontSize: 16,
                      fontWeight: FontWeight.w300,
                      height: 1.5,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Painter
// ---------------------------------------------------------------------------

class _SandPainter extends CustomPainter {
  final _SandDrawingWidgetState g;

  _SandPainter(this.g) : super(repaint: g._tick);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final rect = Offset.zero & size;
    final n = g._samples;
    final rest = g._restY;

    // 1. areia seca ---------------------------------------------------------
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF0DDB0), Color(0xFFE0C58E)],
        ).createShader(rect),
    );
    canvas.drawPoints(
      ui.PointMode.points,
      g._grainDark,
      Paint()
        ..color = const Color(0xFF8A6A38).withOpacity(0.22)
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPoints(
      ui.PointMode.points,
      g._grainLight,
      Paint()
        ..color = const Color(0xFFFFF3D2).withOpacity(0.5)
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round,
    );

    // 2. riscos na areia ----------------------------------------------------
    if (g._strokes.isNotEmpty) {
      final path = Path();
      for (final s in g._strokes) {
        _appendStroke(path, s.pts);
      }

      Paint line(Color color, double width) => Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = width
        ..color = color;

      canvas.drawPath(
        path.shift(const Offset(1.6, 1.8)),
        line(const Color(0xFF6E5026).withOpacity(0.45), 8),
      );
      canvas.drawPath(
        path.shift(const Offset(-1.6, -1.8)),
        line(const Color(0xFFFFF6DC).withOpacity(0.75), 8),
      );
      canvas.drawPath(path, line(const Color(0xFFC9A468), 6));
    }

    // 3. areia molhada (por coluna, com borda suave) -------------------------
    const wetColor = Color(0xFF6E4F26);
    final p1 = <Offset>[], c1 = <Color>[];
    final p2 = <Offset>[], c2 = <Color>[];
    var anyWet = false;
    for (var i = 0; i < n; i++) {
      final a = 0.33 * Curves.easeOut.transform(g._wetA[i].clamp(0.0, 1.0));
      if (a > 0.002) anyWet = true;
      final x = g._sampleX(i);
      final y = g._wetY[i];
      final solid = wetColor.withOpacity(a);
      p1
        ..add(Offset(x, 0))
        ..add(Offset(x, y));
      c1
        ..add(solid)
        ..add(solid);
      p2
        ..add(Offset(x, y))
        ..add(Offset(x, y + 28));
      c2
        ..add(solid)
        ..add(wetColor.withOpacity(0));
    }
    if (anyWet) {
      final v1 = ui.Vertices(ui.VertexMode.triangleStrip, p1, colors: c1);
      final v2 = ui.Vertices(ui.VertexMode.triangleStrip, p2, colors: c2);
      canvas.drawVertices(v1, BlendMode.src, Paint());
      canvas.drawVertices(v2, BlendMode.src, Paint());
      v1.dispose();
      v2.dispose();
    }

    // 4. renda de espuma que a onda deixa na areia ---------------------------
    final lace = Paint();
    for (var i = 0; i < n; i++) {
      final fa = g._foamA[i];
      if (fa < 0.03 || g._foamY[i] < rest + 10) continue;
      final x = g._sampleX(i);
      final y = g._foamY[i];
      final j = g._jit;
      lace.color = Colors.white.withOpacity(0.6 * fa);
      canvas.drawCircle(
        Offset(x + j[4 * i] * 6, y + j[4 * i + 1] * 8 - 3),
        1.4 + (j[4 * i + 2] + 1) * 0.9,
        lace,
      );
      canvas.drawCircle(
        Offset(x + j[4 * i + 3] * 6 + 4, y + 7 + j[4 * i + 2] * 4),
        1.1,
        lace,
      );
    }

    // 5. mar ----------------------------------------------------------------
    final ys = List<double>.generate(n, (i) => g._front(g._sampleX(i)));
    var maxY = 0.0;
    final water = Path()..moveTo(0, 0);
    final front = Path();
    for (var i = 0; i < n; i++) {
      final x = g._sampleX(i);
      maxY = math.max(maxY, ys[i]);
      water.lineTo(x, ys[i]);
      if (i == 0) {
        front.moveTo(x, ys[i]);
      } else {
        front.lineTo(x, ys[i]);
      }
    }
    water
      ..lineTo(w, 0)
      ..close();

    final vn = (g._vel / 300).clamp(-1.0, 1.0); // -1 recuando .. 1 avançando
    final speedN = vn.abs();

    // lâmina fina de água na frente da onda, mais larga quando avança rápido
    final lead = 8 + 22 * math.max(0.0, vn);
    final film = Path()..moveTo(0, 0);
    for (var i = 0; i < n; i++) {
      film.lineTo(g._sampleX(i), ys[i] + lead);
    }
    film
      ..lineTo(w, 0)
      ..close();
    canvas.drawPath(
      film,
      Paint()..color = const Color(0xFF7FD1CC).withOpacity(0.22),
    );

    // corpo do mar
    final waterRect = Rect.fromLTRB(0, 0, w, math.max(maxY, 40));
    canvas.drawPath(
      water,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF14607F), Color(0xFF2A93A8), Color(0xB07FD1CC)],
          stops: [0.0, 0.6, 1.0],
        ).createShader(waterRect),
    );

    // ondulações suaves dentro da água
    for (var k = 1; k <= 3; k++) {
      final f = 0.25 * k + 0.05;
      final ripple = Path();
      for (var i = 0; i < n; i++) {
        final x = g._sampleX(i);
        final y = ys[i] * f + math.sin(x * 0.02 + g._t * 0.5 + k) * 3;
        if (i == 0) {
          ripple.moveTo(x, y);
        } else {
          ripple.lineTo(x, y);
        }
      }
      canvas.drawPath(
        ripple,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = Colors.white.withOpacity(0.08),
      );
    }

    // brilho raso na beira
    canvas.drawPath(
      front,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 30
        ..color = Colors.white.withOpacity(0.12 + 0.08 * speedN)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    // espuma: linhas que ficam para trás da crista quando a onda avança
    // (e à frente dela, como uma película, quando recua)
    final trail = -vn * 34;
    final intensity = 0.4 + 0.6 * speedN;
    canvas.drawPath(
      front.shift(Offset(0, trail * 1.8)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = Colors.white.withOpacity(0.22 * intensity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
    );
    canvas.drawPath(
      front.shift(Offset(0, trail)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..color = Colors.white.withOpacity(0.42 * intensity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
    );
    // crista
    canvas.drawPath(
      front,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4 + 4 * speedN
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withOpacity(0.9)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
    );
  }

  void _appendStroke(Path path, List<Offset> p) {
    if (p.isEmpty) return;
    path.moveTo(p.first.dx, p.first.dy);
    if (p.length == 1) {
      path.lineTo(p.first.dx + 0.01, p.first.dy);
      return;
    }
    for (var i = 1; i < p.length - 1; i++) {
      final mid = Offset(
        (p[i].dx + p[i + 1].dx) / 2,
        (p[i].dy + p[i + 1].dy) / 2,
      );
      path.quadraticBezierTo(p[i].dx, p[i].dy, mid.dx, mid.dy);
    }
    path.lineTo(p.last.dx, p.last.dy);
  }

  @override
  bool shouldRepaint(covariant _SandPainter old) => false;
}