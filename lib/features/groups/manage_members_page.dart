// lib/features/groups/manage_members_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class ManageMembersPage extends StatefulWidget {
  final String groupId;
  final String groupCreatorId;
  const ManageMembersPage({super.key, required this.groupId, required this.groupCreatorId});

  @override
  State<ManageMembersPage> createState() => _ManageMembersPageState();
}

class _ManageMembersPageState extends State<ManageMembersPage> {
  late Future<List<Map<String, dynamic>>> _membersFuture;

  @override
  void initState() {
    super.initState();
    _membersFuture = _getGroupMembers();
  }

  Future<List<Map<String, dynamic>>> _getGroupMembers() async {
    final response = await supabase
        .from('group_members')
        .select('profiles(id, username)')
        .eq('group_id', widget.groupId);
    return (response as List).map((item) => item['profiles'] as Map<String, dynamic>).toList();
  }

  Future<void> _removeMember(String memberId) async {
    final isCreator = memberId == widget.groupCreatorId;
    if (isCreator) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("You can't remove the group creator.")));
      return;
    }
    
    try {
      await supabase
          .from('group_members')
          .delete()
          .match({'group_id': widget.groupId, 'user_id': memberId});
      
      // Refresh the list
      setState(() {
        _membersFuture = _getGroupMembers();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to remove member.")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCurrentUserTheCreator = supabase.auth.currentUser!.id == widget.groupCreatorId;

    return Scaffold(
      appBar: AppBar(title: const Text('Manage Members')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _membersFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final members = snapshot.data!;
          return ListView.builder(
            itemCount: members.length,
            itemBuilder: (context, index) {
              final member = members[index];
              return ListTile(
                leading: const Icon(Icons.person),
                title: Text(member['username']),
                subtitle: member['id'] == widget.groupCreatorId ? const Text('Creator') : null,
                // Only show the remove button if the current user is the creator
                trailing: isCurrentUserTheCreator
                    ? IconButton(
                        icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                        onPressed: () => _removeMember(member['id']),
                      )
                    : null,
              );
            },
          );
        },
      ),
    );
  }
}