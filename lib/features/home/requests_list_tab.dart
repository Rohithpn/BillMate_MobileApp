// lib/features/home/requests_list_tab.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class RequestsListTab extends StatefulWidget {
  final VoidCallback onActionCompleted;
  const RequestsListTab({super.key, required this.onActionCompleted});

  @override
  State<RequestsListTab> createState() => _RequestsListTabState();
}

class _RequestsListTabState extends State<RequestsListTab> {
  Future<List<Map<String, dynamic>>> _getRequests() async {
    final currentUserId = supabase.auth.currentUser!.id;
    try {
      // CORRECTED QUERY: Explicitly join profiles via the requester_id
      final response = await supabase
          .from('friends')
          .select('*, requester:profiles!requester_id(username)')
          .eq('addressee_id', currentUserId)
          .eq('status', 'pending');
      return response;
    } catch (e) {
      print('Error fetching requests: $e');
      return [];
    }
  }

  Future<void> _acceptRequest(String requesterId) async {
    try {
      await supabase.from('friends').update({'status': 'accepted'}).match({
        'requester_id': requesterId,
        'addressee_id': supabase.auth.currentUser!.id
      });
      widget.onActionCompleted();
    } catch (e) { print('Error accepting request: $e'); }
  }

  Future<void> _declineRequest(String requesterId) async {
    try {
      await supabase.from('friends').delete().match({
        'requester_id': requesterId,
        'addressee_id': supabase.auth.currentUser!.id
      });
      widget.onActionCompleted();
    } catch (e) { print('Error declining request: $e'); }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _getRequests(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final requests = snapshot.data!;
        if (requests.isEmpty) {
          return const Center(child: Text('You have no pending friend requests.'));
        }
        return ListView.builder(
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final request = requests[index];
            // CORRECTED DATA ACCESS: Use the 'requester' alias
            final requesterUsername = request['requester']?['username'] ?? 'Unknown User';
            final requesterId = request['requester_id'];
            return ListTile(
              leading: const Icon(Icons.person),
              title: Text(requesterUsername),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.check, color: Colors.green),
                    onPressed: () => _acceptRequest(requesterId),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.red),
                    onPressed: () => _declineRequest(requesterId),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}