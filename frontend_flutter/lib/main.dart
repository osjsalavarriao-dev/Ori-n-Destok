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
            seedColor: const Color(0xFF38BDF8),
            brightness: Brightness.dark,
            surface: const Color(0xFF101827),
          ),
          scaffoldBackgroundColor: const Color(0xFF060913),
          useMaterial3: true,
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
