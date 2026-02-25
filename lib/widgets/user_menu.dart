import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/user_model.dart';
import '../screens/settings_screen.dart';

class UserMenu extends StatelessWidget {
  final User? currentUser;
  final VoidCallback onSettingsReturn;

  const UserMenu({
    super.key,
    required this.currentUser,
    required this.onSettingsReturn,
  });

  @override
  Widget build(BuildContext context) {
    if (currentUser == null) return const SizedBox.shrink();

    return PopupMenuButton<String>(
      onSelected: (value) {
        if (value == 'copy_id') {
          Clipboard.setData(ClipboardData(text: currentUser!.id.toString()));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User ID copied to clipboard!')),
          );
        } else if (value == 'settings') {
          Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const SettingsScreen()))
              .then((_) => onSettingsReturn());
        }
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          enabled: false,
          child: Text(
            currentUser!.name,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'copy_id',
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('ID: ${currentUser!.id.toString()}'),
              const Icon(Icons.copy, size: 18),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'settings',
          child: const ListTile(
            leading: Icon(Icons.settings),
            title: Text('Settings'),
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
        ),
      ],
      icon: const Icon(Icons.account_circle),
    );
  }
}
