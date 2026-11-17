/// Formats backend chart insights for clinicians (no wire keys or IDs).
library;

String humanizeMissingToken(String raw) {
  final String t = raw.trim();
  if (t.isEmpty) return t;
  switch (t) {
    case 'clinician_plan':
      return "Today's Assessment and Plan not entered";
    case 'clinician_subjective':
      return 'Subjective not entered';
    case 'clinician_exam':
      return 'Exam not entered';
    case 'clinician_update':
      return 'Clinical update not entered';
    case 'clinician_support':
      return 'Supporting details not entered';
    case 'no reviewed chart facts':
      return 'No reviewed chart facts yet';
    case 'some facts have no event time':
      return 'Some facts have no event time';
  }
  if (t.startsWith('clinician_history')) {
    return 'History section not entered';
  }
  if (t.startsWith('section_')) {
    return 'Note section not entered';
  }
  if (RegExp(r'^\d+ extracted fact').hasMatch(t)) {
    return t.replaceFirst('extracted fact(s) not yet reviewed (excluded)',
        'chart fact(s) waiting for review');
  }
  if (t.contains('_')) {
    return t
        .split('_')
        .where((String p) => p.isNotEmpty)
        .map(
          (String p) =>
              '${p[0].toUpperCase()}${p.length > 1 ? p.substring(1) : ''}',
        )
        .join(' ');
  }
  return t;
}

/// Trend objects from `computeTrends`: label/from/to/unit/direction.
String formatTrendMap(Map<String, dynamic> map) {
  final String label = _first(map, const <String>['label', 'name', 'title']);
  final String unit = _first(map, const <String>['unit']);
  final String direction = _first(map, const <String>['direction']);
  final Object? from = map['from'];
  final Object? to = map['to'];
  final String fromVal = from is Map
      ? _first(Map<String, dynamic>.from(from), const <String>['value'])
      : '';
  final String toVal = to is Map
      ? _first(Map<String, dynamic>.from(to), const <String>['value'])
      : '';
  if (label.isNotEmpty && fromVal.isNotEmpty && toVal.isNotEmpty) {
    final String verb = switch (direction) {
      'rose' || 'up' || 'increased' => 'increased',
      'fell' || 'down' || 'decreased' => 'decreased',
      'unchanged' => 'unchanged',
      _ => direction.isEmpty ? 'changed' : direction,
    };
    final String u = unit.isEmpty ? '' : ' $unit';
    if (verb == 'unchanged') {
      return '$label unchanged at $toVal$u';
    }
    return '$label $verb from $fromVal to $toVal$u'.trim();
  }
  final String text = _first(map, const <String>[
    'text',
    'detail',
    'description',
    'summary',
    'message',
  ]);
  if (text.isNotEmpty) return text;
  // Never dump wire keys (delta, direction, fact_id) into the clinician UI.
  if (label.isNotEmpty) {
    return unit.isEmpty ? label : '$label ($unit)';
  }
  return 'Trend available in chart facts';
}

String formatConflictMap(Map<String, dynamic> map) {
  final String text = _first(map, const <String>[
    'text',
    'detail',
    'description',
    'summary',
    'message',
  ]);
  final String sources = _first(map, const <String>[
    'sources_text',
    'source_summary',
    'passages',
  ]);
  if (text.isNotEmpty) {
    return sources.isEmpty ? text : '$text Sources: $sources';
  }
  final String type = _first(map, const <String>['type', 'kind']);
  final String label = _first(map, const <String>['label', 'name', 'title']);
  if (type == 'value_conflict' && label.isNotEmpty) {
    final String msg = '$label has different values at the same time.';
    return sources.isEmpty ? msg : '$msg Sources: $sources';
  }
  if (type == 'assertion_conflict' && label.isNotEmpty) {
    final String msg = '$label is documented as both present and absent.';
    return sources.isEmpty ? msg : '$msg Sources: $sources';
  }
  if (label.isNotEmpty) return label;
  return 'Conflicting chart facts need review';
}

String formatInsightMap(Map<String, dynamic> map) {
  if (map.containsKey('from') && map.containsKey('to')) {
    return formatTrendMap(map);
  }
  if (map.containsKey('fact_ids') ||
      map['type'] == 'value_conflict' ||
      map['type'] == 'assertion_conflict') {
    return formatConflictMap(map);
  }
  return formatConflictMap(map);
}

String _first(Map<String, dynamic> map, List<String> keys) {
  for (final String key in keys) {
    final Object? v = map[key];
    if (v == null) continue;
    final String s = v.toString().trim();
    if (s.isNotEmpty) return s;
  }
  return '';
}
