import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../app_state.dart';
import '../program.dart';
import '../theme/app_fonts.dart';
import '../widgets/glass_card.dart';
import '../widgets/progress_ring.dart';

/// Shadow tipis yang sama seperti default di AppFonts — dipakai di sini
/// untuk teks yang gaya-nya tidak lewat AppFonts.stat/label (jadi tidak
/// otomatis dapat shadow itu), supaya keterbacaannya tetap konsisten di
/// atas ParticleBackground yang ramai.
const _kLegibilityShadow = [Shadow(color: Color(0xCC000000), blurRadius: 5, offset: Offset(0, 1))];

class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final accent = state.accentColor;
    final streak = state.computeStreak();
    final sessions = state.totalSessionsAll;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        // ---- Hero ----
        GlassCard(
          eco: state.isEco,
          hero: !state.isEco,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('PROGRESS', style: AppFonts.label(size: 10, letterSpacing: 1.5)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0A94E).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE0A94E).withOpacity(0.35)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(PhosphorIconsFill.fire, size: 14, color: const Color(0xFFE0A94E)),
                        const SizedBox(width: 4),
                        Text('${streak.current} hari', style: const TextStyle(color: Color(0xFFE0A94E), fontWeight: FontWeight.bold, fontSize: 12, shadows: _kLegibilityShadow)),
                      ],
                    ),
                  ).animate(onPlay: (c) => c.repeat(reverse: true)).scaleXY(
                        begin: 1,
                        end: 1.05,
                        duration: 1400.ms,
                        curve: Curves.easeInOut,
                      ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  ProgressRing(
                    fraction: state.progressFraction,
                    color: accent,
                    glow: !state.isEco,
                    centerText: '${(state.progressFraction * 100).round()}%',
                    centerLabel: 'menuju target',
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      children: [
                        _statRow('Berat sekarang', '${state.currentWeight.toStringAsFixed(1)} kg'),
                        const SizedBox(height: 10),
                        _statRow('Target', '${state.settings.goalWeight.toStringAsFixed(0)} kg'),
                        const SizedBox(height: 10),
                        _statRow('Total jarak', '${state.totalKmAll.toStringAsFixed(0)} km'),
                        const SizedBox(height: 10),
                        _statRow('Sesi selesai', '${sessions.done}/${sessions.total}'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.08, end: 0, curve: Curves.easeOutCubic),
        const SizedBox(height: 16),

        // ---- Week nav + phase pill + day list, disatukan supaya nomor
        // minggu & label fase bisa ikut "hidup" mengikuti drag jari (lihat
        // _WeekSyncSection) ----
        _WeekSyncSection(state: state, accent: accent),

        const SizedBox(height: 20),
        // ---- Weight logger ----
        GlassCard(eco: state.isEco, child: _WeightLogger(accent: accent)),
      ],
    );
  }

  Widget _statRow(String label, String val) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFFA3AEBD), shadows: _kLegibilityShadow)),
        Text(val, style: AppFonts.stat(size: 16)),
      ],
    );
  }
}

/// Membungkus nav minggu (panah + chip angka), pil label fase ("Rebuild
/// Base" dsb), dan daftar hari yang bisa di-swipe — supaya semuanya bisa
/// disinkronkan ke SATU nomor minggu yang sama saat jari masih di layar.
///
/// Sebelumnya, chip angka & pil fase langsung baca `state.week` — yang
/// CUMA berubah setelah swipe benar-benar "commit" (state.week baru
/// ditulis begitu animasi pegas kelar). Akibatnya, badan hari sudah
/// bergerak hidup mengikuti jari, tapi chip angka minggu di atasnya masih
/// diam menunjukkan angka lama sampai swipe selesai total — kelihatan
/// "delay". `_previewWeek` di sini menampung nomor minggu yang lagi
/// "menang" secara visual SELAMA drag (dilaporkan live oleh `_WeekSwiper`
/// lewat `onLivePreview`), dipakai buat tampilan SAJA tanpa menyentuh
/// `state.week` yang sesungguhnya (yang juga men-save ke disk, jadi tidak
/// ingin dipanggil 60x/detik).
class _WeekSyncSection extends StatefulWidget {
  final AppState state;
  final Color accent;
  const _WeekSyncSection({required this.state, required this.accent});

  @override
  State<_WeekSyncSection> createState() => _WeekSyncSectionState();
}

class _WeekSyncSectionState extends State<_WeekSyncSection> {
  int? _previewWeek;

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final accent = widget.accent;
    final displayWeek = _previewWeek ?? state.week;
    final phase = phaseFor(displayWeek, state.settings.totalWeeks);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ---- Week nav ----
        Row(
          children: [
            IconButton(
              onPressed: state.week > 1 ? () => state.setWeek(state.week - 1) : null,
              icon: Icon(PhosphorIconsBold.caretLeft),
            ),
            Expanded(
              child: SizedBox(
                height: 36,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: state.settings.totalWeeks,
                  itemBuilder: (ctx, i) {
                    final w = i + 1;
                    final active = w == displayWeek;
                    return GestureDetector(
                      onTap: () => state.setWeek(w),
                      child: Container(
                        width: 34,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: active ? const Color(0xFF1C222C) : const Color(0xFF10141B),
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(color: active ? accent : Colors.transparent),
                        ),
                        child: Text('$w', style: AppFonts.stat(size: 12, color: active ? Colors.white : const Color(0xFF8B97A8), weight: FontWeight.w600)),
                      ),
                    );
                  },
                ),
              ),
            ),
            IconButton(
              onPressed: state.week < state.settings.totalWeeks ? () => state.setWeek(state.week + 1) : null,
              icon: Icon(PhosphorIconsBold.caretRight),
            ),
          ],
        ),
        Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 5),
          decoration: BoxDecoration(
            border: Border.all(color: phase.color.withOpacity(0.5)),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 6, height: 6, decoration: BoxDecoration(color: phase.color, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text(phase.name, style: AppFonts.label(size: 11.5, color: phase.color, letterSpacing: 0.6)),
            ],
          ),
        ),

        // ---- Day list (bisa di-swipe kiri/kanan untuk ganti minggu) ----
        _WeekSwiper(
          week: state.week,
          totalWeeks: state.settings.totalWeeks,
          onWeekChanged: state.setWeek,
          onHaptic: state.haptic,
          onLivePreview: (w) {
            if (w == _previewWeek) return;
            setState(() => _previewWeek = w);
          },
          builder: (w) => _DayListSection(week: w, settings: state.settings),
        ),
      ],
    );
  }
}

/// Kumpulan baris hari untuk satu minggu tertentu — dibungkus jadi satu
/// widget supaya bisa di-animasikan sebagai satu blok saat berpindah minggu
/// (lewat swipe, tombol panah, atau chip minggu).
class _DayListSection extends StatelessWidget {
  final int week;
  final ProgramSettings settings;
  const _DayListSection({required this.week, required this.settings});

  @override
  Widget build(BuildContext context) {
    final plan = weekPlan(week, settings);
    return Column(
      children: [
        for (int i = 0; i < plan.length; i++)
          _DayRow(key: ValueKey('$week-${plan[i].key}'), day: plan[i], week: week)
              .animate()
              .fadeIn(duration: 250.ms, delay: (25 * i).ms)
              .slideX(begin: 0.03, end: 0, curve: Curves.easeOutCubic),
      ],
    );
  }
}

/// Membungkus daftar hari sebagai halaman yang bisa di-swipe kiri/kanan
/// untuk ganti minggu. Dua versi sebelumnya (deteksi drag manual lewat
/// `onHorizontalDragEnd`, lalu versi drag-live custom dengan animasi
/// pegas sendiri) SAMA-SAMA masih kerasa kurang mulus dibanding scroll
/// asli di bagian lain app — dan makin cepat di-swipe malah makin berat.
/// Penyebabnya: keduanya reimplementasi manual gesture+animasi sendiri,
/// bukan scroll asli.
///
/// Sekarang dipakai `PageView` BENERAN — mesin yang SAMA persis dipakai
/// Flutter untuk semua scroll mulus di app ini (`ListView`, dst). Karena
/// itu literally scroll asli (bukan tiruan), perilakunya otomatis identik:
/// mengikuti jari 1:1, fling/momentum bawaan, dan performanya tidak
/// memburuk walau di-swipe cepat (beda dari versi custom sebelumnya yang
/// makin berat kalau event drag makin sering masuk).
///
/// Dua hal ekstra yang perlu ditangani karena pindah ke PageView:
/// 1. PageView butuh TINGGI TETAP (dia viewport, bukan auto-tinggi
///    seperti Column biasa) — padahal minggu ke-1 kadang jumlah harinya
///    lebih sedikit (lihat `week1Length` di program.dart). Diatasi dengan
///    mengukur tinggi tiap halaman yang pernah dirender (`_MeasureSize`)
///    dan memakai yang PALING TINGGI, dibungkus `AnimatedSize` supaya
///    perubahannya (kalau ada) tetap halus, bukan meloncat.
/// 2. Commit ke `state.week` (yang otomatis SAVE ke disk) SENGAJA tidak
///    langsung ditempel ke `onPageChanged` PageView (yang bisa terpanggil
///    berkali-kali kalau geser cepat lewat beberapa minggu sekaligus) —
///    baru benar-benar di-commit sekali saat scroll-nya sudah berhenti
///    total (`ScrollEndNotification`). Sementara chip angka minggu & pil
///    fase di atas tetap di-update SECARA LIVE lewat listener terpisah ke
///    posisi scroll PageView-nya (`onLivePreview`) — jadi tetap ikut
///    gerak real-time tanpa perlu nunggu commit itu.
/// `PageScrollPhysics` bawaan Flutter baru mau pindah halaman kalau
/// geserannya lewat ~50% lebar layar, ATAU lemparan jarinya sangat cepat
/// (ambang kecepatan default-nya cukup ketat) — makanya swipe berkecepatan
/// wajar (bukan geseran sangat pelan, tapi juga bukan sentakan sekuat
/// tenaga) sering dianggap "batal" dan mental balik ke minggu semula,
/// bukannya lanjut ke minggu berikutnya.
///
/// Versi ini menurunkan ambang kecepatannya jauh (`_flingVelocityThreshold`)
/// — swipe sekecepatan apa pun yang terasa wajar sudah cukup buat pindah
/// SATU halaman ke arah tsb, TIDAK PEDULI seberapa jauh jarak geserannya
/// (persis kebiasaan swipe di app carousel/stories kebanyakan). Geseran
/// yang benar-benar pelan/tanpa sentakan (di bawah ambang) tetap jatuh ke
/// perilaku default: baru pindah kalau sudah lewat separuh layar.
class _ForgivingPageScrollPhysics extends PageScrollPhysics {
  const _ForgivingPageScrollPhysics({super.parent});

  static const double _flingVelocityThreshold = 220.0;

  @override
  _ForgivingPageScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return _ForgivingPageScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  Simulation? createBallisticSimulation(ScrollMetrics position, double velocity) {
    if (position is! PageMetrics) {
      return super.createBallisticSimulation(position, velocity);
    }
    // Sudah di ujung (minggu pertama/terakhir) — biarkan fisika bawaan yang
    // urus efek rubber-band-nya, tidak perlu dicampuri.
    if ((velocity <= 0.0 && position.pixels <= position.minScrollExtent) ||
        (velocity >= 0.0 && position.pixels >= position.maxScrollExtent)) {
      return super.createBallisticSimulation(position, velocity);
    }

    final tolerance = toleranceFor(position);
    double page = position.page ?? 0.0;
    if (velocity < -_flingVelocityThreshold) {
      page -= 0.5;
    } else if (velocity > _flingVelocityThreshold) {
      page += 0.5;
    }
    // Tanpa dorongan di atas (geseran pelan tanpa sentakan berarti), ini
    // otomatis jatuh ke pembulatan biasa — butuh lewat separuh layar,
    // sama seperti perilaku default.
    final target = page.roundToDouble() * position.viewportDimension * position.viewportFraction;
    if (target != position.pixels) {
      return ScrollSpringSimulation(spring, position.pixels, target, velocity, tolerance: tolerance);
    }
    return null;
  }
}


class _WeekSwiper extends StatefulWidget {
  final int week;
  final int totalWeeks;
  final ValueChanged<int> onWeekChanged;
  final VoidCallback onHaptic;
  // Dilaporkan TERUS-MENERUS selama scroll (drag maupun fling settle),
  // mengikuti posisi PageView yang sesungguhnya — dipakai parent buat
  // menyinkronkan chip angka minggu & label fase secara live.
  final ValueChanged<int?>? onLivePreview;
  final Widget Function(int week) builder;
  const _WeekSwiper({
    required this.week,
    required this.totalWeeks,
    required this.onWeekChanged,
    required this.onHaptic,
    this.onLivePreview,
    required this.builder,
  });

  @override
  State<_WeekSwiper> createState() => _WeekSwiperState();
}

class _WeekSwiperState extends State<_WeekSwiper> {
  late final PageController _controller;
  int? _lastReportedLive;

  // Tinggi tiap minggu di-cache per nomor minggu (minggu 1 memang bisa
  // lebih pendek — lihat `week1Length` di program.dart) — TAPI, beda dari
  // percobaan sebelumnya, `_pageHeight` yang benar-benar dipakai untuk
  // render TIDAK dievaluasi ulang selama drag berlangsung. Itu yang
  // kemarin bikin patah-patah: mengganti tinggi kotak SAAT BERSAMAAN
  // PageView lagi geser horizontal = dua animasi rebutan tiap frame.
  //
  // Sekarang `_pageHeight` cuma di-update di DUA momen yang sudah pasti
  // TIDAK bertabrakan dengan gerakan drag:
  // 1. Saat halaman baru pertama kali terukur DAN kebetulan itu halaman
  //    yang lagi ditampilkan diam (bukan yang lagi digeser lewat).
  // 2. Saat scroll benar-benar BERHENTI (`ScrollEndNotification`) — baru
  //    di titik itu kita tahu "sudah mendarat di minggu mana", dan
  //    resize-nya (kalau perlu) terjadi SENDIRIAN, tidak dicampuri gerakan
  //    apa pun lagi. Selama drag itu sendiri berlangsung, tinggi kotak
  //    diam total (kalau kontennya kebetulan lebih tinggi dari kotak saat
  //    itu, ya sementara ke-clip dulu — cuma sekejap selama jari masih
  //    bergerak, langsung menyesuaikan begitu mendarat).
  final Map<int, double> _heights = {};
  double _pageHeight = 520;

  @override
  void initState() {
    super.initState();
    _controller = PageController(initialPage: widget.week - 1);
    _controller.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(covariant _WeekSwiper old) {
    super.didUpdateWidget(old);
    // PENTING: cuma bereaksi kalau `week` PROP-nya sendiri benar-benar
    // berubah (navigasi dari LUAR — tombol panah / chip minggu, atau
    // commit dari swipe yang baru selesai). Sebelumnya kode ini
    // membandingkan `targetPage` (dari `widget.week`, yang masih nilai
    // LAMA selama drag berlangsung — commit baru terjadi saat
    // ScrollEndNotification) dengan `_controller.page` yang justru
    // posisi LIVE jari yang sedang menggeser. Akibatnya, begitu geseran
    // lewat separuh halaman, `currentPage` (dibulatkan dari posisi jari)
    // "berbeda" dari `targetPage` (minggu lama) — dan blok ini langsung
    // memanggil `animateToPage` balik ke minggu lama, melawan swipe
    // sendiri, PERSIS di titik lewat 50% (kelihatan seperti "mental").
    // Trigger rebuild-nya sendiri adalah `onLivePreview` di atas, yang
    // setState tiap tick scroll — jadi ini kejadian tiap kali drag jalan,
    // bukan cuma sesekali.
    if (old.week == widget.week) return;
    final targetPage = widget.week - 1;
    if (_controller.hasClients) {
      _controller.animateToPage(targetPage, duration: const Duration(milliseconds: 340), curve: Curves.easeOutCubic);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    _controller.dispose();
    super.dispose();
  }

  // Cuma buat live preview chip angka minggu — SENGAJA tidak menyentuh
  // `_pageHeight` sama sekali di sini (itu kuncinya biar drag tidak
  // dicampuri resize apa pun).
  void _onScroll() {
    if (!_controller.hasClients) return;
    final page = _controller.page;
    if (page == null) return;
    final rounded = page.round().clamp(0, widget.totalWeeks - 1);
    final live = rounded + 1;
    if (live == _lastReportedLive) return;
    _lastReportedLive = live;
    widget.onLivePreview?.call(live == widget.week ? null : live);
  }

  void _onHeightMeasured(int week, double h) {
    if (h <= 0) return;
    final prev = _heights[week];
    if (prev != null && (prev - h).abs() < 0.5) return;
    _heights[week] = h;
    // Cuma langsung diterapkan kalau ini minggu yang SEDANG diam
    // ditampilkan (bukan yang lagi lewat sekilas selagi drag) — supaya
    // tidak memicu resize di tengah gerakan.
    final isIdle = !_controller.hasClients || !_controller.position.isScrollingNotifier.value;
    if (isIdle && week == widget.week) {
      _applyHeight(h);
    }
  }

  void _applyHeight(double h) {
    if ((h - _pageHeight).abs() > 0.5) setState(() => _pageHeight = h);
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notif) {
        if (notif is ScrollEndNotification && _controller.hasClients) {
          final page = _controller.page?.round() ?? (widget.week - 1);
          final newWeek = page.clamp(0, widget.totalWeeks - 1) + 1;
          // Baru sekarang (scroll sudah berhenti total) resize ke tinggi
          // minggu yang benar-benar didarati — aman, tidak lagi bentrok
          // dengan animasi geser manapun.
          final h 
