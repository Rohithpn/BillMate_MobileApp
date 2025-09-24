// lib/features/profile/profile_page.dart
import 'dart:io';
import 'package:bm/core/theme_notifier.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String? _username;
  String? _avatarUrl;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() { _isLoading = true; });
    try {
      final userId = supabase.auth.currentUser!.id;
      final response = await supabase
          .from('profiles')
          .select('username, avatar_url')
          .eq('id', userId)
          .single();
      setState(() {
        _username = response['username'];
        _avatarUrl = response['avatar_url'];
      });
    } catch (e) {
      print('Error loading profile: $e');
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  Future<void> _updateUsername(String newUsername) async {
    try {
      final userId = supabase.auth.currentUser!.id;
      await supabase
          .from('profiles')
          .update({'username': newUsername})
          .eq('id', userId);
      setState(() {
        _username = newUsername;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Username updated!'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating username: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _uploadAvatar() async {
    final picker = ImagePicker();
    final imageFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 300,
      maxHeight: 300,
    );
    if (imageFile == null) return;

    final file = File(imageFile.path);
    final userId = supabase.auth.currentUser!.id;
    final filePath = '$userId/avatar.${imageFile.path.split('.').last}'; 
    
    try {
      await supabase.storage.from('avatars').upload(filePath, file,
        fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
      );
      final publicUrl = supabase.storage.from('avatars').getPublicUrl(filePath);
      await supabase
          .from('profiles')
          .update({'avatar_url': publicUrl})
          .eq('id', userId);

      setState(() { _avatarUrl = publicUrl; });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Avatar updated!'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading avatar: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _showEditUsernameDialog() {
    final controller = TextEditingController(text: _username);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Username'),
        content: TextField(controller: controller),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              _updateUsername(controller.text.trim());
              Navigator.of(context).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final userEmail = supabase.auth.currentUser?.email ?? 'No email';

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                GestureDetector(
                  onTap: _uploadAvatar,
                  child: CircleAvatar(
                    radius: 50,
                    backgroundImage: _avatarUrl != null ? NetworkImage(_avatarUrl!) : null,
                    child: _avatarUrl == null ? const Icon(Icons.camera_alt, size: 40) : null,
                  ),
                ),
                const SizedBox(height: 24),
                ListTile(
                  leading: const Icon(Icons.person),
                  title: const Text('Username'),
                  subtitle: Text(_username ?? 'No username'),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: _showEditUsernameDialog,
                  ),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.email),
                  title: const Text('Email'),
                  subtitle: Text(userEmail),
                ),
                const SizedBox(height: 24),
                const Text('Theme', style: TextStyle(fontWeight: FontWeight.bold)),
                const Divider(),
                SegmentedButton<ThemeMode>(
                  segments: const <ButtonSegment<ThemeMode>>[
                    ButtonSegment<ThemeMode>(value: ThemeMode.light, label: Text('Light'), icon: Icon(Icons.light_mode)),
                    ButtonSegment<ThemeMode>(value: ThemeMode.dark, label: Text('Dark'), icon: Icon(Icons.dark_mode)),
                    ButtonSegment<ThemeMode>(value: ThemeMode.system, label: Text('System'), icon: Icon(Icons.settings)),
                  ],
                  selected: {themeNotifier.themeMode},
                  onSelectionChanged: (Set<ThemeMode> newSelection) {
                    themeNotifier.setThemeMode(newSelection.first);
                  },
                ),
                const SizedBox(height: 40),
                Center(
                  child: ElevatedButton(
                    onPressed: () async => await supabase.auth.signOut(),
                    child: const Text('Logout'),
                  ),
                ),
              ],
            ),
    );
  }
}