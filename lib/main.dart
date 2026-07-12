import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'app_state.dart';
import 'screens/home_shell.dart';
import 'screens/program_settings_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProgressHubApp());
}

/// Material 3 di Android secara default memakai efek overscroll "stretch"
/// (mirip efek karet Android 12+) — begitu list ditarik melebihi batas,
/// KONTENNYA di-transform/di-scale secara non-uniform. Karena panel
/// GlassCard yang blur-nya BackdropFilter ada di dalam konten yang
/// di-scale itu, hasil blur-nya ikut terdistorsi/tidak konsisten.
///
/// Tapi rasa "rubbery" itu sendiri tetap bisa dipertahankan lewat jenis
/// overscroll LAIN: rubber-band ala iOS ([BouncingScrollPhysics]) — konten
/// cuma DIGESER (translasi) melewati batas lalu mantul balik pegas,
/// TIDAK PERNAH di-scale/diregangkan. Translasi murni tidak pernah
/// mendistorsi hasil blur (beda dari scale/stretch) — jadi builder ini
/// tetap kelihatan rubbery & hidup, tapi blur di dalam panel tetap tajam
/// & konsisten di sepanjang gerakannya, termasuk saat ditarik lewat batas.
class _NoStretchScrollBehavior extends MaterialScrollBehavior {
  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
  }

  // BouncingScrollPhysics sudah punya efek pantulnya sendiri secara visual
  // (translasi + pegas) — tidak perlu overlay glow/stretch tambahan di atasnya.
  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) {
    return child;
  }

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.stylus,
        PointerDeviceKind.trackpad,
      };
}

class ProgressHubApp extends StatefulWidget {
  const ProgressHubApp({super.key});
  @override
  State<ProgressHubApp> createState() => _ProgressHubAppState();
}

class _ProgressHubAppState extends State<ProgressHubApp> {
  final AppState appState = AppState();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    appState.load().then((_) => setState(() => _loading = false));
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: appState,
      child: Consumer<AppState>(
        builder: (context, state, _) {
          final accent = state.accentColor;
          return MaterialApp(
            title: '110 → 80 kg — Progress Hub',
            debugShowCheckedModeBanner: false,
            scrollBehavior: _NoStretchScrollBehavior(),
            theme: ThemeData(
              useMaterial3: true,
              brightness: Brightness.dark,
              scaffoldBackgroundColor: const Color(0xFF0A0D12),
              colorScheme: ColorScheme.fromSeed(
                seedColor: accent,
                brightness: Brightness.dark,
              ).copyWith(
                primary: accent,
                surface: const Color(0xFF10141B),
              ),
              // Inter: sans modern, netral & sangat mudah dibaca di ukuran
              // kecil — dipakai untuk semua teks UI (mirip nuansa font pada
              // Komoot/Strava/Whoop). Angka statistik besar pakai Sora lewat
              // AppFonts.stat() supaya terasa lebih tegas & "sport-tech".
              textTheme: GoogleFonts.interTextTheme(
                ThemeData(brightness: Brightness.dark).textTheme,
              ),
              navigationBarTheme: NavigationBarThemeData(
                labelTextStyle: MaterialStateProperty.resolveWith((states) {
                  final selected = states.contains(MaterialState.selected);
                  return GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    color: selected ? Colors.white : const Color(0xFF8B97A8),
                  );
                }),
              ),
            ),
            home: _loading
                ? const Scaffold(
                    backgroundColor: Color(0xFF0A0D12),
                    body: Center(child: CircularProgressIndicator()),
                  )
                : (state.hasCompletedSetup
                    ? const HomeShell()
                    : const ProgramSettingsScreen(isOnboarding: true)),
          );
        },
      ),
    );
  }
}
