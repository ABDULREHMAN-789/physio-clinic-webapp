import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:physio_therapy_clinic/features/dashboard/providers/dashboard_salary_provider.dart';
import 'package:physio_therapy_clinic/features/sessions/providers/sessions_provider.dart';
import 'package:physio_therapy_clinic/features/staff/providers/staff_provider.dart';
import 'package:physio_therapy_clinic/models/session_model.dart';
import 'package:physio_therapy_clinic/models/user_model.dart';

void main() {
  group('Dashboard Salary Month Filter & Calculations', () {
    final therapistA = UserModel(
      userId: 'therapist-1',
      fullName: 'Dr. Jane Doe',
      email: 'jane@clinic.com',
      phone: '1234567890',
      role: 'Therapist',
      specialization: 'Orthopedic',
      qualification: 'DPT',
      status: 'Active',
      createdAt: DateTime(2026, 1, 1),
      revenuePercentage: 40.0,
    );

    final sessionSep1 = SessionModel(
      sessionId: 'sess-sep-1',
      patientId: 'patient-1',
      sessionDate: DateTime(2026, 9, 5, 10, 0),
      treatmentNotes: 'Sep Session 1',
      charges: 2000.0,
      paymentStatus: 'Paid',
      nextRecommendation: 'Continue exercise',
      therapistId: 'therapist-1',
      therapistName: 'Dr. Jane Doe',
    );

    final sessionSep2 = SessionModel(
      sessionId: 'sess-sep-2',
      patientId: 'patient-2',
      sessionDate: DateTime(2026, 9, 12, 11, 0),
      treatmentNotes: 'Sep Session 2 Unpaid',
      charges: 1500.0,
      paymentStatus: 'Unpaid',
      nextRecommendation: 'Rest',
      therapistId: 'therapist-1',
      therapistName: 'Dr. Jane Doe',
    );

    final sessionAug = SessionModel(
      sessionId: 'sess-aug-1',
      patientId: 'patient-3',
      sessionDate: DateTime(2026, 8, 20, 14, 0),
      treatmentNotes: 'Aug Session',
      charges: 3000.0,
      paymentStatus: 'Paid',
      nextRecommendation: 'Follow-up next month',
      therapistId: 'therapist-1',
      therapistName: 'Dr. Jane Doe',
    );

    test('salaryMonthFilterProvider defaults to current month', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final selectedMonth = container.read(salaryMonthFilterProvider);
      final now = DateTime.now();

      expect(selectedMonth.year, equals(now.year));
      expect(selectedMonth.month, equals(now.month));
      expect(selectedMonth.day, equals(1));
    });

    test('staffSalarySummaryProvider calculates metrics filtered by selected month', () async {
      final container = ProviderContainer(
        overrides: [
          staffProvider.overrideWith((ref) => Stream.value([therapistA])),
          sessionsStreamProvider.overrideWith((ref) => Stream.value([
            sessionSep1,
            sessionSep2,
            sessionAug,
          ])),
          salaryMonthFilterProvider.overrideWith((ref) => DateTime(2026, 9, 1)),
        ],
      );
      addTearDown(container.dispose);

      // Wait for stream providers to emit
      await container.read(staffProvider.future);
      await container.read(sessionsStreamProvider.future);

      final sepSummaries = container.read(staffSalarySummaryProvider);
      expect(sepSummaries.length, equals(1));

      final sepSummary = sepSummaries.first;
      expect(sepSummary.staff.fullName, equals('Dr. Jane Doe'));
      // In September: 2 sessions conducted
      expect(sepSummary.sessionsCount, equals(2));
      // Only Paid session (charges = 2000.0) counts towards revenue
      expect(sepSummary.totalRevenueGenerated, equals(2000.0));
      // Calculated Salary = 2000.0 * (40 / 100) = 800.0
      expect(sepSummary.calculatedSalary, equals(800.0));

      // Switch month to August 2026
      container.read(salaryMonthFilterProvider.notifier).state = DateTime(2026, 8, 1);

      final augSummaries = container.read(staffSalarySummaryProvider);
      expect(augSummaries.length, equals(1));

      final augSummary = augSummaries.first;
      // In August: 1 session conducted
      expect(augSummary.sessionsCount, equals(1));
      // Paid session charges = 3000.0
      expect(augSummary.totalRevenueGenerated, equals(3000.0));
      // Calculated Salary = 3000.0 * (40 / 100) = 1200.0
      expect(augSummary.calculatedSalary, equals(1200.0));

      // Switch month to July 2026 (No sessions)
      container.read(salaryMonthFilterProvider.notifier).state = DateTime(2026, 7, 1);

      final julSummaries = container.read(staffSalarySummaryProvider);
      final julSummary = julSummaries.first;
      expect(julSummary.sessionsCount, equals(0));
      expect(julSummary.totalRevenueGenerated, equals(0.0));
      expect(julSummary.calculatedSalary, equals(0.0));
    });
  });
}
