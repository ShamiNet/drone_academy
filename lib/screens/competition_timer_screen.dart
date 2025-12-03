import 'dart:async';
import 'package:drone_academy/services/api_service.dart';
import 'package:flutter/material.dart';

class CompetitionTimerScreen extends StatefulWidget {
  final Map<String, dynamic> competition; // Map
  final Map<String, dynamic> traineeDoc; // Map

  const CompetitionTimerScreen({
    super.key,
    required this.competition,
    required this.traineeDoc,
  });

  @override
  State<CompetitionTimerScreen> createState() => _CompetitionTimerScreenState();
}

class _CompetitionTimerScreenState extends State<CompetitionTimerScreen> {
  final ApiService _apiService = ApiService();
  final Stopwatch _stopwatch = Stopwatch();
  late Timer _timer;
  String _result = '00:00:000';
  bool _isRunning = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 30), (Timer timer) {
      if (_stopwatch.isRunning) {
        setState(() {
          _result =
              '${_stopwatch.elapsed.inMinutes.toString().padLeft(2, '0')}:${(_stopwatch.elapsed.inSeconds % 60).toString().padLeft(2, '0')}:${(_stopwatch.elapsed.inMilliseconds % 1000).toString().padLeft(3, '0')}';
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
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
    final traineeId = widget.traineeDoc['id'] ?? widget.traineeDoc['uid'];
    final traineeName = widget.traineeDoc['displayName'] ?? 'Unknown';

    await _apiService.addCompetitionEntry({
      'competitionId': widget.competition['id'],
      'competitionTitle': widget.competition['title'],
      'traineeUid': traineeId,
      'traineeName': traineeName,
      'score': _stopwatch.elapsed.inMilliseconds,
      'date': DateTime.now().toIso8601String(),
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Result for $traineeName has been saved!')),
      );
      Navigator.of(context).pop();
    }
    _stopwatch.reset();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.competition['title']),
        automaticallyImplyLeading: !_isRunning,
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
