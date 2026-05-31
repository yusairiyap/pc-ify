class UserCredential {
  final String username;
  final String passwordHash;

  const UserCredential({required this.username, required this.passwordHash});

  factory UserCredential.fromJson(Map<String, dynamic> json) =>
      UserCredential(
        username: json['username'] as String,
        passwordHash: json['passwordHash'] as String,
      );

  Map<String, dynamic> toJson() => {
        'username': username,
        'passwordHash': passwordHash,
      };

  UserCredential copyWith({String? username, String? passwordHash}) =>
      UserCredential(
        username: username ?? this.username,
        passwordHash: passwordHash ?? this.passwordHash,
      );
}
