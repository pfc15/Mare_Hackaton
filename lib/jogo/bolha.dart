import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';


// ---------------------------------------------------------------------------
// Dados
// ---------------------------------------------------------------------------

class _Emotion {
  final String name;
  final String emoji;
  final String message;
  final Color color;

  const _Emotion(this.name, this.emoji, this.message, this.color);
}

const _emotions = <_Emotion>[
  _Emotion('Ansiedade', '😰', 'Você está seguro agora. Respire fundo.', Color(0xFF7FB2FF)),
  _Emotion('Raiva', '😠', 'Solte a tensão dos ombros.', Color(0xFFFF8A80)),
  _Emotion('Tristeza', '😢', 'Tudo bem sentir. Isso também passa.', Color(0xFF82B1FF)),
  _Emotion('Estresse', '🤯', 'Uma coisa de cada vez.', Color(0xFFFFB74D)),
  _Emotion('Medo', '😨', 'Você é mais forte do que imagina.', Color(0xFFB39DDB)),
  _Emotion('Culpa', '😔', 'Você fez o seu melhor.', Color(0xFFA1887F)),
  _Emotion('Cansaço', '🥱', 'Descansar também é produtivo.', Color(0xFF80CBC4)),
  _Emotion('Solidão', '🥺', 'Você importa, mesmo quando não parece.', Color(0xFF90A4AE)),
  _Emotion('Frustração', '😤', 'Não precisa ser perfeito.', Color(0xFFFF9E80)),
  _Emotion('Vergonha', '🙈', 'Todo mundo erra. Você é humano.', Color(0xFFF48FB1)),
  _Emotion('Preocupação', '😟', 'Foque no que está ao seu alcance.', Color(0xFFFFE082)),
];

class _Bubble {
  final int id;
  final _Emotion emotion;
  final double diameter;
  final double baseX; // 0..1
  final double speed; // px/s
  final double swayAmp;
  final double swayFreq;
  final double phase;

  double y;
  double age = 0;
  double progress = 0;
  int pointers = 0;

  _Bubble({
    required this.id,
    required this.emotion,
    required this.diameter,
    required this.baseX,
    required this.speed,
    required this.swayAmp,
    required this.swayFreq,
    required this.phase,
    required this.y,
  });

  bool get holding => pointers > 0;
}

class _Particle {
  Offset pos;
  Offset vel;
  double life = 1;
  final double size;
  final Color color;

  _Particle(this.pos, this.vel, this.size, this.color);
}

class _Ring {
  final Offset center;
  final double startRadius;
  final Color color;
  double t = 0;

  _Ring(this.center, this.startRadius, this.color);
}

// ---------------------------------------------------------------------------
// Widget principal
// ---------------------------------------------------------------------------

class BubbleReleaseGame extends StatefulWidget {
  const BubbleReleaseGame({super.key});

  @override
  State<BubbleReleaseGame> createState() => _BubbleReleaseGameState();
}

class _BubbleReleaseGameState extends State<BubbleReleaseGame>
    with SingleTickerProviderStateMixin {
  static const double _holdSeconds = 1.4; // tempo segurando para estourar
  static const int _maxBubbles = 6;

  final _rng = math.Random();
  final _bubbles = <_Bubble>[];
  final _particles = <_Particle>[];
  final _rings = <_Ring>[];

  late final Ticker _ticker;
  Duration _last = Duration.zero;
  Size _size = Size.zero;
  double _spawnTimer = 0;
  int _nextId = 0;

  int _popped = 0;
  int _messageId = 0;
  String _title = 'Respire fundo…';
  String _subtitle = 'Segure uma bolha até ela estourar.';

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  // ----------------------------- lógica ------------------------------------

  void _seed() {
    for (var i = 0; i < 4; i++) {
      _spawn(startY: _size.height * (0.2 + 0.18 * i));
    }
  }

  void _spawn({double? startY}) {
    final d = 96 + _rng.nextDouble() * 44;
    _bubbles.add(
      _Bubble(
        id: _nextId++,
        emotion: _emotions[_rng.nextInt(_emotions.length)],
        diameter: d,
        baseX: _rng.nextDouble(),
        speed: 20 + _rng.nextDouble() * 18,
        swayAmp: 10 + _rng.nextDouble() * 16,
        swayFreq: 0.5 + _rng.nextDouble() * 0.6,
        phase: _rng.nextDouble() * math.pi * 2,
        y: startY ?? _size.height + d / 2,
      ),
    );
  }

  double _bubbleX(_Bubble b) {
    final w = _size.width;
    final base = b.baseX * (w - b.diameter) + b.diameter / 2;
    final sway = math.sin(b.age * b.swayFreq + b.phase) * b.swayAmp;
    return (base + sway).clamp(b.diameter / 2, w - b.diameter / 2).toDouble();
  }

  void _onTick(Duration elapsed) {
    var dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    if (dt > 0.05) dt = 0.05;
    if (_size == Size.zero) return;

    // bolhas
    for (final b in _bubbles) {
      b.age += dt;
      // quase paradas enquanto seguradas
      b.y -= b.speed * (b.holding ? 0.1 : 1.0) * dt;
      if (b.holding) {
        b.progress += dt / _holdSeconds;
      } else {
        b.progress = math.max(0, b.progress - dt * 0.4);
      }
    }

    // estouros
    final done = _bubbles.where((b) => b.progress >= 1).toList();
    for (final b in done) {
      _pop(b);
    }
    _bubbles.removeWhere(
      (b) => b.progress >= 1 || b.y + b.diameter / 2 < -20,
    );

    // novas bolhas, sem pressa
    _spawnTimer += dt;
    if (_bubbles.length < _maxBubbles && _spawnTimer > 1.4) {
      _spawnTimer = 0;
      _spawn();
    }

    // partículas
    for (final p in _particles) {
      p.pos += p.vel * dt;
      p.vel = p.vel * (1 - 1.6 * dt) + Offset(0, -12 * dt);
      p.life -= dt / 1.3;
    }
    _particles.removeWhere((p) => p.life <= 0);

    for (final r in _rings) {
      r.t += dt / 0.9;
    }
    _rings.removeWhere((r) => r.t >= 1);

    setState(() {});
  }

  void _pop(_Bubble b) {
    final center = Offset(_bubbleX(b), b.y);
    final color = b.emotion.color;

    for (var i = 0; i < 18; i++) {
      final angle = _rng.nextDouble() * math.pi * 2;
      final speed = 40 + _rng.nextDouble() * 120;
      _particles.add(
        _Particle(
          center,
          Offset(math.cos(angle), math.sin(angle)) * speed,
          3 + _rng.nextDouble() * 5,
          i.isEven ? color : Colors.white,
        ),
      );
    }
    _rings.add(_Ring(center, b.diameter / 2, color));

    HapticFeedback.mediumImpact();
    _popped++;
    _messageId++;
    _title = 'Você soltou a ${b.emotion.name.toLowerCase()} 🌿';
    _subtitle = b.emotion.message;
  }

  void _pointerDown(_Bubble b) {
    b.pointers++;
    HapticFeedback.selectionClick();
  }

  void _pointerUp(_Bubble b) {
    b.pointers = math.max(0, b.pointers - 1);
  }

  // ------------------------------ UI ---------------------------------------

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final newSize = Size(c.maxWidth, c.maxHeight);
        if (newSize != _size) {
          final first = _size == Size.zero;
          _size = newSize;
          if (first) _seed();
        }

        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF1B2A49), Color(0xFF2E5A88), Color(0xFF4A9A9A)],
            ),
          ),
          child: Stack(
            children: [
              for (final b in _bubbles) _buildBubble(b),
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(painter: _FxPainter(_particles, _rings)),
                ),
              ),
              SafeArea(child: IgnorePointer(child: _buildOverlay())),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBubble(_Bubble b) {
    final cx = _bubbleX(b);
    final tremble = b.holding ? math.sin(b.age * 45) * 1.5 * b.progress : 0.0;
    final scale = 1 + 0.16 * Curves.easeOut.transform(b.progress.clamp(0.0, 1.0));

    return Positioned(
      key: ValueKey(b.id),
      left: cx - b.diameter / 2 + tremble,
      top: b.y - b.diameter / 2,
      width: b.diameter,
      height: b.diameter,
      child: Transform.scale(
        scale: scale,
        // ClipOval faz o hit-test ser circular
        child: ClipOval(
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (_) => _pointerDown(b),
            onPointerUp: (_) => _pointerUp(b),
            onPointerCancel: (_) => _pointerUp(b),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _BubblePainter(
                      color: b.emotion.color,
                      progress: b.progress,
                    ),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      b.emotion.emoji,
                      style: TextStyle(fontSize: b.diameter * 0.30),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      b.emotion.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.none,
                        shadows: [Shadow(blurRadius: 4, color: Colors.black38)],
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
  }

  Widget _buildOverlay() {
    const textStyle = TextStyle(
      color: Colors.white,
      decoration: TextDecoration.none,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Solte o que pesa',
                style: textStyle.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.w300,
                  letterSpacing: 0.5,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '🫧 $_popped',
                  style: textStyle.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 700),
            child: Column(
              key: ValueKey(_messageId),
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _title,
                  textAlign: TextAlign.center,
                  style: textStyle.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _subtitle,
                  textAlign: TextAlign.center,
                  style: textStyle.copyWith(
                    fontSize: 14,
                    color: Colors.white70,
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Painters
// ---------------------------------------------------------------------------

class _BubblePainter extends CustomPainter {
  final Color color;
  final double progress;

  _BubblePainter({required this.color, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final r = size.width / 2 - 4;
    final p = progress.clamp(0.0, 1.0);

    // corpo translúcido
    final body = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.4),
        colors: [
          Colors.white.withOpacity(0.45 + 0.25 * p),
          color.withOpacity(0.30 + 0.2 * p),
          color.withOpacity(0.60),
        ],
        stops: const [0.0, 0.6, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: r));
    canvas.drawCircle(center, r, body);

    // borda
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white.withOpacity(0.5),
    );

    // brilho
    canvas.save();
    canvas.translate(center.dx - r * 0.42, center.dy - r * 0.5);
    canvas.rotate(-0.6);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: r * 0.45, height: r * 0.22),
      Paint()..color = Colors.white.withOpacity(0.55),
    );
    canvas.restore();

    // anel de progresso
    if (p > 0.001) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: r - 8),
        -math.pi / 2,
        math.pi * 2 * p,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round
          ..color = Colors.white.withOpacity(0.9),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BubblePainter old) =>
      old.progress != progress || old.color != color;
}

class _FxPainter extends CustomPainter {
  final List<_Particle> particles;
  final List<_Ring> rings;

  _FxPainter(this.particles, this.rings);

  @override
  void paint(Canvas canvas, Size size) {
    for (final r in rings) {
      final t = Curves.easeOut.transform(r.t);
      canvas.drawCircle(
        r.center,
        r.startRadius + 50 * t,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3 * (1 - t)
          ..color = r.color.withOpacity((1 - t).clamp(0.0, 1.0)),
      );
    }
    for (final p in particles) {
      final life = p.life.clamp(0.0, 1.0);
      canvas.drawCircle(
        p.pos,
        p.size * life,
        Paint()..color = p.color.withOpacity(life),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FxPainter old) => true;
}