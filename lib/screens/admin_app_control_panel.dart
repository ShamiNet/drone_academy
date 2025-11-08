import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drone_academy/l10n/app_localizations.dart';
import 'package:drone_academy/utils/snackbar_helper.dart';
import 'package:flutter/material.dart';

class AdminAppControlPanel extends StatefulWidget {
  const AdminAppControlPanel({super.key});

  @override
  State<AdminAppControlPanel> createState() => _AdminAppControlPanelState();
}

class _AdminAppControlPanelState extends State<AdminAppControlPanel> {
  final _appStatusRef = FirebaseFirestore.instance
      .collection('app_status')
      .doc('config');
  final _maintenanceMessageController = TextEditingController();
  final _updateUrlController = TextEditingController();
  final _updateMessageController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _maintenanceMessageController.dispose();
    _updateUrlController.dispose();
    _updateMessageController.dispose();
    super.dispose();
  }

  Future<void> _saveConfig() async {
    if (_formKey.currentState!.validate()) {
      final l10n = AppLocalizations.of(context)!;
      try {
        await _appStatusRef.set({
          'maintenanceMessage': _maintenanceMessageController.text,
          'updateUrl': _updateUrlController.text,
          'updateMessage': _updateMessageController.text,
        }, SetOptions(merge: true));
        if (mounted) {
          showCustomSnackBar(context, l10n.configSaved, isError: false);
        }
      } catch (e) {
        if (mounted) {
          showCustomSnackBar(context, '${l10n.failed}: $e');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return StreamBuilder<DocumentSnapshot>(
      stream: _appStatusRef.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final config = snapshot.data!.data() as Map<String, dynamic>? ?? {};
        bool isEnabled = config['isEnabled'] ?? true;
        bool forceUpdate = config['forceUpdate'] ?? false;
        _maintenanceMessageController.text = config['maintenanceMessage'] ?? '';
        _updateUrlController.text = config['updateUrl'] ?? '';
        _updateMessageController.text = config['updateMessage'] ?? '';

        return Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.appControl,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: Text(l10n.appEnabled),
                  value: isEnabled,
                  onChanged: (value) => _appStatusRef.set({
                    'isEnabled': value,
                  }, SetOptions(merge: true)),
                ),
                SwitchListTile(
                  title: Text(l10n.forceUpdate),
                  value: forceUpdate,
                  onChanged: (value) => _appStatusRef.set({
                    'forceUpdate': value,
                  }, SetOptions(merge: true)),
                ),
                const Divider(height: 32),
                TextFormField(
                  controller: _maintenanceMessageController,
                  decoration: InputDecoration(
                    labelText: l10n.maintenanceMessage,
                  ),
                  validator: (value) =>
                      value!.isEmpty ? l10n.enterDescription : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _updateUrlController,
                  decoration: InputDecoration(labelText: l10n.updateUrl),
                  validator: (value) => value!.isEmpty ? l10n.enterUrl : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _updateMessageController,
                  decoration: InputDecoration(labelText: l10n.updateMessage),
                  validator: (value) =>
                      value!.isEmpty ? l10n.enterDescription : null,
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saveConfig,
                    child: Text(l10n.saveConfig),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
