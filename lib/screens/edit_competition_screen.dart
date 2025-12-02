import 'package:drone_academy/l10n/app_localizations.dart';
import 'package:drone_academy/services/api_service.dart';
import 'package:flutter/material.dart';

class EditCompetitionScreen extends StatefulWidget {
  final Map<String, dynamic>? competition; // Map
  const EditCompetitionScreen({super.key, this.competition});

  @override
  State<EditCompetitionScreen> createState() => _EditCompetitionScreenState();
}

class _EditCompetitionScreenState extends State<EditCompetitionScreen> {
  final ApiService _apiService = ApiService();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isActive = true;
  bool get _isEditing => widget.competition != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _titleController.text = widget.competition!['title'];
      _descriptionController.text = widget.competition!['description'];
      _isActive = widget.competition!['isActive'];
    }
  }

  Future<void> _saveCompetition() async {
    if (_formKey.currentState!.validate()) {
      final data = {
        'title': _titleController.text,
        'description': _descriptionController.text,
        'metric': 'time',
        'isActive': _isActive,
      };

      if (_isEditing) {
        await _apiService.updateCompetition(widget.competition!['id'], data);
      } else {
        await _apiService.addCompetition(data);
      }
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? l10n.editCompetition : l10n.addNewCompetition),
        actions: [
          IconButton(icon: const Icon(Icons.save), onPressed: _saveCompetition),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(labelText: l10n.enterTitle),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(labelText: l10n.enterDescription),
                maxLines: 5,
              ),
              SwitchListTile(
                title: Text(l10n.activeCompetition),
                value: _isActive,
                onChanged: (v) => setState(() => _isActive = v),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
