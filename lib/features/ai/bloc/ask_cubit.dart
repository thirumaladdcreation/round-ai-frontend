import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:round_ai/core/errors/failures.dart';
import 'package:round_ai/core/errors/result.dart';
import 'package:round_ai/core/network/api_error.dart';
import 'package:round_ai/core/network/idempotency_key.dart';
import 'package:round_ai/features/ai/models/ask_reply.dart';
import 'package:round_ai/features/ai/repository/ai_repository.dart';

enum TurnStatus { loading, done, failed }

/// One question and what came back. [key] is the Idempotency-Key for this
/// question: a retry reuses it, a new question or a new topic makes its own.
class AskTurn extends Equatable {
  const AskTurn({
    required this.id,
    required this.question,
    required this.key,
    this.topic,
    this.status = TurnStatus.loading,
    this.reply,
    this.error,
  });

  final int id;
  final String question;
  final String key;
  final String? topic;
  final TurnStatus status;
  final AskReply? reply;
  final ApiError? error;

  AskTurn copyWith({TurnStatus? status, AskReply? reply, ApiError? error}) {
    return AskTurn(
      id: id,
      question: question,
      key: key,
      topic: topic,
      status: status ?? this.status,
      reply: reply ?? this.reply,
      error: error,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    id,
    question,
    topic,
    status,
    reply,
    error?.code,
  ];
}

class AskState extends Equatable {
  const AskState({this.turns = const <AskTurn>[]});

  final List<AskTurn> turns;

  /// Only one question runs at a time.
  bool get busy => turns.any((AskTurn t) => t.status == TurnStatus.loading);

  @override
  List<Object> get props => <Object>[turns];
}

/// Questions about one patient. The scope is fixed to [patientId].
class AskCubit extends Cubit<AskState> {
  AskCubit(this._repository, this.patientId) : super(const AskState());

  final AiRepository _repository;
  final String patientId;

  int _nextId = 1;
  CancelToken? _cancel;

  Future<void> ask(String question, {String? topic}) async {
    final String text = question.trim();
    if (text.isEmpty || state.busy) return;
    final String? cleanTopic = topic?.trim().isEmpty ?? true
        ? null
        : topic!.trim();
    final AskTurn turn = AskTurn(
      id: _nextId++,
      question: text,
      topic: cleanTopic,
      key: IdempotencyKey.create(),
    );
    emit(AskState(turns: <AskTurn>[...state.turns, turn]));
    await _run(turn);
  }

  /// Same question again, same key.
  Future<void> retry(int turnId) async {
    if (state.busy) return;
    final AskTurn? turn = _find(turnId);
    if (turn == null || turn.status != TurnStatus.failed) return;
    _replace(turn.copyWith(status: TurnStatus.loading));
    await _run(turn);
  }

  /// The backend asked for a topic. It is a new question to the backend, so
  /// it gets its own key.
  Future<void> answerTopic(int turnId, String topic) async {
    final AskTurn? turn = _find(turnId);
    if (turn == null) return;
    await ask(turn.question, topic: topic);
  }

  void cancel() => _cancel?.cancel();

  AskTurn? _find(int id) {
    for (final AskTurn t in state.turns) {
      if (t.id == id) return t;
    }
    return null;
  }

  void _replace(AskTurn turn) {
    emit(
      AskState(
        turns: <AskTurn>[
          for (final AskTurn t in state.turns) t.id == turn.id ? turn : t,
        ],
      ),
    );
  }

  Future<void> _run(AskTurn turn) async {
    final CancelToken token = _cancel = CancelToken();
    final Result<AskReply> result = await _repository.ask(
      patientId,
      question: turn.question,
      topic: turn.topic,
      idempotencyKey: turn.key,
      cancelToken: token,
    );
    if (isClosed) return;
    switch (result) {
      case Err<AskReply>(:final failure):
        _replace(
          turn.copyWith(status: TurnStatus.failed, error: failure.apiError),
        );
      case Ok<AskReply>(:final value):
        _replace(turn.copyWith(status: TurnStatus.done, reply: value));
    }
  }

  @override
  Future<void> close() {
    _cancel?.cancel();
    return super.close();
  }
}
