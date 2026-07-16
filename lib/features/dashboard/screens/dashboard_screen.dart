import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../models/patient_model.dart';
import '../../../models/session_model.dart';
import '../../../models/massage_chair_bill_model.dart';
import '../../patients/providers/patients_provider.dart';
import '../../sessions/providers/sessions_provider.dart';
import '../../billing/providers/massage_chair_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../models/user_model.dart';
import '../../staff/providers/staff_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patientsAsync = ref.watch(patientsStreamProvider);
    final sessionsAsync = ref.watch(sessionsStreamProvider);
    final authState = ref.watch(authProvider);
    final isAdmin = authState.role == 'Admin';
    final massageChairBillsAsync = isAdmin ? ref.watch(massageChairBillsStreamProvider) : null;
    final staffAsync = isAdmin ? ref.watch(staffProvider) : null;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSizes.p24),
          child: patientsAsync.when(
            data: (patients) {
              return sessionsAsync.when(
                data: (sessions) {
                  if (isAdmin && massageChairBillsAsync != null && staffAsync != null) {
                    return massageChairBillsAsync.when(
                      data: (massageChairBills) {
                        return staffAsync.when(
                          data: (staff) {
                            return _buildDashboardContent(context, ref, patients, sessions, massageChairBills, staff, isAdmin);
                          },
                          loading: () => const Center(
                            child: Padding(
                              padding: EdgeInsets.only(top: 100.0),
                              child: CircularProgressIndicator(color: AppColors.primary),
                            ),
                          ),
                          error: (e, s) => Center(child: Text('Error loading staff: $e')),
                        );
                      },
                      loading: () => const Center(
                        child: Padding(
                          padding: EdgeInsets.only(top: 100.0),
                          child: CircularProgressIndicator(color: AppColors.primary),
                        ),
                      ),
                      error: (e, s) => Center(child: Text('Error loading massage chair bills: $e')),
                    );
                  } else {
                    return _buildDashboardContent(context, ref, patients, sessions, [], [], isAdmin);
                  }
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
    List<MassageChairBillModel> massageChairBills,
    List<UserModel> staff,
    bool isAdmin,
  ) {
    final textTheme = Theme.of(context).textTheme;
    final authState = ref.watch(authProvider);

    // Calculations
    final int totalPatients = patients.length;
    final int totalSessions = sessions.length;
    final double totalRevenue = sessions.fold(0.0, (sum, s) => sum + s.charges);
    final double pendingDues = sessions.where((s) => !s.paymentStatus).fold(0.0, (sum, s) => sum + s.charges);
    final double totalEarnings = totalRevenue - pendingDues;

    // Consultation calculations
    final double consultationRevenue = patients
        .where((p) => p.consultationPaymentStatus ?? false)
        .fold(0.0, (sum, p) => sum + (p.consultationFee ?? 0.0));
    final double consultationPending = patients
        .where((p) => !(p.consultationPaymentStatus ?? false))
        .fold(0.0, (sum, p) => sum + (p.consultationFee ?? 0.0));
    final double combinedPendingDues = pendingDues + (isAdmin ? consultationPending : 0.0);

    // Massage chair calculations (admin only)
    final double massageChairRevenue = massageChairBills.where((b) => b.paymentStatus).fold(0.0, (sum, b) => sum + b.fee);
    final double combinedEarnings = totalEarnings + massageChairRevenue + consultationRevenue;

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
            } else if (width < 1200) {
              crossAxisCount = 3;
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
                  title: 'Therapy Revenue',
                  value: 'Rs. ${NumberFormat('#,##0').format(totalEarnings)}',
                  subtitle: 'Collected therapy fees',
                  icon: Icons.check_circle_rounded,
                  color: AppColors.success,
                  gradient: null,
                ),
                if (isAdmin) ...[
                  _buildStatCard(
                    title: 'Massage Chair Revenue',
                    value: 'Rs. ${NumberFormat('#,##0').format(massageChairRevenue)}',
                    subtitle: 'Chair sessions collected',
                    icon: Icons.chair_rounded,
                    color: const Color(0xFFE65100),
                    gradient: null,
                  ),
                  _buildStatCard(
                    title: 'Consultation Revenue',
                    value: 'Rs. ${NumberFormat('#,##0').format(consultationRevenue)}',
                    subtitle: 'Consultation fees collected',
                    icon: Icons.payment_rounded,
                    color: Colors.purple,
                    gradient: null,
                  ),
                  _buildStatCard(
                    title: 'Total Revenue',
                    value: 'Rs. ${NumberFormat('#,##0').format(combinedEarnings)}',
                    subtitle: 'Therapy + Chair + Consult',
                    icon: Icons.monetization_on_rounded,
                    color: AppColors.primary,
                    gradient: AppColors.dashboardCardGradient,
                  ),
                ],
                _buildStatCard(
                  title: 'Pending Dues',
                  value: 'Rs. ${NumberFormat('#,##0').format(combinedPendingDues)}',
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

        if (!isAdmin) ...[
          Builder(
            builder: (context) {
              final currentUser = authState.userModel;
              final double percentage = currentUser?.revenuePercentage ?? 0.0;
              final double totalTherapyRevenue = sessions.fold(0.0, (sum, s) => sum + s.charges);
              final double calculatedSalary = totalTherapyRevenue * (percentage / 100);
              final int sessionsCompleted = sessions.length;
              final now = DateTime.now();
              final currentMonthSessions = sessions.where((s) => s.sessionDate.year == now.year && s.sessionDate.month == now.month);
              final double currentMonthRevenue = currentMonthSessions.fold(0.0, (sum, s) => sum + s.charges);
              final double currentMonthSalary = currentMonthRevenue * (percentage / 100);
              final double totalPaidRevenue = sessions.where((s) => s.paymentStatus).fold(0.0, (sum, s) => sum + s.charges);
              final double totalEarned = totalPaidRevenue * (percentage / 100);

              return _buildTherapistSalaryCard(
                context,
                percentage,
                totalTherapyRevenue,
                calculatedSalary,
                sessionsCompleted,
                currentMonthSalary,
                totalEarned,
              );
            },
          ),
          AppSizes.h24,
        ],

        // 2. Revenue Graph Block
        _buildRevenueGraphCard(context, patients, sessions, massageChairBills, isAdmin),
        AppSizes.h24,

        if (isAdmin) ...[
          _buildAdminStaffSalariesCard(context, staff, sessions),
          AppSizes.h24,
        ],

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

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildRevenueGraphCard(
    BuildContext context,
    List<PatientModel> patients,
    List<SessionModel> sessions,
    List<MassageChairBillModel> massageChairBills,
    bool isAdmin,
  ) {
    // Generate monthly earnings details for the past 6 months
    final now = DateTime.now();
    final List<DateTime> months = List.generate(6, (i) => DateTime(now.year, now.month - i, 1));
    months.sort((a, b) => a.compareTo(b)); // Order chronologically

    final List<FlSpot> therapySpots = [];
    final List<FlSpot> massageChairSpots = [];
    final List<FlSpot> consultationSpots = [];
    final List<String> labels = [];

    for (int i = 0; i < months.length; i++) {
      final m = months[i];
      final monthSessions = sessions.where((s) => s.sessionDate.year == m.year && s.sessionDate.month == m.month);
      // Collect only paid revenue to draw clean graphical data points
      final double paidRevenue = monthSessions.where((s) => s.paymentStatus).fold(0.0, (sum, s) => sum + s.charges);
      
      final double mcPaidRevenue = isAdmin
          ? massageChairBills
              .where((b) => b.sessionDate.year == m.year && b.sessionDate.month == m.month && b.paymentStatus)
              .fold(0.0, (sum, b) => sum + b.fee)
          : 0.0;

      final double consultationPaidRevenue = isAdmin
          ? patients
              .where((p) =>
                  p.consultationPaymentStatus == true &&
                  p.consultationPaymentDate != null &&
                  p.consultationPaymentDate!.year == m.year &&
                  p.consultationPaymentDate!.month == m.month)
              .fold(0.0, (sum, p) => sum + (p.consultationFee ?? 0.0))
          : 0.0;

      therapySpots.add(FlSpot(i.toDouble(), paidRevenue));
      if (isAdmin) {
        massageChairSpots.add(FlSpot(i.toDouble(), mcPaidRevenue));
        consultationSpots.add(FlSpot(i.toDouble(), consultationPaidRevenue));
      }
      labels.add(DateFormat('MMM').format(m));
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.p24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Collected Revenue Trend (Past 6 Months)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                if (isAdmin)
                  Row(
                    children: [
                      _buildLegendItem('Therapy', AppColors.primary),
                      AppSizes.w16,
                      _buildLegendItem('Massage Chair', const Color(0xFFE65100)),
                      AppSizes.w16,
                      _buildLegendItem('Consultation', const Color(0xFF8E24AA)),
                    ],
                  ),
              ],
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
                        interval: 1,
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
                      spots: therapySpots,
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
                    if (isAdmin) ...[
                      LineChartBarData(
                        spots: massageChairSpots,
                        isCurved: true,
                        color: const Color(0xFFE65100),
                        barWidth: 3.5,
                        isStrokeCapRound: true,
                        dotData: const FlDotData(show: true),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFFE65100).withOpacity(0.25),
                              const Color(0xFFE65100).withOpacity(0.0),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                      LineChartBarData(
                        spots: consultationSpots,
                        isCurved: true,
                        color: const Color(0xFF8E24AA),
                        barWidth: 3.5,
                        isStrokeCapRound: true,
                        dotData: const FlDotData(show: true),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF8E24AA).withOpacity(0.25),
                              const Color(0xFF8E24AA).withOpacity(0.0),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ],
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
                        orElse: () => PatientModel(
                          patientId: '',
                          fullName: 'Unknown Patient',
                          phone: '',
                          age: 0,
                          gender: '',
                          address: '',
                          medicalCondition: '',
                          notes: '',
                          registrationDate: DateTime.now(),
                        ),
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
                          patient.fullName,
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

  Widget _buildTherapistSalaryCard(
    BuildContext context,
    double percentage,
    double totalRevenue,
    double calculatedSalary,
    int sessionsCompleted,
    double currentMonthSalary,
    double totalEarned,
  ) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.p24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSizes.p8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.payments_rounded, color: AppColors.primary, size: 24),
                ),
                AppSizes.w12,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'My Salary & Earnings Summary',
                        style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      Text(
                        'Real-time calculation based on your therapy session revenue and assigned percentage',
                        style: textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSizes.p16),
              child: Divider(),
            ),
            Wrap(
              spacing: AppSizes.p24,
              runSpacing: AppSizes.p24,
              children: [
                _buildSalaryMetricTile(
                  context,
                  title: 'Assigned Percentage',
                  value: '${percentage.toStringAsFixed(0)}%',
                  subtitle: 'Of therapy session revenue',
                  icon: Icons.percent_rounded,
                  iconColor: AppColors.secondary,
                ),
                _buildSalaryMetricTile(
                  context,
                  title: 'Total Therapy Revenue',
                  value: 'Rs. ${NumberFormat('#,##0').format(totalRevenue)}',
                  subtitle: 'Generated from $sessionsCompleted sessions',
                  icon: Icons.trending_up_rounded,
                  iconColor: AppColors.primary,
                ),
                _buildSalaryMetricTile(
                  context,
                  title: 'Calculated Salary',
                  value: 'Rs. ${NumberFormat('#,##0').format(calculatedSalary)}',
                  subtitle: 'Overall calculated share',
                  icon: Icons.account_balance_rounded,
                  iconColor: AppColors.success,
                ),
                _buildSalaryMetricTile(
                  context,
                  title: 'Current Month Salary',
                  value: 'Rs. ${NumberFormat('#,##0').format(currentMonthSalary)}',
                  subtitle: DateFormat('MMMM yyyy').format(DateTime.now()),
                  icon: Icons.calendar_month_rounded,
                  iconColor: Colors.purple,
                ),
                _buildSalaryMetricTile(
                  context,
                  title: 'Total Earned',
                  value: 'Rs. ${NumberFormat('#,##0').format(totalEarned)}',
                  subtitle: 'From paid sessions only',
                  icon: Icons.check_circle_rounded,
                  iconColor: AppColors.success,
                  isHighlighted: true,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSalaryMetricTile(
    BuildContext context, {
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    bool isHighlighted = false,
  }) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      width: 220,
      padding: const EdgeInsets.all(AppSizes.p16),
      decoration: BoxDecoration(
        color: isHighlighted ? AppColors.success.withOpacity(0.05) : AppColors.background,
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        border: Border.all(
          color: isHighlighted ? AppColors.success.withOpacity(0.2) : AppColors.border,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 20),
              AppSizes.w8,
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          AppSizes.h12,
          Text(
            value,
            style: textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: isHighlighted ? AppColors.success : AppColors.textPrimary,
              fontSize: 18,
            ),
          ),
          AppSizes.h4,
          Text(
            subtitle,
            style: const TextStyle(fontSize: 10, color: AppColors.textLight, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminStaffSalariesCard(
    BuildContext context,
    List<UserModel> staff,
    List<SessionModel> sessions,
  ) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.p24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSizes.p8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.people_alt_rounded, color: AppColors.primary, size: 24),
                ),
                AppSizes.w12,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Staff Salary & Performance Summary',
                        style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      Text(
                        'Overall therapist sessions and revenue generated with calculated salary shares',
                        style: textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSizes.p16),
              child: Divider(),
            ),
            staff.isEmpty
                ? const SizedBox(
                    height: 120,
                    child: Center(
                      child: Text('No staff members registered yet.', style: TextStyle(color: AppColors.textSecondary)),
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minWidth: constraints.maxWidth,
                          ),
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.all(AppColors.primaryLight.withOpacity(0.4)),
                            columns: const [
                              DataColumn(label: Text('Staff Member', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Role', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Revenue %', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Sessions Conducted', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Total Revenue Generated', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Calculated Salary', style: TextStyle(fontWeight: FontWeight.bold))),
                            ],
                            rows: staff.map((therapist) {
                              final therapistSessions = sessions.where((s) => s.therapistId == therapist.userId);
                              final double revenueGenerated = therapistSessions.fold(0.0, (sum, s) => sum + s.charges);
                              final int count = therapistSessions.length;
                              final double calculatedSalary = revenueGenerated * (therapist.revenuePercentage / 100);

                              return DataRow(
                                cells: [
                                  DataCell(
                                    Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(therapist.fullName, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                                        Text(therapist.email, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                                      ],
                                    ),
                                  ),
                                  DataCell(Text(therapist.role)),
                                  DataCell(Text('${therapist.revenuePercentage.toStringAsFixed(0)}%')),
                                  DataCell(Text('$count')),
                                  DataCell(Text('Rs. ${NumberFormat('#,##0').format(revenueGenerated)}')),
                                  DataCell(
                                    Text(
                                      'Rs. ${NumberFormat('#,##0').format(calculatedSalary)}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.success),
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }
}
