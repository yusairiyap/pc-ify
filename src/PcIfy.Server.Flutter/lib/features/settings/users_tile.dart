import 'package:flutter/material.dart';
import '../../core/models/app_settings.dart';
import '../../core/models/user_credential.dart';
import '../../services/auth_service.dart';
import '../dialogs/add_user_dialog.dart';

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
                    trailing: IconButton(
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
                  )),
          ],
        ),
      ),
    );
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
}
