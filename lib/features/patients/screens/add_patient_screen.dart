import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/utils/validators.dart';
import '../../../models/patient_model.dart';
import '../../../models/massage_chair_bill_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../staff/providers/staff_provider.dart';
import '../providers/patients_provider.dart';
import '../../billing/providers/massage_chair_provider.dart';

class AddPatientScreen extends ConsumerStatefulWidget {
  final String? patientId;
  final PatientModel? patient;

  const AddPatientScreen({
    super.key,
    this.patientId,
    this.patient,
  });

  @override
  ConsumerState<AddPatientScreen> createState() => _AddPatientScreenState();
}

class _AddPatientScreenState extends ConsumerState<AddPatientScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _ageController = TextEditingController();
  final _addressController = TextEditingController();
  final _conditionController = TextEditingController();
  final _notesController = TextEditingController();
  
  // Massage Chair billing fields
  final _feeController = TextEditingController();
  final _durationController = TextEditingController();

  // Consultation Fee fields
  final _consultationFeeController = TextEditingController();
  final _consultationNotesController = TextEditingController();
  bool _consultationPaymentStatus = false;
  DateTime? _consultationPaymentDate;
  
  String _selectedGender = 'Male';
  late bool _isEditMode;
  String? _selectedTherapistId;
  String? _selectedTherapistName;
  
  // Customer type: 'therapy' or 'massage_chair'
  String _customerType = 'therapy';
  
  // Massage chair billing
  DateTime _massageSessionDate = DateTime.now();
  bool _massagePaymentStatus = false; // Unpaid by default

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.patientId != null;
    _populateFields();
    
    if (!_isEditMode) {
      _nameController.addListener(_onTextChanged);
      _phoneController.addListener(_onTextChanged);
    }
  }

  void _onTextChanged() {
    setState(() {});
  }

  void _populateFields() {
    if (_isEditMode && widget.patient != null) {
      final p = widget.patient!;
      _nameController.text = p.fullName;
      _phoneController.text = p.phone;
      _ageController.text = p.age.toString();
      _addressController.text = p.address;
      _conditionController.text = p.medicalCondition;
      _notesController.text = p.notes;
      _selectedGender = p.gender;
      _selectedTherapistId = p.assignedTherapistId;
      _selectedTherapistName = p.assignedTherapistName;
      _customerType = p.customerType;
      
      if (p.consultationFee != null) {
        _consultationFeeController.text = p.consultationFee!.toString();
      }
      _consultationPaymentStatus = p.consultationPaymentStatus ?? false;
      _consultationPaymentDate = p.consultationPaymentDate;
      _consultationNotesController.text = p.consultationNotes ?? '';
    }
  }

  @override
  void dispose() {
    if (!_isEditMode) {
      _nameController.removeListener(_onTextChanged);
      _phoneController.removeListener(_onTextChanged);
    }
    _nameController.dispose();
    _phoneController.dispose();
    _ageController.dispose();
    _addressController.dispose();
    _conditionController.dispose();
    _notesController.dispose();
    _feeController.dispose();
    _durationController.dispose();
    _consultationFeeController.dispose();
    _consultationNotesController.dispose();
    super.dispose();
  }

  Future<void> _pickSessionDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _massageSessionDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) {
      setState(() => _massageSessionDate = picked);
    }
  }

  Future<void> _pickConsultationPaymentDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _consultationPaymentDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) {
      setState(() => _consultationPaymentDate = picked);
    }
  }

  Widget _buildPaymentStatusToggle() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        border: Border.all(color: AppColors.border, width: 1.2),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => setState(() {
                _consultationPaymentStatus = false;
                _consultationPaymentDate = null;
              }),
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: !_consultationPaymentStatus ? AppColors.error.withOpacity(0.1) : null,
                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      !_consultationPaymentStatus ? Icons.radio_button_checked : Icons.radio_button_off,
                      color: !_consultationPaymentStatus ? AppColors.error : AppColors.textSecondary,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Unpaid',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: !_consultationPaymentStatus ? AppColors.error : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Container(width: 1.2, height: 48, color: AppColors.border),
          Expanded(
            child: InkWell(
              onTap: () => setState(() {
                _consultationPaymentStatus = true;
                if (_consultationPaymentDate == null) {
                  _consultationPaymentDate = DateTime.now();
                }
              }),
              borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: _consultationPaymentStatus ? AppColors.success.withOpacity(0.1) : null,
                  borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _consultationPaymentStatus ? Icons.radio_button_checked : Icons.radio_button_off,
                      color: _consultationPaymentStatus ? AppColors.success : AppColors.textSecondary,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Paid',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _consultationPaymentStatus ? AppColors.success : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _saveForm() async {
    if (_formKey.currentState!.validate()) {
      final messenger = ScaffoldMessenger.of(context);
      
      final isMassageChair = _customerType == 'massage_chair';
      
      final patientId = _isEditMode 
          ? widget.patientId! 
          : isMassageChair
              ? 'MC-${const Uuid().v4().substring(0, 5).toUpperCase()}'
              : 'PT-${const Uuid().v4().substring(0, 5).toUpperCase()}';

      final consultationFeeText = _consultationFeeController.text.trim();
      final double? consultationFee = consultationFeeText.isNotEmpty 
          ? double.tryParse(consultationFeeText) 
          : null;
      
      final patient = PatientModel(
        patientId: patientId,
        fullName: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        age: int.parse(_ageController.text.trim()),
        gender: _selectedGender,
        address: _addressController.text.trim(),
        medicalCondition: isMassageChair ? '' : _conditionController.text.trim(),
        notes: isMassageChair ? '' : _notesController.text.trim(),
        registrationDate: _isEditMode 
            ? (widget.patient?.registrationDate ?? DateTime.now())
            : DateTime.now(),
        assignedTherapistId: isMassageChair ? null : _selectedTherapistId,
        assignedTherapistName: isMassageChair ? null : _selectedTherapistName,
        customerType: _customerType,
        consultationFee: isMassageChair ? null : consultationFee,
        consultationPaymentStatus: isMassageChair ? null : (consultationFee != null ? _consultationPaymentStatus : null),
        consultationPaymentDate: isMassageChair ? null : (consultationFee != null && _consultationPaymentStatus ? (_consultationPaymentDate ?? DateTime.now()) : null),
        consultationNotes: isMassageChair ? null : (consultationFee != null && _consultationNotesController.text.trim().isNotEmpty ? _consultationNotesController.text.trim() : null),
      );

      final notifier = ref.read(patientOperationProvider.notifier);
      if (_isEditMode) {
        await notifier.updatePatient(patient);
      } else {
        await notifier.addPatient(patient);
      }

      // If massage chair customer and NOT in edit mode, also create a bill
      if (isMassageChair && !_isEditMode) {
        final billId = 'MCB-${const Uuid().v4().substring(0, 5).toUpperCase()}';
        final bill = MassageChairBillModel(
          billId: billId,
          customerId: patientId,
          customerName: _nameController.text.trim(),
          sessionDate: _massageSessionDate,
          duration: _durationController.text.trim(),
          fee: double.parse(_feeController.text.trim()),
          paymentStatus: _massagePaymentStatus,
          createdAt: DateTime.now(),
        );
        await ref.read(massageChairBillOperationProvider.notifier).addBill(bill);
      }

      final state = ref.read(patientOperationProvider);
      if (state.error != null) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Failed to save: ${state.error}'),
            backgroundColor: AppColors.error,
          ),
        );
      } else {
        messenger.showSnackBar(
          SnackBar(
            content: Text(isMassageChair 
                ? 'Massage Chair customer ${patient.fullName} registered with bill.'
                : 'Patient ${patient.fullName} saved successfully.'),
            backgroundColor: AppColors.success,
          ),
        );
        if (mounted) {
          context.go('/patients');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final operationState = ref.watch(patientOperationProvider);
    final authState = ref.watch(authProvider);
    final isAdmin = authState.role == 'Admin';
    final staffAsync = ref.watch(staffProvider);
    final isMassageChair = _customerType == 'massage_chair';

    // Duplicate check using allPatientsStreamProvider
    final allPatientsAsync = ref.watch(allPatientsStreamProvider);
    PatientModel? duplicatePatient;
    if (!_isEditMode && allPatientsAsync.hasValue) {
      final patientsList = allPatientsAsync.value ?? [];
      final enteredName = _nameController.text.trim().toLowerCase();
      final enteredPhone = _phoneController.text.trim();
      final cleanEnteredPhone = enteredPhone.replaceAll(RegExp(r'\D'), '');

      if (enteredName.isNotEmpty || cleanEnteredPhone.isNotEmpty) {
        for (var p in patientsList) {
          final existingName = p.fullName.trim().toLowerCase();
          final cleanExistingPhone = p.phone.replaceAll(RegExp(r'\D'), '');
          
          bool nameMatch = enteredName.isNotEmpty && existingName == enteredName;
          bool phoneMatch = cleanEnteredPhone.isNotEmpty && cleanExistingPhone == cleanEnteredPhone;
          
          if (nameMatch || phoneMatch) {
            duplicatePatient = p;
            break;
          }
        }
      }
    }

    // Auto-assign if therapist and no therapist selected yet
    if (!isAdmin && _selectedTherapistId == null && authState.userModel != null) {
      _selectedTherapistId = authState.userModel!.userId;
      _selectedTherapistName = authState.userModel!.fullName;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Patient Details' : 'Register New Patient / Customer'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/patients'),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSizes.p24),
          child: Center(
            child: SizedBox(
              width: 800,
              child: Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(AppSizes.p32),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _isEditMode ? Icons.edit_note_rounded : Icons.person_add_alt_1_rounded,
                              color: AppColors.primary,
                              size: 32,
                            ),
                            AppSizes.w12,
                            Expanded(
                              child: Text(
                                _isEditMode ? 'Edit Patient File' : 'Create Patient / Customer Profile',
                                style: textTheme.headlineLarge?.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        AppSizes.h12,
                        Text(
                          'Fill in the personal details below to proceed.',
                          style: textTheme.bodyMedium,
                        ),
                        AppSizes.h24,

                        // ── Customer Type Selector ──
                        if (!_isEditMode) ...[
                          const Text(
                            'Service Type *',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          AppSizes.h8,
                          Container(
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                              border: Border.all(color: AppColors.border, width: 1.2),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _buildCustomerTypeOption(
                                    icon: Icons.medical_services_rounded,
                                    label: 'Therapy Patient',
                                    subtitle: 'Regular physiotherapy sessions',
                                    value: 'therapy',
                                    isSelected: _customerType == 'therapy',
                                  ),
                                ),
                                Container(width: 1.5, height: 80, color: AppColors.border),
                                Expanded(
                                  child: _buildCustomerTypeOption(
                                    icon: Icons.chair_rounded,
                                    label: 'Massage Chair',
                                    subtitle: 'Walk-in massage chair service',
                                    value: 'massage_chair',
                                    isSelected: _customerType == 'massage_chair',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          AppSizes.h24,
                        ] else ...[
                          // Show read-only badge in edit mode
                          Row(
                            children: [
                              const Text(
                                'Service Type: ',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isMassageChair
                                      ? const Color(0xFFFFF3E0)
                                      : AppColors.primaryLight,
                                  borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isMassageChair ? Icons.chair_rounded : Icons.medical_services_rounded,
                                      size: 16,
                                      color: isMassageChair ? const Color(0xFFE65100) : AppColors.primaryDark,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      isMassageChair ? 'Massage Chair Customer' : 'Therapy Patient',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                        color: isMassageChair ? const Color(0xFFE65100) : AppColors.primaryDark,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          AppSizes.h24,
                        ],

                        const Divider(),
                        AppSizes.h24,

                        // ── Personal Information Fields ──
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final double width = constraints.maxWidth;
                            final bool isNarrow = width < 600;
                            
                            Widget buildField(String label, Widget field) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: AppSizes.p20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      label,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    AppSizes.h8,
                                    field,
                                  ],
                                ),
                              );
                            }

                            final fullNameField = TextFormField(
                              controller: _nameController,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                hintText: 'Enter full name',
                                prefixIcon: Icon(Icons.person_outline, size: 20),
                              ),
                              validator: (val) => Validators.required(val, 'Name'),
                            );

                            final phoneField = TextFormField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                hintText: 'Enter phone number',
                                prefixIcon: Icon(Icons.phone_outlined, size: 20),
                              ),
                              validator: Validators.phone,
                            );

                            final ageField = TextFormField(
                              controller: _ageController,
                              keyboardType: TextInputType.number,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                hintText: 'Enter age',
                                prefixIcon: Icon(Icons.cake_outlined, size: 20),
                              ),
                              validator: Validators.age,
                            );

                            final genderField = Container(
                              padding: const EdgeInsets.symmetric(horizontal: AppSizes.p16),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                border: Border.all(color: AppColors.border, width: 1.2),
                                borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedGender,
                                  isExpanded: true,
                                  icon: const Icon(Icons.arrow_drop_down, color: AppColors.textSecondary),
                                  onChanged: (String? val) {
                                    if (val != null) {
                                      setState(() {
                                        _selectedGender = val;
                                      });
                                    }
                                  },
                                  items: const [
                                    DropdownMenuItem(value: 'Male', child: Text('Male')),
                                    DropdownMenuItem(value: 'Female', child: Text('Female')),
                                    DropdownMenuItem(value: 'Other', child: Text('Other')),
                                  ],
                                ),
                              ),
                            );

                            final addressField = TextFormField(
                              controller: _addressController,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                hintText: 'Enter physical address',
                                prefixIcon: Icon(Icons.location_on_outlined, size: 20),
                              ),
                              validator: (val) => Validators.required(val, 'Address'),
                            );

                            if (isNarrow) {
                              return Column(
                                children: [
                                  buildField('Full Name *', fullNameField),
                                  buildField('Phone Number *', phoneField),
                                  buildField('Age *', ageField),
                                  buildField('Gender *', genderField),
                                  buildField('Address *', addressField),
                                ],
                              );
                            }

                            return Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(child: buildField('Full Name *', fullNameField)),
                                    AppSizes.w24,
                                    Expanded(child: buildField('Phone Number *', phoneField)),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Expanded(child: buildField('Age *', ageField)),
                                    AppSizes.w24,
                                    Expanded(child: buildField('Gender *', genderField)),
                                  ],
                                ),
                                buildField('Address *', addressField),
                              ],
                            );
                          },
                        ),

                        // ── Medical Info (Therapy Only) ──
                        if (!isMassageChair) ...[
                          const Text(
                            'Medical Diagnosis & History',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          AppSizes.h8,
                          TextFormField(
                            controller: _conditionController,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              hintText: 'Primary Medical Condition (e.g. Chronic Back Pain)',
                              prefixIcon: Icon(Icons.local_hospital_outlined, size: 20),
                            ),
                            validator: (val) => Validators.required(val, 'Medical condition'),
                          ),
                          AppSizes.p20.hSpacingBox,
                          const SizedBox(height: 20),

                          const Text(
                            'Clinical Notes & Background',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          AppSizes.h8,
                          TextFormField(
                            controller: _notesController,
                            maxLines: 4,
                            keyboardType: TextInputType.multiline,
                            decoration: const InputDecoration(
                              hintText: 'Write down relevant patient details, habits, precautions, or session history guidelines...',
                              alignLabelWithHint: true,
                            ),
                          ),
                          AppSizes.h24,

                          if (isAdmin) ...[
                            const Text(
                              'Assign Therapist',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            AppSizes.h8,
                            staffAsync.when(
                              data: (staffList) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: AppSizes.p16),
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    border: Border.all(color: AppColors.border, width: 1.2),
                                    borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _selectedTherapistId,
                                      hint: const Text('Select a Therapist'),
                                      isExpanded: true,
                                      icon: const Icon(Icons.arrow_drop_down, color: AppColors.textSecondary),
                                      onChanged: (String? val) {
                                        if (val != null) {
                                          setState(() {
                                            _selectedTherapistId = val;
                                            _selectedTherapistName = staffList.firstWhere((s) => s.userId == val).fullName;
                                          });
                                        }
                                      },
                                      items: [
                                        const DropdownMenuItem(value: null, child: Text('Unassigned')),
                                        ...staffList.map((staff) {
                                          return DropdownMenuItem(
                                            value: staff.userId,
                                            child: Text(staff.fullName),
                                          );
                                        }),
                                      ],
                                    ),
                                  ),
                                );
                              },
                              loading: () => const Center(child: CircularProgressIndicator()),
                              error: (e, _) => Text('Error loading staff: $e'),
                            ),
                            AppSizes.h32,
                          ],
                          if (!isAdmin && _selectedTherapistName != null) ...[
                            Text(
                              'Assigned Therapist: $_selectedTherapistName',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                            ),
                            AppSizes.h32,
                          ],

                          const Divider(),
                          AppSizes.h20,
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryLight,
                                  borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
                                ),
                                child: const Icon(Icons.payment_rounded, color: AppColors.primary, size: 22),
                              ),
                              AppSizes.w12,
                              Text(
                                'Consultation Fee Details',
                                style: textTheme.headlineSmall?.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          AppSizes.h8,
                          const Text(
                            'Enter consultation fee and payment status for this patient.',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                          ),
                          AppSizes.h20,

                          LayoutBuilder(
                            builder: (context, constraints) {
                              final bool isNarrow = constraints.maxWidth < 600;

                              final feeField = TextFormField(
                                controller: _consultationFeeController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(
                                  hintText: 'Enter fee (e.g. 1500)',
                                  prefixIcon: Icon(Icons.payments_outlined, size: 20),
                                  prefixText: 'Rs. ',
                                ),
                                validator: (val) {
                                  if (val != null && val.trim().isNotEmpty) {
                                    if (double.tryParse(val.trim()) == null) {
                                      return 'Enter a valid amount';
                                    }
                                  }
                                  return null;
                                },
                                onChanged: (val) {
                                  setState(() {});
                                },
                              );

                              final hasFee = _consultationFeeController.text.trim().isNotEmpty;

                              final dateField = InkWell(
                                onTap: hasFee && _consultationPaymentStatus ? _pickConsultationPaymentDate : null,
                                child: InputDecorator(
                                  decoration: InputDecoration(
                                    prefixIcon: const Icon(Icons.calendar_today_rounded, size: 20),
                                    hintText: 'Select date',
                                    enabled: hasFee && _consultationPaymentStatus,
                                  ),
                                  child: Text(
                                    _consultationPaymentDate != null
                                        ? '${_consultationPaymentDate!.day.toString().padLeft(2, '0')}/${_consultationPaymentDate!.month.toString().padLeft(2, '0')}/${_consultationPaymentDate!.year}'
                                        : 'Select date',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      color: hasFee && _consultationPaymentStatus ? AppColors.textPrimary : AppColors.textLight,
                                    ),
                                  ),
                                ),
                              );

                              Widget buildField(String label, Widget field) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: AppSizes.p20),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        label,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: hasFee ? AppColors.textPrimary : AppColors.textLight,
                                        ),
                                      ),
                                      AppSizes.h8,
                                      field,
                                    ],
                                  ),
                                );
                              }

                              if (isNarrow) {
                                return Column(
                                  children: [
                                    buildField('Consultation Fee (Optional)', feeField),
                                    if (hasFee) ...[
                                      const Text(
                                        'Payment Status *',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      AppSizes.h8,
                                      _buildPaymentStatusToggle(),
                                      AppSizes.h20,
                                      if (_consultationPaymentStatus)
                                        buildField('Payment Date *', dateField),
                                    ],
                                  ],
                                );
                              }

                              return Column(
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(child: buildField('Consultation Fee (Optional)', feeField)),
                                      AppSizes.w24,
                                      Expanded(
                                        child: hasFee 
                                            ? Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  const Text(
                                                    'Payment Status *',
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      fontWeight: FontWeight.w600,
                                                      color: AppColors.textPrimary,
                                                    ),
                                                  ),
                                                  AppSizes.h8,
                                                  _buildPaymentStatusToggle(),
                                                ],
                                              )
                                            : const SizedBox(),
                                      ),
                                    ],
                                  ),
                                  if (hasFee && _consultationPaymentStatus)
                                    Row(
                                      children: [
                                        Expanded(child: buildField('Payment Date *', dateField)),
                                        AppSizes.w24,
                                        Expanded(child: const SizedBox()),
                                      ],
                                    ),
                                ],
                              );
                            },
                          ),

                          if (_consultationFeeController.text.trim().isNotEmpty) ...[
                            const Text(
                              'Consultation Billing Notes',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            AppSizes.h8,
                            TextFormField(
                              controller: _consultationNotesController,
                              maxLines: 2,
                              decoration: const InputDecoration(
                                hintText: 'Optional notes regarding consultation payment...',
                              ),
                            ),
                            AppSizes.h24,
                          ],
                        ],

                        // ── Massage Chair Billing Section (New Registrations Only) ──
                        if (isMassageChair && !_isEditMode) ...[
                          const Divider(),
                          AppSizes.h20,
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF3E0),
                                  borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
                                ),
                                child: const Icon(Icons.receipt_long_rounded, color: Color(0xFFE65100), size: 22),
                              ),
                              AppSizes.w12,
                              Text(
                                'Massage Chair Billing',
                                style: textTheme.headlineSmall?.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          AppSizes.h8,
                          const Text(
                            'Enter the billing details for this massage chair session.',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                          ),
                          AppSizes.h20,

                          LayoutBuilder(
                            builder: (context, constraints) {
                              final bool isNarrow = constraints.maxWidth < 600;

                              final dateField = InkWell(
                                onTap: _pickSessionDate,
                                child: InputDecorator(
                                  decoration: const InputDecoration(
                                    prefixIcon: Icon(Icons.calendar_today_rounded, size: 20),
                                    hintText: 'Select date',
                                  ),
                                  child: Text(
                                    '${_massageSessionDate.day.toString().padLeft(2, '0')}/${_massageSessionDate.month.toString().padLeft(2, '0')}/${_massageSessionDate.year}',
                                    style: const TextStyle(fontWeight: FontWeight.w500),
                                  ),
                                ),
                              );

                              final durationField = TextFormField(
                                controller: _durationController,
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(
                                  hintText: 'e.g. 30 minutes',
                                  prefixIcon: Icon(Icons.timer_outlined, size: 20),
                                ),
                              );

                              final feeField = TextFormField(
                                controller: _feeController,
                                keyboardType: TextInputType.number,
                                textInputAction: TextInputAction.done,
                                decoration: const InputDecoration(
                                  hintText: 'Enter fee amount',
                                  prefixIcon: Icon(Icons.payments_outlined, size: 20),
                                  prefixText: 'Rs. ',
                                ),
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) return 'Fee is required';
                                  if (double.tryParse(val.trim()) == null) return 'Enter a valid amount';
                                  return null;
                                },
                              );

                              Widget buildField(String label, Widget field) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: AppSizes.p20),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        label,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      AppSizes.h8,
                                      field,
                                    ],
                                  ),
                                );
                              }

                              if (isNarrow) {
                                return Column(
                                  children: [
                                    buildField('Session Date *', dateField),
                                    buildField('Duration (Optional)', durationField),
                                    buildField('Massage Chair Fee *', feeField),
                                  ],
                                );
                              }

                              return Column(
                                children: [
                                  Row(
                                    children: [
                                      Expanded(child: buildField('Session Date *', dateField)),
                                      AppSizes.w24,
                                      Expanded(child: buildField('Duration (Optional)', durationField)),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      Expanded(child: buildField('Massage Chair Fee *', feeField)),
                                      AppSizes.w24,
                                      Expanded(child: const SizedBox()),
                                    ],
                                  ),
                                ],
                              );
                            },
                          ),

                          // Payment Status Toggle
                          const Text(
                            'Payment Status *',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
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
                                    onTap: () => setState(() => _massagePaymentStatus = false),
                                    borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      decoration: BoxDecoration(
                                        color: !_massagePaymentStatus ? AppColors.error.withOpacity(0.1) : null,
                                        borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            !_massagePaymentStatus ? Icons.radio_button_checked : Icons.radio_button_off,
                                            color: !_massagePaymentStatus ? AppColors.error : AppColors.textSecondary,
                                            size: 18,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Unpaid',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: !_massagePaymentStatus ? AppColors.error : AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                Container(width: 1.2, height: 48, color: AppColors.border),
                                Expanded(
                                  child: InkWell(
                                    onTap: () => setState(() => _massagePaymentStatus = true),
                                    borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      decoration: BoxDecoration(
                                        color: _massagePaymentStatus ? AppColors.success.withOpacity(0.1) : null,
                                        borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            _massagePaymentStatus ? Icons.radio_button_checked : Icons.radio_button_off,
                                            color: _massagePaymentStatus ? AppColors.success : AppColors.textSecondary,
                                            size: 18,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Paid',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: _massagePaymentStatus ? AppColors.success : AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          AppSizes.h32,
                        ],

                        // Duplicate Warning Card
                        if (duplicatePatient != null) ...[
                          Container(
                            margin: const EdgeInsets.only(bottom: AppSizes.p24),
                            padding: const EdgeInsets.all(AppSizes.p16),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                              border: Border.all(color: AppColors.warning, width: 1.2),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 24),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Duplicate Patient Detected',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: AppColors.warning,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'A patient with this name or phone number is already registered:\n'
                                  '• Name: ${duplicatePatient.fullName}\n'
                                  '• Phone: ${duplicatePatient.phone}\n'
                                  '• ID: ${duplicatePatient.patientId}',
                                  style: const TextStyle(fontSize: 13, height: 1.4, color: AppColors.textPrimary),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    ElevatedButton.icon(
                                      onPressed: () {
                                        context.go('/patients/${duplicatePatient!.patientId}');
                                      },
                                      icon: const Icon(Icons.visibility_rounded, size: 16),
                                      label: const Text('Go to Existing Profile'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.warning,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],

                        // Actions Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton(
                              onPressed: () => context.go('/patients'),
                              child: const Text('Cancel'),
                            ),
                            AppSizes.w16,
                            ElevatedButton(
                              onPressed: (operationState.isLoading || duplicatePatient != null) ? null : _saveForm,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: AppSizes.p32, vertical: 18),
                              ),
                              child: operationState.isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                    )
                                  : Text(_isEditMode 
                                      ? 'Update Patient' 
                                      : isMassageChair 
                                          ? 'Register & Save Bill' 
                                          : 'Register Profile'),
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

  Widget _buildCustomerTypeOption({
    required IconData icon,
    required String label,
    required String subtitle,
    required String value,
    required bool isSelected,
  }) {
    return InkWell(
      onTap: () => setState(() => _customerType = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(AppSizes.p16),
        decoration: BoxDecoration(
          color: isSelected 
              ? (value == 'massage_chair' ? const Color(0xFFFFF3E0) : AppColors.primaryLight)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppSizes.radiusMedium - 1),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected 
                    ? (value == 'massage_chair' ? const Color(0xFFE65100) : AppColors.primary).withOpacity(0.15)
                    : AppColors.background,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isSelected 
                    ? (value == 'massage_chair' ? const Color(0xFFE65100) : AppColors.primary)
                    : AppColors.textSecondary,
                size: 22,
              ),
            ),
            AppSizes.w12,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: isSelected ? AppColors.textSecondary : AppColors.textLight,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle_rounded,
                color: value == 'massage_chair' ? const Color(0xFFE65100) : AppColors.primary,
                size: 22,
              ),
          ],
        ),
      ),
    );
  }
}

extension on double {
  SizedBox get hSpacingBox => SizedBox(height: this);
}
