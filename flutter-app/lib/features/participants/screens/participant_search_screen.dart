import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../checkin/models/attendance_mode.dart';
import '../../checkin/services/checkin_service.dart';
import '../models/participant_model.dart';
import '../services/participant_service.dart';
import '../widgets/participant_card.dart';
import 'participant_detail_sheet.dart';

/// Screen for manual participant lookup supporting both:
/// 1. Festival Arrival Check-in
/// 2. Event-Specific Attendance Verification
class ParticipantSearchScreen extends StatefulWidget {
  final AttendanceMode mode;
  final String? eventId;
  final String? eventName;

  const ParticipantSearchScreen({
    super.key,
    this.mode = AttendanceMode.arrival,
    this.eventId,
    this.eventName,
  });

  @override
  State<ParticipantSearchScreen> createState() => _ParticipantSearchScreenState();
}

class _ParticipantSearchScreenState extends State<ParticipantSearchScreen> {
  final _searchController = TextEditingController();
  final CheckinService _checkinService = CheckinService();
  Timer? _debounceTimer;

  bool _isLoading = false;
  List<ParticipantModel> _results = [];
  String? _errorMessage;
  bool _hasSearched = false;

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) {
      setState(() {
        _results = [];
        _hasSearched = false;
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _hasSearched = true;
    });

    try {
      final data = await ParticipantService().searchParticipants(cleanQuery);
      
      // Fetch checkin status for each returned participant
      final List<ParticipantModel> mapped = [];
      for (final item in data) {
        final checkin = await _checkinService.getArrivalCheckin(item['id'].toString());
        mapped.add(
          ParticipantModel.fromMap(
            item,
            isCheckedIn: checkin != null,
            checkedInAt: checkin != null && checkin['checked_in_at'] != null
                ? DateTime.tryParse(checkin['checked_in_at'].toString())
                : null,
          ),
        );
      }

      if (!mounted) return;
      setState(() {
        _results = mapped;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Search error: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEvent = widget.mode == AttendanceMode.event;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(isEvent ? 'Event Lookup' : 'Participant Lookup'),
            Text(
              isEvent
                  ? (widget.eventName ?? 'Event Attendance')
                  : 'FEST Arrival Check-in',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.electricBlue,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(68),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              onChanged: _onSearchChanged,
              style: const TextStyle(fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Search code (SRI27-...), name, phone, email',
                prefixIcon: const Icon(Icons.search_rounded, size: 22),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                      )
                    : null,
              ),
            ),
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.electricBlue),
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 48, color: AppColors.error),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => _performSearch(_searchController.text),
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    if (!_hasSearched) {
      return EmptyStateView(
        icon: Icons.person_search_rounded,
        title: widget.mode == AttendanceMode.event
            ? 'Manual Event Check-in'
            : 'Search Participants',
        description: widget.mode == AttendanceMode.event
            ? 'Find participant to verify FEST arrival and event registration for ${widget.eventName ?? "this event"}.'
            : 'Enter participant code, name, phone number, or email address to record arrival check-in.',
      );
    }

    if (_results.isEmpty) {
      return const EmptyStateView(
        icon: Icons.search_off_rounded,
        title: 'No Participants Found',
        description: 'No registered participant matches your search query. Please double check the details.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16.0),
      itemCount: _results.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final participant = _results[index];
        return ParticipantCard(
          participant: participant,
          onTap: () {
            ParticipantDetailSheet.show(
              context,
              participant: participant,
              mode: widget.mode,
              eventId: widget.eventId,
              eventName: widget.eventName,
              source: 'manual', // Manual operation
              onActionSuccess: () {
                _performSearch(_searchController.text);
              },
            );
          },
        );
      },
    );
  }
}
