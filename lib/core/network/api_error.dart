/// What went wrong, in terms the UI can react to.
enum ApiErrorKind {
  unauthenticated,
  badCredentials,
  accessDenied,
  noReviewedFacts,
  outdated,
  unresolvedFlags,
  placeholdersRemaining,
  aiDisabled,
  dailyLimit,
  aiUnavailable,
  aiInvalidOutput,
  evidenceRetrievalFailed,
  querySafety,
  tooLarge,
  mimeNotAllowed,
  emptyFile,
  imageUnreadable,
  notApproved,
  notConfirmable,
  teamRequired,
  topicRequired,
  needsProblem,
  permissionDenied,
  chatDisabled,
  rateLimited,
  duplicateMessage,
  messageTooLong,
  emptyThread,
  channelArchived,
  network,
  timeout,
  cancelled,
  other,
}

/// Error from the backend: `{ "error": { "code", "message", "details"? } }`.
///
/// The server `message` is kept for debugging only. Screens show
/// [userMessage], so clinical text from the server is never put on screen.
class ApiError implements Exception {
  const ApiError({
    required this.code,
    required this.message,
    this.details,
    this.status,
  });

  /// No response: no connection, bad certificate, or similar.
  const ApiError.network([this.message = 'No connection.'])
    : code = 'network_error',
      details = null,
      status = null;

  const ApiError.timeout()
    : code = 'timeout',
      message = 'Request timed out.',
      details = null,
      status = null;

  const ApiError.cancelled()
    : code = 'cancelled',
      message = 'Request cancelled.',
      details = null,
      status = null;

  /// Reads the error envelope. A body without one still becomes an
  /// [ApiError] carrying the HTTP status.
  factory ApiError.fromResponse(int? status, Object? body) {
    if (body is Map) {
      final Object? error = body['error'];
      if (error is Map) {
        final Object? details = error['details'];
        return ApiError(
          code: error['code']?.toString() ?? 'unknown_error',
          message: error['message']?.toString() ?? '',
          details: details is Map ? Map<String, dynamic>.from(details) : null,
          status: status,
        );
      }
    }
    return ApiError(code: 'unknown_error', message: '', status: status);
  }

  final String code;
  final String message;
  final Map<String, dynamic>? details;
  final int? status;

  ApiErrorKind get kind {
    switch (code) {
      case 'unauthenticated':
        return ApiErrorKind.unauthenticated;
      case 'bad_credentials':
        return ApiErrorKind.badCredentials;
      case 'access_denied':
        return ApiErrorKind.accessDenied;
      case 'no_reviewed_facts':
        return ApiErrorKind.noReviewedFacts;
      case 'outdated':
        return ApiErrorKind.outdated;
      case 'unresolved_flags':
        return ApiErrorKind.unresolvedFlags;
      case 'placeholders_remaining':
        return ApiErrorKind.placeholdersRemaining;
      case 'ai_disabled':
        return ApiErrorKind.aiDisabled;
      case 'daily_limit':
        return ApiErrorKind.dailyLimit;
      case 'ai_unavailable':
        return ApiErrorKind.aiUnavailable;
      case 'ai_invalid_output':
        return ApiErrorKind.aiInvalidOutput;
      case 'evidence_retrieval_failed':
        return ApiErrorKind.evidenceRetrievalFailed;
      case 'query_not_safe':
        return ApiErrorKind.querySafety;
      case 'too_large':
        return ApiErrorKind.tooLarge;
      case 'mime_not_allowed':
        return ApiErrorKind.mimeNotAllowed;
      case 'empty_file':
        return ApiErrorKind.emptyFile;
      case 'image_unreadable':
        return ApiErrorKind.imageUnreadable;
      case 'not_approved':
        return ApiErrorKind.notApproved;
      case 'not_confirmable':
        return ApiErrorKind.notConfirmable;
      case 'team_required':
        return ApiErrorKind.teamRequired;
      case 'topic_required':
        return ApiErrorKind.topicRequired;
      case 'no_problems':
      case 'problem_not_selected':
        return ApiErrorKind.needsProblem;
      case 'permission_denied':
      case 'permission_permanently_denied':
        return ApiErrorKind.permissionDenied;
      case 'chat_disabled':
        return ApiErrorKind.chatDisabled;
      case 'rate_limited':
        return ApiErrorKind.rateLimited;
      case 'duplicate_message':
        return ApiErrorKind.duplicateMessage;
      case 'too_long':
        return ApiErrorKind.messageTooLong;
      case 'empty_thread':
        return ApiErrorKind.emptyThread;
      case 'archived':
        return ApiErrorKind.channelArchived;
      case 'network_error':
        return ApiErrorKind.network;
      case 'timeout':
        return ApiErrorKind.timeout;
      case 'cancelled':
        return ApiErrorKind.cancelled;
      case 'text_required':
      case 'no_plan':
        return ApiErrorKind.other;
    }
    // The status still tells us the basics when the code is unknown.
    if (status == 401) return ApiErrorKind.unauthenticated;
    if (status == 403) return ApiErrorKind.accessDenied;
    if (status == 413) return ApiErrorKind.tooLarge;
    if (status == 415) return ApiErrorKind.mimeNotAllowed;
    if (status == 429) return ApiErrorKind.rateLimited;
    return ApiErrorKind.other;
  }

  /// A 401 on a request that carried a token ends the session.
  bool get isUnauthenticated => kind == ApiErrorKind.unauthenticated;

  /// Generation failures where Retry makes sense.
  bool get isRetryable {
    if (kind == ApiErrorKind.aiUnavailable ||
        kind == ApiErrorKind.aiInvalidOutput ||
        kind == ApiErrorKind.evidenceRetrievalFailed ||
        kind == ApiErrorKind.network ||
        kind == ApiErrorKind.timeout) {
      return true;
    }
    // Transient server failures during note/summary generation.
    if (status != null && status! >= 500) return true;
    return code == 'internal' || code == 'unknown_error';
  }

  /// Section keys named by `unresolved_flags` / `placeholders_remaining`.
  List<String> get sections {
    final Object? raw = details?['sections'];
    if (raw is List) return raw.map((Object? e) => e.toString()).toList();
    return const <String>[];
  }

  /// Plain text for the user. No server text is included.
  String get userMessage {
    switch (kind) {
      case ApiErrorKind.unauthenticated:
        return 'Your session has ended. Sign in again.';
      case ApiErrorKind.badCredentials:
        return 'Email or password is incorrect.';
      case ApiErrorKind.accessDenied:
        return 'You do not have access to this patient.';
      case ApiErrorKind.noReviewedFacts:
        return 'Review chart facts first.';
      case ApiErrorKind.outdated:
        return 'Chart changed. Regenerate before marking reviewed.';
      case ApiErrorKind.unresolvedFlags:
        return 'Some sections still have unresolved flags.';
      case ApiErrorKind.placeholdersRemaining:
        return 'Some sections still have information that is not entered.';
      case ApiErrorKind.aiDisabled:
        return 'AI is temporarily off. Manual entry still works.';
      case ApiErrorKind.dailyLimit:
        return 'Daily AI limit reached.';
      case ApiErrorKind.aiUnavailable:
        return 'AI service busy, try again.';
      case ApiErrorKind.aiInvalidOutput:
        return 'Generation failed. Your data is unchanged.';
      case ApiErrorKind.evidenceRetrievalFailed:
        return 'Evidence search failed.';
      case ApiErrorKind.querySafety:
        return 'Topic looks like it contains patient identifiers. '
            'Use a generic clinical topic.';
      case ApiErrorKind.tooLarge:
        return 'Photo is too large.';
      case ApiErrorKind.mimeNotAllowed:
        return 'That photo format is not supported. Try JPEG or PNG.';
      case ApiErrorKind.emptyFile:
        return 'That file is empty.';
      case ApiErrorKind.imageUnreadable:
        return 'Could not read the photo, try better lighting.';
      case ApiErrorKind.notApproved:
        return 'This question was reported and is under review.';
      case ApiErrorKind.notConfirmable:
        return 'This census scan was already confirmed or discarded.';
      case ApiErrorKind.teamRequired:
        return 'Join a team before scanning a census.';
      case ApiErrorKind.topicRequired:
        return 'Pick a clinical topic first.';
      case ApiErrorKind.needsProblem:
        return 'Confirm or mark a differential problem before requesting '
            'ICD suggestions.';
      case ApiErrorKind.permissionDenied:
        return code == 'permission_permanently_denied'
            ? 'Permission is off. Open Settings to allow it.'
            : 'Permission is needed to continue.';
      case ApiErrorKind.chatDisabled:
        return 'Chat is turned off by your administrator.';
      case ApiErrorKind.rateLimited:
        return 'Too many messages. Slow down and try again.';
      case ApiErrorKind.duplicateMessage:
        return 'That message was already sent. Wait a moment before retrying.';
      case ApiErrorKind.messageTooLong:
        return 'That message is too long.';
      case ApiErrorKind.emptyThread:
        return 'No messages to summarize in this channel.';
      case ApiErrorKind.channelArchived:
        return 'This channel is archived.';
      case ApiErrorKind.network:
        return 'No connection. Check your network and try again.';
      case ApiErrorKind.timeout:
        return 'The request took too long. Try again.';
      case ApiErrorKind.cancelled:
        return 'Cancelled.';
      case ApiErrorKind.other:
        if (code == 'text_required') {
          return 'Enter the plan text first, then save.';
        }
        if (code == 'transcript_required') {
          return 'Enter or dictate an update before writing the note.';
        }
        if (code == 'no_plan') {
          return 'Save today\'s plan before proposing tasks.';
        }
        if (code == 'internal' || code == 'unknown_error') {
          return 'Note generation failed. Your dictation and edits were kept — tap Retry.';
        }
        if (code == 'ai_invalid_output') {
          return 'The draft could not be validated from that update. Your text was kept — edit and Retry.';
        }
        if (status != null && status! >= 500) {
          return 'Note generation failed. Your dictation and edits were kept — tap Retry.';
        }
        return 'Note generation failed. Your entered text was kept — tap Retry.';
    }
  }

  /// Safe to log: no message text, no details.
  @override
  String toString() => 'ApiError($status, $code)';
}
