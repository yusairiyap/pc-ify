import 'dart:convert';

enum WidgetType { battery, volume, cpu, ram, screenLock, notifications }

class DashboardItem {
  const DashboardItem({required this.id, required this.type});
  final String id;
  final WidgetType type;

  factory DashboardItem.fromJson(Map<String, dynamic> json) => DashboardItem(
        id: json['id'] as String,
        type: WidgetType.values.firstWhere(
          (e) => e.name == (json['type'] as String),
          orElse: () => WidgetType.battery,
        ),
      );

  Map<String, dynamic> toJson() => {'id': id, 'type': type.name};
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

  factory DashboardSection.fromJson(Map<String, dynamic> json) => DashboardSection(
        id: json['id'] as String,
        name: json['name'] as String,
        isBookmarks: (json['isBookmarks'] as bool?) ?? false,
        items: (json['items'] as List<dynamic>? ?? [])
            .map((e) => DashboardItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'isBookmarks': isBookmarks,
        'items': items.map((e) => e.toJson()).toList(),
      };

  DashboardSection copyWith({String? name, List<DashboardItem>? items}) => DashboardSection(
        id: id,
        name: name ?? this.name,
        isBookmarks: isBookmarks,
        items: items ?? this.items,
      );
}

class DashboardLayout {
  const DashboardLayout({required this.sections});
  final List<DashboardSection> sections;

  factory DashboardLayout.defaultLayout() => const DashboardLayout(sections: [
        DashboardSection(
          id: 'system',
          name: 'System',
          items: [
            DashboardItem(id: 'battery', type: WidgetType.battery),
            DashboardItem(id: 'volume', type: WidgetType.volume),
            DashboardItem(id: 'cpu', type: WidgetType.cpu),
            DashboardItem(id: 'ram', type: WidgetType.ram),
            DashboardItem(id: 'screenLock', type: WidgetType.screenLock),
          ],
        ),
        DashboardSection(
          id: 'notifications',
          name: 'Notifications',
          items: [
            DashboardItem(id: 'notifications', type: WidgetType.notifications),
          ],
        ),
        DashboardSection(
          id: 'bookmarks',
          name: 'My Bookmarks',
          isBookmarks: true,
        ),
      ]);

  factory DashboardLayout.fromJson(Map<String, dynamic> json) => DashboardLayout(
        sections: (json['sections'] as List<dynamic>)
            .map((e) => DashboardSection.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'sections': sections.map((e) => e.toJson()).toList(),
      };

  DashboardLayout copyWith({List<DashboardSection>? sections}) =>
      DashboardLayout(sections: sections ?? this.sections);
}
