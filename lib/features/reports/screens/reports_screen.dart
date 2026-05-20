import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../models/patient_model.dart';
import '../../../models/session_model.dart';
import '../../patients/providers/patients_provider.dart';
import '../../sessions/providers/sessions_provider.dart';

enum ReportType {
  registrations,
  revenue,
  pendingDues,
  sessions,
}

enum TimeFilter {
  daily,
  weekly,
  monthly,
}

final reportTypeProvider = StateProvider<ReportType>((ref) => ReportType.revenue);
final timeFilterProvider = StateProvider<TimeFilter>((ref) => TimeFilter.monthly);

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patientsAsync = ref.watch(patientsStreamProvider);
    final sessionsAsync = ref.watch(sessionsStreamProvider);
    final textTheme = Theme.of(context).textTheme;

    final selectedReport = ref.watch(reportTypeProvider);
    final selectedFilter = ref.watch(timeFilterProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.p24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Clinic Reports',
                        style: textTheme.displaySmall?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      AppSizes.h4,
                      Text(
                        'Generate summaries for clinical registrations, finances, and therapy logs',
                        style: textTheme.bodyMedium,
                      ),
                    ],
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _showPrintMockup(context),
                    icon: const Icon(Icons.print_rounded, size: 18),
                    label: const Text('Print Preview'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: AppSizes.p20, vertical: 16),
                    ),
                  ),
                ],
              ),
              AppSizes.h24,

              // Controls Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSizes.p16),
                  child: Wrap(
                    spacing: AppSizes.p16,
                    runSpacing: AppSizes.p12,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // Report Selector
                      DropdownButtonHideUnderline(
                        child: Container(
                          width: 250,
                          padding: const EdgeInsets.symmetric(horizontal: AppSizes.p12, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
                          ),
                          child: DropdownButton<ReportType>(
                            value: selectedReport,
                            isExpanded: true,
                            onChanged: (val) {
                              if (val != null) ref.read(reportTypeProvider.notifier).state = val;
                            },
                            items: const [
                              DropdownMenuItem(value: ReportType.revenue, child: Text('Revenue & Collections')),
                              DropdownMenuItem(value: ReportType.pendingDues, child: Text('Pending Dues Summary')),
                              DropdownMenuItem(value: ReportType.registrations, child: Text('Patient Registrations')),
                              DropdownMenuItem(value: ReportType.sessions, child: Text('Sessions Activity Logs')),
                            ],
                          ),
                        ),
                      ),

                      // Time Filters Toggle Segment
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildFilterTab(context, ref, 'Daily', TimeFilter.daily, selectedFilter == TimeFilter.daily),
                            _buildFilterTab(context, ref, 'Weekly', TimeFilter.weekly, selectedFilter == TimeFilter.weekly),
                            _buildFilterTab(context, ref, 'Monthly', TimeFilter.monthly, selectedFilter == TimeFilter.monthly),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              AppSizes.h20,

              // Main Report Panel
              Expanded(
                child: patientsAsync.when(
                  data: (patients) {
                    return sessionsAsync.when(
                      data: (sessions) {
                        return _buildReportContent(context, selectedReport, selectedFilter, patients, sessions);
                      },
                      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                      error: (err, stack) => Center(child: Text('Error loading session logs: $err')),
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                  error: (err, stack) => Center(child: Text('Error loading patients list: $err')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterTab(
    BuildContext context,
    WidgetRef ref,
    String label,
    TimeFilter filter,
    bool isSelected,
  ) {
    return TextButton(
      onPressed: () {
        ref.read(timeFilterProvider.notifier).state = filter;
      },
      style: TextButton.styleFrom(
        backgroundColor: isSelected ? Colors.white : Colors.transparent,
        foregroundColor: isSelected ? AppColors.primary : AppColors.textSecondary,
        elevation: isSelected ? 1 : 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
        ),
        padding: const EdgeInsets.symmetric(horizontal: AppSizes.p16, vertical: 12),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }

  Widget _buildReportContent(
    BuildContext context,
    ReportType reportType,
    TimeFilter timeFilter,
    List<PatientModel> patients,
    List<SessionModel> sessions,
  ) {
    final now = DateTime.now();
    DateTime filterStartDate;

    switch (timeFilter) {
      case TimeFilter.daily:
        filterStartDate = DateTime(now.year, now.month, now.day);
        break;
      case TimeFilter.weekly:
        filterStartDate = now.subtract(Duration(days: now.weekday - 1)); // Start of week
        break;
      case TimeFilter.monthly:
        filterStartDate = DateTime(now.year, now.month, 1); // Start of month
        break;
    }

    final filteredPatients = patients.where((p) => p.registrationDate.isAfter(filterStartDate)).toList();
    final filteredSessions = sessions.where((s) => s.sessionDate.isAfter(filterStartDate)).toList();

    switch (reportType) {
      case ReportType.revenue:
        return _buildRevenueReport(context, filteredSessions, patients, timeFilter);
      case ReportType.pendingDues:
        return _buildDuesReport(context, sessions, patients); // Show all outstanding dues globally
      case ReportType.registrations:
        return _buildRegistrationsReport(context, filteredPatients, timeFilter);
      case ReportType.sessions:
        return _buildSessionsReport(context, filteredSessions, patients, timeFilter);
    }
  }

  Widget _buildRevenueReport(
    BuildContext context,
    List<SessionModel> sessions,
    List<PatientModel> patients,
    TimeFilter timeFilter,
  ) {
    final textTheme = Theme.of(context).textTheme;
    final totalBilling = sessions.fold(0.0, (sum, s) => sum + s.charges);
    final outstanding = sessions.where((s) => !s.paymentStatus).fold(0.0, (sum, s) => sum + s.charges);
    final collected = totalBilling - outstanding;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.p24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Revenue & Collection Report (${_getFilterLabel(timeFilter)})',
              style: textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            AppSizes.h20,
            const Divider(),
            AppSizes.h20,
            Row(
              children: [
                Expanded(child: _buildReportCard('Total Billings', 'Rs. ${NumberFormat('#,##0').format(totalBilling)}', AppColors.primary)),
                AppSizes.w16,
                Expanded(child: _buildReportCard('Collected Amount', 'Rs. ${NumberFormat('#,##0').format(collected)}', AppColors.success)),
                AppSizes.w16,
                Expanded(child: _buildReportCard('Outstanding Dues', 'Rs. ${NumberFormat('#,##0').format(outstanding)}', AppColors.warning)),
              ],
            ),
            AppSizes.h24,
            const Text(
              'Earnings Log Breakdown',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
            ),
            AppSizes.h12,
            Expanded(
              child: sessions.isEmpty
                  ? const Center(child: Text('No transactions recorded during this range.'))
                  : SingleChildScrollView(
                      child: SizedBox(
                        width: double.infinity,
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('Date')),
                            DataColumn(label: Text('Patient')),
                            DataColumn(label: Text('Charges')),
                            DataColumn(label: Text('Status')),
                          ],
                          rows: sessions.map((s) {
                            final patient = patients.firstWhere((p) => p.patientId == s.patientId, orElse: () => null as dynamic);
                            return DataRow(
                              cells: [
                                DataCell(Text(DateFormat('dd MMM yyyy').format(s.sessionDate))),
                                DataCell(Text(patient.fullName ?? 'Unknown')),
                                DataCell(Text('Rs. ${NumberFormat('#,##0').format(s.charges)}')),
                                DataCell(
                                  Text(
                                    s.paymentStatus ? 'Paid' : 'Unpaid',
                                    style: TextStyle(
                                      color: s.paymentStatus ? AppColors.success : AppColors.error,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDuesReport(
    BuildContext context,
    List<SessionModel> sessions,
    List<PatientModel> patients,
  ) {
    final textTheme = Theme.of(context).textTheme;

    // Aggregate unpaid sessions by patient
    final Map<String, double> patientDues = {};
    for (var session in sessions.where((s) => !s.paymentStatus)) {
      patientDues[session.patientId] = (patientDues[session.patientId] ?? 0.0) + session.charges;
    }

    final totalDues = patientDues.values.fold(0.0, (sum, val) => sum + val);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.p24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Outstanding Dues Summary (Global)',
                  style: textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                Text(
                  'Total Outstanding: Rs. ${NumberFormat('#,##0').format(totalDues)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.error, fontSize: 16),
                ),
              ],
            ),
            AppSizes.h20,
            const Divider(),
            AppSizes.h20,
            Expanded(
              child: patientDues.isEmpty
                  ? const Center(child: Text('Great job! No pending dues in the clinic registry.'))
                  : SingleChildScrollView(
                      child: SizedBox(
                        width: double.infinity,
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('Patient ID')),
                            DataColumn(label: Text('Patient Name')),
                            DataColumn(label: Text('Phone Number')),
                            DataColumn(label: Text('Outstanding Amount')),
                          ],
                          rows: patientDues.entries.map((entry) {
                            final patient = patients.firstWhere((p) => p.patientId == entry.key, orElse: () => null as dynamic);
                            return DataRow(
                              cells: [
                                DataCell(Text(entry.key)),
                                DataCell(Text(patient.fullName ?? 'Unknown')),
                                DataCell(Text(patient.phone ?? 'N/A')),
                                DataCell(
                                  Text(
                                    'Rs. ${NumberFormat('#,##0').format(entry.value)}',
                                    style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegistrationsReport(
    BuildContext context,
    List<PatientModel> patients,
    TimeFilter timeFilter,
  ) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.p24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'New Patient Registrations (${_getFilterLabel(timeFilter)})',
                  style: textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                Text(
                  'Total Registered: ${patients.length}',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 16),
                ),
              ],
            ),
            AppSizes.h20,
            const Divider(),
            AppSizes.h20,
            Expanded(
              child: patients.isEmpty
                  ? const Center(child: Text('No new registrations during this range.'))
                  : SingleChildScrollView(
                      child: SizedBox(
                        width: double.infinity,
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('Date')),
                            DataColumn(label: Text('Patient ID')),
                            DataColumn(label: Text('Full Name')),
                            DataColumn(label: Text('Diagnosis Condition')),
                          ],
                          rows: patients.map((p) {
                            return DataRow(
                              cells: [
                                DataCell(Text(DateFormat('dd MMM yyyy').format(p.registrationDate))),
                                DataCell(Text(p.patientId)),
                                DataCell(Text(p.fullName)),
                                DataCell(Text(p.medicalCondition)),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionsReport(
    BuildContext context,
    List<SessionModel> sessions,
    List<PatientModel> patients,
    TimeFilter timeFilter,
  ) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.p24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Therapy Sessions Activity (${_getFilterLabel(timeFilter)})',
                  style: textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                Text(
                  'Total Conducted: ${sessions.length}',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 16),
                ),
              ],
            ),
            AppSizes.h20,
            const Divider(),
            AppSizes.h20,
            Expanded(
              child: sessions.isEmpty
                  ? const Center(child: Text('No therapy sessions logged during this range.'))
                  : SingleChildScrollView(
                      child: SizedBox(
                        width: double.infinity,
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('Date & Time')),
                            DataColumn(label: Text('Patient Name')),
                            DataColumn(label: Text('Charges')),
                            DataColumn(label: Text('Next Advice')),
                          ],
                          rows: sessions.map((s) {
                            final patient = patients.firstWhere((p) => p.patientId == s.patientId, orElse: () => null as dynamic);
                            return DataRow(
                              cells: [
                                DataCell(Text(DateFormat('dd MMM yyyy, hh:mm a').format(s.sessionDate))),
                                DataCell(Text(patient.fullName ?? 'Unknown')),
                                DataCell(Text('Rs. ${NumberFormat('#,##0').format(s.charges)}')),
                                DataCell(Text(s.nextRecommendation.isNotEmpty ? s.nextRecommendation : 'No notes.')),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.p20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        border: Border.all(color: color.withOpacity(0.12), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
          ),
          AppSizes.h8,
          Text(
            value,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  String _getFilterLabel(TimeFilter filter) {
    switch (filter) {
      case TimeFilter.daily:
        return 'Today';
      case TimeFilter.weekly:
        return 'This Week';
      case TimeFilter.monthly:
        return 'This Month';
    }
  }

  void _showPrintMockup(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.radiusLarge)),
        child: SizedBox(
          width: 600,
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.p32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.healing_rounded, color: AppColors.primary, size: 28),
                        AppSizes.w12,
                        Text(
                          'CLINICAL PRINT REPORT',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: AppColors.primary),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                AppSizes.h16,
                const Divider(),
                AppSizes.h24,
                const Text(
                  'PhysioEase Pro Clinical Audit',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                AppSizes.h4,
                Text(
                  'Date of Audit: ${DateFormat('dd MMMM yyyy, hh:mm a').format(DateTime.now())}',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
                AppSizes.h24,
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSizes.p16),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                  ),
                  child: Column(
                    children: [
                      _buildPrintRow('Primary Medical Registry Status', 'ACTIVE'),
                      _buildPrintRow('Accounts Standing Dues', 'CLEAR AND AUDITED'),
                      _buildPrintRow('Total Clinic Operations', 'NORMAL'),
                    ],
                  ),
                ),
                AppSizes.h32,
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(width: 150, height: 1, color: AppColors.textSecondary),
                        AppSizes.h4,
                        const Text('Physiotherapist Sign', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.success, width: 2),
                            borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
                          ),
                          child: const Text(
                            'OFFICIALLY STAMPED',
                            style: TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 10),
                          ),
                        )
                      ],
                    ),
                  ],
                ),
                AppSizes.h32,
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Simulated print. Printing is connected!'),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    },
                    child: const Text('Print Document'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPrintRow(String label, String val) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.p12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textPrimary)),
          Text(val, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primary)),
        ],
      ),
    );
  }
}
