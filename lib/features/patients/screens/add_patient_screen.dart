import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/utils/validators.dart';
import '../../../models/patient_model.dart';
import '../providers/patients_provider.dart';

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
  
  String _selectedGender = 'Male';
  late bool _isEditMode;

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.patientId != null;
    _populateFields();
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
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _ageController.dispose();
    _addressController.dispose();
    _conditionController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _saveForm() async {
    if (_formKey.currentState!.validate()) {
      final messenger = ScaffoldMessenger.of(context);
      
      final patientId = _isEditMode 
          ? widget.patientId! 
          : 'PT-${const Uuid().v4().substring(0, 5).toUpperCase()}';
      
      final patient = PatientModel(
        patientId: patientId,
        fullName: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        age: int.parse(_ageController.text.trim()),
        gender: _selectedGender,
        address: _addressController.text.trim(),
        medicalCondition: _conditionController.text.trim(),
        notes: _notesController.text.trim(),
        registrationDate: _isEditMode 
            ? (widget.patient?.registrationDate ?? DateTime.now())
            : DateTime.now(),
      );

      final notifier = ref.read(patientOperationProvider.notifier);
      if (_isEditMode) {
        await notifier.updatePatient(patient);
      } else {
        await notifier.addPatient(patient);
      }

      final state = ref.read(patientOperationProvider);
      if (state.error != null) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Failed to save patient: ${state.error}'),
            backgroundColor: AppColors.error,
          ),
        );
      } else {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Patient ${patient.fullName} saved successfully.'),
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

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Patient Details' : 'Register New Patient'),
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
                            Text(
                              _isEditMode ? 'Edit Patient File' : 'Create Patient Profile',
                              style: textTheme.headlineLarge?.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        AppSizes.h12,
                        Text(
                          'Fill in the personal and medical details below to proceed.',
                          style: textTheme.bodyMedium,
                        ),
                        AppSizes.h24,
                        const Divider(),
                        AppSizes.h24,

                        // Form Grid (Responsive wrap)
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

                        // Medical Info block
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
                        AppSizes.p20.hSpacingBox, // using a custom sizedbox or size tokens
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
                        AppSizes.h32,

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
                                  : Text(_isEditMode ? 'Update Patient' : 'Register Profile'),
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

extension on double {
  SizedBox get hSpacingBox => SizedBox(height: this);
}
