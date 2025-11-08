// lib/help_support_page.dart
import 'package:flutter/material.dart';

class HelpSupportPage extends StatelessWidget {
  final bool isDarkTheme;

  const HelpSupportPage({
    super.key,
    required this.isDarkTheme,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Help & Support'),
        backgroundColor: isDarkTheme ? Colors.grey[900] : Colors.blue[700],
        foregroundColor: Colors.white,
      ),
      backgroundColor: isDarkTheme ? Colors.grey[850] : Colors.white,
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          const Text(
            'Frequently Asked Questions (FAQs)',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          _buildFAQItem(
            'How do I add a transaction?',
            'Tap the floating action button (+) on the Transactions tab, fill in the details, and save.',
          ),
          _buildFAQItem(
            'How do I set a budget?',
            'Go to the Budgets tab, tap "Add Budget / Category", enter the amount, and save.',
          ),
          _buildFAQItem(
            'How do I search transactions?',
            'On the Transactions tab, tap the search icon and enter keywords like title, category, or date.',
          ),
          _buildFAQItem(
            'How do I logout?',
            'Open the drawer (hamburger menu), and tap "Logout".',
          ),
          const SizedBox(height: 30),
          const Text(
            'User Guide',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            '1. Register or login to access your account.\n'
                '2. Use the Dashboard to view your balance and recent transactions.\n'
                '3. Add transactions on the Transactions tab.\n'
                '4. Set budgets on the Budgets tab to track spending.\n'
                '5. Access settings from the drawer to customize preferences.',
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 30),
          const Text(
            'Contact Support',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'If you need help, email us at: support@mymoneyapp.com\n',
            style: TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildFAQItem(String question, String answer) {
    return ExpansionTile(
      title: Text(question, style: const TextStyle(fontWeight: FontWeight.bold)),
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(answer),
        ),
      ],
    );
  }
}