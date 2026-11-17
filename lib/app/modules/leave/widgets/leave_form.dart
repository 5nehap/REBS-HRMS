import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_helper.dart';
import '../controllers/leave_controller.dart';

class LeaveForm extends GetView<LeaveController> {
  final Future<void> Function()? onSuccess;

  const LeaveForm({super.key, this.onSuccess});

  Future<void> _selectStartDate(BuildContext context) async {
    final companyDate = controller.leaveLogic.getCompanyCurrentDate();
    final initialDate =
        controller.startDate.value.isNotEmpty
            ? (DateHelper.parseDate(controller.startDate.value) ?? companyDate)
            : companyDate;

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate.isBefore(companyDate) ? companyDate : initialDate,
      firstDate: companyDate,
      lastDate: companyDate.add(const Duration(days: 365)),
      helpText: 'Select Leave Start Date',
    );

    if (picked != null) {
      controller.updateStartDate(DateHelper.formatDate(picked));
    }
  }

  Future<void> _selectEndDate(BuildContext context) async {
    final companyDate = controller.leaveLogic.getCompanyCurrentDate();
    final parsedStart = DateHelper.parseDate(controller.startDate.value);
    final minDate = parsedStart ?? companyDate;

    final initialDate =
        controller.endDate.value.isNotEmpty
            ? (DateHelper.parseDate(controller.endDate.value) ?? minDate)
            : minDate;

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate.isBefore(minDate) ? minDate : initialDate,
      firstDate: minDate,
      lastDate: companyDate.add(const Duration(days: 365)),
      helpText: 'Select Leave End Date',
    );

    if (picked != null) {
      controller.updateEndDate(DateHelper.formatDate(picked));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Obx(() {
        final balance = controller.leaveBalance.value;
        final casualAvailable = balance?.casualLeave ?? 0;
        final sickAvailable = balance?.sickLeave ?? 0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Leave Type Selector
            const Text(
              'Leave Type',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: Center(
                      child: Text('Casual ($casualAvailable)'),
                    ),
                    selected: controller.selectedLeaveType.value == 'Casual',
                    onSelected: (selected) {
                      if (selected) controller.updateLeaveType('Casual');
                    },
                    selectedColor: AppColors.primaryLight,
                    labelStyle: TextStyle(
                      fontWeight: FontWeight.w600,
                      color:
                          controller.selectedLeaveType.value == 'Casual'
                              ? Colors.white
                              : AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ChoiceChip(
                    label: Center(
                      child: Text('Sick ($sickAvailable)'),
                    ),
                    selected: controller.selectedLeaveType.value == 'Sick',
                    onSelected: (selected) {
                      if (selected) controller.updateLeaveType('Sick');
                    },
                    selectedColor: AppColors.primaryLight,
                    labelStyle: TextStyle(
                      fontWeight: FontWeight.w600,
                      color:
                          controller.selectedLeaveType.value == 'Sick'
                              ? Colors.white
                              : AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 2. Start Date & End Date Row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Start Date Field
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Start Date',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: () => _selectStartDate(context),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color:
                                  controller.startDateError.value.isNotEmpty
                                      ? AppColors.error
                                      : AppColors.border,
                            ),
                            borderRadius: BorderRadius.circular(8),
                            color: AppColors.cardColor
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                controller.startDate.value.isNotEmpty
                                    ? controller.startDate.value
                                    : 'YYYY-MM-DD',
                                style: TextStyle(
                                  color:
                                      controller.startDate.value.isNotEmpty
                                          ? AppColors.textPrimary
                                          : AppColors.textMuted,
                                  fontSize: 13,
                                ),
                              ),
                              const Icon(
                                Icons.calendar_month_rounded,
                                size: 18,
                                color: AppColors.primary,
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (controller.startDateError.value.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          controller.startDateError.value,
                          style: const TextStyle(
                            color: AppColors.error,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // End Date Field
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'End Date',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: () => _selectEndDate(context),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color:
                                  controller.endDateError.value.isNotEmpty
                                      ? AppColors.error
                                      : AppColors.border,
                            ),
                            borderRadius: BorderRadius.circular(8),
                            color: AppColors.cardColor
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                controller.endDate.value.isNotEmpty
                                    ? controller.endDate.value
                                    : 'YYYY-MM-DD',
                                style: TextStyle(
                                  color:
                                      controller.endDate.value.isNotEmpty
                                          ? AppColors.textPrimary
                                          : AppColors.textMuted,
                                  fontSize: 13,
                                ),
                              ),
                              const Icon(
                                Icons.calendar_month_rounded,
                                size: 18,
                                color: AppColors.primary,
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (controller.endDateError.value.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          controller.endDateError.value,
                          style: const TextStyle(
                            color: AppColors.error,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),

            // 3. Requested Duration Display & Overlap / Balance Warnings
            if (controller.requestedDays.value > 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.primary.withAlpha(40)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.timelapse_rounded,
                      size: 18,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Requested: ${controller.requestedDays.value} calendar day(s) (including weekends & holidays)',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Balance Error
            if (controller.balanceError.value.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.error.withAlpha(15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.error.withAlpha(50)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      size: 16,
                      color: AppColors.error,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        controller.balanceError.value,
                        style: const TextStyle(
                          color: AppColors.error,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Overlap Error
            if (controller.overlapError.value.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.error.withAlpha(15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.error.withAlpha(50)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      size: 16,
                      color: AppColors.error,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        controller.overlapError.value,
                        style: const TextStyle(
                          color: AppColors.error,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            // 4. Reason Field
            const Text(
              'Reason for Leave',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: controller.reasonController,
              onChanged: controller.onReasonChanged,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Enter reason (minimum 10 characters)...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                errorText:
                    controller.reasonError.value.isNotEmpty
                        ? controller.reasonError.value
                        : null,
              ),
            ),

            // 5. Server Error Banner (if any)
            if (controller.serverError.value.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error.withAlpha(15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.error.withAlpha(60)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: AppColors.error,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        controller.serverError.value,
                        style: const TextStyle(
                          color: AppColors.error,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // 6. Submit Button
            ElevatedButton(
              onPressed:
                  controller.isSubmitting.value
                      ? null
                      : () async {
                        final success =
                            await controller.submitLeaveApplication();
                        if (success && onSuccess != null) {
                          await onSuccess!();
                        }
                      },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child:
                  controller.isSubmitting.value
                      ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                      : const Text(
                        'Submit Application',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
            ),
          ],
        );
      }),
    );
  }
}
