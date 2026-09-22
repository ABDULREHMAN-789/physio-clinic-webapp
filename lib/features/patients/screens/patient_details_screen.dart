import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../models/patient_model.dart';
import '../../../models/session_model.dart';
import '../../../models/massage_chair_bill_model.dart';
import '../../sessions/providers/sessions_provider.dart';
import '../providers/patients_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../staff/providers/staff_provider.dart';
import '../../billing/providers/massage_chair_provider.dart';
import '../../../models/user_model.dart';
import 'package:uuid/uuid.dart';

class PatientDetailsScreen extends ConsumerWidget {
  final String patientId;

  const PatientDetailsScreen({
    super.key,
    required this.patientId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patientsAsync = ref.watch(patientsStreamProvider);
    final sessionsAsync = ref.watch(patientSessionsStreamProvider(patientId));
    final authState = ref.watch(authProvider);
    final staffAsync = ref.watch(staffProvider);
    final isAdmin = authState.role == 'Admin';
    final massageChairBillsAsync = ref.watch(massageChairBillsStreamProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Patient Details & History'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/patients'),
        ),
      ),
      body: SafeArea(
        child: patientsAsync.when(
          data: (patients) {
            final hasPatient = patients.any((p) => p.patientId == patientId);
            if (!hasPatient) {
              return const Center(child: Text('Patient not found'));
            }
            final patient = patients.firstWhere((p) => p.patientId == patientId);

            return sessionsAsync.when(
              data: (sessions) {
                final patientSessions = sessions.where((s) => s.patientId == patientId).toList();
                final massageBills = (massageChairBillsAsync.valueOrNull ?? <MassageChairBillModel>[])
                        .where((b) => b.customerId == patientId)
                        .toList();
                final staffList = staffAsync.valueOrNull ?? <UserModel>[];
                return _buildDetailsLayout(
                  context,
                  ref,
                  patient,
                  patientSessions,
                  massageBills,
                  isAdmin,
                  staffList,
                );
              },
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
              error: (err, stack) => Center(child: Text('Error loading session history: $err')),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
          error: (err, stack) => Center(child: Text('Error loading patient: $err')),
        ),
      ),
    );
  }

  Widget _buildDetailsLayout(
    BuildContext context,
    WidgetRef ref,
    PatientModel patient,
    List<SessionModel> sessions,
    List<MassageChairBillModel> massageBills,
    bool isAdmin,
    List<UserModel> staffList,
  ) {
    final formatter = DateFormat('dd MMM yyyy');
    
    // Consultation Fee logic (accessible to admin)
    final double consultationFee = (isAdmin && patient.consultationFee != null) ? (patient.consultationFee ?? 0.0) : 0.0;
    final String consultationStatus = patient.consultationPaymentStatus ?? 'Unpaid';

    final double totalCharges = sessions.fold(0.0, (sum, s) => sum + s.charges) + 
                                massageBills.fold(0.0, (sum, b) => sum + b.fee) + 
                                consultationFee;
        
    final double unpaidDues = sessions.where((s) => s.paymentStatus == 'Unpaid').fold(0.0, (sum, s) => sum + s.charges) + 
                              massageBills.where((b) => b.paymentStatus == 'Unpaid').fold(0.0, (sum, b) => sum + b.fee) + 
                              (consultationStatus == 'Unpaid' ? consultationFee : 0.0);
        
    final double totalPaid = totalCharges - unpaidDues;

    final size = MediaQuery.of(context).size;
    final isNarrow = size.width < AppSizes.desktopBreakpoint;

    Widget profileCard = Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.p24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: AppColors.primaryLight,
                  child: Text(
                    patient.fullName.substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.primaryDark,
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                    ),
                  ),
                ),
                AppSizes.w16,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              patient.fullName,
                              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (sessions.isNotEmpty) ...[
                            AppSizes.w8,
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.primaryLight,
                                borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.medical_services_rounded, size: 12, color: AppColors.primaryDark),
                                  const SizedBox(width: 3),
                                  Text(
                                    'Therapy',
                                    style: TextStyle(
                                      color: AppColors.primaryDark,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (massageBills.isNotEmpty) ...[
                            AppSizes.w8,
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
                      AppSizes.h4,
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                    ],
                  ),
                ),
              ],
            ),
            AppSizes.h24,
            const Divider(),
            AppSizes.h20,

            // Bio Details
            _buildDetailRow(Icons.cake_outlined, 'Age / Gender', '${patient.age} yrs  /  ${patient.gender}'),
            _buildDetailRow(Icons.phone_outlined, 'Phone', patient.phone),
            _buildDetailRow(Icons.location_on_outlined, 'Address', patient.address),
            if (patient.assignedTherapistName != null)
              _buildDetailRow(Icons.medical_services_outlined, 'Therapist', patient.assignedTherapistName!),
            _buildDetailRow(Icons.calendar_month_outlined, 'Registered', formatter.format(patient.registrationDate)),
            AppSizes.h12,
            const Divider(),
            AppSizes.h20,

            // Condition & Notes
            if (patient.medicalCondition.isNotEmpty) ...[
              const Text(
                'Diagnosis / Condition',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textSecondary),
              ),
              AppSizes.h8,
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSizes.p12),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
                  border: Border.all(color: AppColors.error.withValues(alpha: 0.1)),
                ),
                child: Text(
                  patient.medicalCondition,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.error,
                    fontSize: 14,
                  ),
                ),
              ),
              AppSizes.h20,
            ],

            if (patient.notes.isNotEmpty) ...[
              const Text(
                'Clinical Notes',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textSecondary),
              ),
              AppSizes.h8,
              Text(
                patient.notes,
                style: const TextStyle(height: 1.4, fontSize: 13, color: AppColors.textPrimary),
              ),
              AppSizes.h24,
            ],

            // Buttons
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => context.go('/patients/edit/${patient.patientId}', extra: patient),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Edit Patient Record'),
              ),
            ),
            if (isAdmin) ...[
              AppSizes.h12,
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showTransferDialog(context, ref, patient, staffList),
                  icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                  label: const Text('Transfer Patient'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondary),
                ),
              ),
            ],
          ],
        ),
      ),
    );

    Widget financialCard = Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.p24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Financial Overview',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary),
            ),
            AppSizes.h16,
            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    title: 'Total Sessions',
                    value: (sessions.length + massageBills.length).toString(),
                    color: AppColors.primary,
                  ),
                ),
                AppSizes.w16,
                Expanded(
                  child: _buildMetricTile(
                    title: 'Pending Dues',
                    value: 'Rs. ${NumberFormat('#,##0').format(unpaidDues)}',
                    color: unpaidDues > 0 ? AppColors.warning : AppColors.success,
                  ),
                ),
              ],
            ),
            AppSizes.h16,
            _buildBillingRow('Total Charges', 'Rs. ${NumberFormat('#,##0').format(totalCharges)}', false),
            if (patient.consultationFee != null && (patient.consultationFee! > 0 || patient.consultationPaymentStatus == 'Fee Waiver'))
              _buildBillingRow('  ↳ Consultation Fee', 'Rs. ${NumberFormat('#,##0').format(patient.consultationFee)}', false),
            if (sessions.isNotEmpty)
              _buildBillingRow('  ↳ Therapy Sessions Total', 'Rs. ${NumberFormat('#,##0').format(sessions.fold(0.0, (sum, s) => sum + s.charges))}', false),
            if (massageBills.isNotEmpty)
              _buildBillingRow('  ↳ Massage Chair Total', 'Rs. ${NumberFormat('#,##0').format(massageBills.fold(0.0, (sum, b) => sum + b.fee))}', false),
            _buildBillingRow('Total Collected', 'Rs. ${NumberFormat('#,##0').format(totalPaid)}', true),
          ],
        ),
      ),
    );

    Widget? consultationCard;
    if (isAdmin && (patient.consultationPaymentStatus != null || (patient.consultationFee != null && patient.consultationFee! >= 0))) {
      consultationCard = Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.p24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.purple.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
                    ),
                    child: const Icon(Icons.payment_rounded, color: Colors.purple, size: 20),
                  ),
                  AppSizes.w12,
                  const Text(
                    'Consultation Fee Details',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary),
                  ),
                ],
              ),
              AppSizes.h16,
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Amount',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                  Text(
                    'Rs. ${NumberFormat('#,##0').format(patient.consultationFee ?? 0.0)}',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                ],
              ),
              AppSizes.h12,
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Payment Status',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: (consultationStatus == 'Paid'
                              ? AppColors.success
                              : consultationStatus == 'Fee Waiver'
                                  ? Colors.purple
                                  : AppColors.error)
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      patient.consultationPaymentStatus ?? 'Unpaid',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: patient.consultationPaymentStatus == 'Paid'
                            ? AppColors.success
                            : patient.consultationPaymentStatus == 'Fee Waiver'
                                ? Colors.purple
                                : AppColors.warning,
                      ),
                    ),
                  ),
                ],
              ),
              if (patient.consultationPaymentDate != null) ...[
                AppSizes.h12,
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Payment Date', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    Text(
                      DateFormat('dd MMM yyyy').format(patient.consultationPaymentDate!),
                      style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: AppColors.textPrimary),
                    ),
                  ],
                ),
              ],
              if (patient.consultationNotes != null && patient.consultationNotes!.isNotEmpty) ...[
                AppSizes.h12,
                const Text('Notes:', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
                AppSizes.h4,
                Text(
                  patient.consultationNotes!,
                  style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                ),
              ],
              if (patient.consultationPaymentStatus != 'Paid' && patient.consultationPaymentStatus != 'Fee Waiver') ...[
                AppSizes.h16,
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _markConsultationPaid(context, ref, patient),
                    icon: const Icon(Icons.check_circle_rounded, size: 18),
                    label: const Text('Mark Consultation Fee as Paid'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    // Build History timeline items
    final List<TimelineItemData> timelineData = [];

    for (final session in sessions) {
      timelineData.add(
        TimelineItemData(
          date: session.sessionDate,
          widgetBuilder: (isLast) => _buildTimelineItem(context, ref, session, isLast, isAdmin),
        ),
      );
    }

    for (final bill in massageBills) {
      timelineData.add(
        TimelineItemData(
          date: bill.sessionDate,
          widgetBuilder: (isLast) => _buildMassageTimelineItem(context, ref, bill, isLast, isAdmin),
        ),
      );
    }

    if (patient.consultationPaymentStatus != null || (patient.consultationFee != null && patient.consultationFee! >= 0)) {
      timelineData.add(
        TimelineItemData(
          date: patient.registrationDate,
          widgetBuilder: (isLast) => _buildConsultationTimelineItem(context, ref, patient, isLast, isAdmin),
        ),
      );
    }

    // Sort descending by date (newest first)
    timelineData.sort((a, b) => b.date.compareTo(a.date));

    Widget timelineColumn = Expanded(
      flex: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Activity & Service History',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => context.go('/sessions/add?patientId=${patient.patientId}'),
                    icon: const Icon(Icons.add_task_rounded, size: 16),
                    label: const Text('Log Session'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _showAddMassageChairVisitDialog(context, ref, patient, isAdmin),
                    icon: const Icon(Icons.chair_rounded, size: 16),
                    label: const Text('Log Massage Visit'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE65100),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
          AppSizes.h24,
          Expanded(
            child: timelineData.isEmpty
                ? _buildEmptyUnifiedState(context, patient)
                : ListView.builder(
                    itemCount: timelineData.length,
                    itemBuilder: (context, index) {
                      return timelineData[index].widgetBuilder(index == timelineData.length - 1);
                    },
                  ),
          ),
        ],
      ),
    );

    if (isNarrow) {
      return Padding(
        padding: const EdgeInsets.all(AppSizes.p24),
        child: Column(
          children: [
            profileCard,
            AppSizes.h20,
            if (isAdmin) ...[
              financialCard,
              AppSizes.h20,
            ],
            if (consultationCard != null) ...[
              consultationCard,
              AppSizes.h20,
            ],
            AppSizes.h32,
            const Divider(),
            AppSizes.h24,
            Expanded(child: timelineColumn),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(AppSizes.p24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  profileCard,
                  if (isAdmin) ...[
                    AppSizes.h20,
                    financialCard,
                  ],
                  if (consultationCard != null) ...[
                    AppSizes.h20,
                    consultationCard,
                  ],
                ],
              ),
            ),
          ),
          AppSizes.w32,
          timelineColumn,
        ],
      ),
    );
  }

  void _showTransferDialog(BuildContext context, WidgetRef ref, PatientModel patient, List<UserModel> staffList) {
    String? selectedTherapistId = patient.assignedTherapistId;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Transfer Patient'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Select a new therapist to assign to this patient.'),
                  AppSizes.h16,
                  DropdownButtonFormField<String>(
                    initialValue: selectedTherapistId,
                    hint: const Text('Select Therapist'),
                    items: staffList.map((staff) {
                      return DropdownMenuItem(
                        value: staff.userId,
                        child: Text(staff.fullName),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        selectedTherapistId = val;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
                ),
                ElevatedButton(
                  onPressed: selectedTherapistId == null || selectedTherapistId == patient.assignedTherapistId
                      ? null
                      : () async {
                          final selectedStaff = staffList.firstWhere((s) => s.userId == selectedTherapistId);
                          final updatedPatient = patient.copyWith(
                            assignedTherapistId: selectedStaff.userId,
                            assignedTherapistName: selectedStaff.fullName,
                          );
                          await ref.read(patientOperationProvider.notifier).updatePatient(updatedPatient);
                          if (context.mounted) Navigator.pop(context);
                        },
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                  child: const Text('Confirm Transfer'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.p12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          AppSizes.w12,
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textSecondary),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile({required String title, required String value, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.p16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
          AppSizes.h4,
          Text(
            value,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildBillingRow(String label, String value, bool isHighlight) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSizes.p12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: isHighlight ? AppColors.textPrimary : AppColors.textSecondary,
              fontWeight: isHighlight ? FontWeight.bold : FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: isHighlight ? AppColors.success : AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildTimelineItem(
    BuildContext context,
    WidgetRef ref,
    SessionModel session,
    bool isLast,
    bool isAdmin,
  ) {
    final formatter = DateFormat('dd MMM yyyy, hh:mm a');
    final Color indicatorColor = isAdmin 
        ? (session.paymentStatus == 'Paid' ? AppColors.success : (session.paymentStatus == 'Fee Waiver' ? Colors.purple : AppColors.warning)) 
        : AppColors.primary;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline indicator line
          Column(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: indicatorColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: indicatorColor.withValues(alpha: 0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    )
                  ],
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: AppColors.border,
                  ),
                ),
            ],
          ),
          AppSizes.w16,

          // Session Content Card
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSizes.p24),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSizes.p20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            formatter.format(session.sessionDate),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                          ),
                          AppSizes.h4,
                          Row(
                            children: [
                              const Icon(Icons.person_outline_rounded, size: 12, color: AppColors.textSecondary),
                              AppSizes.w4,
                              Text(
                                'Conducted by: ${session.therapistName ?? 'Unknown'}',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                          if (isAdmin)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: (session.paymentStatus == 'Paid'
                                        ? AppColors.success
                                        : session.paymentStatus == 'Fee Waiver'
                                            ? Colors.purple
                                            : AppColors.error)
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
                              ),
                              child: Text(
                                session.paymentStatus,
                                style: TextStyle(
                                  color: session.paymentStatus == 'Paid'
                                      ? AppColors.success
                                      : session.paymentStatus == 'Fee Waiver'
                                          ? Colors.purple
                                          : AppColors.error,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                        ],
                      ),
                      AppSizes.h12,
                      const Text(
                        'Treatment / Clinical Notes:',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                      ),
                      AppSizes.h4,
                      Text(
                        session.treatmentNotes,
                        style: const TextStyle(fontSize: 13, height: 1.4, color: AppColors.textPrimary),
                      ),
                      if (session.nextRecommendation.isNotEmpty) ...[
                        AppSizes.h12,
                        const Text(
                          'Next Recommendation:',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                        ),
                        AppSizes.h4,
                        Text(
                          session.nextRecommendation,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ],
                      AppSizes.h16,
                      const Divider(),
                      AppSizes.h8,
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (isAdmin)
                            Text(
                              'Session Charge: Rs. ${NumberFormat('#,##0').format(session.charges ?? 0.0)}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                            )
                          else
                            const SizedBox(),
                          Row(
                            children: [
                              IconButton(
                                tooltip: 'Edit Session Notes',
                                icon: const Icon(Icons.edit_outlined, color: AppColors.secondary, size: 18),
                                onPressed: () => context.go('/sessions/edit/${session.sessionId}', extra: session),
                              ),
                              if (isAdmin && session.paymentStatus == 'Unpaid') ...[
                                AppSizes.w4,
                                TextButton.icon(
                                  onPressed: () async {
                                    final updatedSession = session.copyWith(paymentStatus: 'Paid');
                                    await ref.read(sessionOperationProvider.notifier).updateSession(updatedSession);
                                  },
                                  icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                                  label: const Text('Mark Paid'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppColors.success,
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMassageTimelineItem(
    BuildContext context,
    WidgetRef ref,
    MassageChairBillModel bill,
    bool isLast,
    bool isAdmin,
  ) {
    final formatter = DateFormat('dd MMM yyyy, hh:mm a');
    final Color indicatorColor = isAdmin 
        ? (bill.paymentStatus == 'Paid' ? AppColors.success : (bill.paymentStatus == 'Fee Waiver' ? Colors.purple : AppColors.warning)) 
        : const Color(0xFFE65100);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline indicator line
          Column(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: indicatorColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: indicatorColor.withValues(alpha: 0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    )
                  ],
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: AppColors.border,
                  ),
                ),
            ],
          ),
          AppSizes.w16,

          // Bill Content Card
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSizes.p24),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSizes.p20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            formatter.format(bill.sessionDate),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                          ),
                          if (isAdmin)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: (bill.paymentStatus == 'Paid'
                                        ? AppColors.success
                                        : bill.paymentStatus == 'Fee Waiver'
                                            ? Colors.purple
                                            : AppColors.error)
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
                              ),
                              child: Text(
                                bill.paymentStatus,
                                style: TextStyle(
                                  color: bill.paymentStatus == 'Paid'
                                      ? AppColors.success
                                      : bill.paymentStatus == 'Fee Waiver'
                                          ? Colors.purple
                                          : AppColors.error,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                        ],
                      ),
                      AppSizes.h12,
                      const Text(
                        'Session Details:',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                      ),
                      AppSizes.h4,
                      Text(
                        bill.duration.isNotEmpty ? 'Duration: ${bill.duration}' : 'Walk-in session',
                        style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                      ),
                      AppSizes.h16,
                      const Divider(),
                      AppSizes.h8,
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (isAdmin)
                            Text(
                              'Session Fee: Rs. ${NumberFormat('#,##0').format(bill.fee ?? 0.0)}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                            )
                          else
                            const SizedBox(),
                          if (isAdmin && bill.paymentStatus == 'Unpaid')
                            TextButton.icon(
                              onPressed: () async {
                                final updatedBill = bill.copyWith(paymentStatus: 'Paid');
                                await ref.read(massageChairBillOperationProvider.notifier).updateBill(updatedBill);
                              },
                              icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                              label: const Text('Mark Paid'),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.success,
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConsultationTimelineItem(
    BuildContext context,
    WidgetRef ref,
    PatientModel patient,
    bool isLast,
    bool isAdmin,
  ) {
    final formatter = DateFormat('dd MMM yyyy, hh:mm a');
    final String consultationStatus = patient.consultationPaymentStatus ?? 'Unpaid';
    final Color indicatorColor = isAdmin 
        ? (consultationStatus == 'Paid' ? AppColors.success : (consultationStatus == 'Fee Waiver' ? Colors.purple : AppColors.warning)) 
        : Colors.purple;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline indicator line
          Column(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: indicatorColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: indicatorColor.withValues(alpha: 0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    )
                  ],
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: AppColors.border,
                  ),
                ),
            ],
          ),
          AppSizes.w16,

          // Content Card
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSizes.p24),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSizes.p20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.purple.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'Consultation Billed',
                                  style: TextStyle(
                                    color: Colors.purple,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (isAdmin)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: (consultationStatus == 'Paid'
                                        ? AppColors.success
                                        : consultationStatus == 'Fee Waiver'
                                            ? Colors.purple
                                            : AppColors.error)
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
                              ),
                              child: Text(
                                consultationStatus,
                                style: TextStyle(
                                  color: consultationStatus == 'Paid'
                                      ? AppColors.success
                                      : consultationStatus == 'Fee Waiver'
                                          ? Colors.purple
                                          : AppColors.error,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                        ],
                      ),
                      AppSizes.h12,
                      Text(
                        formatter.format(patient.registrationDate),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                      ),
                      if (patient.consultationNotes != null && patient.consultationNotes!.isNotEmpty) ...[
                        AppSizes.h12,
                        const Text(
                          'Notes:',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                        ),
                        AppSizes.h4,
                        Text(
                          patient.consultationNotes!,
                          style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                        ),
                      ],
                      AppSizes.h16,
                      const Divider(),
                      AppSizes.h8,
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (isAdmin)
                            Text(
                              'Consultation Fee: Rs. ${NumberFormat('#,##0').format(patient.consultationFee ?? 0.0)}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                            )
                          else
                            const SizedBox(),
                          if (isAdmin && consultationStatus == 'Unpaid')
                            TextButton.icon(
                              onPressed: () async {
                                final updatedPatient = patient.copyWith(
                                  consultationPaymentStatus: 'Paid',
                                  consultationPaymentDate: DateTime.now(),
                                );
                                await ref.read(patientOperationProvider.notifier).updatePatient(updatedPatient);
                              },
                              icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                              label: const Text('Mark Paid'),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.success,
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Dialog to log a new Massage Chair visit for existing patients
  // ─────────────────────────────────────────────────────────────
  void _showAddMassageChairVisitDialog(
    BuildContext context,
    WidgetRef ref,
    PatientModel patient,
    bool isAdmin,
  ) {
    final formKey = GlobalKey<FormState>();
    DateTime selectedDate = DateTime.now();
    final durationController = TextEditingController(text: '30 minutes');
    final feeController = TextEditingController(text: '500');
    String paymentStatus = 'Unpaid';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            Future<void> pickDate() async {
              final picked = await showDatePicker(
                context: context,
                initialDate: selectedDate,
                firstDate: DateTime(2020),
                lastDate: DateTime.now().add(const Duration(days: 30)),
              );
              if (picked != null) {
                setState(() => selectedDate = picked);
              }
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.radiusLarge)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFF3E0),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.chair_rounded, color: Color(0xFFE65100), size: 22),
                  ),
                  AppSizes.w12,
                  const Expanded(child: Text('Log Massage Chair Visit', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                ],
              ),
              content: SizedBox(
                width: 450,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Date *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary)),
                        AppSizes.h8,
                        InkWell(
                          onTap: pickDate,
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.calendar_today_rounded, size: 20),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                            child: Text(
                              '${selectedDate.day.toString().padLeft(2, '0')}/${selectedDate.month.toString().padLeft(2, '0')}/${selectedDate.year}',
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ),
                        ),
                        AppSizes.h16,

                        const Text('Duration (Optional)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary)),
                        AppSizes.h8,
                        TextFormField(
                          controller: durationController,
                          decoration: const InputDecoration(
                            hintText: 'e.g., 30 minutes',
                            prefixIcon: Icon(Icons.timer_outlined, size: 20),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                        ),
                        
                        if (isAdmin) ...[
                          AppSizes.h16,
                          const Text('Session Fee *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary)),
                          AppSizes.h8,
                          TextFormField(
                            controller: feeController,
                            readOnly: paymentStatus == 'Fee Waiver',
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              hintText: 'Enter fee amount',
                              prefixIcon: Icon(Icons.payments_outlined, size: 20),
                              prefixText: 'Rs. ',
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) return 'Fee is required';
                              if (double.tryParse(val.trim()) == null) return 'Enter a valid amount';
                              return null;
                            },
                          ),
                          AppSizes.h16,
                          const Text('Payment Status *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary)),
                          AppSizes.h8,
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                              border: Border.all(color: AppColors.border, width: 1.2),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    onTap: () => setState(() => paymentStatus = 'Unpaid'),
                                    borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      decoration: BoxDecoration(
                                        color: paymentStatus == 'Unpaid' ? AppColors.error.withValues(alpha: 0.1) : null,
                                        borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            paymentStatus == 'Unpaid' ? Icons.radio_button_checked : Icons.radio_button_off,
                                            color: paymentStatus == 'Unpaid' ? AppColors.error : AppColors.textSecondary,
                                            size: 16,
                                          ),
                                          const SizedBox(width: 4),
                                          Text('Unpaid', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: paymentStatus == 'Unpaid' ? AppColors.error : AppColors.textSecondary)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                Container(width: 1.2, height: 40, color: AppColors.border),
                                Expanded(
                                  child: InkWell(
                                    onTap: () => setState(() => paymentStatus = 'Paid'),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      decoration: BoxDecoration(
                                        color: paymentStatus == 'Paid' ? AppColors.success.withValues(alpha: 0.1) : null,
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            paymentStatus == 'Paid' ? Icons.radio_button_checked : Icons.radio_button_off,
                                            color: paymentStatus == 'Paid' ? AppColors.success : AppColors.textSecondary,
                                            size: 16,
                                          ),
                                          const SizedBox(width: 4),
                                          Text('Paid', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: paymentStatus == 'Paid' ? AppColors.success : AppColors.textSecondary)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                Container(width: 1.2, height: 40, color: AppColors.border),
                                Expanded(
                                  child: InkWell(
                                    onTap: () => setState(() {
                                      paymentStatus = 'Fee Waiver';
                                      feeController.text = '0';
                                    }),
                                    borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      decoration: BoxDecoration(
                                        color: paymentStatus == 'Fee Waiver' ? Colors.purple.withValues(alpha: 0.1) : null,
                                        borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            paymentStatus == 'Fee Waiver' ? Icons.radio_button_checked : Icons.radio_button_off,
                                            color: paymentStatus == 'Fee Waiver' ? Colors.purple : AppColors.textSecondary,
                                            size: 16,
                                          ),
                                          const SizedBox(width: 4),
                                          Text('Fee Waiver', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: paymentStatus == 'Fee Waiver' ? Colors.purple : AppColors.textSecondary)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (formKey.currentState == null || formKey.currentState!.validate()) {
                      final feeText = feeController.text.trim();
                      final fee = double.tryParse(feeText) ?? 500.0;

                      final billId = 'MCB-${const Uuid().v4().substring(0, 5).toUpperCase()}';
                      final bill = MassageChairBillModel(
                        billId: billId,
                        customerId: patient.patientId,
                        customerName: patient.fullName,
                        sessionDate: selectedDate,
                        duration: durationController.text.trim(),
                        fee: fee,
                        paymentStatus: paymentStatus,
                        createdAt: DateTime.now(),
                      );

                      final messenger = ScaffoldMessenger.of(context);
                      await ref.read(massageChairBillOperationProvider.notifier).addBill(bill);
                      
                      final state = ref.read(massageChairBillOperationProvider);
                      if (state.error != null) {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text('Failed to log massage chair visit: ${state.error}'),
                            backgroundColor: AppColors.error,
                          ),
                        );
                      } else {
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Massage chair visit logged successfully.'),
                            backgroundColor: AppColors.success,
                          ),
                        );
                        if (context.mounted) Navigator.pop(context);
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE65100)),
                  child: const Text('Save Visit'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _markConsultationPaid(BuildContext context, WidgetRef ref, PatientModel patient) async {
    final messenger = ScaffoldMessenger.of(context);
    final updatedPatient = patient.copyWith(
      consultationPaymentStatus: 'Paid',
      consultationPaymentDate: DateTime.now(),
    );
    await ref.read(patientOperationProvider.notifier).updatePatient(updatedPatient);
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Consultation fee marked as Paid.'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  Widget _buildEmptyUnifiedState(BuildContext context, PatientModel patient) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSizes.p16),
            decoration: const BoxDecoration(
              color: AppColors.primaryLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.history_rounded, color: AppColors.primary, size: 36),
          ),
          AppSizes.h16,
          Text(
            'No History Recorded Yet',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
          ),
          AppSizes.h8,
          Text(
            'No therapy sessions or massage chair visits have been recorded for ${patient.fullName}.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class TimelineItemData {
  final DateTime date;
  final Widget Function(bool isLast) widgetBuilder;
  TimelineItemData({required this.date, required this.widgetBuilder});
}

