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
    final target = position.getPixelsFromPage(page.roundToDouble());
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
    final targetPage = widget.week - 1;
    final currentPage = _controller.hasClients ? (_controller.page?.round() ?? targetPage) : targetPage;
    // Perubahan dari LUAR (tombol panah / chip minggu) — animasikan
    // PageView ke sana. Kalau perubahannya berasal dari scroll kita
    // sendiri (sudah collect lewat _onScroll -> onWeekChanged), currentPage
    // sudah match, jadi tidak melakukan apa-apa di sini (tidak dobel).
    if (targetPage != currentPage && _controller.hasClients) {
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
          final h = _heights[newWeek];
          if (h != null) _applyHeight(h);
          if (newWeek != widget.week) {
            widget.onWeekChanged(newWeek);
            widget.onHaptic();
          }
        }
        return false;
      },
      child: AnimatedSize(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        alignment: Alignment.topCenter,
        child: ClipRect(
          child: SizedBox(
            height: _pageHeight,
            child: PageView.builder(
              controller: _controller,
              itemCount: widget.totalWeeks,
              physics: const _ForgivingPageScrollPhysics(),
              itemBuilder: (context, i) {
                final week = i + 1;
                return _MeasureSize(
                  onHeight: (h) => _onHeightMeasured(week, h),
                  child: widget.builder(week),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Widget pembantu kecil: merender [child] apa adanya, tapi setelah setiap
/// frame terpasang, melaporkan tinggi ALAMINYA lewat [onHeight] — dipakai
/// `_WeekSwiper` di atas buat tahu seberapa tinggi PageView-nya harus
/// dibuat (karena PageView butuh tinggi pasti, sementara jumlah baris hari
/// bisa beda-beda tiap minggu, khususnya minggu pertama).
///
/// PENTING soal `OverflowBox` di bawah: tanpa itu, [child] akan menerima
/// batasan tinggi TETAP dari PageView di luarnya (PageView selalu memaksa
/// tinggi anaknya pas dengan tinggi yang kita kasih ke SizedBox pembungkus
/// — sama seperti dia memaksa lebar anaknya pas dengan lebar layar).
/// Akibatnya pengukuran jadi "muter tanpa ujung": tinggi yang terukur
/// SELALU sama persis dengan tinggi yang sudah kita tentukan duluan, jadi
/// tidak akan pernah bisa terkoreksi turun untuk minggu yang lebih pendek
/// (itu sebabnya minggu pertama kelihatan punya area kosong raksasa di
/// bawahnya). `OverflowBox` memutus lingkaran itu — memberi [child]
/// keleluasaan tinggi TAK TERBATAS untuk mengukur ukuran alaminya sendiri,
/// terlepas dari batasan yang datang dari PageView di luar.
class _MeasureSize extends StatefulWidget {
  final Widget child;
  final ValueChanged<double> onHeight;
  const _MeasureSize({required this.child, required this.onHeight});

  @override
  State<_MeasureSize> createState() => _MeasureSizeState();
}

class _MeasureSizeState extends State<_MeasureSize> {
  final _key = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(_report);
  }

  @override
  void didUpdateWidget(covariant _MeasureSize old) {
    super.didUpdateWidget(old);
    WidgetsBinding.instance.addPostFrameCallback(_report);
  }

  void _report(Duration _) {
    if (!mounted) return;
    final size = (_key.currentContext?.findRenderObject() as RenderBox?)?.size;
    if (size != null) widget.onHeight(size.height);
  }

  @override
  Widget build(BuildContext context) {
    return OverflowBox(
      minHeight: 0,
      maxHeight: double.infinity,
      alignment: Alignment.topCenter,
      child: KeyedSubtree(key: _key, child: widget.child),
    );
  }
}


class _DayRow extends StatefulWidget {
  final DayPlan day;
  final int week;
  const _DayRow({super.key, required this.day, required this.week});

  @override
  State<_DayRow> createState() => _DayRowState();
}

class _DayRowState extends State<_DayRow> {
  // Controller ini sekarang dibuat SEKALI (bukan tiap build) dan di-dispose
  // dengan benar saat baris hari ini dilepas — sebelumnya widget membuat
  // TextEditingController baru setiap kali AppState notifyListeners() (mis.
  // saat mencatat berat badan di kartu lain), padahal baris ini sendiri
  // sama sekali tidak berubah. `_DayRow` diberi key unik per '$week-$day'
  // (lihat _DayListSection) supaya State ini otomatis diganti — bukan
  // sekadar di-update — begitu berpindah minggu atau hari.
  late final TextEditingController _kmController;
  // FocusNode ini yang jadi kunci perbaikan bug "custom km balik ke
  // default saat edit hari lain": sebelumnya field cuma tersimpan ke state
  // lewat onSubmitted (tekan Enter/Done di keyboard) — kalau pengguna
  // ngetik lalu langsung TAP PINDAH ke field hari lain (tanpa Enter),
  // nilainya tidak pernah ke-commit ke `state.actualKm`. Begitu hari LAIN
  // itu di-submit dan notifyListeners() membuat baris ini ikut rebuild,
  // logika sinkronisasi di build() (yang membaca ulang dari state) melihat
  // `state.actualKm` masih kosong untuk baris ini lalu menimpa balik teks
  // yang sudah diketik dengan nilai default. Dengan commit saat fokus
  // hilang, begitu pengguna tap pindah field, nilainya SUDAH tersimpan ke
  // state duluan — jadi tidak ada lagi celah buat ketimpa balik.
  late final FocusNode _kmFocus;

  String get _key => '${widget.week}-${widget.day.key}';

  /// Format angka km buat ditampilkan di field: BUKAN selalu dibulatkan ke
  /// bilangan bulat (itu penyebab bug "desimal nggak kesimpan" — nilainya
  /// sebenarnya tersimpan benar sebagai double di state, tapi tampilannya
  /// selalu dipaksa `.toStringAsFixed(0)` jadi kelihatan hilang desimalnya
  /// setiap kali field ini disinkronkan ulang). Sekarang: kalau memang
  /// bilangan bulat tampil polos ("12"), kalau ada desimal tetap tampil
  /// apa adanya sampai 2 angka di belakang koma tanpa trailing zero sampah
  /// ("12.5", bukan "12.50" atau "13").
  String _formatKm(double km) {
    if (km == km.roundToDouble()) return km.toStringAsFixed(0);
    var s = km.toStringAsFixed(2);
    s = s.replaceFirst(RegExp(r'0+$'), '');
    s = s.replaceFirst(RegExp(r'\.$'), '');
    return s;
  }

  @override
  void initState() {
    super.initState();
    final state = context.read<AppState>();
    _kmController = TextEditingController(
      text: _formatKm(state.actualKm[_key] ?? widget.day.km),
    );
    _kmFocus = FocusNode();
    _kmFocus.addListener(() {
      if (!_kmFocus.hasFocus) _commitKm();
    });
  }

  @override
  void dispose() {
    _kmController.dispose();
    _kmFocus.dispose();
    super.dispose();
  }

  /// Simpan isi field ke state. Kalau isinya bukan angka valid (mis. sudah
  /// dikosongkan pengguna), jangan disimpan — cukup kembalikan tampilan
  /// field ke nilai terakhir yang benar dari state, supaya tidak nyimpan
  /// sampah ke actualKm.
  void _commitKm() {
    final state = context.read<AppState>();
    final val = double.tryParse(_kmController.text.replaceAll(',', '.'));
    if (val != null) {
      state.setActualKm(widget.week, widget.day.key, val);
    } else {
      _kmController.text = _formatKm(state.actualKm[_key] ?? widget.day.km);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final accent = state.accentColor;
    final key = _key;
    final done = state.completed[key] == true;

    if (widget.day.rest) {
      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          // Panel ini sengaja TIDAK pakai GlassCard (biar kesannya "redup/
          // nonaktif" dibanding kartu hari aktif) — tapi itu artinya tanpa
          // fill sama sekali, bokeh dari ParticleBackground tembus penuh
          // di baliknya tanpa peredam apa pun. Ditambah warna teksnya yang
          // memang sengaja redup (abu gelap, buat kesan "istirahat"),
          // kombinasinya jadi nyaris tak terbaca. Fill gelap tipis ini
          // cuma menambal celah itu — bukan mengubah gayanya jadi
          // "kartu aktif", opacity-nya sengaja rendah supaya masih terasa
          // beda/lebih pudar dari kartu hari lain.
          color: const Color(0xFF0B0F15).withOpacity(0.62),
          border: Border.all(color: const Color(0xFF232A35), style: BorderStyle.solid),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(widget.day.label, style: const TextStyle(color: Color(0xFF5A6577), fontWeight: FontWeight.bold, fontSize: 15, shadows: _kLegibilityShadow)),
            Text(formatDateId(widget.day.date), style: const TextStyle(color: Color(0xFF454E5E), fontSize: 11, shadows: _kLegibilityShadow)),
            Text('Istirahat', style: AppFonts.label(size: 12, color: const Color(0xFF454E5E), letterSpacing: 0.6)),
          ],
        ),
      );
    }

    // Sinkronkan teks field kalau nilainya berubah dari luar (mis. tombol
    // "selesai" ditekan sehingga actualKm terisi nilai default) — tapi
    // HANYA kalau field ini sedang tidak difokus. Kalau lagi difokus
    // (pengguna sedang mengetik), jangan disentuh sama sekali — supaya
    // ketikan yang belum di-commit (lihat _commitKm) tidak pernah tertimpa
    // oleh rebuild yang dipicu edit di hari lain.
    if (!_kmFocus.hasFocus) {
      final displayKm = _formatKm(state.actualKm[key] ?? widget.day.km);
      if (_kmController.text != displayKm) {
        _kmController.text = displayKm;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        eco: state.isEco,
        radius: 16,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        borderColor: done ? accent : null,
        child: Row(
        children: [
          GestureDetector(
            onTap: () => state.toggleDayDone(widget.week, widget.day.key, widget.day.km),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutBack,
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: done ? accent : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: done ? accent : const Color(0xFF3A4353), width: 1.5),
                boxShadow: done && !state.isEco
                    ? [BoxShadow(color: accent.withOpacity(0.5), blurRadius: 10, spreadRadius: 1)]
                    : null,
              ),
              child: done ? Icon(PhosphorIconsBold.check, size: 16, color: Colors.black) : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(widget.day.label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, shadows: _kLegibilityShadow)),
                    const SizedBox(width: 6),
                    Text(formatDateId(widget.day.date), style: const TextStyle(fontSize: 10.5, color: Color(0xFFAAB4C4), shadows: _kLegibilityShadow)),
                  ],
                ),
                const SizedBox(height: 2),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: 'Target ${widget.day.km.toStringAsFixed(0)} km',
                        style: AppFonts.stat(size: 11.5, color: const Color(0xFFB7C0CF), weight: FontWeight.w500, letterSpacing: 0),
                      ),
                      TextSpan(
                        text: '  ·  ≈${estimateCalories(state.currentWeight, widget.day.km)} kkal',
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF9AA6B8), fontWeight: FontWeight.w600, shadows: _kLegibilityShadow),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 60,
            child: TextField(
              controller: _kmController,
              focusNode: _kmFocus,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.center,
              style: AppFonts.stat(size: 14),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF0A0D12),
                contentPadding: const EdgeInsets.symmetric(vertical: 9),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(9),
                  borderSide: const BorderSide(color: Color(0xFF232A35)),
                ),
              ),
              onSubmitted: (_) => _commitKm(),
            ),
          ),
        ],
        ),
      ),
    );
  }
}

class _WeightLogger extends StatefulWidget {
  final Color accent;
  const _WeightLogger({required this.accent});
  @override
  State<_WeightLogger> createState() => _WeightLoggerState();
}

class _WeightLoggerState extends State<_WeightLogger> {
  final _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Catat Berat Badan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, shadows: _kLegibilityShadow)),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: AppFonts.stat(size: 16),
                decoration: InputDecoration(
                  hintText: '${state.currentWeight}',
                  filled: true,
                  fillColor: const Color(0xFF0A0D12),
                  suffixText: 'kg',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF232A35)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE0A94E),
                foregroundColor: const Color(0xFF1A1206),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                final v = double.tryParse(_controller.text.replaceAll(',', '.'));
                if (v != null && v > 0) {
                  state.logWeight(v);
                  _controller.clear();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Berat badan dicatat')),
                  );
                }
              },
              child: const Text('Catat', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ],
    );
  }
}
