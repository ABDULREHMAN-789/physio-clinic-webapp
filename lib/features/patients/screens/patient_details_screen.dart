import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../models/patient_model.dart';
import '../../../models/session_model.dart';
import '../../sessions/providers/sessions_provider.dart';
import '../providers/patients_provider.dart';

class PatientDetailsScreen extends ConsumerWidget {
  final String patientId;

  const PatientDetailsScreen({
    super.key,
    required this.patientId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patientsAsync = ref.watch(patientsStreamProvider);
    final sessionsAsync = ref.watch(sessionsStreamProvider);
    final textTheme = Theme.of(context).textTheme;

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
            final patient = patients.firstWhere(
              (p) => p.patientId == patientId,
              orElse: () => null as dynamic,
            );

            return sessionsAsync.when(
              data: (sessions) {
                final patientSessions = sessions.where((s) => s.patientId == patientId).toList();
                return _buildDetailsLayout(context, ref, patient, patientSessions);
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
  ) {
    final formatter = DateFormat('dd MMM yyyy');
    final double totalCharges = sessions.fold(0.0, (sum, s) => sum + s.charges);
    final double unpaidDues = sessions.where((s) => !s.paymentStatus).fold(0.0, (sum, s) => sum + s.charges);
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
                      Text(
                        patient.fullName,
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
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
            _buildDetailRow(Icons.calendar_month_outlined, 'Registered', formatter.format(patient.registrationDate)),
            AppSizes.h12,
            const Divider(),
            AppSizes.h20,

            // Condition & Notes
            const Text(
              'Diagnosis / Condition',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textSecondary),
            ),
            AppSizes.h8,
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSizes.p12),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.06),
                borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
                border: Border.all(color: AppColors.error.withOpacity(0.1)),
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

            const Text(
              'Clinical Notes',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textSecondary),
            ),
            AppSizes.h8,
            Text(
              patient.notes.isNotEmpty ? patient.notes : 'No extra notes recorded.',
              style: const TextStyle(height: 1.4, fontSize: 13, color: AppColors.textPrimary),
            ),
            AppSizes.h24,

            // Buttons
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => context.go('/patients/edit/${patient.patientId}', extra: patient),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Edit Patient Record'),
              ),
            ),
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
                    value: sessions.length.toString(),
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
            _buildBillingRow('Total Collected', 'Rs. ${NumberFormat('#,##0').format(totalPaid)}', true),
          ],
        ),
      ),
    );

    Widget timelineColumn = Expanded(
      flex: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Therapy Log & Progress Timeline',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
              ),
              ElevatedButton.icon(
                onPressed: () => context.go('/sessions/add?patientId=${patient.patientId}'),
                icon: const Icon(Icons.add_task_rounded, size: 18),
                label: const Text('Log New Session'),
              ),
            ],
          ),
          AppSizes.h24,
          Expanded(
            child: sessions.isEmpty
                ? _buildEmptySessionsState(context, patient)
                : ListView.builder(
                    itemCount: sessions.length,
                    itemBuilder: (context, index) {
                      return _buildTimelineItem(context, ref, sessions[index], index == sessions.length - 1);
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
            financialCard,
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
                  AppSizes.h20,
                  financialCard,
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
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        border: Border.all(color: color.withOpacity(0.15)),
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

  Widget _buildEmptySessionsState(BuildContext context, PatientModel patient) {
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
            child: const Icon(Icons.history_edu_rounded, color: AppColors.primary, size: 36),
          ),
          AppSizes.h16,
          Text(
            'No Sessions Recorded Yet',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
          ),
          AppSizes.h8,
          Text(
            'Create the first clinical session log for ${patient.fullName} to begin tracking therapeutic progress.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(BuildContext context, WidgetRef ref, SessionModel session, bool isLast) {
    final formatter = DateFormat('dd MMM yyyy, hh:mm a');

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
                  color: session.paymentStatus ? AppColors.success : AppColors.warning,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: (session.paymentStatus ? AppColors.success : AppColors.warning).withOpacity(0.3),
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
                          Text(
                            'Session Charge: Rs. ${NumberFormat('#,##0').format(session.charges)}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, color: AppColors.secondary, size: 18),
                                onPressed: () => context.go('/sessions/edit/${session.sessionId}', extra: session),
                              ),
                              if (!session.paymentStatus) ...[
                                AppSizes.w4,
                                TextButton.icon(
                                  onPressed: () async {
                                    final updatedSession = session.copyWith(paymentStatus: true);
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
}
