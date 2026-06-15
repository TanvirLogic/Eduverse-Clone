import 'package:flutter/material.dart';
import 'package:edtech/app/setup_network_caller.dart';
import 'package:edtech/app/urls.dart';
import 'package:edtech/global/core/services/toast_service.dart';
import 'resend_timer_mixin.dart';

class PasswordResetProvider extends ChangeNotifier with ResendTimerMixin {
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  String? _resetEmail;
  String? get resetEmail => _resetEmail;

  String? _resetCode;
  String? get resetCode => _resetCode;

  Future<bool> forgotPassword(String email) async {
    bool isSuccess = false;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final response = await getNetworkCaller(isPublic: true).postRequest(
      url: Urls.forgotPasswordUrl,
      body: {'email': email},
    );

    if (response.isSuccess) {
      _resetEmail = email;
      isSuccess = true;
      ToastService.showSuccess("OTP sent to your email!");
    } else {
      _errorMessage = response.errorMessage;
      ToastService.showError(response.errorMessage ?? 'Failed to send OTP');
    }

    _isLoading = false;
    notifyListeners();
    return isSuccess;
  }

  Future<bool> verifyResetOtp(String email, String code) async {
    bool isSuccess = false;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final response = await getNetworkCaller(isPublic: true).postRequest(
      url: Urls.verifyResetOtpUrl,
      body: {'email': email, 'code': code},
    );

    if (response.isSuccess) {
      isSuccess = true;
      _resetEmail = email;
      _resetCode = code;
      ToastService.showSuccess("OTP verified successfully!");
    } else {
      _errorMessage = response.errorMessage;
      ToastService.showError(response.errorMessage ?? 'OTP verification failed');
    }

    _isLoading = false;
    notifyListeners();
    return isSuccess;
  }

  Future<bool> resetPassword(String email, String code, String newPassword) async {
    bool isSuccess = false;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final response = await getNetworkCaller(isPublic: true).postRequest(
      url: Urls.resetPasswordUrl,
      body: {'email': email, 'code': code, 'newPassword': newPassword},
    );

    if (response.isSuccess) {
      isSuccess = true;
      _resetEmail = null;
      ToastService.showSuccess("Password reset successfully!");
    } else {
      _errorMessage = response.errorMessage;
      ToastService.showError(response.errorMessage ?? 'Password reset failed');
    }

    _isLoading = false;
    notifyListeners();
    return isSuccess;
  }

}
