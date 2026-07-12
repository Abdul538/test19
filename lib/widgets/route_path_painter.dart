import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Elemen dekoratif "tanda tangan" visual untuk header ala Strava/Komoot:
/// jejak rute GPS yang berkelok putus-putus lengkap dengan dua penanda
/// titik (awal & tujuan), plus dua sapuan glow lembut untuk kedalaman.
/// Ini yang jadi elemen paling berkesan di bagian atas layar — bukan cuma
/// warna solid polos, tapi terasa "merancang rute perjalanan", sesuai
/// identitas app kebugaran/sport-tech.
///
/// Statis (bukan CustomPainter yang di-repaint tiap frame) — cukup gambar
/// sekali, ringan dipakai di header yang selalu tampil di layar.
class RoutePathBackground extends StatelessWidget {
  final Color accent;
  const RoutePathBackground({super.key, required this.accent});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _RoutePathPainter(accent: accent),
      size: Size.infinite,
    );
  }
}

class _RoutePathPainter extends CustomPainter {
  final Color accent;
  _RoutePathPainter({required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    // Glow lembut pojok kiri-atas (warna aksen) & kanan-bawah (biru dingin
    // netral) — memberi kedalaman tanpa jadi gradient generik penuh layar.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = RadialGradient(
          colors: [accent.withOpacity(0.30), accent.withOpacity(0.0)],
        ).createShader(
          Rect.fromCircle(center: Offset(size.width * 0.08, -size.height * 0.35), radius: size.width * 0.85),
        ),
    );
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = RadialGradient(
          colors: [const Color(0xFF3E6FD1).withOpacity(0.18), const Color(0xFF3E6FD1).withOpacity(0.0)],
        ).createShader(
          Rect.fromCircle(center: Offset(size.width * 1.02, size.height * 1.15), radius: size.width * 0.75),
        ),
    );

    // Titik kontrol tetap (bukan Random()) supaya bentuk rute konsisten
    // tiap rebuild, tapi tetap terasa organik/tidak simetris kaku — dua
    // titik ujung sengaja diletakkan sedikit di luar kanvas supaya garis
    // terlihat "mengalir keluar-masuk" bingkai, bukan berhenti kaku di tepi.
    final points = <Offset>[
      Offset(size.width * -0.08, size.height * 0.32),
      Offset(size.width * 0.20, size.height * 0.78),
      Offset(size.width * 0.46, size.height * 0.16),
      Offset(size.width * 0.72, size.height * 0.64),
      Offset(size.width * 1.08, size.height * 0.20),
    ];
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final mid = Offset((p0.dx + p1.dx) / 2, (p0.dy + p1.dy) / 2);
      path.quadraticBezierTo(p0.dx, p0.dy, mid.dx, mid.dy);
    }
    path.lineTo(points.last.dx, points.last.dy);

    final linePaint = Paint()
      ..color = accent.withOpacity(0.36)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;

    // Dash manual lewat PathMetrics — supaya kelihatan seperti garis rute
    // GPS putus-putus (khas app tracking), bukan garis solid biasa.
    const dashWidth = 7.0, dashGap = 6.0;
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      bool draw = true;
      while (distance < metric.length) {
        final segLen = draw ? dashWidth : dashGap;
        final next = math.min(distance + segLen, metric.length);
        if (draw) canvas.drawPath(metric.extractPath(distance, next), linePaint);
        distance = next;
        draw = !draw;
      }
    }

    // Penanda titik awal & tujuan (indeks 1 & 3, yang pasti di dalam
    // kanvas) — ala pin start/finish di peta rute.
    _drawWaypoint(canvas, points[1], accent);
    _drawWaypoint(canvas, points[3], accent);
  }

  void _drawWaypoint(Canvas canvas, Offset center, Color color) {
    canvas.drawCircle(center, 8, Paint()
      ..color = color.withOpacity(0.30)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4);
    canvas.drawCircle(center, 4.5, Paint()..color = color.withOpacity(0.85));
  }

  @override
  bool shouldRepaint(covariant _RoutePathPainter oldDelegate) => oldDelegate.accent != accent;
}
