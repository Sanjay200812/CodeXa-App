import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../api/api_client.dart';
import '../models/models.dart';
import '../services/cx_notification_service.dart';
import '../storage/secure_storage.dart';

// --- AUTH STATE & NOTIFIER ---
class AuthState {
  final bool isAuthenticated;
  final bool isLoading;
  final bool mustChangePassword;
  final UserModel? user;
  final String? errorMessage;
  final List<SavedAccount> savedAccounts;
  final String? activeAccountId;
  final bool requiresFounderOtp;
  final String? challengeToken;
  final String? maskedFounderEmail;
  final Map<String, dynamic>? candidateUser;
  final String? lastAuthStage;

  AuthState({
    this.isAuthenticated = false,
    this.isLoading = false,
    this.mustChangePassword = false,
    this.user,
    this.errorMessage,
    this.savedAccounts = const [],
    this.activeAccountId,
    this.requiresFounderOtp = false,
    this.challengeToken,
    this.maskedFounderEmail,
    this.candidateUser,
    this.lastAuthStage,
  });

  AuthState copyWith({
    bool? isAuthenticated,
    bool? isLoading,
    bool? mustChangePassword,
    UserModel? user,
    String? errorMessage,
    List<SavedAccount>? savedAccounts,
    String? activeAccountId,
    bool? requiresFounderOtp,
    String? challengeToken,
    String? maskedFounderEmail,
    Map<String, dynamic>? candidateUser,
    String? lastAuthStage,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isLoading: isLoading ?? this.isLoading,
      mustChangePassword: mustChangePassword ?? this.mustChangePassword,
      user: user ?? this.user,
      errorMessage: errorMessage,
      savedAccounts: savedAccounts ?? this.savedAccounts,
      activeAccountId: activeAccountId ?? this.activeAccountId,
      requiresFounderOtp: requiresFounderOtp ?? this.requiresFounderOtp,
      challengeToken: challengeToken ?? this.challengeToken,
      maskedFounderEmail: maskedFounderEmail ?? this.maskedFounderEmail,
      candidateUser: candidateUser ?? this.candidateUser,
      lastAuthStage: lastAuthStage ?? this.lastAuthStage,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final CxApiClient api = CxApiClient();
  bool _googleInitialized = false;

  AuthNotifier() : super(AuthState(isLoading: true)) {
    checkInitialSession();
  }

  void _logStage(String stage, {String? details, int? status, String? code}) {
    if (kDebugMode) {
      final statusStr = status != null ? ' HTTP: $status' : '';
      final codeStr = code != null ? ' [$code]' : '';
      final detStr = details != null ? ' - $details' : '';
      debugPrint('[$stage]$statusStr$codeStr$detStr');
    }
  }

  Future<void> _ensureGoogleInitialized() async {
    if (_googleInitialized) return;
    try {
      await GoogleSignIn.instance.initialize(
        serverClientId: '268559658188-bu0mls9rd74n26tgsv6ajo3khg1hcnrq.apps.googleusercontent.com',
      );
      _googleInitialized = true;
    } catch (e) {
      debugPrint('Google Sign-In initialization notice: $e');
    }
  }

  Future<void> checkInitialSession() async {
    try {
      final accounts = await CxStorage.getSavedAccounts();
      final active = await CxStorage.getActiveAccount();

      if (active == null || active.accessToken.isEmpty) {
        state = AuthState(
          isAuthenticated: false,
          isLoading: false,
          savedAccounts: accounts,
        );
        return;
      }

      // Restore active user from saved account for instantaneous launch
      final user = UserModel(
        id: active.id,
        username: active.username,
        email: active.email,
        fullName: active.fullName,
        role: active.role,
        orgRole: active.orgRole,
        department: active.department,
        profileMediaUrl: active.profileMediaUrl,
      );

      state = AuthState(
        isAuthenticated: true,
        isLoading: false,
        user: user,
        savedAccounts: accounts,
        activeAccountId: active.id,
      );

      // Verify and refresh token in background via Core API
      _verifySessionInBackground(active);

      // Synchronize FCM push token for restored session
      CxNotificationService.syncFcmTokenWithBackend();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AuthNotifier] checkInitialSession notice: $e');
      }
      state = AuthState(isAuthenticated: false, isLoading: false);
    }
  }

  Future<void> _verifySessionInBackground(SavedAccount active) async {
    try {
      // Refresh token or bootstrap validate session
      final res = await api.dio.post(
        '/api/mobile/auth/refresh',
        data: {'refreshToken': active.accessToken},
      );

      if (res.data != null && res.data['ok'] == true) {
        final verifiedUser = UserModel.fromJson(res.data['user'] ?? {});
        final newToken = res.data['accessToken'] ?? active.accessToken;
        final updatedAccount = SavedAccount.fromUserAndToken(
          verifiedUser,
          newToken,
        );
        await CxStorage.saveAccount(updatedAccount, makeActive: true);
        if (mounted) {
          state = state.copyWith(
            user: verifiedUser,
            savedAccounts: await CxStorage.getSavedAccounts(),
          );
        }
      }
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (kDebugMode) {
        debugPrint('[AUTH] Background session verify status: $status');
      }
      // ONLY invalidate stored account on authoritative 401 session revocation/expiry
      // Never wipe stored account on transient 500, 503 database unavailability, or network timeouts!
      if (status == 401) {
        if (kDebugMode) {
          debugPrint(
            '[AUTH] Session revoked or expired by server (401). Clearing stored account.',
          );
        }
        await removeAccount(active.id);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AuthNotifier] Background session note: $e');
      }
    }
  }

  /// Normal primary login (First account on device)
  Future<bool> login(String identifier, String password) async {
    if (state.isLoading) return false; // Prevent double submit

    state = state.copyWith(isLoading: true, errorMessage: null);

    _logStage('AUTH_STAGE_2 = backend reachability check');
    _logStage(
      'AUTH_STAGE_3 = login request sent',
      details: 'identifier provided',
    );

    try {
      final deviceId = await CxStorage.getOrCreateDeviceId();
      final fcmToken = await CxStorage.getFcmToken();
      Response res;
      try {
        res = await api.dio.post(
          '/api/mobile/auth/login',
          data: {
            'identifier': identifier.trim(),
            'password': password,
            'deviceId': deviceId,
            'deviceName': 'Android Mobile',
            'platform': 'ANDROID',
            if (fcmToken != null && fcmToken.isNotEmpty) 'fcmToken': fcmToken,
          },
        );
      } on DioException catch (dioErr) {
        if (dioErr.response == null &&
            (dioErr.type == DioExceptionType.connectionError ||
                dioErr.type == DioExceptionType.connectionTimeout ||
                dioErr.type == DioExceptionType.unknown)) {
          // Automatic 1-time retry for transient cellular network drops
          await Future.delayed(const Duration(milliseconds: 1200));
          res = await api.dio.post(
            '/api/mobile/auth/login',
            data: {
              'identifier': identifier.trim(),
              'password': password,
              'deviceId': deviceId,
              'deviceName': 'Android Mobile',
              'platform': 'ANDROID',
              if (fcmToken != null && fcmToken.isNotEmpty) 'fcmToken': fcmToken,
            },
          );
        } else {
          rethrow;
        }
      }

      _logStage('AUTH_STAGE_4 = backend responded', status: res.statusCode);

      final data = res.data;
      if (data is Map<String, dynamic> && data['ok'] == true) {
        _logStage('AUTH_STAGE_5 = database user lookup completed');
        _logStage('AUTH_STAGE_6 = credentials verified');

        if (data['mustChangePassword'] == true) {
          final tempUser = UserModel.fromJson(data['user']);
          state = state.copyWith(
            isLoading: false,
            mustChangePassword: true,
            user: tempUser,
            lastAuthStage: 'AUTH_STAGE_6',
          );
          return false;
        }

        _logStage('AUTH_STAGE_7 = session issued');
        final token = data['accessToken'];
        final user = UserModel.fromJson(data['user']);

        final savedAccount = SavedAccount.fromUserAndToken(user, token);
        await CxStorage.saveAccount(savedAccount, makeActive: true);
        await CxStorage.saveUserData(jsonEncode(user.toJson()));

        _logStage('AUTH_STAGE_8 = token stored');

        final accounts = await CxStorage.getSavedAccounts();

        state = AuthState(
          isAuthenticated: true,
          isLoading: false,
          user: user,
          savedAccounts: accounts,
          activeAccountId: user.id,
          lastAuthStage: 'AUTH_STAGE_8',
        );

        // Synchronize FCM push token with backend for authenticated user
        CxNotificationService.syncFcmTokenWithBackend();

        _logStage('AUTH_STAGE_11 = Home opened');
        return true;
      } else {
        final errCode = (data is Map && data['error'] is Map)
            ? data['error']['code']
            : 'LOGIN_FAILED';
        final errMsg = (data is Map && data['error'] is Map)
            ? data['error']['message']
            : (data is Map && data['error'] is String
                  ? data['error']
                  : 'Login failed.');
        _logStage(
          'AUTH_STAGE_4 = login failed',
          status: res.statusCode,
          code: errCode,
        );

        state = state.copyWith(
          isLoading: false,
          errorMessage: errMsg ?? 'Login failed.',
          lastAuthStage: 'AUTH_STAGE_4',
        );
        return false;
      }
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final isConnError = e.type == DioExceptionType.connectionError;
      final errCode = (e.error is CxApiException)
          ? (e.error as CxApiException).code
          : 'UNKNOWN';

      if (kDebugMode) {
        final rStr = isConnError ? 'NO' : 'YES';
        debugPrint('[AUTH] backend reachable: $rStr');
        final sStr = status?.toString() ?? 'N/A';
        debugPrint('[AUTH] login HTTP status: $sStr');
        debugPrint('[AUTH] backend error code: $errCode');
        debugPrint('[AUTH] session issued: NO');
      }

      state = state.copyWith(
        isLoading: false,
        errorMessage: CxApiClient.parseError(e),
        lastAuthStage: 'AUTH_FAILED',
      );
      return false;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AUTH] Unexpected login failure: $e');
      }
      state = state.copyWith(
        isLoading: false,
        errorMessage: CxApiClient.parseError(e),
        lastAuthStage: 'AUTH_FAILED',
      );
      return false;
    }
  }

  /// Normal Google login (First account on device)
  Future<bool> loginWithGoogle() async {
    if (state.isLoading) return false;

    state = state.copyWith(isLoading: true, errorMessage: null);

    _logStage('GOOGLE_PICKER = launching Google Sign-In');

    try {
      await _ensureGoogleInitialized();
      final account = await GoogleSignIn.instance.authenticate(
        scopeHint: const ['email', 'profile', 'openid'],
      );

      _logStage('GOOGLE_TOKEN = retrieving ID token');
      final idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        _logStage('GOOGLE_TOKEN = FAILED (empty idToken)');
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Unable to retrieve Google authentication token.',
        );
        return false;
      }

      _logStage(
        'BACKEND_GOOGLE_VERIFY = verifying Google token on CodeXa Core',
      );
      final deviceId = await CxStorage.getOrCreateDeviceId();
      final fcmToken = await CxStorage.getFcmToken();
      Response res;
      try {
        res = await api.dio.post(
          '/api/mobile/auth/google',
          data: {
            'idToken': idToken,
            'deviceId': deviceId,
            'deviceName': 'Android Device',
            'platform': 'ANDROID',
            if (fcmToken != null && fcmToken.isNotEmpty) 'fcmToken': fcmToken,
          },
        );
      } on DioException catch (dioErr) {
        if (dioErr.response == null &&
            (dioErr.type == DioExceptionType.connectionError ||
                dioErr.type == DioExceptionType.connectionTimeout ||
                dioErr.type == DioExceptionType.unknown)) {
          // Automatic 1-time retry for transient cellular network drops
          await Future.delayed(const Duration(milliseconds: 1200));
          res = await api.dio.post(
            '/api/mobile/auth/google',
            data: {
              'idToken': idToken,
              'deviceId': deviceId,
              'deviceName': 'Android Device',
              'platform': 'ANDROID',
              if (fcmToken != null && fcmToken.isNotEmpty) 'fcmToken': fcmToken,
            },
          );
        } else {
          rethrow;
        }
      }

      _logStage('CORE_DB_USER_LOOKUP = Core user resolved');
      final data = res.data;
      if (data is Map<String, dynamic> && data['ok'] == true) {
        _logStage('CODEXA_SESSION_CREATE = session issued');
        final token = data['accessToken'];
        final user = UserModel.fromJson(data['user']);

        final savedAccount = SavedAccount.fromUserAndToken(user, token);
        await CxStorage.saveAccount(savedAccount, makeActive: true);
        await CxStorage.saveUserData(jsonEncode(user.toJson()));

        final accounts = await CxStorage.getSavedAccounts();

        state = AuthState(
          isAuthenticated: true,
          isLoading: false,
          user: user,
          savedAccounts: accounts,
          activeAccountId: user.id,
          lastAuthStage: 'CODEXA_SESSION_CREATE',
        );

        // Synchronize FCM push token with backend for authenticated user
        CxNotificationService.syncFcmTokenWithBackend();

        _logStage('BOOTSTRAP = ready for workspace load');
        return true;
      } else {
        final errCode = (data is Map && data['error'] is Map)
            ? data['error']['code']
            : 'GOOGLE_AUTH_FAILED';
        final errMsg = (data is Map && data['error'] is Map)
            ? data['error']['message']
            : (data is Map && data['error'] is String
                  ? data['error']
                  : 'Google authentication failed.');
        _logStage(
          'BACKEND_GOOGLE_VERIFY = FAILED',
          status: res.statusCode,
          code: errCode,
        );

        state = state.copyWith(
          isLoading: false,
          errorMessage: errMsg ?? 'Google authentication failed.',
        );
        return false;
      }
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        state = state.copyWith(isLoading: false);
        return false;
      }
      _logStage('GOOGLE_PICKER = EXCEPTION: ${e.code.name}');
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Google Sign-In: ${e.description ?? e.code.name}',
      );
      return false;
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final isConnError = e.type == DioExceptionType.connectionError;
      final errCode = (e.error is CxApiException)
          ? (e.error as CxApiException).code
          : 'UNKNOWN';

      if (kDebugMode) {
        final grStr = isConnError ? 'NO' : 'YES';
        debugPrint('[AUTH Google] backend reachable: $grStr');
        final gsStr = status?.toString() ?? 'N/A';
        debugPrint('[AUTH Google] HTTP status: $gsStr');
        debugPrint('[AUTH Google] backend error code: $errCode');
      }

      state = state.copyWith(
        isLoading: false,
        errorMessage: CxApiClient.parseError(e),
      );
      return false;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AUTH Google] Unexpected failure: $e');
      }
      state = state.copyWith(
        isLoading: false,
        errorMessage: CxApiClient.parseError(e),
      );
      return false;
    }
  }

  /// Start Add Account Flow with credentials (Triggers Founder OTP)
  Future<bool> startAddAccount(String identifier, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final deviceId = await CxStorage.getOrCreateDeviceId();
      final res = await api.dio.post(
        '/api/mobile/accounts/add/start',
        data: {
          'identifier': identifier.trim(),
          'password': password,
          'deviceId': deviceId,
          'deviceName': 'Android Device',
          'platform': 'ANDROID',
        },
      );

      final data = res.data;
      if (data['ok'] == true && data['requiresFounderApproval'] == true) {
        state = state.copyWith(
          isLoading: false,
          requiresFounderOtp: true,
          challengeToken: data['challengeToken'],
          maskedFounderEmail:
              data['maskedTargetEmail'] ??
              data['maskedFounderEmail'] ??
              'Verified Email',
          candidateUser: data['targetUser'],
        );
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          errorMessage:
              data['error']?['message'] ??
              'Unable to initiate account addition.',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: CxApiClient.parseError(e),
      );
      return false;
    }
  }

  /// Start Add Account Flow with Google (Triggers Founder OTP)
  Future<bool> startAddAccountWithGoogle() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _ensureGoogleInitialized();
      final account = await GoogleSignIn.instance.authenticate(
        scopeHint: const ['email', 'profile', 'openid'],
      );

      final idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Unable to retrieve Google authentication token.',
        );
        return false;
      }

      final deviceId = await CxStorage.getOrCreateDeviceId();
      final res = await api.dio.post(
        '/api/mobile/accounts/add/google/start',
        data: {
          'idToken': idToken,
          'deviceId': deviceId,
          'deviceName': 'Android Device',
          'platform': 'ANDROID',
        },
      );

      final data = res.data;
      if (data['ok'] == true && data['requiresFounderApproval'] == true) {
        state = state.copyWith(
          isLoading: false,
          requiresFounderOtp: true,
          challengeToken: data['challengeToken'],
          maskedFounderEmail:
              data['maskedTargetEmail'] ??
              data['maskedFounderEmail'] ??
              'Verified Email',
          candidateUser: data['targetUser'],
        );
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          errorMessage:
              data['error']?['message'] ??
              'Unable to initiate account addition.',
        );
        return false;
      }
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        state = state.copyWith(isLoading: false);
        return false;
      }
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Google Sign-In: ${e.description ?? e.code.name}',
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: CxApiClient.parseError(e),
      );
      return false;
    }
  }

  /// Verify Founder OTP and finalize adding the account
  Future<bool> verifyAddAccountOtp(String otp) async {
    if (state.challengeToken == null) return false;
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final deviceId = await CxStorage.getOrCreateDeviceId();
      final res = await api.dio.post(
        '/api/mobile/accounts/verify-add',
        data: {
          'challengeToken': state.challengeToken,
          'otp': otp.trim(),
          'deviceId': deviceId,
          'deviceName': 'Android Device',
          'platform': 'ANDROID',
        },
      );

      final data = res.data;
      if (data['ok'] == true) {
        final token = data['accessToken'];
        final user = UserModel.fromJson(data['user']);

        final savedAccount = SavedAccount.fromUserAndToken(user, token);
        await CxStorage.saveAccount(savedAccount, makeActive: true);
        await CxStorage.saveUserData(jsonEncode(user.toJson()));

        final accounts = await CxStorage.getSavedAccounts();

        state = AuthState(
          isAuthenticated: true,
          isLoading: false,
          user: user,
          savedAccounts: accounts,
          activeAccountId: user.id,
          requiresFounderOtp: false,
          challengeToken: null,
        );
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          errorMessage: data['error']?['message'] ?? 'Verification failed.',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: CxApiClient.parseError(e),
      );
      return false;
    }
  }

  /// Resend Founder OTP
  Future<bool> resendFounderOtp() async {
    if (state.challengeToken == null) return false;
    try {
      final res = await api.dio.post(
        '/api/mobile/accounts/resend-otp',
        data: {'challengeToken': state.challengeToken},
      );
      return res.data?['ok'] == true;
    } catch (e) {
      state = state.copyWith(errorMessage: CxApiClient.parseError(e));
      return false;
    }
  }

  void cancelFounderOtp() {
    state = state.copyWith(
      requiresFounderOtp: false,
      challengeToken: null,
      errorMessage: null,
    );
  }

  /// Switch active account
  Future<void> switchAccount(String accountId) async {
    try {
      await CxStorage.switchActiveAccount(accountId);
      final active = await CxStorage.getActiveAccount();
      if (active != null) {
        final user = UserModel(
          id: active.id,
          username: active.username,
          email: active.email,
          fullName: active.fullName,
          role: active.role,
          orgRole: active.orgRole,
          department: active.department,
          profileMediaUrl: active.profileMediaUrl,
        );

        state = state.copyWith(
          user: user,
          activeAccountId: active.id,
          savedAccounts: await CxStorage.getSavedAccounts(),
        );

        _verifySessionInBackground(active);
        CxNotificationService.syncFcmTokenWithBackend();
      }
    } catch (e) {
      debugPrint('[AuthNotifier] Switch account failed: $e');
    }
  }

  /// Remove an account from this device
  Future<void> removeAccount(String accountId) async {
    try {
      await CxStorage.removeAccount(accountId);
      final accounts = await CxStorage.getSavedAccounts();
      final active = await CxStorage.getActiveAccount();

      if (accounts.isEmpty || active == null) {
        state = AuthState(isAuthenticated: false, isLoading: false);
      } else {
        final user = UserModel(
          id: active.id,
          username: active.username,
          email: active.email,
          fullName: active.fullName,
          role: active.role,
          orgRole: active.orgRole,
          department: active.department,
          profileMediaUrl: active.profileMediaUrl,
        );

        state = state.copyWith(
          user: user,
          activeAccountId: active.id,
          savedAccounts: accounts,
        );
      }
    } catch (e) {
      debugPrint('[AuthNotifier] Remove account failed: $e');
    }
  }

  Future<bool> changePassword(
    String newPassword,
    String confirmPassword,
  ) async {
    if (state.user == null) return false;
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final res = await api.dio.post(
        '/api/mobile/auth/password-change',
        data: {
          'userId': state.user!.id,
          'newPassword': newPassword,
          'confirmPassword': confirmPassword,
        },
      );

      final data = res.data;
      if (data['ok'] == true) {
        final token = data['accessToken'];
        final user = UserModel.fromJson(data['user']);

        final savedAccount = SavedAccount.fromUserAndToken(user, token);
        await CxStorage.saveAccount(savedAccount, makeActive: true);
        await CxStorage.saveUserData(jsonEncode(user.toJson()));

        state = AuthState(
          isAuthenticated: true,
          isLoading: false,
          mustChangePassword: false,
          user: user,
          savedAccounts: await CxStorage.getSavedAccounts(),
          activeAccountId: user.id,
        );
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          errorMessage:
              data['error']?['message'] ?? 'Failed to update password.',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: CxApiClient.parseError(e),
      );
      return false;
    }
  }

  Future<void> logout({bool all = false}) async {
    try {
      final deviceId = await CxStorage.getOrCreateDeviceId();
      await api.dio.delete('/api/mobile/devices?deviceId=$deviceId');
    } catch (_) {}

    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}

    if (all || state.savedAccounts.length <= 1) {
      await CxStorage.clearAll();
      state = AuthState(isAuthenticated: false, isLoading: false);
    } else {
      if (state.activeAccountId != null) {
        await removeAccount(state.activeAccountId!);
      }
    }
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});

// --- BOOTSTRAP DATA PROVIDER ---
// Independent from login failure: If bootstrap fails, login is still preserved!
final bootstrapProvider = FutureProvider.autoDispose<BootstrapModel?>((
  ref,
) async {
  final auth = ref.watch(authProvider);
  if (!auth.isAuthenticated) return null;

  if (kDebugMode) {
    debugPrint('[AUTH_STAGE_9] bootstrap called');
  }

  final api = CxApiClient();
  try {
    final res = await api.dio.get('/api/mobile/bootstrap');
    if (res.data != null && res.data['ok'] == true) {
      if (kDebugMode) {
        debugPrint('[AUTH_STAGE_10] bootstrap successful');
      }
      return BootstrapModel.fromJson(res.data);
    }
  } catch (e) {
    if (kDebugMode) {
      debugPrint('[AUTH] Bootstrap error: $e');
    }
    rethrow;
  }
  return null;
});

// --- ATTENDANCE MARKING CONTROLLER ---
class AttendanceState {
  final bool isMarking;
  final bool markedSuccess;
  final String? markedAt;
  final String? errorMessage;

  AttendanceState({
    this.isMarking = false,
    this.markedSuccess = false,
    this.markedAt,
    this.errorMessage,
  });

  AttendanceState copyWith({
    bool? isMarking,
    bool? markedSuccess,
    String? markedAt,
    String? errorMessage,
  }) {
    return AttendanceState(
      isMarking: isMarking ?? this.isMarking,
      markedSuccess: markedSuccess ?? this.markedSuccess,
      markedAt: markedAt ?? this.markedAt,
      errorMessage: errorMessage,
    );
  }
}

class AttendanceNotifier extends StateNotifier<AttendanceState> {
  final Ref ref;
  final CxApiClient api = CxApiClient();

  AttendanceNotifier(this.ref) : super(AttendanceState());

  Future<bool> markPresent() async {
    state = state.copyWith(isMarking: true, errorMessage: null);

    try {
      final res = await api.dio.post('/api/mobile/attendance/mark');
      final data = res.data;

      if (data['ok'] == true) {
        state = AttendanceState(
          isMarking: false,
          markedSuccess: true,
          markedAt: data['markedAt'] ?? DateTime.now().toIso8601String(),
        );
        ref.invalidate(bootstrapProvider);
        return true;
      } else {
        state = AttendanceState(
          isMarking: false,
          errorMessage:
              data['error']?['message'] ?? 'Could not mark attendance.',
        );
        return false;
      }
    } catch (e) {
      state = AttendanceState(
        isMarking: false,
        errorMessage: CxApiClient.parseError(e),
      );
      return false;
    }
  }
}

final attendanceProvider =
    StateNotifierProvider<AttendanceNotifier, AttendanceState>((ref) {
      return AttendanceNotifier(ref);
    });

// --- PEOPLE DIRECTORY & SEARCH PROVIDERS ---
class PeopleFilter {
  final String query;
  final String role; // ALL | EMPLOYEES | INTERNS | MANAGEMENT
  final String department;

  const PeopleFilter({
    this.query = '',
    this.role = 'ALL',
    this.department = '',
  });

  PeopleFilter copyWith({String? query, String? role, String? department}) {
    return PeopleFilter(
      query: query ?? this.query,
      role: role ?? this.role,
      department: department ?? this.department,
    );
  }
}

final peopleFilterProvider = StateProvider<PeopleFilter>(
  (ref) => const PeopleFilter(),
);

final peopleListProvider = FutureProvider.autoDispose<List<PeopleModel>>((
  ref,
) async {
  final filter = ref.watch(peopleFilterProvider);
  final api = CxApiClient();

  final queryParams = <String, dynamic>{
    if (filter.query.isNotEmpty) 'q': filter.query,
    if (filter.role != 'ALL') 'role': filter.role,
    if (filter.department.isNotEmpty) 'department': filter.department,
    'limit': 100,
  };

  try {
    final res = await api.dio.get(
      '/api/mobile/people',
      queryParameters: queryParams,
    );
    if (res.data != null && res.data['ok'] == true) {
      final list = (res.data['people'] as List<dynamic>?) ?? [];
      return list.map((p) => PeopleModel.fromJson(p)).toList();
    }
  } catch (e) {
    debugPrint('[peopleListProvider] error: $e');
  }
  return [];
});

final coworkerProfileProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>?, String>((ref, username) async {
      final api = CxApiClient();
      try {
        final res = await api.dio.get('/api/mobile/profile/$username');
        if (res.data != null &&
            res.data['ok'] == true &&
            res.data['profile'] != null) {
          return Map<String, dynamic>.from(res.data['profile']);
        }
      } catch (_) {}

      // Fallback to canonical people profile endpoint
      try {
        final res2 = await api.dio.get('/api/mobile/people/$username/profile');
        if (res2.data != null &&
            res2.data['ok'] == true &&
            res2.data['profile'] != null) {
          return Map<String, dynamic>.from(res2.data['profile']);
        }
      } catch (e) {
        debugPrint('[coworkerProfileProvider] fallback error: $e');
      }
      return null;
    });

// --- GLOBAL SEARCH PROVIDER ---
class GlobalSearchQuery {
  final String query;
  final String category; // all | people | projects | posts | documents

  const GlobalSearchQuery({this.query = '', this.category = 'all'});
}

final globalSearchQueryProvider = StateProvider<GlobalSearchQuery>(
  (ref) => const GlobalSearchQuery(),
);

final globalSearchResultsProvider =
    FutureProvider.autoDispose<List<SearchResultItem>>((ref) async {
      final sq = ref.watch(globalSearchQueryProvider);
      if (sq.query.trim().isEmpty) return [];

      final api = CxApiClient();
      try {
        final res = await api.dio.get(
          '/api/mobile/search',
          queryParameters: {'q': sq.query.trim(), 'category': sq.category},
        );
        if (res.data != null && res.data['ok'] == true) {
          final results = (res.data['results'] as List<dynamic>?) ?? [];
          return results.map((r) => SearchResultItem.fromJson(r)).toList();
        }
      } catch (e) {
        debugPrint('[globalSearchResultsProvider] error: $e');
      }
      return [];
    });

// --- ATTENDANCE HISTORY & CORRECTIONS ---
final attendanceHistoryProvider =
    FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
      final api = CxApiClient();
      try {
        final res = await api.dio.get('/api/mobile/attendance/history');
        if (res.data != null && res.data['ok'] == true) {
          return Map<String, dynamic>.from(res.data);
        }
      } catch (e) {
        debugPrint('[attendanceHistoryProvider] error: $e');
      }
      return null;
    });

// --- LEAVE MANAGEMENT ---
final leaveListProvider = FutureProvider.autoDispose<List<LeaveRequestModel>>((
  ref,
) async {
  final api = CxApiClient();
  try {
    final res = await api.dio.get('/api/mobile/leave');
    if (res.data != null && res.data['ok'] == true) {
      final list = (res.data['leaveRequests'] as List<dynamic>?) ?? [];
      return list.map((l) => LeaveRequestModel.fromJson(l)).toList();
    }
  } catch (e) {
    debugPrint('[leaveListProvider] error: $e');
  }
  return [];
});

// --- DOCUMENTS MANAGEMENT ---
final documentsListProvider =
    FutureProvider.autoDispose<List<DocumentItemModel>>((ref) async {
      final api = CxApiClient();
      try {
        final res = await api.dio.get('/api/mobile/documents');
        if (res.data != null && res.data['ok'] == true) {
          final list = (res.data['documents'] as List<dynamic>?) ?? [];
          return list.map((d) => DocumentItemModel.fromJson(d)).toList();
        }
      } catch (e) {
        debugPrint('[documentsListProvider] error: $e');
      }
      return [];
    });

// --- PROJECTS PROVIDER ---
final projectsListProvider = FutureProvider.autoDispose<List<ProjectItemModel>>(
  (ref) async {
    final api = CxApiClient();
    try {
      final res = await api.dio.get('/api/mobile/projects');
      if (res.data != null && res.data['ok'] == true) {
        final list = (res.data['projects'] as List<dynamic>?) ?? [];
        return list.map((p) => ProjectItemModel.fromJson(p)).toList();
      }
    } catch (e) {
      debugPrint('[projectsListProvider] error: $e');
    }
    return [];
  },
);

// --- STORIES PROVIDER ---
final storiesProvider = FutureProvider.autoDispose<List<StoryGroupModel>>((
  ref,
) async {
  final api = CxApiClient();
  try {
    final res = await api.dio.get('/api/mobile/stories');
    if (res.data != null && res.data['ok'] == true) {
      final list = (res.data['stories'] as List<dynamic>?) ?? [];
      return list.map((s) => StoryGroupModel.fromJson(s)).toList();
    }
  } catch (e) {
    debugPrint('[storiesProvider] error: ');
  }
  return [];
});

// --- PAYMENTS DASHBOARD PROVIDER ---
final paymentsDashboardProvider =
    FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
      final api = CxApiClient();
      try {
        final res = await api.dio.get('/api/mobile/payments');
        if (res.data != null && res.data['ok'] == true) {
          return Map<String, dynamic>.from(res.data);
        }
      } catch (e) {
        debugPrint('[paymentsDashboardProvider] error: ');
      }
      return null;
    });

// --- MY WORK PROVIDER ---
final myWorkProvider = FutureProvider.autoDispose<List<MyWorkTaskModel>>((
  ref,
) async {
  final api = CxApiClient();
  try {
    final res = await api.dio.get('/api/mobile/work');
    if (res.data != null && res.data['ok'] == true) {
      final list = (res.data['tasks'] as List<dynamic>?) ?? [];
      return list.map((t) => MyWorkTaskModel.fromJson(t)).toList();
    }
  } catch (e) {
    debugPrint('[myWorkProvider] error: ');
  }
  return [];
});
