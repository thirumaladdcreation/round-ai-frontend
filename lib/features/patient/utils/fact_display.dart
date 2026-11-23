import 'package:round_ai/features/patient/models/fact.dart';

/// Clinician-facing value line for a chart fact (keeps O₂ context when present).
String factValueLine(Fact fact) {
  final String base = <String>[
    fact.value.trim(),
    if (fact.unit != null && fact.unit!.trim().isNotEmpty) fact.unit!.trim(),
  ].where((String s) => s.isNotEmpty).join(' ');
  final String qualifier = (fact.qualifier ?? '').trim();
  final String context = qualifier.isNotEmpty
      ? qualifier
      : oxygenContextHint(fact);
  if (base.isEmpty) {
    return context.isEmpty ? 'Not entered' : context;
  }
  if (context.isEmpty) return base;
  // Avoid "88% · room air" twice if value already includes it.
  if (base.toLowerCase().contains(context.toLowerCase())) return base;
  return '$base · $context';
}

/// Room air / supplemental O₂ hint from name, value, or passage.
String oxygenContextHint(Fact fact) {
  final String blob = <String>[
    fact.name,
    fact.value,
    if (fact.unit != null) fact.unit!,
    if (fact.passage != null) fact.passage!,
  ].join(' ').toLowerCase();

  final bool looksOxygen =
      blob.contains('spo2') ||
      blob.contains('spo₂') ||
      blob.contains('o2 sat') ||
      blob.contains('oxygen sat') ||
      (RegExp(r'\bsat\b').hasMatch(blob) && blob.contains('o2')) ||
      blob.contains('nasal cannula') ||
      blob.contains('room air') ||
      blob.contains('nrb') ||
      blob.contains('bipap') ||
      blob.contains('cpap');

  if (!looksOxygen) return '';

  if (blob.contains('room air') ||
      blob.contains('on ra') ||
      RegExp(r'\bra\b').hasMatch(blob)) {
    return 'on room air';
  }
  final RegExp liters = RegExp(
    r'(\d+(?:\.\d+)?)\s*l(?:/?min)?(?:\s*(?:nc|nasal cannula))?',
    caseSensitive: false,
  );
  final Match? m = liters.firstMatch(blob);
  if (m != null) {
    return 'on ${m.group(1)} L supplemental O₂';
  }
  if (blob.contains('nasal cannula') || blob.contains(' nc')) {
    return 'on supplemental O₂ (nasal cannula)';
  }
  if (blob.contains('nrb') || blob.contains('non-rebreather')) {
    return 'on non-rebreather';
  }
  if (blob.contains('bipap') || blob.contains('cpap')) {
    return 'on noninvasive ventilation';
  }
  if (blob.contains('supplemental') || blob.contains('oxygen')) {
    return 'check room air vs supplemental O₂';
  }
  return '';
}

bool factNeedsOxygenContext(Fact fact) {
  final String name = fact.name.toLowerCase();
  return name.contains('spo2') ||
      name.contains('spo₂') ||
      name.contains('oxygen') ||
      name.contains('o2 sat');
}
