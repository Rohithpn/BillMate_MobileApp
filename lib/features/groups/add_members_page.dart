import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class AddMembersPage extends StatefulWidget {
  final String groupId;
  const AddMembersPage({super.key, required this.groupId});

  @override
  State<AddMembersPage> createState() => _AddMembersPageState();
}

class _AddMembersPageState extends State<AddMembersPage> {
  late Future<List<Map<String, dynamic>>> _friendsFuture;
  final Set<String> _selectedFriendIds = {};

  @override
  void initState() {
    super.initState();
    _friendsFuture = _getFriendsNotInGroup();
  }

  Future<List<Map<String, dynamic>>> _getFriendsNotInGroup() async {
    final userId = supabase.auth.currentUser!.id;
    try {
      // This is a complex query, so we use an RPC function for it.
      // It finds all your friends who are not already in the specified group.
      final response = await supabase.rpc('get_friends_not_in_group', params: {
        'p_user_id': userId,
        'p_group_id': widget.groupId,
      });
      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      print('Error fetching friends not in group: $e');
      return [];
    }
  }

  Future<void> _addSelectedMembers() async {
    if (_selectedFriendIds.isEmpty) return;

    final membersToInsert = _selectedFriendIds.map((friendId) => {
      'group_id': widget.groupId,
      'user_id': friendId,
    }).toList();

    try {
      await supabase.from('group_members').insert(membersToInsert);
      if(mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      print('Error adding members: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Friends to Group'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _addSelectedMembers,
          )
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _friendsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final friends = snapshot.data!;
          if (friends.isEmpty) {
            return const Center(child: Text('All of your friends are already in this group.'));
          }

          return ListView.builder(
            itemCount: friends.length,
            itemBuilder: (context, index) {
              final friend = friends[index];
              final isSelected = _selectedFriendIds.contains(friend['id']);
              return CheckboxListTile(
                title: Text(friend['username']),
                value: isSelected,
                onChanged: (bool? selected) {
                  setState(() {
                    if (selected == true) {
                      _selectedFriendIds.add(friend['id']);
                    } else {
                      _selectedFriendIds.remove(friend['id']);
                    }
                  });
                },
              );
            },
          );
        },
      ),
    );
  }
}