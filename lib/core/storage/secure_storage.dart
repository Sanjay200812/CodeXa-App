import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';

class CxStorage {
  static const _storage = FlutterSecureStorage();
  static SharedPreferences? _prefs;

  static const String _tokenKey = 'cxa_access_token';
  static const String _userKey = 'cxa_user_json';
  static const String _roleKey = 'cxa_user_role';
  static const String _deviceIdKey = 'cxa_device_id';
  static const String _savedAccountsKey = 'cxa_saved_accounts_v1';
  static const String _activeAccountIdKey = 'cxa_active_account_id_v1';

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // --- MULTI-ACCOUNT VAULT ---

  static Future<List<SavedAccount>> getSavedAccounts() async {
    try {
      String? jsonStr;
      try {
        jsonStr = await _storage.read(key: _savedAccountsKey);
      } catch (_) {
        jsonStr = _prefs?.getString(_savedAccountsKey);
      }
      if (jsonStr == null || jsonStr.isEmpty) return [];
      final list = jsonDecode(jsonStr) as List<dynamic>;
      return list
          .map((item) => SavedAccount.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<String?> getActiveAccountId() async {
    final prefId = _prefs?.getString(_activeAccountIdKey);
    if (prefId != null && prefId.isNotEmpty) return prefId;
    try {
      return await _storage.read(key: _activeAccountIdKey);
    } catch (_) {
      return null;
    }
  }

  static Future<SavedAccount?> getActiveAccount() async {
    try {
      final activeId = await getActiveAccountId();
      final accounts = await getSavedAccounts();
      if (accounts.isEmpty) return null;
      if (activeId == null) return accounts.first;
      try {
        return accounts.firstWhere((acc) => acc.id == activeId);
      } catch (_) {
        return accounts.first;
      }
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveAccount(
    SavedAccount account, {
    bool makeActive = true,
  }) async {
    try {
      final accounts = await getSavedAccounts();
      // Remove if already exists with same ID to avoid duplicates
      accounts.removeWhere((acc) => acc.id == account.id);
      accounts.insert(0, account);

      final jsonStr = jsonEncode(accounts.map((a) => a.toJson()).toList());
      _prefs?.setString(_savedAccountsKey, jsonStr);
      try {
        await _storage.write(key: _savedAccountsKey, value: jsonStr);
      } catch (_) {}

      if (makeActive) {
        await switchActiveAccount(account.id);
      }
    } catch (_) {}
  }

  static Future<bool> switchActiveAccount(String accountId) async {
    try {
      final accounts = await getSavedAccounts();
      final target = accounts.firstWhere(
        (acc) => acc.id == accountId,
        orElse: () => accounts.isNotEmpty
            ? accounts.first
            : throw Exception('No account found'),
      );

      _prefs?.setString(_activeAccountIdKey, target.id);
      try {
        await _storage.write(key: _activeAccountIdKey, value: target.id);
      } catch (_) {}

      // Sync active token & user data for transparent compatibility
      _prefs?.setString(_tokenKey, target.accessToken);
      _prefs?.setString('has_token', 'true');
      _prefs?.setString('user_role', target.role);
      try {
        await _storage.write(key: _tokenKey, value: target.accessToken);
        await _storage.write(key: _roleKey, value: target.role);
      } catch (_) {}

      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> removeAccount(String accountId) async {
    try {
      final accounts = await getSavedAccounts();
      accounts.removeWhere((acc) => acc.id == accountId);

      final jsonStr = jsonEncode(accounts.map((a) => a.toJson()).toList());
      _prefs?.setString(_savedAccountsKey, jsonStr);
      try {
        await _storage.write(key: _savedAccountsKey, value: jsonStr);
      } catch (_) {}

      final activeId = await getActiveAccountId();
      if (activeId == accountId) {
        if (accounts.isNotEmpty) {
          await switchActiveAccount(accounts.first.id);
        } else {
          await clearAll();
        }
      }
    } catch (_) {}
  }

  // --- TOKEN MANAGEMENT (ACTIVE ACCOUNT) ---

  static Future<void> saveToken(String token) async {
    _prefs?.setString(_tokenKey, token);
    _prefs?.setString('has_token', 'true');
    try {
      await _storage.write(key: _tokenKey, value: token);
    } catch (_) {}
  }

  static Future<String?> getToken() async {
    try {
      final active = await getActiveAccount();
      if (active != null && active.accessToken.isNotEmpty) {
        return active.accessToken;
      }
      final prefToken = _prefs?.getString(_tokenKey);
      if (prefToken != null && prefToken.isNotEmpty) return prefToken;
      try {
        return await _storage.read(key: _tokenKey);
      } catch (_) {
        return null;
      }
    } catch (_) {
      return null;
    }
  }

  static Future<void> deleteToken() async {
    _prefs?.remove(_tokenKey);
    _prefs?.remove('has_token');
    try {
      await _storage.delete(key: _tokenKey);
    } catch (_) {}
  }

  // --- ROLE AND USER CACHE ---

  static Future<void> saveUserRole(String role) async {
    _prefs?.setString('user_role', role);
    try {
      await _storage.write(key: _roleKey, value: role);
    } catch (_) {}
  }

  static Future<String?> getUserRole() async {
    final role = _prefs?.getString('user_role');
    if (role != null) return role;
    try {
      return await _storage.read(key: _roleKey);
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveUserData(String jsonString) async {
    _prefs?.setString('cached_user', jsonString);
    try {
      await _storage.write(key: _userKey, value: jsonString);
    } catch (_) {}
  }

  static Future<String?> getUserData() async {
    final cached = _prefs?.getString('cached_user');
    if (cached != null) return cached;
    try {
      return await _storage.read(key: _userKey);
    } catch (_) {
      return null;
    }
  }

  // --- DEVICE ID & FCM PUSH TOKEN ---

  static const String _fcmTokenKey = 'cxa_fcm_token';

  static Future<void> saveFcmToken(String token) async {
    _prefs?.setString(_fcmTokenKey, token);
    try {
      await _storage.write(key: _fcmTokenKey, value: token);
    } catch (_) {}
  }

  static Future<String?> getFcmToken() async {
    final token = _prefs?.getString(_fcmTokenKey);
    if (token != null && token.isNotEmpty) return token;
    try {
      return await _storage.read(key: _fcmTokenKey);
    } catch (_) {
      return null;
    }
  }

  static Future<String> getOrCreateDeviceId() async {
    String? id = _prefs?.getString(_deviceIdKey);
    if (id == null) {
      id = 'device_${DateTime.now().millisecondsSinceEpoch}';
      _prefs?.setString(_deviceIdKey, id);
    }
    return id;
  }

  // --- GENERIC KEY-VALUE VAULT ---

  static Future<String?> read(String key) async {
    final cached = _prefs?.getString(key);
    if (cached != null) return cached;
    try {
      return await _storage.read(key: key);
    } catch (_) {
      return null;
    }
  }

  static Future<void> write(String key, String value) async {
    _prefs?.setString(key, value);
    try {
      await _storage.write(key: key, value: value);
    } catch (_) {}
  }

  // --- CLEAR ON LOGOUT ALL ---

  static Future<void> clearAll() async {
    _prefs?.remove('has_token');
    _prefs?.remove('user_role');
    _prefs?.remove('cached_user');
    _prefs?.remove(_activeAccountIdKey);
    _prefs?.remove(_tokenKey);
    _prefs?.remove(_savedAccountsKey);
    try {
      await _storage.deleteAll();
    } catch (_) {}
  }
}
