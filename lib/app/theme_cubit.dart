import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:round_ai/core/storage/app_storage.dart';

/// Remembers Light, Dark, or System across app launches.
class ThemeCubit extends Cubit<ThemeMode> {
  ThemeCubit(this._storage) : super(_storage.themeMode);

  final AppStorage _storage;

  Future<void> setMode(ThemeMode mode) async {
    await _storage.saveThemeMode(mode);
    emit(mode);
  }
}
