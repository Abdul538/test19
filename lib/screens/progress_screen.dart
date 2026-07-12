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

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        GlassCard(
          eco: state.isEco,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('GRAFIK BERAT BADAN', style: AppFonts.label(size: 12, color: Colors.white, weight: FontWeight.w700, letterSpacing: 0.6)),
              const SizedBox(height: 16),
              SizedBox(
                height: 200,
                child: history.length < 2
                    ? const Center(
                        child: Text('Catat berat badan minimal 2x untuk lihat grafik',
                            style: TextStyle(color: Color(0xFF6B7688), fontSize: 12)),
                      )
                    : LineChart(
                        LineChartData(
                          gridData: const FlGridData(show: false),
                          titlesData: const FlTitlesData(
                            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 34)),
                          ),
                          borderData: FlBorderData(show: false),
                          lineBarsData: [
                            LineChartBarData(
                              spots: [
                                for (final e in history) FlSpot(e.key.toDouble(), e.value)
                              ],
                              isCurved: true,
                              color: accent,
                              barWidth: 3,
                              dotData: const FlDotData(show: true),
                              belowBarData: BarAreaData(show: true, color: accent.withOpacity(0.12)),
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
