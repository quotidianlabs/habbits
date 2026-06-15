import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/reorder.dart';
import '../../l10n/app_localizations.dart';
import '../settings/settings_screen.dart';
import '../widgets/habit_dialogs.dart';
import 'habit_list_view_model.dart';
import 'widgets/habit_card.dart';

class HabitListScreen extends ConsumerWidget {
  const HabitListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaries = ref.watch(habitListViewModelProvider);
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Habbits'),
        actions: [
          IconButton(
            key: const Key('open-settings'),
            icon: const Icon(Icons.settings),
            tooltip: l10n.settings,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        key: const Key('add-habit-fab'),
        onPressed: () async {
          final name = await showHabitNameDialog(context);
          if (name != null) {
            await ref.read(habitListViewModelProvider.notifier).createHabit(name);
          }
        },
        child: const Icon(Icons.add),
      ),
      body: summaries.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l10n.homeError(e.toString()))),
        data: (items) {
          if (items.isEmpty) {
            return Center(child: Text(l10n.noHabits));
          }
          return ReorderableListView(
            buildDefaultDragHandles: false,
            padding: const EdgeInsets.symmetric(vertical: 6),
            onReorderItem: (oldIndex, newIndex) {
              final ids = [for (final it in items) it.habit.id];
              ref.read(habitListViewModelProvider.notifier).reorder(reorderedIds(ids, oldIndex, newIndex));
            },
            children: [
              for (var i = 0; i < items.length; i++)
                HabitCard(
                  key: ValueKey('habit-${items[i].habit.id}'),
                  item: items[i],
                  index: i,
                ),
            ],
          );
        },
      ),
    );
  }
}
