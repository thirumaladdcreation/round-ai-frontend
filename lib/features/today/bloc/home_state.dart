import 'package:equatable/equatable.dart';
import 'package:round_ai/features/today/models/home_snapshot.dart';

sealed class HomeState extends Equatable {
  const HomeState();
}

class HomeLoading extends HomeState {
  const HomeLoading();

  @override
  List<Object?> get props => <Object?>[];
}

class HomeReady extends HomeState {
  const HomeReady(this.snapshot);

  final HomeSnapshot snapshot;

  @override
  List<Object?> get props => <Object?>[
    snapshot.clinicianName,
    snapshot.patientCount,
    snapshot.pendingTaskCount,
    snapshot.draftsAwaitingReview,
    snapshot.roundsStatus,
    snapshot.attention.map((HomeAttentionItem i) => i.id).toList(),
  ];
}

class HomeFailure extends HomeState {
  const HomeFailure(this.message);

  final String message;

  @override
  List<Object?> get props => <Object?>[message];
}
