import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Pasangan font ala aplikasi sport-tech modern (Strava/Komoot/Whoop):
/// - [stat] — Sora ExtraBold, geometris & tegas, dipakai untuk angka besar
///   (berat badan, jarak, persentase progress, dsb). Sora dipilih karena
///   lebih "solid"/percaya-diri dibanding font kondensed — kesannya lebih
///   dekat ke tampilan angka besar di app kebugaran modern.
/// - [label] — Inter, huruf kecil kapital dengan tracking lebar, dipakai
///   untuk label/eyebrow di atas angka & body text secara umum.
///
/// Keduanya punya shadow tipis DEFAULT (lihat [_legibilityShadow]) supaya
/// tetap terbaca konsisten di atas ParticleBackground yang ramai/berubah
/// warna di baliknya — bisa dimatikan per pemanggilan lewat `shadows: []`
/// kalau memang perlu teks polos tanpa shadow.
class AppFonts {
  AppFonts._();

  // Shadow tipis & rapat (bukan glow lebar) yang dipakai sebagai DEFAULT di
  // stat & label — bukan buat gaya, tapi jangkar kontras. Latar di
  // belakang teks (ParticleBackground lewat GlassCard yang blur-nya
  // sengaja tipis) itu tidak rata: kadang teks kebetulan nempel di bokeh
  // terang, kadang di area gelap polos. Tanpa shadow, keterbacaan jadi
  // "untung-untungan" tergantung posisi bokeh. Shadow gelap tipis ini
  // menjamin kontras minimum di kondisi TERBURUK (teks di atas bokeh
  // terang) tanpa terlihat sebagai efek di kondisi terbaik (teks di atas
  // area gelap) — itu sebabnya blur-nya kecil & offset-nya nyaris nol.
  static const List<Shadow> _legibilityShadow = [
    Shadow(color: Color(0xCC000000), blurRadius: 5, offset: Offset(0, 1)),
  ];

  static TextStyle stat({
    double size = 16,
    Color color = Colors.white,
    FontWeight weight = FontWeight.w800,
    double? letterSpacing,
    List<Shadow>? shadows,
  }) {
    return GoogleFonts.sora(
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: letterSpacing ?? -0.3,
      height: 1.0,
      shadows: shadows ?? _legibilityShadow,
    );
  }

  static TextStyle label({
    double size = 11,
    Color color = const Color(0xFF93A0B3),
    FontWeight weight = FontWeight.w700,
    double letterSpacing = 1.1,
    List<Shadow>? shadows,
  }) {
    return GoogleFonts.inter(
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: letterSpacing,
      shadows: shadows ?? _legibilityShadow,
    );
  }
}
