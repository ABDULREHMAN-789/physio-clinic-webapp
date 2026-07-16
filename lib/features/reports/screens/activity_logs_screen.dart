import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../providers/activity_logs_provider.dart';

class ActivityLogsScreen extends ConsumerWidget {
  const ActivityLogsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(activityLogsStreamProvider);
    final textTheme = Theme.of(context).textTheme;
    final formatter = DateFormat('dd MMM yyyy, hh:mm a');

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.p24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                'Activity Logs',
                style: textTheme.displaySmall?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              AppSizes.h4,
              Text(
                'Monitor staff actions, patient transfers, and system events.',
                style: textTheme.bodyMedium,
              ),
              AppSizes.h24,

              // Logs List
              Expanded(
                child: logsAsync.when(
                  data: (logs) {
                    if (logs.isEmpty) {
                      return Center(
                        child: Text(
                          'No activity logs recorded yet.',
                          style: textTheme.headlineMedium?.copyWith(color: AppColors.textSecondary),
                        ),
                      );
                    }
                    return Card(
                      child: ListView.separated(
                        itemCount: logs.length,
                        separatorBuilder: (context, index) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final log = logs[index];
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: AppSizes.p20, vertical: AppSizes.p12),
                            leading: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.primaryLight,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.info_outline_rounded, color: AppColors.primaryDark),
                            ),
                            title: Text(
                              log.action,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AppSizes.h4,
                                Text(log.details, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
                                AppSizes.h4,
                                Text(
                                  formatter.format(log.timestamp),
                                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                            trailing: Text(
                              'By: ${log.performedByName}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primaryDark),
                            ),
                          );
                        },
                      ),
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Center(child: Text('Error loading logs: $err')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
