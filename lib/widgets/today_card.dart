import 'package:flutter/material.dart';

class TodayCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Map<String, dynamic>> items; // each: { 'title': String, 'done': bool }
  final VoidCallback onViewAll;
  final Function(int index) onToggleDone;

  const TodayCard({
    Key? key,
    required this.title,
    required this.subtitle,
    required this.items,
    required this.onViewAll,
    required this.onToggleDone,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: theme.textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(subtitle, style: theme.textTheme.bodySmall),
              ]),
            ),
            TextButton(onPressed: onViewAll, child: const Text('Ver tudo')),
          ]),
          const SizedBox(height: 8),
          ...List.generate(items.length > 3 ? 3 : items.length, (i) {
            final it = items[i];
            return ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: GestureDetector(
                onTap: () => onToggleDone(i),
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: it['done'] == true ? Theme.of(context).colorScheme.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: it['done'] == true ? Theme.of(context).colorScheme.primary : Colors.grey),
                  ),
                  child: it['done'] == true ? const Icon(Icons.check, size: 16, color: Colors.black) : null,
                ),
              ),
              title: Text(it['title'] ?? '', style: TextStyle(decoration: it['done'] == true ? TextDecoration.lineThrough : TextDecoration.none)),
            );
          }),
          if (items.isEmpty)
            Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text('Nenhum item', style: theme.textTheme.bodySmall)),
        ]),
      ),
    );
  }
}