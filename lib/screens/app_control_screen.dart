import 'package:drone_academy/services/role_service.dart';
import 'package:drone_academy/services/app_config_service.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// صفحة التحكم في التطبيق - حصرية للـ Owner فقط
class AppControlScreen extends StatefulWidget {
  const AppControlScreen({super.key});

  @override
  State<AppControlScreen> createState() => _AppControlScreenState();
}

class _AppControlScreenState extends State<AppControlScreen> {
  final RoleService _roleService = RoleService();
  final AppConfigService _configService = AppConfigService();
  final FirebaseRemoteConfig _remoteConfig =
      FirebaseRemoteConfig.instance; // احتياطي فقط

  bool _isLoading = true;
  bool _isAppEnabled = true;
  String _minAppVersion = '';
  String _currentAppVersion = '';
  bool _hasAccess = false;
  String _updateUrl = '';

  final _minVersionController = TextEditingController();
  final _updateUrlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkAccess();
  }

  Future<void> _checkAccess() async {
    // التحقق من أن المستخدم Owner
    final isOwner = await _roleService.isOwner();

    if (!isOwner) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⛔ ليس لديك صلاحية للوصول إلى هذه الصفحة'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() {
      _hasAccess = true;
    });

    await _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // الحصول على إصدار التطبيق الحالي
      final packageInfo = await PackageInfo.fromPlatform();
      _currentAppVersion = packageInfo.version;

      // جلب من Firestore أولاً
      final config = await _configService.fetch();

      if (config != null) {
        _minAppVersion = config.forceUpdateVersion;
        _isAppEnabled = config.isAppActive;
        _updateUrl = config.updateUrl;
      } else {
        // احتياطي: Remote Config
        await _remoteConfig.fetchAndActivate();
        final keys = _remoteConfig.getAll().keys;
        _minAppVersion = _remoteConfig.getString('forceUpdateVersion');
        _isAppEnabled = keys.contains('isAppActive')
            ? _remoteConfig.getBool('isAppActive')
            : _remoteConfig.getBool('appEnabled');
        _updateUrl = _remoteConfig.getString('updateUrl');
      }

      if (_minAppVersion.isEmpty) _minAppVersion = '1.0.0';
      _minVersionController.text = _minAppVersion;
      _updateUrlController.text = _updateUrl;

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading app control data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateMinVersion() async {
    final newVersion = _minVersionController.text.trim();

    if (newVersion.isEmpty) {
      _showSnackBar('⚠️ يرجى إدخال رقم إصدار صحيح', Colors.orange);
      return;
    }

    // التحقق من صيغة الإصدار
    if (!_isValidVersion(newVersion)) {
      _showSnackBar('⚠️ صيغة الإصدار غير صحيحة. استخدم: X.Y.Z', Colors.orange);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _configService.setForceUpdateVersion(newVersion);
      setState(() {
        _minAppVersion = newVersion;
        _isLoading = false;
      });
      _showSnackBar('✅ تم تحديث الحد الأدنى للإصدار', Colors.green);
    } catch (e) {
      _showSnackBar('❌ خطأ: $e', Colors.red);
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleAppStatus() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final newStatus = !_isAppEnabled;
      await _configService.setIsAppActive(newStatus);
      setState(() {
        _isAppEnabled = newStatus;
        _isLoading = false;
      });
      _showSnackBar(
        newStatus ? '✅ تم تشغيل التطبيق' : '⛔ تم إيقاف التطبيق',
        newStatus ? Colors.green : Colors.red,
      );
    } catch (e) {
      _showSnackBar('❌ خطأ: $e', Colors.red);
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveUpdateUrl() async {
    final url = _updateUrlController.text.trim();
    setState(() => _isLoading = true);
    try {
      await _configService.setUpdateUrl(url);
      setState(() {
        _updateUrl = url;
        _isLoading = false;
      });
      _showSnackBar('✅ تم حفظ رابط/جهة التحديث', Colors.green);
    } catch (e) {
      _showSnackBar('❌ خطأ: $e', Colors.red);
      setState(() => _isLoading = false);
    }
  }

  bool _isValidVersion(String version) {
    final regex = RegExp(r'^\d+\.\d+\.\d+$');
    return regex.hasMatch(version);
  }

  void _showSnackBar(
    String message,
    Color color, {
    Duration duration = const Duration(seconds: 4),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: duration,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _minVersionController.dispose();
    _updateUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasAccess) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('⚙️ التحكم في التطبيق'),
        backgroundColor: Colors.purple,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // بطاقة معلومات التطبيق
                  Card(
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: Colors.blue,
                                size: 32,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'معلومات التطبيق',
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          _buildInfoRow(
                            'الإصدار الحالي',
                            _currentAppVersion,
                            Icons.phone_android,
                          ),
                          const SizedBox(height: 12),
                          _buildInfoRow(
                            'الحد الأدنى للإصدار',
                            _minAppVersion,
                            Icons.security,
                          ),
                          const SizedBox(height: 12),
                          _buildInfoRow(
                            'حالة التطبيق',
                            _isAppEnabled ? 'مفعّل ✅' : 'موقف ⛔',
                            Icons.power_settings_new,
                            valueColor: _isAppEnabled
                                ? Colors.green
                                : Colors.red,
                          ),
                          const SizedBox(height: 12),
                          _buildInfoRow(
                            'رابط/جهة التحديث',
                            _updateUrl.isEmpty ? '-' : _updateUrl,
                            Icons.link,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // بطاقة التحكم في حالة التطبيق
                  Card(
                    elevation: 4,
                    color: _isAppEnabled
                        ? Colors.green.shade50
                        : Colors.red.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.power_settings_new,
                                color: _isAppEnabled
                                    ? Colors.green
                                    : Colors.red,
                                size: 32,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'إيقاف/تشغيل التطبيق',
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _isAppEnabled
                                ? '🟢 التطبيق يعمل حالياً. يمكن للمستخدمين تسجيل الدخول والاستخدام بشكل طبيعي.'
                                : '🔴 التطبيق موقف حالياً. لا يمكن للمستخدمين الوصول إليه.',
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _toggleAppStatus,
                              icon: Icon(
                                _isAppEnabled
                                    ? Icons.stop_circle
                                    : Icons.play_circle,
                              ),
                              label: Text(
                                _isAppEnabled
                                    ? 'إيقاف التطبيق'
                                    : 'تشغيل التطبيق',
                                style: const TextStyle(fontSize: 18),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _isAppEnabled
                                    ? Colors.red
                                    : Colors.green,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.all(16),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // بطاقة تحديث الإصدار
                  Card(
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.system_update,
                                color: Colors.orange,
                                size: 32,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'إدارة التحديث الإجباري',
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            '📱 قم بتعيين الحد الأدنى لإصدار التطبيق. المستخدمون الذين يستخدمون إصدارات أقدم سيُطلب منهم التحديث.',
                            style: TextStyle(fontSize: 14),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _minVersionController,
                            decoration: const InputDecoration(
                              labelText: 'الحد الأدنى للإصدار',
                              hintText: '1.0.0',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.edit),
                              helperText: 'مثال: 2.1.0',
                            ),
                            keyboardType: TextInputType.text,
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _updateUrlController,
                            decoration: const InputDecoration(
                              labelText: 'رابط/جهة التحديث (اختياري)',
                              hintText: 'https://example.com أو +963...',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.link),
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                await _saveUpdateUrl();
                                await _updateMinVersion();
                              },
                              icon: const Icon(Icons.save),
                              label: const Text('حفظ'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.all(16),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ملاحظة هامة
                  Card(
                    color: Colors.blue.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info, color: Colors.blue, size: 24),
                              const SizedBox(width: 8),
                              Text(
                                'ملاحظة هامة',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.blue.shade900,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'للتحديثات الفعلية، يجب تعديل القيم في Firebase Remote Config Console. هذه الصفحة توفر واجهة لعرض الحالة الحالية وتوجيهات التحديث.',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.blue.shade900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value,
    IconData icon, {
    Color? valueColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 16,
              color: valueColor ?? Colors.black87,
              fontWeight: valueColor != null ? FontWeight.bold : null,
            ),
          ),
        ),
      ],
    );
  }
}
