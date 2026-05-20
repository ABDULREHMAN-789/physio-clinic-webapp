import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/utils/validators.dart';
import '../../../models/session_model.dart';
import '../../patients/providers/patients_provider.dart';
import '../providers/sessions_provider.dart';

class AddSessionScreen extends ConsumerStatefulWidget {
  final String? sessionId;
  final SessionModel? session;
  final String? initialPatientId;

  const AddSessionScreen({
    super.key,
    this.sessionId,
    this.session,
    this.initialPatientId,
  });

  @override
  ConsumerState<AddSessionScreen> createState() => _AddSessionScreenState();
}

class _AddSessionScreenState extends ConsumerState<AddSessionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _chargesController = TextEditingController();
  final _notesController = TextEditingController();
  final _recommendationController = TextEditingController();

  String? _selectedPatientId;
  DateTime _selectedDate = DateTime.now();
  bool _paymentStatus = false;
  late bool _isEditMode;

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.sessionId != null;
    _populateFields();
  }

  void _populateFields() {
    if (_isEditMode && widget.session != null) {
      final s = widget.session!;
      _chargesController.text = s.charges.toStringAsFixed(0);
      _notesController.text = s.treatmentNotes;
      _recommendationController.text = s.nextRecommendation;
      _selectedPatientId = s.patientId;
      _selectedDate = s.sessionDate;
      _paymentStatus = s.paymentStatus;
    } else if (widget.initialPatientId != null) {
      _selectedPatientId = widget.initialPatientId;
    }
  }

  @override
  void dispose() {
    _chargesController.dispose();
    _notesController.dispose();
    _recommendationController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
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
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _selectedDate.hour,
          _selectedDate.minute,
        );
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDate),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
          picked.hour,
          picked.minute,
        );
      });
    }
  }

  void _saveForm() async {
    if (_selectedPatientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a patient to record the session.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_formKey.currentState!.validate()) {
      final messenger = ScaffoldMessenger.of(context);
      
      final sessionId = _isEditMode 
          ? widget.sessionId! 
          : 'SE-${const Uuid().v4().substring(0, 5).toUpperCase()}';

      final session = SessionModel(
        sessionId: sessionId,
        patientId: _selectedPatientId!,
        sessionDate: _selectedDate,
        treatmentNotes: _notesController.text.trim(),
        charges: double.parse(_chargesController.text.trim()),
        paymentStatus: _paymentStatus,
        nextRecommendation: _recommendationController.text.trim(),
      );

      final notifier = ref.read(sessionOperationProvider.notifier);
      if (_isEditMode) {
        await notifier.updateSession(session);
      } else {
        await notifier.addSession(session);
      }

      final state = ref.read(sessionOperationProvider);
      if (state.error != null) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Failed to save session log: ${state.error}'),
            backgroundColor: AppColors.error,
          ),
        );
      } else {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Session log recorded successfully.'),
            backgroundColor: AppColors.success,
          ),
        );
        if (mounted) {
          // Go back to previous location or patients list
          if (widget.initialPatientId != null) {
            context.go('/patients/${widget.initialPatientId}');
          } else {
            context.go('/sessions');
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final patientsAsync = ref.watch(patientsStreamProvider);
    final operationState = ref.watch(sessionOperationProvider);
    final dateFormatter = DateFormat('EEEE, dd MMMM yyyy');
    final timeFormatter = DateFormat('hh:mm a');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Session Record' : 'Record Therapy Session'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (widget.initialPatientId != null) {
              context.go('/patients/${widget.initialPatientId}');
            } else {
              context.go('/sessions');
            }
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSizes.p24),
          child: Center(
            child: SizedBox(
              width: 750,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSizes.p32),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.history_edu_rounded, color: AppColors.primary, size: 30),
                            AppSizes.w12,
                            Text(
                              _isEditMode ? 'Edit Clinical Session Entry' : 'Log New Therapy Session',
                              style: textTheme.headlineLarge?.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        AppSizes.h12,
                        Text(
                          'Record treatment logs, financial charges, and next schedules here.',
                          style: textTheme.bodyMedium,
                        ),
                        AppSizes.h24,
                        const Divider(),
                        AppSizes.h24,

                        // Patient Selection Dropdown
                        const Text(
                          'Select Patient *',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                        ),
                        AppSizes.h8,
                        patientsAsync.when(
                          data: (patients) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: AppSizes.p16),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                border: Border.all(color: AppColors.border, width: 1.2),
                                borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedPatientId,
                                  isExpanded: true,
                                  hint: const Text('Choose a patient from register'),
                                  disabledHint: _isEditMode ? const Text('Patient details locked during edit') : null,
                                  icon: const Icon(Icons.arrow_drop_down, color: AppColors.textSecondary),
                                  onChanged: _isEditMode
                                      ? null // Cannot change patient in edit mode
                                      : (String? val) {
                                          setState(() {
                                            _selectedPatientId = val;
                                          });
                                        },
                                  items: patients.map((patient) {
                                    return DropdownMenuItem(
                                      value: patient.patientId,
                                      child: Text('${patient.fullName} (${patient.patientId}) - ${patient.medicalCondition}'),
                                    );
                                  }).toList(),
                                ),
                              ),
                            );
                          },
                          loading: () => const LinearProgressIndicator(color: AppColors.primary),
                          error: (e, s) => Text('Error loading patients list: $e', style: const TextStyle(color: AppColors.error)),
                        ),
                        AppSizes.h24,

                        // Date & Time Selectors
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Session Date *',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                  ),
                                  AppSizes.h8,
                                  OutlinedButton.icon(
                                    onPressed: () => _selectDate(context),
                                    icon: const Icon(Icons.calendar_month_outlined, size: 18),
                                    label: Text(dateFormatter.format(_selectedDate)),
                                    style: OutlinedButton.styleFrom(
                                      alignment: Alignment.centerLeft,
                                      padding: const EdgeInsets.symmetric(horizontal: AppSizes.p16, vertical: 16),
                                      minimumSize: const Size.fromHeight(50),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            AppSizes.w16,
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Session Time *',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                  ),
                                  AppSizes.h8,
                                  OutlinedButton.icon(
                                    onPressed: () => _selectTime(context),
                                    icon: const Icon(Icons.access_time_rounded, size: 18),
                                    label: Text(timeFormatter.format(_selectedDate)),
                                    style: OutlinedButton.styleFrom(
                                      alignment: Alignment.centerLeft,
                                      padding: const EdgeInsets.symmetric(horizontal: AppSizes.p16, vertical: 16),
                                      minimumSize: const Size.fromHeight(50),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        AppSizes.h24,

                        // Charges and Payment Status Switch
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Charges (Rs.) *',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                  ),
                                  AppSizes.h8,
                                  TextFormField(
                                    controller: _chargesController,
                                    keyboardType: TextInputType.number,
                                    textInputAction: TextInputAction.next,
                                    decoration: const InputDecoration(
                                      hintText: 'E.g., 2000',
                                      prefixIcon: Icon(Icons.payments_outlined, size: 20),
                                    ),
                                    validator: (val) => Validators.numeric(val, 'Charges'),
                                  ),
                                ],
                              ),
                            ),
                            AppSizes.w24,
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Payment Status',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                  ),
                                  AppSizes.h8,
                                  Container(
                                    height: 52,
                                    padding: const EdgeInsets.symmetric(horizontal: AppSizes.p16),
                                    decoration: BoxDecoration(
                                      color: _paymentStatus ? AppColors.success.withOpacity(0.06) : AppColors.error.withOpacity(0.06),
                                      border: Border.all(
                                        color: _paymentStatus ? AppColors.success.withOpacity(0.3) : AppColors.error.withOpacity(0.3),
                                        width: 1.2,
                                      ),
                                      borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          _paymentStatus ? 'PAID' : 'UNPAID',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                            color: _paymentStatus ? AppColors.success : AppColors.error,
                                          ),
                                        ),
                                        Switch(
                                          value: _paymentStatus,
                                          activeThumbColor: AppColors.success,
                                          activeTrackColor: AppColors.success.withOpacity(0.2),
                                          inactiveThumbColor: AppColors.error,
                                          inactiveTrackColor: AppColors.error.withOpacity(0.2),
                                          onChanged: (val) {
                                            setState(() {
                                              _paymentStatus = val;
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        AppSizes.h24,

                        // Notes & Next Steps
                        const Text(
                          'Treatment Notes / Diagnosis Activities *',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                        ),
                        AppSizes.h8,
                        TextFormField(
                          controller: _notesController,
                          maxLines: 4,
                          keyboardType: TextInputType.multiline,
                          decoration: const InputDecoration(
                            hintText: 'Record therapy routines administered, progress updates, pain score reports, exercises, etc...',
                          ),
                          validator: (val) => Validators.required(val, 'Treatment notes'),
                        ),
                        AppSizes.h24,

                        const Text(
                          'Next Session Recommendations / Advice',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                        ),
                        AppSizes.h8,
                        TextFormField(
                          controller: _recommendationController,
                          decoration: const InputDecoration(
                            hintText: 'E.g., Core exercises at home, Next session in 3 days',
                            prefixIcon: Icon(Icons.lightbulb_outline_rounded, size: 20),
                          ),
                        ),
                        AppSizes.h32,

                        // Action Buttons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton(
                              onPressed: () {
                                if (widget.initialPatientId != null) {
                                  context.go('/patients/${widget.initialPatientId}');
                                } else {
                                  context.go('/sessions');
                                }
                              },
                              child: const Text('Cancel'),
                            ),
                            AppSizes.w16,
                            ElevatedButton(
                              onPressed: operationState.isLoading ? null : _saveForm,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: AppSizes.p32, vertical: 18),
                              ),
                              child: operationState.isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                    )
                                  : Text(_isEditMode ? 'Update Session' : 'Save Session Log'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
