import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../models/patient_model.dart';
import '../../../models/session_model.dart';
import '../../patients/providers/patients_provider.dart';
import '../../sessions/providers/sessions_provider.dart';

// Filter state: false = Unpaid Dues Only, true = Paid Only, null = All
final billingFilterProvider = StateProvider<bool?>((ref) => false);
final billingSearchProvider = StateProvider<String>((ref) => '');

class BillingScreen extends ConsumerWidget {
  const BillingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(sessionsStreamProvider);
    final patientsAsync = ref.watch(patientsStreamProvider);
    final textTheme = Theme.of(context).textTheme;

    final activeFilter = ref.watch(billingFilterProvider);
    final searchQuery = ref.watch(billingSearchProvider).toLowerCase().trim();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
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
              sessionsAsync.when(
                data: (sessions) {
                  final totalCharges = sessions.fold(0.0, (sum, s) => sum + s.charges);
                  final unpaidDues = sessions.where((s) => !s.paymentStatus).fold(0.0, (sum, s) => sum + s.charges);
                  final receivedRevenue = totalCharges - unpaidDues;

                  return LayoutBuilder(
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
                                      color: color.withOpacity(0.3),
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
                                      title,
                                      style: TextStyle(
                                        color: gradient == null ? AppColors.textSecondary : Colors.white.withOpacity(0.8),
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    AppSizes.h4,
                                    Text(
                                      value,
                                      style: TextStyle(
                                        color: gradient == null ? AppColors.textPrimary : Colors.white,
                                        fontSize: 22,
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

                      final totalCard = buildSummaryCard(
                        title: 'TOTAL BILLINGS',
                        value: 'Rs. ${NumberFormat('#,##0').format(totalCharges)}',
                        icon: Icons.receipt_long_rounded,
                        color: AppColors.primary,
                        gradient: null,
                      );

                      final receivedCard = buildSummaryCard(
                        title: 'REVENUE COLLECTED',
                        value: 'Rs. ${NumberFormat('#,##0').format(receivedRevenue)}',
                        icon: Icons.check_circle_rounded,
                        color: AppColors.success,
                        gradient: AppColors.dashboardCardGradient,
                      );

                      final pendingCard = buildSummaryCard(
                        title: 'PENDING DUES',
                        value: 'Rs. ${NumberFormat('#,##0').format(unpaidDues)}',
                        icon: Icons.pending_actions_rounded,
                        color: AppColors.warning,
                        gradient: null,
                      );

                      if (isNarrow) {
                        return Column(
                          children: [
                            totalCard,
                            AppSizes.h12,
                            receivedCard,
                            AppSizes.h12,
                            pendingCard,
                          ],
                        );
                      }

                      return Row(
                        children: [
                          Expanded(child: totalCard),
                          AppSizes.w16,
                          Expanded(child: receivedCard),
                          AppSizes.w16,
                          Expanded(child: pendingCard),
                        ],
                      );
                    },
                  );
                },
                loading: () => const LinearProgressIndicator(color: AppColors.primary),
                error: (e, s) => Container(),
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
                      // Filter toggle
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
                    ],
                  ),
                ),
              ),
              AppSizes.h20,

              // Invoices Grid/Table
              Expanded(
                child: sessionsAsync.when(
                  data: (sessions) {
                    return patientsAsync.when(
                      data: (patients) {
                        // Apply filters
                        var filtered = sessions;
                        if (activeFilter != null) {
                          filtered = filtered.where((s) => s.paymentStatus == activeFilter).toList();
                        }
                        if (searchQuery.isNotEmpty) {
                          filtered = filtered.where((s) {
                            final patient = patients.firstWhere(
                              (p) => p.patientId == s.patientId,
                              orElse: () => null as dynamic,
                            );
                            return patient.fullName.toLowerCase().contains(searchQuery);
                          }).toList();
                        }

                        if (filtered.isEmpty) {
                          return _buildEmptyState(context);
                        }

                        return _buildBillingTable(context, ref, filtered, patients);
                      },
                      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                      error: (err, stack) => Center(child: Text('Error: $err')),
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                  error: (err, stack) => Center(child: Text('Error: $err')),
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

  Widget _buildBillingTable(
    BuildContext context,
    WidgetRef ref,
    List<SessionModel> sessions,
    List<PatientModel> patients,
  ) {
    final formatter = DateFormat('dd MMM yyyy, hh:mm a');

    return Card(
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        child: SizedBox(
          width: double.infinity,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(AppColors.primaryLight.withOpacity(0.4)),
            dataRowMaxHeight: 75,
            columnSpacing: AppSizes.p24,
            columns: const [
              DataColumn(label: Text('Invoice Date', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Patient Details', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Treatment Summary', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Amount Charged', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Payment Status', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
            ],
            rows: sessions.map((session) {
              final patient = patients.firstWhere(
                (p) => p.patientId == session.patientId,
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

              return DataRow(
                cells: [
                  DataCell(
                    Text(
                      formatter.format(session.sessionDate),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                  DataCell(
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          patient.fullName,
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                        Text(
                          'Phone: ${patient.phone}',
                          style: const TextStyle(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  DataCell(
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 260),
                      child: Text(
                        session.treatmentNotes,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      'Rs. ${NumberFormat('#,##0').format(session.charges)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                  ),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: (session.paymentStatus ? AppColors.success : AppColors.error).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
                      ),
                      child: Text(
                        session.paymentStatus ? 'Paid' : 'Unpaid',
                        style: TextStyle(
                          color: session.paymentStatus ? AppColors.success : AppColors.error,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                  DataCell(
                    session.paymentStatus
                        ? const Icon(Icons.check_circle_outline_rounded, color: AppColors.success, size: 22)
                        : ElevatedButton.icon(
                            onPressed: () async {
                              final updatedSession = session.copyWith(paymentStatus: true);
                              await ref.read(sessionOperationProvider.notifier).updateSession(updatedSession);
                            },
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
            }).toList(),
          ),
        ),
      ),
    );
  }
}
