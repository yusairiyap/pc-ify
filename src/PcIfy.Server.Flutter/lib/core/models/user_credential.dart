class UserCredential {
  final String username;
  final String passwordHash;
  // Empty = unrestricted (access all source directories).
  final List<String> allowedDirectories;

  const UserCredential({
    required this.username,
    required this.passwordHash,
    this.allowedDirectories = const [],
  });

  factory UserCredential.fromJson(Map<String, dynamic> json) => UserCredential(
        username: json['username'] as String,
        passwordHash: json['passwordHash'] as String,
        allowedDirectories:
            (json['allowedDirectories'] as List<dynamic>? ?? []).cast<String>(),
      );

  Map<String, dynamic> toJson() => {
        'username': username,
        'passwordHash': passwordHash,
        'allowedDirectories': allowedDirectories,
      };

  UserCredential copyWith({
    String? username,
    String? passwordHash,
    List<String>? allowedDirectories,
  }) =>
      UserCredential(
        username: username ?? this.username,
        passwordHash: passwordHash ?? this.passwordHash,
        allowedDirectories: allowedDirectories ?? this.allowedDirectories,
      );
}
