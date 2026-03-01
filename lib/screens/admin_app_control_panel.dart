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
  bool _updateRequired = false;
  final TextEditingController _latestVersionController =
      TextEditingController();
  final TextEditingController _minVersionController = TextEditingController();
  final TextEditingController _updateUrlController = TextEditingController();
  final TextEditingController _updateMessageController =
      TextEditingController();
  final TextEditingController _releaseNotesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final config = await _apiService.fetchAppConfig();
    setState(() {
      _isEnabled = config['isEnabled'] ?? true;
      _updateRequired = config['updateRequired'] ?? false;
      _latestVersionController.text = config['latestVersion'] ?? '1.0.2';
      _minVersionController.text = config['minVersion'] ?? '1.0.0';
      _updateUrlController.text = config['updateUrl'] ?? '';
      _updateMessageController.text =
          config['updateMessage'] ?? 'تحديث جديد متاح';

      // تحميل ملاحظات الإصدار
      if (config['releaseLog'] != null &&
          config['releaseLog']['highlights'] != null) {
        final highlights = config['releaseLog']['highlights'] as List;
        _releaseNotesController.text = highlights.join('\n');
      }

      _isLoading = false;
    });
  }

  Future<void> _saveConfig() async {
    setState(() => _isLoading = true);

    // تحويل ملاحظات الإصدار إلى قائمة
    final highlights = _releaseNotesController.text
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .toList();

    final success = await _apiService.updateAppConfig({
      'isEnabled': _isEnabled,
      'updateRequired': _updateRequired,
      'latestVersion': _latestVersionController.text.trim(),
      'minVersion': _minVersionController.text.trim(),
      'updateUrl': _updateUrlController.text.trim(),
      'updateMessage': _updateMessageController.text.trim(),
      'releaseLog': {
        'appName': 'Drone Academy',
        'version': _latestVersionController.text.trim(),
        'highlights': highlights,
      },
    });

    setState(() => _isLoading = false);

    if (success) {
      AppNotifications.showSuccess(context, "تم تحديث إعدادات التطبيق بنجاح ✅");
    } else {
      AppNotifications.showError(context, "فشل الحفظ");
    }
  }

  @override
  void dispose() {
    _minVersionController.dispose();
    _updateUrlController.dispose();
    _latestVersionController.dispose();
    _updateMessageController.dispose();
    _releaseNotesController.dispose();
    super.dispose();
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
            controller: _latestVersionController,
            decoration: const InputDecoration(
              labelText: "أحدث إصدار متاح (Latest Version)",
              hintText: "مثال: 1.0.2",
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.system_update),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 10),
          const Text(
            "هذا هو رقم الإصدار الحالي الذي سيظهر للمستخدمين.",
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),

          const SizedBox(height: 20),

          SwitchListTile(
            title: const Text("إجبار التحديث (Update Required)"),
            subtitle: const Text(
              "سيتم منع المستخدمين من استخدام التطبيق حتى يقوموا بالتحديث",
            ),
            value: _updateRequired,
            onChanged: (val) => setState(() => _updateRequired = val),
          ),

          const SizedBox(height: 20),

          TextField(
            controller: _updateMessageController,
            decoration: const InputDecoration(
              labelText: "رسالة التحديث (Update Message)",
              hintText: "تحديث جديد متاح",
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.message),
            ),
            maxLines: 2,
          ),

          const SizedBox(height: 20),

          TextField(
            controller: _releaseNotesController,
            decoration: const InputDecoration(
              labelText: "ملاحظات الإصدار (Release Notes)",
              hintText:
                  "أضف سطر جديد لكل ميزة\nمثال:\n- تحسين الأداء\n- إصلاح مشاكل",
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.notes),
              alignLabelWithHint: true,
            ),
            maxLines: 5,
          ),
          const SizedBox(height: 10),
          const Text(
            "ضع كل ملاحظة في سطر منفصل (سيتم تحويلها تلقائياً إلى قائمة)",
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
