import 'package:flutter/material.dart';
import 'package:edtech/app/setup_network_caller.dart';
import 'package:edtech/app/urls.dart';
import 'package:edtech/features/auth/data/models/auth_controller.dart';
import 'package:edtech/features/auth/data/models/user_model.dart';
import 'package:edtech/global/core/services/toast_service.dart';
import 'resend_timer_mixin.dart';

class VerifyOtpProvider extends ChangeNotifier with ResendTimerMixin {
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  UserModel? _verifiedUser;
  UserModel? get verifiedUser => _verifiedUser;

  Future<bool> verifyEmail(String email, String code) async {
    bool isSuccess = false;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final response = await getNetworkCaller(isPublic: true).postRequest(
      url: Urls.verifyEmailUrl,
      body: {'email': email, 'code': code},
    );

    if (response.isSuccess) {
      final data = response.responseData['data'];
      final token = data['accessToken']?.toString() ?? '';
      final refreshToken = data['refreshToken']?.toString() ?? '';
      if (token.isNotEmpty) {
        await AuthController.saveUserData(
          token,
          UserModel(id: '', email: email, firstName: '', lastName: '', token: token, refreshToken: refreshToken),
        );
      }
      _verifiedUser = UserModel(id: '', email: email, firstName: '', lastName: '');
      isSuccess = true;
      ToastService.showSuccess("Email verified successfully!");
    } else {
      _errorMessage = response.errorMessage;
      ToastService.showError(response.errorMessage ?? 'Verification failed');
    }

    _isLoading = false;
    notifyListeners();
    return isSuccess;
  }

  Future<String?> resendEmailVerification(String email) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final response = await getNetworkCaller(isPublic: true).postRequest(
      url: Urls.resendEmailVerificationUrl,
      body: {'email': email},
    );

    String? message;
    if (response.isSuccess) {
      message = response.responseData['message']?.toString() ?? 'Verification code sent';
      startResendTimer();
      ToastService.showSuccess(message);
    } else {
      _errorMessage = response.errorMessage;
      ToastService.showError(response.errorMessage ?? 'Failed to resend code');
    }

    _isLoading = false;
    notifyListeners();
    return message;
  }

}
