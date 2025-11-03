import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drone_academy/l10n/app_localizations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

class ScheduleScreen extends StatefulWidget {
  final String traineeId;
  const ScheduleScreen({super.key, required this.traineeId});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  late AppLocalizations l10n;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<DocumentSnapshot>> _events = {};

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    l10n = AppLocalizations.of(context)!;
  }

  Stream<Map<DateTime, List<DocumentSnapshot>>> _loadEvents() {
    return FirebaseFirestore.instance
        .collection('schedule')
        .where('traineeId', isEqualTo: widget.traineeId)
        .snapshots()
        .map((snapshot) {
          final eventsMap = <DateTime, List<DocumentSnapshot>>{};
          for (var doc in snapshot.docs) {
            final eventDate = (doc['startTime'] as Timestamp).toDate();
            final dayOnly = DateTime.utc(
              eventDate.year,
              eventDate.month,
              eventDate.day,
            );

            if (eventsMap[dayOnly] == null) {
              eventsMap[dayOnly] = [];
            }
            eventsMap[dayOnly]!.add(doc);
          }
          return eventsMap;
        });
  }

  Future<void> _showAddEventDialog() async {
    final titleController = TextEditingController();
    DateTime? selectedDate = _selectedDay;
    TimeOfDay? startTime;
    TimeOfDay? endTime;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(l10n.addSession),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(labelText: l10n.sessionTitle),
                    ),
                    const SizedBox(height: 20),
                    ListTile(
                      leading: const Icon(Icons.calendar_today),
                      title: Text(
                        selectedDate != null
                            ? DateFormat.yMMMd().format(selectedDate!)
                            : l10n.date,
                      ),
                      onTap: () async {
                        final pickedDate = await showDatePicker(
                          context: context,
                          initialDate: _focusedDay,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (pickedDate != null)
                          setDialogState(() => selectedDate = pickedDate);
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.access_time),
                      title: Text(
                        startTime != null
                            ? startTime!.format(context)
                            : l10n.startTime,
                      ),
                      onTap: () async {
                        final pickedTime = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.now(),
                        );
                        if (pickedTime != null)
                          setDialogState(() => startTime = pickedTime);
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.timelapse),
                      title: Text(
                        endTime != null
                            ? endTime!.format(context)
                            : l10n.endTime,
                      ),
                      onTap: () async {
                        final pickedTime = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.now(),
                        );
                        if (pickedTime != null)
                          setDialogState(() => endTime = pickedTime);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l10n.cancel),
                ),
                ElevatedButton(
                  onPressed:
                      (selectedDate != null &&
                          startTime != null &&
                          endTime != null &&
                          titleController.text.isNotEmpty)
                      ? () => _saveEvent(
                          titleController.text,
                          selectedDate!,
                          startTime!,
                          endTime!,
                        )
                      : null,
                  child: Text(l10n.save),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _saveEvent(
    String title,
    DateTime date,
    TimeOfDay start,
    TimeOfDay end,
  ) async {
    final trainerAuth = FirebaseAuth.instance.currentUser;
    if (trainerAuth == null) return;

    final trainerDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(trainerAuth.uid)
        .get();
    final trainerName = trainerDoc.data()?['displayName'] ?? 'Unknown';

    final startTime = DateTime(
      date.year,
      date.month,
      date.day,
      start.hour,
      start.minute,
    );
    final endTime = DateTime(
      date.year,
      date.month,
      date.day,
      end.hour,
      end.minute,
    );

    FirebaseFirestore.instance.collection('schedule').add({
      'title': title,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'traineeId': widget.traineeId,
      'trainerId': trainerAuth.uid,
      'trainerName': trainerName,
    });

    if (mounted) Navigator.of(context).pop();
    // --- هذا هو السطر الذي تم إضافته ---
    setState(() {}); // لإجبار الواجهة على إعادة البناء
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<List<DocumentSnapshot>>(
        // تغيير إلى FutureBuilder
        future:
            _loadEventsForSelectedDay(), // دالة جديدة لجلب بيانات اليوم المحدد
        builder: (context, snapshot) {
          final selectedEvents = snapshot.data ?? [];

          return Column(
            children: [
              TableCalendar(
                firstDay: DateTime.utc(2020, 1, 1),
                lastDay: DateTime.utc(2030, 12, 31),
                focusedDay: _focusedDay,
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });
                },
                eventLoader: (day) =>
                    _events[DateTime.utc(day.year, day.month, day.day)] ?? [],
              ),
              const SizedBox(height: 8.0),
              Expanded(
                child: ListView.builder(
                  itemCount: selectedEvents.length,
                  itemBuilder: (context, index) {
                    final event = selectedEvents[index];
                    final startTime = (event['startTime'] as Timestamp)
                        .toDate();
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      child: ListTile(
                        title: Text(event['title']),
                        subtitle: Text(
                          '${l10n.trainer}: ${event['trainerName']}',
                        ),
                        trailing: Text(DateFormat.jm().format(startTime)),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddEventDialog,
        tooltip: l10n.addSession,
        child: const Icon(Icons.add),
      ),
    );
  }

  // --- دالة جديدة لجلب بيانات اليوم المحدد فقط ---
  Future<List<DocumentSnapshot>> _loadEventsForSelectedDay() async {
    if (_selectedDay == null) return [];

    final startOfDay = DateTime.utc(
      _selectedDay!.year,
      _selectedDay!.month,
      _selectedDay!.day,
    );
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final snapshot = await FirebaseFirestore.instance
        .collection('schedule')
        .where('traineeId', isEqualTo: widget.traineeId)
        .where(
          'startTime',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
        )
        .where('startTime', isLessThan: Timestamp.fromDate(endOfDay))
        .get();

    // تحديث علامات التقويم
    _loadAllEventsForMarkers();
    return snapshot.docs;
  }

  // --- دالة مساعدة لتحديث علامات النقاط في التقويم ---
  void _loadAllEventsForMarkers() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('schedule')
        .where('traineeId', isEqualTo: widget.traineeId)
        .get();

    final eventsMap = <DateTime, List<DocumentSnapshot>>{};
    for (var doc in snapshot.docs) {
      final eventDate = (doc['startTime'] as Timestamp).toDate();
      final dayOnly = DateTime.utc(
        eventDate.year,
        eventDate.month,
        eventDate.day,
      );
      if (eventsMap[dayOnly] == null) {
        eventsMap[dayOnly] = [];
      }
      eventsMap[dayOnly]!.add(doc);
    }
    if (mounted) {
      setState(() {
        _events = eventsMap;
      });
    }
  }
}
