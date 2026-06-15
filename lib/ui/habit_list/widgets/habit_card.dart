import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/dates.dart';
import '../../../domain/models/habit_summary.dart';
import '../../../l10n/app_localizations.dart';
import '../../habit_detail/habit_detail_screen.dart';
import '../../widgets/day_strip.dart';
import '../habit_list_view_model.dart';

class HabitCard extends ConsumerWidget {
  const HabitCard({super.key, required this.item, required this.index});
  final HabitSummary item;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final today = dateOnly(DateTime.now());
    final percent = item.completionPercent;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => HabitDetailScreen(habitId: item.habit.id),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Checkbox(
                    key: ValueKey('checkoff-toggle-${item.habit.id}'),
                    value: item.doneToday,
                    onChanged: (_) => ref
                        .read(habitListViewModelProvider.notifier)
                        .toggleToday(item.habit.id),
                  ),
                  Expanded(
                    child: Text(
                      item.habit.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Text(l10n.streakLabel(item.streak)),
                  const SizedBox(width: 12),
                  Text(percent == null ? '—' : '$percent%'),
                  ReorderableDragStartListener(
                    index: index,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Icon(
                        Icons.drag_handle,
                        key: ValueKey('drag-handle-${item.habit.id}'),
                        semanticLabel: l10n.dragToReorder(item.habit.name),
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              DayStrip(
                completed: item.dates,
                today: today,
                color: Color(item.habit.color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
