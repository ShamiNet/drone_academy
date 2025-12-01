import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class DebugConnectionScreen extends StatefulWidget {
  const DebugConnectionScreen({super.key});

  @override
  State<DebugConnectionScreen> createState() => _DebugConnectionScreenState();
}

class _DebugConnectionScreenState extends State<DebugConnectionScreen> {
  String _status = "اضغط على الزر لفحص الاتصال";
  String _logs = "";
  bool _isLoading = false;

  // رابط سيرفرك
  final String baseUrl = 'http://qaaz.live:3000/api';

  void _log(String message) {
    print("DEBUG_TEST: $message"); // يطبع في الكونسول
    setState(() {
      _logs += "$message\n\n"; // يطبع على الشاشة
    });
  }

  Future<void> _testConnection() async {
    setState(() {
      _isLoading = true;
      _logs = "";
      _status = "جاري الاتصال...";
    });

    try {
      _log("1. محاولة الاتصال بـ: $baseUrl/users");

      final response = await http
          .get(Uri.parse('$baseUrl/users'))
          .timeout(const Duration(seconds: 10));

      _log("2. تم استلام الرد. كود الحالة: ${response.statusCode}");

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _log("3. نجاح! البيانات المستلمة (أول عنصر):");
        if (data is List && data.isNotEmpty) {
          _log(data[0].toString());
        } else {
          _log("القائمة فارغة، لكن الاتصال سليم.");
        }
        setState(() => _status = "✅ الاتصال ناجح بالسيرفر!");
      } else {
        _log("3. فشل. السيرفر رد بخطأ: ${response.body}");
        setState(() => _status = "❌ السيرفر رد بخطأ ${response.statusCode}");
      }
    } catch (e) {
      _log("3. حدث استثناء (Exception): $e");
      setState(() => _status = "❌ فشل الاتصال تماماً");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("فحص اتصال السيرفر")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _status,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _testConnection,
              icon: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Icon(Icons.network_check),
              label: const Text("افحص الاتصال الآن"),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(15),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "سجل العمليات (Logs):",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const Divider(),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  _logs,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
