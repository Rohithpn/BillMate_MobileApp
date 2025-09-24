// lib/features/groups/add_expense_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class AddExpensePage extends StatefulWidget {
  final String groupId;
  const AddExpensePage({super.key, required this.groupId});

  @override
  State<AddExpensePage> createState() => _AddExpensePageState();
}

// Enums to represent the choices
enum SplitMethod { equally, byExactAmounts, byPercentage }
enum Currency { usd, inr }

class _AddExpensePageState extends State<AddExpensePage> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  bool _isLoading = false;
  SplitMethod _splitMethod = SplitMethod.equally;
  Currency _currency = Currency.usd;

  late Map<String, TextEditingController> _shareControllers;
  late Future<List<Map<String, dynamic>>> _membersFuture;

  @override
  void initState() {
    super.initState();
    _shareControllers = {};
    _membersFuture = _getGroupMembers();
  }

  Future<List<Map<String, dynamic>>> _getGroupMembers() async {
    final response = await supabase
        .from('group_members')
        .select('profiles!inner(id, username)')
        .eq('group_id', widget.groupId);
    final members = (response as List).map((item) => item['profiles'] as Map<String, dynamic>).toList();
    for (var member in members) {
      _shareControllers[member['id']] = TextEditingController();
    }
    return members;
  }

  Future<void> _addExpense() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isLoading = true; });

    final description = _descriptionController.text.trim();
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null) { /* handle error */ return; }
    final paidByUserId = supabase.auth.currentUser!.id;

    try {
      final membersResponse = await supabase.from('group_members').select('user_id').eq('group_id', widget.groupId);
      final members = (membersResponse as List).map((item) => item['user_id'] as String).toList();
      if (members.isEmpty) throw Exception('No members in this group.');

      late final List<Map<String, dynamic>> sharesToInsert;

      switch (_splitMethod) {
        case SplitMethod.equally:
          final share = (amount / members.length);
          sharesToInsert = members.map((userId) => {'user_id': userId, 'share': share}).toList();
          break;
        case SplitMethod.byExactAmounts:
          double sumOfShares = 0;
          _shareControllers.forEach((_, controller) {
            sumOfShares += double.tryParse(controller.text) ?? 0;
          });
          if (sumOfShares.toStringAsFixed(2) != amount.toStringAsFixed(2)) {
            throw Exception('The shares do not add up to the total amount.');
          }
          sharesToInsert = members.map((userId) => {'user_id': userId, 'share': double.tryParse(_shareControllers[userId]!.text) ?? 0}).toList();
          break;
        case SplitMethod.byPercentage:
          double sumOfPercentages = 0;
          _shareControllers.forEach((_, controller) {
            sumOfPercentages += double.tryParse(controller.text) ?? 0;
          });
          if (sumOfPercentages != 100) {
            throw Exception('Percentages must add up to 100.');
          }
          sharesToInsert = members.map((userId) {
            final percentage = double.tryParse(_shareControllers[userId]!.text) ?? 0;
            return {'user_id': userId, 'share': amount * (percentage / 100)};
          }).toList();
          break;
      }

      final newExpense = await supabase.from('expenses').insert({
        'description': description,
        'amount': amount,
        'group_id': widget.groupId,
        'paid_by': paidByUserId,
        'currency': _currency.name.toUpperCase(),
      }).select().single();

      final newExpenseId = newExpense['id'];
      final sharesWithExpenseId = sharesToInsert.map((share) => {...share, 'expense_id': newExpenseId}).toList();
      await supabase.from('expense_shares').insert(sharesWithExpenseId);

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to add expense: ${e.toString()}'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) { setState(() { _isLoading = false; }); }
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    for (var controller in _shareControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String get _currencySymbol {
    switch (_currency) {
      case Currency.usd: return '\$';
      case Currency.inr: return '₹';
    }
  }

  String get _splitInputHint {
    switch (_splitMethod) {
      case SplitMethod.byExactAmounts: return 'Amount';
      case SplitMethod.byPercentage: return '%';
      default: return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add New Expense')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Description'),
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _amountController,
                    decoration: InputDecoration(labelText: 'Amount', prefixText: _currencySymbol),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) => v == null || v.isEmpty || double.tryParse(v) == null ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 100,
                  child: DropdownButtonFormField<Currency>(
                    value: _currency,
                    items: const [
                      DropdownMenuItem(value: Currency.usd, child: Text('USD')),
                      DropdownMenuItem(value: Currency.inr, child: Text('INR')),
                    ],
                    onChanged: (value) => setState(() => _currency = value!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            DropdownButtonFormField<SplitMethod>(
              value: _splitMethod,
              items: const [
                DropdownMenuItem(value: SplitMethod.equally, child: Text('Split Equally')),
                DropdownMenuItem(value: SplitMethod.byExactAmounts, child: Text('Split by Exact Amounts')),
                DropdownMenuItem(value: SplitMethod.byPercentage, child: Text('Split by Percentage')),
              ],
              onChanged: (value) => setState(() => _splitMethod = value!),
              decoration: const InputDecoration(labelText: 'Split Method'),
            ),
            const SizedBox(height: 24),
            const Text('Members', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const Divider(),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _membersFuture,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final members = snapshot.data!;
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: members.length,
                  itemBuilder: (context, index) {
                    final member = members[index];
                    return ListTile(
                      title: Text(member['username']),
                      trailing: _splitMethod != SplitMethod.equally
                          ? SizedBox(
                              width: 80,
                              child: TextFormField(
                                controller: _shareControllers[member['id']],
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(hintText: _splitInputHint),
                              ),
                            )
                          : null,
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 24),
            _isLoading ? const Center(child: CircularProgressIndicator()) : ElevatedButton(onPressed: _addExpense, child: const Text('Add Expense')),
          ],
        ),
      ),
    );
  }
}