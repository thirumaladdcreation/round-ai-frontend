import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:round_ai/core/errors/result.dart';
import 'package:round_ai/features/ai/repository/ai_repository.dart';
import 'package:round_ai/features/patient/models/fact.dart';

enum SourceLoad { loading, ready, failed }

/// The source of one fact behind a claim.
class SourceEntry extends Equatable {
  const SourceEntry({
    required this.factId,
    this.load = SourceLoad.loading,
    this.source,
    this.message,
  });

  final String factId;
  final SourceLoad load;
  final SourcePassage? source;
  final String? message;

  @override
  List<Object?> get props => <Object?>[factId, load, source, message];
}

class SourceDrawerState extends Equatable {
  const SourceDrawerState(this.entries);

  final List<SourceEntry> entries;

  @override
  List<Object> get props => <Object>[entries];
}

/// Loads the passage and source for each fact of a claim.
class SourceDrawerCubit extends Cubit<SourceDrawerState> {
  SourceDrawerCubit(this._repository, this.factIds)
    : super(
        SourceDrawerState(<SourceEntry>[
          for (final String id in factIds) SourceEntry(factId: id),
        ]),
      );

  final AiRepository _repository;
  final List<String> factIds;

  Future<void> load() => Future.wait(<Future<void>>[
    for (final String id in factIds) _loadOne(id),
  ]);

  Future<void> retry(String factId) => _loadOne(factId);

  Future<void> _loadOne(String factId) async {
    _set(SourceEntry(factId: factId));
    final Result<SourcePassage> result = await _repository.factSource(factId);
    if (isClosed) return;
    switch (result) {
      case Err<SourcePassage>(:final failure):
        _set(
          SourceEntry(
            factId: factId,
            load: SourceLoad.failed,
            message: failure.message,
          ),
        );
      case Ok<SourcePassage>(:final value):
        _set(
          SourceEntry(factId: factId, load: SourceLoad.ready, source: value),
        );
    }
  }

  void _set(SourceEntry entry) {
    emit(
      SourceDrawerState(<SourceEntry>[
        for (final SourceEntry e in state.entries)
          e.factId == entry.factId ? entry : e,
      ]),
    );
  }
}
