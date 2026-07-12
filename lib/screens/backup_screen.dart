import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../app_state.dart';
import '../program.dart';
import '../theme/app_fonts.dart';
import '../widgets/glass_card.dart';

class BackupScreen extends StatelessWidget {
  const BackupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        GlassCard(
          eco: state.isEco,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('RIWAYAT AKSI', style: AppFonts.label(size: 12, color: Colors.white, weight: FontWeight.w700, letterSpacing: 0.6)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: state.canUndo ? state.undo : null,
                      icon: Icon(PhosphorIconsBold.arrowCounterClockwise, size: 18),
                      label: const Text('Undo'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: state.canRedo ? state.redo : null,
                      icon: Icon(PhosphorIconsBold.arrowClockwise, size: 18),
                      label: const Text('Redo'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        GlassCard(
          eco: state.isEco,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('BAGIKAN RINGKASAN', style: AppFonts.label(size: 12, color: Colors.white, weight: FontWeight.w700, letterSpacing: 0.6)),
              const SizedBox(height: 10),
              const Text(
                'Kirim progress kamu (berat, jarak, streak) ke aplikasi lain.',
                style: TextStyle(fontSize: 12, color: Color(0xFF93A0B3)),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _shareSummary(state),
                  icon: Icon(PhosphorIconsBold.shareNetwork, size: 18),
                  label: const Text('Bagikan'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        GlassCard(
          eco: state.isEco,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('BACKUP DATA', style: AppFonts.label(size: 12, color: Colors.white, weight: FontWeight.w700, letterSpacing: 0.6)),
              const SizedBox(height: 10),
              const Text(
                'Semua data tersimpan otomatis di HP kamu. Bagikan file JSON di bawah ini sebagai cadangan.',
                style: TextStyle(fontSize: 12, color: Color(0xFF93A0B3)),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _exportData(state),
                  icon: Icon(PhosphorIconsBold.downloadSimple, size: 18),
                  label: const Text('Export Data (JSON)'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        GlassCard(
          eco: state.isEco,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('TENTANG', style: AppFonts.label(size: 12, color: Colors.white, weight: FontWeight.w700, letterSpacing: 0.6)),
              const SizedBox(height: 10),
              const Text('Progress Sepeda Hub v1.0 — Flutter native app',
                  style: TextStyle(fontSize: 12, color: Color(0xFF93A0B3))),
            ],
          ),
        ),
      ],
    );
  }

  void _shareSummary(AppState state) {
    final kgLost = state.settings.startWeight - state.currentWeight;
    final streak = state.computeStreak();
    final km = state.totalKmAll;
    final text = '🚴 Progress Sepeda Hub\n'
        'Berat: ${state.currentWeight.toStringAsFixed(1)}kg (turun ${kgLost > 0 ? kgLost.toStringAsFixed(1) : 0}kg dari ${state.settings.startWeight.toStringAsFixed(0)} kg)\n'
        'Total jarak: ${km.toStringAsFixed(0)} km\n'
        'Streak: ${streak.current} hari (terbaik ${streak.best} hari)\n'
        'Target: ${state.settings.goalWeight.toStringAsFixed(0)} kg';
    Share.share(text);
  }

  void _exportData(AppState state) {
    Share.share(state.exportJson(), subject: 'progress-hub-backup.json');
  }
}
