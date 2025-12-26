// lib/analysis_page.dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'database_helper.dart';
import 'currency_service.dart';
import 'ai_service.dart';
import 'package:shimmer/shimmer.dart';

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

  final AIService _aiService = AIService();


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
    // 1. Fetch Local Data First
    final transactions = await DatabaseHelper.instance.getAllTransactions(widget.userId);
    final budgets = await DatabaseHelper.instance.getAllBudgets(widget.userId);

    final expenses = transactions.where((t) => t.type == TransactionType.expense).toList();
    final incomeList = transactions.where((t) => t.type == TransactionType.income).toList();

    // Calculate Totals
    final categoryTotals = <String, double>{};
    for (var expense in expenses) {
      categoryTotals[expense.category] = (categoryTotals[expense.category] ?? 0) + expense.amount;
    }

    // Calculate Monthly Data
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

    // Update UI with chart data immediately so the screen isn't blank
    if (mounted) {
      setState(() {
        _transactions = transactions;
        _categoryTotals = categoryTotals;
        _monthlyData = monthlyData;
        // Don't set isLoading to false yet, we wait for AI
      });
    }

    // 2. Prepare Data for AI
    final totalSpent = expenses.fold(0.0, (sum, e) => sum + e.amount);
    final totalIncome = incomeList.fold(0.0, (sum, i) => sum + i.amount);

    // 3. Call AI Service (Real Intelligence)
    List<Insight> aiInsights;

    // Check if we have internet/data to send
    if (expenses.isEmpty) {
      aiInsights = [Insight(type: InsightType.info, title: "No Data", description: "Add expenses to get AI insights.", icon: Icons.hourglass_empty)];
    } else {
      aiInsights = await _aiService.getFinancialAdvice(
        totalIncome: _convertAmount(totalIncome),
        totalExpense: _convertAmount(totalSpent),
        categoryTotals: categoryTotals.map((k, v) => MapEntry(k, _convertAmount(v))),
        monthlyTrend: monthlyData.map((m) => MonthlyData(month: m.month, total: _convertAmount(m.total))).toList(),
        currencySymbol: _getCurrencySymbol(),
      );
    }

    if (mounted) {
      setState(() {
        _insights = aiInsights;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analysis'),
        backgroundColor: widget.isDarkTheme ? Colors.grey[900] : Colors.blue[700],
        foregroundColor: Colors.white,
      ),
      backgroundColor: widget.isDarkTheme ? Colors.grey[850] : Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- AI INSIGHTS SECTION ---
            const Text(
              'AI Insights & Advice',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // CONDITIONAL RENDERING
            if (_isLoading)
            // Render 3 skeletons directly here
              Column(
                children: List.generate(3, (index) => _InsightSkeleton(isDarkTheme: widget.isDarkTheme)),
              )
            else if (_insights.isEmpty)
              const Text("No specific insights available right now.")
            else
              ..._insights.map((insight) => _buildInsightCard(insight)),

            const SizedBox(height: 24),

            // --- VISUAL ANALYTICS SECTION ---
            const Text(
              'Visual Analytics',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildCategoryPieChart(),
            const SizedBox(height: 16),
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

    // 1. Calculate dynamic Max Y to give the chart "headroom"
    // We find the highest spending month and add 20% extra space at the top
    double maxSpend = 0;
    for (var m in _monthlyData) {
      if (m.total > maxSpend) maxSpend = m.total;
    }
    final double maxY = maxSpend * 1.2; // 20% buffer

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Spending Trend',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Last 6 Months',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 220, // Increased height for better visibility
              child: LineChart(
                LineChartData(
                  // 2. Fix the Scale
                  minY: 0,
                  maxY: maxY == 0 ? 100 : maxY, // Prevent crash if all are 0

                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false, // Cleaner look
                    horizontalInterval: maxY / 5, // roughly 5 grid lines
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: Colors.grey[300],
                        strokeWidth: 1,
                        dashArray: [5, 5], // Dashed grid lines
                      );
                    },
                  ),

                  titlesData: FlTitlesData(
                    show: true,
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),

                    // Y-Axis Labels (Left)
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40, // Space for "10k" etc
                        getTitlesWidget: (value, meta) {
                          if (value == 0) return const SizedBox.shrink(); // Hide 0
                          // Simple formatting: 1000 -> 1k
                          if (value >= 1000) {
                            return Text('${(value / 1000).toStringAsFixed(1)}k',
                                style: const TextStyle(fontSize: 10, color: Colors.grey));
                          }
                          return Text(value.toInt().toString(),
                              style: const TextStyle(fontSize: 10, color: Colors.grey));
                        },
                      ),
                    ),

                    // X-Axis Labels (Bottom)
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index >= 0 && index < _monthlyData.length) {
                            // Extract just the month name (e.g. "Nov") to save space
                            // Assuming _monthlyData[i].month is "Nov 2025"
                            String fullDate = _monthlyData[index].month;
                            String shortMonth = fullDate.split(' ')[0];

                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                shortMonth,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blueGrey,
                                ),
                              ),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                  ),

                  borderData: FlBorderData(show: false), // No ugly border box

                  lineBarsData: [
                    LineChartBarData(
                      spots: _monthlyData.asMap().entries.map((e) {
                        return FlSpot(e.key.toDouble(), e.value.total);
                      }).toList(),
                      isCurved: true, // Smooth curves
                      curveSmoothness: 0.35,
                      color: widget.isDarkTheme ? Colors.blueAccent : Colors.blue,
                      barWidth: 4,
                      isStrokeCapRound: true,

                      // 3. Add the Dot on the data points
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) {
                          return FlDotCirclePainter(
                            radius: 4,
                            color: Colors.white,
                            strokeWidth: 2,
                            strokeColor: Colors.blue,
                          );
                        },
                      ),

                      // 4. Add the Gradient Fill below the line (Modern Look)
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                            Colors.blue.withOpacity(0.3),
                            Colors.blue.withOpacity(0.0),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
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

// --- Place this at the bottom of analysis_page.dart ---

class _InsightSkeleton extends StatelessWidget {
  final bool isDarkTheme;
  const _InsightSkeleton({required this.isDarkTheme});

  @override
  Widget build(BuildContext context) {
    // Define colors: Darker greys for Dark Mode, Lighter for Light Mode
    final baseColor = isDarkTheme ? Colors.grey[800]! : Colors.grey[300]!;
    final highlightColor = isDarkTheme ? Colors.grey[700]! : Colors.grey[100]!;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      // Make card transparent so shimmer effect stands out
      color: Colors.transparent,
      elevation: 0,
      child: Shimmer.fromColors(
        baseColor: baseColor,
        highlightColor: highlightColor,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // 1. Fake Icon Circle
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 16),
              // 2. Fake Text Lines
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title Bar
                    Container(
                      width: double.infinity,
                      height: 16,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Description Bar (shorter)
                    Container(
                      width: 200,
                      height: 14,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
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