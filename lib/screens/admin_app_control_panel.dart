import 'package:drone_academy/services/api_service.dart';
import 'package:drone_academy/utils/app_notifications.dart';
import 'package:flutter/material.dart';

class AdminAppControlPanel extends StatefulWidget {
  const AdminAppControlPanel({super.key});

  @override
  State<AdminAppControlPanel> createState() => _AdminAppControlPanelState();
}

class _AdminAppControlPanelState extends State<AdminAppControlPanel> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;

  // المتغيرات
  bool _isEnabled = true;
  final TextEditingController _minVersionController = TextEditingController();
  final TextEditingController _updateUrlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final config = await _apiService.fetchAppConfig();
    setState(() {
      _isEnabled = config['isEnabled'] ?? true;
      _minVersionController.text = config['minVersion'] ?? '1.0.0';
      _updateUrlController.text = config['updateUrl'] ?? '';
      _isLoading = false;
    });
  }

  Future<void> _saveConfig() async {
    setState(() => _isLoading = true);
    final success = await _apiService.updateAppConfig({
      'isEnabled': _isEnabled,
      'minVersion': _minVersionController.text
          .trim(), // الرقم الذي سيوقف النسخ الأقدم منه
      'updateUrl': _updateUrlController.text.trim(), // رابط المتجر
    });
    setState(() => _isLoading = false);

    if (success) {
      AppNotifications.showSuccess(context, "تم تحديث إعدادات التطبيق بنجاح");
    } else {
      AppNotifications.showError(context, "فشل الحفظ");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      appBar: AppBar(title: const Text("لوحة التحكم بالتطبيق")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. حالة التطبيق (صيانة)
          SwitchListTile(
            title: const Text("حالة التطبيق (مفعل/صيانة)"),
            subtitle: Text(
              _isEnabled ? "التطبيق يعمل بشكل طبيعي" : "التطبيق في وضع الصيانة",
            ),
            value: _isEnabled,
            activeColor: Colors.green,
            onChanged: (val) => setState(() => _isEnabled = val),
          ),
          const Divider(),

          // 2. إدارة الإصدارات
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Text(
              "إدارة الإصدارات والتحديثات",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),

          TextField(
            controller: _minVersionController,
            decoration: const InputDecoration(
              labelText: "أقل إصدار مسموح به (Min Version)",
              hintText: "مثال: 1.0.1",
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.verified_user),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 10),
          const Text(
            "تنبيه: أي مستخدم لديه إصدار أقل من هذا الرقم سيتم إجباره على التحديث.",
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),

          const SizedBox(height: 20),

          TextField(
            controller: _updateUrlController,
            decoration: const InputDecoration(
              labelText: "رابط التحديث (المتجر)",
              hintText: "https://...",
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.link),
            ),
          ),

          const SizedBox(height: 30),

          ElevatedButton.icon(
            onPressed: _saveConfig,
            icon: const Icon(Icons.save),
            label: const Text("حفظ الإعدادات"),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.all(16),
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
