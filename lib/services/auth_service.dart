import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'amplifyconfiguration.dart';

enum UserRole {
  superAdmin,
  admin,
  user,
  guest,
}

extension UserRoleExtension on UserRole {
  String get displayName {
    switch (this) {
      case UserRole.superAdmin:
        return 'Super Admin';
      case UserRole.admin:
        return 'Admin';
      case UserRole.user:
        return 'User';
      case UserRole.guest:
        return 'Guest';
    }
  }

  bool hasPermission(UserRole requiredRole) {
    return index <= requiredRole.index;
  }
}

class AuthService {
  static CognitoPoolType _currentPoolType = CognitoPoolType.user;

  static bool debugSuperAdminMode = false;

  static CognitoPoolType get currentPoolType => _currentPoolType;

  static Future<void> configureAmplify(CognitoPoolType poolType) async {
    _currentPoolType = poolType;

    if (Amplify.isConfigured) {
      safePrint(
          '⚠️ Amplify already configured. Current pool: ${_currentPoolType.name}');
      return;
    }

    try {
      final config = getAmplifyConfig(poolType);
      await Amplify.addPlugin(AmplifyAuthCognito());
      await Amplify.configure(config);
      safePrint('✅ Amplify configured with ${poolType.name} pool');
    } on AmplifyAlreadyConfiguredException {
      safePrint('Amplify was already configured');
    } catch (e) {
      safePrint('Error configuring Amplify: $e');
      rethrow;
    }
  }

  static Future<bool> switchPool(CognitoPoolType newPoolType) async {
    if (_currentPoolType == newPoolType) {
      safePrint('Already using ${newPoolType.name} pool');
      return true;
    }

    safePrint(
        '⚠️ Pool switching requires app restart. Target pool: ${newPoolType.name}');
    return false;
  }

  static CognitoPoolType getPoolTypeForAuth({required bool isAdmin}) {
    return isAdmin ? CognitoPoolType.admin : CognitoPoolType.user;
  }

  Future<void> signUp({
    required String email,
    required String password,
    bool isAdmin = false,
  }) async {
    final expectedPool = isAdmin ? CognitoPoolType.admin : CognitoPoolType.user;
    if (_currentPoolType != expectedPool) {
      throw InvalidStateException(
        'Wrong pool configured! Expected ${expectedPool.name} but using ${_currentPoolType.name}. '
        'Please restart the app and select the correct account type.',
      );
    }

    try {
      final userAttributes = {
        AuthUserAttributeKey.email: email,
      };
      final result = await Amplify.Auth.signUp(
        username: email,
        password: password,
        options: SignUpOptions(
          userAttributes: userAttributes,
        ),
      );
      safePrint(
          'Sign up result: ${result.isSignUpComplete} (pool: ${_currentPoolType.name}, account_type: ${isAdmin ? 'admin' : 'user'})');
    } on AuthException catch (e) {
      safePrint('Error signing up: ${e.message}');
      rethrow;
    }
  }

  Future<void> confirmSignUp({
    required String email,
    required String confirmationCode,
  }) async {
    try {
      final result = await Amplify.Auth.confirmSignUp(
        username: email,
        confirmationCode: confirmationCode,
      );
      safePrint('Confirm sign up result: ${result.isSignUpComplete}');
    } on AuthException catch (e) {
      safePrint('Error confirming sign up: ${e.message}');
      rethrow;
    }
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final result = await Amplify.Auth.signIn(
        username: email,
        password: password,
      );
      safePrint(
          'Sign in result: ${result.isSignedIn} (pool: ${_currentPoolType.name})');
    } on AuthException catch (e) {
      safePrint('Error signing in: ${e.message}');
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      await Amplify.Auth.signOut();
      safePrint('Signed out from ${_currentPoolType.name} pool');
    } on AuthException catch (e) {
      safePrint('Error signing out: ${e.message}');
      rethrow;
    }
  }

  Future<AuthUser?> getCurrentUser() async {
    try {
      final user = await Amplify.Auth.getCurrentUser();
      return user;
    } on AuthException catch (e) {
      safePrint('Error getting current user: ${e.message}');
      return null;
    }
  }

  Future<bool> isUserSignedIn() async {
    try {
      final result = await Amplify.Auth.fetchAuthSession();
      return result.isSignedIn;
    } on AuthException catch (e) {
      safePrint('Error checking auth session: ${e.message}');
      return false;
    }
  }

  Future<List<String>> _getUserGroups() async {
    try {
      final session = await Amplify.Auth.fetchAuthSession();
      if (session is CognitoAuthSession) {
        final idToken = session.userPoolTokensResult.value.idToken;
        return idToken.groups.toList();
      }
      return [];
    } catch (e) {
      safePrint('Error fetching user groups: $e');
      return [];
    }
  }

  Future<UserRole> getUserRole() async {
    if (debugSuperAdminMode) {
      return UserRole.superAdmin;
    }

    final isSignedIn = await isUserSignedIn();
    if (!isSignedIn) {
      return UserRole.guest;
    }

    if (_currentPoolType == CognitoPoolType.admin) {
      final groups = await _getUserGroups();
      if (groups.contains('SuperAdmins')) {
        return UserRole.superAdmin;
      }
      return UserRole.admin;
    } else {
      return UserRole.user;
    }
  }

  Future<bool> isSuperAdmin() async {
    final role = await getUserRole();
    return role == UserRole.superAdmin;
  }

  Future<bool> isAdmin() async {
    final role = await getUserRole();
    return role.hasPermission(UserRole.admin);
  }

  Future<bool> hasRole(UserRole requiredRole) async {
    final role = await getUserRole();
    return role.hasPermission(requiredRole);
  }

  Future<bool> canAccessAdminPanel() async {
    return await isAdmin();
  }

  Future<bool> canManageAdmins() async {
    return await isSuperAdmin();
  }

  Future<bool> canDeleteGrids() async {
    return await isSuperAdmin();
  }

  Future<bool> canEditGrids() async {
    return await isAdmin();
  }

  Future<bool> canViewStatistics() async {
    return await isAdmin();
  }

  Future<void> resetPassword({required String email}) async {
    try {
      await Amplify.Auth.resetPassword(username: email);
      safePrint('Password reset code sent to: $email');
    } on AuthException catch (e) {
      safePrint('Error requesting password reset: ${e.message}');
      rethrow;
    }
  }

  Future<void> confirmResetPassword({
    required String email,
    required String newPassword,
    required String confirmationCode,
  }) async {
    try {
      await Amplify.Auth.confirmResetPassword(
        username: email,
        newPassword: newPassword,
        confirmationCode: confirmationCode,
      );
      safePrint('Password reset successful for: $email');
    } on AuthException catch (e) {
      safePrint('Error confirming password reset: ${e.message}');
      rethrow;
    }
  }
}
