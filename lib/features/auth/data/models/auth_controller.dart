import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../../global/core/services/secure_storage.dart';
import 'user_model.dart';

class AuthController {
  static const _userKey = 'user-data';
  static UserModel? userModel;
  static String? accessToken;

  static Future<void> saveUserData(String token, UserModel model) async {
    await SecureStorage.saveTokens(
      accessToken: token,
      refreshToken: model.refreshToken ?? '',
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(model.toJson()));
    accessToken = token;
    userModel = model;
  }

  static Future<void> getUserData() async {
    accessToken = await SecureStorage.getAccessToken();
    if (accessToken != null) {
      final prefs = await SharedPreferences.getInstance();
      final userData = prefs.getString(_userKey);
      if (userData != null) {
        userModel = UserModel.fromJson(jsonDecode(userData));
        if (userModel?.token == null) {
          final refreshToken = await SecureStorage.getRefreshToken();
          userModel = userModel!.copyWith(
            token: accessToken,
            refreshToken: refreshToken,
          );
        }
      }
    }
  }

  static Future<bool> isLoggedIn() async {
    final token = await SecureStorage.getAccessToken();
    return token != null;
  }

  static Future<void> clearUserData() async {
    await SecureStorage.clearTokens();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
    accessToken = null;
    userModel = null;
  }
}