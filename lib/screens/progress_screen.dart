import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../app_state.dart';
import '../program.dart';
import '../theme/app_fonts.dart';
import '../widgets/glass_card.dart';

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final accent = state.accentColor;
    final history = state.weightHistorySorted;
    final streak = state.computeStreak();
    final sessions = state.totalSessionsAll;

    // PENTING: fl_chart, kalau tidak dikasih `interval`/`minY`/`maxY`
    // eksplisit, menghitung sendiri jarak antar label sumbu-Y — dan untuk
    // rentang berat yang kecil (mis. 110 -> 112.7 kg, cuma 2.7 kg) itu
    // sering menghasilkan terlalu banyak label buat tinggi chart 200px,
    // sampai teksnya numpuk/tabrakan satu sama lain. Di bawah ini kita
    // hitung sendiri langkah label yang "rapi" (0.5/1/2/5/10 dst.) dari
    // data beratnya, supaya jumlah label selalu masuk akal apa pun
    // rentang beratnya.
    double chartMinY = 0, chartMaxY = 1, chartInterval = 1;
    if (history.length >= 2) {
      final weights = history.map((e) => e.value).toList();
      final minW = weights.reduce((a, b) => a < b ? a : b);
      final maxW = weights.reduce((a, b) => a > b ? a : b);
      final rawRange = (maxW - minW).abs();
      final span = rawRange < 1 ? 1.0 : rawRange;
      // Buletkan target ~4 label jadi salah satu langkah "rapi" standar.
      const niceSteps = [0.5, 1.0, 2.0, 2.5, 5.0, 10.0, 20.0, 50.0];
      double step = niceSteps.last;
      for (final s in niceSteps) {
        if (span / 4 <= s) {
          step = s;
          break;
        }
      }
      chartInterval = step;
      chartMinY = (minW / step).floor() * step - step;
      chartMaxY = (maxW / step).ceil() * step + step;
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        GlassCard(
          eco: state.isEco,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('GRAFIK BERAT BADAN', style: AppFonts.label(size: 12, color: Colors.white, weight: FontWeight.w700, letterSpacing: 0.6)),
                  if (history.length >= 2)
                    // Chip kecil di kanan header nunjukin perubahan sejak
                    // catatan pertama — bukan cuma dekorasi, ini info yang
                    // langsung jawab "kemajuannya gimana" tanpa harus baca
                    // grafiknya baris demi baris.
                    Builder(builder: (context) {
                      final delta = history.last.value - history.first.value;
                      final improving = delta <= 0; // turun berat = progres, utk goal turun berat
                      final deltaColor = improving ? const Color(0xFF4EE0A0) : const Color(0xFFE0A94E);
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: deltaColor.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: deltaColor.withOpacity(0.35), width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              improving ? Icons.trending_down_rounded : Icons.trending_up_rounded,
                              size: 14,
                              color: deltaColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${delta > 0 ? '+' : ''}${delta.toStringAsFixed(1)} kg',
                              style: AppFonts.label(size: 11, color: deltaColor, weight: FontWeight.w700),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 220,
                child: history.length < 2
                    ? const Center(
                        child: Text('Catat berat badan minimal 2x untuk lihat grafik',
                            style: TextStyle(color: Color(0xFF6B7688), fontSize: 12)),
                      )
                    : LineChart(
                        LineChartData(
                          // Grid horizontal SANGAT tipis, selaras dengan
                          // interval label kiri — dulu cuma polos tanpa
                          // acuan sama sekali, sekarang mata bisa
                          // menyusuri satu titik ke label sumbu-nya.
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            horizontalInterval: chartInterval,
                            getDrawingHorizontalLine: (value) => FlLine(
                              color: Colors.white.withOpacity(0.045),
                              strokeWidth: 1,
                            ),
                          ),
                          minY: chartMinY,
                          maxY: chartMaxY,
                          titlesData: FlTitlesData(
                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 38,
                                interval: chartInterval,
                                getTitlesWidget: (value, meta) => Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: Text(
                                    // Cuma tampilkan desimal kalau langkahnya
                                    // memang pecahan (mis. 0.5) — kalau
                                    // langkahnya bulat (1, 2, 5...) label jadi
                                    // bilangan bulat biar tidak berantakan.
                                    chartInterval % 1 == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(1),
                                    style: const TextStyle(color: Color(0xFF6B7688), fontSize: 10),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          // Sentuh & geser di grafik buat lihat angka pasti
                          // tiap titik — sebelumnya statis total, tidak ada
                          // cara baca nilai selain baca ujung garis.
                          lineTouchData: LineTouchData(
                            touchTooltipData: LineTouchTooltipData(
                              getTooltipColor: (_) => const Color(0xFF10151D).withOpacity(0.92),
                              tooltipRoundedRadius: 10,
                              tooltipBorder: BorderSide(color: accent.withOpacity(0.4), width: 1),
                              tooltipPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              getTooltipItems: (spots) => spots
                                  .map((s) => LineTooltipItem(
                                        '${s.y.toStringAsFixed(1)} kg',
                                        AppFonts.label(size: 12, color: Colors.white, weight: FontWeight.w700),
                                      ))
                                  .toList(),
                            ),
                            getTouchedSpotIndicator: (bar, indexes) => indexes
                                .map((i) => TouchedSpotIndicatorData(
                                      FlLine(color: accent.withOpacity(0.5), strokeWidth: 1, dashArray: [4, 4]),
                                      FlDotData(
                                        getDotPainter: (spot, pct, bar, i) =>
                                            FlDotCirclePainter(radius: 4, color: Colors.white, strokeWidth: 2, strokeColor: accent),
                                      ),
                                    ))
                                .toList(),
                          ),
                          lineBarsData: [
                            LineChartBarData(
                              spots: [
                                for (final e in history) FlSpot(e.key.toDouble(), e.value)
                              ],
                              isCurved: true,
                              curveSmoothness: 0.25,
                              barWidth: 3,
                              // Gradasi arah kiri->kanan di garis sendiri —
                              // titik terbaru (kanan) sedikit lebih terang
                              // dari titik pertama (kiri), jadi ada rasa
                              // "menuju sekarang" tanpa perlu teks tambahan.
                              gradient: LinearGradient(
                                colors: [accent.withOpacity(0.55), accent],
                              ),
                              // Titik-titik lama disembunyikan (dulu SEMUA
                              // titik dikasih dot polos ukuran sama —
                              // ramai & tidak ada fokus); yang tersisa
                              // cuma titik TERBARU, dibuat menyala dengan
                              // glow supaya mata langsung ketemu "posisi
                              // sekarang" begitu lihat grafiknya.
                              dotData: FlDotData(
                                show: true,
                                checkToShowDot: (spot, bar) => spot.x == bar.spots.last.x,
                                getDotPainter: (spot, pct, bar, i) => FlDotCirclePainter(
                                  radius: 5,
                                  color: accent,
                                  strokeWidth: 3,
                                  strokeColor: accent.withOpacity(0.35),
                                ),
                              ),
                              belowBarData: BarAreaData(
                                show: true,
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [accent.withOpacity(0.22), accent.withOpacity(0.0)],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // PENTING: kedelapan stat ini dulu masing-masing punya GlassCard
        // (BackdropFilter+blur) SENDIRI-SENDIRI — artinya 8 operasi blur
        // mahal berjalan bersamaan di dalam satu scrollview, ditambah 1
        // dari kartu grafik di atas = 9 total. Banyaknya BackdropFilter
        // aktif bersamaan yang menyampel latar partikel yang terus
        // bergerak inilah penyebab paling mungkin dari flicker/jank saat
        // discroll — bukan soal BackdropGroup gagal bekerja, tapi murni
        // beban render. Sekarang cuma 1 GlassCard (blur SEKALI) berisi
        // grid ubin polos (tanpa blur masing-masing) di dalamnya — efek
        // kaca & partikel di baliknya tetap kelihatan (panelnya tetap
        // transparan blur), cuma sumber blur-nya jadi satu, bukan delapan.
        GlassCard(
          eco: state.isEco,
          padding: const EdgeInsets.all(12),
          child: GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 4,
            crossAxisSpacing: 10,
            childAspectRatio: 1.9,
            children: [
              _MiniStat(icon: PhosphorIconsFill.scales, color: accent, label: 'Berat sekarang', value: '${state.currentWeight.toStringAsFixed(1)} kg'),
              _MiniStat(icon: PhosphorIconsFill.target, color: const Color(0xFF4E9BE0), label: 'Sisa target', value: '${(state.currentWeight - state.settings.goalWeight).clamp(0, 999).toStringAsFixed(1)} kg'),
              _MiniStat(icon: PhosphorIconsFill.bicycle, color: const Color(0xFF4EE0A0), label: 'Total jarak', value: '${state.totalKmAll.toStringAsFixed(0)} km'),
              _MiniStat(icon: PhosphorIconsFill.lightning, color: const Color(0xFFD97757), label: 'Estimasi kalori', value: '${state.totalCaloriesAll} kkal'),
              _MiniStat(icon: PhosphorIconsFill.checkCircle, color: const Color(0xFF7FE04E), label: 'Sesi selesai', value: '${sessions.done}/${sessions.total}'),
              _MiniStat(icon: PhosphorIconsFill.fire, color: const Color(0xFFE0A94E), label: 'Streak sekarang', value: '${streak.current} hari'),
              _MiniStat(icon: PhosphorIconsFill.trophy, color: const Color(0xFFE0C64E), label: 'Streak terbaik', value: '${streak.best} hari'),
              _MiniStat(
                icon: PhosphorIconsFill.percent,
                color: const Color(0xFF8A7FD1),
                label: 'Konsistensi',
                value: sessions.total > 0 ? '${(sessions.done / sessions.total * 100).round()}%' : '0%',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Ubin stat POLOS (tanpa BackdropFilter sendiri) — dipakai di dalam SATU
/// GlassCard bersama, bukan masing-masing punya panel kaca sendiri. Lihat
/// catatan performa di atas untuk alasannya.
class _MiniStat extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  const _MiniStat({required this.icon, required this.color, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withOpacity(0.16),
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.35), width: 1),
            ),
            child: Icon(icon, size: 17, color: color),
          ),
          const SizedBox(height: 8),
          Text(label, style: AppFonts.label(size: 9.5, letterSpacing: 0.6)),
          const SizedBox(height: 3),
          Text(value, style: AppFonts.stat(size: 16)),
        ],
      ),
    );
  }
}
