import 'package:material_ui/material_ui.dart';

import 'l10n/language.dart';
import 'screens/edge_shell.dart';

void main() => runApp(const HorionApp());

class HorionApp extends StatefulWidget {
  /// [language] fija el idioma inicial; por defecto, el del sistema.
  const HorionApp({super.key, this.language});
  final AppLanguage? language;
  @override
  State<HorionApp> createState() => _HorionAppState();
}

class _HorionAppState extends State<HorionApp> {
  late final language = LanguageController(widget.language ?? systemLanguage());

  @override
  void dispose() {
    language.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LanguageScope(
    controller: language,
    child: ValueListenableBuilder(
      valueListenable: language,
      builder: (context, lang, _) => MaterialApp(
        title: 'Horion Edge',
        debugShowCheckedModeBanner: false,
        locale: lang.locale,
        supportedLocales: [for (final l in AppLanguage.values) l.locale],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: ThemeData(
          brightness: Brightness.dark,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF67E8D3),
            brightness: Brightness.dark,
            surface: const Color(0xFF111E25),
          ),
          scaffoldBackgroundColor: const Color(0xFF071219),
          useMaterial3: true,
          cardTheme: CardThemeData(
            elevation: 0,
            margin: const EdgeInsets.all(4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: Color(0xFF293B44)),
            ),
          ),
          navigationRailTheme: const NavigationRailThemeData(
            indicatorColor: Color(0xFF20483F),
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF071219),
            elevation: 0,
          ),
          inputDecorationTheme: const InputDecorationTheme(
            border: OutlineInputBorder(),
            filled: true,
          ),
        ),
        home: const EdgeShell(),
      ),
    ),
  );
}
