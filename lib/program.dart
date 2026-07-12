// Logika program latihan — sekarang sepenuhnya dikendalikan oleh
// [ProgramSettings] yang bisa diubah lewat layar Pengaturan, bukan lagi
// konstanta tetap. Struktur minggu (minggu pertama parsial mulai dari hari
// pilihan pengguna & selesai Sabtu, minggu berikutnya selalu penuh
// Minggu→Sabtu) dipertahankan persis seperti sebelumnya — hanya sumber
// tanggal mulainya saja yang sekarang datang dari pengaturan.
import 'package:flutter/material.dart';

const List<String> dayKeysByDow = ["sun", "mon", "tue", "wed", "thu", "fri", "sat"];
const List<String> dayLabelsId = ["Min", "Sen", "Sel", "Rab", "Kam", "Jum", "Sab"];
const List<String> dayLabelsFullId = [
  "Minggu", "Senin", "Selasa", "Rabu", "Kamis", "Jumat", "Sabtu"
];
const List<String> monthLabelsId = [
  "Jan", "Feb", "Mar", "Apr", "Mei", "Jun", "Jul", "Agu", "Sep", "Okt", "Nov", "Des"
];

const double kCalorieFactorFlat = 0.32;

/// Nilai default — dipakai saat pengguna belum pernah mengubah pengaturan
/// (dan sebagai fallback saat data tersimpan rusak/kosong). Nilainya sama
/// persis dengan yang dulu ter-hardcode di app, supaya pengguna lama tidak
/// merasakan perubahan apa pun sebelum mereka sendiri membuka Pengaturan.
class ProgramDefaults {
  static const double startWeight = 110;
  static const double goalWeight = 80;
  static const int totalWeeks = 26;

  /// Hari mulai default mengikuti hari ini — hari pertama kali pengguna
  /// membuka aplikasi dan menyelesaikan setup, apa pun hari kalendernya
  /// (tidak lagi dipaksa ke hari Minggu terdekat). Kalau ini membuat
  /// minggu pertama jadi parsial (mis. mulai hari Jumat), itu memang
  /// perilaku yang diharapkan — lihat [ProgramSettings.week1Length].
  static DateTime get startDate {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  static const Set<String> restDayKeys = {"sat"};
}

/// Seluruh parameter program yang bisa dikustomisasi pengguna lewat layar
/// Pengaturan Program.
class ProgramSettings {
  final double startWeight;
  final double goalWeight;
  final int totalWeeks;
  final DateTime startDate; // hari mulai program — menentukan hari-apa
  final Set<String> restDayKeys; // hari libur/istirahat, mis. {"sat"} atau {"sat","wed"}

  const ProgramSettings({
    required this.startWeight,
    required this.goalWeight,
    required this.totalWeeks,
    required this.startDate,
    required this.restDayKeys,
  });

  factory ProgramSettings.defaults() => ProgramSettings(
        startWeight: ProgramDefaults.startWeight,
        goalWeight: ProgramDefaults.goalWeight,
        totalWeeks: ProgramDefaults.totalWeeks,
        startDate: ProgramDefaults.startDate,
        restDayKeys: {...ProgramDefaults.restDayKeys},
      );

  ProgramSettings copyWith({
    double? startWeight,
    double? goalWeight,
    int? totalWeeks,
    DateTime? startDate,
    Set<String>? restDayKeys,
  }) {
    return _normalize(ProgramSettings(
      startWeight: startWeight ?? this.startWeight,
      goalWeight: goalWeight ?? this.goalWeight,
      totalWeeks: totalWeeks ?? this.totalWeeks,
      startDate: startDate ?? this.startDate,
      restDayKeys: restDayKeys ?? this.restDayKeys,
    ));
  }

  /// Menjaga agar kombinasi pengaturan selalu valid:
  /// - minimal 1 hari latihan tersisa (rest days tidak boleh melahap semua 7 hari)
  /// - durasi minimal 1 minggu
  static ProgramSettings _normalize(ProgramSettings s) {
    var rest = {...s.restDayKeys}..removeWhere((k) => !dayKeysByDow.contains(k));
    if (rest.length > 5) {
      // sisakan minimal 2 hari latihan
      rest = rest.toList().take(5).toSet();
    }
    final weeks = s.totalWeeks < 1 ? 1 : s.totalWeeks;
    return ProgramSettings(
      startWeight: s.startWeight,
      goalWeight: s.goalWeight,
      totalWeeks: weeks,
      startDate: DateTime(s.startDate.year, s.startDate.month, s.startDate.day),
      restDayKeys: rest,
    );
  }

  /// Hari sesi jarak jauh dihitung otomatis oleh algoritma, bukan lagi
  /// dipilih manual oleh pengguna: hari latihan pertama dalam satu minggu
  /// (dimulai dari Minggu) yang bukan hari libur. Otomatis menyesuaikan
  /// begitu pengguna mengubah hari libur mereka.
  String get longRunDayKey => dayKeysByDow.firstWhere(
        (k) => !restDayKeys.contains(k),
        orElse: () => dayKeysByDow.first,
      );

  int get startDow => startDate.weekday % 7; // Dart: Mon=1..Sun=7 -> 0=Sun..6=Sat

  /// Panjang minggu pertama: dari hari mulai sampai Sabtu (inklusif).
  /// Kalau mulai hari Minggu, minggu pertama otomatis genap 7 hari.
  int get week1Length => (6 - startDow) + 1;

  /// Minggu ke-2 dan seterusnya selalu mulai hari Minggu.
  DateTime get week2Start => startDate.add(Duration(days: week1Length));

  Map<String, dynamic> toJson() => {
        "startWeight": startWeight,
        "goalWeight": goalWeight,
        "totalWeeks": totalWeeks,
        "startDate": startDate.toIso8601String(),
        "restDayKeys": restDayKeys.toList(),
      };

  factory ProgramSettings.fromJson(Map<String, dynamic> j) {
    final d = ProgramSettings.defaults();
    try {
      return _normalize(ProgramSettings(
        startWeight: (j["startWeight"] as num?)?.toDouble() ?? d.startWeight,
        goalWeight: (j["goalWeight"] as num?)?.toDouble() ?? d.goalWeight,
        totalWeeks: (j["totalWeeks"] as num?)?.toInt() ?? d.totalWeeks,
        startDate: j["startDate"] != null ? DateTime.parse(j["startDate"] as String) : d.startDate,
        restDayKeys: j["restDayKeys"] != null
            ? Set<String>.from(j["restDayKeys"] as List)
            : d.restDayKeys,
      ));
    } catch (_) {
      return d;
    }
  }
}

class Phase {
  final String name;
  final Color color;
  Phase(this.name, this.color);
}

/// Batas antar fase (dalam nomor minggu) — diskalakan proporsional dari
/// pembagian fase aslinya (4/26, 10/26, 20/26 minggu) supaya struktur
/// 4-fase (Rebuild → Ramp Up → Target Volume → Maintain) tetap masuk akal
/// untuk durasi program berapa pun yang dipilih pengguna.
class PhaseBounds {
  final int b1, b2, b3;
  PhaseBounds(this.b1, this.b2, this.b3);
}

PhaseBounds phaseBoundsFor(int totalWeeks) {
  int b1 = (totalWeeks * 4 / 26).round();
  if (b1 < 1) b1 = 1;
  if (b1 > totalWeeks) b1 = totalWeeks;

  int b2 = (totalWeeks * 10 / 26).round();
  if (b2 <= b1) b2 = b1 + 1;
  if (b2 > totalWeeks) b2 = totalWeeks;

  int b3 = (totalWeeks * 20 / 26).round();
  if (b3 <= b2) b3 = b2 + 1;
  if (b3 > totalWeeks) b3 = totalWeeks;

  return PhaseBounds(b1, b2, b3);
}

Phase phaseFor(int week, int totalWeeks) {
  final b = phaseBoundsFor(totalWeeks);
  if (week <= b.b1) return Phase("Rebuild Base", const Color(0xFF5FB3A3));
  if (week <= b.b2) return Phase("Ramp Up", const Color(0xFFE0A94E));
  if (week <= b.b3) return Phase("Target Volume", const Color(0xFFD16B5C));
  return Phase("Maintain & Deload", const Color(0xFF7A8BA6));
}

/// Beban latihan generik untuk satu minggu: nilai untuk hari latihan
/// "berat", hari latihan "ringan" (dua ini berselang-seling per hari
/// kalender), dan hari sesi jarak jauh.
class TrainingLoad {
  final double heavy;
  final double light;
  final double longRun;
  final bool deload;
  TrainingLoad(this.heavy, this.light, this.longRun, this.deload);
}

TrainingLoad targetsForWeek(int week, int totalWeeks) {
  final b = phaseBoundsFor(totalWeeks);

  if (week <= b.b1) {
    return TrainingLoad(30, 25, 40, false);
  }
  if (week <= b.b2) {
    final v = (30 + (week - b.b1) * 2).clamp(0, 40).toDouble();
    final sun = (45 + (week - b.b1 - 1)).clamp(0, 50).toDouble();
    return TrainingLoad(v, v, sun, false);
  }
  if (week <= b.b3) {
    final isDeload = week % 4 == 0;
    const base = 48.0;
    final d = isDeload ? (base * 0.65).roundToDouble() : base;
    return TrainingLoad(d, d, isDeload ? 35 : 52, isDeload);
  }
  final isDeload = (week - b.b3) % 4 == 0;
  const base = 50.0;
  final d = isDeload ? (base * 0.6).roundToDouble() : base;
  return TrainingLoad(d, d, isDeload ? 35 : 54, isDeload);
}

/// Peran tiap hari-dalam-minggu (identitas hari, bukan posisi tampilan):
/// "rest", "longrun", "heavy", atau "light". Dihitung sekali dari
/// pengaturan (hari libur & hari jarak jauh), lalu dipakai sama setiap
/// minggu — persis seperti pola asli (Senin selalu "berat", Selasa selalu
/// "ringan", dst).
Map<String, String> computeDayRoles(ProgramSettings s) {
  final roles = <String, String>{};
  bool nextHeavy = true;
  for (final key in dayKeysByDow) {
    if (s.restDayKeys.contains(key)) {
      roles[key] = "rest";
      continue;
    }
    if (key == s.longRunDayKey) {
      roles[key] = "longrun";
      continue;
    }
    roles[key] = nextHeavy ? "heavy" : "light";
    nextHeavy = !nextHeavy;
  }
  return roles;
}

DateTime dateForSlot(int week, int offset, ProgramSettings s) {
  if (week == 1) return s.startDate.add(Duration(days: offset));
  return s.week2Start.add(Duration(days: (week - 2) * 7 + offset));
}

String formatDateId(DateTime d) => "${d.day} ${monthLabelsId[d.month - 1]} ${d.year}";

class DayPlan {
  final String key;
  final String label;
  final DateTime date;
  final double km;
  final bool rest;
  DayPlan(this.key, this.label, this.date, this.km, this.rest);
}

List<DayPlan> weekPlan(int week, ProgramSettings s) {
  final t = targetsForWeek(week, s.totalWeeks);
  final roles = computeDayRoles(s);
  final length = week == 1 ? s.week1Length : 7;
  final days = <DayPlan>[];
  for (int offset = 0; offset < length; offset++) {
    final d = dateForSlot(week, offset, s);
    final dow = d.weekday % 7; // Dart Mon=1..Sun=7 -> 0=Sun..6=Sat
    final key = dayKeysByDow[dow];
    final role = roles[key] ?? "rest";
    final rest = role == "rest";
    double km;
    switch (role) {
      case "longrun":
        km = t.longRun;
        break;
      case "heavy":
        km = t.heavy;
        break;
      case "light":
        km = t.light;
        break;
      default:
        km = 0.0;
    }
    days.add(DayPlan(key, dayLabelsId[dow], d, rest ? 0.0 : km, rest));
  }
  return days;
}

int estimateCalories(double weightKg, double km) =>
    (weightKg * km * kCalorieFactorFlat).round();
