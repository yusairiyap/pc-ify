import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../../core/models/app_settings.dart';
import '../../core/models/user_credential.dart';
import '../../services/auth_service.dart';
import '../dialogs/add_user_dialog.dart';
import '../dialogs/user_directories_dialog.dart';

class UsersTile extends StatelessWidget {
  final AppSettings settings;
  final ValueChanged<AppSettings> onChanged;

  const UsersTile({
    super.key,
    required this.settings,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Users',
                    style: Theme.of(context).textTheme.titleSmall),
                const Spacer(),
                FilledButton.tonalIcon(
                  onPressed: () => _addUser(context),
                  icon: const Icon(Icons.person_add, size: 16),
                  label: const Text('Add User'),
                ),
              ],
            ),
            if (settings.users.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('No users configured.',
                    style: TextStyle(color: Colors.grey)),
              )
            else
              ...settings.users.map((u) => ListTile(
                    dense: true,
                    leading: const Icon(Icons.person_outline),
                    title: Text(u.username),
                    subtitle: Text(_accessLabel(u)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.folder_open, size: 18),
                          tooltip: 'Directory access',
                          onPressed: () => _editUserDirs(context, u),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18),
                          tooltip: 'Remove',
                          onPressed: () {
                            final updated =
                                List<UserCredential>.from(settings.users)
                                  ..removeWhere(
                                      (x) => x.username == u.username);
                            onChanged(settings.copyWith(users: updated));
                          },
                        ),
                      ],
                    ),
                  )),
          ],
        ),
      ),
    );
  }

  String _accessLabel(UserCredential u) {
    if (u.allowedDirectories.isEmpty) return 'All directories';
    final count = u.allowedDirectories.length;
    final names = u.allowedDirectories.map(p.basename).join(', ');
    return '$count director${count == 1 ? "y" : "ies"}: $names';
  }

  Future<void> _addUser(BuildContext context) async {
    final result = await showDialog<({String username, String password})>(
      context: context,
      builder: (_) => const AddUserDialog(),
    );
    if (result == null) return;
    final hash = AuthService.hashPassword(result.password);
    final newUser =
        UserCredential(username: result.username, passwordHash: hash);
    final updated = List<UserCredential>.from(settings.users)..add(newUser);
    onChanged(settings.copyWith(users: updated));
  }

  Future<void> _editUserDirs(BuildContext context, UserCredential user) async {
    if (settings.sourceDirectories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add source directories first.')),
      );
      return;
    }
    final result = await showDialog<List<String>>(
      context: context,
      builder: (_) => UserDirectoriesDialog(
        user: user,
        allDirectories: settings.sourceDirectories,
      ),
    );
    if (result == null) return;
    final updated = settings.users
        .map((u) => u.username == user.username
            ? u.copyWith(allowedDirectories: result)
            : u)
        .toList();
    onChanged(settings.copyWith(users: updated));
  }
}
