import '../models/file_entry.dart';

enum SortOption { nameAsc, nameDesc, dateNewest, dateOldest, sizeDesc, typeFirst }

const sortPrefKey = 'sort_option';

List<FileEntry> applySortToEntries(List<FileEntry> entries, SortOption sort) {
  final copy = List<FileEntry>.from(entries);
  switch (sort) {
    case SortOption.nameAsc:
      copy.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    case SortOption.nameDesc:
      copy.sort((a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
    case SortOption.dateNewest:
      copy.sort((a, b) => b.lastModified.compareTo(a.lastModified));
    case SortOption.dateOldest:
      copy.sort((a, b) => a.lastModified.compareTo(b.lastModified));
    case SortOption.sizeDesc:
      copy.sort((a, b) => b.sizeBytes.compareTo(a.sizeBytes));
    case SortOption.typeFirst:
      copy.sort((a, b) {
        if (a.type == b.type) {
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        }
        if (a.type == FileType.folder) return -1;
        if (b.type == FileType.folder) return 1;
        return a.type.index.compareTo(b.type.index);
      });
  }
  return copy;
}

SortOption sortFromString(String? s) => switch (s) {
  'nameDesc' => SortOption.nameDesc,
  'dateNewest' => SortOption.dateNewest,
  'dateOldest' => SortOption.dateOldest,
  'sizeDesc' => SortOption.sizeDesc,
  'typeFirst' => SortOption.typeFirst,
  _ => SortOption.nameAsc,
};

String sortLabel(SortOption s) => switch (s) {
  SortOption.nameAsc => 'Name A→Z',
  SortOption.nameDesc => 'Name Z→A',
  SortOption.dateNewest => 'Newest first',
  SortOption.dateOldest => 'Oldest first',
  SortOption.sizeDesc => 'Largest first',
  SortOption.typeFirst => 'Type',
};
