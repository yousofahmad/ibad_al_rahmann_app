import 'package:flutter/material.dart';

class ClearAllDialog extends StatelessWidget {
  final VoidCallback onConfirm;

  const ClearAllDialog({
    super.key,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Clear All Bookmarks'),
      content: const Text(
          'Are you sure you want to remove all bookmarked verses? This action cannot be undone.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            onConfirm();
            Navigator.pop(context);
          },
          child: const Text('Clear All', style: TextStyle(color: Colors.red)),
        ),
      ],
    );
  }
}
