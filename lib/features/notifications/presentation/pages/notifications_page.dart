import 'package:edtech/app/app_colors.dart';
import 'package:edtech/global/core/constants/sizes.dart';
import 'package:edtech/global/core/widgets/app_back_button.dart';
import 'package:flutter/material.dart';

class _NotificationItem {
  final String title;
  final String body;
  final String time;
  final bool isRead;

  const _NotificationItem({
    required this.title,
    required this.body,
    required this.time,
    this.isRead = false,
  });
}

const _sampleNotifications = [
  _NotificationItem(
    title: 'New Course Available',
    body: 'Advanced Flutter with AI course is now live. Enroll now to get 20% off!',
    time: '2 min ago',
  ),
  _NotificationItem(
    title: 'Assignment Due Soon',
    body: 'Your "State Management" assignment is due in 2 days.',
    time: '1 hour ago',
  ),
  _NotificationItem(
    title: 'Certificate Earned',
    body: 'Congratulations! You earned a certificate for "Dart Fundamentals".',
    time: '3 hours ago',
  ),
  _NotificationItem(
    title: 'New Message from Mentor',
    body: 'Your mentor replied to your question about Streams in Dart.',
    time: '5 hours ago',
  ),
  _NotificationItem(
    title: 'Payment Successful',
    body: 'Your payment for "Web Development Bootcamp" has been confirmed.',
    time: '1 day ago',
    isRead: true,
  ),
  _NotificationItem(
    title: 'Course Updated',
    body: 'New videos added to the "React Native" module.',
    time: '2 days ago',
    isRead: true,
  ),
  _NotificationItem(
    title: 'Achievement Unlocked',
    body: 'You completed 10 consecutive days of learning! Keep it up!',
    time: '3 days ago',
    isRead: true,
  ),
];

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});
  static const String name = '/notifications';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: const Padding(
          padding: EdgeInsets.only(left: 8),
          child: AppBackButton(),
        ),
        title: Text(
          'Notifications',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: cs.onSurface,
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: () {},
            child: Text(
              'Clear All',
              style: TextStyle(color: AppColors.themeColor, fontSize: 14),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
        children: [
          ...List.generate(_sampleNotifications.length, (index) {
            final notif = _sampleNotifications[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _buildNotificationCard(notif, cs, isDark),
            );
          }),
          _buildTestButton(cs, isDark),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(_NotificationItem notif, ColorScheme cs, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: notif.isRead
            ? (isDark ? cs.surfaceContainerLow : Colors.white)
            : (isDark ? cs.surfaceContainerHighest : const Color(0xFFF0F4FF)),
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        notif.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: notif.isRead ? FontWeight.w500 : FontWeight.w700,
                          color: cs.onSurface,
                        ),
                      ),
                    ),
                    if (!notif.isRead)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: AppColors.themeColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  notif.body,
                  style: TextStyle(
                    fontSize: 13,
                    color: cs.onSurface.withValues(alpha: 0.6),
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  notif.time,
                  style: TextStyle(
                    fontSize: 11,
                    color: cs.onSurface.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestButton(ColorScheme cs, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? cs.surfaceContainerLow : Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(
          color: AppColors.border,
          width: 1.5,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        onTap: () {},
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Test Push Notification',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Tap here to send a test notification to your notification tray',
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: 14, color: cs.onSurface.withValues(alpha: 0.3)),
          ],
        ),
      ),
    );
  }

}
