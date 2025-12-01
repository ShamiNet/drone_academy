import 'package:flutter/material.dart';
import 'package:drone_academy/services/api_service.dart';

class TestApiScreen extends StatefulWidget {
  const TestApiScreen({super.key});

  @override
  State<TestApiScreen> createState() => _TestApiScreenState();
}

class _TestApiScreenState extends State<TestApiScreen> {
  String _result = "اضغط الزر لفحص البيانات";
  bool _isLoading = false;
  final ApiService _apiService = ApiService();

  Future<void> _checkData() async {
    setState(() {
      _isLoading = true;
      _result = "جاري الاتصال بالسيرفر...";
    });

    try {
      // جلب المستخدمين
      final users = await _apiService.fetchUsers();

      if (users.isEmpty) {
        setState(() {
          _result = "✅ القائمة فارغة []\n(هذا يعني أنك تخلصت من Test User!)";
        });
      } else {
        final firstUser = users[0];
        final name = firstUser['displayName'];

        if (name == "Test User 1") {
          setState(() {
            _result =
                "❌ فشل! ما زال يظهر:\nTest User 1\n(السيرفر القديم لا يزال يعمل)";
          });
        } else {
          setState(() {
            _result = "✅ نجاح! ظهر مستخدم حقيقي:\n$name";
          });
        }
      }
    } catch (e) {
      setState(() {
        _result = "خطأ في الاتصال: $e";
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("اختبار السيرفر")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _result,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 30),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _checkData,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 15,
                      ),
                    ),
                    child: const Text("افحص الآن"),
                  ),
          ],
        ),
      ),
    );
  }
}
