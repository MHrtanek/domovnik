import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/app_bar_widget.dart';
import '../../../profile/presentation/providers/profile_provider.dart';

class FeedbackScreen extends ConsumerStatefulWidget {
  const FeedbackScreen({super.key});

  @override
  ConsumerState<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends ConsumerState<FeedbackScreen> {
  final _formKey = GlobalKey<FormState>();
  final _messageCtrl = TextEditingController();
  String _type = 'bug';
  bool _sending = false;

  static const _functionUrl =
      'https://pclawaxmilduvfkwhhge.supabase.co/functions/v1/send-feedback-email';

  @override
  void dispose() {
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final profile = await ref.read(profileProvider.future);
    if (profile == null) return;

    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) return;

    setState(() => _sending = true);
    try {
      final response = await http.post(
        Uri.parse(_functionUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${session.accessToken}',
        },
        body: jsonEncode({
          'user_id': profile.id,
          'building_id': profile.buildingId,
          'full_name': profile.fullName,
          'email': profile.email,
          'type': _type,
          'message': _messageCtrl.text.trim(),
        }),
      );

      if (response.statusCode >= 400) {
        throw Exception('Server error ${response.statusCode}: ${response.body}');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ďakujeme za feedback!')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Chyba pri odosielaní: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const DomovnikAppBar(title: 'Feedback', showBack: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Pomôžte nám zlepšiť Domovník. Váš feedback si prečítame osobne.',
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),
              RadioGroup<String>(
                groupValue: _type,
                onChanged: (v) => setState(() => _type = v!),
                child: const Card(
                  child: Column(
                    children: [
                      RadioListTile<String>(
                        value: 'bug',
                        title: Text('Niečo nefunguje'),
                      ),
                      Divider(height: 1, indent: 16),
                      RadioListTile<String>(
                        value: 'napad',
                        title: Text('Nápad na zlepšenie'),
                      ),
                      Divider(height: 1, indent: 16),
                      RadioListTile<String>(
                        value: 'ine',
                        title: Text('Iné'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _messageCtrl,
                decoration: const InputDecoration(
                  labelText: 'Správa',
                  hintText: 'Opíšte čo najpresnejšie...',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
                minLines: 4,
                maxLines: 8,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Povinné pole' : null,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _sending ? null : _submit,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _sending
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Odoslať'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
