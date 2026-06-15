import 'dart:async';
import 'package:flutter/material.dart';

mixin ResendTimerMixin on ChangeNotifier {
  int _resendTimerSeconds = 0;
  Timer? _resendTimer;

  int get resendTimerSeconds => _resendTimerSeconds;
  bool get canResendCode => _resendTimerSeconds == 0;

  void startResendTimer() {
    _resendTimerSeconds = 30;
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendTimerSeconds > 0) {
        _resendTimerSeconds--;
        notifyListeners();
      } else {
        _resendTimer?.cancel();
      }
    });
    notifyListeners();
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    super.dispose();
  }
}
