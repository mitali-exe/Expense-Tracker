import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'database_helper.dart';

class SettingsPage extends StatefulWidget {
  final String selectedCurrency;
  final ValueChanged<String> onCurrencyChanged;
  final bool isDarkTheme;
  final int userId;
  final VoidCallback onDataReset;
  final VoidCallback onAccountDeleted;

  const SettingsPage({
    super.key,
    required this.selectedCurrency,
    required this.onCurrencyChanged,
    required this.isDarkTheme,
    required this.userId,
    required this.onDataReset,
    required this.onAccountDeleted,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late String _selectedCurrency;

  @override
  void initState() {
    super.initState();
    _selectedCurrency = widget.selectedCurrency;
  }

  final List<String> _currencies = ['INR', 'EUR', 'GBP', 'USD', 'JPY'];

  void _exportData() async {
    final transactions = await DatabaseHelper.instance.getAllTransactions(widget.userId);
    final csvData = [
      ['title', 'amount', 'date', 'category', 'type'], // Header
      ...transactions.map((t) => [
        t.title,
        t.amount.toString(),
        DateFormat('yyyy-MM-dd').format(t.date),
        t.category,
        t.type == TransactionType.income ? 'income' : 'expense',
      ]),
    ];

    final csvString = const ListToCsvConverter().convert(csvData);
    final directory = await getExternalStorageDirectory();
    final filePath = '${directory!.path}/transactions_export.csv';
    final file = File(filePath);
    await file.writeAsString(csvString);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Data exported to $filePath')),
    );
  }

  void _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text('This will permanently delete your account and ALL associated data (transactions, budgets, goals). This action CANNOT be undone. Are you absolutely sure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('DELETE ACCOUNT'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await DatabaseHelper.instance.deleteAllDataForUser(widget.userId);
        await DatabaseHelper.instance.deleteUser(widget.userId);
        widget.onAccountDeleted();
        if (mounted) {
          Navigator.of(context).pop();
        }
      } catch (e) {
        // Handle database errors
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting account: $e')),
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: widget.isDarkTheme ? Colors.grey[900] : Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          const Text(
            'Preferences',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          ListTile(
            title: const Text('Currency'),
            subtitle: Text('Current: $_selectedCurrency'),
            trailing: DropdownButton<String>(
              value: _selectedCurrency,
              items: _currencies.map((String currency) {
                return DropdownMenuItem<String>(
                  value: currency,
                  child: Text(currency),
                );
              }).toList(),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    _selectedCurrency = newValue;
                  });
                  widget.onCurrencyChanged(newValue);
                }
              },
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Data Management',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          ListTile(
            title: const Text('Export Data'),
            subtitle: const Text('Export transactions to CSV'),
            trailing: const Icon(Icons.download),
            onTap: _exportData,  // Add this
          ),

          ListTile(
            title: const Text('Reset Data'),
            subtitle: const Text('Clear all transactions and budgets'),
            trailing: const Icon(Icons.delete_forever),
            onTap: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Reset Data'),
                  content: const Text('This will permanently delete all your transactions and budgets. This action cannot be undone. Are you sure?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Reset'),
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                    ),
                  ],
                ),
              );

              if (confirmed == true) {
                try {
                  await DatabaseHelper.instance.deleteAllDataForUser(widget.userId);
                  widget.onDataReset();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('All data has been reset')),
                  );
                  Navigator.pop(context);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error resetting data: $e')),
                  );
                }
              }
            },
          ),

          const SizedBox(height: 20),
          const Text(
            'Account Management', // NEW Section Header
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),

          ListTile(
            title: const Text('Delete Account'),
            subtitle: const Text('Permanently delete your account and all data'),
            trailing: const Icon(Icons.person_remove, color: Colors.red),
            onTap: _deleteAccount, // NEW: Call the deletion function
          ),

        ],
      ),
    );
  }
}