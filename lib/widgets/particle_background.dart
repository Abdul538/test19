import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// Latar partikel cahaya melayang di belakang seluruh app — dirancang
/// ulang total supaya jadi sumber "refraksi" yang realistis saat lewat
/// di balik panel GlassCard (yang sekarang blur-nya dalam):
///
/// - Bentuk partikel: bokeh (titik cahaya bulat & buram), BUKAN garis
///   kecepatan/"warp speed" seperti sebelumnya.
/// - Gerakan: melayang organik — drift horizontal pelan + ayunan vertikal
///   naik-turun (gabungan beberapa gelombang sinus dgn fase acak per
///   partikel), bukan garis lurus satu arah.
/// - Jumlah partikel TIDAK dibatasi ke angka kecil tetap (dulu 14/30) —
///   sekarang murni proporsional terhadap luas layar, jadi otomatis
///   penuh & padat di layar besar, dan tetap wajar di layar kecil.
/// - eco: partikel lebih sedikit & blur lebih tipis (hemat GPU).
///   high: lebih padat, blur lebih lembut & berlapis (bokeh lebih dalam).
class ParticleBackground extends StatefulWidget {
  final bool eco;
  final Color accent;
  const ParticleBackground({super.key, required this.eco, required this.accent});

  @override
  State<ParticleBackground> createState() => _ParticleBackgroundState();
}

class _Bokeh {
  double x, y, baseY, radius, blur, alpha, driftSpeed, wobbleSpeed, wobbleAmp, phase;
  Color color;
  // Seberapa jauh partikel ini ikut bergeser saat parallax (tilt/goyang
  // HP): partikel yang lebih besar dianggap lebih "dekat" ke mata jadi
  // bergerak lebih jauh, yang kecil dianggap lebih "jauh" jadi hampir diam
  // — itulah yang menciptakan kesan kedalaman/parallax asli, bukan semua
  // partikel bergeser rata sama jauhnya.
  final double parallaxDepth;
  // Paint sudah disiapkan sekali saat partikel dibuat (bukan di dalam loop
  // paint() yang berjalan 60x/detik) — warna, radius, dan blur satu
  // partikel tidak pernah berubah selama hidupnya, cuma posisinya (x/y)
  // yang bergerak tiap frame. Alokasi Paint+MaskFilter baru tiap frame
  // tiap partikel murni kerja sia-sia yang membebani GC tanpa mengubah
  // tampilan sedikit pun.
  late final Paint corePaint;
  late final Paint? outerPaint;

  _Bokeh({
    required this.x,
    required this.y,
    required this.baseY,
    required this.radius,
    required this.blur,
    required this.alpha,
    required this.driftSpeed,
    required this.wobbleSpeed,
    required this.wobbleAmp,
    required this.phase,
    required this.color,
    required this.parallaxDepth,
    required bool layered,
  }) {
    corePaint = Paint()
      ..color = color.withOpacity(alpha)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur);
    outerPaint = layered
        ? (Paint()
          ..color = color.withOpacity(alpha * 0.28)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur * 1.3))
        : null;
  }
}

class _ParticleBackgroundState extends State<ParticleBackground> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  List<_Bokeh> _particles = [];
  Size _lastSize = Size.zero;
  final _rand = Random();
  double _t = 0;

  // --- Parallax dari sensor gerak ---
  // Akselerometer: dipakai sebagai sumber "tilt" untuk sumbu VERTIKAL
  // (atas-bawah) saja. Nilainya ABSOLUT (mengikuti arah gravitasi terhadap
  // bodi HP), jadi tetap stabil selama HP dipegang miring — tidak seperti
  // giroskop yang cuma mengukur KECEPATAN rotasi dan akan diam di 0 begitu
  // gerakan berhenti. Untuk sumbu HORIZONTAL, akselerometer sengaja TIDAK
  // dipakai lagi — lihat catatan di dekat `_rotKickX` di bawah.
  StreamSubscription<AccelerometerEvent>? _accelSub;
  double _accelZ = 0; // pembacaan mentah terakhir, m/s²
  double _tiltY = 0; // hasil low-pass filter, kira-kira -1..1

  // Giroskop: dipakai sebagai lapisan "kick" tambahan yang responsif —
  // begitu HP diputar/digoyang cepat, partikel ikut menyentak sedikit lalu
  // meluruh balik ke posisi tilt-nya. Ini melengkapi akselerometer yang
  // agak lamban (di-smoothing) supaya gerakan cepat tetap terasa hidup.
  // Kombinasi keduanya = teknik "complementary filter" sensor fusion yang
  // umum dipakai, disederhanakan untuk kebutuhan dekoratif di sini.
  StreamSubscription<GyroscopeEvent>? _gyroSub;
  double _gyroRateX = 0, _gyroRateY = 0, _gyroRateZ = 0; // pembacaan mentah terakhir, rad/s
  double _gyroKickY = 0; // hasil integrasi + peluruhan

  // CATATAN PENTING soal sumbu horizontal (kiri-kanan):
  // Dulu tiltX diambil dari accelX (akselerometer). Masalahnya: accelX itu
  // mengukur ke mana arah gravitasi RELATIF terhadap bodi HP — dan gerakan
  // yang PALING mengubah itu adalah MEMIRINGKAN HP (roll di sumbu yang
  // tegak lurus layar, kayak bikin lukisan di dinding jadi miring), bukan
  // MEMUTAR HP (rotasi murni di sumbu tegak lurus layar, kayak muter kenop
  // sambil layarnya tetap menghadap kita). Efeknya: parallax jadi salah
  // nyantol ke gerakan miring, bukan ke gerakan putar seperti yang
  // diinginkan.
  //
  // Rotasi murni (memutar) itu justru TIDAK banyak mengubah accelX/Y/Z
  // (gravitasi relatif terhadap HP nyaris sama saja waktu diputar di
  // sumbunya sendiri) — yang benar-benar berubah adalah KECEPATAN
  // rotasinya, dan itu cuma bisa dibaca dari gyroscope sumbu Z (gyroRateZ).
  // Makanya sekarang horizontal parallax sepenuhnya dipindah ke gyroRateZ,
  // accelX sudah tidak dipakai sama sekali untuk sumbu ini.
  double _rotKickX = 0; // hasil integrasi rotasi (gyro Z) + peluruhan

  // Diturunkan dari sebelumnya sesuai permintaan supaya tidak terlalu
  // sensitif — kalau masih kurang/kelebihan pas, tinggal geser dua angka
  // ini.
  static const double _maxTiltPixels = 45;
  static const double _maxParallaxPixels = 85;

  static const _colors = [
    Color(0xFF9CE8D4),
    Color(0xFFF6CF85),
    Color(0xFFEF9D84),
    Color(0xFF8FB8F0),
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(days: 1))..repeat();

    // Sensor gerak tidak tersedia di semua perangkat (emulator, HP kelas
    // bawah tertentu) — kalau stream error/tidak ada, jangan crash, tapi
    // JANGAN ditelan diam-diam juga: di-log ke console lewat debugPrint
    // supaya kalau memang ada masalah di suatu perangkat, itu kelihatan di
    // `flutter run` / logcat, bukan cuma "efeknya diam" tanpa jejak sama
    // sekali.
    try {
      _accelSub = accelerometerEventStream(samplingPeriod: SensorInterval.uiInterval).listen(
        (e) {
          _accelZ = e.z;
        },
        onError: (Object err) {
          debugPrint('[ParticleBackground] accelerometer stream error: $err');
        },
        cancelOnError: true,
      );
    } catch (err) {
      debugPrint('[ParticleBackground] accelerometer unavailable: $err');
    }
    try {
      _gyroSub = gyroscopeEventStream(samplingPeriod: SensorInterval.uiInterval).listen(
        (e) {
          _gyroRateX = e.x;
          _gyroRateY = e.y;
          _gyroRateZ = e.z;
        },
        onError: (Object err) {
          debugPrint('[ParticleBackground] gyroscope stream error: $err');
        },
        cancelOnError: true,
      );
    } catch (err) {
      debugPrint('[ParticleBackground] gyroscope unavailable: $err');
    }
  }

  void _ensureParticles(Size size) {
    if (size == _lastSize && _particles.isNotEmpty) return;
    _lastSize = size;
    final area = size.width * size.height;
    // Kepadatan murni skala-luas, tanpa dipaksa ke angka kecil — layar
    // lebih besar otomatis mendapat lebih banyak titik bokeh.
    final density = widget.eco ? area / 18000 : area / 9000;
    final count = density.round().clamp(1, 999999);
    _particles = List.generate(count, (_) => _makeParticle(size));
  }

  _Bokeh _makeParticle(Size size) {
    // Radius & alpha dinaikkan cukup jauh, dan yang PALING penting: rasio
    // blur terhadap radius diturunkan drastis. Sebelumnya blur = radius *
    // 1.6-2.4 — itu menyebarkan alpha titiknya ke area jauh lebih lebar
    // dari radius aslinya, jadi puncak opacity-nya nyaris nol (makanya
    // "tidak terlihat sama sekali"). Sekarang blur cuma radius * 0.5-0.7,
    // cukup untuk kesan "cahaya lembut" tanpa melenyapkan titiknya.
    final minR = widget.eco ? 4.0 : 5.0;
    final maxR = widget.eco ? 11.0 : 16.0;
    final radius = minR + _rand.nextDouble() * (maxR - minR);
    final y = _rand.nextDouble() * size.height;
    // Map radius ke rentang kedalaman parallax 0.12 (jauh, nyaris diam —
    // seperti bintang jauh) sampai 1.4 (dekat, bergerak jauh LEBIH dari
    // gerakan HP-nya sendiri — seperti benda yang nyaris menempel di lensa
    // kamera). Kontrasnya sengaja dibuat lebar (dulu 0.35–1.0, hampir rata
    // semua) — beda jauh antar lapisan inilah yang sebenarnya terbaca
    // sebagai "3D", bukan cuma seberapa jauh geser totalnya.
    final depthT = ((radius - minR) / (maxR - minR)).clamp(0.0, 1.0);
    final parallaxDepth = 0.12 + depthT * 1.28;
    return _Bokeh(
      x: _rand.nextDouble() * size.width,
      y: y,
      baseY: y,
      radius: radius,
      blur: radius * (widget.eco ? 0.5 : 0.7),
      alpha: 0.45 + _rand.nextDouble() * 0.40,
      driftSpeed: 0.06 + _rand.nextDouble() * (widget.eco ? 0.14 : 0.22),
      wobbleSpeed: 0.4 + _rand.nextDouble() * 0.9,
      wobbleAmp: 10 + _rand.nextDouble() * (widget.eco ? 18 : 34),
      phase: _rand.nextDouble() * pi * 2,
      color: _colors[_rand.nextInt(_colors.length)],
      parallaxDepth: parallaxDepth,
      layered: !widget.eco,
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _accelSub?.cancel();
    _gyroSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // RepaintBoundary mengisolasi canvas partikel jadi layer sendiri supaya
    // animasinya tetap mulus walau panel kaca di atasnya sedang repaint.
    return RepaintBoundary(
      child: IgnorePointer(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = Size(constraints.maxWidth, constraints.maxHeight);
            _ensureParticles(size);
            return AnimatedBuilder(
              animation: _ctrl,
              child: null,
              builder: (context, _) {
                _t += 1 / 60;

                // Tilt dari akselerometer: didekati ke arah nilai barunya
                // sedikit demi sedikit tiap frame (low-pass filter) —
                // bukan langsung dipakai mentah — supaya noise sensor
                // tidak bikin partikel gemetar, tapi tetap terasa
                // "mengikuti" kemiringan HP secara halus.
                //
                // PENTING soal sumbu vertikal: dulu dipakai accelY mentah,
                // tapi itu HAMPIR TIDAK BERUBAH selama HP dipegang tegak
                // wajar di depan wajah — gravitasi sudah "mengunci" sumbu Y
                // di sekitar -9.8 terus-menerus, cuma benar-benar berubah
                // kalau HP direbahkan jauh. Gerakan alami "lihat ke atas/
                // bawah" (memiringkan bagian atas HP menjauh/mendekat)
                // justru jauh lebih mengubah accelZ (sumbu yang tegak lurus
                // layar) — makanya sekarang dipakai accelZ, jauh lebih
                // responsif untuk sumbu atas-bawah di gerakan sehari-hari.
                // Sumbu vertikal (atas-bawah) tetap dari akselerometer —
                // ini tidak dikomplain, cuma diperlambat sedikit (0.09 ->
                // 0.06) biar lebih halus/tidak terlalu peka.
                _tiltY += ((_accelZ / 9.8).clamp(-1.0, 1.0) - _tiltY) * 0.06;

                // Sumbu horizontal (kiri-kanan) sekarang SEPENUHNYA dari
                // rotasi (gyro Z), bukan dari kemiringan (accelX) lagi —
                // ini intinya perbaikan bug: supaya efeknya nyantol ke
                // gerakan MEMUTAR, bukan MEMIRINGKAN.
                _rotKickX += _gyroRateZ * (1 / 60) * 10.0;
                _rotKickX *= 0.90;

                // Kick dari giroskop sumbu lain, cuma sebagai lapisan
                // "kick" tambahan buat sumbu vertikal supaya gerakan cepat
                // tetap terasa hidup (sama seperti sebelumnya, cuma
                // sensitivitasnya diturunkan).
                _gyroKickY += -_gyroRateX * (1 / 60) * 10.0;
                _gyroKickY *= 0.90;

                final parallax = Offset(
                  _rotKickX.clamp(-_maxParallaxPixels, _maxParallaxPixels),
                  (_tiltY * _maxTiltPixels + _gyroKickY).clamp(-_maxParallaxPixels, _maxParallaxPixels),
                );
                // 0..1: seberapa kuat tilt SAAT INI dibanding maksimum yang
                // diizinkan — dipakai buat efek "perspektif" tambahan di
                // bawah (partikel dekat membesar dikit, yang jauh mengecil
                // dikit), bukan cuma geser XY rata.
                final parallaxStrength = (parallax.distance / _maxParallaxPixels).clamp(0.0, 1.0);

                for (final p in _particles) {
                  // Drift horizontal pelan, melingkar balik saat keluar layar.
                  p.x += p.driftSpeed;
                  if (p.x - p.radius > size.width) {
                    p.x = -p.radius;
                    p.baseY = _rand.nextDouble() * size.height;
                  }
                  // Ayunan naik-turun organik (bukan garis lurus).
                  p.y = p.baseY + sin(_t * p.wobbleSpeed + p.phase) * p.wobbleAmp;
                }
                return CustomPaint(
                  size: size,
                  painter: _BokehPainter(_particles, parallax: parallax, parallaxStrength: parallaxStrength),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _BokehPainter extends CustomPainter {
  final List<_Bokeh> particles;
  final Offset parallax;
  final double parallaxStrength;
  _BokehPainter(this.particles, {required this.parallax, required this.parallaxStrength});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      // Parallax diterapkan di sini SAJA (bukan ditambahkan permanen ke
      // p.x/p.y) supaya tidak ikut terhitung di logika wraparound drift —
      // posisi "asli" partikel tetap murni hasil drift+wobble, offset
      // parallax cuma pergeseran render sesaat yang berubah tiap frame
      // sesuai tilt/goyangan HP. Dikalikan parallaxDepth per partikel biar
      // yang besar/dekat bergeser lebih jauh dari yang kecil/jauh.
      final center = Offset(
        p.x + parallax.dx * p.parallaxDepth,
        p.y + parallax.dy * p.parallaxDepth,
      );

      // Efek "perspektif" tambahan: semakin kuat tilt-nya, partikel yang
      // dekat (parallaxDepth tinggi) sedikit MEMBESAR — seolah mendekat ke
      // lensa — sementara yang jauh (parallaxDepth rendah) sedikit
      // MENGECIL — seolah menjauh. Titik netralnya di tengah rentang depth
      // (~0.76). Ini efek murah tapi efeknya kuat untuk kesan "3D asli",
      // bukan cuma seluruh layar geser rata ke satu arah.
      final scale = (1.0 + (p.parallaxDepth - 0.76) * parallaxStrength * 0.32).clamp(0.55, 1.7);

      // Lapisan luar: glow lembut lebih lebar & lebih buram — memberi
      // kesan cahaya benar-benar menghambur (bokeh dalam), bukan cuma
      // titik solid. Paint-nya sudah disiapkan sekali di _Bokeh, tinggal
      // dipakai ulang di sini setiap frame.
      final outer = p.outerPaint;
      if (outer != null) {
        canvas.drawCircle(center, p.radius * 2.1 * scale, outer);
      }

      canvas.drawCircle(center, p.radius * scale, p.corePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _BokehPainter oldDelegate) => true;
}
