import 'package:flutter/foundation.dart';

/// Live AI provider from `GET /health` (mock vs openai).
///
/// Used to show a persistent MOCK AI banner when the backend is mock.
class AiProviderStore extends ChangeNotifier {
  String? _provider;
  String? _model;

  String? get provider => _provider;
  String? get model => _model;

  bool get isMock => (_provider ?? '').toLowerCase() == 'mock';

  void applyHealth(Map<String, dynamic> health) {
    final String? nextProvider = health['provider']?.toString();
    final String? nextModel = health['model']?.toString();
    if (nextProvider == _provider && nextModel == _model) return;
    _provider = nextProvider;
    _model = nextModel;
    notifyListeners();
  }
}
