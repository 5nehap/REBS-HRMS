import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/leave_balance_model.dart';

class LeaveBalanceCard extends StatelessWidget {
  final LeaveBalanceModel? balance;

  const LeaveBalanceCard({super.key, this.balance});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Leave Balances',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildBalanceItem(
                  'Casual',
                  balance?.casualLeave ?? 0,
                  AppColors.info,
                ),
                _buildBalanceItem(
                  'Sick',
                  balance?.sickLeave ?? 0,
                  AppColors.warning,
                ),
                _buildBalanceItem(
                  'Total',
                  balance?.totalAvailableLeave ?? 0,
                  AppColors.success,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceItem(String title, int count, Color color) {
    return Column(
      children: [
        Text(
          '$count',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
