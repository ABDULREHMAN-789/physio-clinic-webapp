import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/user_model.dart';
import '../../sessions/providers/sessions_provider.dart';
import '../../staff/providers/staff_provider.dart';

/// StateProvider holding the currently selected month and year for staff salary calculations.
/// Defaults to the 1st of the current month.
final salaryMonthFilterProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, 1);
});

/// Data holder for aggregated staff salary and performance metrics.
class StaffSalarySummary {
  final UserModel staff;
  final int sessionsCount;
  final double totalRevenueGenerated;
  final double calculatedSalary;

  const StaffSalarySummary({
    required this.staff,
    required this.sessionsCount,
    required this.totalRevenueGenerated,
    required this.calculatedSalary,
  });
}

/// Selector/Provider that computes staff salary and performance summary for the selected month.
/// Listens to [staffProvider], [sessionsStreamProvider], and [salaryMonthFilterProvider].
final staffSalarySummaryProvider = Provider<List<StaffSalarySummary>>((ref) {
  final staffList = ref.watch(staffProvider).valueOrNull ?? [];
  final sessionsList = ref.watch(sessionsStreamProvider).valueOrNull ?? [];
  final selectedMonth = ref.watch(salaryMonthFilterProvider);

  // Filter conducted sessions to only those in the selected month & year
  final monthSessions = sessionsList.where((s) =>
    s.sessionDate.year == selectedMonth.year &&
    s.sessionDate.month == selectedMonth.month,
  ).toList();

  return staffList.map((therapist) {
    final therapistSessions = monthSessions.where((s) => s.therapistId == therapist.userId);
    final double revenueGenerated = therapistSessions
        .where((s) => s.paymentStatus == 'Paid')
        .fold(0.0, (sum, s) => sum + s.charges);
    final int count = therapistSessions.length;
    final double calculatedSalary = revenueGenerated * (therapist.revenuePercentage / 100);

    return StaffSalarySummary(
      staff: therapist,
      sessionsCount: count,
      totalRevenueGenerated: revenueGenerated,
      calculatedSalary: calculatedSalary,
    );
  }).toList();
});
