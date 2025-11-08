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
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final monthStart = DateTime(now.year, now.month, 1);
    final yearStart = DateTime(now.year, 1, 1);

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
                final goal = SavingsGoal(
                  id: DateTime.now().toString(),
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

  void _addSaving() {
    final amountController = TextEditingController();
    final titleController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Saving Amount'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Saving Title (e.g., Deposit)'),
            ),
            TextField(
              controller: amountController,
              decoration: InputDecoration(
                labelText: 'Amount (${widget.selectedCurrency})',  // Use currency
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final title = titleController.text.trim();
              final amount = double.tryParse(amountController.text) ?? 0;
              if (title.isNotEmpty && amount > 0) {
                final savingTransaction = Transaction(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  title: title,
                  amount: amount,
                  date: DateTime.now(),
                  category: 'Savings',
                  type: TransactionType.income,  // Treat as income for savings
                  isSaving: true,
                );
                await DatabaseHelper.instance.insertTransaction(savingTransaction, widget.userId);
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
            const Text('Savings Summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildSummaryCard('Weekly Savings', _weeklySavings),
            _buildSummaryCard('Monthly Savings', _monthlySavings),
            _buildSummaryCard('Yearly Savings', _yearlySavings),
            const SizedBox(height: 32),
            const Text('Goals', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ..._goals.map((goal) => _buildGoalCard(goal)),
          ],
        ),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: _addSaving,
            child: const Icon(Icons.add_circle),
            tooltip: 'Add Saving Amount',
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            onPressed: _addGoal,
            child: const Icon(Icons.add),
            tooltip: 'Add Goal',
          ),
        ],
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
            Text('${widget.selectedCurrency}${amount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),  // Use currency
          ],
        ),
      ),
    );
  }

  Widget _buildGoalCard(SavingsGoal goal) {
    final double progress = goal.target > 0 ? (_yearlySavings / goal.target).clamp(0.0, 1.0) : 0;
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(goal.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: progress, minHeight: 8),
            const SizedBox(height: 8),
            Text('${widget.selectedCurrency}${_yearlySavings.toStringAsFixed(2)} / ${widget.selectedCurrency}${goal.target.toStringAsFixed(2)} (${(progress * 100).toInt()}%)'),  // Use currency
          ],
        ),
      ),
    );
  }
}