import 'package:flutter/material.dart';

import '../models/family_member.dart';
import '../utils/icon_helper.dart';

class FamilyMemberSelector extends StatelessWidget {
  const FamilyMemberSelector({
    super.key,
    required this.members,
    required this.selectedMemberId,
    required this.onChanged,
    this.enableSplitSelection = false,
    this.splitSelections = const [],
    this.onSplitChanged,
    this.label = 'Who filled fuel?',
    this.helperText,
  });
  final List<FamilyMember> members;
  final int? selectedMemberId;
  final ValueChanged<int?> onChanged;
  final bool enableSplitSelection;
  final List<int> splitSelections;
  final ValueChanged<List<int>>? onSplitChanged;
  final String label;
  final String? helperText;

  @override
  Widget build(BuildContext context) {
    if (members.isEmpty) {
      return Text(
        'Add family members in Settings to assign expenses',
        style: Theme.of(context).textTheme.bodySmall,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<int?>(
          initialValue: selectedMemberId,
          decoration: InputDecoration(
            labelText: label,
            helperText: helperText,
            prefixIcon: const Icon(Icons.people_alt_outlined),
          ),
          isExpanded: true,
          items: [
            const DropdownMenuItem<int?>(
              child: Text('Unassigned'),
            ),
            ...members.map(
              (member) => DropdownMenuItem<int?>(
                value: member.id,
                child: _MemberTile(member: member),
              ),
            ),
          ],
          onChanged: onChanged,
        ),
        if (enableSplitSelection && onSplitChanged != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.call_split, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      'Split expense',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: members
                      .where((member) => member.id != null)
                      .map((member) {
                    final memberId = member.id!;
                    return FilterChip(
                      avatar: CircleAvatar(
                        backgroundColor: Color(member.colorHex),
                        foregroundColor: Colors.white,
                        child: Icon(
                          IconHelper.fromString(member.avatarIcon),
                          size: 16,
                        ),
                      ),
                      label: Text(member.name),
                      selected: splitSelections.contains(memberId),
                      onSelected: enableSplitSelection
                          ? (selected) {
                              final updated = [...splitSelections];
                              if (selected) {
                                if (!updated.contains(memberId)) {
                                  updated.add(memberId);
                                }
                              } else {
                                updated.remove(memberId);
                              }
                              onSplitChanged?.call(updated);
                            }
                          : null,
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({required this.member});
  final FamilyMember member;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          backgroundColor: Color(member.colorHex),
          foregroundColor: Colors.white,
          child: Icon(IconHelper.fromString(member.avatarIcon)),
        ),
        const SizedBox(width: 12),
        Text(member.name),
      ],
    );
  }
}
