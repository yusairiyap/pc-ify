import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/connection_log_entry.dart';
import '../../providers/log_providers.dart';

class LogTableWidget extends ConsumerStatefulWidget {
  const LogTableWidget({super.key});

  @override
  ConsumerState<LogTableWidget> createState() => _LogTableWidgetState();
}

class _LogTableWidgetState extends ConsumerState<LogTableWidget> {
  static const _maxRows = 500;
  final List<ConnectionLogEntry> _entries = [];
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Seed with existing entries.
    final existing = ref.read(connectionLogServiceProvider).getRecent(_maxRows);
    _entries.addAll(existing.reversed);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(logEntriesProvider, (_, next) {
      next.whenData((entry) {
        setState(() {
          _entries.insert(0, entry);
          if (_entries.length > _maxRows) _entries.removeLast();
        });
      });
    });

    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Text('Connection Log',
                  style: Theme.of(context).textTheme.titleSmall),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () {
                ref.read(connectionLogServiceProvider).clear();
                setState(() => _entries.clear());
              },
              icon: const Icon(Icons.delete_outline, size: 16),
              label: const Text('Clear'),
            ),
          ],
        ),
        Expanded(
          child: _entries.isEmpty
              ? const Center(child: Text('No connections yet'))
              : SingleChildScrollView(
                  controller: _scrollController,
                  scrollDirection: Axis.vertical,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowHeight: 36,
                      dataRowMinHeight: 30,
                      dataRowMaxHeight: 30,
                      columnSpacing: 16,
                      columns: const [
                        DataColumn(label: Text('Time')),
                        DataColumn(label: Text('IP')),
                        DataColumn(label: Text('User')),
                        DataColumn(label: Text('Method')),
                        DataColumn(label: Text('Path')),
                        DataColumn(label: Text('Status')),
                      ],
                      rows: _entries.map((e) {
                        final isError = e.statusCode >= 400;
                        final textStyle = isError
                            ? TextStyle(
                                color: colorScheme.error, fontSize: 12)
                            : const TextStyle(fontSize: 12);
                        return DataRow(cells: [
                          DataCell(Text(
                            _formatTime(e.timestamp),
                            style: textStyle,
                          )),
                          DataCell(Text(e.clientIp, style: textStyle)),
                          DataCell(Text(e.username, style: textStyle)),
                          DataCell(Text(e.method, style: textStyle)),
                          DataCell(Text(
                            e.path,
                            style: textStyle,
                            overflow: TextOverflow.ellipsis,
                          )),
                          DataCell(Text(
                            '${e.statusCode}',
                            style: textStyle,
                          )),
                        ]);
                      }).toList(),
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  String _formatTime(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';
}
