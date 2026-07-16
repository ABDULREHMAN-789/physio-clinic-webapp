import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../models/patient_model.dart';
import '../../../models/session_model.dart';
import '../../../models/massage_chair_bill_model.dart';
import '../../patients/providers/patients_provider.dart';
import '../../sessions/providers/sessions_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/massage_chair_provider.dart';

// Filter state: false = Unpaid Dues Only, true = Paid Only, null = All
final billingFilterProvider = StateProvider<bool?>((ref) => false);
final billingSearchProvider = StateProvider<String>((ref) => '');
// Service type filter: 'all', 'therapy', 'massage_chair'
final billingServiceFilterProvider = StateProvider<String>((ref) => 'all');

class BillingScreen extends ConsumerWidget {
  const BillingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(sessionsStreamProvider);
    final patientsAsync = ref.watch(patientsStreamProvider);
    final authState = ref.watch(authProvider);
    final isAdmin = authState.role == 'Admin';
    final massageChairBillsAsync = isAdmin ? ref.watch(massageChairBillsStreamProvider) : null;
    final textTheme = Theme.of(context).textTheme;

    final activeFilter = ref.watch(billingFilterProvider);
    final searchQuery = ref.watch(billingSearchProvider).toLowerCase().trim();
    final serviceFilter = ref.watch(billingServiceFilterProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: patientsAsync.when(
          data: (patients) {
            return sessionsAsync.when(
              data: (sessions) {
                final massageChairBills = isAdmin 
                    ? (massageChairBillsAsync?.valueOrNull ?? <MassageChairBillModel>[]) 
                    : <MassageChairBillModel>[];

                // Therapy metrics
                final totalCharges = sessions.fold(0.0, (sum, s) => sum + s.charges);
                final unpaidDues = sessions.where((s) => !s.paymentStatus).fold(0.0, (sum, s) => sum + s.charges);
                final receivedRevenue = totalCharges - unpaidDues;

                // Massage chair metrics (admin only)
                final mcTotal = massageChairBills.fold(0.0, (sum, b) => sum + b.fee);
                final mcUnpaid = massageChairBills.where((b) => !b.paymentStatus).fold(0.0, (sum, b) => sum + b.fee);
                final mcReceived = mcTotal - mcUnpaid;

                // Consultation metrics (admin only)
                final consultationFeePatients = patients.where((p) => p.consultationFee != null && p.consultationFee! > 0);
                final double consultationTotal = consultationFeePatients.fold(0.0, (sum, p) => sum + p.consultationFee!);
                final double consultationReceived = consultationFeePatients
                    .where((p) => p.consultationPaymentStatus == true)
                    .fold(0.0, (sum, p) => sum + p.consultationFee!);
                final double consultationUnpaid = consultationTotal - consultationReceived;

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSizes.p24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Billing & Accounts',
                            style: textTheme.displaySmall?.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          AppSizes.h4,
                          Text(
                            'Manage clinical invoices, collect pending dues, and track earnings metrics',
                            style: textTheme.bodyMedium,
                          ),
                        ],
                      ),
                      AppSizes.h24,

                      // Top Metric Summary Cards
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final double width = constraints.maxWidth;
                          final bool isNarrow = width < 700;

                          Widget buildSummaryCard({
                            required String title,
                            required String value,
                            required IconData icon,
                            required Color color,
                            required Gradient? gradient,
                          }) {
                            return Container(
                              padding: const EdgeInsets.all(AppSizes.p20),
                              decoration: BoxDecoration(
                                gradient: gradient,
                                color: gradient == null ? Colors.white : null,
                                borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                                border: gradient == null ? Border.all(color: AppColors.border, width: 1.5) : null,
                                boxShadow: gradient != null
                                    ? [
                                        BoxShadow(
                                          color: color.withValues(alpha: 0.3),
                                          blurRadius: 12,
                                          offset: const Offset(0, 6),
                                        )
                                      ]
                                    : null,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(AppSizes.p12),
                                    decoration: BoxDecoration(
                                      color: gradient == null ? color.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.2),
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
                                          title,
                                          style: TextStyle(
                                            color: gradient == null ? AppColors.textSecondary : Colors.white.withValues(alpha: 0.8),
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        AppSizes.h4,
                                        Text(
                                          value,
                                          style: TextStyle(
                                            color: gradient == null ? AppColors.textPrimary : Colors.white,
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          final List<Widget> cards = [
                            buildSummaryCard(
                              title: isAdmin ? 'THERAPY BILLINGS' : 'TOTAL BILLINGS',
                              value: 'Rs. ${NumberFormat('#,##0').format(totalCharges)}',
                              icon: Icons.receipt_long_rounded,
                              color: AppColors.primary,
                              gradient: null,
                            ),
                            buildSummaryCard(
                              title: isAdmin ? 'THERAPY COLLECTED' : 'REVENUE COLLECTED',
                              value: 'Rs. ${NumberFormat('#,##0').format(receivedRevenue)}',
                              icon: Icons.check_circle_rounded,
                              color: AppColors.success,
                              gradient: null,
                            ),
                            buildSummaryCard(
                              title: isAdmin ? 'THERAPY PENDING' : 'PENDING DUES',
                              value: 'Rs. ${NumberFormat('#,##0').format(unpaidDues)}',
                              icon: Icons.pending_actions_rounded,
                              color: AppColors.warning,
                              gradient: null,
                            ),
                            if (isAdmin) ...[
                              buildSummaryCard(
                                title: 'MASSAGE BILLINGS',
                                value: 'Rs. ${NumberFormat('#,##0').format(mcTotal)}',
                                icon: Icons.receipt_long_rounded,
                                color: const Color(0xFFE65100),
                                gradient: null,
                              ),
                              buildSummaryCard(
                                title: 'MASSAGE COLLECTED',
                                value: 'Rs. ${NumberFormat('#,##0').format(mcReceived)}',
                                icon: Icons.check_circle_rounded,
                                color: AppColors.success,
                                gradient: AppColors.dashboardCardGradient,
                              ),
                              buildSummaryCard(
                                title: 'MASSAGE PENDING',
                                value: 'Rs. ${NumberFormat('#,##0').format(mcUnpaid)}',
                                icon: Icons.pending_actions_rounded,
                                color: AppColors.warning,
                                gradient: null,
                              ),
                              buildSummaryCard(
                                title: 'CONSULTATION BILLINGS',
                                value: 'Rs. ${NumberFormat('#,##0').format(consultationTotal)}',
                                icon: Icons.receipt_long_rounded,
                                color: Colors.purple,
                                gradient: null,
                              ),
                              buildSummaryCard(
                                title: 'CONSULTATION COLLECTED',
                                value: 'Rs. ${NumberFormat('#,##0').format(consultationReceived)}',
                                icon: Icons.check_circle_rounded,
                                color: AppColors.success,
                                gradient: const LinearGradient(
                                  colors: [Colors.purple, Color(0xFFAB47BC)],
                                ),
                              ),
                              buildSummaryCard(
                                title: 'CONSULTATION PENDING',
                                value: 'Rs. ${NumberFormat('#,##0').format(consultationUnpaid)}',
                                icon: Icons.pending_actions_rounded,
                                color: AppColors.warning,
                                gradient: null,
                              ),
                            ],
                          ];

                          if (isNarrow) {
                            return Column(
                              children: cards.map((c) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: c,
                              )).toList(),
                            );
                          }

                          if (isAdmin) {
                            return Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(child: cards[0]),
                                    AppSizes.w16,
                                    Expanded(child: cards[1]),
                                    AppSizes.w16,
                                    Expanded(child: cards[2]),
                                  ],
                                ),
                                AppSizes.h16,
                                Row(
                                  children: [
                                    Expanded(child: cards[3]),
                                    AppSizes.w16,
                                    Expanded(child: cards[4]),
                                    AppSizes.w16,
                                    Expanded(child: cards[5]),
                                  ],
                                ),
                                AppSizes.h16,
                                Row(
                                  children: [
                                    Expanded(child: cards[6]),
                                    AppSizes.w16,
                                    Expanded(child: cards[7]),
                                    AppSizes.w16,
                                    Expanded(child: cards[8]),
                                  ],
                                ),
                              ],
                            );
                          }

                          return Row(
                            children: [
                              Expanded(child: cards[0]),
                              AppSizes.w16,
                              Expanded(child: cards[1]),
                              AppSizes.w16,
                              Expanded(child: cards[2]),
                            ],
                          );
                        },
                      ),
                      AppSizes.h24,

                      // Filters & Search Card
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSizes.p16),
                          child: Row(
                            children: [
                              // Search patient name
                              Expanded(
                                child: TextField(
                                  onChanged: (val) => ref.read(billingSearchProvider.notifier).state = val,
                                  decoration: InputDecoration(
                                    hintText: 'Search invoice by patient name...',
                                    prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textSecondary),
                                    fillColor: AppColors.background,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                                      borderSide: BorderSide.none,
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                ),
                              ),
                              AppSizes.w16,
                              // Payment status filter
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                                ),
                                child: Row(
                                  children: [
                                    _buildFilterTab(context, ref, 'Dues Only', false, activeFilter == false),
                                    _buildFilterTab(context, ref, 'Paid Only', true, activeFilter == true),
                                    _buildFilterTab(context, ref, 'All', null, activeFilter == null),
                                  ],
                                ),
                              ),
                              // Service type filter (Admin only)
                              if (isAdmin) ...[
                                AppSizes.w16,
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.background,
                                    borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                                  ),
                                  child: Row(
                                    children: [
                                      _buildServiceFilterTab(context, ref, 'All Services', 'all', serviceFilter == 'all'),
                                      _buildServiceFilterTab(context, ref, 'Therapy', 'therapy', serviceFilter == 'therapy'),
                                      _buildServiceFilterTab(context, ref, 'Massage Chair', 'massage_chair', serviceFilter == 'massage_chair'),
                                      _buildServiceFilterTab(context, ref, 'Consultation', 'consultation', serviceFilter == 'consultation'),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      AppSizes.h20,

                      // Invoices Grid/Table
                      Builder(
                        builder: (context) {
                          // Apply filters to therapy sessions
                          var filteredSessions = sessions;
                          if (activeFilter != null) {
                            filteredSessions = filteredSessions.where((s) => s.paymentStatus == activeFilter).toList();
                          }
                          if (searchQuery.isNotEmpty) {
                            filteredSessions = filteredSessions.where((s) {
                              final hasPatient = patients.any((p) => p.patientId == s.patientId);
                              if (!hasPatient) return false;
                              final patient = patients.firstWhere((p) => p.patientId == s.patientId);
                              return patient.fullName.toLowerCase().contains(searchQuery);
                            }).toList();
                          }

                          // Apply filters to massage chair bills
                          var filteredMcBills = massageChairBills;
                          if (activeFilter != null) {
                            filteredMcBills = filteredMcBills.where((b) => b.paymentStatus == activeFilter).toList();
                          }
                          if (searchQuery.isNotEmpty) {
                            filteredMcBills = filteredMcBills.where((b) =>
                                b.customerName.toLowerCase().contains(searchQuery)).toList();
                          }

                          // Apply filters to consultation records
                          var filteredConsultations = patients
                              .where((p) => p.consultationFee != null && p.consultationFee! > 0)
                              .toList();
                          if (activeFilter != null) {
                            filteredConsultations = filteredConsultations
                                .where((p) => (p.consultationPaymentStatus ?? false) == activeFilter)
                                .toList();
                          }
                          if (searchQuery.isNotEmpty) {
                            filteredConsultations = filteredConsultations
                                .where((p) => p.fullName.toLowerCase().contains(searchQuery))
                                .toList();
                          }

                          // Apply service type filter
                          final showTherapy = serviceFilter == 'all' || serviceFilter == 'therapy';
                          final showMassageChair = isAdmin && (serviceFilter == 'all' || serviceFilter == 'massage_chair');
                          final showConsultation = isAdmin && (serviceFilter == 'all' || serviceFilter == 'consultation');

                          final hasTherapy = showTherapy && filteredSessions.isNotEmpty;
                          final hasMassageChair = showMassageChair && filteredMcBills.isNotEmpty;
                          final hasConsultation = showConsultation && filteredConsultations.isNotEmpty;

                          if (!hasTherapy && !hasMassageChair && !hasConsultation) {
                            return _buildEmptyState(context);
                          }

                          return _buildCombinedBillingTable(
                            context,
                            ref,
                            showTherapy ? filteredSessions : [],
                            showMassageChair ? filteredMcBills : [],
                            showConsultation ? filteredConsultations : [],
                            patients,
                          );
                        },
                      ),
                      // Bottom padding so last row never sits against the edge
                      const SizedBox(height: 32),
                    ],
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
              error: (err, stack) => Center(child: Text('Error loading billing records: $err')),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
          error: (err, stack) => Center(child: Text('Error loading patient directory: $err')),
        ),
      ),
    );
  }

  Widget _buildFilterTab(
    BuildContext context,
    WidgetRef ref,
    String label,
    bool? filterValue,
    bool isSelected,
  ) {
    return TextButton(
      onPressed: () {
        ref.read(billingFilterProvider.notifier).state = filterValue;
      },
      style: TextButton.styleFrom(
        backgroundColor: isSelected ? Colors.white : Colors.transparent,
        foregroundColor: isSelected ? AppColors.primary : AppColors.textSecondary,
        elevation: isSelected ? 1 : 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
        ),
        padding: const EdgeInsets.symmetric(horizontal: AppSizes.p16, vertical: AppSizes.p12),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }

  Widget _buildServiceFilterTab(
    BuildContext context,
    WidgetRef ref,
    String label,
    String filterValue,
    bool isSelected,
  ) {
    Color selectedColor;
    if (filterValue == 'massage_chair') {
      selectedColor = const Color(0xFFE65100);
    } else if (filterValue == 'consultation') {
      selectedColor = Colors.purple;
    } else {
      selectedColor = AppColors.primary;
    }

    return TextButton(
      onPressed: () {
        ref.read(billingServiceFilterProvider.notifier).state = filterValue;
      },
      style: TextButton.styleFrom(
        backgroundColor: isSelected ? Colors.white : Colors.transparent,
        foregroundColor: isSelected ? selectedColor : AppColors.textSecondary,
        elevation: isSelected ? 1 : 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
        ),
        padding: const EdgeInsets.symmetric(horizontal: AppSizes.p16, vertical: AppSizes.p12),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSizes.p20),
            decoration: const BoxDecoration(color: AppColors.primaryLight, shape: BoxShape.circle),
            child: const Icon(Icons.account_balance_wallet_outlined, color: AppColors.primary, size: 40),
          ),
          AppSizes.h16,
          Text(
            'No Billings Found',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
          ),
          AppSizes.h8,
          const Text(
            'No logs match the current search or filters.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildCombinedBillingTable(
    BuildContext context,
    WidgetRef ref,
    List<SessionModel> sessions,
    List<MassageChairBillModel> massageChairBills,
    List<PatientModel> consultations,
    List<PatientModel> patients,
  ) {
    final formatter = DateFormat('dd MMM yyyy, hh:mm a');

    // Build unified rows helper
    final List<_BillingRowData> rowDataList = [];

    // Add therapy session rows
    for (final session in sessions) {
      final p = patients.firstWhere(
        (pat) => pat.patientId == session.patientId,
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

      rowDataList.add(_BillingRowData(
        date: session.sessionDate,
        customerName: p.fullName,
        customerSub: 'Phone: ${p.phone}',
        serviceType: 'Therapy',
        details: session.treatmentNotes,
        amount: session.charges,
        isPaid: session.paymentStatus,
        onMarkPaid: () async {
          final updatedSession = session.copyWith(paymentStatus: true);
          await ref.read(sessionOperationProvider.notifier).updateSession(updatedSession);
        },
      ));
    }

    // Add massage chair bill rows
    for (final bill in massageChairBills) {
      rowDataList.add(_BillingRowData(
        date: bill.sessionDate,
        customerName: bill.customerName,
        customerSub: 'ID: ${bill.customerId}',
        serviceType: 'Massage Chair',
        details: bill.duration.isNotEmpty ? 'Duration: ${bill.duration}' : 'Walk-in session',
        amount: bill.fee,
        isPaid: bill.paymentStatus,
        onMarkPaid: () async {
          final updatedBill = bill.copyWith(paymentStatus: true);
          await ref.read(massageChairBillOperationProvider.notifier).updateBill(updatedBill);
        },
      ));
    }

    // Add consultation rows
    for (final p in consultations) {
      rowDataList.add(_BillingRowData(
        date: p.registrationDate,
        customerName: p.fullName,
        customerSub: 'Phone: ${p.phone}',
        serviceType: 'Consultation',
        details: p.consultationNotes ?? 'Initial Consultation',
        amount: p.consultationFee ?? 0.0,
        isPaid: p.consultationPaymentStatus ?? false,
        onMarkPaid: () async {
          final updatedPatient = p.copyWith(
            consultationPaymentStatus: true,
            consultationPaymentDate: DateTime.now(),
          );
          await ref.read(patientOperationProvider.notifier).updatePatient(updatedPatient);
        },
      ));
    }

    // Sort descending by date (newest first)
    rowDataList.sort((a, b) => b.date.compareTo(a.date));

    final List<DataRow> rows = rowDataList.map((row) {
      Color badgeColor;
      Color textColor;
      Widget? serviceIcon;

      if (row.serviceType == 'Massage Chair') {
        badgeColor = const Color(0xFFFFF3E0);
        textColor = const Color(0xFFE65100);
        serviceIcon = const Icon(Icons.chair_rounded, size: 12, color: Color(0xFFE65100));
      } else if (row.serviceType == 'Consultation') {
        badgeColor = Colors.purple.withValues(alpha: 0.1);
        textColor = Colors.purple;
        serviceIcon = const Icon(Icons.payment_rounded, size: 12, color: Colors.purple);
      } else {
        badgeColor = AppColors.primaryLight;
        textColor = AppColors.primaryDark;
      }

      return DataRow(
        cells: [
          DataCell(
            Text(
              formatter.format(row.date),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          DataCell(
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.customerName,
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                if (row.customerSub.isNotEmpty)
                  Text(
                    row.customerSub,
                    style: const TextStyle(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.bold),
                  ),
              ],
            ),
          ),
          DataCell(
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: badgeColor,
                borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (serviceIcon != null) ...[
                    serviceIcon,
                    const SizedBox(width: 4),
                  ],
                  Text(
                    row.serviceType,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
          DataCell(
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 200),
              child: Text(
                row.details,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ),
          DataCell(
            Text(
              'Rs. ${NumberFormat('#,##0').format(row.amount)}',
              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
          ),
          DataCell(
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: (row.isPaid ? AppColors.success : AppColors.error).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
              ),
              child: Text(
                row.isPaid ? 'Paid' : 'Unpaid',
                style: TextStyle(
                  color: row.isPaid ? AppColors.success : AppColors.error,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
          ),
          DataCell(
            row.isPaid
                ? const Icon(Icons.check_circle_outline_rounded, color: AppColors.success, size: 22)
                : ElevatedButton.icon(
                    onPressed: row.onMarkPaid,
                    icon: const Icon(Icons.payment_rounded, size: 14),
                    label: const Text('Mark Paid'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
          ),
        ],
      );
    }).toList();

    // Horizontal scroll only — vertical scrolling is handled by the page-level
    // SingleChildScrollView so the whole page scrolls as one unit.
    return Card(
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 800),
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(
              AppColors.primaryLight.withValues(alpha: 0.4),
            ),
            dataRowMaxHeight: 75,
            columnSpacing: AppSizes.p24,
            columns: const [
              DataColumn(label: Text('Invoice Date', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Customer Details', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Service Type', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Details', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Amount', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
            ],
            rows: rows,
          ),
        ),
      ),
    );
  }
}

class _BillingRowData {
  final DateTime date;
  final String customerName;
  final String customerSub;
  final String serviceType;
  final String details;
  final double amount;
  final bool isPaid;
  final Future<void> Function() onMarkPaid;

  _BillingRowData({
    required this.date,
    required this.customerName,
    required this.customerSub,
    required this.serviceType,
    required this.details,
    required this.amount,
    required this.isPaid,
    required this.onMarkPaid,
  });
}

