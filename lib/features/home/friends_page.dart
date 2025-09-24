// lib/features/home/friends_page.dart
import 'package:bm/features/home/friends_list_tab.dart';
import 'package:bm/features/home/requests_list_tab.dart';
import 'package:bm/features/home/search_users_page.dart';
import 'package:bm/features/home/sent_requests_tab.dart';
import 'package:flutter/material.dart';

class FriendsPage extends StatefulWidget {
  const FriendsPage({super.key});

  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage> {
  // A key is used to force the friends list to rebuild when we need it to.
  Key _friendsListKey = UniqueKey();

  // This function will be called by child tabs to trigger a refresh.
  void _refreshAllTabs() {
    setState(() {
      // Changing the key tells Flutter to create a new instance of the widget.
      _friendsListKey = UniqueKey();
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Friends'),
          actions: [
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () {
                Navigator.of(context)
                    .push(MaterialPageRoute(
                      builder: (context) => const SearchUsersPage(),
                    ))
                    .then((_) => _refreshAllTabs());
              },
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'My Friends'),
              Tab(text: 'Requests'),
              Tab(text: 'Sent'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // The FriendsListTab is refreshed by changing its key.
            FriendsListTab(key: _friendsListKey),
            // The other tabs are refreshed by calling the onActionCompleted callback.
            RequestsListTab(onActionCompleted: _refreshAllTabs),
            SentRequestsTab(onActionCompleted: _refreshAllTabs),
          ],
        ),
      ),
    );
  }
}