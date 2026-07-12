import 'dart:ui';
import 'package:flutter/material.dart';

/// Panel "Frosted Glass" realistis — cara kerjanya meniru kaca es/kaca
/// buram fisik yang sesungguhnya:
///
/// - Kaca frosted ASLI tidak memantulkan cahaya seperti cermin — ia
///   MENGHAMBURKAN cahaya yang menembusnya. Karena itu satu-satunya efek
///   yang dipakai di sini adalah blur backdrop yang dalam & konsisten.
///   Semakin dalam blur-nya, semakin "berdifraksi" konten (termasuk
///   partikel cahaya) yang lewat di baliknya — itulah sumber realismenya,
///   BUKAN sheen atau garis kilau yang digambar di atas panel.
/// - Tidak ada animasi sheen diagonal, tidak ada gradient putih terang
///   yang bisa terbaca sebagai "glare" mengganggu.
/// - Vibrancy tipis (saturasi warna dinaikkan sedikit di balik kaca) supaya
///   warna partikel/konten di belakang tetap hidup, bukan jadi abu-abu mati.
/// - Tepi kaca: sisi atas sedikit lebih terang ("edge-lit", seolah
///   menangkap cahaya dari atas) untuk kesan volume, sisi lain tetap redup
///   supaya tidak jadi glare penuh di semua tepi.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? borderColor;
  final bool eco;
  final bool hero;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 20,
    this.borderColor,
    this.eco = true,
    this.hero = false,
  });

  // Hanya ada segelintir nilai saturasi yang pernah dipakai (eco/non-eco),
  // jadi matriksnya dihitung sekali lalu dipakai ulang — GlassCard dipakai
  // di hampir semua panel dan sering rebuild, jadi menghindari alokasi
  // List baru tiap build cukup berarti.
  static final Map<double, List<double>> _vibrancyMatrixCache = {};

  List<double> _vibrancyMatrix(double s) {
    return _vibrancyMatrixCache.putIfAbsent(s, () {
      final inv = 1 - s;
      const lumR = 0.213, lumG = 0.715, lumB = 0.072;
      return <double>[
        lumR * inv + s, lumG * inv, lumB * inv, 0, 0,
        lumR * inv, lumG * inv + s, lumB * inv, 0, 0,
        lumR * inv, lumG * inv, lumB * inv + s, 0, 0,
        0, 0, 0, 1, 0,
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    // PENTING: blur sedalam 16-30 (nilai sebelumnya) melunturkan bokeh di
    // belakang jadi kabut rata tanpa bentuk — bukan "difraksi realistis",
    // itu cuma bikin partikelnya lenyap total. Kaca frosted asli tetap
    // menyisakan bentuk buram, bukan menghapusnya. Diturunkan jauh supaya
    // partikel warna-warni tetap kelihatan sebagai bokeh, cuma buram.
    final blurSigma = eco ? 6.0 : (hero ? 10.0 : 8.0);
    final radiusGeo = BorderRadius.circular(radius);
    final tint = borderColor;

    return ClipRRect(
      borderRadius: radiusGeo,
      // .grouped (bukan BackdropFilter biasa) supaya panel ini berbagi satu
      // "sampel" latar belakang dengan semua GlassCard lain di layar yang
      // sama — lihat BackdropGroup yang membungkus body tiap layar. Tanpa
      // ini, saat panel di-scroll, tiap BackdropFilter menyampel latar di
      // baliknya secara terpisah & sedikit lag satu sama lain, kelihatan
      // sebagai blur yang "berkedip"/tidak konsisten antar frame — bug
      // rendering Flutter yang dikenal (flutter/flutter#104769), makanya
      // solusinya bukan cuma ubah nilai blur tapi ganti mekanismenya.
      child: BackdropFilter.grouped(
        filter: ImageFilter.compose(
          outer: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          inner: ColorFilter.matrix(_vibrancyMatrix(eco ? 1.04 : 1.14)),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: radiusGeo,
            // Volume kaca yang lembut — gradasi dari atas-terang-tipis ke
            // bawah-gelap. Titik gelapnya dinaikkan (0.42 -> 0.56) dan
            // mulai lebih awal (stop 0.3 -> 0.22): bukan buat ubah gaya,
            // tapi supaya bokeh terang di ParticleBackground yang lewat di
            // baliknya tidak "menabrak" teks konten dengan kontras yang
            // naik-turun tidak terduga. Bokeh tetap kelihatan sebagai
            // cahaya buram (itu tetap dipertahankan), cuma lebih diredam
            // sebelum sampai ke lapisan teks di atasnya.
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white.withOpacity(0.055),
                Colors.white.withOpacity(0.02),
                const Color(0xFF0B0F15).withOpacity(0.56),
              ],
              stops: const [0, 0.22, 1],
            ),
            // Tepi kaca tidak lagi rata di semua sisi — sisi ATAS dibuat
            // sedikit lebih terang ("edge-lit") seolah menangkap cahaya
            // dari atas, khas panel kaca premium di app sport-tech
            // (Strava/Komoot). Sisi lain tetap redup supaya tidak jadi
            // glare penuh, cuma kesan tipis di satu sisi ini yang bikin
            // panel terasa punya bentuk/volume, bukan kotak datar polos.
            border: Border(
              top: BorderSide(color: (tint ?? Colors.white).withOpacity(eco ? 0.24 : 0.32), width: 1.1),
              left: BorderSide(color: (tint ?? Colors.white).withOpacity(eco ? 0.10 : 0.14), width: 1),
              right: BorderSide(color: (tint ?? Colors.white).withOpacity(eco ? 0.10 : 0.14), width: 1),
              bottom: BorderSide(color: (tint ?? Colors.white).withOpacity(eco ? 0.10 : 0.14), width: 1),
            ),
            // Shadow tipis tetap dipertahankan bahkan di mode eco (dulu
            // null total) — biayanya jauh lebih murah dibanding blur
            // BackdropFilter, tapi dampaknya besar buat lepas dari kesan
            // "kartu datar nempel di layar" yang plain.
            boxShadow: eco
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.24),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.30),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
