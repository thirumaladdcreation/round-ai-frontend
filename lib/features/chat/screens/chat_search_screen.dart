import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:round_ai/core/di/injection_container.dart';
import 'package:round_ai/core/router/app_routes.dart';
import 'package:round_ai/core/theme/app_colors.dart';
import 'package:round_ai/core/theme/app_typography.dart';
import 'package:round_ai/features/chat/bloc/chat_search_cubit.dart';
import 'package:round_ai/features/chat/models/chat_message.dart';
import 'package:round_ai/features/chat/models/chat_nav_extra.dart';
import 'package:round_ai/features/chat/repository/chat_repository.dart';
import 'package:round_ai/features/chat/utils/chat_mention_utils.dart';
import 'package:round_ai/shared/widgets/ai_error_box.dart';

/// Search across the user's channels. Queries are never logged.
class ChatSearchScreen extends StatelessWidget {
  const ChatSearchScreen({this.chatRepository, super.key});

  final ChatRepository? chatRepository;

  @override
  Widget build(BuildContext context) {
    final InjectionContainer di = InjectionContainer.instance;
    return BlocProvider<ChatSearchCubit>(
      create: (_) => ChatSearchCubit(chatRepository ?? di.chatRepository),
      child: const _SearchView(),
    );
  }
}

class _SearchView extends StatefulWidget {
  const _SearchView();

  @override
  State<_SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<_SearchView> {
  final TextEditingController _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        title: Text(
          'Search chat',
          style: AppTypography.semiBold(
            fontSize: 17,
            color: colors.textPrimary,
          ),
        ),
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Semantics(
              label: 'Search messages',
              textField: true,
              child: TextField(
                controller: _query,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search messages',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: colors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                // Queries are never logged (ChatSearchCubit / AppLog).
                onChanged: context.read<ChatSearchCubit>().onQueryChanged,
              ),
            ),
          ),
          Expanded(
            child: BlocBuilder<ChatSearchCubit, ChatSearchState>(
              builder: (BuildContext context, ChatSearchState state) {
                if (state.error != null) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: AiErrorBox(error: state.error!),
                  );
                }
                if (state.loading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (state.query.length < 2) {
                  return Center(
                    child: Text(
                      'Type at least 2 characters.',
                      style: AppTypography.regular(
                        fontSize: 14,
                        color: colors.textMuted,
                      ),
                    ),
                  );
                }
                if (state.results.isEmpty) {
                  return Center(
                    child: Text(
                      'No matches.',
                      style: AppTypography.regular(
                        fontSize: 14,
                        color: colors.textMuted,
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: state.results.length,
                  separatorBuilder: (_, _) => Divider(color: colors.border),
                  itemBuilder: (BuildContext context, int i) {
                    final ChatMessage m = state.results[i];
                    final String snippet = m.deleted
                        ? 'Message deleted'
                        : (m.body.length > 120
                              ? '${m.body.substring(0, 120)}…'
                              : m.body);
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        state.titleFor(m.channelId),
                        style: AppTypography.semiBold(
                          fontSize: 13,
                          color: colors.textMuted,
                        ),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text.rich(
                          buildMentionSpans(snippet, colors: colors),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      onTap: () {
                        context.push(
                          AppRoutes.chatChannelPath(m.channelId),
                          extra: ChatChannelExtra(
                            highlightMessageId: m.id,
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
