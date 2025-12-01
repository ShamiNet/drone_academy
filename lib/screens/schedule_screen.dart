import 'package:cloud_firestore/cloud_firestore.dart'; // نحتاجها فقط لنوع Timestamp إذا كان مستخدماً في مكان ما، لكن سنحاول تجنبه
import 'package:drone_academy/l10n/app_localizations.dart';
import 'package:drone_academy/services/api_service.dart';
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
  final ApiService _apiService = ApiService();
  late AppLocalizations l10n;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  // تخزين الأحداث: المفتاح هو التاريخ (بدون وقت)، القيمة هي قائمة الأحداث
  Map<DateTime, List<dynamic>> _events = {};

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

  // دالة مساعدة لتحويل قائمة الأحداث القادمة من API إلى Map للتقويم
  Map<DateTime, List<dynamic>> _groupEventsByDate(List<dynamic> events) {
    final Map<DateTime, List<dynamic>> data = {};
    for (var event in events) {
      final startTimeString = event['startTime'];
      if (startTimeString == null) continue;

      final eventDate = DateTime.parse(startTimeString);
      final dayOnly = DateTime.utc(
        eventDate.year,
        eventDate.month,
        eventDate.day,
      );

      if (data[dayOnly] == null) {
        data[dayOnly] = [];
      }
      data[dayOnly]!.add(event);
    }
    return data;
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
              backgroundColor: const Color(0xFF1E2230),
              title: Text(
                l10n.addSession,
                style: const TextStyle(color: Colors.white),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: titleController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: l10n.sessionTitle,
                        labelStyle: const TextStyle(color: Colors.grey),
                        enabledBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ListTile(
                      leading: const Icon(
                        Icons.calendar_today,
                        color: Colors.grey,
                      ),
                      title: Text(
                        selectedDate != null
                            ? DateFormat.yMMMd().format(selectedDate!)
                            : l10n.date,
                        style: const TextStyle(color: Colors.white),
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
                      leading: const Icon(
                        Icons.access_time,
                        color: Colors.grey,
                      ),
                      title: Text(
                        startTime != null
                            ? startTime!.format(context)
                            : l10n.startTime,
                        style: const TextStyle(color: Colors.white),
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
                      leading: const Icon(Icons.timelapse, color: Colors.grey),
                      title: Text(
                        endTime != null
                            ? endTime!.format(context)
                            : l10n.endTime,
                        style: const TextStyle(color: Colors.white),
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
                  child: Text(
                    l10n.cancel,
                    style: const TextStyle(color: Colors.grey),
                  ),
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8FA1B4),
                    foregroundColor: Colors.black,
                  ),
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

    // بما أننا لا نستطيع استخدام Firestore لجلب اسم المدرب مباشرة، نرسل المعرف
    // أو نجلبه عبر API (للتبسيط سنرسل المعرف واسم افتراضي أو نجلبه من المستخدم الحالي)
    final trainerName = trainerAuth.displayName ?? 'Unknown';

    final startDateTime = DateTime(
      date.year,
      date.month,
      date.day,
      start.hour,
      start.minute,
    );
    final endDateTime = DateTime(
      date.year,
      date.month,
      date.day,
      end.hour,
      end.minute,
    );

    await _apiService.addScheduleEvent({
      'title': title,
      'startTime': startDateTime,
      'endTime': endDateTime,
      'traineeId': widget.traineeId,
      'trainerId': trainerAuth.uid,
      'trainerName': trainerName,
    });

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    const bgColor = Color(0xFF111318);

    return Scaffold(
      backgroundColor: bgColor,
      body: StreamBuilder<List<dynamic>>(
        stream: _apiService.streamSchedule(traineeId: widget.traineeId),
        builder: (context, snapshot) {
          final allEventsList = snapshot.data ?? [];
          // تحديث خريطة الأحداث
          _events = _groupEventsByDate(allEventsList);

          // الحصول على أحداث اليوم المحدد
          final selectedEvents =
              _events[DateTime.utc(
                _selectedDay!.year,
                _selectedDay!.month,
                _selectedDay!.day,
              )] ??
              [];

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

                // تنسيق التقويم للوضع الداكن
                calendarStyle: const CalendarStyle(
                  defaultTextStyle: TextStyle(color: Colors.white),
                  weekendTextStyle: TextStyle(color: Colors.white70),
                  outsideTextStyle: TextStyle(color: Colors.grey),
                  selectedDecoration: BoxDecoration(
                    color: Color(0xFF8FA1B4),
                    shape: BoxShape.circle,
                  ),
                  todayDecoration: BoxDecoration(
                    color: Color(0xFF3F51B5),
                    shape: BoxShape.circle,
                  ),
                  markerDecoration: BoxDecoration(
                    color: Color(0xFFFF9800),
                    shape: BoxShape.circle,
                  ),
                ),
                headerStyle: const HeaderStyle(
                  titleTextStyle: TextStyle(color: Colors.white, fontSize: 16),
                  formatButtonVisible: false,
                  leftChevronIcon: Icon(
                    Icons.chevron_left,
                    color: Colors.white,
                  ),
                  rightChevronIcon: Icon(
                    Icons.chevron_right,
                    color: Colors.white,
                  ),
                ),
                daysOfWeekStyle: const DaysOfWeekStyle(
                  weekdayStyle: TextStyle(color: Colors.grey),
                  weekendStyle: TextStyle(color: Colors.grey),
                ),
              ),
              const SizedBox(height: 8.0),
              Expanded(
                child: ListView.builder(
                  itemCount: selectedEvents.length,
                  itemBuilder: (context, index) {
                    final event = selectedEvents[index];
                    final startTime = DateTime.parse(event['startTime']);

                    return Card(
                      color: const Color(0xFF1E2230),
                      margin: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      child: ListTile(
                        title: Text(
                          event['title'] ?? '',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          '${l10n.trainer}: ${event['trainerName'] ?? "Unknown"}',
                          style: const TextStyle(color: Colors.grey),
                        ),
                        trailing: Text(
                          DateFormat.jm().format(startTime),
                          style: const TextStyle(
                            color: Color(0xFF8FA1B4),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
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
        backgroundColor: const Color(0xFFFF9800),
        child: const Icon(Icons.add, color: Colors.black),
      ),
    );
  }
}
