import 'dart:ui' show PlatformDispatcher;

import 'package:material_ui/material_ui.dart';

/// Idiomas de la interfaz. Para añadir uno: agrega el valor aquí, su campo en
/// [T] y las traducciones (el compilador señala los `switch` incompletos).
enum AppLanguage { es, en }

extension AppLanguageInfo on AppLanguage {
  /// Nombre del idioma en ese mismo idioma.
  String get nativeName => switch (this) {
    AppLanguage.es => 'Español',
    AppLanguage.en => 'English',
  };
  Locale get locale => Locale(name);
}

/// Idioma del sistema si está soportado; si no, inglés.
AppLanguage systemLanguage() {
  final code = PlatformDispatcher.instance.locale.languageCode;
  return AppLanguage.values.firstWhere(
    (l) => l.name == code,
    orElse: () => AppLanguage.en,
  );
}

/// Texto traducido. Se usa en datos constantes (base de conocimiento, entornos)
/// y en el controlador, donde no hay BuildContext.
class T {
  const T(this.es, this.en);
  final String es, en;
  String of(AppLanguage language) => switch (language) {
    AppLanguage.es => es,
    AppLanguage.en => en,
  };

  /// Un T dentro de '${...}' es un error: siempre mostraría el mismo idioma.
  /// En debug y en las pruebas falla para detectarlo.
  @override
  String toString() {
    assert(false, 'T interpolado sin traducir: usa context.t() o .of(language) ("$es")');
    return es;
  }
}

class LanguageController extends ValueNotifier<AppLanguage> {
  LanguageController(super.value);
}

/// Expone el idioma actual al árbol de widgets y los reconstruye al cambiarlo.
class LanguageScope extends InheritedNotifier<LanguageController> {
  const LanguageScope({
    super.key,
    required LanguageController controller,
    required super.child,
  }) : super(notifier: controller);

  static LanguageController controllerOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<LanguageScope>()!
      .notifier!;
}

extension LanguageContext on BuildContext {
  AppLanguage get lang => LanguageScope.controllerOf(this).value;

  /// Texto en línea: `context.tr('Guardar', 'Save')`.
  String tr(String es, String en) => T(es, en).of(lang);

  /// Texto de un dato constante: `context.t(indicator.name)`.
  String t(T text) => text.of(lang);
}

/// Botón de la barra superior para cambiar de idioma.
class LanguageMenu extends StatelessWidget {
  const LanguageMenu({super.key});
  @override
  Widget build(BuildContext context) {
    final controller = LanguageScope.controllerOf(context);
    return PopupMenuButton<AppLanguage>(
      tooltip: context.tr('Idioma', 'Language'),
      initialValue: controller.value,
      onSelected: (l) => controller.value = l,
      itemBuilder: (_) => [
        for (final l in AppLanguage.values)
          PopupMenuItem(value: l, child: Text(l.nativeName)),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.translate, size: 18),
            const SizedBox(width: 6),
            Text(controller.value.name.toUpperCase()),
          ],
        ),
      ),
    );
  }
}
