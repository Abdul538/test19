import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../theme/app_fonts.dart';

/// Header utama ala aplikasi sport-tech (Strava/Komoot): bukan cuma judul
/// di tengah, tapi identitas program + strip statistik ringkas yang selalu
/// terlihat di semua tab — mirip header profil/ringkasan di Strava.
///
/// Struktur:
/// - Baris atas: lencana ikon (gradient aksen) + label program & judul,
///   badge fase program di kanan judul, tombol pengaturan di ujung kanan.
/// - Strip statistik: minggu berjalan, streak, berat saat ini — dipisah
///   garis tipis, angka pakai AppFonts.stat supaya terasa tegas.
/// - Alas kaca tipis (frosted glass otentik): blur ringan + opacity rendah
///   supaya partikel bokeh di ParticleBackground tetap tembus & terlihat
///   bergerak di baliknya — tanpa garis highlight atau grain putih yang
///   dulu terbaca sebagai "glare".
class AppHeader extends StatelessWidget {
  final Color accent;
  final Color phaseColor;
  final String phaseName;
  final int week;
  final int totalWeeks;
  final int streakCurrent;
  final double currentWeight;
  final double startWeight;
  final double goalWeight;
  final VoidCallback onSettingsTap;
  final bool eco;

  const AppHeader({
    super.key,
    required this.accent,
    required this.phaseColor,
    required this.phaseName,
    required this.week,
    required this.totalWeeks,
    required this.streakCurrent,
    required this.currentWeight,
    required this.startWeight,
    required this.goalWeight,
    required this.onSettingsTap,
    required this.eco,
  });

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    return ClipRRect(
      child: BackdropFilter(
        // Blur diturunkan lagi (12 -> 8, mode eco 8 -> 5) supaya bokeh warna
        // dari ParticleBackground di belakang header masih kelihatan jelas
        // saat menembus panel, bukan sekadar buram putih rata.
        filter: ImageFilter.blur(sigmaX: eco ? 5 : 8, sigmaY: eco ? 5 : 8),
        child: Container(
          padding: EdgeInsets.fromLTRB(16, topPad + 10, 16, 12),
          decoration: BoxDecoration(
            // Opacity diturunkan lagi (0.50/0.34 -> 0.30/0.18) supaya
            // partikel bokeh di belakang benar-benar tembus & terlihat,
            // bukan sekadar teori "harusnya kelihatan".
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF0C0F14).withOpacity(0.30),
                const Color(0xFF0C0F14).withOpacity(0.18),
              ],
            ),
            border: Border(
              bottom: BorderSide(color: Colors.white.withOpacity(0.08), width: 1),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Lencana ikon dengan gradient aksen — pengganti ruang
                      // kosong di sisi kiri AppBar sebelumnya.
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [accent, accent.withOpacity(0.55)],
                          ),
                          boxShadow: [
                            BoxShadow(color: accent.withOpacity(0.35), blurRadius: 14, spreadRadius: -2),
                          ],
                        ),
                        child: const Icon(PhosphorIconsFill.bicycle, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('PROGRAM PENURUNAN BERAT', style: AppFonts.label(size: 9.5, letterSpacing: 1.3)),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    '${startWeight.toInt()} → ${goalWeight.toInt()} KG',
                                    overflow: TextOverflow.ellipsis,
                                    style: AppFonts.stat(size: 18, weight: FontWeight.w800, letterSpacing: -0.2),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: phaseColor.withOpacity(0.14),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: phaseColor.withOpacity(0.4), width: 1),
                                  ),
                                  child: Text(
                                    phaseName,
                                    style: TextStyle(color: phaseColor, fontSize: 10.5, fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      _SettingsButton(onTap: onSettingsTap),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Strip statistik ringkas — mengisi ruang kosong di bawah
                  // judul, mirip ringkasan cepat di header Strava/Komoot.
                  Row(
                    children: [
                      Expanded(
                        child: _HeaderStat(
                          icon: PhosphorIconsBold.calendarBlank,
                          label: 'MINGGU',
                          value: '$week/$totalWeeks',
                          color: accent,
                        ),
                      ),
                      _divider(),
                      Expanded(
                        child: _HeaderStat(
                          icon: PhosphorIconsBold.fire,
                          label: 'STREAK',
                          value: '$streakCurrent hari',
                          color: const Color(0xFFE0A94E),
                        ),
                      ),
                      _divider(),
                      Expanded(
                        child: _HeaderStat(
                          icon: PhosphorIconsBold.scales,
                          label: 'BERAT',
                          value: '${currentWeight.toStringAsFixed(1)} kg',
                          color: accent,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
        ),
      ),
    );
  }

  Widget _divider() => Container(
        width: 1,
        height: 28,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        color: Colors.white.withOpacity(0.08),
      );
}

class _HeaderStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _HeaderStat({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(value, style: AppFonts.stat(size: 13, weight: FontWeight.w700)),
            Text(label, style: AppFonts.label(size: 8.5, letterSpacing: 1.0)),
          ],
        ),
      ],
    );
  }
}

class _SettingsButton extends StatelessWidget {
  final VoidCallback onTap;
  const _SettingsButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.06),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.all(9),
          child: Icon(PhosphorIconsBold.slidersHorizontal, size: 18),
        ),
      ),
    );
  }
}
