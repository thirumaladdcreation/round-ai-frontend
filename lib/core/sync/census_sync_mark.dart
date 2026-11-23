import 'package:round_ai/core/di/injection_container.dart';

/// Marks Census/Today lists stale after a chart mutation. Safe when DI
/// is not initialized (widget tests).
void markCensusDirty() {
  try {
    InjectionContainer.instance.censusSync.markDirty();
  } catch (_) {}
}

/// Applies mutation `patient_status` into [PatientStatusStore] when present.
void applyPatientStatusFromBody(Object? body) {
  try {
    InjectionContainer.instance.patientStatusStore.applyFromResponse(body);
  } catch (_) {}
}
