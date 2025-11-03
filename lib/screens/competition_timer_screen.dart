import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class CompetitionTimerScreen extends StatefulWidget {
  final DocumentSnapshot competition;
  final DocumentSnapshot traineeDoc; // 1. متغير جديد لاستقبال بيانات المتدرب

  const CompetitionTimerScreen({
    super.key,
    required this.competition,
    required this.traineeDoc, // مطلوب الآن
  });

  @override
  State<CompetitionTimerScreen> createState() => _CompetitionTimerScreenState();
}

class _CompetitionTimerScreenState extends State<CompetitionTimerScreen> {
  final Stopwatch _stopwatch = Stopwatch();
  late Timer _timer;
  String _result = '00:00:000';
  bool _isRunning = false;

  @override
  void initState() {
    super.initState();
    // المؤقت الذي سيقوم بتحديث الواجهة بشكل دوري
    _timer = Timer.periodic(const Duration(milliseconds: 30), (Timer timer) {
      if (_stopwatch.isRunning) {
        setState(() {
          // تنسيق الوقت لعرضه على الشاشة
          _result =
              '${_stopwatch.elapsed.inMinutes.toString().padLeft(2, '0')}:${(_stopwatch.elapsed.inSeconds % 60).toString().padLeft(2, '0')}:${(_stopwatch.elapsed.inMilliseconds % 1000).toString().padLeft(3, '0')}';
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel(); // إيقاف المؤقت عند إغلاق الشاشة
    super.dispose();
  }

  void _startStopwatch() {
    setState(() {
      _isRunning = true;
    });
    _stopwatch.start();
  }

  void _stopStopwatch() {
    setState(() {
      _isRunning = false;
    });
    _stopwatch.stop();
  }

  Future<void> _saveResult() async {
    // استخدام بيانات المتدرب التي تم تمريرها بدلاً من المستخدم الحالي
    final traineeId = widget.traineeDoc.id;
    final traineeName = widget.traineeDoc['displayName'] ?? 'Unknown Trainee';
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    await FirebaseFirestore.instance.collection('competition_entries').add({
      'competitionId': widget.competition.id,
      'competitionTitle': widget.competition['title'],
      'traineeUid': traineeId,
      'traineeName': traineeName,
      'score': _stopwatch.elapsed.inMilliseconds,
      'date': Timestamp.now(),
    });
    // ignore: use_build_context_synchronously
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Result for $traineeName has been saved!')),
    );

    _stopwatch.reset();
    // ignore: use_build_context_synchronously
    Navigator.of(context).pop(); // العودة للشاشة السابقة بعد الحفظ
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.competition['title']),
        automaticallyImplyLeading: !_isRunning, // منع الرجوع أثناء تشغيل المؤقت
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              _result,
              style: const TextStyle(fontSize: 60.0, fontFamily: 'monospace'),
            ),
            const SizedBox(height: 40),
            // إظهار زر البدء أو الإيقاف بناءً على حالة المؤقت
            if (!_isRunning &&
                !_stopwatch.isRunning &&
                _stopwatch.elapsedMilliseconds == 0)
              ElevatedButton(
                onPressed: _startStopwatch,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 50,
                    vertical: 20,
                  ),
                ),
                child: const Text(
                  'START',
                  style: TextStyle(fontSize: 24, color: Colors.white),
                ),
              ),
            if (_isRunning)
              ElevatedButton(
                onPressed: _stopStopwatch,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 50,
                    vertical: 20,
                  ),
                ),
                child: const Text(
                  'STOP',
                  style: TextStyle(fontSize: 24, color: Colors.white),
                ),
              ),
            // إظهار زر الحفظ بعد إيقاف المؤقت
            if (!_isRunning && _stopwatch.elapsedMilliseconds > 0)
              ElevatedButton(
                onPressed: _saveResult,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 50,
                    vertical: 20,
                  ),
                ),
                child: const Text(
                  'SAVE RESULT',
                  style: TextStyle(fontSize: 24, color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
