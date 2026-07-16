import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../models/patient_model.dart';
import '../../../models/session_model.dart';
import '../../patients/providers/patients_provider.dart';
import '../providers/sessions_provider.dart';

class SessionsScreen extends ConsumerWidget {
  const SessionsScreen({super.key});

  void _showDeleteConfirmation(BuildContext context, WidgetRef ref, SessionModel session, String patientName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.error),
            AppSizes.w8,
            const Text('Confirm Deletion'),
          ],
        ),
        content: Text(
          'Are you sure you want to delete the session logged on ${DateFormat('dd MMM yyyy').format(session.sessionDate)} for $patientName?\n\nThis will permanently delete this record. This action cannot be undone.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final messenger = ScaffoldMessenger.of(context);
              await ref.read(sessionOperationProvider.notifier).deleteSession(session.sessionId);
              
              final state = ref.read(sessionOperationProvider);
              if (state.error != null) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Failed to delete session: ${state.error}'),
                    backgroundColor: AppColors.error,
                  ),
                );
              } else {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Session log deleted successfully.'),
                    backgroundColor: AppColors.success,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filteredSessionsAsync = ref.watch(filteredSessionsProvider);
    final patientsAsync = ref.watch(patientsStreamProvider);
    final textTheme = Theme.of(context).textTheme;

    final selectedPatient = ref.watch(selectedPatientFilterProvider);
    final selectedPaymentStatus = ref.watch(paymentStatusFilterProvider);

    final size = MediaQuery.of(context).size;
    final isMobile = size.width < AppSizes.tabletBreakpoint;

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
                        'Therapy Session Logs',
                        style: textTheme.displaySmall?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      AppSizes.h4,
                      Text(
                        'Review, filter, and record all clinical therapist treatment records',
                        style: textTheme.bodyMedium,
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: () => context.go('/sessions/add'),
                    icon: const Icon(Icons.add_task_rounded, size: 20),
                    label: const Text('Record Session'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: AppSizes.p20, vertical: 16),
                    ),
                  ),
                ],
              ),
              AppSizes.h24,

              // Filters Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSizes.p16),
                  child: Wrap(
                    spacing: AppSizes.p16,
                    runSpacing: AppSizes.p12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // Patient Filter Dropdown
                      patientsAsync.when(
                        data: (patients) {
                          return Container(
                            width: 250,
                            padding: const EdgeInsets.symmetric(horizontal: AppSizes.p12),
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String?>(
                                value: selectedPatient,
                                isExpanded: true,
                                hint: const Text('Filter by Patient'),
                                onChanged: (val) {
                                  ref.read(selectedPatientFilterProvider.notifier).state = val;
                                },
                                items: [
                                  const DropdownMenuItem(value: null, child: Text('All Patients')),
                                  ...patients.map((p) {
                                    return DropdownMenuItem(
                                      value: p.patientId,
                                      child: Text(p.fullName),
                                    );
                                  }),
                                ],
                              ),
                            ),
                          );
                        },
                        loading: () => const SizedBox(width: 250, height: 40, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
                        error: (e, s) => const Text('Error loading filter'),
                      ),

                      // Payment Status Filter Dropdown
                      Container(
                        width: 200,
                        padding: const EdgeInsets.symmetric(horizontal: AppSizes.p12),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<bool?>(
                            value: selectedPaymentStatus,
                            isExpanded: true,
                            hint: const Text('Filter by Payment'),
                            onChanged: (val) {
                              ref.read(paymentStatusFilterProvider.notifier).state = val;
                            },
                            items: const [
                              DropdownMenuItem(value: null, child: Text('All Payment Statuses')),
                              DropdownMenuItem(value: true, child: Text('Paid Sessions Only')),
                              DropdownMenuItem(value: false, child: Text('Unpaid Sessions Only')),
                            ],
                          ),
                        ),
                      ),

                      // Clear Filters Button
                      if (selectedPatient != null || selectedPaymentStatus != null) ...[
                        TextButton.icon(
                          onPressed: () {
                            ref.read(selectedPatientFilterProvider.notifier).state = null;
                            ref.read(paymentStatusFilterProvider.notifier).state = null;
                          },
                          icon: const Icon(Icons.clear_rounded, size: 16),
                          label: const Text('Reset Filters'),
                          style: TextButton.styleFrom(foregroundColor: AppColors.error),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              AppSizes.h20,

              // Main List
              Expanded(
                child: filteredSessionsAsync.when(
                  data: (sessions) {
                    return patientsAsync.when(
                      data: (patients) {
                        if (sessions.isEmpty) {
                          return _buildEmptyState(context);
                        }
                        return isMobile 
                            ? _buildMobileSessions(context, ref, sessions, patients) 
                            : _buildDesktopSessionsTable(context, ref, sessions, patients);
                      },
                      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                      error: (err, stack) => Center(child: Text('Error loading patient mappings: $err')),
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                  error: (err, stack) => Center(child: Text('Error loading sessions: $err')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSizes.p24),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.history_edu_rounded,
              color: AppColors.primary,
              size: 54,
            ),
          ),
          AppSizes.h24,
          Text(
            'No Session Records Found',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
          ),
          AppSizes.h8,
          Text(
            'Create a new session record or adjust filters to begin clinical tracking.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopSessionsTable(
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
            dataRowMaxHeight: 80,
            columnSpacing: AppSizes.p24,
            columns: const [
              DataColumn(label: Text('Date & Time', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Patient Name', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Therapist', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Treatment summary', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Charges', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
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
                          patient.patientId,
                          style: const TextStyle(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  DataCell(
                    Text(
                      session.therapistName ?? 'Unknown',
                      style: const TextStyle(fontWeight: FontWeight.w500, color: AppColors.textPrimary),
                    ),
                  ),
                  DataCell(
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 320),
                      child: Text(
                        session.treatmentNotes,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, height: 1.3),
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
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Edit Session Log',
                          icon: const Icon(Icons.edit_outlined, color: AppColors.secondary),
                          onPressed: () => context.go('/sessions/edit/${session.sessionId}', extra: session),
                        ),
                        IconButton(
                          tooltip: 'Delete Log',
                          icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                          onPressed: () => _showDeleteConfirmation(context, ref, session, patient.fullName),
                        ),
                      ],
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

  Widget _buildMobileSessions(
    BuildContext context,
    WidgetRef ref,
    List<SessionModel> sessions,
    List<PatientModel> patients,
  ) {
    final formatter = DateFormat('dd MMM yyyy, hh:mm a');

    return ListView.builder(
      itemCount: sessions.length,
      itemBuilder: (context, index) {
        final session = sessions[index];
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

        return Card(
          margin: const EdgeInsets.only(bottom: AppSizes.p12),
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.p16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            patient.fullName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary),
                          ),
                          AppSizes.h4,
                          Text(
                            'Therapist: ${session.therapistName ?? 'Unknown'}',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                  ],
                ),
                AppSizes.h8,
                Text(
                  formatter.format(session.sessionDate),
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
                ),
                AppSizes.h8,
                const Divider(),
                AppSizes.h8,
                const Text(
                  'Treatment notes:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.textSecondary),
                ),
                Text(
                  session.treatmentNotes,
                  style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, height: 1.4),
                ),
                if (session.nextRecommendation.isNotEmpty) ...[
                  AppSizes.h8,
                  Text(
                    'Recommendation: ${session.nextRecommendation}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                  ),
                ],
                AppSizes.h12,
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Charges: Rs. ${NumberFormat('#,##0').format(session.charges)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, color: AppColors.secondary, size: 20),
                          onPressed: () => context.go('/sessions/edit/${session.sessionId}', extra: session),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
                          onPressed: () => _showDeleteConfirmation(context, ref, session, patient.fullName),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
