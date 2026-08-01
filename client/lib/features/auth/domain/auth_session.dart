class AuthSession {
  final String username;
  final String email;
  final String userId;
  final String accessToken;
  final double userCredits;
  final double totalCredits;

  const AuthSession({
    required this.username,
    required this.email,
    required this.userId,
    required this.accessToken,
    required this.userCredits,
    required this.totalCredits,
  });
}
