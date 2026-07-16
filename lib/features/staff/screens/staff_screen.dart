import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../models/user_model.dart';
import '../../../models/patient_model.dart';
import '../../../models/reassignment_log_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../patients/providers/patients_provider.dart';
import '../providers/staff_provider.dart';
import '../providers/reassignment_provider.dart';

class StaffScreen extends ConsumerWidget {
  const StaffScreen({super.key});

  // ─────────────────────────────────────────────────────────────
  // Confirmation dialog — describes exactly what will happen
  // ─────────────────────────────────────────────────────────────
  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    UserModel staff,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.radiusLarge)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person_remove_rounded, color: AppColors.error, size: 22),
            ),
            AppSizes.w12,
            const Expanded(
              child: Text(
                'Delete Staff Account',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(
              text: TextSpan(
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, height: 1.5),
                children: [
                  const TextSpan(text: 'You are about to deactivate the account of\n'),
                  TextSpan(
                    text: staff.fullName,
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                  ),
                  TextSpan(
                    text: ' (${staff.email}).',
                  ),
                ],
              ),
            ),
            AppSizes.h16,
            _infoRow(Icons.check_circle_outline, AppColors.success, 'All patient records remain intact'),
            _infoRow(Icons.check_circle_outline, AppColors.success, 'Session & billing history preserved'),
            _infoRow(Icons.check_circle_outline, AppColors.success, 'Salary & revenue records kept'),
            _infoRow(Icons.cancel_outlined, AppColors.error, 'Staff member can no longer log in'),
            AppSizes.h16,
            Container(
              padding: const EdgeInsets.all(AppSizes.p12),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.08),
                borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
                border: Border.all(color: AppColors.warning.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: AppColors.warning, size: 16),
                  AppSizes.w8,
                  const Expanded(
                    child: Text(
                      'This is a soft-delete. The account is deactivated, not permanently removed.',
                      style: TextStyle(color: AppColors.warning, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(ctx).pop(true),
            icon: const Icon(Icons.delete_rounded, size: 16),
            label: const Text('Delete Account'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      final staffService = ref.read(staffServiceProvider);
      final adminUser = ref.read(authProvider).userModel;
      if (adminUser == null) throw Exception('Admin session expired. Please log in again.');
      await staffService.deleteStaff(staff, adminUser);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${staff.fullName}\'s account has been deactivated.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  static Widget _infoRow(IconData icon, Color color, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          AppSizes.w8,
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Trigger auto reversion check for expired reassignments
    ref.watch(autoReversionCheckerProvider);

    final staffAsync = ref.watch(staffProvider);
    final textTheme = Theme.of(context).textTheme;
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < AppSizes.tabletBreakpoint;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
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
                          'Staff & Reassignment',
                          style: textTheme.displaySmall?.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        AppSizes.h4,
                        Text(
                          'Manage clinic therapists and temporary patient reassignments',
                          style: textTheme.bodyMedium,
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      onPressed: () => context.go('/staff/add'),
                      icon: const Icon(Icons.person_add_alt_1_rounded, size: 20),
                      label: const Text('Add Staff'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(horizontal: AppSizes.p20, vertical: 16),
                      ),
                    ),
                  ],
                ),
                AppSizes.h12,

                // TabBar
                const TabBar(
                  tabs: [
                    Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.people_outline_rounded, size: 18),
                          SizedBox(width: 8),
                          Text('Staff Directory'),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.swap_horiz_rounded, size: 18),
                          SizedBox(width: 8),
                          Text('Temporary Reassignments'),
                        ],
                      ),
                    ),
                  ],
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textSecondary,
                  indicatorColor: AppColors.primary,
                  indicatorWeight: 3,
                ),
                AppSizes.h24,

                // TabBarView Content
                Expanded(
                  child: TabBarView(
                    children: [
                      // Tab 1: Staff Directory List
                      staffAsync.when(
                        data: (staffList) {
                          if (staffList.isEmpty) {
                            return _buildEmptyState(context);
                          }
                          return isMobile
                              ? _buildMobileCards(context, ref, staffList)
                              : _buildDesktopTable(context, ref, staffList);
                        },
                        loading: () => const Center(
                          child: CircularProgressIndicator(color: AppColors.primary),
                        ),
                        error: (err, stack) => _buildErrorState(textTheme, err),
                      ),

                      // Tab 2: Temporary Reassignments
                      _buildTemporaryReassignmentsTab(context, ref, isMobile),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(TextTheme textTheme, Object err) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 48),
          AppSizes.h16,
          Text('Error loading staff', style: textTheme.headlineMedium),
          AppSizes.h8,
          Text(err.toString(), style: textTheme.bodyMedium),
        ],
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
            'No Staff Found',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
          ),
          AppSizes.h8,
          Text(
            'Click on "Add Staff" to register a new therapist.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Desktop DataTable (Tab 1)
  // ─────────────────────────────────────────────────────────────
  Widget _buildDesktopTable(BuildContext context, WidgetRef ref, List<UserModel> staffList) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: SizedBox(
          width: double.infinity,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(AppColors.primaryLight.withOpacity(0.4)),
            dataRowMaxHeight: 70,
            columnSpacing: AppSizes.p20,
            columns: const [
              DataColumn(label: Text('Name', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Email', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Phone', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Specialization', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Revenue %', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
            ],
            rows: staffList.map((staff) {
              return DataRow(
                cells: [
                  DataCell(
                    Text(
                      staff.fullName,
                      style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    ),
                  ),
                  DataCell(Text(staff.email)),
                  DataCell(Text(staff.phone)),
                  DataCell(Text(staff.specialization.isEmpty ? '-' : staff.specialization)),
                  DataCell(Text('${staff.revenuePercentage.toStringAsFixed(0)}%')),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: staff.status == 'Active'
                            ? AppColors.success.withOpacity(0.2)
                            : AppColors.error.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
                      ),
                      child: Text(
                        staff.status,
                        style: TextStyle(
                          color: staff.status == 'Active' ? AppColors.success : AppColors.error,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Edit button
                        IconButton(
                          tooltip: 'Edit Staff Details',
                          icon: const Icon(Icons.edit_outlined, color: AppColors.secondary),
                          onPressed: () => context.go('/staff/edit/${staff.userId}', extra: staff),
                        ),
                        // Delete button
                        IconButton(
                          tooltip: 'Delete Staff Account',
                          icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                          onPressed: () => _confirmDelete(context, ref, staff),
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

  // ─────────────────────────────────────────────────────────────
  // Mobile Card List (Tab 1)
  // ─────────────────────────────────────────────────────────────
  Widget _buildMobileCards(BuildContext context, WidgetRef ref, List<UserModel> staffList) {
    return ListView.builder(
      itemCount: staffList.length,
      itemBuilder: (context, index) {
        final staff = staffList[index];
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
                      child: Text(
                        staff.fullName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: staff.status == 'Active'
                            ? AppColors.success.withOpacity(0.2)
                            : AppColors.error.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
                      ),
                      child: Text(
                        staff.status,
                        style: TextStyle(
                          color: staff.status == 'Active' ? AppColors.success : AppColors.error,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
                AppSizes.h8,
                Text(
                  'Email: ${staff.email}',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
                AppSizes.h4,
                Text(
                  'Phone: ${staff.phone}',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
                AppSizes.h8,
                const Divider(),
                AppSizes.h8,
                Text(
                  'Specialization: ${staff.specialization}',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
                ),
                AppSizes.h4,
                Text(
                  'Revenue Percentage: ${staff.revenuePercentage.toStringAsFixed(0)}%',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
                ),
                AppSizes.h12,
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => context.go('/staff/edit/${staff.userId}', extra: staff),
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text('Edit'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: AppSizes.p12, vertical: 8),
                      ),
                    ),
                    AppSizes.w8,
                    OutlinedButton.icon(
                      onPressed: () => _confirmDelete(context, ref, staff),
                      icon: const Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.error),
                      label: const Text('Delete', style: TextStyle(color: AppColors.error)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: AppSizes.p12, vertical: 8),
                        side: const BorderSide(color: AppColors.error),
                      ),
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

  // ─────────────────────────────────────────────────────────────
  // Temporary Reassignments Tab (Tab 2)
  // ─────────────────────────────────────────────────────────────
  Widget _buildTemporaryReassignmentsTab(
    BuildContext context,
    WidgetRef ref,
    bool isMobile,
  ) {
    final patientsAsync = ref.watch(allPatientsStreamProvider);
    final logsAsync = ref.watch(reassignmentLogsStreamProvider);
    final staffAsync = ref.watch(staffProvider);

    return patientsAsync.when(
      data: (patients) {
        final activeReassignedPatients = patients.where((p) => p.isTemporarilyReassigned == true).toList();
        final activeStaff = staffAsync.valueOrNull?.where((u) => u.status == 'Active').toList() ?? [];

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Operations Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Active Reassignments',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  ElevatedButton.icon(
                    onPressed: activeStaff.length < 2
                        ? null
                        : () => _showReassignDialog(context, ref, activeStaff, patients),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('New Temporary Reassignment'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ],
              ),
              AppSizes.h16,

              // Active Reassignments Table/Cards
              if (activeReassignedPatients.isEmpty)
                _buildCardPlaceholder(context, 'No Active Temporary Reassignments', 'All patients are currently assigned to their original therapists.')
              else if (isMobile)
                _buildActiveReassignmentsMobile(context, ref, activeReassignedPatients, logsAsync.valueOrNull ?? [])
              else
                _buildActiveReassignmentsDesktop(context, ref, activeReassignedPatients, logsAsync.valueOrNull ?? []),

              AppSizes.h32,
              const Divider(),
              AppSizes.h24,

              // Audit Trail History
              const Text(
                'Reassignment Audit Trail',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              AppSizes.h16,

              logsAsync.when(
                data: (logs) {
                  if (logs.isEmpty) {
                    return _buildCardPlaceholder(context, 'Audit History Empty', 'Reassignment logs will populate here as assignments are managed.');
                  }
                  return isMobile 
                      ? _buildAuditTrailMobile(context, logs) 
                      : _buildAuditTrailDesktop(context, logs);
                },
                loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                error: (e, s) => Text('Error loading logs: $e', style: const TextStyle(color: AppColors.error)),
              ),
              AppSizes.h32,
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      error: (e, s) => Text('Error loading patients data: $e', style: const TextStyle(color: AppColors.error)),
    );
  }

  Widget _buildCardPlaceholder(BuildContext context, String title, String subtitle) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSizes.p32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const Icon(Icons.info_outline_rounded, color: AppColors.textSecondary, size: 36),
          AppSizes.h12,
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 15)),
          AppSizes.h4,
          Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        ],
      ),
    );
  }

  // Active Reassignments layouts
  Widget _buildActiveReassignmentsDesktop(
    BuildContext context,
    WidgetRef ref,
    List<PatientModel> patients,
    List<ReassignmentLogModel> logs,
  ) {
    final dateFormat = DateFormat('dd MMM yyyy');
    return Card(
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: double.infinity,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(AppColors.primaryLight.withOpacity(0.4)),
          dataRowMaxHeight: 65,
          columns: const [
            DataColumn(label: Text('Patient', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Original Therapist', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Temporary Therapist', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Assignment Date', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Effective Period', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Action', style: TextStyle(fontWeight: FontWeight.bold))),
          ],
          rows: patients.map((patient) {
            final activeLog = logs.firstWhere(
              (l) => l.patientId == patient.patientId && l.revertDate == null,
              orElse: () => ReassignmentLogModel(
                reassignmentId: '',
                patientId: patient.patientId,
                patientName: patient.fullName,
                originalTherapistId: patient.assignedTherapistId ?? '',
                originalTherapistName: patient.assignedTherapistName ?? 'Unknown',
                temporaryTherapistId: patient.tempTherapistId ?? '',
                temporaryTherapistName: patient.tempTherapistName ?? 'Unknown',
                assignedById: '',
                assignedByName: '',
                assignmentDate: patient.tempAssignmentDate ?? DateTime.now(),
              ),
            );

            final periodText = (patient.tempAssignmentStartDate != null && patient.tempAssignmentEndDate != null)
                ? '${dateFormat.format(patient.tempAssignmentStartDate!)} - ${dateFormat.format(patient.tempAssignmentEndDate!)}'
                : 'Manual Revert';

            return DataRow(
              cells: [
                DataCell(Text(patient.fullName, style: const TextStyle(fontWeight: FontWeight.bold))),
                DataCell(Text(activeLog.originalTherapistName)),
                DataCell(Text(patient.tempTherapistName ?? 'Unknown', style: const TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.w600))),
                DataCell(Text(patient.tempAssignmentDate != null ? dateFormat.format(patient.tempAssignmentDate!) : '-')),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: patient.tempAssignmentEndDate != null ? Colors.blue.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
                    ),
                    child: Text(
                      periodText,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: patient.tempAssignmentEndDate != null ? Colors.blue[900] : Colors.grey[800],
                      ),
                    ),
                  ),
                ),
                DataCell(
                  ElevatedButton(
                    onPressed: () => _handleRevert(context, ref, patient, activeLog),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      minimumSize: Size.zero,
                    ),
                    child: const Text('Revert', style: TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildActiveReassignmentsMobile(
    BuildContext context,
    WidgetRef ref,
    List<PatientModel> patients,
    List<ReassignmentLogModel> logs,
  ) {
    final dateFormat = DateFormat('dd MMM yyyy');
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: patients.length,
      itemBuilder: (context, index) {
        final patient = patients[index];
        final activeLog = logs.firstWhere(
          (l) => l.patientId == patient.patientId && l.revertDate == null,
          orElse: () => ReassignmentLogModel(
            reassignmentId: '',
            patientId: patient.patientId,
            patientName: patient.fullName,
            originalTherapistId: patient.assignedTherapistId ?? '',
            originalTherapistName: patient.assignedTherapistName ?? 'Unknown',
            temporaryTherapistId: patient.tempTherapistId ?? '',
            temporaryTherapistName: patient.tempTherapistName ?? 'Unknown',
            assignedById: '',
            assignedByName: '',
            assignmentDate: patient.tempAssignmentDate ?? DateTime.now(),
          ),
        );

        final periodText = (patient.tempAssignmentStartDate != null && patient.tempAssignmentEndDate != null)
            ? '${dateFormat.format(patient.tempAssignmentStartDate!)} - ${dateFormat.format(patient.tempAssignmentEndDate!)}'
            : 'Manual Revert';

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.p16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(patient.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    ElevatedButton(
                      onPressed: () => _handleRevert(context, ref, patient, activeLog),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        minimumSize: Size.zero,
                      ),
                      child: const Text('Revert', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
                AppSizes.h8,
                Text('Original: ${activeLog.originalTherapistName}', style: const TextStyle(fontSize: 13)),
                AppSizes.h4,
                Text('Temporary: ${patient.tempTherapistName}', style: const TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.bold)),
                AppSizes.h8,
                const Divider(),
                AppSizes.h8,
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Assigned: ${patient.tempAssignmentDate != null ? dateFormat.format(patient.tempAssignmentDate!) : "-"}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    Text(periodText, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleRevert(
    BuildContext context,
    WidgetRef ref,
    PatientModel patient,
    ReassignmentLogModel log,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Revert Patient Assignment'),
        content: Text('Are you sure you want to return patient "${patient.fullName}" back to their original therapist "${log.originalTherapistName}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
            child: const Text('Confirm Return'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final adminUser = ref.read(authProvider).userModel;
    if (adminUser == null) return;

    final messenger = ScaffoldMessenger.of(context);
    await ref.read(reassignmentOperationProvider.notifier).revertReassignment(
      patient: patient,
      log: log,
      adminUser: adminUser,
    );

    final state = ref.read(reassignmentOperationProvider);
    if (state.error != null) {
      messenger.showSnackBar(
        SnackBar(content: Text('Error reverting assignment: ${state.error}'), backgroundColor: AppColors.error),
      );
    } else {
      messenger.showSnackBar(
        const SnackBar(content: Text('Patient successfully returned to original therapist.'), backgroundColor: AppColors.success),
      );
    }
  }

  // Audit Trail Table Layouts
  Widget _buildAuditTrailDesktop(BuildContext context, List<ReassignmentLogModel> logs) {
    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');
    return Card(
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: double.infinity,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(AppColors.primaryLight.withOpacity(0.2)),
          dataRowMaxHeight: 65,
          columnSpacing: 12,
          columns: const [
            DataColumn(label: Text('Patient', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Original', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Temporary', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Assigned By', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Assign Date', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Revert Date', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Reason', style: TextStyle(fontWeight: FontWeight.bold))),
          ],
          rows: logs.map((log) {
            final isReverted = log.revertDate != null;
            return DataRow(
              cells: [
                DataCell(Text(log.patientName, style: const TextStyle(fontWeight: FontWeight.bold))),
                DataCell(Text(log.originalTherapistName)),
                DataCell(Text(log.temporaryTherapistName)),
                DataCell(Text(log.assignedByName)),
                DataCell(Text(dateFormat.format(log.assignmentDate))),
                DataCell(Text(isReverted ? dateFormat.format(log.revertDate!) : '-')),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: (isReverted ? AppColors.success : AppColors.warning).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
                    ),
                    child: Text(
                      isReverted ? 'Reverted' : 'Active',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isReverted ? AppColors.success : AppColors.warning,
                      ),
                    ),
                  ),
                ),
                DataCell(
                  Tooltip(
                    message: log.reason ?? 'No reason provided',
                    child: Text(
                      log.reason == null || log.reason!.isEmpty ? '-' : log.reason!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildAuditTrailMobile(BuildContext context, List<ReassignmentLogModel> logs) {
    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: logs.length,
      itemBuilder: (context, index) {
        final log = logs[index];
        final isReverted = log.revertDate != null;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.p16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(log.patientName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: (isReverted ? AppColors.success : AppColors.warning).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
                      ),
                      child: Text(
                        isReverted ? 'Reverted' : 'Active',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: isReverted ? AppColors.success : AppColors.warning,
                        ),
                      ),
                    ),
                  ],
                ),
                AppSizes.h8,
                Row(
                  children: [
                    Expanded(child: Text('From: ${log.originalTherapistName}', style: const TextStyle(fontSize: 12))),
                    Expanded(child: Text('To: ${log.temporaryTherapistName}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                  ],
                ),
                AppSizes.h8,
                const Divider(),
                AppSizes.h8,
                Text('Assigned By: ${log.assignedByName} on ${dateFormat.format(log.assignmentDate)}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                if (isReverted)
                  Text('Reverted On: ${dateFormat.format(log.revertDate!)}', style: const TextStyle(fontSize: 11, color: AppColors.success, fontWeight: FontWeight.bold)),
                if (log.reason != null && log.reason!.isNotEmpty) ...[
                  AppSizes.h8,
                  Text('Reason: ${log.reason}', style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppColors.textSecondary)),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  // Temporary Reassign dialog wizard
  void _showReassignDialog(
    BuildContext context,
    WidgetRef ref,
    List<UserModel> therapists,
    List<PatientModel> allPatients,
  ) {
    UserModel? selectedLeaveTherapist;
    UserModel? selectedTempTherapist;
    List<PatientModel> originalPatients = [];
    final List<String> selectedPatientIds = [];
    DateTimeRange? selectedDateRange;
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final dateFormat = DateFormat('dd MMM yyyy');

            // Pick Date range
            Future<void> pickDateRange() async {
              final picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 90)),
                builder: (context, child) {
                  return Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: const ColorScheme.light(
                        primary: AppColors.primary,
                        onPrimary: Colors.white,
                        onSurface: AppColors.textPrimary,
                      ),
                    ),
                    child: child!,
                  );
                },
              );

              if (picked != null) {
                setModalState(() {
                  selectedDateRange = picked;
                });
              }
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.radiusLarge)),
              title: Row(
                children: [
                  const Icon(Icons.swap_horiz_rounded, color: AppColors.primary, size: 24),
                  AppSizes.w8,
                  const Text('Setup Temporary Reassignment', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SizedBox(
                width: 600,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Leave Therapist Selector
                      const Text(
                        'Select Therapist Going on Leave *',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                      ),
                      AppSizes.h8,
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          border: Border.all(color: AppColors.border),
                          borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<UserModel>(
                            value: selectedLeaveTherapist,
                            isExpanded: true,
                            hint: const Text('Select a therapist'),
                            onChanged: (UserModel? therapist) {
                              if (therapist == null) return;
                              setModalState(() {
                                selectedLeaveTherapist = therapist;
                                // Reset selection
                                selectedPatientIds.clear();
                                // Load original therapist's patients who are not already temporarily reassigned
                                originalPatients = allPatients
                                    .where((p) => p.assignedTherapistId == therapist.userId && p.isTemporarilyReassigned != true)
                                    .toList();
                                // Reset temporary therapist if it is the same as leave therapist
                                if (selectedTempTherapist?.userId == therapist.userId) {
                                  selectedTempTherapist = null;
                                }
                              });
                            },
                            items: therapists.map((t) {
                              return DropdownMenuItem(
                                value: t,
                                child: Text('${t.fullName} (${t.specialization})'),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                      AppSizes.h16,

                      // 2. Patient Checklist
                      if (selectedLeaveTherapist != null) ...[
                        const Text(
                          'Select Patients to Reassign *',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                        ),
                        AppSizes.h8,
                        if (originalPatients.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8.0),
                            child: Text(
                              'No active patients found assigned to this therapist.',
                              style: TextStyle(color: AppColors.error, fontSize: 13, fontStyle: FontStyle.italic),
                            ),
                          )
                        else
                          Container(
                            height: 150,
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              border: Border.all(color: AppColors.border),
                              borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                            ),
                            child: ListView.builder(
                              itemCount: originalPatients.length,
                              itemBuilder: (ctx, i) {
                                final p = originalPatients[i];
                                final isChecked = selectedPatientIds.contains(p.patientId);
                                return CheckboxListTile(
                                  title: Text(p.fullName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                  subtitle: Text('Condition: ${p.medicalCondition}', style: const TextStyle(fontSize: 11)),
                                  value: isChecked,
                                  onChanged: (val) {
                                    setModalState(() {
                                      if (val == true) {
                                        selectedPatientIds.add(p.patientId);
                                      } else {
                                        selectedPatientIds.remove(p.patientId);
                                      }
                                    });
                                  },
                                );
                              },
                            ),
                          ),
                        AppSizes.h16,
                      ],

                      // 3. Temp Therapist Selector
                      if (selectedLeaveTherapist != null) ...[
                        const Text(
                          'Select Temporary Therapist *',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                        ),
                        AppSizes.h8,
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            border: Border.all(color: AppColors.border),
                            borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<UserModel>(
                              value: selectedTempTherapist,
                              isExpanded: true,
                              hint: const Text('Choose substitute therapist'),
                              onChanged: (UserModel? therapist) {
                                setModalState(() {
                                  selectedTempTherapist = therapist;
                                });
                              },
                              items: therapists
                                  .where((t) => t.userId != selectedLeaveTherapist!.userId)
                                  .map((t) {
                                return DropdownMenuItem(
                                  value: t,
                                  child: Text('${t.fullName} (${t.specialization})'),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                        AppSizes.h16,
                      ],

                      // 4. Effective period (Optional)
                      if (selectedLeaveTherapist != null) ...[
                        const Text(
                          'Effective Reassignment Period (Optional)',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                        ),
                        AppSizes.h8,
                        OutlinedButton.icon(
                          onPressed: pickDateRange,
                          icon: const Icon(Icons.date_range_rounded, size: 16),
                          label: Text(
                            selectedDateRange == null
                                ? 'Select date range (leave dates)'
                                : '${dateFormat.format(selectedDateRange!.start)} - ${dateFormat.format(selectedDateRange!.end)}',
                          ),
                          style: OutlinedButton.styleFrom(
                            alignment: Alignment.centerLeft,
                            minimumSize: const Size.fromHeight(48),
                          ),
                        ),
                        if (selectedDateRange != null) ...[
                          AppSizes.h4,
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () => setModalState(() => selectedDateRange = null),
                                child: const Text('Clear date range', style: TextStyle(color: AppColors.error, fontSize: 11)),
                              ),
                            ],
                          ),
                        ],
                        AppSizes.h12,
                      ],

                      // 5. Reason
                      if (selectedLeaveTherapist != null) ...[
                        const Text(
                          'Reason for Reassignment (Optional)',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                        ),
                        AppSizes.h8,
                        TextField(
                          controller: reasonController,
                          decoration: const InputDecoration(
                            hintText: 'e.g. Attending conference, Annual leave',
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
                ),
                ElevatedButton(
                  onPressed: (selectedLeaveTherapist == null || selectedTempTherapist == null || selectedPatientIds.isEmpty)
                      ? null
                      : () async {
                          Navigator.pop(ctx);
                          final messenger = ScaffoldMessenger.of(context);
                          final admin = ref.read(authProvider).userModel;
                          if (admin == null) return;

                          // Gather selected PatientModel list
                          final targetPatients = originalPatients
                              .where((p) => selectedPatientIds.contains(p.patientId))
                              .toList();

                          await ref.read(reassignmentOperationProvider.notifier).reassignPatients(
                            patients: targetPatients,
                            originalTherapist: selectedLeaveTherapist!,
                            temporaryTherapist: selectedTempTherapist!,
                            adminUser: admin,
                            startDate: selectedDateRange?.start,
                            endDate: selectedDateRange?.end,
                            reason: reasonController.text.trim(),
                          );

                          final state = ref.read(reassignmentOperationProvider);
                          if (state.error != null) {
                            messenger.showSnackBar(
                              SnackBar(content: Text('Failed to reassign: ${state.error}'), backgroundColor: AppColors.error),
                            );
                          } else {
                            messenger.showSnackBar(
                              const SnackBar(content: Text('Temporary reassignment scheduled successfully.'), backgroundColor: AppColors.success),
                            );
                          }
                        },
                  child: const Text('Confirm Reassign'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
