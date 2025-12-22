import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'amplifyconfiguration.dart';

/// User roles in order of privilege (highest to lowest)
enum UserRole {
  superAdmin, // Full system access
  admin, // Parking lot management
  user, // Regular user
  guest, // Not signed in
}

/// Extension to add helper methods to UserRole
extension UserRoleExtension on UserRole {
  /// Display name for the role
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

  /// Check if this role has at least the given permission level
  bool hasPermission(UserRole requiredRole) {
    return index <= requiredRole.index;
  }
}

class AuthService {
  /// Track the currently active pool type
  static CognitoPoolType _currentPoolType = CognitoPoolType.user;

  /// Debug flag to bypass authentication and force superAdmin role
  static bool debugSuperAdminMode = false;

  /// Get the current pool type
  static CognitoPoolType get currentPoolType => _currentPoolType;

  // Pool Management Methods

  /// Initialize Amplify with the specified pool type
  /// Call this before any auth operations when switching pools
  static Future<void> configureAmplify(CognitoPoolType poolType) async {
    _currentPoolType = poolType;

    if (Amplify.isConfigured) {
      // If already configured, we need to sign out first and reconfigure
      // Note: In production, you may want to handle this differently
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

  /// Switch to a different user pool
  /// IMPORTANT: This requires signing out the current user first
  /// and reconfiguring Amplify (which is complex with the current SDK)
  ///
  /// For production use, consider one of these approaches:
  /// 1. Use separate app entries/flavors for admin and user apps
  /// 2. Use AWS SDK directly without Amplify for more control
  /// 3. Configure pool at app startup based on login type selection
  static Future<bool> switchPool(CognitoPoolType newPoolType) async {
    if (_currentPoolType == newPoolType) {
      safePrint('Already using ${newPoolType.name} pool');
      return true;
    }

    safePrint(
        '⚠️ Pool switching requires app restart. Target pool: ${newPoolType.name}');
    // Due to Amplify SDK limitations, you cannot reconfigure after initial setup
    // The recommended approach is to set the pool type before configuring Amplify
    return false;
  }

  /// Get which pool should be used based on user selection
  /// Call this BEFORE configuring Amplify in main.dart
  static CognitoPoolType getPoolTypeForAuth({required bool isAdmin}) {
    return isAdmin ? CognitoPoolType.admin : CognitoPoolType.user;
  }

  // Authentication Methods

  Future<void> signUp({
    required String email,
    required String password,
    bool isAdmin = false,
  }) async {
    // Verify we're using the correct pool
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

  /// Confirm Sign Up with verification code
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

  /// Sign In an existing user
  ///
  /// IMPORTANT: Make sure the correct pool is configured before calling this!
  /// Users registered in the admin pool must sign in with admin pool configured,
  /// and users registered in user pool must sign in with user pool configured.
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

  /// Sign Out the current user
  Future<void> signOut() async {
    try {
      await Amplify.Auth.signOut();
      safePrint('Signed out from ${_currentPoolType.name} pool');
    } on AuthException catch (e) {
      safePrint('Error signing out: ${e.message}');
      rethrow;
    }
  }

  /// Get the currently signed in user
  Future<AuthUser?> getCurrentUser() async {
    try {
      final user = await Amplify.Auth.getCurrentUser();
      return user;
    } on AuthException catch (e) {
      safePrint('Error getting current user: ${e.message}');
      return null;
    }
  }

  /// Check if any user is signed in
  Future<bool> isUserSignedIn() async {
    try {
      final result = await Amplify.Auth.fetchAuthSession();
      return result.isSignedIn;
    } on AuthException catch (e) {
      safePrint('Error checking auth session: ${e.message}');
      return false;
    }
  }

  // Role & Permission Methods

  /// Get the user's Cognito groups
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

  /// Get the current user's role based on pool type and groups
  Future<UserRole> getUserRole() async {
    // Check for debug override first
    if (debugSuperAdminMode) {
      return UserRole.superAdmin;
    }

    // Check if user is signed in
    final isSignedIn = await isUserSignedIn();
    if (!isSignedIn) {
      return UserRole.guest;
    }

    // Determine role based on current pool type
    if (_currentPoolType == CognitoPoolType.admin) {
      // Admin pool users - check for super admin group
      final groups = await _getUserGroups();
      if (groups.contains('SuperAdmins')) {
        return UserRole.superAdmin;
      }
      return UserRole.admin;
    } else {
      // User pool - regular users
      return UserRole.user;
    }
  }

  /// Check if user is a Super Admin
  Future<bool> isSuperAdmin() async {
    final role = await getUserRole();
    return role == UserRole.superAdmin;
  }

  /// Check if user is an Admin (or higher)
  Future<bool> isAdmin() async {
    final role = await getUserRole();
    return role.hasPermission(UserRole.admin);
  }

  /// Check if user has at least a specific role
  Future<bool> hasRole(UserRole requiredRole) async {
    final role = await getUserRole();
    return role.hasPermission(requiredRole);
  }

  // Permission Helpers

  /// Check if user can access the admin panel
  Future<bool> canAccessAdminPanel() async {
    return await isAdmin();
  }

  /// Check if user can manage other admins (SuperAdmin only)
  Future<bool> canManageAdmins() async {
    return await isSuperAdmin();
  }

  /// Check if user can delete parking grids (SuperAdmin only)
  Future<bool> canDeleteGrids() async {
    return await isSuperAdmin();
  }

  /// Check if user can edit parking grids (Admin or higher)
  Future<bool> canEditGrids() async {
    return await isAdmin();
  }

  /// Check if user can view statistics (Admin or higher)
  Future<bool> canViewStatistics() async {
    return await isAdmin();
  }

  // Password Reset Methods

  /// Request password reset code - sends email with confirmation code
  Future<void> resetPassword({required String email}) async {
    try {
      await Amplify.Auth.resetPassword(username: email);
      safePrint('Password reset code sent to: $email');
    } on AuthException catch (e) {
      safePrint('Error requesting password reset: ${e.message}');
      rethrow;
    }
  }

  /// Confirm password reset with new password and code from email
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
