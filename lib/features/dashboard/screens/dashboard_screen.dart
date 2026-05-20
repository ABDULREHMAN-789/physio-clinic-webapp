import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../models/patient_model.dart';
import '../../../models/session_model.dart';
import '../../patients/providers/patients_provider.dart';
import '../../sessions/providers/sessions_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patientsAsync = ref.watch(patientsStreamProvider);
    final sessionsAsync = ref.watch(sessionsStreamProvider);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSizes.p24),
          child: patientsAsync.when(
            data: (patients) {
              return sessionsAsync.when(
                data: (sessions) {
                  return _buildDashboardContent(context, ref, patients, sessions);
                },
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.only(top: 100.0),
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                ),
                error: (e, s) => Center(child: Text('Error loading session data: $e')),
              );
            },
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.only(top: 100.0),
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            ),
            error: (e, s) => Center(child: Text('Error loading patient registry: $e')),
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardContent(
    BuildContext context,
    WidgetRef ref,
    List<PatientModel> patients,
    List<SessionModel> sessions,
  ) {
    final textTheme = Theme.of(context).textTheme;
    final size = MediaQuery.of(context).size;
    final isNarrow = size.width < AppSizes.desktopBreakpoint;

    // Calculations
    final int totalPatients = patients.length;
    final int totalSessions = sessions.length;
    final double totalRevenue = sessions.fold(0.0, (sum, s) => sum + s.charges);
    final double pendingDues = sessions.where((s) => !s.paymentStatus).fold(0.0, (sum, s) => sum + s.charges);
    final double totalEarnings = totalRevenue - pendingDues;

    // Slice recent activities (Max 4 logs)
    final recentPatients = patients.take(4).toList();
    final recentSessions = sessions.take(4).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Welcome Header Banner
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dashboard Overview',
                  style: textTheme.displaySmall?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                AppSizes.h4,
                Text(
                  'Track clinical patients activity, outstanding dues, and weekly revenue graphs.',
                  style: textTheme.bodyMedium,
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSizes.p16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.primary),
                  AppSizes.w8,
                  Text(
                    DateFormat('EEEE, d MMMM yyyy').format(DateTime.now()),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                  ),
                ],
              ),
            ),
          ],
        ),
        AppSizes.h24,

        // 1. Grid of metrics statistic cards
        LayoutBuilder(
          builder: (context, constraints) {
            final double width = constraints.maxWidth;
            int crossAxisCount = 4;
            if (width < 600) {
              crossAxisCount = 1;
            } else if (width < 1000) {
              crossAxisCount = 2;
            }

            return GridView.count(
              crossAxisCount: crossAxisCount,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: AppSizes.p16,
              mainAxisSpacing: AppSizes.p16,
              childAspectRatio: 2.2,
              children: [
                _buildStatCard(
                  title: 'Total Patients',
                  value: totalPatients.toString(),
                  subtitle: 'Registered profiles',
                  icon: Icons.people_alt_rounded,
                  color: AppColors.primary,
                  gradient: null,
                ),
                _buildStatCard(
                  title: 'Therapy Sessions',
                  value: totalSessions.toString(),
                  subtitle: 'Conducted logs',
                  icon: Icons.history_edu_rounded,
                  color: AppColors.secondary,
                  gradient: null,
                ),
                _buildStatCard(
                  title: 'Revenue Collected',
                  value: 'Rs. ${NumberFormat('#,##0').format(totalEarnings)}',
                  subtitle: 'Earned earnings',
                  icon: Icons.check_circle_rounded,
                  color: AppColors.success,
                  gradient: AppColors.dashboardCardGradient,
                ),
                _buildStatCard(
                  title: 'Pending Dues',
                  value: 'Rs. ${NumberFormat('#,##0').format(pendingDues)}',
                  subtitle: 'Outstanding dues',
                  icon: Icons.pending_actions_rounded,
                  color: AppColors.warning,
                  gradient: null,
                ),
              ],
            );
          },
        ),
        AppSizes.h24,

        // 2. Revenue Graph Block
        _buildRevenueGraphCard(context, sessions),
        AppSizes.h24,

        // 3. Splits for Recent Check-ins and Recent Sessions
        LayoutBuilder(
          builder: (context, constraints) {
            final double width = constraints.maxWidth;
            final bool isSplitNarrow = width < 800;

            final patientsListWidget = _buildRecentPatientsList(context, recentPatients);
            final sessionsListWidget = _buildRecentSessionsList(context, recentSessions, patients);

            if (isSplitNarrow) {
              return Column(
                children: [
                  patientsListWidget,
                  AppSizes.h20,
                  sessionsListWidget,
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: patientsListWidget),
                AppSizes.w24,
                Expanded(child: sessionsListWidget),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Gradient? gradient,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.p20),
      decoration: BoxDecoration(
        color: gradient == null ? Colors.white : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        border: gradient == null ? Border.all(color: AppColors.border, width: 1.5) : null,
        boxShadow: gradient != null
            ? [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                )
              ]
            : null,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSizes.p12),
            decoration: BoxDecoration(
              color: gradient == null ? color.withOpacity(0.1) : Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: gradient == null ? color : Colors.white,
              size: 24,
            ),
          ),
          AppSizes.w16,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    color: gradient == null ? AppColors.textSecondary : Colors.white.withOpacity(0.8),
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                    letterSpacing: 0.5,
                  ),
                ),
                AppSizes.h4,
                Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: gradient == null ? AppColors.textPrimary : Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
                AppSizes.h4,
                Text(
                  subtitle,
                  style: TextStyle(
                    color: gradient == null ? AppColors.textLight : Colors.white.withOpacity(0.7),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueGraphCard(BuildContext context, List<SessionModel> sessions) {
    // Generate monthly earnings details for the past 6 months
    final now = DateTime.now();
    final List<DateTime> months = List.generate(6, (i) => DateTime(now.year, now.month - i, 1));
    months.sort((a, b) => a.compareTo(b)); // Order chronologically

    final List<FlSpot> spots = [];
    final List<String> labels = [];

    for (int i = 0; i < months.length; i++) {
      final m = months[i];
      final monthSessions = sessions.where((s) => s.sessionDate.year == m.year && s.sessionDate.month == m.month);
      // Collect only paid revenue to draw clean graphical data points
      final double paidRevenue = monthSessions.where((s) => s.paymentStatus).fold(0.0, (sum, s) => sum + s.charges);
      spots.add(FlSpot(i.toDouble(), paidRevenue));
      labels.add(DateFormat('MMM').format(m));
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.p24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Collected Revenue Trend (Past 6 Months)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            AppSizes.h24,
            SizedBox(
              height: 240,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) => const FlLine(
                      color: AppColors.border,
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx >= 0 && idx < labels.length) {
                            return SideTitleWidget(
                              axisSide: meta.axisSide,
                              child: Text(
                                labels[idx],
                                style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 11),
                              ),
                            );
                          }
                          return Container();
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 60,
                        getTitlesWidget: (value, meta) {
                          return SideTitleWidget(
                            axisSide: meta.axisSide,
                            child: Text(
                              'Rs. ${NumberFormat.compact().format(value)}',
                              style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 10),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: AppColors.primary,
                      barWidth: 3.5,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary.withOpacity(0.25),
                            AppColors.primary.withOpacity(0.0),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentPatientsList(BuildContext context, List<PatientModel> patients) {
    final formatter = DateFormat('dd MMM yyyy');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.p20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent Registered Patients',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                TextButton(
                  onPressed: () => context.go('/patients'),
                  child: const Text('View Registry'),
                ),
              ],
            ),
            AppSizes.h12,
            const Divider(),
            AppSizes.h8,
            patients.isEmpty
                ? const SizedBox(
                    height: 150,
                    child: Center(child: Text('No patient records found.')),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: patients.length,
                    itemBuilder: (context, index) {
                      final p = patients[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primaryLight,
                          child: Text(
                            p.fullName.substring(0, 1).toUpperCase(),
                            style: const TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(
                          p.fullName,
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 13),
                        ),
                        subtitle: Text(
                          p.medicalCondition,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11),
                        ),
                        trailing: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              formatter.format(p.registrationDate),
                              style: const TextStyle(color: AppColors.textLight, fontSize: 10),
                            ),
                            AppSizes.h4,
                            const Icon(Icons.arrow_forward_ios_rounded, size: 10, color: AppColors.textSecondary),
                          ],
                        ),
                        onTap: () => context.go('/patients/${p.patientId}'),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentSessionsList(
    BuildContext context,
    List<SessionModel> sessions,
    List<PatientModel> patients,
  ) {
    final formatter = DateFormat('dd MMM, hh:mm a');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.p20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent Session Activity',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                TextButton(
                  onPressed: () => context.go('/sessions'),
                  child: const Text('View History'),
                ),
              ],
            ),
            AppSizes.h12,
            const Divider(),
            AppSizes.h8,
            sessions.isEmpty
                ? const SizedBox(
                    height: 150,
                    child: Center(child: Text('No session logs recorded.')),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: sessions.length,
                    itemBuilder: (context, index) {
                      final s = sessions[index];
                      final patient = patients.firstWhere(
                        (p) => p.patientId == s.patientId,
                        orElse: () => null as dynamic,
                      );

                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          padding: const EdgeInsets.all(AppSizes.p8),
                          decoration: BoxDecoration(
                            color: (s.paymentStatus ? AppColors.success : AppColors.error).withOpacity(0.08),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            s.paymentStatus ? Icons.check_rounded : Icons.pending_rounded,
                            color: s.paymentStatus ? AppColors.success : AppColors.error,
                            size: 16,
                          ),
                        ),
                        title: Text(
                          patient.fullName ?? 'Unknown Patient',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 13),
                        ),
                        subtitle: Text(
                          s.treatmentNotes,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11),
                        ),
                        trailing: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              formatter.format(s.sessionDate),
                              style: const TextStyle(color: AppColors.textLight, fontSize: 10),
                            ),
                            AppSizes.h4,
                            Text(
                              'Rs. ${NumberFormat('#,##0').format(s.charges)}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.textPrimary),
                            ),
                          ],
                        ),
                        onTap: () {
                          context.go('/patients/${patient.patientId}');
                                                },
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }
}
