import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:round_ai/core/di/injection_container.dart';
import 'package:round_ai/core/errors/failures.dart';
import 'package:round_ai/core/errors/result.dart';
import 'package:round_ai/core/network/api_error.dart';
import 'package:round_ai/core/router/app_routes.dart';
import 'package:round_ai/core/theme/app_colors.dart';
import 'package:round_ai/core/theme/app_typography.dart';
import 'package:round_ai/features/chat/cache/chat_people_directory.dart';
import 'package:round_ai/features/chat/models/chat_channel.dart';
import 'package:round_ai/features/chat/models/chat_nav_extra.dart';
import 'package:round_ai/features/chat/models/chat_person.dart';
import 'package:round_ai/features/chat/repository/chat_repository.dart';
import 'package:round_ai/features/team_selection/models/clinical_team.dart';
import 'package:round_ai/shared/widgets/ai_error_box.dart';
import 'package:round_ai/shared/widgets/app_button.dart';

enum ChatNewKind { dm, group }

/// Create a DM or group from the in-memory teammates directory.
/// Leave/archive are not supported by the backend.
class ChatNewConversationScreen extends StatefulWidget {
  const ChatNewConversationScreen({
    required this.kind,
    this.chatRepository,
    this.people,
    this.teamId,
    this.excludeUserId,
    super.key,
  });

  final ChatNewKind kind;
  final ChatRepository? chatRepository;
  final ChatPeopleDirectory? people;
  final String? teamId;
  final String? excludeUserId;

  @override
  State<ChatNewConversationScreen> createState() =>
      _ChatNewConversationScreenState();
}

class _ChatNewConversationScreenState extends State<ChatNewConversationScreen> {
  final TextEditingController _name = TextEditingController();
  final Set<String> _selected = <String>{};
  String? _dmUserId;
  bool _busy = false;
  Object? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final InjectionContainer di = InjectionContainer.instance;
    final ChatRepository chat = widget.chatRepository ?? di.chatRepository;
    final List<ClinicalTeam> teams =
        di.profileRepository.current?.teams ?? const <ClinicalTeam>[];
    final String? teamId =
        widget.teamId ?? (teams.isEmpty ? null : teams.first.id);

    setState(() {
      _busy = true;
      _error = null;
    });

    final Result<ChatChannel> result;
    if (widget.kind == ChatNewKind.dm) {
      final String? userId = _dmUserId;
      if (userId == null) {
        setState(() {
          _busy = false;
          _error = 'Pick a teammate.';
        });
        return;
      }
      result = await chat.createChannel(
        type: 'dm',
        teamId: teamId,
        userId: userId,
      );
    } else {
      final String name = _name.text.trim();
      if (name.isEmpty) {
        setState(() {
          _busy = false;
          _error = 'Enter a group name.';
        });
        return;
      }
      result = await chat.createChannel(
        type: 'group',
        teamId: teamId,
        name: name,
        memberIds: _selected.toList(),
      );
    }

    if (!mounted) return;
    setState(() => _busy = false);
    if (result case Err<ChatChannel>(:final failure)) {
      setState(() => _error = failure.apiError);
      return;
    }
    final ChatChannel channel = (result as Ok<ChatChannel>).value;
    context.pushReplacement(
      AppRoutes.chatChannelPath(channel.id),
      extra: ChatChannelExtra(channel: channel),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    final InjectionContainer di = InjectionContainer.instance;
    final ChatPeopleDirectory people = widget.people ?? di.chatPeople;
    final String? exclude =
        widget.excludeUserId ?? di.profileRepository.current?.user.id;
    final List<ChatPerson> roster = people.all
        .where((ChatPerson p) => p.id != exclude)
        .toList();

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        title: Text(
          widget.kind == ChatNewKind.dm ? 'New direct message' : 'New group',
          style: AppTypography.semiBold(
            fontSize: 17,
            color: colors.textPrimary,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: <Widget>[
          Text(
            'Teammates come from people seen in chat. There is no separate '
            'directory API yet. Leave and archive are not available.',
            style: AppTypography.regular(
              fontSize: 13,
              color: colors.textMuted,
            ),
          ),
          const SizedBox(height: 16),
          if (widget.kind == ChatNewKind.group) ...<Widget>[
            TextField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'Group name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (roster.isEmpty)
            Text(
              'No teammates yet. They appear after someone posts in a shared '
              'channel (or in demo mode).',
              style: AppTypography.regular(
                fontSize: 14,
                color: colors.textMuted,
              ),
            )
          else
            for (final ChatPerson person in roster)
              widget.kind == ChatNewKind.dm
                  ? ListTile(
                      title: Text(person.displayName),
                      trailing: Icon(
                        _dmUserId == person.id
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                      ),
                      onTap: _busy
                          ? null
                          : () => setState(() => _dmUserId = person.id),
                    )
                  : CheckboxListTile(
                      value: _selected.contains(person.id),
                      title: Text(person.displayName),
                      onChanged: _busy
                          ? null
                          : (bool? on) {
                              setState(() {
                                if (on == true) {
                                  _selected.add(person.id);
                                } else {
                                  _selected.remove(person.id);
                                }
                              });
                            },
                    ),
          if (_error != null) ...<Widget>[
            const SizedBox(height: 12),
            if (_error is ApiError)
              AiErrorBox(error: _error! as ApiError)
            else
              Text(
                '$_error',
                style: AppTypography.regular(
                  fontSize: 13,
                  color: colors.error,
                ),
              ),
          ],
          const SizedBox(height: 20),
          AppButton(
            label: widget.kind == ChatNewKind.dm ? 'Open chat' : 'Create group',
            onPressed: _busy ? null : _submit,
          ),
        ],
      ),
    );
  }
}
