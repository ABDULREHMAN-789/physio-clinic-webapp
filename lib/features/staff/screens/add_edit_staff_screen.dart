import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../models/user_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/staff_provider.dart';

class AddEditStaffScreen extends ConsumerStatefulWidget {
  final String? staffId;
  final UserModel? staff;

  const AddEditStaffScreen({super.key, this.staffId, this.staff});

  @override
  ConsumerState<AddEditStaffScreen> createState() => _AddEditStaffScreenState();
}

class _AddEditStaffScreenState extends ConsumerState<AddEditStaffScreen> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _qualificationController;
  late TextEditingController _specializationController;
  late TextEditingController _passwordController;
  late TextEditingController _revenuePercentageController;
  
  String _status = 'Active';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.staff?.fullName ?? '');
    _emailController = TextEditingController(text: widget.staff?.email ?? '');
    _phoneController = TextEditingController(text: widget.staff?.phone ?? '');
    _qualificationController = TextEditingController(text: widget.staff?.qualification ?? '');
    _specializationController = TextEditingController(text: widget.staff?.specialization ?? '');
    _passwordController = TextEditingController();
    _revenuePercentageController = TextEditingController(
      text: widget.staff != null ? widget.staff!.revenuePercentage.toStringAsFixed(0) : '30',
    );
    if (widget.staff != null) {
      _status = widget.staff!.status;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _qualificationController.dispose();
    _specializationController.dispose();
    _passwordController.dispose();
    _revenuePercentageController.dispose();
    super.dispose();
  }

  Future<void> _saveStaff() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final staffService = ref.read(staffServiceProvider);
      final adminUser = ref.read(authProvider).userModel;

      if (adminUser == null) throw Exception('Admin user not found in state.');

      final revenuePercent = double.tryParse(_revenuePercentageController.text.trim()) ?? 30.0;

      if (widget.staff == null) {
        // Adding new staff
        final newStaff = UserModel(
          userId: '', // generated later
          fullName: _nameController.text.trim(),
          email: _emailController.text.trim(),
          phone: _phoneController.text.trim(),
          role: 'Therapist',
          specialization: _specializationController.text.trim(),
          qualification: _qualificationController.text.trim(),
          status: _status,
          createdAt: DateTime.now(),
          revenuePercentage: revenuePercent,
        );
        await staffService.addStaff(newStaff, _passwordController.text.trim(), adminUser);
      } else {
        // Updating existing staff
        final updatedStaff = widget.staff!.copyWith(
          fullName: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
          qualification: _qualificationController.text.trim(),
          specialization: _specializationController.text.trim(),
          status: _status,
          revenuePercentage: revenuePercent,
        );
        await staffService.updateStaff(updatedStaff, adminUser);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.staff == null ? 'Staff added successfully!' : 'Staff updated successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isEditing = widget.staff != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Therapist Details' : 'Add New Therapist'),
        backgroundColor: Colors.white,
        scrolledUnderElevation: 0,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSizes.p24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSizes.p24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Staff Profile',
                          style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                        ),
                        const Divider(),
                        AppSizes.h16,
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.person_outline)),
                          validator: (val) => val == null || val.isEmpty ? 'Required field' : null,
                        ),
                        AppSizes.h16,
                        TextFormField(
                          controller: _emailController,
                          decoration: const InputDecoration(labelText: 'Email Address', prefixIcon: Icon(Icons.email_outlined)),
                          enabled: !isEditing, // Email usually shouldn't be changed easily in Firebase
                          validator: (val) => val == null || !val.contains('@') ? 'Enter a valid email' : null,
                        ),
                        AppSizes.h16,
                        TextFormField(
                          controller: _phoneController,
                          decoration: const InputDecoration(labelText: 'Phone Number', prefixIcon: Icon(Icons.phone_outlined)),
                        ),
                        AppSizes.h16,
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _qualificationController,
                                decoration: const InputDecoration(labelText: 'Qualification (e.g. DPT)'),
                              ),
                            ),
                            AppSizes.w16,
                            Expanded(
                              child: TextFormField(
                                controller: _specializationController,
                                decoration: const InputDecoration(labelText: 'Specialization'),
                              ),
                            ),
                          ],
                        ),
                        AppSizes.h16,
                        TextFormField(
                          controller: _revenuePercentageController,
                          decoration: const InputDecoration(
                            labelText: 'Revenue Percentage (%)',
                            prefixIcon: Icon(Icons.percent_rounded),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Required field';
                            }
                            final numVal = double.tryParse(val.trim());
                            if (numVal == null) {
                              return 'Enter a valid number';
                            }
                            if (numVal < 0 || numVal > 100) {
                              return 'Percentage must be between 0 and 100';
                            }
                            return null;
                          },
                        ),
                        AppSizes.h16,
                        DropdownButtonFormField<String>(
                          value: _status,
                          decoration: const InputDecoration(labelText: 'Status'),
                          items: const [
                            DropdownMenuItem(value: 'Active', child: Text('Active')),
                            DropdownMenuItem(value: 'Inactive', child: Text('Inactive')),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _status = val);
                          },
                        ),
                        if (!isEditing) ...[
                          AppSizes.h16,
                          TextFormField(
                            controller: _passwordController,
                            decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock_outline)),
                            obscureText: true,
                            validator: (val) => val == null || val.length < 6 ? 'Password must be at least 6 characters' : null,
                          ),
                        ],
                        AppSizes.h32,
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _saveStaff,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: AppSizes.p16),
                            ),
                            child: _isLoading
                                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : Text(isEditing ? 'Save Changes' : 'Register Therapist', style: const TextStyle(fontSize: 16)),
                          ),
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
