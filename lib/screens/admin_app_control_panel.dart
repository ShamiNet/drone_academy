import 'package:animate_do/animate_do.dart';
import 'package:drone_academy/l10n/app_localizations.dart';
import 'package:drone_academy/services/api_service.dart';
import 'package:drone_academy/utils/snackbar_helper.dart';
import 'package:drone_academy/widgets/loading_view.dart';
import 'package:flutter/material.dart';

class AdminAppControlPanel extends StatefulWidget {
  const AdminAppControlPanel({super.key});

  @override
  State<AdminAppControlPanel> createState() => _AdminAppControlPanelState();
}

class _AdminAppControlPanelState extends State<AdminAppControlPanel> {
  final ApiService _apiService = ApiService();
  final _maintenanceMessageController = TextEditingController();
  final _updateUrlController = TextEditingController();
  final _updateMessageController = TextEditingController();

  bool _isEnabled = true;
  bool _forceUpdate = false;
  bool _isSaving = false;
  bool _isInit = true;

  final Color _bgColor = const Color(0xFF111318);
  final Color _cardColor = const Color(0xFF1E2230);
  final Color _primaryColor = const Color(0xFFFF9800);
  final Color _accentColor = const Color(0xFF3F51B5);

  @override
  void dispose() {
    _maintenanceMessageController.dispose();
    _updateUrlController.dispose();
    _updateMessageController.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);

    final success = await _apiService.updateAppConfig({
      'isEnabled': _isEnabled,
      'forceUpdate': _forceUpdate,
      'maintenanceMessage': _maintenanceMessageController.text,
      'updateUrl': _updateUrlController.text,
      'updateMessage': _updateMessageController.text,
    });

    if (mounted) {
      setState(() => _isSaving = false);
      if (success) {
        showCustomSnackBar(context, 'تم حفظ الإعدادات بنجاح!', isError: false);
      } else {
        showCustomSnackBar(context, 'فشل حفظ الإعدادات.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (_isSaving) {
      return const LoadingView(message: "جاري حفظ الإعدادات...");
    }

    return Scaffold(
      backgroundColor: _bgColor,
      body: StreamBuilder<Map<String, dynamic>>(
        stream: _apiService.streamAppConfig(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && _isInit) {
            return const LoadingView(
              message: "جاري تحضير الصفحة. اذكر الله بينما تجهز...",
            );
          }

          if (snapshot.hasData && _isInit) {
            final data = snapshot.data!;
            _isEnabled = data['isEnabled'] ?? true;
            _forceUpdate = data['forceUpdate'] ?? false;
            _maintenanceMessageController.text =
                data['maintenanceMessage'] ?? '';
            _updateUrlController.text = data['updateUrl'] ?? '';
            _updateMessageController.text = data['updateMessage'] ?? '';
            _isInit = false;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 50),
                // 1. الهيدر (مع زر العودة الجديد)
                FadeInDown(
                  duration: const Duration(milliseconds: 800),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 24,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_accentColor, _bgColor],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: _accentColor.withOpacity(0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        // [إضافة] زر العودة
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: const Icon(
                              Icons.arrow_back,
                              color: Colors.white,
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ),
                        const SizedBox(width: 16),

                        // الأيقونة الكبيرة
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.settings_remote,
                            size: 32,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 16),

                        // النصوص
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.appControl,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                "التحكم في النظام",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                // 2. قسم حالة النظام
                FadeInUp(
                  delay: const Duration(milliseconds: 200),
                  child: _buildSectionTitle(
                    "حالة النظام",
                    Icons.power_settings_new,
                  ),
                ),
                const SizedBox(height: 12),

                FadeInUp(
                  delay: const Duration(milliseconds: 300),
                  child: Container(
                    decoration: BoxDecoration(
                      color: _cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _isEnabled
                            ? Colors.green.withOpacity(0.3)
                            : Colors.red.withOpacity(0.3),
                        width: 1.5,
                      ),
                    ),
                    child: SwitchListTile(
                      title: Text(
                        l10n.appEnabled,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        _isEnabled
                            ? "التطبيق يعمل بشكل طبيعي"
                            : "التطبيق مغلق للصيانة",
                        style: TextStyle(
                          color: _isEnabled ? Colors.green : Colors.red,
                          fontSize: 12,
                        ),
                      ),
                      value: _isEnabled,
                      activeColor: Colors.green,
                      secondary: Icon(
                        _isEnabled ? Icons.check_circle : Icons.cancel,
                        color: _isEnabled ? Colors.green : Colors.red,
                      ),
                      onChanged: (val) => setState(() => _isEnabled = val),
                    ),
                  ),
                ),

                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  child: !_isEnabled
                      ? FadeInUp(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 12.0),
                            child: _buildTextFieldCard(
                              controller: _maintenanceMessageController,
                              label: l10n.maintenanceMessage,
                              icon: Icons.warning_amber_rounded,
                              color: Colors.orange,
                              maxLines: 2,
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),

                const SizedBox(height: 30),

                // 3. قسم التحديثات
                FadeInUp(
                  delay: const Duration(milliseconds: 400),
                  child: _buildSectionTitle("التحديثات", Icons.system_update),
                ),
                const SizedBox(height: 12),

                FadeInUp(
                  delay: const Duration(milliseconds: 500),
                  child: Container(
                    decoration: BoxDecoration(
                      color: _cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _forceUpdate
                            ? _primaryColor.withOpacity(0.5)
                            : Colors.transparent,
                      ),
                    ),
                    child: SwitchListTile(
                      title: Text(
                        l10n.forceUpdate,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: const Text(
                        "إجبار التحديث",
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      value: _forceUpdate,
                      activeColor: _primaryColor,
                      secondary: Icon(
                        Icons.update,
                        color: _forceUpdate ? _primaryColor : Colors.grey,
                      ),
                      onChanged: (val) => setState(() => _forceUpdate = val),
                    ),
                  ),
                ),

                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  child: _forceUpdate
                      ? Column(
                          children: [
                            const SizedBox(height: 12),
                            FadeInUp(
                              child: _buildTextFieldCard(
                                controller: _updateUrlController,
                                label: l10n.updateUrl,
                                icon: Icons.link,
                                color: Colors.blue,
                              ),
                            ),
                            const SizedBox(height: 12),
                            FadeInUp(
                              child: _buildTextFieldCard(
                                controller: _updateMessageController,
                                label: l10n.updateMessage,
                                icon: Icons.info_outline,
                                color: Colors.blue,
                                maxLines: 2,
                              ),
                            ),
                          ],
                        )
                      : const SizedBox.shrink(),
                ),

                const SizedBox(height: 40),

                // 4. زر الحفظ
                FadeInUp(
                  delay: const Duration(milliseconds: 600),
                  child: SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _saveSettings,
                      icon: const Icon(
                        Icons.save_outlined,
                        color: Colors.black,
                      ),
                      label: Text(
                        l10n.saveConfig,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 10,
                        shadowColor: _primaryColor.withOpacity(0.4),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: _primaryColor, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: _primaryColor,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildTextFieldCard({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required Color color,
    int maxLines = 1,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        style: const TextStyle(color: Colors.white),
        maxLines: maxLines,
        decoration: InputDecoration(
          icon: Icon(icon, color: color),
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey.shade500),
          border: InputBorder.none,
        ),
      ),
    );
  }
}
