// lib/savings_page.dart
import 'package:flutter/material.dart';
import 'database_helper.dart';

class SavingsPage extends StatefulWidget {
  final bool isDarkTheme;
  final int userId;
  final String selectedCurrency;

  const SavingsPage({super.key, required this.isDarkTheme, required this.userId, required this.selectedCurrency});

  @override
  State<SavingsPage> createState() => _SavingsPageState();
}

class _SavingsPageState extends State<SavingsPage> {
  List<SavingsGoal> _goals = [];
  double _weeklySavings = 0;
  double _monthlySavings = 0;
  double _yearlySavings = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final goals = await DatabaseHelper.instance.getAllSavingsGoals(widget.userId);
    final now = DateTime.now();
    // Calculate weekly start day: Monday (1)
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final monthStart = DateTime(now.year, now.month, 1);
    final yearStart = DateTime(now.year, 1, 1);

    // Get savings totals
    final weekly = await DatabaseHelper.instance.getTotalSavings(widget.userId, startDate: weekStart, endDate: now);
    final monthly = await DatabaseHelper.instance.getTotalSavings(widget.userId, startDate: monthStart, endDate: now);
    final yearly = await DatabaseHelper.instance.getTotalSavings(widget.userId, startDate: yearStart, endDate: now);


    setState(() {
      _goals = goals;
      _weeklySavings = weekly;
      _monthlySavings = monthly;
      _yearlySavings = yearly;
    });
  }

  // Modified: Simplified to only ask for amount and log a transaction
  void _addSavingToGoal(SavingsGoal goal) {
    final amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add Saving to ${goal.title}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Current total savings this year: ${_getCurrencySymbol()}${_yearlySavings.toStringAsFixed(2)}'),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              decoration: InputDecoration(
                labelText: 'Amount to Save (${_getCurrencySymbol()})',
                hintText: 'e.g., 50.00',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(amountController.text) ?? 0;
              if (amount > 0) {
                final savingTransaction = Transaction(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  title: 'Saving for: ${goal.title}',
                  amount: amount,
                  date: DateTime.now(),
                  category: 'Savings',
                  type: TransactionType.expense, // Changed to Expense: Savings is usually considered an expense (money leaving liquid funds) for tracking purposes.
                  isSaving: true,
                );
                await DatabaseHelper.instance.insertTransaction(savingTransaction, widget.userId);
                _loadData();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${_getCurrencySymbol()}${amount.toStringAsFixed(2)} added to ${goal.title}')),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a valid amount')),
                );
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  String _getCurrencySymbol() {
    switch (widget.selectedCurrency) {
      case 'EUR':
        return '€';
      case 'GBP':
        return '£';
      case 'INR':
        return '₹';
      case 'JPY':
        return '¥';
      default:
        return '\$';  // USD
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Savings Goals'),
        backgroundColor: widget.isDarkTheme ? Colors.grey[900] : Colors.blue,
        foregroundColor: Colors.white,
      ),
      backgroundColor: widget.isDarkTheme ? Colors.grey[850] : Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Savings Summary (This Year)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildSummaryCard('Weekly Savings', _weeklySavings),
            _buildSummaryCard('Monthly Savings', _monthlySavings),
            _buildSummaryCard('Yearly Savings', _yearlySavings),
            const SizedBox(height: 32),
            const Text('Goals', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            if (_goals.isEmpty)
              const Center(child: Text('No savings goals set yet.'))
            else
              ..._goals.map((goal) => _buildGoalCard(goal)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addGoal,
        child: const Icon(Icons.add),
        tooltip: 'Add Goal',
      ),
    );
  }

  Widget _buildSummaryCard(String title, double amount) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(fontSize: 16)),
            Text('${_getCurrencySymbol()}${amount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalCard(SavingsGoal goal) {
    final double progress = goal.target > 0 ? _yearlySavings / goal.target : 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ListTile(
        onTap: () => _addSavingToGoal(goal), // Tapping asks for amount to save
        title: Text(goal.title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: Colors.grey[300],
              color: Colors.blue,
            ),
            const SizedBox(height: 4),
            Text(
              '${_getCurrencySymbol()}${_yearlySavings.toStringAsFixed(2)} saved / ${_getCurrencySymbol()}${goal.target.toStringAsFixed(2)} target (${(progress * 100).toInt()}%)',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit') {
              _editGoal(goal);
            } else if (value == 'delete') {
              _deleteGoal(goal);
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: Text('Modify Goal'),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Text('Remove Goal'),
            ),
          ],
        ),
      ),
    );
  }

  void _editGoal(SavingsGoal goal) {
    final titleController = TextEditingController(text: goal.title);
    final targetController = TextEditingController(text: goal.target.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Savings Goal'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Goal Title'),
            ),
            TextField(
              controller: targetController,
              decoration: const InputDecoration(labelText: 'Target Amount'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final title = titleController.text.trim();
              final target = double.tryParse(targetController.text) ?? 0;
              if (title.isNotEmpty && target > 0) {
                final updatedGoal = SavingsGoal(
                  id: goal.id,
                  title: title,
                  target: target,
                );
                await DatabaseHelper.instance.updateSavingsGoal(updatedGoal, widget.userId);
                _loadData();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Savings goal updated.')),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _deleteGoal(SavingsGoal goal) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Savings Goal'),
        content: Text('Are you sure you want to remove the goal: ${goal.title}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              await DatabaseHelper.instance.deleteSavingsGoal(goal.id, widget.userId);
              _loadData();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Savings goal removed.')),
              );
            },
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _addGoal() {
    final titleController = TextEditingController();
    final targetController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Savings Goal'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Goal Title'),
            ),
            TextField(
              controller: targetController,
              decoration: InputDecoration(labelText: 'Target Amount (${_getCurrencySymbol()})'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final title = titleController.text.trim();
              final target = double.tryParse(targetController.text) ?? 0;
              if (title.isNotEmpty && target > 0) {
                final goal = SavingsGoal(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  title: title,
                  target: target,
                );
                await DatabaseHelper.instance.insertSavingsGoal(goal, widget.userId);
                _loadData();
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}