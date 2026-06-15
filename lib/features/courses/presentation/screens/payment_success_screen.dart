import 'package:edtech/global/core/constants/images/images.dart';
import 'package:edtech/global/core/constants/sizes.dart';
import 'package:edtech/app/app_routes.dart';
import 'package:edtech/global/core/widgets/auth_button.dart';
import 'package:flutter/material.dart';

class PaymentSuccessScreen extends StatelessWidget {
  const PaymentSuccessScreen({super.key});
  static const String name = '/payment-success';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSizes.horizontalPadding, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 2),
              Center(
                child: SizedBox(
                  width: 240,
                  height: 240,
                  child: Image.asset(
                    Images.passwordSuccess,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                'Congrats! Your Payment\nSuccessful',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 24,
                  height: 1.3,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'You now have full access to all course videos, modules, tasks, and resources.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(flex: 2),
              const _PaymentSummaryContainer(
                amount: '\u09F3500',
                courseName: 'UI/UX Design Bootca...',
                transactionId: '#9A7BC12D34',
              ),
              const Spacer(flex: 3),
              AuthButton(
                text: 'Continue',
                height: 54,
                borderRadius: 30,
                onPressed: () => Navigator.pushNamedAndRemoveUntil(
                  context,
                  AppRoutes.home,
                  (route) => false,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaymentSummaryContainer extends StatelessWidget {
  final String amount;
  final String courseName;
  final String transactionId;

  const _PaymentSummaryContainer({
    required this.amount,
    required this.courseName,
    required this.transactionId,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg2),
        border: Border.all(
          color: theme.colorScheme.outlineVariant,
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Summary',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          _SummaryMetricRow(label: 'Pay Amount:', value: amount),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            child: Divider(height: 1, color: theme.colorScheme.outlineVariant),
          ),
          _SummaryMetricRow(label: 'Course Name:', value: courseName),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            child: Divider(height: 1, color: theme.colorScheme.outlineVariant),
          ),
          _SummaryMetricRow(label: 'Trx ID:', value: transactionId),
        ],
      ),
    );
  }
}

class _SummaryMetricRow extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryMetricRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 15,
            color: cs.onSurface.withValues(alpha: 0.6),
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            color: cs.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
