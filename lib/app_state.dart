import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'program.dart';

const String kAccentTeal = "teal";
const String kAccentAmber = "amber";
const String kAccentRose = "rose";
const String kAccentViolet = "violet";

const Map<String, Color> accentColors = {
  kAccentTeal: Color(0xFF5FB3A3),
  kAccentAmber: Color(0xFFE0A94E),
  kAccentRose: Color(0xFFD16B8A),
  kAccentViolet: Color(0xFF8A7FD1),
};

class Snapshot {
  final Map<String, bool> completed;
  final Map<String, double> actualKm;
  final Map<String, double> weights;
  Snapshot(this.completed, this.actualKm, this.weights);
  Snapshot clone() => Snapshot(
        Map<String, bool>.from(completed),
        Map<String, double>.from(actualKm),
        Map<String, double>.from(weights),
      );
}

class AppState extends ChangeNotifier {
  static const _storageKey = "sepeda_progress_hub_v1";

  // Pengaturan program — bisa diubah lewat layar Pengaturan Program.
  // Semua tanggal/target/fase diturunkan dari sini, bukan dari konstanta
  // tetap lagi.
  ProgramSettings settings = ProgramSettings.defaults();

  // Ditandai true begitu pengguna menyelesaikan panel pengaturan target
  // pertama kali (onboarding). Sebelum ini true, aplikasi menampilkan
  // panel setup, bukan langsung ke Hari Ini.
  bool hasCompletedSetup = false;

  int week = 1;
  Map<String, bool> completed = {};
  Map<String, double> actualKm = {};
  Map<String, double> weights = {};
  String accentTheme = kAccentTeal;
  bool hapticEnabled = true;

  final List<Snapshot> _undoStack = [];
  final List<Snapshot> _redoStack = [];
  static const _maxHistory = 30;

  Color get accentColor => accentColors[accentTheme] ?? accentColors[kAccentTeal]!;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    weights = {"0": settings.startWeight};
    // Instalasi baru (belum ada data tersimpan sama sekali) -> tampilkan
    // panel setup. Pengguna lama yang datanya tersimpan dari versi
    // sebelum fitur onboarding ini ada dianggap sudah "selesai setup"
    // secara default, supaya tidak tiba-tiba disuruh setup ulang.
    hasCompletedSetup = raw != null;
    if (raw != null) {
      try {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        if (j["settings"] != null) {
          settings = ProgramSettings.fromJson(j["settings"] as Map<String, dynamic>);
        }
        hasCompletedSetup = j["hasCompletedSetup"] ?? true;
        week = j["week"] ?? 1;
        completed = Map<String, bool>.from(j["completed"] ?? {});
        actualKm = (j["actualKm"] as Map<String, dynamic>? ?? {})
            .map((k, v) => MapEntry(k, (v as num).toDouble()));
        weights = (j["weights"] as Map<String, dynamic>? ?? {"0": settings.startWeight})
            .map((k, v) => MapEntry(k, (v as num).toDouble()));
        accentTheme = j["accentTheme"] ?? kAccentTeal;
        hapticEnabled = j["hapticEnabled"] ?? true;
      } catch (_) {}
    }
    week = week.clamp(1, settings.totalWeeks);
    notifyListeners();
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    final j = {
      "settings": settings.toJson(),
      "hasCompletedSetup": hasCompletedSetup,
      "week": week,
      "completed": completed,
      "actualKm": actualKm,
      "weights": weights,
      "accentTheme": accentTheme,
      "hapticEnabled": hapticEnabled,
    };
    await prefs.setString(_storageKey, jsonEncode(j));
  }

  Snapshot _snapshot() => Snapshot(completed, actualKm, weights).clone();

  void _pushUndo() {
    _undoStack.add(_snapshot());
    if (_undoStack.length > _maxHistory) _undoStack.removeAt(0);
    _redoStack.clear();
  }

  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  void undo() {
    if (_undoStack.isEmpty) return;
    _redoStack.add(_snapshot());
    final snap = _undoStack.removeLast();
    completed = snap.completed;
    actualKm = snap.actualKm;
    weights = snap.weights;
    save();
    notifyListeners();
  }

  void redo() {
    if (_redoStack.isEmpty) return;
    _undoStack.add(_snapshot());
    final snap = _redoStack.removeLast();
    completed = snap.completed;
    actualKm = snap.actualKm;
    weights = snap.weights;
    save();
    notifyListeners();
  }

  void haptic([int ms = 18]) {
    if (hapticEnabled) HapticFeedback.lightImpact();
  }

  /// Menerapkan pengaturan program baru (berat awal/target, jumlah minggu,
  /// hari mulai, hari libur, hari sesi jarak jauh). Data yang sudah dicatat
  /// (centang selesai, jarak aktual, riwayat berat) tetap disimpan karena
  /// semuanya terkunci ke nomor minggu & kunci hari — bukan ke tanggal
  /// kalender — jadi aman meski hari mulai/liburnya diubah belakangan.
  void updateSettings(ProgramSettings newSettings) {
    settings = newSettings;
    week = week.clamp(1, settings.totalWeeks);
    save();
    notifyListeners();
  }

  /// Dipanggil sekali dari panel setup pertama kali (onboarding). Sama
  /// seperti [updateSettings], tapi juga menandai setup selesai supaya
  /// panel ini tidak muncul lagi di pembukaan aplikasi berikutnya.
  void completeInitialSetup(ProgramSettings newSettings) {
    settings = newSettings;
    weights = {"0": newSettings.startWeight};
    hasCompletedSetup = true;
    week = 1;
    save();
    notifyListeners();
  }

  void toggleDayDone(int week, String dayKey, double defaultKm) {
    _pushUndo();
    final k = "$week-$dayKey";
    final isDone = completed[k] == true;
    completed[k] = !isDone;
    if (!isDone && !(actualKm.containsKey(k))) {
      actualKm[k] = defaultKm;
    }
    haptic();
    save();
    notifyListeners();
  }

  void setActualKm(int week, String dayKey, double km) {
    final k = "$week-$dayKey";
    actualKm[k] = km;
    save();
    notifyListeners();
  }

  void logWeight(double kg) {
    _pushUndo();
    final dayOffset = DateTime.now().difference(settings.startDate).inDays;
    weights[dayOffset.toString()] = kg;
    haptic(20);
    save();
    notifyListeners();
  }

  double get currentWeight {
    if (weights.isEmpty) return settings.startWeight;
    final keys = weights.keys.map(int.parse).toList()..sort();
    return weights[keys.last.toString()] ?? settings.startWeight;
  }

  List<MapEntry<int, double>> get weightHistorySorted {
    final entries = weights.entries
        .map((e) => MapEntry(int.parse(e.key), e.value))
        .toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return entries;
  }

  // Cache hasil _allDays(): isinya (peran hari, target km per minggu, dst)
  // murni turunan dari `settings`, tidak tergantung `completed`/`actualKm`.
  // Tanpa cache ini, computeStreak() + totalKmAll + totalSessionsAll yang
  // sering dipanggil bersamaan dalam satu build layar (mis. ProgressScreen)
  // masing-masing membangun ulang seluruh jadwal dari minggu 1..N — 3x kerja
  // yang sama padahal hasilnya identik selama `settings` belum berubah.
  List<({int week, DayPlan day})>? _allDaysCache;
  ProgramSettings? _allDaysCacheFor;

  List<({int week, DayPlan day})> _allDays() {
    if (_allDaysCache != null && identical(_allDaysCacheFor, settings)) {
      return _allDaysCache!;
    }
    final list = <({int week, DayPlan day})>[];
    for (int w = 1; w <= settings.totalWeeks; w++) {
      for (final d in weekPlan(w, settings)) {
        list.add((week: w, day: d));
      }
    }
    _allDaysCache = list;
    _allDaysCacheFor = settings;
    return list;
  }

  ({int current, int best}) computeStreak() {
    final all = _allDays().where((e) => !e.day.rest).toList()
      ..sort((a, b) => a.day.date.compareTo(b.day.date));
    final today = DateTime.now();
    final todayMid = DateTime(today.year, today.month, today.day);
    final past = all.where((e) => !e.day.date.isAfter(todayMid)).toList();
    int streak = 0;
    for (int i = past.length - 1; i >= 0; i--) {
      final k = "${past[i].week}-${past[i].day.key}";
      if (completed[k] == true) {
        streak++;
      } else {
        break;
      }
    }
    int best = 0, cur = 0;
    for (final e in all) {
      final k = "${e.week}-${e.day.key}";
      if (completed[k] == true) {
        cur++;
        if (cur > best) best = cur;
      } else {
        cur = 0;
      }
    }
    return (current: streak, best: best);
  }

  /// Total km dari hari-hari yang BENAR-BENAR ditandai selesai. Sebelumnya
  /// fungsi ini menjumlahkan semua entri di `actualKm` tanpa mengecek status
  /// `completed` — jadi kalau kamu centang lalu batalkan centang, angkanya
  /// tetap nyangkut di total karena `actualKm[k]` tidak pernah dihapus oleh
  /// toggleDayDone(). Sekarang disaring by `completed`, senada dengan
  /// [totalSessionsAll] di bawah yang sudah benar dari awal.
  double get totalKmAll {
    double sum = 0;
    for (final e in _allDays()) {
      final k = "${e.week}-${e.day.key}";
      if (completed[k] != true) continue;
      final v = actualKm[k];
      if (v != null) sum += v;
    }
    return sum;
  }

  /// Estimasi total kalori terbakar dari hari-hari yang BENAR-BENAR selesai
  /// (bukan sekadar punya entri actualKm — lihat catatan di [totalKmAll]).
  /// Dihitung dari berat badan TERKINI (bukan berat awal) dan bukan nilai
  /// tersimpan/di-cache — jadi otomatis menyesuaikan begitu pengguna
  /// mencatat berat baru, mengubah jarak, atau mengubah jumlah minggu
  /// (yang mengubah target km per hari lewat targetsForWeek).
  int get totalCaloriesAll {
    int sum = 0;
    for (final e in _allDays()) {
      final k = "${e.week}-${e.day.key}";
      if (completed[k] != true) continue;
      final km = actualKm[k];
      if (km != null) sum += estimateCalories(currentWeight, km);
    }
    return sum;
  }

  /// Nomor minggu tertinggi yang punya progres tercatat (centang selesai
  /// atau jarak aktual). Dipakai untuk mencegah "Jumlah minggu" dikurangi
  /// sampai membuat minggu yang sudah ada progresnya jadi tidak terjangkau
  /// lagi lewat navigasi minggu — datanya tidak akan terhapus, tapi tanpa
  /// pengaman ini pengguna bisa mengira progresnya hilang.
  int get highestRecordedWeek {
    int highest = 0;
    for (final k in completed.keys) {
      if (completed[k] != true) continue;
      final w = int.tryParse(k.split('-').first);
      if (w != null && w > highest) highest = w;
    }
    for (final k in actualKm.keys) {
      final w = int.tryParse(k.split('-').first);
      if (w != null && w > highest) highest = w;
    }
    return highest;
  }

  ({int done, int total}) get totalSessionsAll {
    int done = 0, total = 0;
    for (final e in _allDays()) {
      if (e.day.rest) continue;
      total++;
      if (completed["${e.week}-${e.day.key}"] == true) done++;
    }
    return (done: done, total: total);
  }

  double get progressFraction {
    final lost = settings.startWeight - currentWeight;
    final goalLoss = settings.startWeight - settings.goalWeight;
    if (goalLoss <= 0) return 0;
    return (lost / goalLoss).clamp(0, 1).toDouble();
  }

  void setAccent(String theme) {
    accentTheme = theme;
    save();
    notifyListeners();
  }

  // Pilihan kualitas grafis "Hemat" dihapus — aplikasi sekarang selalu
  // memakai varian efek penuh (blur, partikel, glow) tanpa pilihan.
  bool get isEco => false;

  void setHaptic(bool v) {
    hapticEnabled = v;
    save();
    notifyListeners();
  }

  void setWeek(int w) {
    week = w.clamp(1, settings.totalWeeks);
    save();
    notifyListeners();
  }

  Future<void> restoreFromJson(String raw) async {
    final j = jsonDecode(raw) as Map<String, dynamic>;
    if (j["settings"] != null) {
      settings = ProgramSettings.fromJson(j["settings"] as Map<String, dynamic>);
    }
    hasCompletedSetup = j["hasCompletedSetup"] ?? true;
    week = (j["week"] ?? 1).clamp(1, settings.totalWeeks);
    completed = Map<String, bool>.from(j["completed"] ?? {});
    actualKm = (j["actualKm"] as Map<String, dynamic>? ?? {})
        .map((k, v) => MapEntry(k, (v as num).toDouble()));
    weights = (j["weights"] as Map<String, dynamic>? ?? {"0": settings.startWeight})
        .map((k, v) => MapEntry(k, (v as num).toDouble()));
    accentTheme = j["accentTheme"] ?? kAccentTeal;
    hapticEnabled = j["hapticEnabled"] ?? true;
    await save();
    notifyListeners();
  }

  String exportJson() => jsonEncode({
        "settings": settings.toJson(),
        "hasCompletedSetup": hasCompletedSetup,
        "week": week,
        "completed": completed,
        "actualKm": actualKm,
        "weights": weights,
        "accentTheme": accentTheme,
        "hapticEnabled": hapticEnabled,
      });
}
