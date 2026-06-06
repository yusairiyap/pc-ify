enum WidgetType { battery, volume, cpu, ram, screenLock, serverInfo }

enum WidgetSize { halfWidth, fullWidth }

class DashboardItem {
  const DashboardItem({required this.id, required this.type, this.size});
  final String id;
  final WidgetType type;
  final WidgetSize? size;

  WidgetSize get effectiveSize =>
      size ?? _defaultSizeFor(type);

  static WidgetSize _defaultSizeFor(WidgetType t) =>
      (t == WidgetType.screenLock || t == WidgetType.serverInfo)
          ? WidgetSize.fullWidth
          : WidgetSize.halfWidth;

  DashboardItem copyWith({WidgetSize? size}) =>
      DashboardItem(id: id, type: type, size: size ?? this.size);

  static DashboardItem? tryFromJson(Map<String, dynamic> json) {
    final typeName = json['type'] as String? ?? '';
    final type = WidgetType.values.where((e) => e.name == typeName).firstOrNull;
    if (type == null) return null;
    final sizeStr = json['size'] as String?;
    return DashboardItem(
      id: json['id'] as String,
      type: type,
      size: sizeStr == null
          ? null
          : WidgetSize.values.firstWhere(
              (e) => e.name == sizeStr,
              orElse: () => WidgetSize.fullWidth,
            ),
    );
  }

  factory DashboardItem.fromJson(Map<String, dynamic> json) =>
      tryFromJson(json) ?? DashboardItem(id: json['id'] as String? ?? '', type: WidgetType.battery);

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        if (size != null) 'size': size!.name,
      };
}

class DashboardSection {
  const DashboardSection({
    required this.id,
    required this.name,
    this.isBookmarks = false,
    this.items = const [],
  });
  final String id;
  final String name;
  final bool isBookmarks;
  final List<DashboardItem> items;

  factory DashboardSection.fromJson(Map<String, dynamic> json) =>
      DashboardSection(
        id: json['id'] as String,
        name: json['name'] as String,
        isBookmarks: (json['isBookmarks'] as bool?) ?? false,
        items: (json['items'] as List<dynamic>? ?? [])
            .map((e) => DashboardItem.tryFromJson(e as Map<String, dynamic>))
            .whereType<DashboardItem>()
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'isBookmarks': isBookmarks,
        'items': items.map((e) => e.toJson()).toList(),
      };

  DashboardSection copyWith({String? name, List<DashboardItem>? items}) =>
      DashboardSection(
        id: id,
        name: name ?? this.name,
        isBookmarks: isBookmarks,
        items: items ?? this.items,
      );
}

class DashboardLayout {
  const DashboardLayout({required this.sections});
  final List<DashboardSection> sections;

  factory DashboardLayout.defaultLayout() =>
      const DashboardLayout(sections: [
        DashboardSection(
          id: 'system',
          name: 'Server Overview',
          items: [
            DashboardItem(id: 'server_info', type: WidgetType.serverInfo),
            DashboardItem(id: 'battery', type: WidgetType.battery),
            DashboardItem(id: 'volume', type: WidgetType.volume),
            DashboardItem(id: 'cpu', type: WidgetType.cpu),
            DashboardItem(id: 'ram', type: WidgetType.ram),
            DashboardItem(id: 'screenLock', type: WidgetType.screenLock),
          ],
        ),
        DashboardSection(
          id: 'bookmarks',
          name: 'My Bookmarks',
          isBookmarks: true,
        ),
      ]);

  factory DashboardLayout.fromJson(Map<String, dynamic> json) =>
      DashboardLayout(
        sections: (json['sections'] as List<dynamic>)
            .map((e) =>
                DashboardSection.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'sections': sections.map((e) => e.toJson()).toList(),
      };

  DashboardLayout copyWith({List<DashboardSection>? sections}) =>
      DashboardLayout(sections: sections ?? this.sections);
}
