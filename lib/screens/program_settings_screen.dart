import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../app_state.dart';
import '../program.dart';
import '../theme/app_fonts.dart';
import '../widgets/glass_card.dart';
import '../widgets/route_path_painter.dart';
import 'home_shell.dart';

/// Layar khusus untuk mengustomisasi seluruh parameter program lewat UI —
/// bukan lagi konstanta tetap di kode. Perubahan disimpan sebagai draft
/// lokal dulu (supaya bisa dibatalkan) dan baru diterapkan ke [AppState]
/// saat pengguna menekan "Simpan Pengaturan".
class ProgramSettingsScreen extends StatefulWidget {
  /// Saat true, layar ini tampil sebagai panel setup pertama kali: tanpa
  /// tombol kembali, tombol simpan berlabel "Mulai Program", dan menutup
  /// dirinya dengan pushReplacement ke HomeShell alih-alih Navigator.pop.
  final bool isOnboarding;
  const ProgramSettingsScreen({super.key, this.isOnboarding = false});

  @override
  State<ProgramSettingsScreen> createState() => _ProgramSettingsScreenState();
}

class _ProgramSettingsScreenState extends State<ProgramSettingsScreen> {
  late ProgramSettings _draft;
  late TextEditingController _startWeightCtrl;
  late TextEditingController _goalWeightCtrl;
  late TextEditingController _weeksCtrl;

  @override
  void initState() {
    super.initState();
    _draft = context.read<AppState>().settings;
    // Saat setup pertama kali (onboarding), field target sengaja dikosongkan
    // ke 0 alih-alih diisi contoh angka (110/80/26) — supaya pengguna baru
    // tidak salah kira itu target mereka sendiri dan lupa menggantinya.
    // Saat mengedit pengaturan yang sudah ada, field tetap menampilkan
    // nilai aktual pengguna seperti biasa.
    final startText = widget.isOnboarding ? '0' : _draft.startWeight.toStringAsFixed(0);
    final goalText = widget.isOnboarding ? '0' : _draft.goalWeight.toStringAsFixed(0);
    final weeksText = widget.isOnboarding ? '0' : '${_draft.totalWeeks}';
    _startWeightCtrl = TextEditingController(text: startText);
    _goalWeightCtrl = TextEditingController(text: goalText);
    _weeksCtrl = TextEditingController(text: weeksText);
  }

  @override
  void dispose() {
    _startWeightCtrl.dispose();
    _goalWeightCtrl.dispose();
    _weeksCtrl.dispose();
    super.dispose();
  }

  void _update(ProgramSettings Function(ProgramSettings) fn) {
    setState(() => _draft = fn(_draft));
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _draft.startDate,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2035, 12, 31),
      builder: (ctx, child) {
        return Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: Theme.of(ctx).colorScheme.copyWith(
                  surface: const Color(0xFF10141B),
                ),
            dialogBackgroundColor: const Color(0xFF10141B),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      _update((s) => s.copyWith(startDate: picked));
    }
  }

  void _toggleRestDay(String key) {
    final rest = {..._draft.restDayKeys};
    if (rest.contains(key)) {
      rest.remove(key);
    } else {
      rest.add(key);
    }
    _update((s) => s.copyWith(restDayKeys: rest));
  }

  void _save() {
    final startWeight = double.tryParse(_startWeightCtrl.text.replaceAll(',', '.')) ?? _draft.startWeight;
    final goalWeight = double.tryParse(_goalWeightCtrl.text.replaceAll(',', '.')) ?? _draft.goalWeight;
    final weeks = int.tryParse(_weeksCtrl.text) ?? _draft.totalWeeks;

    String? error;
    if (startWeight <= 0 || goalWeight <= 0) {
      error = 'Isi dulu berat awal & berat target (tidak boleh 0).';
    } else if (weeks < 1) {
      error = 'Jumlah minggu minimal 1.';
    } else if (goalWeight >= startWeight) {
      error = 'Berat target harus lebih kecil dari berat awal.';
    } else if (!widget.isOnboarding) {
      final recordedMax = context.read<AppState>().highestRecordedWeek;
      if (weeks < recordedMax) {
        error = 'Jumlah minggu tidak bisa dikurangi sampai di bawah minggu $recordedMax — progres kamu sudah tercatat sampai sana.';
      }
    }
    if (error != null) {
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: const Color(0xFF7A2E2E)),
      );
      return;
    }

    final finalSettings = _draft.copyWith(
      startWeight: startWeight,
      goalWeight: goalWeight,
      totalWeeks: weeks,
    );
    HapticFeedback.mediumImpact();
    if (widget.isOnboarding) {
      context.read<AppState>().completeInitialSetup(finalSettings);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeShell()),
      );
      return;
    }
    context.read<AppState>().updateSettings(finalSettings);
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Pengaturan program disimpan')),
    );
  }

  void _resetToDefault() {
    final d = ProgramSettings.defaults();
    setState(() {
      _draft = d;
      _startWeightCtrl.text = d.startWeight.toStringAsFixed(0);
      _goalWeightCtrl.text = d.goalWeight.toStringAsFixed(0);
      _weeksCtrl.text = '${d.totalWeeks}';
    });
  }

  @override
  Widget build(BuildContext context) {
    final accent = context.watch<AppState>().accentColor;
    // Draft yang dipakai untuk pratinjau memakai nilai terbaru dari field
    // teks juga (supaya pratinjau minggu ikut update saat mengetik jumlah
    // minggu), tapi tetap toleran kalau field sedang kosong/tidak valid.
    final previewWeeks = int.tryParse(_weeksCtrl.text) ?? _draft.totalWeeks;
    final previewDraft = _draft.copyWith(totalWeeks: previewWeeks < 1 ? 1 : previewWeeks);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0D12),
      body: Column(
        children: [
          _ProgramSettingsHeader(
            isOnboarding: widget.isOnboarding,
            accent: accent,
            onBack: () => Navigator.of(context).maybePop(),
            onReset: _resetToDefault,
          ),
          Expanded(
            child: BackdropGroup(
              child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
              children: [
          if (widget.isOnboarding) ...[
            _OnboardingHero(
              accent: accent,
              startText: _startWeightCtrl.text,
              goalText: _goalWeightCtrl.text,
              weeksText: _weeksCtrl.text,
            ).animate().fadeIn(duration: 420.ms).slideY(begin: 0.06, end: 0, curve: Curves.easeOutCubic),
            const SizedBox(height: 22),
          ] else ...[
            GlassCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(PhosphorIconsBold.check, size: 22, color: accent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Ubah target berat, durasi, atau jadwal sebebas apa pun — progres yang sudah kamu catat (centang harian, jarak, riwayat berat) tetap aman dan tidak akan tereset.',
                      style: const TextStyle(fontSize: 12.5, color: Color(0xFFB7C0CF), height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
          _section(
            widget.isOnboarding,
            1,
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader('TARGET BERAT BADAN', PhosphorIconsBold.scales, accent),
                const SizedBox(height: 10),
                GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: _NumberField(
                          label: 'Berat awal (kg)',
                          controller: _startWeightCtrl,
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(PhosphorIconsBold.arrowRight, size: 18, color: const Color(0xFF6B7688)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _NumberField(
                          label: 'Berat target (kg)',
                          controller: _goalWeightCtrl,
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          _section(
            widget.isOnboarding,
            2,
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader('DURASI PROGRAM', PhosphorIconsBold.calendarBlank, accent),
                const SizedBox(height: 10),
                GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: _NumberField(
                          label: 'Jumlah minggu',
                          controller: _weeksCtrl,
                          decimal: false,
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _StepperButton(
                            icon: PhosphorIconsBold.plus,
                            onTap: () {
                              final v = (int.tryParse(_weeksCtrl.text) ?? _draft.totalWeeks) + 1;
                              setState(() => _weeksCtrl.text = '$v');
                            },
                          ),
                          const SizedBox(height: 6),
                          _StepperButton(
                            icon: PhosphorIconsBold.minus,
                            onTap: () {
                              final v = (int.tryParse(_weeksCtrl.text) ?? _draft.totalWeeks) - 1;
                              setState(() => _weeksCtrl.text = '${v < 1 ? 1 : v}');
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          _section(
            widget.isOnboarding,
            3,
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader('HARI MULAI PROGRAM', PhosphorIconsBold.calendarCheck, accent),
                const SizedBox(height: 10),
                GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Tanggal mulai', style: AppFonts.label(size: 10.5, letterSpacing: 0.6)),
                            const SizedBox(height: 4),
                            Text(
                              '${dayLabelsFullId[_draft.startDate.weekday % 7]}, ${formatDateId(_draft.startDate)}',
                              style: AppFonts.stat(size: 15),
                            ),
                          ],
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _pickStartDate,
                        icon: Icon(PhosphorIconsBold.calendarBlank, size: 16),
                        label: const Text('Pilih'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          _section(
            widget.isOnboarding,
            4,
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader('HARI LIBUR / ISTIRAHAT', PhosphorIconsBold.moon, accent),
                const SizedBox(height: 6),
                Text(
                  'Ketuk untuk menandai hari sebagai libur. Minimal harus ada 2 hari latihan tersisa.',
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF6B7688)),
                ),
                const SizedBox(height: 10),
                GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final key in dayKeysByDow)
                        _DayChip(
                          label: dayLabelsFullId[dayKeysByDow.indexOf(key)],
                          active: _draft.restDayKeys.contains(key),
                          activeColor: const Color(0xFF6B7688),
                          onTap: () => _toggleRestDay(key),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          _section(
            widget.isOnboarding,
            5,
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader('PRATINJAU JADWAL', PhosphorIconsBold.calendarBlank, accent),
                const SizedBox(height: 10),
                _SchedulePreview(settings: previewDraft, accent: accent),
              ],
            ),
          ),
          const SizedBox(height: 24),

          _section(
            widget.isOnboarding,
            6,
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.black,
                  elevation: widget.isOnboarding ? 8 : 0,
                  shadowColor: accent.withOpacity(0.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.isOnboarding ? 'Mulai Program' : 'Simpan Pengaturan',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15.5),
                    ),
                    if (widget.isOnboarding) ...[
                      const SizedBox(width: 8),
                      const Icon(PhosphorIconsBold.arrowRight, size: 18),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
            ),
          ),
        ],
      ),
    );
  }

  /// Bungkus satu blok section dengan animasi masuk bertahap — TAPI hanya
  /// saat setup pertama kali (onboarding). Saat mengedit pengaturan yang
  /// sudah ada, layar ini bisa dibuka-tutup berkali-kali, jadi sengaja
  /// dibuat instan tanpa animasi supaya tidak terasa lambat/mengganggu.
  Widget _section(bool animated, int index, Widget child) {
    if (!animated) return child;
    return child.animate().fadeIn(duration: 340.ms, delay: (90 * index).ms).slideY(begin: 0.05, end: 0, curve: Curves.easeOutCubic);
  }

  Widget _sectionTitle(String t) => Text(t, style: AppFonts.label(size: 11.5, letterSpacing: 0.8));

  /// Header section dengan badge ikon berwarna — dipakai supaya tiap
  /// bagian form (target berat, durasi, hari mulai, dst) terasa seperti
  /// langkah yang jelas & mudah dipindai matanya, bukan cuma daftar label
  /// abu-abu polos yang seragam semua.
  Widget _sectionHeader(String title, IconData icon, Color accent) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [accent.withOpacity(0.28), accent.withOpacity(0.10)],
            ),
            shape: BoxShape.circle,
            border: Border.all(color: accent.withOpacity(0.45)),
            boxShadow: [BoxShadow(color: accent.withOpacity(0.25), blurRadius: 10, spreadRadius: -1)],
          ),
          child: Icon(icon, size: 14, color: accent),
        ),
        const SizedBox(width: 10),
        Text(title, style: AppFonts.label(size: 11.5, letterSpacing: 0.8)),
      ],
    );
  }
}

/// Header tetap (tidak ikut scroll) untuk layar pengaturan program —
/// pengganti AppBar polos sebelumnya. Dirancang biar bagian atas layar
/// langsung terasa "sport-tech" sejak detik pertama dibuka: lencana ikon
/// bergradasi, tipografi besar & tegas (AppFonts.stat), jejak rute GPS
/// dekoratif (RoutePathBackground) sebagai identitas visual, dan tombol
/// aksi berbentuk pil kaca alih-alih ikon polos di AppBar.
class _ProgramSettingsHeader extends StatelessWidget {
  final bool isOnboarding;
  final Color accent;
  final VoidCallback onBack;
  final VoidCallback onReset;
  const _ProgramSettingsHeader({
    required this.isOnboarding,
    required this.accent,
    required this.onBack,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF12161F), Color(0xFF0A0D12)],
        ),
        border: Border(bottom: BorderSide(color: accent.withOpacity(0.20), width: 1)),
      ),
      child: ClipRect(
        child: Stack(
          children: [
            // Jejak rute GPS + glow — elemen "tanda tangan" visual header,
            // diletakkan mengambang di seluruh area (termasuk di balik
            // status bar) supaya terasa full-bleed, bukan kotak sempit.
            Positioned.fill(child: RoutePathBackground(accent: accent)),
            Padding(
              padding: EdgeInsets.fromLTRB(16, topPad + 14, 16, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (!isOnboarding)
                        _HeaderPillButton(icon: PhosphorIconsBold.arrowLeft, onTap: onBack)
                      else
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(colors: [accent, accent.withOpacity(0.55)]),
                            boxShadow: [BoxShadow(color: accent.withOpacity(0.4), blurRadius: 16, spreadRadius: -2)],
                          ),
                          child: const Icon(PhosphorIconsFill.bicycle, color: Colors.black, size: 20),
                        ),
                      const Spacer(),
                      _HeaderPillButton(
                        icon: PhosphorIconsBold.arrowCounterClockwise,
                        label: 'Reset',
                        onTap: onReset,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    isOnboarding ? 'MULAI PERJALANANMU' : 'KELOLA PROGRAM',
                    style: AppFonts.label(size: 11, letterSpacing: 1.5, color: accent),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isOnboarding ? 'Atur Target Program' : 'Pengaturan Program & Jadwal',
                    style: AppFonts.stat(size: 26, weight: FontWeight.w800, letterSpacing: -0.6),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    isOnboarding
                        ? 'Tetapkan target berat & durasi — sisanya biar kita yang susun jadwalnya.'
                        : 'Ubah target, durasi, atau jadwal kapan pun — progres yang sudah tercatat tetap aman.',
                    style: const TextStyle(fontSize: 12.5, color: Color(0xFF9AA6B8), height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tombol aksi bentuk pil kaca tipis — dipakai untuk "kembali" & "reset"
/// di header, pengganti IconButton polos ala Material default supaya
/// konsisten dengan bahasa visual kaca (GlassCard) di seluruh app.
class _HeaderPillButton extends StatelessWidget {
  final IconData icon;
  final String? label;
  final VoidCallback onTap;
  const _HeaderPillButton({required this.icon, this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: label != null ? 13 : 10, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: Colors.white),
                if (label != null) ...[
                  const SizedBox(width: 6),
                  Text(label!, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.white)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Kartu hero untuk setup pertama kali: bukan cuma teks sambutan statis,
/// tapi tampilan besar & LANGSUNG BEREAKSI — begitu pengguna mengetik berat
/// awal & target, angkanya langsung membesar di sini secara live, plus
/// badge "turun X kg dalam Y minggu" begitu keduanya valid. Ini yang jadi
/// elemen paling berkesan di layar setup — bukan form biasa, tapi pratinjau
/// transformasi yang hidup, khas app sport-tech (Strava/Whoop-style).
class _OnboardingHero extends StatelessWidget {
  final Color accent;
  final String startText;
  final String goalText;
  final String weeksText;
  const _OnboardingHero({
    required this.accent,
    required this.startText,
    required this.goalText,
    required this.weeksText,
  });

  @override
  Widget build(BuildContext context) {
    final start = double.tryParse(startText.replaceAll(',', '.'));
    final goal = double.tryParse(goalText.replaceAll(',', '.'));
    final weeks = int.tryParse(weeksText);
    final hasStart = start != null && start > 0;
    final hasGoal = goal != null && goal > 0;
    final delta = (hasStart && hasGoal) ? (start - goal) : null;

    return GlassCard(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [accent.withOpacity(0.35), accent.withOpacity(0.08)]),
                  border: Border.all(color: accent.withOpacity(0.5), width: 1.2),
                  boxShadow: [BoxShadow(color: accent.withOpacity(0.35), blurRadius: 18, spreadRadius: 1)],
                ),
                child: Icon(PhosphorIconsBold.bicycle, size: 22, color: accent),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('PROGRAM PENURUNAN BERAT', style: AppFonts.label(size: 11, letterSpacing: 1.0, color: accent)),
                    const SizedBox(height: 3),
                    const Text(
                      'Tetapkan target kamu, kita yang urus jadwalnya',
                      style: TextStyle(fontSize: 12, color: Color(0xFF9AA6B8), height: 1.3),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(hasStart ? start!.toStringAsFixed(0) : '--', style: AppFonts.stat(size: 40, color: Colors.white)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                child: Icon(PhosphorIconsBold.arrowRight, size: 20, color: const Color(0xFF5A6577)),
              ),
              Text(hasGoal ? goal!.toStringAsFixed(0) : '--', style: AppFonts.stat(size: 40, color: accent)),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('KG', style: AppFonts.label(size: 12, letterSpacing: 0.5)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (delta != null && delta > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: accent.withOpacity(0.14),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: accent.withOpacity(0.35)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(PhosphorIconsBold.target, size: 13, color: accent),
                  const SizedBox(width: 6),
                  Text(
                    weeks != null && weeks > 0
                        ? 'Turun ${delta.toStringAsFixed(0)} kg dalam $weeks minggu'
                        : 'Turun ${delta.toStringAsFixed(0)} kg',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: accent),
                  ),
                ],
              ),
            )
          else
            Text(
              'Isi target berat di bawah buat lihat perkiraan progres kamu',
              style: const TextStyle(fontSize: 11.5, color: Color(0xFF6B7688)),
            ),
        ],
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final bool decimal;
  const _NumberField({required this.label, required this.controller, this.onChanged, this.decimal = true});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppFonts.label(size: 10.5, letterSpacing: 0.6)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: TextInputType.numberWithOptions(decimal: decimal),
          style: AppFonts.stat(size: 16),
          onChanged: onChanged,
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFF0A0D12),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF232A35)),
            ),
          ),
        ),
      ],
    );
  }
}

class _StepperButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _StepperButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1C222C),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: Icon(icon, size: 15),
        ),
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  final String label;
  final bool active;
  final Color activeColor;
  final bool disabled;
  final VoidCallback onTap;
  const _DayChip({
    required this.label,
    required this.active,
    required this.activeColor,
    required this.onTap,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: active ? activeColor.withOpacity(0.18) : const Color(0xFF10141B),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active ? activeColor : const Color(0xFF232A35),
            width: active ? 1.4 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: disabled
                ? const Color(0xFF3A4353)
                : (active ? Colors.white : const Color(0xFFA3AEBD)),
          ),
        ),
      ),
    );
  }
}

/// Ringkasan visual: panjang minggu pertama (parsial, mengikuti hari mulai
/// pengguna, selesai Sabtu) dan konfirmasi bahwa minggu ke-2 dst selalu
/// genap Minggu→Sabtu, plus peran tiap hari dalam seminggu (libur / jarak
/// jauh / latihan berat / latihan ringan).
class _SchedulePreview extends StatelessWidget {
  final ProgramSettings settings;
  final Color accent;
  const _SchedulePreview({required this.settings, required this.accent});

  @override
  Widget build(BuildContext context) {
    final week1End = settings.startDate.add(Duration(days: settings.week1Length - 1));
    final roles = computeDayRoles(settings);
    final isFullWeek = settings.week1Length == 7;
    const restColor = Color(0xFF5A6577);

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(PhosphorIconsBold.calendarBlank, size: 15, color: accent),
              const SizedBox(width: 6),
              Text('CARA JADWAL DISUSUN', style: AppFonts.label(size: 11, letterSpacing: 0.7)),
            ],
          ),
          const SizedBox(height: 16),
          _TimelineStep(
            dotColor: accent,
            lineColor: accent.withOpacity(0.3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text('Minggu 1', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: Colors.white)),
                          if (!isFullWeek) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE0A94E).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text('Lebih pendek', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: Color(0xFFE0A94E))),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text.rich(
                        TextSpan(
                          style: const TextStyle(fontSize: 12.5, color: Color(0xFFB7C0CF), height: 1.5),
                          children: [
                            const TextSpan(text: 'Mulai '),
                            TextSpan(
                              text: '${dayLabelsFullId[settings.startDate.weekday % 7]}, ${formatDateId(settings.startDate)}',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                            ),
                            const TextSpan(text: ', latihan sampai '),
                            TextSpan(
                              text: 'Sabtu, ${formatDateId(week1End)}',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                            ),
                            const TextSpan(text: '.'),
                          ],
                        ),
                      ),
                      if (!isFullWeek) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Karena mulai di tengah minggu, minggu pertama ini cuma berisi ${settings.week1Length} hari — bukan bug, ini supaya minggu ke-2 dan seterusnya bisa selalu rapi dari Minggu.',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF808C9E), height: 1.4),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: accent.withOpacity(0.35)),
                  ),
                  child: Text('${settings.week1Length} hari', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: accent)),
                ),
              ],
            ),
          ),
          _TimelineStep(
            isLast: true,
            dotColor: restColor,
            lineColor: Colors.transparent,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Minggu 2 dan seterusnya', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: Colors.white)),
                const SizedBox(height: 6),
                Text.rich(
                  TextSpan(
                    style: const TextStyle(fontSize: 12.5, color: Color(0xFFB7C0CF), height: 1.5),
                    children: [
                      const TextSpan(text: 'Selalu genap, dari '),
                      TextSpan(text: 'Minggu sampai Sabtu', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                      const TextSpan(text: ' — 7 hari penuh, otomatis berulang tiap minggu sampai program selesai.'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text('POLA TIAP HARI', style: AppFonts.label(size: 10, letterSpacing: 0.6)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final key in dayKeysByDow) _RoleBadge(day: dayLabelsFullId[dayKeysByDow.indexOf(key)], role: roles[key] ?? 'rest', accent: accent),
            ],
          ),
        ],
      ),
    );
  }
}

/// Satu langkah pada garis waktu vertikal (titik + garis penghubung di kiri,
/// konten bebas di kanan) — dipakai supaya "Minggu 1" dan "Minggu 2 dst"
/// terbaca sebagai alur berurutan, bukan dua paragraf lepas yang terpisah.
class _TimelineStep extends StatelessWidget {
  final bool isLast;
  final Color dotColor;
  final Color lineColor;
  final Widget child;
  const _TimelineStep({
    this.isLast = false,
    required this.dotColor,
    required this.lineColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(top: 3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: dotColor,
                  boxShadow: [BoxShadow(color: dotColor.withOpacity(0.55), blurRadius: 7, spreadRadius: 0.5)],
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 5),
                    color: lineColor,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 18),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final String day;
  final String role;
  final Color accent;
  const _RoleBadge({required this.day, required this.role, required this.accent});

  (String, Color) _roleInfo() {
    switch (role) {
      case 'rest':
        return ('Libur', const Color(0xFF5A6577));
      case 'longrun':
        return ('Jarak jauh', accent);
      case 'heavy':
        return ('Berat', const Color(0xFFD16B5C));
      default:
        return ('Ringan', const Color(0xFFE0A94E));
    }
  }

  @override
  Widget build(BuildContext context) {
    final (label, color) = _roleInfo();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(day, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Colors.white)),
          Text(label, style: TextStyle(fontSize: 9.5, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
