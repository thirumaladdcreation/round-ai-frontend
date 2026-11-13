import 'package:round_ai/core/errors/failures.dart';
import 'package:round_ai/core/errors/result.dart';
import 'package:round_ai/features/patient/models/chart_source.dart';
import 'package:round_ai/features/patient/models/fact.dart';
import 'package:round_ai/features/patient/repository/chart_data_repository.dart';

/// In-memory chart data for `USE_DEMO=true`. Reading facts out of text needs
/// the backend, so demo mode does not pretend to: it only keeps manual facts.
class DemoChartDataRepository implements ChartDataRepository {
  final Map<String, List<Fact>> _pending = <String, List<Fact>>{};
  int _next = 1;

  @override
  Future<Result<ChartSource>> addSource(
    String patientId, {
    required ChartSourceKind kind,
    required DateTime time,
    required String text,
  }) async {
    return Ok<ChartSource>(
      ChartSource(id: 'demo-src-${_next++}', kind: kind, time: time),
    );
  }

  @override
  Future<Result<List<ChartSource>>> listSources(String patientId) async =>
      const Ok<List<ChartSource>>(<ChartSource>[]);

  @override
  Future<Result<void>> extract(String patientId, String sourceId) async {
    return const Err<void>(
      ValidationFailure(
        'Reading facts from text needs the backend. Add facts by hand in demo mode.',
      ),
    );
  }

  @override
  Future<Result<List<Fact>>> pendingFacts(String patientId) async {
    return Ok<List<Fact>>(List<Fact>.of(_pending[patientId] ?? const <Fact>[]));
  }

  @override
  Future<Result<void>> decide(
    String patientId,
    List<String> factIds, {
    required bool confirm,
  }) async {
    final Set<String> ids = factIds.toSet();
    final List<Fact>? list = _pending[patientId];
    list?.removeWhere((Fact f) => ids.contains(f.id));
    return const Ok<void>(null);
  }

  @override
  Future<Result<void>> addFact(String patientId, NewFact fact) async {
    _pending
        .putIfAbsent(patientId, () => <Fact>[])
        .add(
          Fact(
            id: 'demo-fact-${_next++}',
            name: fact.name,
            value: fact.value,
            unit: fact.unit,
            eventTime: fact.eventTime,
            status: FactStatus.pending,
          ),
        );
    return const Ok<void>(null);
  }
}
