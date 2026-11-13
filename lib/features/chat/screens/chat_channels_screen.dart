import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:round_ai/core/di/injection_container.dart';
import 'package:round_ai/core/network/api_error.dart';
import 'package:round_ai/core/router/app_routes.dart';
import 'package:round_ai/core/theme/app_colors.dart';
import 'package:round_ai/core/theme/app_typography.dart';
import 'package:round_ai/features/authentication/repository/profile_repository.dart';
import 'package:round_ai/features/chat/bloc/chat_channels_cubit.dart';
import 'package:round_ai/features/chat/cache/chat_people_directory.dart';
import 'package:round_ai/features/chat/chat_unread_badge.dart';
import 'package:round_ai/features/chat/models/chat_channel.dart';
import 'package:round_ai/features/chat/models/chat_nav_extra.dart';
import 'package:round_ai/features/chat/repository/chat_repository.dart';
import 'package:round_ai/features/chat/services/chat_push_controller.dart';
import 'package:round_ai/features/chat/services/chat_realtime_controller.dart';
import 'package:round_ai/features/chat/widgets/chat_push_opt_in_banner.dart';
import 'package:round_ai/shared/widgets/chat_disabled_banner.dart';
import 'package:round_ai/shared/widgets/retry_view.dart';
import 'package:round_ai/shared/widgets/skeleton.dart';

/// Team chat inbox: Team / Patients / Groups / DMs with unread counts.
class ChatChannelsScreen extends StatelessWidget {
  const ChatChannelsScreen({
    this.chatRepository,
    this.unreadBadge,
    this.realtime,
    this.people,
    this.chatOff,
    this.push,
    super.key,
  });

  final ChatRepository? chatRepository;
  final ChatUnreadBadge? unreadBadge;
  final ChatRealtimeController? realtime;
  final ChatPeopleDirectory? people;
  final bool? chatOff;
  final ChatPushController? push;

  @override
  Widget build(BuildContext context) {
    final InjectionContainer di = InjectionContainer.instance;
    final bool useDi = chatRepository == null;
    final bool off =
        chatOff ?? (useDi ? di.profileRepository.chatOff : false);
    final ChatPushController? pushCtrl =
        push ?? (useDi ? di.chatPush : null);
    pushCtrl?.refreshOptInVisibility(chatEnabled: !off);
    return BlocProvider<ChatChannelsCubit>(
      create: (_) => ChatChannelsCubit(
        chatRepository ?? di.chatRepository,
        unreadBadge ?? di.chatUnreadBadge,
        // Tests that inject a repo skip DI (container may be uninit).
        realtime: realtime ?? (useDi ? di.chatRealtime : null),
        people: people ?? (useDi ? di.chatPeople : null),
        currentUserId: useDi ? di.profileRepository.current?.user.id : null,
      )..load(),
      child: _InboxView(chatOff: off, push: pushCtrl),
    );
  }
}

class _InboxView extends StatelessWidget {
  const _InboxView({required this.chatOff, this.push});

  final bool chatOff;
  final ChatPushController? push;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    return BlocBuilder<ChatChannelsCubit, ChatChannelsState>(
      builder: (BuildContext context, ChatChannelsState state) {
        final ChatChannelsCubit cubit = context.read<ChatChannelsCubit>();
        final bool disabled = chatOff || state.chatDisabled;
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (bool didPop, Object? result) {
            if (!didPop) context.go(AppRoutes.today);
          },
          child: Scaffold(
          backgroundColor: colors.background,
          floatingActionButton: disabled
              ? null
              : FloatingActionButton(
                  tooltip: 'New conversation',
                  onPressed: () => _openNewMenu(context),
                  child: const Icon(Icons.edit_square),
                ),
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (disabled) const ChatDisabledBanner(),
                if (!disabled && push != null)
                  ChatPushOptInBanner(controller: push),
                Expanded(
                  child: disabled
                      ? const SizedBox.shrink()
                      : state.loading
                      ? const SkeletonList(count: 4)
                      : state.error != null && state.sections.isEmpty
                      ? RetryView(
                          title: 'Chat could not be loaded.',
                          message: state.error!.userMessage,
                          onRetry: cubit.load,
                        )
                      : RefreshIndicator(
                          onRefresh: cubit.load,
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                            children: <Widget>[
                              Text(
                                'COMMAND CENTER',
                                style: AppTypography.semiBold(
                                  fontSize: 11,
                                  color: colors.textMuted,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: <Widget>[
                                  IconButton(
                                    tooltip: 'Back to Home',
                                    onPressed: () =>
                                        context.go(AppRoutes.today),
                                    icon: Icon(
                                      Icons.arrow_back_rounded,
                                      color: colors.textPrimary,
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      'Chat',
                                      style: AppTypography.bold(
                                        fontSize: 28,
                                        color: colors.textPrimary,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Search',
                                    onPressed: () =>
                                        context.push(AppRoutes.chatSearch),
                                    icon: const Icon(Icons.search),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Messages stay on your team. Do not paste '
                                'names, MRNs or dates of birth into chat.',
                                style: AppTypography.regular(
                                  fontSize: 13,
                                  color: colors.textMuted,
                                ),
                              ),
                              if (state.error != null) ...<Widget>[
                                const SizedBox(height: 12),
                                Text(
                                  state.error!.kind == ApiErrorKind.network
                                      ? state.error!.userMessage
                                      : 'Some channels may be out of date. '
                                            'Pull to refresh.',
                                  style: AppTypography.regular(
                                    fontSize: 12.5,
                                    color: colors.warning,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 20),
                              if (state.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 40),
                                  child: Text(
                                    'No channels yet.',
                                    textAlign: TextAlign.center,
                                    style: AppTypography.regular(
                                      fontSize: 14,
                                      color: colors.textMuted,
                                    ),
                                  ),
                                )
                              else
                                for (final ChatChannelSection section
                                    in state.sections) ...<Widget>[
                                  Text(
                                    section.title.toUpperCase(),
                                    style: AppTypography.semiBold(
                                      fontSize: 11,
                                      color: colors.textMuted,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  for (final ChatChannel channel
                                      in section.channels)
                                    _ChannelTile(channel: channel),
                                  const SizedBox(height: 20),
                                ],
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
        );
      },
    );
  }
}

Future<void> _openNewMenu(BuildContext context) async {
  final String? choice = await showModalBottomSheet<String>(
    context: context,
    builder: (BuildContext context) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Direct message'),
              onTap: () => Navigator.pop(context, 'dm'),
            ),
            ListTile(
              leading: const Icon(Icons.group_outlined),
              title: const Text('Group'),
              onTap: () => Navigator.pop(context, 'group'),
            ),
          ],
        ),
      );
    },
  );
  if (!context.mounted || choice == null) return;
  context.push(
    choice == 'dm' ? AppRoutes.chatNewDm : AppRoutes.chatNewGroup,
  );
}

class _ChannelTile extends StatelessWidget {
  const _ChannelTile({required this.channel});

  final ChatChannel channel;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    final String title = channel.name.isEmpty ? 'Channel' : channel.name;
    return Semantics(
      button: true,
      label: channel.unread > 0
          ? '$title, ${channel.unread} unread'
          : title,
      child: InkWell(
        onTap: () => context.push(
          AppRoutes.chatChannelPath(channel.id),
          extra: ChatChannelExtra(channel: channel),
        ),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: <Widget>[
              CircleAvatar(
                radius: 20,
                backgroundColor: colors.primary.withValues(alpha: 0.12),
                child: Text(
                  _initials(title),
                  style: AppTypography.semiBold(
                    fontSize: 13,
                    color: colors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.semiBold(
                    fontSize: 15,
                    color: colors.textPrimary,
                  ),
                ),
              ),
              if (channel.unread > 0)
                Container(
                  constraints: const BoxConstraints(minWidth: 22),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: colors.error,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    channel.unread > 9 ? '9+' : '${channel.unread}',
                    style: TextStyle(
                      color: colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static String _initials(String name) {
    final String trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    final List<String> parts = trimmed
        .split(RegExp(r'\s+'))
        .where((String p) => p.isNotEmpty)
        .toList();
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return trimmed[0].toUpperCase();
  }
}
