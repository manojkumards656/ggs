import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:pocket_party/core/providers/preferences_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: ref.read(usernameProvider));
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isNotEmpty) {
      ref.read(usernameProvider.notifier).setUsername(name);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile saved successfully', style: TextStyle(fontWeight: FontWeight.bold)),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your Profile',
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900),
            ).animate().fade().slideX(begin: -0.2, curve: Curves.easeOutBack),
            const SizedBox(height: 8),
            Text(
              'This is how other players will see you.',
              style: TextStyle(fontSize: 16, color: Colors.white.withValues(alpha: 0.6)), 
            ).animate().fade(delay: 100.ms).slideX(begin: -0.2, curve: Curves.easeOutBack),
            const SizedBox(height: 40),
            TextField(
              controller: _nameController,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                labelText: 'Username',
                labelStyle: TextStyle(color: Theme.of(context).colorScheme.primary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
                prefixIcon: const Icon(Icons.person),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
                ),
              ),
              onSubmitted: (_) => _save(),
            ).animate().fade(delay: 200.ms).slideY(begin: 0.2, curve: Curves.easeOutBack),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                child: const Text('SAVE PROFILE'),
              ),
            ).animate().fade(delay: 300.ms).scale(curve: Curves.easeOutBack),
          ],
        ),
      ),
    );
  }
}
