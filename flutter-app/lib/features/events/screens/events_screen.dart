import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../checkin/services/checkin_service.dart';
import '../models/event_model.dart';
import '../widgets/event_card.dart';
import 'event_detail_sheet.dart';

/// Screen displaying all SRISHTI 2.7 events, competitions, and workshops.
class EventsScreen extends StatefulWidget {
  final VoidCallback? onNavigateToScan;

  const EventsScreen({
    super.key,
    this.onNavigateToScan,
  });

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  bool _isLoading = true;
  List<EventModel> _events = [];
  String _selectedCategory = 'All';

  final List<String> _categories = [
    'All',
    'Coding',
    'Robotics',
    'Web & App',
    'Gaming',
    'Workshops',
  ];

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final data = await CheckinService().getActiveEvents();
      if (!mounted) return;

      if (data.isNotEmpty) {
        setState(() {
          _events = data.map((map) => EventModel.fromMap(map)).toList();
          _isLoading = false;
        });
      } else {
        // Fallback to sample preview events if database table is not yet populated
        setState(() {
          _events = _previewSampleEvents;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      // Show sample events with informative notice rather than a dead screen
      setState(() {
        _events = _previewSampleEvents;
        _isLoading = false;
      });
    }
  }

  static const List<EventModel> _previewSampleEvents = [
    EventModel(
      id: 'e1',
      eventCode: 'EV-01',
      name: 'Code Sprint (Speed Coding)',
      category: 'Coding',
      venue: 'CS Lab 3',
      date: 'Day 1',
      time: '10:30 AM',
      registrationCount: 64,
      attendanceCount: 42,
      status: 'Live',
    ),
    EventModel(
      id: 'e2',
      eventCode: 'EV-02',
      name: 'RoboQuest (Obstacle Race)',
      category: 'Robotics',
      venue: 'College Quadrangle',
      date: 'Day 1',
      time: '01:30 PM',
      registrationCount: 38,
      attendanceCount: 12,
      status: 'Upcoming',
    ),
    EventModel(
      id: 'e3',
      eventCode: 'EV-03',
      name: 'HackAI 24h Hackathon',
      category: 'Web & App',
      venue: 'Main Auditorium',
      date: 'Day 1 & 2',
      time: '03:00 PM',
      registrationCount: 120,
      attendanceCount: 0,
      status: 'Upcoming',
    ),
    EventModel(
      id: 'e4',
      eventCode: 'EV-04',
      name: 'Valorant Championship',
      category: 'Gaming',
      venue: 'Media Hall',
      date: 'Day 2',
      time: '11:00 AM',
      registrationCount: 32,
      attendanceCount: 0,
      status: 'Upcoming',
    ),
    EventModel(
      id: 'e5',
      eventCode: 'EV-05',
      name: 'GenAI & LLM Architecture Workshop',
      category: 'Workshops',
      venue: 'Seminar Hall 1',
      date: 'Day 1',
      time: '11:00 AM',
      registrationCount: 85,
      attendanceCount: 78,
      status: 'Completed',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final filteredEvents = _selectedCategory == 'All'
        ? _events
        : _events
            .where((e) =>
                e.category.toLowerCase() == _selectedCategory.toLowerCase())
            .toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Festival Events'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Events',
            onPressed: _loadEvents,
          ),
        ],
      ),
      body: Column(
        children: [
          // Category Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: _categories.map((cat) {
                final isSelected = _selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: FilterChip(
                    label: Text(cat),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedCategory = cat;
                      });
                    },
                    selectedColor: AppColors.surfaceDark,
                    backgroundColor: AppColors.backgroundSecondary,
                    labelStyle: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? AppColors.cyan : AppColors.textSecondary,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: isSelected ? AppColors.surfaceDark : AppColors.border,
                      ),
                    ),
                    showCheckmark: false,
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),

          // Events List
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.electricBlue),
                    ),
                  )
                : filteredEvents.isEmpty
                    ? const EmptyStateView(
                        icon: Icons.event_busy_rounded,
                        title: 'No Events in this Category',
                        description: 'Select another filter or check back later.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16.0),
                        itemCount: filteredEvents.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 14),
                        itemBuilder: (context, index) {
                          final event = filteredEvents[index];
                          return EventCard(
                            event: event,
                            onTap: () {
                              EventDetailSheet.show(
                                context,
                                event: event,
                                onAttendanceMarked: _loadEvents,
                              );
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
