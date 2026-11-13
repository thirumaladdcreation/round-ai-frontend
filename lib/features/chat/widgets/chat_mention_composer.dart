import 'package:flutter/material.dart';
import 'package:round_ai/core/theme/app_colors.dart';
import 'package:round_ai/core/theme/app_typography.dart';
import 'package:round_ai/features/chat/cache/chat_people_directory.dart';
import 'package:round_ai/features/chat/models/chat_message.dart';
import 'package:round_ai/features/chat/models/chat_person.dart';
import 'package:round_ai/features/chat/utils/chat_mention_utils.dart';

/// Composer with optional @ teammate picker. Inserts `@FirstName ` for the
/// server mention parser.
class ChatMentionComposer extends StatefulWidget {
  const ChatMentionComposer({
    required this.controller,
    required this.focusNode,
    required this.enabled,
    required this.onSend,
    required this.people,
    this.excludeUserId,
    this.showPatientReminder = false,
    this.hintText = 'Message',
    super.key,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;
  final VoidCallback onSend;
  final ChatPeopleDirectory people;
  final String? excludeUserId;
  final bool showPatientReminder;
  final String hintText;

  @override
  State<ChatMentionComposer> createState() => _ChatMentionComposerState();
}

class _ChatMentionComposerState extends State<ChatMentionComposer> {
  List<ChatPerson> _suggestions = const <ChatPerson>[];
  int? _mentionStart;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onText);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onText);
    super.dispose();
  }

  void _onText() {
    final int cursor = widget.controller.selection.baseOffset;
    final ({int start, String query})? active = mentionQueryAt(
      widget.controller.text,
      cursor < 0 ? widget.controller.text.length : cursor,
    );
    setState(() {
      if (active == null) {
        _suggestions = const <ChatPerson>[];
        _mentionStart = null;
      } else {
        _mentionStart = active.start;
        _suggestions = widget.people.matchingMention(
          active.query,
          excludeUserId: widget.excludeUserId,
        );
      }
    });
  }

  void _insertMention(ChatPerson person) {
    final int start = _mentionStart ?? 0;
    final TextSelection sel = widget.controller.selection;
    final int cursor = sel.baseOffset < 0
        ? widget.controller.text.length
        : sel.baseOffset;
    final String text = widget.controller.text;
    final String insert = '@${person.mentionToken} ';
    final String next =
        text.substring(0, start) + insert + text.substring(cursor);
    widget.controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: start + insert.length),
    );
    setState(() {
      _suggestions = const <ChatPerson>[];
      _mentionStart = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    return Material(
      color: colors.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (widget.showPatientReminder)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Semantics(
                    label:
                        'Share only what the team needs. Do not paste names, '
                        'MRNs or dates of birth.',
                    child: Text(
                      'Share only what the team needs. Do not paste names, '
                      'MRNs or dates of birth.',
                      style: AppTypography.regular(
                        fontSize: 11.5,
                        color: colors.textMuted,
                      ),
                    ),
                  ),
                ),
              if (_suggestions.isNotEmpty)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 140),
                  child: Material(
                    color: colors.background,
                    borderRadius: BorderRadius.circular(10),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _suggestions.length,
                      itemBuilder: (BuildContext context, int i) {
                        final ChatPerson p = _suggestions[i];
                        return Semantics(
                          button: true,
                          label: 'Mention ${p.displayName}',
                          child: ListTile(
                            dense: true,
                            title: Text(p.displayName),
                            subtitle: Text('@${p.mentionToken}'),
                            onTap: () => _insertMention(p),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              if (_suggestions.isNotEmpty) const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Expanded(
                    child: Semantics(
                      label: 'Message',
                      textField: true,
                      child: TextField(
                        controller: widget.controller,
                        focusNode: widget.focusNode,
                        enabled: widget.enabled,
                        minLines: 1,
                        maxLines: 5,
                        maxLength: kChatMaxBodyLength,
                        buildCounter:
                            (
                              BuildContext context, {
                              required int currentLength,
                              required bool isFocused,
                              required int? maxLength,
                            }) {
                              if (maxLength == null ||
                                  currentLength < maxLength - 200) {
                                return const SizedBox.shrink();
                              }
                              return Text(
                                '$currentLength / $maxLength',
                                style: AppTypography.regular(
                                  fontSize: 11,
                                  color: colors.textMuted,
                                ),
                              );
                            },
                        decoration: InputDecoration(
                          hintText: widget.hintText,
                          filled: true,
                          fillColor: colors.background,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: colors.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: colors.border),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) {
                          if (widget.enabled) widget.onSend();
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Semantics(
                    button: true,
                    label: 'Send message',
                    child: IconButton.filled(
                      tooltip: 'Send',
                      onPressed: widget.enabled ? widget.onSend : null,
                      icon: const Icon(Icons.send_rounded),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
