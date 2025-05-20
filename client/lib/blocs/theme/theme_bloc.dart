import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme_event.dart';
import 'theme_state.dart';

class ThemeBloc extends Bloc<ThemeEvent, ThemeState> {
  final SharedPreferences prefs;
  static const String _themeKey = 'is_dark_mode';

  ThemeBloc(this.prefs) : super(ThemeState(isDarkMode: prefs.getBool(_themeKey) ?? false)) {
    on<ToggleTheme>(_onToggleTheme);
  }

  void _onToggleTheme(ToggleTheme event, Emitter<ThemeState> emit) async {
    final newIsDarkMode = !state.isDarkMode;
    await prefs.setBool(_themeKey, newIsDarkMode);
    emit(state.copyWith(isDarkMode: newIsDarkMode));
  }
}
