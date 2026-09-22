import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../models/patient_model.dart';
import '../providers/patients_provider.dart';

class PatientsScreen extends ConsumerWidget {
  const PatientsScreen({super.key});

  void _showDeleteConfirmation(BuildContext context, WidgetRef ref, PatientModel patient) {
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
        content: RichText(
          text: TextSpan(
            style: Theme.of(context).textTheme.bodyLarge,
            children: [
              const TextSpan(text: 'Are you sure you want to delete patient '),
              TextSpan(
                text: patient.fullName,
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const TextSpan(text: '?\n\nThis will permanently delete the patient and '),
              const TextSpan(
                text: 'ALL associated therapy sessions and logs.',
                style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.error),
              ),
              const TextSpan(text: ' This action cannot be undone.'),
            ],
          ),
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
              await ref.read(patientOperationProvider.notifier).deletePatient(patient.patientId);
              
              final state = ref.read(patientOperationProvider);
              if (state.error != null) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Failed to delete: ${state.error}'),
                    backgroundColor: AppColors.error,
                  ),
                );
              } else {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Patient ${patient.fullName} deleted successfully.'),
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
    final filteredPatientsAsync = ref.watch(filteredPatientsProvider);
    final textTheme = Theme.of(context).textTheme;
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
              // Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Patient Registry',
                        style: textTheme.displaySmall?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      AppSizes.h4,
                      Text(
                        'Register, search, and manage clinic patient records',
                        style: textTheme.bodyMedium,
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: () => context.go('/patients/add'),
                    icon: const Icon(Icons.person_add_alt_1_rounded, size: 20),
                    label: const Text('Register Patient'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: AppSizes.p20, vertical: 16),
                    ),
                  ),
                ],
              ),
              AppSizes.h24,

              // Search & Filter Block
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSizes.p16),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          onChanged: (val) => ref.read(searchFilterProvider.notifier).state = val,
                          decoration: InputDecoration(
                            hintText: 'Search patients by name, phone, or condition...',
                            prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textSecondary),
                            suffixIcon: ref.watch(searchFilterProvider).isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear_rounded, color: AppColors.textSecondary),
                                    onPressed: () {
                                      ref.read(searchFilterProvider.notifier).state = '';
                                    },
                                  )
                                : null,
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
                    ],
                  ),
                ),
              ),
              AppSizes.h20,

              // Main List/Table Content
              Expanded(
                child: filteredPatientsAsync.when(
                  data: (patients) {
                    if (patients.isEmpty) {
                      return _buildEmptyState(context);
                    }
                    return isMobile ? _buildMobileCards(context, ref, patients) : _buildDesktopTable(context, ref, patients);
                  },
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                  error: (err, stack) => Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 48),
                        AppSizes.h16,
                        Text('Error loading patients', style: textTheme.headlineMedium),
                        AppSizes.h8,
                        Text(err.toString(), style: textTheme.bodyMedium),
                      ],
                    ),
                  ),
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
              Icons.people_outline_rounded,
              color: AppColors.primary,
              size: 54,
            ),
          ),
          AppSizes.h24,
          Text(
            'No Patients Found',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
          ),
          AppSizes.h8,
          Text(
            'Try adjusting your search filter or add a new patient to get started.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopTable(BuildContext context, WidgetRef ref, List<PatientModel> patients) {
    final formatter = DateFormat('dd MMM yyyy');

    return Card(
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: SizedBox(
          width: double.infinity,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(AppColors.primaryLight.withValues(alpha: 0.4)),
            dataRowMaxHeight: 70,
            columnSpacing: AppSizes.p20,
            columns: const [
              DataColumn(label: Text('ID', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Name', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Age / Gender', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Phone', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Condition', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Reg. Date', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
            ],
            rows: patients.map((patient) {
              return DataRow(
                cells: [
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
                          ),
                          child: Text(
                            patient.patientId,
                            style: const TextStyle(
                              color: AppColors.primaryDark,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        if (patient.customerType == 'massage_chair') ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF3E0),
                              borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.chair_rounded, size: 12, color: Color(0xFFE65100)),
                                SizedBox(width: 3),
                                Text(
                                  'Massage',
                                  style: TextStyle(
                                    color: Color(0xFFE65100),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  DataCell(
                    Text(
                      patient.fullName,
                      style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    ),
                  ),
                  DataCell(Text('${patient.age} yrs / ${patient.gender}')),
                  DataCell(Text(patient.phone)),
                  DataCell(
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 220),
                      child: Text(
                        patient.medicalCondition,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
                  DataCell(Text(formatter.format(patient.registrationDate))),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'View Patient History',
                          icon: const Icon(Icons.visibility_outlined, color: AppColors.primary),
                          onPressed: () => context.go('/patients/${patient.patientId}'),
                        ),
                        IconButton(
                          tooltip: 'Edit Details',
                          icon: const Icon(Icons.edit_outlined, color: AppColors.secondary),
                          onPressed: () => context.go('/patients/edit/${patient.patientId}', extra: patient),
                        ),
                        IconButton(
                          tooltip: 'Delete Patient',
                          icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                          onPressed: () => _showDeleteConfirmation(context, ref, patient),
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

  Widget _buildMobileCards(BuildContext context, WidgetRef ref, List<PatientModel> patients) {
    final formatter = DateFormat('dd MMM yyyy');

    return ListView.builder(
      itemCount: patients.length,
      itemBuilder: (context, index) {
        final patient = patients[index];
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
                    Text(
                      patient.fullName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
                      ),
                      child: Text(
                        patient.patientId,
                        style: const TextStyle(
                          color: AppColors.primaryDark,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    if (patient.customerType == 'massage_chair') ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF3E0),
                          borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.chair_rounded, size: 12, color: Color(0xFFE65100)),
                            SizedBox(width: 3),
                            Text(
                              'Massage',
                              style: TextStyle(
                                color: Color(0xFFE65100),
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                AppSizes.h8,
                Text(
                  '${patient.age} years  •  ${patient.gender}',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
                AppSizes.h4,
                Text(
                  'Phone: ${patient.phone}',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
                AppSizes.h8,
                const Divider(),
                AppSizes.h8,
                const Text(
                  'Medical Condition:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                ),
                Text(
                  patient.medicalCondition,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
                ),
                AppSizes.h4,
                Text(
                  'Registered: ${formatter.format(patient.registrationDate)}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textLight),
                ),
                AppSizes.h12,
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => context.go('/patients/${patient.patientId}'),
                      icon: const Icon(Icons.visibility_outlined, size: 16),
                      label: const Text('History'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: AppSizes.p12, vertical: 8),
                      ),
                    ),
                    AppSizes.w8,
                    OutlinedButton.icon(
                      onPressed: () => context.go('/patients/edit/${patient.patientId}', extra: patient),
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text('Edit'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: AppSizes.p12, vertical: 8),
                      ),
                    ),
                    AppSizes.w8,
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                      onPressed: () => _showDeleteConfirmation(context, ref, patient),
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
