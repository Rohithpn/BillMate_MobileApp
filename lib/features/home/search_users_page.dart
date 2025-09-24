// lib/features/home/search_users_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class SearchUsersPage extends StatefulWidget {
  const SearchUsersPage({super.key});

  @override
  State<SearchUsersPage> createState() => _SearchUsersPageState();
}

class _SearchUsersPageState extends State<SearchUsersPage> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoading = false;

  Future<void> _searchUsers() async {
    setState(() { _isLoading = true; _searchResults = []; });
    final searchTerm = _searchController.text.trim();
    if (searchTerm.isEmpty) {
      setState(() { _isLoading = false; });
      return;
    }
    try {
      final currentUserId = supabase.auth.currentUser!.id;
      final response = await supabase
          .from('profiles')
          .select()
          .ilike('username', '%$searchTerm%')
          .not('id', 'eq', currentUserId);
      setState(() { _searchResults = response; });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error searching for users.')),
      );
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  Future<void> _sendFriendRequest(String addresseeId) async {
    final requesterId = supabase.auth.currentUser!.id;
    try {
      await supabase.from('friends').insert({
        'requester_id': requesterId,
        'addressee_id': addresseeId,
        'status': 'pending',
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Friend request sent!'),
          backgroundColor: Colors.green,
        ),
      );
      // Refresh search results to potentially update UI for sent requests
      _searchUsers(); 
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not send friend request.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Friends'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search by username',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _searchUsers,
                ),
              ),
              onSubmitted: (_) => _searchUsers(),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _searchResults.isEmpty
                    ? const Center(child: Text('No users found.'))
                    : ListView.builder(
                        itemCount: _searchResults.length,
                        itemBuilder: (context, index) {
                          final user = _searchResults[index];
                          return ListTile(
                            leading: const Icon(Icons.person),
                            title: Text(user['username']),
                            trailing: IconButton(
                              icon: const Icon(Icons.person_add, color: Colors.green),
                              onPressed: () => _sendFriendRequest(user['id']),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}