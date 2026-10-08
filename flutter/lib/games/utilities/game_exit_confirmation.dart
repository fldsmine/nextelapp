import 'package:flutter/material.dart';

Future<bool> confirmGameExit(BuildContext context) async =>
    await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text(
          'Exit Game',
          style: TextStyle(color: Color(0xFF17241F)),
        ),
        content: const Text(
          'Are you sure you want to exit the current game?',
          style: TextStyle(color: Color(0xFF303030)),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            icon: const Icon(Icons.close, color: Colors.red),
            label: const Text('Cancel', style: TextStyle(color: Colors.red)),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            icon: const Icon(Icons.check),
            label: const Text('Proceed'),
          ),
        ],
      ),
    ) ??
    false;
