import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drone_academy/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

class EditCompetitionScreen extends StatefulWidget {
  // متغير لاستقبال بيانات المسابقة في حالة التعديل
  final DocumentSnapshot? competition;

  const EditCompetitionScreen({super.key, this.competition});

  @override
  State<EditCompetitionScreen> createState() => _EditCompetitionScreenState();
}

class _EditCompetitionScreenState extends State<EditCompetitionScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isActive = true;

  bool get _isEditing => widget.competition != null;

  @override
  void initState() {
    super.initState();
    // إذا كنا في وضع التعديل، قم بتعبئة الحقول بالبيانات القديمة
    if (_isEditing) {
      _titleController.text = widget.competition!['title'];
      _descriptionController.text = widget.competition!['description'];
      _isActive = widget.competition!['isActive'];
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _saveCompetition() async {
    if (_formKey.currentState!.validate()) {
      final data = {
        'title': _titleController.text,
        'description': _descriptionController.text,
        'metric': 'time',
        'isActive': _isActive,
      };

      try {
        if (_isEditing) {
          await FirebaseFirestore.instance
              .collection('competitions')
              .doc(widget.competition!.id)
              .update(data);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Competition updated successfully!')),
          );
        } else {
          await FirebaseFirestore.instance.collection('competitions').add(data);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Competition added successfully!')),
          );
        }
        Navigator.of(context).pop();
      } catch (e) {
        print('Error saving competition: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save competition.')),
        );
      }
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
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: l10n.enterTitle,
                  border: const OutlineInputBorder(),
                ),
                validator: (value) => value!.isEmpty ? l10n.enterTitle : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: l10n.enterDescription,
                  border: const OutlineInputBorder(),
                ),
                maxLines: 5,
                validator: (value) =>
                    value!.isEmpty ? l10n.enterDescription : null,
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: Text(l10n.activeCompetition),
                subtitle: Text(
                  l10n.activeCompetitionSubtitle,
                  style: const TextStyle(color: Colors.grey),
                ),
                value: _isActive,
                onChanged: (bool value) => setState(() => _isActive = value),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
