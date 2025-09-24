// lib/features/groups/group_details_page.dart
import 'package:bm/features/groups/add_expense_page.dart';
import 'package:bm/features/groups/add_members_page.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GroupDetailsPage extends StatefulWidget {
  final String groupId;
  final String groupName;
  const GroupDetailsPage({super.key, required this.groupId, required this.groupName});

  @override
  State<GroupDetailsPage> createState() => _GroupDetailsPageState();
}

class _GroupDetailsPageState extends State<GroupDetailsPage> {
  final supabase = Supabase.instance.client;

  Future<Map<String, dynamic>> _getSummaryData() async {
    final userId = supabase.auth.currentUser!.id;
    final expensesRes = await supabase
        .from('expenses')
        .select('amount')
        .eq('group_id', widget.groupId);
    
    final totalSpending = (expensesRes as List)
        .fold(0.0, (sum, row) => sum + double.parse(row['amount'].toString()));

    final balancesRes = await supabase.rpc('get_group_balances', params: {'p_group_id': widget.groupId});
    
    double myBalance = 0.0;
    final myBalanceData = (balancesRes as List).firstWhere(
      (balance) => balance['user_id'] == userId,
      orElse: () => null,
    );
    if (myBalanceData != null) {
      myBalance = double.parse(myBalanceData['net_balance'].toString());
    }

    return {'total_spending': totalSpending, 'my_balance': myBalance};
  }
  
  Future<List<Map<String, dynamic>>> _getExpenses() async {
    return await supabase
        .from('expenses')
        .select('id, description, amount, currency, profiles:paid_by(username)')
        .eq('group_id', widget.groupId)
        .order('created_at', ascending: false);
  }

  Future<List<Map<String, dynamic>>> _getBalances() async {
    return (await supabase.rpc('get_group_balances', params: {'p_group_id': widget.groupId}) as List)
        .cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> _getSettlements() async {
    return (await supabase.rpc('get_group_settlements', params: {'p_group_id': widget.groupId}) as List)
        .cast<Map<String, dynamic>>();
  }

  Future<void> _deleteExpense(int expenseId) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Expense'),
        content: const Text('Are you sure you want to delete this expense?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete')),
        ],
      ),
    );
    if (shouldDelete == true) {
      try {
        await supabase.rpc('delete_expense', params: {'p_expense_id': expenseId});
        setState(() {});
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete expense: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  String _getCurrencySymbol(String? currencyCode) {
    return currencyCode == 'INR' ? '₹' : '\$';
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.groupName),
          actions: [
            IconButton(
              icon: const Icon(Icons.group_add),
              onPressed: () {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) => AddMembersPage(groupId: widget.groupId),
                )).then((_) => setState(() {}));
              },
              tooltip: 'Add Members',
            )
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Summary'),
              Tab(text: 'Expenses'),
              Tab(text: 'Balances'),
              Tab(text: 'Settlements'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildSummaryTab(),
            _buildExpensesList(),
            _buildBalancesList(),
            _buildSettlementsList(),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            Navigator.of(context)
                .push(MaterialPageRoute(builder: (context) => AddExpensePage(groupId: widget.groupId)))
                .then((_) => setState(() {}));
          },
          child: const Icon(Icons.add),
          tooltip: 'Add Expense',
        ),
      ),
    );
  }

  Widget _buildSummaryTab() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _getSummaryData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }
        final data = snapshot.data!;
        final totalSpending = data['total_spending'] as double;
        final myBalance = data['my_balance'] as double;

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildMetric(context, 'Group Total', '\$${totalSpending.toStringAsFixed(2)}'),
                      _buildMetric(context, 'Your Balance', '${myBalance >= 0 ? '+' : '-'}\$${myBalance.abs().toStringAsFixed(2)}', 
                        color: myBalance >= 0 ? Colors.green : Colors.red),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetric(BuildContext context, String title, String value, {Color? color}) {
    return Column(
      children: [
        Text(title, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey.shade400)),
        const SizedBox(height: 8),
        Text(
          value,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: color ?? Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
        ),
      ],
    );
  }

  Widget _buildExpensesList() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _getExpenses(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final expenses = snapshot.data!;
        if (expenses.isEmpty) return const Center(child: Text('No expenses yet. Add one!'));
        
        return ListView.builder(
          itemCount: expenses.length,
          itemBuilder: (context, index) {
            final expense = expenses[index];
            return ListTile(
              title: Text(expense['description']),
              subtitle: Text('Paid by ${expense['profiles']?['username'] ?? '...'}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${_getCurrencySymbol(expense['currency'])}${expense['amount']}'),
                  IconButton(
                    icon: Icon(Icons.delete, color: Colors.grey.shade600),
                    onPressed: () => _deleteExpense(expense['id']),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBalancesList() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _getBalances(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final balances = snapshot.data!;
        if (balances.isEmpty) return const Center(child: Text('No balances to show.'));
        
        return ListView.builder(
          itemCount: balances.length,
          itemBuilder: (context, index) {
            final balance = balances[index];
            final netBalance = double.parse(balance['net_balance'].toString());
            final isOwed = netBalance > 0;
            return ListTile(
              leading: CircleAvatar(child: Text(balance['username'][0])),
              title: Text(balance['username']),
              trailing: Text(
                isOwed ? 'Gets back \$${netBalance.abs().toStringAsFixed(2)}' : 'Owes \$${netBalance.abs().toStringAsFixed(2)}',
                style: TextStyle(color: isOwed ? Colors.green : Colors.red),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSettlementsList() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _getSettlements(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final settlements = snapshot.data!;
        if (settlements.isEmpty) return const Center(child: Text('All debts are settled!'));
        
        return ListView.builder(
          itemCount: settlements.length,
          itemBuilder: (context, index) {
            final settlement = settlements[index];
            return ListTile(
              leading: const Icon(Icons.payment),
              title: Text('${settlement['payer_username']} pays ${settlement['receiver_username']}'),
              trailing: Text('\$${settlement['amount']}'),
            );
          },
        );
      },
    );
  }
}