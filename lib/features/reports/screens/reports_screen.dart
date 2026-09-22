import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:docx_creator/docx_creator.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:js_interop';
import 'package:web/web.dart' as web;
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../models/patient_model.dart';
import '../../../models/session_model.dart';
import '../../../models/massage_chair_bill_model.dart';
import '../../../models/user_model.dart';
import '../../patients/providers/patients_provider.dart';
import '../../sessions/providers/sessions_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../billing/providers/massage_chair_provider.dart';
import '../../staff/providers/staff_provider.dart';

enum ReportType {
  registrations,
  revenue,
  pendingDues,
  sessions,
  staffSalary,
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
    final authState = ref.watch(authProvider);
    final isAdmin = authState.role == 'Admin';
    final massageChairBillsAsync = isAdmin ? ref.watch(massageChairBillsStreamProvider) : null;
    final staffAsync = isAdmin ? ref.watch(staffProvider) : null;
    final textTheme = Theme.of(context).textTheme;

    final selectedReport = ref.watch(reportTypeProvider);
    final selectedFilter = ref.watch(timeFilterProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
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
                    onPressed: () {
                      final patients = patientsAsync.valueOrNull ?? <PatientModel>[];
                      final sessions = sessionsAsync.valueOrNull ?? <SessionModel>[];
                      final mcBills = massageChairBillsAsync?.valueOrNull ?? <MassageChairBillModel>[];
                      final staff = staffAsync?.valueOrNull ?? <UserModel>[];
                      _showPrintPreviewDialog(
                        context,
                        selectedReport,
                        selectedFilter,
                        patients,
                        sessions,
                        mcBills,
                        staff,
                        isAdmin,
                      );
                    },
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
                            items: [
                              const DropdownMenuItem(value: ReportType.revenue, child: Text('Revenue & Collections')),
                              const DropdownMenuItem(value: ReportType.pendingDues, child: Text('Pending Dues Summary')),
                              const DropdownMenuItem(value: ReportType.registrations, child: Text('Patient Registrations')),
                              const DropdownMenuItem(value: ReportType.sessions, child: Text('Sessions Activity Logs')),
                              if (isAdmin)
                                const DropdownMenuItem(value: ReportType.staffSalary, child: Text('Staff Salary Reports')),
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
              patientsAsync.when(
                data: (patients) {
                  return sessionsAsync.when(
                    data: (sessions) {
                      final massageChairBills = isAdmin 
                          ? (massageChairBillsAsync?.valueOrNull ?? <MassageChairBillModel>[]) 
                          : <MassageChairBillModel>[];
                      
                      if (isAdmin && staffAsync != null) {
                        return staffAsync.when(
                          data: (staff) {
                            return _buildReportContent(context, selectedReport, selectedFilter, patients, sessions, massageChairBills, staff, isAdmin);
                          },
                          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                          error: (err, stack) => Center(child: Text('Error loading staff list: $err')),
                        );
                      } else {
                        return _buildReportContent(context, selectedReport, selectedFilter, patients, sessions, massageChairBills, [], isAdmin);
                      }
                    },
                    loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                    error: (err, stack) => Center(child: Text('Error loading session logs: $err')),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                error: (err, stack) => Center(child: Text('Error loading patients list: $err')),
              ),
            ],
            ),
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
    List<MassageChairBillModel> massageChairBills,
    List<UserModel> staff,
    bool isAdmin,
  ) {
    final now = DateTime.now();
    DateTime filterStartDate;

    switch (timeFilter) {
      case TimeFilter.daily:
        filterStartDate = DateTime(now.year, now.month, now.day);
        break;
      case TimeFilter.weekly:
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        filterStartDate = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
        break;
      case TimeFilter.monthly:
        filterStartDate = DateTime(now.year, now.month, 1); // Start of month
        break;
    }

    final filteredPatients = patients.where((p) => p.registrationDate.isAfter(filterStartDate)).toList();
    final filteredSessions = sessions.where((s) => s.sessionDate.isAfter(filterStartDate)).toList();
    final filteredMcBills = massageChairBills.where((b) => b.sessionDate.isAfter(filterStartDate)).toList();

    switch (reportType) {
      case ReportType.revenue:
        return _buildRevenueReport(context, filteredSessions, patients, filteredPatients, timeFilter, filteredMcBills, isAdmin);
      case ReportType.pendingDues:
        return _buildDuesReport(context, sessions, patients, massageChairBills, isAdmin); // Show all outstanding dues globally
      case ReportType.registrations:
        return _buildRegistrationsReport(context, filteredPatients, timeFilter);
      case ReportType.sessions:
        return _buildSessionsReport(context, filteredSessions, patients, timeFilter);
      case ReportType.staffSalary:
        return _buildStaffSalaryReport(context, filteredSessions, staff, timeFilter);
    }
  }

  Widget _buildRevenueReport(
    BuildContext context,
    List<SessionModel> sessions,
    List<PatientModel> patients,
    List<PatientModel> filteredPatients,
    TimeFilter timeFilter,
    List<MassageChairBillModel> massageChairBills,
    bool isAdmin,
  ) {
    final textTheme = Theme.of(context).textTheme;
    final totalBilling = sessions.fold(0.0, (sum, s) => sum + s.charges);
    final outstanding = sessions.where((s) => s.paymentStatus == 'Unpaid').fold(0.0, (sum, s) => sum + s.charges);
    final collected = sessions.where((s) => s.paymentStatus == 'Paid').fold(0.0, (sum, s) => sum + s.charges);

    // Massage chair totals
    final mcTotal = massageChairBills.fold(0.0, (sum, b) => sum + b.fee);
    final mcOutstanding = massageChairBills.where((b) => b.paymentStatus == 'Unpaid').fold(0.0, (sum, b) => sum + b.fee);
    final mcCollected = massageChairBills.where((b) => b.paymentStatus == 'Paid').fold(0.0, (sum, b) => sum + b.fee);

    // Consultation totals (based on filteredPatients)
    final consultationFeePatients = filteredPatients.where((p) => p.consultationPaymentStatus != null || (p.consultationFee != null && p.consultationFee! >= 0));
    final double consultationCollected = consultationFeePatients
        .where((p) => p.consultationPaymentStatus == 'Paid')
        .fold(0.0, (sum, p) => sum + (p.consultationFee ?? 0.0));
    final double consultationOutstanding = consultationFeePatients
        .where((p) => (p.consultationPaymentStatus ?? 'Unpaid') == 'Unpaid')
        .fold(0.0, (sum, p) => sum + (p.consultationFee ?? 0.0));
    final double consultationTotal = consultationCollected + consultationOutstanding;

    // Fee Waiver & Free Patient Statistics
    final int totalPaidPatientsCount = filteredPatients.where((p) =>
      p.consultationPaymentStatus == 'Paid' || sessions.any((s) => s.patientId == p.patientId && s.paymentStatus == 'Paid')
    ).length;

    final int totalUnpaidPatientsCount = filteredPatients.where((p) =>
      p.consultationPaymentStatus == 'Unpaid' || sessions.any((s) => s.patientId == p.patientId && s.paymentStatus == 'Unpaid')
    ).length;

    final int totalFeeWaiverPatientsCount = filteredPatients.where((p) =>
      p.consultationPaymentStatus == 'Fee Waiver' || sessions.any((s) => s.patientId == p.patientId && s.paymentStatus == 'Fee Waiver')
    ).length;

    final int totalFreeConsultationsCount = filteredPatients.where((p) => p.consultationPaymentStatus == 'Fee Waiver').length;
    final int totalFreeTherapySessionsCount = sessions.where((s) => s.paymentStatus == 'Fee Waiver').length;
    final int totalFreeMassageChairVisitsCount = massageChairBills.where((b) => b.paymentStatus == 'Fee Waiver').length;

    // Build unified transactions breakdown rows
    final List<_ReportRowData> reportRows = [];
     
    // Add therapy sessions
    for (final s in sessions) {
      final p = patients.firstWhere(
        (p) => p.patientId == s.patientId,
        orElse: () => PatientModel(
          patientId: '',
          fullName: 'Unknown Patient',
          phone: 'N/A',
          age: 0,
          gender: '',
          address: '',
          medicalCondition: '',
          notes: '',
          registrationDate: DateTime.now(),
        ),
      );
      reportRows.add(_ReportRowData(
        date: s.sessionDate,
        customerName: p.fullName,
        serviceType: 'Therapy',
        amount: s.charges,
        paymentStatus: s.paymentStatus,
      ));
    }

    // Add massage chair sessions
    for (final b in massageChairBills) {
      reportRows.add(_ReportRowData(
        date: b.sessionDate,
        customerName: b.customerName,
        serviceType: 'Massage Chair',
        amount: b.fee,
        paymentStatus: b.paymentStatus,
      ));
    }

    // Add consultation
    for (final p in consultationFeePatients) {
      reportRows.add(_ReportRowData(
        date: p.registrationDate,
        customerName: p.fullName,
        serviceType: 'Consultation',
        amount: p.consultationFee ?? 0.0,
        paymentStatus: p.consultationPaymentStatus ?? 'Unpaid',
      ));
    }

    // Sort descending by date
    reportRows.sort((a, b) => b.date.compareTo(a.date));

    final List<DataRow> rows = reportRows.map((row) {
      Color color;
      Color textBadgeColor;
      if (row.serviceType == 'Massage Chair') {
        color = const Color(0xFFFFF3E0);
        textBadgeColor = const Color(0xFFE65100);
      } else if (row.serviceType == 'Consultation') {
        color = Colors.purple.withValues(alpha: 0.1);
        textBadgeColor = Colors.purple;
      } else {
        color = AppColors.primaryLight;
        textBadgeColor = AppColors.primaryDark;
      }

      return DataRow(
        cells: [
          DataCell(Text(DateFormat('dd MMM yyyy').format(row.date))),
          DataCell(Text(row.customerName)),
          DataCell(
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                row.serviceType,
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: textBadgeColor),
              ),
            ),
          ),
          DataCell(Text('Rs. ${NumberFormat('#,##0').format(row.amount)}')),
          DataCell(
            Text(
              row.paymentStatus,
              style: TextStyle(
                color: row.paymentStatus == 'Paid'
                    ? AppColors.success
                    : row.paymentStatus == 'Fee Waiver'
                        ? Colors.purple
                        : AppColors.error,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      );
    }).toList();

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
              if (isAdmin) ...[
                Row(
                  children: [
                    Expanded(child: _buildReportCard('Therapy Billings', 'Rs. ${NumberFormat('#,##0').format(totalBilling)}', AppColors.primary)),
                    AppSizes.w16,
                    Expanded(child: _buildReportCard('Therapy Collected', 'Rs. ${NumberFormat('#,##0').format(collected)}', AppColors.success)),
                    AppSizes.w16,
                    Expanded(child: _buildReportCard('Therapy Outstanding', 'Rs. ${NumberFormat('#,##0').format(outstanding)}', AppColors.warning)),
                  ],
                ),
                AppSizes.h16,
                Row(
                  children: [
                    Expanded(child: _buildReportCard('Massage Billings', 'Rs. ${NumberFormat('#,##0').format(mcTotal)}', const Color(0xFFE65100))),
                    AppSizes.w16,
                    Expanded(child: _buildReportCard('Massage Collected', 'Rs. ${NumberFormat('#,##0').format(mcCollected)}', AppColors.success)),
                    AppSizes.w16,
                    Expanded(child: _buildReportCard('Massage Outstanding', 'Rs. ${NumberFormat('#,##0').format(mcOutstanding)}', AppColors.warning)),
                  ],
                ),
                AppSizes.h16,
                Row(
                  children: [
                    Expanded(child: _buildReportCard('Consultation Billings', 'Rs. ${NumberFormat('#,##0').format(consultationTotal)}', Colors.purple)),
                    AppSizes.w16,
                    Expanded(child: _buildReportCard('Consultation Collected', 'Rs. ${NumberFormat('#,##0').format(consultationCollected)}', AppColors.success)),
                    AppSizes.w16,
                    Expanded(child: _buildReportCard('Consultation Outstanding', 'Rs. ${NumberFormat('#,##0').format(consultationOutstanding)}', AppColors.warning)),
                  ],
                ),
                AppSizes.h24,
                Text(
                  'Fee Waiver & Free Services Statistics',
                  style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                AppSizes.h12,
                Row(
                  children: [
                    Expanded(child: _buildReportCard('Total Paid Patients', '$totalPaidPatientsCount', AppColors.success)),
                    AppSizes.w16,
                    Expanded(child: _buildReportCard('Total Unpaid Patients', '$totalUnpaidPatientsCount', AppColors.error)),
                    AppSizes.w16,
                    Expanded(child: _buildReportCard('Total Fee Waiver Patients', '$totalFeeWaiverPatientsCount', Colors.purple)),
                  ],
                ),
                AppSizes.h12,
                Row(
                  children: [
                    Expanded(child: _buildReportCard('Total Free Consultations', '$totalFreeConsultationsCount', Colors.purple)),
                    AppSizes.w16,
                    Expanded(child: _buildReportCard('Total Free Therapy Sessions', '$totalFreeTherapySessionsCount', Colors.purple)),
                    AppSizes.w16,
                    Expanded(child: _buildReportCard('Total Free Massage Visits', '$totalFreeMassageChairVisitsCount', Colors.purple)),
                  ],
                ),
              ] else ...[
                Row(
                  children: [
                    Expanded(child: _buildReportCard('Total Billings', 'Rs. ${NumberFormat('#,##0').format(totalBilling)}', AppColors.primary)),
                    AppSizes.w16,
                    Expanded(child: _buildReportCard('Collected Amount', 'Rs. ${NumberFormat('#,##0').format(collected)}', AppColors.success)),
                    AppSizes.w16,
                    Expanded(child: _buildReportCard('Outstanding Dues', 'Rs. ${NumberFormat('#,##0').format(outstanding)}', AppColors.warning)),
                  ],
                ),
              ],
              AppSizes.h24,
              const Text(
                'Earnings Log Breakdown',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
              ),
              AppSizes.h12,
              reportRows.isEmpty
                  ? const Center(child: Text('No transactions recorded during this range.'))
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        return SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(minWidth: constraints.maxWidth),
                            child: DataTable(
                              columns: const [
                                DataColumn(label: Text('Date')),
                                DataColumn(label: Text('Customer')),
                                DataColumn(label: Text('Service')),
                                DataColumn(label: Text('Charges')),
                                DataColumn(label: Text('Status')),
                              ],
                              rows: rows,
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

  Widget _buildDuesReport(
    BuildContext context,
    List<SessionModel> sessions,
    List<PatientModel> patients,
    List<MassageChairBillModel> massageChairBills,
    bool isAdmin,
  ) {
    final textTheme = Theme.of(context).textTheme;

    // Aggregate unpaid sessions by patient
    final Map<String, double> patientDues = {};
    for (var session in sessions.where((s) => s.paymentStatus == 'Unpaid')) {
      patientDues[session.patientId] = (patientDues[session.patientId] ?? 0.0) + session.charges;
    }

    final totalDues = patientDues.values.fold(0.0, (sum, val) => sum + val);

    // Massage chair dues (admin only)
    final Map<String, double> mcDues = {};
    if (isAdmin) {
      for (var bill in massageChairBills.where((b) => b.paymentStatus == 'Unpaid')) {
        mcDues[bill.customerId] = (mcDues[bill.customerId] ?? 0.0) + bill.fee;
      }
    }
    final totalMcDues = mcDues.values.fold(0.0, (sum, val) => sum + val);

    // Consultation dues (admin only)
    final Map<String, double> consultationDues = {};
    if (isAdmin) {
      for (var p in patients.where((p) => p.consultationFee != null && (p.consultationFee ?? 0.0) > 0 && (p.consultationPaymentStatus ?? 'Unpaid') == 'Unpaid')) {
        consultationDues[p.patientId] = (consultationDues[p.patientId] ?? 0.0) + (p.consultationFee ?? 0.0);
      }
    }
    final totalConsultationDues = consultationDues.values.fold(0.0, (sum, val) => sum + val);

    // Build unified dues list
    final List<_DuesRowData> duesRows = [];
    final dummyPatient = PatientModel(
      patientId: '',
      fullName: 'Unknown',
      phone: 'N/A',
      age: 0,
      gender: '',
      address: '',
      medicalCondition: '',
      notes: '',
      registrationDate: DateTime.now(),
    );
     
    // Add therapy dues
    for (final entry in patientDues.entries) {
      final p = patients.firstWhere((p) => p.patientId == entry.key, orElse: () => dummyPatient);
      duesRows.add(_DuesRowData(
        id: entry.key,
        name: p.fullName,
        serviceType: 'Therapy',
        phone: p.phone,
        amount: entry.value,
      ));
    }

    // Add massage chair dues
    for (final entry in mcDues.entries) {
      final p = patients.firstWhere((p) => p.patientId == entry.key, orElse: () => dummyPatient);
      duesRows.add(_DuesRowData(
        id: entry.key,
        name: p.fullName,
        serviceType: 'Massage Chair',
        phone: p.phone,
        amount: entry.value,
      ));
    }

    // Add consultation dues
    for (final entry in consultationDues.entries) {
      final p = patients.firstWhere((p) => p.patientId == entry.key, orElse: () => dummyPatient);
      duesRows.add(_DuesRowData(
        id: entry.key,
        name: p.fullName,
        serviceType: 'Consultation',
        phone: p.phone,
        amount: entry.value,
      ));
    }

    // Sort descending by amount
    duesRows.sort((a, b) => b.amount.compareTo(a.amount));

    final List<DataRow> rows = duesRows.map((row) {
      Color color;
      Color textBadgeColor;
      if (row.serviceType == 'Massage Chair') {
        color = const Color(0xFFFFF3E0);
        textBadgeColor = const Color(0xFFE65100);
      } else if (row.serviceType == 'Consultation') {
        color = Colors.purple.withValues(alpha: 0.1);
        textBadgeColor = Colors.purple;
      } else {
        color = AppColors.primaryLight;
        textBadgeColor = AppColors.primaryDark;
      }

      return DataRow(
        cells: [
          DataCell(Text(row.id)),
          DataCell(Text(row.name)),
          DataCell(
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                row.serviceType,
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: textBadgeColor),
              ),
            ),
          ),
          DataCell(Text(row.phone)),
          DataCell(
            Text(
              'Rs. ${NumberFormat('#,##0').format(row.amount)}',
              style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      );
    }).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.p24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Outstanding Dues Summary (Global)',
                      style: textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Therapy Outstanding: Rs. ${NumberFormat('#,##0').format(totalDues)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.error, fontSize: 14),
                      ),
                      if (isAdmin && totalConsultationDues > 0) ...[
                        AppSizes.h4,
                        Text(
                          'Consultation Outstanding: Rs. ${NumberFormat('#,##0').format(totalConsultationDues)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.purple, fontSize: 14),
                        ),
                      ],
                      if (isAdmin && totalMcDues > 0) ...[
                        AppSizes.h4,
                        Text(
                          'Massage Chair Outstanding: Rs. ${NumberFormat('#,##0').format(totalMcDues)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFE65100), fontSize: 14),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              AppSizes.h20,
              const Divider(),
              AppSizes.h20,
              duesRows.isEmpty
                  ? const Center(child: Text('Great job! No pending dues in the clinic registry.'))
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        return SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(minWidth: constraints.maxWidth),
                            child: DataTable(
                              columns: const [
                                DataColumn(label: Text('ID')),
                                DataColumn(label: Text('Name')),
                                DataColumn(label: Text('Service')),
                                DataColumn(label: Text('Phone')),
                                DataColumn(label: Text('Outstanding')),
                              ],
                              rows: rows,
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
                  Expanded(
                    child: Text(
                      'New Patient Registrations (${_getFilterLabel(timeFilter)})',
                      style: textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
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
              patients.isEmpty
                  ? const Center(child: Text('No new registrations during this range.'))
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        return SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(minWidth: constraints.maxWidth),
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
                        );
                      },
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
                  Expanded(
                    child: Text(
                      'Therapy Sessions Activity (${_getFilterLabel(timeFilter)})',
                      style: textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
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
              sessions.isEmpty
                  ? const Center(child: Text('No therapy sessions logged during this range.'))
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        return SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(minWidth: constraints.maxWidth),
                            child: DataTable(
                              columns: const [
                                DataColumn(label: Text('Date & Time')),
                                DataColumn(label: Text('Patient Name')),
                                DataColumn(label: Text('Charges')),
                                DataColumn(label: Text('Next Advice')),
                              ],
                              rows: sessions.map((s) {
                                final patient = patients.firstWhere(
                                  (p) => p.patientId == s.patientId,
                                  orElse: () => PatientModel(
                                    patientId: '',
                                    fullName: 'Unknown',
                                    phone: 'N/A',
                                    age: 0,
                                    gender: '',
                                    address: '',
                                    medicalCondition: '',
                                    notes: '',
                                    registrationDate: DateTime.now(),
                                  ),
                                );
                                return DataRow(
                                  cells: [
                                    DataCell(Text(DateFormat('dd MMM yyyy, hh:mm a').format(s.sessionDate))),
                                    DataCell(Text(patient.fullName)),
                                    DataCell(Text('Rs. ${NumberFormat('#,##0').format(s.charges)}')),
                                    DataCell(Text(s.nextRecommendation.isNotEmpty ? s.nextRecommendation : 'No notes.')),
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

  Widget _buildReportCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.p20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        border: Border.all(color: color.withValues(alpha: 0.12), width: 1.5),
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

  void _showPrintPreviewDialog(
    BuildContext context,
    ReportType reportType,
    TimeFilter timeFilter,
    List<PatientModel> patients,
    List<SessionModel> sessions,
    List<MassageChairBillModel> massageChairBills,
    List<UserModel> staff,
    bool isAdmin,
  ) {
    showDialog(
      context: context,
      builder: (context) => PrintPreviewDialog(
        reportType: reportType,
        timeFilter: timeFilter,
        patients: patients,
        sessions: sessions,
        massageChairBills: massageChairBills,
        staff: staff,
        isAdmin: isAdmin,
      ),
    );
  }

  Widget _buildStaffSalaryReport(
    BuildContext context,
    List<SessionModel> sessions,
    List<UserModel> staff,
    TimeFilter timeFilter,
  ) {
    final textTheme = Theme.of(context).textTheme;

    // Filter staff members to therapists only
    final therapists = staff.where((s) => s.role == 'Therapist').toList();

    // Summary calculations
    double totalSessionsConducted = 0;
    double totalRevenueGenerated = 0;
    double totalSalaryExpense = 0;

    final List<_StaffSalaryRowData> rowsData = [];
    for (final therapist in therapists) {
      final therapistSessions = sessions.where((s) => s.therapistId == therapist.userId).toList();
      final double revenue = therapistSessions.where((s) => s.paymentStatus == 'Paid').fold(0.0, (sum, s) => sum + s.charges);
      final int count = therapistSessions.length;
      final double salary = revenue * (therapist.revenuePercentage / 100);

      totalSessionsConducted += count;
      totalRevenueGenerated += revenue;
      totalSalaryExpense += salary;

      rowsData.add(_StaffSalaryRowData(
        name: therapist.fullName,
        email: therapist.email,
        percentage: therapist.revenuePercentage,
        sessionsCount: count,
        revenue: revenue,
        salary: salary,
      ));
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
                  Expanded(
                    child: Text(
                      'Staff Salary Report (${_getFilterLabel(timeFilter)})',
                      style: textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                  ),
                  Text(
                    'Total Salary Expense: Rs. ${NumberFormat('#,##0').format(totalSalaryExpense)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 16),
                  ),
                ],
              ),
              AppSizes.h20,
              const Divider(),
              AppSizes.h20,
              therapists.isEmpty
                  ? const Center(child: Text('No therapists registered.'))
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        LayoutBuilder(
                          builder: (context, constraints) {
                            return SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minWidth: constraints.maxWidth,
                                ),
                                child: DataTable(
                                  headingRowColor: WidgetStateProperty.all(AppColors.primaryLight.withValues(alpha: 0.4)),
                                  columns: const [
                                    DataColumn(label: Text('Therapist')),
                                    DataColumn(label: Text('Revenue Percentage')),
                                    DataColumn(label: Text('Sessions Conducted')),
                                    DataColumn(label: Text('Revenue Generated')),
                                    DataColumn(label: Text('Calculated Salary')),
                                  ],
                                  rows: [
                                    ...rowsData.map((row) {
                                      return DataRow(
                                        cells: [
                                          DataCell(
                                            Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(row.name, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                                                Text(row.email, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                                              ],
                                            ),
                                          ),
                                          DataCell(Text('${row.percentage.toStringAsFixed(0)}%')),
                                          DataCell(Text('${row.sessionsCount}')),
                                          DataCell(Text('Rs. ${NumberFormat('#,##0').format(row.revenue)}')),
                                          DataCell(
                                            Text(
                                              'Rs. ${NumberFormat('#,##0').format(row.salary)}',
                                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.success),
                                            ),
                                          ),
                                        ],
                                      );
                                    }),
                                    // Total Sum Row
                                    DataRow(
                                      color: WidgetStateProperty.all(AppColors.background),
                                      cells: [
                                        const DataCell(Text('TOTALS', style: TextStyle(fontWeight: FontWeight.bold))),
                                        const DataCell(Text('-')),
                                        DataCell(Text('${totalSessionsConducted.toInt()}', style: const TextStyle(fontWeight: FontWeight.bold))),
                                        DataCell(Text('Rs. ${NumberFormat('#,##0').format(totalRevenueGenerated)}', style: const TextStyle(fontWeight: FontWeight.bold))),
                                        DataCell(
                                          Text(
                                            'Rs. ${NumberFormat('#,##0').format(totalSalaryExpense)}',
                                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
            ],
          ),
        ),
    );
  }
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

void _downloadFile(Uint8List bytes, String fileName, String mimeType) {
  if (kIsWeb) {
    final blobParts = [bytes.buffer.toJS].toJS;
    final blob = web.Blob(blobParts, web.BlobPropertyBag(type: mimeType));
    final url = web.URL.createObjectURL(blob);
    final anchor = web.document.createElement('a') as web.HTMLAnchorElement
      ..href = url
      ..download = fileName;
    web.document.body!.appendChild(anchor);
    anchor.click();
    web.document.body!.removeChild(anchor);
    web.URL.revokeObjectURL(url);
  }
}

Future<Uint8List> _generatePdfReport(
  ReportType reportType,
  TimeFilter timeFilter,
  List<PatientModel> patients,
  List<SessionModel> sessions,
  List<MassageChairBillModel> massageChairBills,
  List<UserModel> staff,
  bool isAdmin,
) async {
  final pdf = pw.Document();

  final primaryColor = PdfColor.fromHex('#2196F3');
  final primaryDark = PdfColor.fromHex('#1976D2');
  final successColor = PdfColor.fromHex('#4CAF50');
  final errorColor = PdfColor.fromHex('#F44336');
  final textSecondary = PdfColor.fromHex('#757575');
  final bgLight = PdfColor.fromHex('#F5F5F5');

  final now = DateTime.now();
  DateTime filterStartDate;
  switch (timeFilter) {
    case TimeFilter.daily:
      filterStartDate = DateTime(now.year, now.month, now.day);
      break;
    case TimeFilter.weekly:
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      filterStartDate = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
      break;
    case TimeFilter.monthly:
      filterStartDate = DateTime(now.year, now.month, 1);
      break;
  }

  final filteredPatients = patients.where((p) => p.registrationDate.isAfter(filterStartDate)).toList();
  final filteredSessions = sessions.where((s) => s.sessionDate.isAfter(filterStartDate)).toList();
  final filteredMcBills = massageChairBills.where((b) => b.sessionDate.isAfter(filterStartDate)).toList();

  String timeframeText = '';
  switch (timeFilter) {
    case TimeFilter.daily: timeframeText = 'Today'; break;
    case TimeFilter.weekly: timeframeText = 'This Week'; break;
    case TimeFilter.monthly: timeframeText = 'This Month'; break;
  }

  List<pw.Widget> content = [];

  if (reportType == ReportType.revenue) {
    final totalBilling = filteredSessions.fold(0.0, (sum, s) => sum + s.charges);
    final outstanding = filteredSessions.where((s) => s.paymentStatus == 'Unpaid').fold(0.0, (sum, s) => sum + s.charges);
    final collected = filteredSessions.where((s) => s.paymentStatus == 'Paid').fold(0.0, (sum, s) => sum + s.charges);

    final mcTotal = filteredMcBills.fold(0.0, (sum, b) => sum + b.fee);
    final mcOutstanding = filteredMcBills.where((b) => b.paymentStatus == 'Unpaid').fold(0.0, (sum, b) => sum + b.fee);
    final mcCollected = filteredMcBills.where((b) => b.paymentStatus == 'Paid').fold(0.0, (sum, b) => sum + b.fee);

    final consultationFeePatients = filteredPatients.where((p) => p.consultationPaymentStatus != null || (p.consultationFee != null && p.consultationFee! >= 0));
    final consultationCollected = consultationFeePatients.where((p) => p.consultationPaymentStatus == 'Paid').fold(0.0, (sum, p) => sum + (p.consultationFee ?? 0.0));
    final consultationOutstanding = consultationFeePatients.where((p) => (p.consultationPaymentStatus ?? 'Unpaid') == 'Unpaid').fold(0.0, (sum, p) => sum + (p.consultationFee ?? 0.0));
    final consultationTotal = consultationCollected + consultationOutstanding;

    content.add(
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Revenue & Collection Report ($timeframeText)', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: primaryDark)),
          pw.SizedBox(height: 10),
          pw.Text('Billing Summaries:', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 5),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(color: bgLight),
                children: [
                  pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Service', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                  pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Billings', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                  pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Collected', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                  pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Outstanding', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                ]
              ),
              pw.TableRow(
                children: [
                  pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Therapy Sessions')),
                  pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Rs. ${NumberFormat('#,##0').format(totalBilling)}')),
                  pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Rs. ${NumberFormat('#,##0').format(collected)}')),
                  pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Rs. ${NumberFormat('#,##0').format(outstanding)}')),
                ]
              ),
              if (isAdmin) ...[
                pw.TableRow(
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Massage Chair')),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Rs. ${NumberFormat('#,##0').format(mcTotal)}')),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Rs. ${NumberFormat('#,##0').format(mcCollected)}')),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Rs. ${NumberFormat('#,##0').format(mcOutstanding)}')),
                  ]
                ),
                pw.TableRow(
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Consultations')),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Rs. ${NumberFormat('#,##0').format(consultationTotal)}')),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Rs. ${NumberFormat('#,##0').format(consultationCollected)}')),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Rs. ${NumberFormat('#,##0').format(consultationOutstanding)}')),
                  ]
                ),
              ],
            ]
          ),
          pw.SizedBox(height: 20),
          pw.Text('Earnings Log Breakdown:', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 5),
        ]
      )
    );

    final List<_ReportRowData> reportRows = [];
    for (final s in filteredSessions) {
      final p = patients.firstWhere((p) => p.patientId == s.patientId, orElse: () => PatientModel(patientId: '', fullName: 'Unknown', phone: 'N/A', age: 0, gender: '', address: '', medicalCondition: '', notes: '', registrationDate: DateTime.now()));
      reportRows.add(_ReportRowData(date: s.sessionDate, customerName: p.fullName, serviceType: 'Therapy', amount: s.charges, paymentStatus: s.paymentStatus));
    }
    for (final b in filteredMcBills) {
      reportRows.add(_ReportRowData(date: b.sessionDate, customerName: b.customerName, serviceType: 'Massage Chair', amount: b.fee, paymentStatus: b.paymentStatus));
    }
    for (final p in consultationFeePatients) {
      reportRows.add(_ReportRowData(date: p.registrationDate, customerName: p.fullName, serviceType: 'Consultation', amount: p.consultationFee ?? 0.0, paymentStatus: p.consultationPaymentStatus ?? 'Unpaid'));
    }
    reportRows.sort((a, b) => b.date.compareTo(a.date));

    final tableData = <List<String>>[
      ['Date', 'Customer', 'Service', 'Charges', 'Status'],
      ...reportRows.map((row) => [
        DateFormat('dd MMM yyyy').format(row.date),
        row.customerName,
        row.serviceType,
        'Rs. ${NumberFormat('#,##0').format(row.amount)}',
        row.paymentStatus,
      ])
    ];

    content.add(
      pw.TableHelper.fromTextArray(
        context: null,
        border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
        headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
        headerDecoration: pw.BoxDecoration(color: bgLight),
        data: tableData,
      )
    );
  } else if (reportType == ReportType.pendingDues) {
    final Map<String, double> patientDues = {};
    for (var session in sessions.where((s) => s.paymentStatus == 'Unpaid')) {
      patientDues[session.patientId] = (patientDues[session.patientId] ?? 0.0) + session.charges;
    }
    final totalDues = patientDues.values.fold(0.0, (sum, val) => sum + val);

    final Map<String, double> mcDues = {};
    if (isAdmin) {
      for (var bill in massageChairBills.where((b) => b.paymentStatus == 'Unpaid')) {
        mcDues[bill.customerId] = (mcDues[bill.customerId] ?? 0.0) + bill.fee;
      }
    }
    final totalMcDues = mcDues.values.fold(0.0, (sum, val) => sum + val);

    final Map<String, double> consultationDues = {};
    if (isAdmin) {
      for (var p in patients.where((p) => p.consultationFee != null && (p.consultationFee ?? 0.0) > 0 && (p.consultationPaymentStatus ?? 'Unpaid') == 'Unpaid')) {
        consultationDues[p.patientId] = (consultationDues[p.patientId] ?? 0.0) + (p.consultationFee ?? 0.0);
      }
    }
    final totalConsultationDues = consultationDues.values.fold(0.0, (sum, val) => sum + val);

    final List<_DuesRowData> duesRows = [];
    final dummyPatient = PatientModel(patientId: '', fullName: 'Unknown', phone: 'N/A', age: 0, gender: '', address: '', medicalCondition: '', notes: '', registrationDate: DateTime.now());
    for (final entry in patientDues.entries) {
      final p = patients.firstWhere((p) => p.patientId == entry.key, orElse: () => dummyPatient);
      duesRows.add(_DuesRowData(id: entry.key, name: p.fullName, serviceType: 'Therapy', phone: p.phone, amount: entry.value));
    }
    for (final entry in mcDues.entries) {
      final p = patients.firstWhere((p) => p.patientId == entry.key, orElse: () => dummyPatient);
      duesRows.add(_DuesRowData(id: entry.key, name: p.fullName, serviceType: 'Massage Chair', phone: p.phone, amount: entry.value));
    }
    for (final entry in consultationDues.entries) {
      final p = patients.firstWhere((p) => p.patientId == entry.key, orElse: () => dummyPatient);
      duesRows.add(_DuesRowData(id: entry.key, name: p.fullName, serviceType: 'Consultation', phone: p.phone, amount: entry.value));
    }
    duesRows.sort((a, b) => b.amount.compareTo(a.amount));

    content.add(
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Outstanding Dues Summary (Global)', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: errorColor)),
          pw.SizedBox(height: 10),
          pw.Text('Therapy Sessions Outstanding: Rs. ${NumberFormat('#,##0').format(totalDues)}', style: pw.TextStyle(color: errorColor, fontWeight: pw.FontWeight.bold)),
          if (isAdmin) ...[
            pw.SizedBox(height: 4),
            pw.Text('Consultation Outstanding: Rs. ${NumberFormat('#,##0').format(totalConsultationDues)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.Text('Massage Chair Outstanding: Rs. ${NumberFormat('#,##0').format(totalMcDues)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          ],
          pw.SizedBox(height: 20),
          pw.Text('Dues Registry Breakdown:', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 5),
        ]
      )
    );

    final tableData = <List<String>>[
      ['ID', 'Name', 'Service', 'Phone', 'Outstanding'],
      ...duesRows.map((row) => [
        row.id,
        row.name,
        row.serviceType,
        row.phone,
        'Rs. ${NumberFormat('#,##0').format(row.amount)}',
      ])
    ];

    content.add(
      pw.TableHelper.fromTextArray(
        context: null,
        border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
        headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
        headerDecoration: pw.BoxDecoration(color: bgLight),
        data: tableData,
      )
    );
  } else if (reportType == ReportType.registrations) {
    content.add(
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('New Patient Registrations ($timeframeText)', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: primaryDark)),
          pw.SizedBox(height: 10),
          pw.Text('Total Registered Patients: ${filteredPatients.length}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 20),
        ]
      )
    );

    final tableData = <List<String>>[
      ['Date', 'Patient ID', 'Full Name', 'Diagnosis Condition'],
      ...filteredPatients.map((p) => [
        DateFormat('dd MMM yyyy').format(p.registrationDate),
        p.patientId,
        p.fullName,
        p.medicalCondition,
      ])
    ];

    content.add(
      pw.TableHelper.fromTextArray(
        context: null,
        border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
        headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
        headerDecoration: pw.BoxDecoration(color: bgLight),
        data: tableData,
      )
    );
  } else if (reportType == ReportType.sessions) {
    content.add(
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Therapy Sessions Activity Log ($timeframeText)', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: primaryDark)),
          pw.SizedBox(height: 10),
          pw.Text('Total Conducted Sessions: ${filteredSessions.length}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 20),
        ]
      )
    );

    final tableData = <List<String>>[
      ['Date & Time', 'Patient Name', 'Charges', 'Next Advice'],
      ...filteredSessions.map((s) {
        final patient = patients.firstWhere((p) => p.patientId == s.patientId, orElse: () => PatientModel(patientId: '', fullName: 'Unknown', phone: 'N/A', age: 0, gender: '', address: '', medicalCondition: '', notes: '', registrationDate: DateTime.now()));
        return [
          DateFormat('dd MMM yyyy, hh:mm a').format(s.sessionDate),
          patient.fullName,
          'Rs. ${NumberFormat('#,##0').format(s.charges)}',
          s.nextRecommendation.isNotEmpty ? s.nextRecommendation : 'No notes.',
        ];
      })
    ];

    content.add(
      pw.TableHelper.fromTextArray(
        context: null,
        border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
        headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
        headerDecoration: pw.BoxDecoration(color: bgLight),
        data: tableData,
      )
    );
  } else if (reportType == ReportType.staffSalary) {
    final therapists = staff.where((s) => s.role == 'Therapist').toList();
    double totalSessionsConducted = 0;
    double totalRevenueGenerated = 0;
    double totalSalaryExpense = 0;

    final List<_StaffSalaryRowData> rowsData = [];
    for (final therapist in therapists) {
      final therapistSessions = filteredSessions.where((s) => s.therapistId == therapist.userId).toList();
      final double revenue = therapistSessions.fold(0.0, (sum, s) => sum + s.charges);
      final int count = therapistSessions.length;
      final double salary = revenue * (therapist.revenuePercentage / 100);

      totalSessionsConducted += count;
      totalRevenueGenerated += revenue;
      totalSalaryExpense += salary;

      rowsData.add(_StaffSalaryRowData(name: therapist.fullName, email: therapist.email, percentage: therapist.revenuePercentage, sessionsCount: count, revenue: revenue, salary: salary));
    }

    content.add(
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Staff Salary Report ($timeframeText)', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: successColor)),
          pw.SizedBox(height: 10),
          pw.Text('Total Clinic Salary Expense: Rs. ${NumberFormat('#,##0').format(totalSalaryExpense)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: successColor)),
          pw.SizedBox(height: 20),
        ]
      )
    );

    final tableData = <List<String>>[
      ['Therapist', 'Revenue %', 'Sessions Conducted', 'Revenue Generated', 'Calculated Salary'],
      ...rowsData.map((row) => [
        row.name,
        '${row.percentage.toStringAsFixed(0)}%',
        '${row.sessionsCount}',
        'Rs. ${NumberFormat('#,##0').format(row.revenue)}',
        'Rs. ${NumberFormat('#,##0').format(row.salary)}',
      ]),
      [
        'TOTALS',
        '-',
        '${totalSessionsConducted.toInt()}',
        'Rs. ${NumberFormat('#,##0').format(totalRevenueGenerated)}',
        'Rs. ${NumberFormat('#,##0').format(totalSalaryExpense)}'
      ]
    ];

    content.add(
      pw.TableHelper.fromTextArray(
        context: null,
        border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
        headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
        headerDecoration: pw.BoxDecoration(color: bgLight),
        data: tableData,
      )
    );
  }

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (context) {
        return [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('SAEED PHYSIO & REHAB CLINIC', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                  pw.SizedBox(height: 4),
                  pw.Text('Clinic Administration Registry & Analytics', style: pw.TextStyle(fontSize: 10, color: textSecondary)),
                ]
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('OFFICIALLY AUDITED', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: successColor)),
                  pw.SizedBox(height: 2),
                  pw.Text(DateFormat('dd MMMM yyyy, hh:mm a').format(now), style: pw.TextStyle(fontSize: 9, color: textSecondary)),
                ]
              )
            ]
          ),
          pw.Divider(),
          pw.SizedBox(height: 15),

          ...content,

          pw.SizedBox(height: 35),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(width: 150, height: 1, color: textSecondary),
                  pw.SizedBox(height: 4),
                  pw.Text('Clinical Administrator Sign', style: pw.TextStyle(fontSize: 8, color: textSecondary)),
                ]
              ),
              pw.Text('Page ${context.pageNumber} of ${context.pagesCount}', style: pw.TextStyle(fontSize: 9, color: textSecondary)),
            ]
          )
        ];
      }
    )
  );

  return pdf.save();
}

Future<Uint8List> _generateDocxReport(
  ReportType reportType,
  TimeFilter timeFilter,
  List<PatientModel> patients,
  List<SessionModel> sessions,
  List<MassageChairBillModel> massageChairBills,
  List<UserModel> staff,
  bool isAdmin,
) async {
  final now = DateTime.now();
  DateTime filterStartDate;
  switch (timeFilter) {
    case TimeFilter.daily:
      filterStartDate = DateTime(now.year, now.month, now.day);
      break;
    case TimeFilter.weekly:
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      filterStartDate = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
      break;
    case TimeFilter.monthly:
      filterStartDate = DateTime(now.year, now.month, 1);
      break;
  }

  final filteredPatients = patients.where((p) => p.registrationDate.isAfter(filterStartDate)).toList();
  final filteredSessions = sessions.where((s) => s.sessionDate.isAfter(filterStartDate)).toList();
  final filteredMcBills = massageChairBills.where((b) => b.sessionDate.isAfter(filterStartDate)).toList();

  String timeframeText = '';
  switch (timeFilter) {
    case TimeFilter.daily: timeframeText = 'Today'; break;
    case TimeFilter.weekly: timeframeText = 'This Week'; break;
    case TimeFilter.monthly: timeframeText = 'This Month'; break;
  }

  final builder = docx()
      .h1('SAEED PHYSIO & REHAB CLINIC')
      .p('Clinic Administration Registry & Analytics')
      .p('Date Generated: ${DateFormat('dd MMMM yyyy, hh:mm a').format(now)}')
      .p('Report Period: $timeframeText')
      .h2(reportType == ReportType.revenue ? 'Revenue & Collection Report'
        : reportType == ReportType.pendingDues ? 'Outstanding Dues Summary'
        : reportType == ReportType.registrations ? 'New Patient Registrations Report'
        : reportType == ReportType.sessions ? 'Therapy Sessions Activity Log'
        : 'Staff Salary Report');

  if (reportType == ReportType.revenue) {
    final totalBilling = filteredSessions.fold(0.0, (sum, s) => sum + s.charges);
    final outstanding = filteredSessions.where((s) => s.paymentStatus == 'Unpaid').fold(0.0, (sum, s) => sum + s.charges);
    final collected = filteredSessions.where((s) => s.paymentStatus == 'Paid').fold(0.0, (sum, s) => sum + s.charges);

    final mcTotal = filteredMcBills.fold(0.0, (sum, b) => sum + b.fee);
    final mcOutstanding = filteredMcBills.where((b) => b.paymentStatus == 'Unpaid').fold(0.0, (sum, b) => sum + b.fee);
    final mcCollected = filteredMcBills.where((b) => b.paymentStatus == 'Paid').fold(0.0, (sum, b) => sum + b.fee);

    final consultationFeePatients = filteredPatients.where((p) => p.consultationPaymentStatus != null || (p.consultationFee != null && p.consultationFee! >= 0));
    final consultationCollected = consultationFeePatients.where((p) => p.consultationPaymentStatus == 'Paid').fold(0.0, (sum, p) => sum + (p.consultationFee ?? 0.0));
    final consultationOutstanding = consultationFeePatients.where((p) => (p.consultationPaymentStatus ?? 'Unpaid') == 'Unpaid').fold(0.0, (sum, p) => sum + (p.consultationFee ?? 0.0));
    final consultationTotal = consultationCollected + consultationOutstanding;

    builder.h3('Billing Summaries')
           .p('Therapy Sessions Billings: Rs. ${NumberFormat('#,##0').format(totalBilling)} (Collected: Rs. ${NumberFormat('#,##0').format(collected)}, Outstanding: Rs. ${NumberFormat('#,##0').format(outstanding)})');
    if (isAdmin) {
      builder.p('Massage Chair Billings: Rs. ${NumberFormat('#,##0').format(mcTotal)} (Collected: Rs. ${NumberFormat('#,##0').format(mcCollected)}, Outstanding: Rs. ${NumberFormat('#,##0').format(mcOutstanding)})')
             .p('Consultation Billings: Rs. ${NumberFormat('#,##0').format(consultationTotal)} (Collected: Rs. ${NumberFormat('#,##0').format(consultationCollected)}, Outstanding: Rs. ${NumberFormat('#,##0').format(consultationOutstanding)})');
    }

    builder.h3('Earnings Log Breakdown');
    final List<_ReportRowData> reportRows = [];
    for (final s in filteredSessions) {
      final p = patients.firstWhere((p) => p.patientId == s.patientId, orElse: () => PatientModel(patientId: '', fullName: 'Unknown', phone: 'N/A', age: 0, gender: '', address: '', medicalCondition: '', notes: '', registrationDate: DateTime.now()));
      reportRows.add(_ReportRowData(date: s.sessionDate, customerName: p.fullName, serviceType: 'Therapy', amount: s.charges, paymentStatus: s.paymentStatus));
    }
    for (final b in filteredMcBills) {
      reportRows.add(_ReportRowData(date: b.sessionDate, customerName: b.customerName, serviceType: 'Massage Chair', amount: b.fee, paymentStatus: b.paymentStatus));
    }
    for (final p in consultationFeePatients) {
      reportRows.add(_ReportRowData(date: p.registrationDate, customerName: p.fullName, serviceType: 'Consultation', amount: p.consultationFee ?? 0.0, paymentStatus: p.consultationPaymentStatus ?? 'Unpaid'));
    }
    reportRows.sort((a, b) => b.date.compareTo(a.date));

    final List<List<String>> data = [
      ['Date', 'Customer', 'Service', 'Charges', 'Status']
    ];
    for (final row in reportRows) {
      data.add([
        DateFormat('dd MMM yyyy').format(row.date),
        row.customerName,
        row.serviceType,
        'Rs. ${NumberFormat('#,##0').format(row.amount)}',
        row.paymentStatus
      ]);
    }
    builder.table(data);
  } else if (reportType == ReportType.pendingDues) {
    final Map<String, double> patientDues = {};
    for (var session in sessions.where((s) => s.paymentStatus == 'Unpaid')) {
      patientDues[session.patientId] = (patientDues[session.patientId] ?? 0.0) + session.charges;
    }
    final totalDues = patientDues.values.fold(0.0, (sum, val) => sum + val);

    final Map<String, double> mcDues = {};
    if (isAdmin) {
      for (var bill in massageChairBills.where((b) => b.paymentStatus == 'Unpaid')) {
        mcDues[bill.customerId] = (mcDues[bill.customerId] ?? 0.0) + bill.fee;
      }
    }
    final totalMcDues = mcDues.values.fold(0.0, (sum, val) => sum + val);

    final Map<String, double> consultationDues = {};
    if (isAdmin) {
      for (var p in patients.where((p) => p.consultationFee != null && (p.consultationFee ?? 0.0) > 0 && (p.consultationPaymentStatus ?? 'Unpaid') == 'Unpaid')) {
        consultationDues[p.patientId] = (consultationDues[p.patientId] ?? 0.0) + (p.consultationFee ?? 0.0);
      }
    }
    final totalConsultationDues = consultationDues.values.fold(0.0, (sum, val) => sum + val);

    final List<_DuesRowData> duesRows = [];
    final dummyPatient = PatientModel(patientId: '', fullName: 'Unknown', phone: 'N/A', age: 0, gender: '', address: '', medicalCondition: '', notes: '', registrationDate: DateTime.now());
    for (final entry in patientDues.entries) {
      final p = patients.firstWhere((p) => p.patientId == entry.key, orElse: () => dummyPatient);
      duesRows.add(_DuesRowData(id: entry.key, name: p.fullName, serviceType: 'Therapy', phone: p.phone, amount: entry.value));
    }
    for (final entry in mcDues.entries) {
      final p = patients.firstWhere((p) => p.patientId == entry.key, orElse: () => dummyPatient);
      duesRows.add(_DuesRowData(id: entry.key, name: p.fullName, serviceType: 'Massage Chair', phone: p.phone, amount: entry.value));
    }
    for (final entry in consultationDues.entries) {
      final p = patients.firstWhere((p) => p.patientId == entry.key, orElse: () => dummyPatient);
      duesRows.add(_DuesRowData(id: entry.key, name: p.fullName, serviceType: 'Consultation', phone: p.phone, amount: entry.value));
    }
    duesRows.sort((a, b) => b.amount.compareTo(a.amount));

    builder.h3('Dues Summaries')
           .p('Therapy Sessions Outstanding: Rs. ${NumberFormat('#,##0').format(totalDues)}');
    if (isAdmin) {
      builder.p('Consultation Outstanding: Rs. ${NumberFormat('#,##0').format(totalConsultationDues)}')
             .p('Massage Chair Outstanding: Rs. ${NumberFormat('#,##0').format(totalMcDues)}');
    }

    final List<List<String>> data = [
      ['ID', 'Name', 'Service', 'Phone', 'Outstanding Amount']
    ];
    for (final row in duesRows) {
      data.add([
        row.id,
        row.name,
        row.serviceType,
        row.phone,
        'Rs. ${NumberFormat('#,##0').format(row.amount)}'
      ]);
    }
    builder.table(data);
  } else if (reportType == ReportType.registrations) {
    builder.h3('New Patient Registrations')
           .p('Total Registered: ${filteredPatients.length}');

    final List<List<String>> data = [
      ['Date', 'Patient ID', 'Full Name', 'Diagnosis Condition']
    ];
    for (final p in filteredPatients) {
      data.add([
        DateFormat('dd MMM yyyy').format(p.registrationDate),
        p.patientId,
        p.fullName,
        p.medicalCondition
      ]);
    }
    builder.table(data);
  } else if (reportType == ReportType.sessions) {
    builder.h3('Therapy Sessions Activity Log')
           .p('Total Sessions Conducted: ${filteredSessions.length}');

    final List<List<String>> data = [
      ['Date & Time', 'Patient Name', 'Charges', 'Next Recommendation / Advice']
    ];
    for (final s in filteredSessions) {
      final patient = patients.firstWhere((p) => p.patientId == s.patientId, orElse: () => PatientModel(patientId: '', fullName: 'Unknown', phone: 'N/A', age: 0, gender: '', address: '', medicalCondition: '', notes: '', registrationDate: DateTime.now()));
      data.add([
        DateFormat('dd MMM yyyy, hh:mm a').format(s.sessionDate),
        patient.fullName,
        'Rs. ${NumberFormat('#,##0').format(s.charges)}',
        s.nextRecommendation.isNotEmpty ? s.nextRecommendation : 'No notes.'
      ]);
    }
    builder.table(data);
  } else if (reportType == ReportType.staffSalary) {
    final therapists = staff.where((s) => s.role == 'Therapist').toList();
    double totalSessionsConducted = 0;
    double totalRevenueGenerated = 0;
    double totalSalaryExpense = 0;

    final List<_StaffSalaryRowData> rowsData = [];
    for (final therapist in therapists) {
      final therapistSessions = filteredSessions.where((s) => s.therapistId == therapist.userId).toList();
      final double revenue = therapistSessions.fold(0.0, (sum, s) => sum + s.charges);
      final int count = therapistSessions.length;
      final double salary = revenue * (therapist.revenuePercentage / 100);

      totalSessionsConducted += count;
      totalRevenueGenerated += revenue;
      totalSalaryExpense += salary;

      rowsData.add(_StaffSalaryRowData(name: therapist.fullName, email: therapist.email, percentage: therapist.revenuePercentage, sessionsCount: count, revenue: revenue, salary: salary));
    }

    builder.h3('Staff Salaries Summary')
           .p('Total Clinic Salary Expense: Rs. ${NumberFormat('#,##0').format(totalSalaryExpense)}');

    final List<List<String>> data = [
      ['Therapist', 'Revenue Percentage', 'Sessions Conducted', 'Revenue Generated', 'Calculated Salary']
    ];
    for (final row in rowsData) {
      data.add([
        row.name,
        '${row.percentage.toStringAsFixed(0)}%',
        '${row.sessionsCount}',
        'Rs. ${NumberFormat('#,##0').format(row.revenue)}',
        'Rs. ${NumberFormat('#,##0').format(row.salary)}'
      ]);
    }
    data.add([
      'TOTALS',
      '-',
      '${totalSessionsConducted.toInt()}',
      'Rs. ${NumberFormat('#,##0').format(totalRevenueGenerated)}',
      'Rs. ${NumberFormat('#,##0').format(totalSalaryExpense)}'
    ]);
    builder.table(data);
  }

  final builtDoc = builder.build();
  final docxBytes = await DocxExporter().exportToBytes(builtDoc);
  return Uint8List.fromList(docxBytes);
}

class PrintPreviewDialog extends StatelessWidget {
  final ReportType reportType;
  final TimeFilter timeFilter;
  final List<PatientModel> patients;
  final List<SessionModel> sessions;
  final List<MassageChairBillModel> massageChairBills;
  final List<UserModel> staff;
  final bool isAdmin;

  const PrintPreviewDialog({
    super.key,
    required this.reportType,
    required this.timeFilter,
    required this.patients,
    required this.sessions,
    required this.massageChairBills,
    required this.staff,
    required this.isAdmin,
  });

  @override
  Widget build(BuildContext context) {
    final reportLabel = reportType == ReportType.revenue ? 'Revenue'
        : reportType == ReportType.pendingDues ? 'Dues'
        : reportType == ReportType.registrations ? 'Registrations'
        : reportType == ReportType.sessions ? 'Sessions'
        : 'StaffSalary';
    final filterLabel = timeFilter == TimeFilter.daily ? 'Today'
        : timeFilter == TimeFilter.weekly ? 'Weekly'
        : 'Monthly';
    final baseFilename = 'SaeedPhysioRehab_${reportLabel}_$filterLabel';

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.radiusLarge)),
      child: Container(
        width: 1100,
        height: 750,
        padding: const EdgeInsets.all(AppSizes.p24),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.print_rounded, color: AppColors.primary, size: 28),
                    AppSizes.w12,
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Report Print & Export Center',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                        Text(
                          'Generate, customize, download, or share clinical audits',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(height: 24),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    flex: 7,
                    child: Card(
                      elevation: 0,
                      color: AppColors.background,
                      child: PdfPreview(
                        build: (format) => _generatePdfReport(
                          reportType,
                          timeFilter,
                          patients,
                          sessions,
                          massageChairBills,
                          staff,
                          isAdmin,
                        ),
                        useActions: false,
                        allowPrinting: true,
                        allowSharing: false,
                        canChangeOrientation: false,
                        canChangePageFormat: false,
                        canDebug: false,
                      ),
                    ),
                  ),
                  AppSizes.w24,
                  SizedBox(
                    width: 280,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'DOCUMENT ACTIONS',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textSecondary,
                            letterSpacing: 1.0,
                          ),
                        ),
                        AppSizes.h12,
                        ElevatedButton.icon(
                          onPressed: () async {
                            final bytes = await _generatePdfReport(
                              reportType,
                              timeFilter,
                              patients,
                              sessions,
                              massageChairBills,
                              staff,
                              isAdmin,
                            );
                            _downloadFile(bytes, '$baseFilename.pdf', 'application/pdf');
                          },
                          icon: const Icon(Icons.picture_as_pdf_rounded),
                          label: const Text('Download PDF'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                        AppSizes.h12,
                        ElevatedButton.icon(
                          onPressed: () async {
                            final bytes = await _generateDocxReport(
                              reportType,
                              timeFilter,
                              patients,
                              sessions,
                              massageChairBills,
                              staff,
                              isAdmin,
                            );
                            _downloadFile(
                              bytes,
                              '$baseFilename.docx',
                              'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
                            );
                          },
                          icon: const Icon(Icons.description_rounded),
                          label: const Text('Download Word Document'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueGrey,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                        AppSizes.h24,
                        const Text(
                          'SHARING ACTIONS',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textSecondary,
                            letterSpacing: 1.0,
                          ),
                        ),
                        AppSizes.h12,
                        OutlinedButton.icon(
                          onPressed: () async {
                            final bytes = await _generatePdfReport(
                              reportType,
                              timeFilter,
                              patients,
                              sessions,
                              massageChairBills,
                              staff,
                              isAdmin,
                            );
                            final xFile = XFile.fromData(
                              bytes,
                              name: '$baseFilename.pdf',
                              mimeType: 'application/pdf',
                            );
                            await Share.shareXFiles([xFile], text: 'SAEED PHYSIO & REHAB CLINIC PDF Report');
                          },
                          icon: const Icon(Icons.share_rounded),
                          label: const Text('Share PDF Report'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                        AppSizes.h12,
                        OutlinedButton.icon(
                          onPressed: () async {
                            final bytes = await _generateDocxReport(
                              reportType,
                              timeFilter,
                              patients,
                              sessions,
                              massageChairBills,
                              staff,
                              isAdmin,
                            );
                            final xFile = XFile.fromData(
                              bytes,
                              name: '$baseFilename.docx',
                              mimeType: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
                            );
                            await Share.shareXFiles([xFile], text: 'SAEED PHYSIO & REHAB CLINIC Word Report');
                          },
                          icon: const Icon(Icons.share_rounded),
                          label: const Text('Share Word Document'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.all(AppSizes.p12),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline_rounded, color: AppColors.primaryDark, size: 20),
                              AppSizes.w8,
                              const Expanded(
                                child: Text(
                                  'To print the document, click the printer icon in the preview top bar.',
                                  style: TextStyle(fontSize: 10, color: AppColors.textSecondary, height: 1.3),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class _ReportRowData {
  final DateTime date;
  final String customerName;
  final String serviceType;
  final double amount;
  final String paymentStatus;
  _ReportRowData({
    required this.date,
    required this.customerName,
    required this.serviceType,
    required this.amount,
    required this.paymentStatus,
  });
}

class _DuesRowData {
  final String id;
  final String name;
  final String serviceType;
  final String phone;
  final double amount;
  _DuesRowData({
    required this.id,
    required this.name,
    required this.serviceType,
    required this.phone,
    required this.amount,
  });
}

class _StaffSalaryRowData {
  final String name;
  final String email;
  final double percentage;
  final int sessionsCount;
  final double revenue;
  final double salary;

  _StaffSalaryRowData({
    required this.name,
    required this.email,
    required this.percentage,
    required this.sessionsCount,
    required this.revenue,
    required this.salary,
  });
}
