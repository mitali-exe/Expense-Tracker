// lib/about_page.dart
import 'package:flutter/material.dart';

class AboutPage extends StatelessWidget {
  final bool isDarkTheme;
  const AboutPage({
    super.key,
    required this.isDarkTheme,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('About'),
        backgroundColor: isDarkTheme ? Colors.grey[900] : Colors.blue[700],
        foregroundColor: Colors.white,
      ),
      backgroundColor: isDarkTheme ? Colors.grey[850] : Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            Center(
              child: Icon(
                Icons.account_balance_wallet,
                size: 80,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 20),
            const Center(
              child: Text(
                'MyMoney',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Center(
              child: Text(
                'Version 1.0.0',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
            ),
            const SizedBox(height: 30),
            const Text(
              'About This App',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'MyMoney is a simple and intuitive expense tracker app designed to help you manage your finances. Track transactions, set budgets, and monitor your spending with ease.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            const Text(
              'Developer',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'Built with Flutter by Mitali Srivastav.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            const Text(
              'Contact',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'For support, email: support@mymoneyapp.com',
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}