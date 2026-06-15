import 'package:flutter/material.dart';
import 'package:edtech/app/setup_network_caller.dart';
import 'package:edtech/app/urls.dart';
import 'package:edtech/global/core/services/toast_service.dart';

class ChangePasswordProvider extends ChangeNotifier {
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  Future<bool> changeEmail(String newEmail) async {
    bool isSuccess = false;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final response = await getNetworkCaller().postRequest(
      url: Urls.profileEmailUrl,
      body: {'email': newEmail},
    );

    if (response.isSuccess) {
      isSuccess = true;
      ToastService.showSuccess('Email change requested. Check your new inbox.');
    } else {
      _errorMessage = response.errorMessage;
      ToastService.showError(response.errorMessage ?? 'Failed to change email');
    }

    _isLoading = false;
    notifyListeners();
    return isSuccess;
  }

  Future<bool> changePassword(String currentPassword, String newPassword) async {
    bool isSuccess = false;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final response = await getNetworkCaller().postRequest(
      url: Urls.changePasswordUrl,
      body: {'currentPassword': currentPassword, 'newPassword': newPassword},
    );

    if (response.isSuccess) {
      isSuccess = true;
      ToastService.showSuccess('Password changed successfully');
    } else {
      _errorMessage = response.errorMessage;
      ToastService.showError(response.errorMessage ?? 'Failed to change password');
    }

    _isLoading = false;
    notifyListeners();
    return isSuccess;
  }
}
