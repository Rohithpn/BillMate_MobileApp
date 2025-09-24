// lib/features/home/friends_list_tab.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class FriendsListTab extends StatefulWidget {
  const FriendsListTab({super.key});

  @override
  State<FriendsListTab> createState() => _FriendsListTabState();
}

class _FriendsListTabState extends State<FriendsListTab> {
  Future<List<Map<String, dynamic>>> _getFriends() async {
    final userId = supabase.auth.currentUser!.id;
    try {
      // CORRECTED QUERY 1: Explicitly join profiles via addressee_id
      final response1 = await supabase
          .from('friends')
          .select('addressee:profiles!addressee_id(id, username)')
          .eq('requester_id', userId)
          .eq('status', 'accepted');

      // CORRECTED QUERY 2: Explicitly join profiles via requester_id
      final response2 = await supabase
          .from('friends')
          .select('requester:profiles!requester_id(id, username)')
          .eq('addressee_id', userId)
          .eq('status', 'accepted');

      final friends = (response1 as List).map((e) => e['addressee']).toList();
      friends.addAll((response2 as List).map((e) => e['requester']));
      
      return friends.cast<Map<String, dynamic>>();
    } catch (e) {
      print('Error fetching friends: $e');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _getFriends(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final friends = snapshot.data;
        if (friends == null || friends.isEmpty) {
          return const Center(child: Text('You have no friends yet.'));
        }
        
        return RefreshIndicator(
          onRefresh: () async {
            setState(() {});
          },
          child: ListView.builder(
            itemCount: friends.length,
            itemBuilder: (context, index) {
              final friend = friends[index];
              return ListTile(
                leading: const Icon(Icons.person),
                title: Text(friend['username'] ?? 'Unknown User'),
              );
            },
          ),
        );
      },
    );
  }
}