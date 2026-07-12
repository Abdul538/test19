import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../app_state.dart';
import '../program.dart';
import '../widgets/particle_background.dart';
import '../widgets/app_header.dart';
import 'today_screen.dart';
import 'progress_screen.dart';
import 'backup_screen.dart';
import 'program_settings_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final accent = state.accentColor;
    final screens = const [TodayScreen(), ProgressScreen(), BackupScreen()];
    final phase = phaseFor(state.week, state.settings.totalWeeks);
    final streak = state.computeStreak();

    return Scaffold(
      extendBodyBehindAppBar: false,
      // false: body (dan partikel di dalamnya) TIDAK mengecil saat keyboard
      // muncul. Sebelumnya (default true) area body ikut mengecil setiap
      // kali keyboard buka/tutup — itu mengubah ukuran layout yang dibaca
      // ParticleBackground, memicu SEMUA partikel di-generate ulang dari
      // posisi acak baru setiap kali keyboard toggle, kelihatan seperti
      // "reset mendadak". List konten yang ada TextField (km, catat berat)
      // tetap otomatis scroll ke atas keyboard sendiri karena sudah ada di
      // dalam ListView — jadi field yang diketik tetap kelihatan.
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          Positioned.fill(
            child: ParticleBackground(eco: state.isEco, accent: accent),
          ),
          // BackdropGroup membungkus SEMUA GlassCard di layar (header +
          // ketiga tab) supaya BackdropFilter.grouped di dalamnya berbagi
          // satu titik sampel latar — ini yang menghilangkan efek blur
          // "berkedip"/tidak konsisten saat panel di-scroll. Particle
          // background sengaja tetap DI LUAR grup ini (tetap sibling di
          // belakang), karena dialah yang justru harus disampel, bukan
          // ikut jadi bagian dari grup filter.
          BackdropGroup(
            child: Column(
              children: [
                AppHeader(
                  accent: accent,
                  phaseColor: phase.color,
                  phaseName: phase.name,
                  week: state.week,
                  totalWeeks: state.settings.totalWeeks,
                  streakCurrent: streak.current,
                  currentWeight: state.currentWeight,
                  startWeight: state.settings.startWeight,
                  goalWeight: state.settings.goalWeight,
                  eco: state.isEco,
                  onSettingsTap: () => _openSettings(context),
                ),
                Expanded(
                  child: IndexedStack(index: _tab, children: screens),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        backgroundColor: const Color(0xFF0C0F14).withOpacity(0.92),
        indicatorColor: accent.withOpacity(0.18),
        destinations: [
          NavigationDestination(
            icon: Icon(PhosphorIconsBold.bicycle),
            selectedIcon: Icon(PhosphorIconsFill.bicycle),
            label: 'Hari Ini',
          ),
          NavigationDestination(
            icon: Icon(PhosphorIconsBold.chartLineUp),
            selectedIcon: Icon(PhosphorIconsFill.chartLineUp),
            label: 'Progress',
          ),
          NavigationDestination(
            icon: Icon(PhosphorIconsBold.cloudArrowUp),
            selectedIcon: Icon(PhosphorIconsFill.cloudArrowUp),
            label: 'Backup',
          ),
        ],
      ),
    );
  }

  void _openSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF10141B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => const _SettingsSheet(),
    );
  }
}

class _SettingsSheet extends StatelessWidget {
  const _SettingsSheet();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('PENGATURAN', style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.8)),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ProgramSettingsScreen()),
                );
              },
              icon: Icon(PhosphorIconsBold.calendarCheck, size: 18),
              label: const Text('Pengaturan Program & Jadwal'),
            ),
          ),
          const SizedBox(height: 18),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Getar (Haptic)'),
            value: state.hapticEnabled,
            onChanged: (v) => state.setHaptic(v),
          ),
          const SizedBox(height: 14),
          Text('TEMA AKSEN', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: const Color(0xFF6B7688))),
          const SizedBox(height: 10),
          Row(
            children: accentColors.entries.map((e) {
              final active = state.accentTheme == e.key;
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: GestureDetector(
                  onTap: () => state.setAccent(e.key),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: e.value,
                      shape: BoxShape.circle,
                      border: Border.all(color: active ? Colors.white : Colors.transparent, width: 2),
                      boxShadow: active
                          ? [BoxShadow(color: e.value.withOpacity(0.6), blurRadius: 10, spreadRadius: 1)]
                          : null,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

