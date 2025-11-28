// lib/analysis_page.dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'database_helper.dart';
import 'currency_service.dart';

class AnalysisPage extends StatefulWidget {
  final bool isDarkTheme;
  final int userId;
  final String selectedCurrency;
  final Map<String, double> exchangeRates;
  const AnalysisPage({
    super.key,
    required this.isDarkTheme,
    required this.userId,
    required this.selectedCurrency,
    required this.exchangeRates,
  });
  @override
  State<AnalysisPage> createState() => _AnalysisPageState();
}
class _AnalysisPageState extends State<AnalysisPage> {
  List<Transaction> _transactions = [];
  List<Budget> _budgets = [];
  bool _isLoading = true;
  List<Insight> _insights = [];
  Map<String, double> _categoryTotals = {};
  List<MonthlyData> _monthlyData = [];
  // Helper to convert amounts (assuming DB stores in base INR, convert for display)
  double _convertAmount(double amount) {
    if (widget.exchangeRates.isEmpty) return amount;
    try {
      return CurrencyService.convertAmount(amount, 'INR', widget.selectedCurrency, widget.exchangeRates);
    } catch (e) {
      return amount;
    }
  }
  String _getCurrencySymbol() {
    switch (widget.selectedCurrency) {
      case 'EUR': return '€';
      case 'GBP': return '£';
      case 'INR': return '₹';
      case 'JPY': return '¥';
      default: return '\$';
    }
  }
  @override
  void initState() {
    super.initState();
    _loadData();
  }
  Future<void> _loadData() async {
    final transactions = await DatabaseHelper.instance.getAllTransactions(widget.userId);
    final budgets = await DatabaseHelper.instance.getAllBudgets(widget.userId);
    // Filter expenses only for analysis
    final expenses = transactions.where((t) => t.type == TransactionType.expense).toList();
    // Calculate category totals
    final categoryTotals = <String, double>{};
    for (var expense in expenses) {
      categoryTotals[expense.category] = (categoryTotals[expense.category] ?? 0) + expense.amount;
    }
    // Calculate monthly data for trend (last 6 months)
    final now = DateTime.now();
    final monthlyData = <MonthlyData>[];
    for (int i = 5; i >= 0; i--) {
      final monthStart = DateTime(now.year, now.month - i, 1);
      final monthEnd = DateTime(now.year, now.month - i + 1, 0);
      double total = 0;
      for (var expense in expenses) {
        if (expense.date.isAfter(monthStart.subtract(const Duration(days: 1))) &&
            expense.date.isBefore(monthEnd.add(const Duration(days: 1)))) {
          total += expense.amount;
        }
      }
      monthlyData.add(MonthlyData(
        month: DateFormat('MMM yyyy').format(monthStart),
        total: total,
      ));
    }
    // Generate AI-like insights (rule-based for now; can integrate real AI API later)
    // Fixed: Pass all required data to avoid using uninitialized state variables
    final insights = _generateInsights(transactions, expenses, budgets, categoryTotals, monthlyData);
    if (mounted) {
      setState(() {
        _transactions = transactions;
        _budgets = budgets;
        _categoryTotals = categoryTotals;
        _monthlyData = monthlyData;
        _insights = insights;
        _isLoading = false;
      });
    }
  }
  List<Insight> _generateInsights(
      List<Transaction> allTransactions,
      List<Transaction> expenses,
      List<Budget> budgets,
      Map<String, double> categoryTotals,
      List<MonthlyData> monthlyData,
      ) {
    final insights = <Insight>[];
    final totalSpent = expenses.fold(0.0, (sum, e) => sum + e.amount);
    final totalIncome = allTransactions.where((t) => t.type == TransactionType.income).fold(0.0, (sum, i) => sum + i.amount);
    final netSavings = totalIncome - totalSpent;
    // Insight 1: Overall balance
    insights.add(Insight(
      type: InsightType.info,
      title: 'Net Savings',
      description: 'Your net savings this period is ${_getCurrencySymbol()}${_convertAmount(netSavings).toStringAsFixed(2)}. Keep up the good work!',
      icon: Icons.trending_up,
    ));
    // Insight 2: Top spending category
    if (categoryTotals.isNotEmpty) {
      final topCategory = categoryTotals.entries.reduce((a, b) => a.value > b.value ? a : b);
      insights.add(Insight(
        type: InsightType.warning,
        title: 'Top Spending Category',
        description: 'You spent the most (${_getCurrencySymbol()}${_convertAmount(topCategory.value).toStringAsFixed(2)}) on ${topCategory.key}. Consider reviewing this category.',
        icon: Icons.category,
      ));
    }
    // Insight 3: Budget overspend
    for (var budget in budgets) {
      final spent = categoryTotals[budget.category] ?? 0;
      if (spent > budget.allocated) {
        insights.add(Insight(
          type: InsightType.error,
          title: 'Budget Overspend',
          description: 'Overspent on ${budget.category} by ${_getCurrencySymbol()}${_convertAmount(spent - budget.allocated).toStringAsFixed(2)}. Adjust your budget or cut back.',
          icon: Icons.warning,
        ));
      }
    }
    // Insight 4: Spending trend
    if (monthlyData.length > 1) {
      final lastMonth = monthlyData.last.total;
      final prevMonth = monthlyData[monthlyData.length - 2].total;
      if (lastMonth > prevMonth) {
        insights.add(Insight(
          type: InsightType.error,
          title: 'Increasing Spend',
          description: 'Spending increased by ${_getCurrencySymbol()}${_convertAmount(lastMonth - prevMonth).toStringAsFixed(2)} from last month. Track expenses closely.',
          icon: Icons.trending_up,
        ));
      } else {
        insights.add(Insight(
          type: InsightType.info,
          title: 'Decreasing Spend',
          description: 'Spending decreased by ${_getCurrencySymbol()}${_convertAmount(prevMonth - lastMonth).toStringAsFixed(2)} from last month. Great progress!',
          icon: Icons.trending_down,
        ));
      }
    }
    // Advice: General tip
    insights.add(Insight(
      type: InsightType.advice,
      title: 'Pro Tip',
      description: 'Review your subscriptions in the "Bills" category to save more. Aim to save 20% of your income automatically.',
      icon: Icons.lightbulb,
    ));
    return insights;
  }
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Analysis'),
          backgroundColor: widget.isDarkTheme ? Colors.grey[900] : Colors.blue[700],
          foregroundColor: Colors.white,
        ),
        backgroundColor: widget.isDarkTheme ? Colors.grey[850] : Colors.white,
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      backgroundColor: widget.isDarkTheme ? Colors.grey[850] : Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // AI Insights & Advice Section
            const Text(
              'AI Insights & Advice',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ..._insights.map((insight) => _buildInsightCard(insight)),
            const SizedBox(height: 24),
            // Charts Section
            const Text(
              'Visual Analytics',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildCategoryPieChart(),
            const SizedBox(height: 16),
            // Fixed: Removed fixed height to prevent overflow; let it expand naturally
            _buildMonthlyTrendChart(),
          ],
        ),
      ),
    );
  }
  Widget _buildInsightCard(Insight insight) {
    Color? iconColor;
    switch (insight.type) {
      case InsightType.info:
        iconColor = Colors.blue;
        break;
      case InsightType.warning:
        iconColor = Colors.orange;
        break;
      case InsightType.error:
        iconColor = Colors.red;
        break;
      case InsightType.advice:
        iconColor = Colors.green;
        break;
    }
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: widget.isDarkTheme ? Colors.grey[800] : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(insight.icon, color: iconColor, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    insight.title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(insight.description, style: const TextStyle(fontSize: 14)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildCategoryPieChart() {
    if (_categoryTotals.isEmpty) {
      return const Card(child: Center(child: Text('No data for categories yet.')));
    }
    final total = _categoryTotals.values.fold(0.0, (sum, v) => sum + v);
    final slices = _categoryTotals.entries.map((entry) {
      final percentage = (entry.value / total) * 100;
      return PieChartSectionData(
        color: _getRandomColor(entry.key.hashCode),
        value: entry.value,
        title: '${entry.key}\n${percentage.toStringAsFixed(1)}%',
        radius: 60,
        titleStyle: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold),
      );
    }).toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('Spending by Category', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              child: PieChart(
                PieChartData(
                  sections: slices,
                  centerSpaceRadius: 40,
                  sectionsSpace: 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlyTrendChart() {
    if (_monthlyData.isEmpty) {
      return const Card(child: Center(child: Text('No trend data yet.')));
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Monthly Spending Trend (Last 6 Months)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            SizedBox(
              height: 120, // Reduced height to prevent overflow
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: true),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 1, // Force show all intervals
                        reservedSize: 30, // Reserve space for labels
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index >= 0 && index < _monthlyData.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                _monthlyData[index].month,
                                style: const TextStyle(fontSize: 8), // Smaller font to fit
                              ),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: true),
                  lineBarsData: [
                    LineChartBarData(
                      spots: _monthlyData.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.total)).toList(),
                      isCurved: true,
                      color: Colors.blue,
                      barWidth: 3,
                      dotData: const FlDotData(show: true),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getRandomColor(int seed) {
    // Simple hash-based color generator
    final colors = [Colors.red, Colors.green, Colors.blue, Colors.orange, Colors.purple, Colors.teal, Colors.pink];
    return colors[seed % colors.length];
  }
}
// Supporting models
enum InsightType { info, warning, error, advice }
class Insight {
  final InsightType type;
  final String title;
  final String description;
  final IconData icon;
  Insight({
    required this.type,
    required this.title,
    required this.description,
    required this.icon,
  });
}
class MonthlyData {
  final String month;
  final double total;
  MonthlyData({required this.month, required this.total});
}