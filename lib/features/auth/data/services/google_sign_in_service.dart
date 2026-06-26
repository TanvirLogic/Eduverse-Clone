import 'dart:convert';

import 'package:edtech/global/core/config/app_config.dart';
import 'package:edtech/global/core/services/logger_service.dart';
import 'package:google_sign_in/google_sign_in.dart';

class GoogleSignInService {
  late final GoogleSignIn _googleSignIn;

  GoogleSignInService() {
    _googleSignIn = GoogleSignIn(
      scopes: ['email', 'profile'],
      clientId: AppConfig.googleClientId,
      serverClientId: AppConfig.googleClientId,
    );
  }

  String _decodeIdTokenAudience(String idToken) {
    try {
      final parts = idToken.split('.');
      if (parts.length != 3) return '⚠️ Not a valid JWT (expected 3 parts)';
      final normalized = parts[1]
          .replaceAll('-', '+')
          .replaceAll('_', '/')
          .padRight(((parts[1].length + 3) ~/ 4) * 4, '=');
      final decoded = utf8.decode(base64.decode(normalized));
      final json = jsonDecode(decoded) as Map<String, dynamic>;

      final aud = json['aud']?.toString() ?? '⚠️ no "aud" claim';
      final email = json['email']?.toString() ?? '⚠️ no "email" claim';

      AppLogger.d('idToken aud=$aud, email=$email');
      return aud;
    } catch (e) {
      return '⚠️ decode error: $e';
    }
  }

  Future<void> signOut() => _googleSignIn.signOut();

  Future<String?> signIn() async {
    await _googleSignIn.signOut();

    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) {
      return null;
    }

    final googleAuth = await googleUser.authentication;
    if (googleAuth.idToken == null) {
      return null;
    }

    _decodeIdTokenAudience(googleAuth.idToken!);

    return googleAuth.idToken;
  }
}
