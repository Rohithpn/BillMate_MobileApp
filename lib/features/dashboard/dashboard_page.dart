// lib/features/dashboard/dashboard_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final supabase = Supabase.instance.client;
  late Future<Map<String, dynamic>> _dashboardTotalsFuture;

  @override
  void initState() {
    super.initState();
    _dashboardTotalsFuture = _getTotals();
  }

  Future<Map<String, dynamic>> _getTotals() async {
    final userId = supabase.auth.currentUser!.id;
    // This calls the database function we created to get all the totals.
    return await supabase.rpc(
      'get_user_dashboard_totals',
      params: {'p_user_id': userId},
    ).single();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _dashboardTotalsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }
          final data = snapshot.data!;
          final totalGetsBack = data['total_gets_back'] ?? 0.0;
          final totalSpent = data['total_spent'] ?? 0.0;

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _dashboardTotalsFuture = _getTotals();
              });
            },
            child: ListView( // Wrapped in ListView to allow for scrolling if needed
              padding: const EdgeInsets.all(16.0),
              children: [
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Your Money',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildMetric(
                              context,
                              'You are owed',
                              '\$${double.parse(totalGetsBack.toString()).toStringAsFixed(2)}',
                              'Across all groups',
                            ),
                            _buildMetric(
                              context,
                              'You spent',
                              '\$${double.parse(totalSpent.toString()).toStringAsFixed(2)}',
                              'Total paid by you',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMetric(BuildContext context, String title, String value, String subtitle) {
    return Column(
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey.shade400),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                color: Colors.blue.shade300,
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade500),
        ),
      ],
    );
  }
}