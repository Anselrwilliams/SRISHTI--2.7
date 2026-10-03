import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/unified/unified_design_system.dart';
import '../../auth/models/volunteer_model.dart';
import '../../events/models/event_model.dart';
import '../models/spot_registration_draft.dart';
import '../models/team_member_model.dart';
import '../services/spot_registration_service.dart';
import 'spot_payment_screen.dart';

/// Step 1: Participant Information and Event Selection form for Spot Registration.
/// Supports both Individual and dynamic Team events.
class SpotRegistrationScreen extends StatefulWidget {
  final VolunteerModel volunteer;
  final SpotRegistrationService? spotRegistrationService;

  const SpotRegistrationScreen({
    super.key,
    required this.volunteer,
    this.spotRegistrationService,
  });

  @override
  State<SpotRegistrationScreen> createState() => _SpotRegistrationScreenState();
}

class _SpotRegistrationScreenState extends State<SpotRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();

  late final SpotRegistrationService _service;

  // Controllers for primary participant (Leader)
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _collegeController = TextEditingController();

  String _selectedYear = '3rd Year';
  final List<String> _yearOptions = [
    '1st Year',
    '2nd Year',
    '3rd Year',
    '4th Year',
    'Post Graduate',
    'Other',
  ];

  // Event Selection state
  List<EventModel> _availableEvents = [];
  EventModel? _selectedEvent;
  bool _isLoadingEvents = true;

  // Team Members state
  final List<Map<String, TextEditingController>> _memberControllers = [];

  @override
  void initState() {
    super.initState();
    _service = widget.spotRegistrationService ?? SpotRegistrationService();
    _loadEvents();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _collegeController.dispose();
    for (final ctrlMap in _memberControllers) {
      for (final ctrl in ctrlMap.values) {
        ctrl.dispose();
      }
    }
    super.dispose();
  }

  Future<void> _loadEvents() async {
    setState(() => _isLoadingEvents = true);
    try {
      final events = await _service.getAvailableEvents();
      if (!mounted) return;
      setState(() {
        _availableEvents = events;
        if (events.isNotEmpty) {
          _selectedEvent = events.first;
        } else {
          _selectedEvent = null;
        }
        _isLoadingEvents = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _availableEvents = [];
        _selectedEvent = null;
        _isLoadingEvents = false;
      });
    }
  }

  void _onEventChanged(EventModel? event) {
    if (event == null) return;
    setState(() {
      _selectedEvent = event;
      // Adjust team members if team size changed
      if (event.isIndividualEvent) {
        _clearTeamMembers();
      } else {
        // Enforce max team size
        final maxAllowedExtra = event.effectiveMaxTeamSize - 1;
        while (_memberControllers.length > maxAllowedExtra) {
          _removeTeamMember(_memberControllers.length - 1);
        }
      }
    });
  }

  void _addTeamMember() {
    final event = _selectedEvent;
    if (event == null) return;

    final maxExtra = event.effectiveMaxTeamSize - 1;
    if (_memberControllers.length >= maxExtra) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Maximum team size for ${event.name} is ${event.effectiveMaxTeamSize} (including leader).',
          ),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() {
      _memberControllers.add({
        'name': TextEditingController(),
        'phone': TextEditingController(),
        'email': TextEditingController(),
        'college': TextEditingController(text: _collegeController.text.trim()),
      });
    });
  }

  void _removeTeamMember(int index) {
    if (index >= 0 && index < _memberControllers.length) {
      setState(() {
        final removed = _memberControllers.removeAt(index);
        for (final ctrl in removed.values) {
          ctrl.dispose();
        }
      });
    }
  }

  void _clearTeamMembers() {
    for (final ctrlMap in _memberControllers) {
      for (final ctrl in ctrlMap.values) {
        ctrl.dispose();
      }
    }
    _memberControllers.clear();
  }

  void _handleContinue() {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please correct the highlighted errors in the form.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_selectedEvent == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an event for registration.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    // Assemble team members
    final List<TeamMemberModel> teamMembers = [];
    if (_selectedEvent!.isTeamEvent) {
      for (final ctrlMap in _memberControllers) {
        teamMembers.add(
          TeamMemberModel(
            name: ctrlMap['name']!.text.trim(),
            phone: ctrlMap['phone']!.text.trim(),
            email: ctrlMap['email']!.text.trim().isNotEmpty
                ? ctrlMap['email']!.text.trim()
                : null,
            college: ctrlMap['college']!.text.trim().isNotEmpty
                ? ctrlMap['college']!.text.trim()
                : _collegeController.text.trim(),
          ),
        );
      }
    }

    final draft = SpotRegistrationDraft(
      fullName: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      email: _emailController.text.trim(),
      college: _collegeController.text.trim(),
      yearOfStudy: _selectedYear,
      selectedEvent: _selectedEvent,
      teamMembers: teamMembers,
    );

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SpotPaymentScreen(
          volunteer: widget.volunteer,
          draft: draft,
          spotRegistrationService: _service,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.volunteer.isRegistration && !widget.volunteer.isAdmin) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Access Denied'),
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.textPrimary,
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.gpp_bad_rounded, size: 48, color: AppColors.error),
                SizedBox(height: 16),
                Text(
                  'Access Denied',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Only Registration Coordinators can access Spot Registration.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Spot Registration',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        elevation: 0,
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
      ),
      body: UnifiedBackground(
        child: SafeArea(
          child: _isLoadingEvents
              ? const Center(child: CircularProgressIndicator())
              : _availableEvents.isEmpty
                  ? _buildEmptyEventsView()
                  : Form(
                      key: _formKey,
                      child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20.0, 16.0, 20.0, 32.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Step progress banner
                        _buildStepIndicator(
                          currentStep: 1,
                          stepTitle: 'Step 1 of 3: Details & Event',
                        ),
                        const SizedBox(height: 20),

                        // Section 1: Participant Information Card
                        _buildSectionCard(
                          title: 'PARTICIPANT DETAILS',
                          icon: Icons.person_rounded,
                          subtitle: _selectedEvent?.isTeamEvent == true
                              ? 'Primary Contact / Team Leader'
                              : 'Candidate Information',
                          children: [
                            _buildTextField(
                              controller: _nameController,
                              label: 'Full Name *',
                              hint: 'e.g. Rahul Sharma',
                              icon: Icons.badge_rounded,
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'Full Name is required';
                                }
                                if (val.trim().length < 2) {
                                  return 'Name must be at least 2 characters';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                            _buildTextField(
                              controller: _phoneController,
                              label: 'Phone Number *',
                              hint: 'e.g. 9876543210',
                              icon: Icons.phone_rounded,
                              keyboardType: TextInputType.phone,
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'Phone number is required';
                                }
                                final clean = val.replaceAll(RegExp(r'[^0-9]'), '');
                                if (clean.length < 10) {
                                  return 'Enter a valid 10-digit phone number';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                            _buildTextField(
                              controller: _emailController,
                              label: 'Email Address *',
                              hint: 'e.g. rahul@example.com',
                              icon: Icons.email_rounded,
                              keyboardType: TextInputType.emailAddress,
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'Email is required';
                                }
                                final emailRegex = RegExp(
                                  r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
                                );
                                if (!emailRegex.hasMatch(val.trim())) {
                                  return 'Enter a valid email address';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                            _buildTextField(
                              controller: _collegeController,
                              label: 'College / Institution *',
                              hint: 'e.g. Govt Engineering College',
                              icon: Icons.school_rounded,
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'College is required';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                            _buildYearDropdown(),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Section 2: Event Selection Card
                        _buildSectionCard(
                          title: 'SELECT EVENT',
                          icon: Icons.event_available_rounded,
                          subtitle: 'Competition or Workshop',
                          children: [
                            _buildEventDropdown(),
                            if (_selectedEvent != null) ...[
                              const SizedBox(height: 14),
                              _buildSelectedEventInfoCard(_selectedEvent!),
                            ],
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Section 3: Team Members Card (Conditional on Team Event)
                        if (_selectedEvent?.isTeamEvent == true) ...[
                          _buildTeamMembersCard(),
                          const SizedBox(height: 20),
                        ],

                        // Submit / Continue Button
                        _buildContinueButton(),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator({
    required int currentStep,
    required String stepTitle,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: AppColors.softShadow,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.how_to_reg_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stepTitle,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'On-spot participant verification & ticket issue',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.blue.withAlpha(20),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Desk Desk',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.blue,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required String subtitle,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: AppColors.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AppColors.blue),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(
        fontSize: 14.5,
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 20, color: AppColors.textSecondary),
        filled: true,
        fillColor: AppColors.backgroundSecondary.withAlpha(120),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.blue, width: 1.8),
        ),
      ),
      validator: validator,
    );
  }

  Widget _buildYearDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _selectedYear,
      decoration: InputDecoration(
        labelText: 'Year of Study *',
        prefixIcon:
            const Icon(Icons.school_outlined, size: 20, color: AppColors.textSecondary),
        filled: true,
        fillColor: AppColors.backgroundSecondary.withAlpha(120),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
      ),
      items: _yearOptions.map((year) {
        return DropdownMenuItem(
          value: year,
          child: Text(
            year,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        );
      }).toList(),
      onChanged: (val) {
        if (val != null) setState(() => _selectedYear = val);
      },
    );
  }

  Widget _buildEventDropdown() {
    return DropdownButtonFormField<EventModel>(
      initialValue: _selectedEvent,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Select Target Event *',
        prefixIcon:
            const Icon(Icons.stars_rounded, size: 20, color: AppColors.blue),
        filled: true,
        fillColor: AppColors.backgroundSecondary.withAlpha(120),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
      ),
      items: _availableEvents.map((ev) {
        final typeLabel = ev.isTeamEvent ? 'Team (Max ${ev.effectiveMaxTeamSize})' : 'Individual';
        return DropdownMenuItem<EventModel>(
          value: ev,
          child: Text(
            '${ev.name} [${ev.eventCode}] • $typeLabel',
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
          ),
        );
      }).toList(),
      onChanged: _onEventChanged,
    );
  }

  Widget _buildSelectedEventInfoCard(EventModel event) {
    final feeText = event.registrationFee != null && event.registrationFee! > 0
        ? '₹${event.registrationFee!.toStringAsFixed(0)}'
        : '₹150';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary.withAlpha(140),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: event.isTeamEvent
                      ? AppColors.purple.withAlpha(25)
                      : AppColors.blue.withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  event.isTeamEvent
                      ? 'TEAM EVENT (MAX ${event.effectiveMaxTeamSize})'
                      : 'INDIVIDUAL EVENT',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: event.isTeamEvent ? AppColors.purple : AppColors.blue,
                  ),
                ),
              ),
              Text(
                'Fee: $feeText',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            event.name,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text(
                event.venue ?? 'Venue TBA',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(width: 14),
              const Icon(Icons.access_time_rounded, size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text(
                event.time ?? 'Time TBA',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTeamMembersCard() {
    final event = _selectedEvent!;
    final maxExtraMembers = event.effectiveMaxTeamSize - 1;
    final canAddMore = _memberControllers.length < maxExtraMembers;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.purple.withAlpha(80)),
        boxShadow: AppColors.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.groups_rounded, size: 22, color: AppColors.purple),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'TEAM MEMBERS',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        '${1 + _memberControllers.length} of ${event.effectiveMaxTeamSize} Members',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (canAddMore)
                TextButton.icon(
                  onPressed: _addTeamMember,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text(
                    'Add Member',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.purple,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // Note explaining leader is Member 1
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.purpleBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.purpleBorder),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.purple),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Team Leader (Member 1): ${_nameController.text.trim().isNotEmpty ? _nameController.text.trim() : "Primary Participant"}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.purple,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          if (_memberControllers.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'No additional members added yet.\nTap "+ Add Member" to add up to $maxExtraMembers more members.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ),
            ),

          // Dynamic Team Member Cards
          for (int i = 0; i < _memberControllers.length; i++) ...[
            _buildMemberFormCard(i),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _buildMemberFormCard(int index) {
    final controllers = _memberControllers[index];
    final memberNum = index + 2; // Member 1 is Team Leader

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary.withAlpha(120),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Member #$memberNum',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.error),
                onPressed: () => _removeTeamMember(index),
                tooltip: 'Remove Member',
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: controllers['name'],
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              labelText: 'Member Name *',
              hintText: 'Full Name',
              isDense: true,
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.border),
              ),
            ),
            validator: (val) {
              if (_selectedEvent?.isTeamEvent == true && (val == null || val.trim().isEmpty)) {
                return 'Member name is required';
              }
              return null;
            },
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: controllers['phone'],
            keyboardType: TextInputType.phone,
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              labelText: 'Phone Number *',
              hintText: '10-digit mobile',
              isDense: true,
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.border),
              ),
            ),
            validator: (val) {
              if (_selectedEvent?.isTeamEvent == true && (val == null || val.trim().isEmpty)) {
                return 'Phone is required';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildContinueButton() {
    final event = _selectedEvent;
    final totalMembers = 1 + _memberControllers.length;
    final amount = event?.registrationFee != null && event!.registrationFee! > 0
        ? event.registrationFee!
        : (event?.isTeamEvent == true ? (100.0 * totalMembers) : 150.0);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.glowShadow,
      ),
      child: ElevatedButton(
        onPressed: _handleContinue,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Ink(
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Continue to Payment',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(50),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '₹${amount.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyEventsView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.borderLight),
                boxShadow: AppColors.softShadow,
              ),
              child: const Icon(
                Icons.event_busy_rounded,
                size: 48,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No Events Available',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Unable to load events from the festival database or no events are currently published for spot registration.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadEvents,
              icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 18),
              label: const Text(
                'Retry Loading Events',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.blue,
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
