import 'package:flutter/material.dart';

class AlfredFab extends StatelessWidget {
  final VoidCallback onTap;
  const AlfredFab({Key? key, required this.onTap}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Um FAB mais largo e com ícone "A" estilizado
    return FloatingActionButton.extended(
      heroTag: 'alfred_fab',
      onPressed: onTap,
      backgroundColor: Theme.of(context).colorScheme.primary,
      label: Row(children: const [
        Icon(Icons.room_service, size: 18),
        SizedBox(width: 8),
        Text('Alfred'),
      ]),
    );
  }
}