import 'package:flutter/material.dart';
import '../../core/models/dashboard_models.dart';

Future<WidgetType?> showAddWidgetSheet(
  BuildContext context, {
  required List<WidgetType> alreadyAdded,
}) {
  return showModalBottomSheet<WidgetType>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _AddWidgetSheet(alreadyAdded: alreadyAdded),
  );
}

class _AddWidgetSheet extends StatelessWidget {
  const _AddWidgetSheet({required this.alreadyAdded});
  final List<WidgetType> alreadyAdded;

  @override
  Widget build(BuildContext context) {
    final available =
        WidgetType.values.where((t) => !alreadyAdded.contains(t)).toList();
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('Add widget',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
          const Divider(height: 1),
          if (available.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'All widgets are already on your dashboard.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            )
          else
            ...available.map((type) => ListTile(
                  leading: Icon(_icon(type),
                      color: Theme.of(context).colorScheme.primary),
                  title: Text(_name(type)),
                  subtitle:
                      Text(_desc(type), style: const TextStyle(fontSize: 12)),
                  onTap: () => Navigator.pop(context, type),
                )),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  IconData _icon(WidgetType t) => switch (t) {
        WidgetType.battery => Icons.battery_full_outlined,
        WidgetType.volume => Icons.volume_up_outlined,
        WidgetType.cpu => Icons.memory_outlined,
        WidgetType.ram => Icons.storage_outlined,
        WidgetType.screenLock => Icons.lock_outline,
        WidgetType.serverInfo => Icons.dns_outlined,
      };

  String _name(WidgetType t) => switch (t) {
        WidgetType.battery => 'Battery',
        WidgetType.volume => 'Volume',
        WidgetType.cpu => 'CPU Usage',
        WidgetType.ram => 'RAM Usage',
        WidgetType.screenLock => 'Screen Lock',
        WidgetType.serverInfo => 'Server Info',
      };

  String _desc(WidgetType t) => switch (t) {
        WidgetType.battery => 'Current charge level and charging state',
        WidgetType.volume => 'Volume control and mute toggle',
        WidgetType.cpu => 'Processor utilization',
        WidgetType.ram => 'Memory utilization',
        WidgetType.screenLock => 'Lock or wake the remote screen',
        WidgetType.serverInfo => 'Platform, server name and connection status',
      };
}
