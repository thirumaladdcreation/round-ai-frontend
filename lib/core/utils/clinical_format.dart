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
    return t.replaceFirst(
      'extracted fact(s) not yet reviewed (excluded)',
      'chart fact(s) waiting for review',
    );
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

bool looksLikeTrendMap(Map<String, dynamic> map) {
  return map.containsKey('from') ||
      map.containsKey('to') ||
      map.containsKey('direction') ||
      map.containsKey('delta') ||
      map.containsKey('unit');
}

bool looksLikeConflictMap(Map<String, dynamic> map) {
  final String type = _first(map, const <String>['type', 'kind']).toLowerCase();
  return map.containsKey('fact_ids') ||
      type.contains('conflict') ||
      map.containsKey('values') ||
      map.containsKey('value_a') ||
      map.containsKey('value_b');
}

/// Trend objects from `computeTrends`: label/from/to/unit/direction.
String formatTrendMap(Map<String, dynamic> map) {
  final String label = _first(map, const <String>[
    'label',
    'name',
    'title',
    'metric',
  ]);
  final String unit = _first(map, const <String>['unit']);
  final String direction = _first(map, const <String>['direction']).toLowerCase();
  final String fromVal = _valueToken(
    map,
    const <String>['from', 'previous', 'prior', 'old', 'start'],
  );
  final String toVal = _valueToken(
    map,
    const <String>['to', 'current', 'new', 'end', 'latest'],
  );

  if (label.isNotEmpty && fromVal.isNotEmpty && toVal.isNotEmpty) {
    final String verb = _trendVerb(direction, fromVal, toVal);
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
  if (text.isNotEmpty && !_looksTechnicalDump(text)) {
    return text;
  }

  // Never dump wire keys (delta, direction, fact_id) into the clinician UI.
  if (label.isNotEmpty) {
    if (toVal.isNotEmpty) {
      final String u = unit.isEmpty ? '' : ' $unit';
      return direction.isEmpty
          ? '$label is $toVal$u'
          : '$label ${_trendVerb(direction, fromVal, toVal)} to $toVal$u';
    }
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
  final String sources = _sourcesLine(map);
  final String type = _first(map, const <String>['type', 'kind']).toLowerCase();
  final String label = _first(map, const <String>[
    'label',
    'name',
    'title',
    'metric',
  ]);
  final String values = _conflictValues(map);

  String core;
  if (text.isNotEmpty && !_looksTechnicalDump(text)) {
    core = text;
  } else if (type.contains('value') && label.isNotEmpty) {
    core = values.isEmpty
        ? '$label has different values at the same time.'
        : '$label has conflicting values: $values.';
  } else if (type.contains('assertion') && label.isNotEmpty) {
    core = '$label is documented as both present and absent.';
  } else if (label.isNotEmpty && values.isNotEmpty) {
    core = '$label conflict: $values.';
  } else if (label.isNotEmpty) {
    core = '$label has conflicting chart facts.';
  } else if (values.isNotEmpty) {
    core = 'Conflicting values: $values.';
  } else {
    core = 'Conflicting chart facts need review.';
  }

  if (sources.isEmpty) return core;
  return '$core Sources: $sources';
}

String formatInsightMap(Map<String, dynamic> map) {
  if (looksLikeTrendMap(map) && !looksLikeConflictMap(map)) {
    return formatTrendMap(map);
  }
  if (looksLikeConflictMap(map)) {
    return formatConflictMap(map);
  }
  if (map.containsKey('from') && map.containsKey('to')) {
    return formatTrendMap(map);
  }
  return formatConflictMap(map);
}

List<String> insightFactIds(Map<String, dynamic> map) {
  final Object? raw = map['fact_ids'] ?? map['factIds'] ?? map['sources'];
  if (raw is! List) return const <String>[];
  return raw
      .map((Object? e) {
        if (e is Map) {
          return _first(Map<String, dynamic>.from(e), const <String>[
            'fact_id',
            'id',
            'factId',
          ]);
        }
        return e?.toString().trim() ?? '';
      })
      .where((String id) => id.isNotEmpty && !_looksLikeUuidOnlyDisplay(id))
      .toList();
}

/// Prefer opening the source drawer over printing UUIDs; still return IDs.
List<String> insightFactIdsRaw(Map<String, dynamic> map) {
  final Object? raw = map['fact_ids'] ?? map['factIds'];
  if (raw is! List) return const <String>[];
  return raw
      .map((Object? e) {
        if (e is Map) {
          return _first(Map<String, dynamic>.from(e), const <String>[
            'fact_id',
            'id',
            'factId',
          ]);
        }
        return e?.toString().trim() ?? '';
      })
      .where((String id) => id.isNotEmpty)
      .toList();
}

String _trendVerb(String direction, String fromVal, String toVal) {
  switch (direction) {
    case 'rose':
    case 'up':
    case 'increased':
    case 'rising':
    case 'increase':
      return 'increased';
    case 'fell':
    case 'down':
    case 'decreased':
    case 'falling':
    case 'decrease':
      return 'decreased';
    case 'unchanged':
    case 'stable':
    case 'same':
      return 'unchanged';
  }
  final double? a = double.tryParse(fromVal.replaceAll(',', ''));
  final double? b = double.tryParse(toVal.replaceAll(',', ''));
  if (a != null && b != null) {
    if (b > a) return 'increased';
    if (b < a) return 'decreased';
    return 'unchanged';
  }
  return direction.isEmpty ? 'changed' : direction;
}

String _valueToken(Map<String, dynamic> map, List<String> keys) {
  for (final String key in keys) {
    final Object? v = map[key];
    if (v == null) continue;
    if (v is Map) {
      final String nested = _first(Map<String, dynamic>.from(v), const <String>[
        'value',
        'val',
        'amount',
        'text',
      ]);
      if (nested.isNotEmpty) return nested;
      continue;
    }
    final String s = v.toString().trim();
    if (s.isNotEmpty && s != 'null') return s;
  }
  return '';
}

String _conflictValues(Map<String, dynamic> map) {
  final Object? values = map['values'];
  if (values is List && values.isNotEmpty) {
    return values
        .map((Object? e) {
          if (e is Map) {
            return _first(Map<String, dynamic>.from(e), const <String>[
              'value',
              'text',
              'label',
            ]);
          }
          return e?.toString().trim() ?? '';
        })
        .where((String s) => s.isNotEmpty)
        .join(' vs ');
  }
  final String a = _valueToken(map, const <String>[
    'value_a',
    'left',
    'a',
    'first',
  ]);
  final String b = _valueToken(map, const <String>[
    'value_b',
    'right',
    'b',
    'second',
  ]);
  if (a.isNotEmpty && b.isNotEmpty) return '$a vs $b';
  return '';
}

String _sourcesLine(Map<String, dynamic> map) {
  final String direct = _first(map, const <String>[
    'sources_text',
    'source_summary',
    'passages',
  ]);
  if (direct.isNotEmpty && !_looksLikeUuidOnlyDisplay(direct)) return direct;

  final Object? sources = map['sources'] ?? map['source_texts'];
  if (sources is List && sources.isNotEmpty) {
    final List<String> bits = <String>[];
    for (final Object? e in sources) {
      if (e is Map) {
        final String passage = _first(Map<String, dynamic>.from(e),
            const <String>['text', 'passage', 'excerpt', 'quote', 'label']);
        if (passage.isNotEmpty && !_looksLikeUuidOnlyDisplay(passage)) {
          bits.add(passage);
        }
      } else {
        final String s = e?.toString().trim() ?? '';
        if (s.isNotEmpty && !_looksLikeUuidOnlyDisplay(s)) bits.add(s);
      }
    }
    if (bits.isNotEmpty) return bits.join(' · ');
  }

  final List<String> ids = insightFactIdsRaw(map);
  if (ids.isEmpty) return '';
  return ids.length == 1
      ? '1 linked chart fact (open Sources to review)'
      : '${ids.length} linked chart facts (open Sources to review)';
}

bool _looksTechnicalDump(String text) {
  final String t = text.toLowerCase();
  if (t.contains('fact_id') || t.contains('fact-id')) return true;
  if (RegExp(r'\bdelta\b').hasMatch(t) && RegExp(r'\bdirection\b').hasMatch(t)) {
    return true;
  }
  if (t.contains('clinician_')) return true;
  // "Creatinine / mg/dL / 1.2 / up" style dumps
  final List<String> parts = text
      .split(RegExp(r'\s*/\s*'))
      .map((String p) => p.trim())
      .where((String p) => p.isNotEmpty)
      .toList();
  if (parts.length >= 3) {
    final bool hasUnitish = parts.any(
      (String p) => RegExp(r'^(mg/dL|mmol/L|%|mmHg|bpm|g/dL)$', caseSensitive: false)
          .hasMatch(p),
    );
    final bool hasDir = parts.any(
      (String p) =>
          <String>['up', 'down', 'rose', 'fell', 'increased', 'decreased']
              .contains(p.toLowerCase()),
    );
    if (hasUnitish || hasDir) return true;
  }
  return false;
}

bool _looksLikeUuidOnlyDisplay(String value) {
  return RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    caseSensitive: false,
  ).hasMatch(value.trim());
}

String _first(Map<String, dynamic> map, List<String> keys) {
  for (final String key in keys) {
    final Object? v = map[key];
    if (v == null) continue;
    final String s = v.toString().trim();
    if (s.isNotEmpty && s != 'null') return s;
  }
  return '';
}
