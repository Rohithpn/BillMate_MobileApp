// lib/features/groups/groups_page.dart
import 'package:bm/features/groups/create_group_page.dart';
import 'package:bm/features/groups/group_details_page.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GroupsPage extends StatefulWidget {
  const GroupsPage({super.key});

  @override
  State<GroupsPage> createState() => _GroupsPageState();
}

class _GroupsPageState extends State<GroupsPage> {
  final supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> _getGroups() async {
    final userId = supabase.auth.currentUser!.id;
    try {
      final response = await supabase
          .from('group_members')
          .select('groups!inner(id, name)')
          .eq('user_id', userId);
      
      final groupsList = (response as List)
          .map((item) => item['groups'] as Map<String, dynamic>)
          .toList();
      return groupsList;
    } catch (e) {
      print('Error fetching groups: $e');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Groups'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _getGroups(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final groups = snapshot.data;
          if (groups == null || groups.isEmpty) {
            return const Center(child: Text('You are not in any groups.'));
          }

          return ListView.builder(
            itemCount: groups.length,
            itemBuilder: (context, index) {
              final group = groups[index];
              return ListTile(
                leading: const Icon(Icons.group_work),
                title: Text(group['name']),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => GroupDetailsPage(
                        groupId: group['id'],
                        groupName: group['name'],
                      ),
                    ),
                  ).then((_) => setState(() {}));
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const CreateGroupPage()),
          ).then((_) {
            setState(() {});
          });
        },
        child: const Icon(Icons.add),
        tooltip: 'Create Group',
      ),
    );
  }
}