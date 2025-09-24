// lib/features/home/sent_requests_tab.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class SentRequestsTab extends StatefulWidget {
  final VoidCallback onActionCompleted;
  const SentRequestsTab({super.key, required this.onActionCompleted});

  @override
  State<SentRequestsTab> createState() => _SentRequestsTabState();
}

class _SentRequestsTabState extends State<SentRequestsTab> {
  Future<List<Map<String, dynamic>>> _getSentRequests() async {
    final currentUserId = supabase.auth.currentUser!.id;

    // --- DEBUG LOGGING ---
    print('--- Fetching Sent Requests ---');
    print('Current User ID (Requester): $currentUserId');
    // --- END DEBUG LOGGING ---

    try {
      final response = await supabase
          .from('friends')
          .select('*, profiles:addressee_id(username)')
          .eq('requester_id', currentUserId)
          .eq('status', 'pending');

      // --- DEBUG LOGGING ---
      print('Supabase response for sent requests: $response');
      // --- END DEBUG LOGGING ---

      return response;
    } catch (e) {
      // --- DEBUG LOGGING ---
      print('!!! ERROR fetching sent requests: $e');
      // --- END DEBUG LOGGING ---
      return [];
    }
  }

  // ... The rest of your file (_cancelRequest, build method) remains the same
  Future<void> _cancelRequest(String addresseeId) async {
    try {
      await supabase
          .from('friends')
          .delete()
          .match({'requester_id': supabase.auth.currentUser!.id, 'addressee_id': addresseeId});
      widget.onActionCompleted();
    } catch (e) { print('Error cancelling request: $e'); }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _getSentRequests(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final requests = snapshot.data!;
        if (requests.isEmpty) {
          return const Center(child: Text('You have no pending sent requests.'));
        }
        return ListView.builder(
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final request = requests[index];
            final addresseeUsername = request['profiles']?['username'] ?? 'Unknown User';
            final addresseeId = request['addressee_id'];
            return ListTile(
              leading: const Icon(Icons.person),
              title: Text(addresseeUsername),
              subtitle: const Text('Request sent'),
              trailing: TextButton(
                onPressed: () => _cancelRequest(addresseeId),
                child: const Text('Cancel', style: TextStyle(color: Colors.red)),
              ),
            );
          },
        );
      },
    );
  }
}