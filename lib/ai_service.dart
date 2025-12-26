// lib/ai_service.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'analysis_page.dart';

class AIService {
  static const String _apiKey = 'YOUR_API_KEY';

  Future<List<Insight>> getFinancialAdvice({
    required double totalIncome,
    required double totalExpense,
    required Map<String, double> categoryTotals,
    required List<MonthlyData> monthlyTrend,
    required String currencySymbol,
  }) async {
    if (_apiKey == null) return [];

    // UPDATED: Use the current 2025 model
    final model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: _apiKey,
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json', // 2.5 supports JSON natively
      ),
    );

    final trendString = monthlyTrend.map((m) => "${m.month}: ${m.total}").join(", ");
    final categoryString = categoryTotals.entries.map((e) => "${e.key}: ${e.value}").join(", ");

    final prompt = '''
      You are a smart financial advisor. Analyze the following user financial data and generate 4-5 concise insights.
      
      Data:
      - Currency: $currencySymbol
      - Total Income: $totalIncome
      - Total Expense: $totalExpense
      - Spending by Category: $categoryString
      - Monthly Spending Trend (last 6 months): $trendString
      
      Output Requirement:
      Return a strict JSON array of objects. Each object must have:
      - "type": One of ["info", "warning", "error", "advice"]
      - "title": Short title (max 5 words)
      - "description": specific advice based on the numbers (max 20 words)
      - "icon_name": One of ["trending_up", "trending_down", "warning", "lightbulb", "attach_money", "category"]
    ''';

    try {
      final content = [Content.text(prompt)];
      final response = await model.generateContent(content);

      if (response.text == null) return [];

      String cleanJson = response.text!;

      // --- NEW ROBUST CLEANING LOGIC ---
      // This finds the actual JSON array [...] and ignores any extra text before or after it.
      final startIndex = cleanJson.indexOf('[');
      final endIndex = cleanJson.lastIndexOf(']');

      if (startIndex != -1 && endIndex != -1) {
        cleanJson = cleanJson.substring(startIndex, endIndex + 1);
      } else {
        // If AI didn't return an array, return empty list to prevent crash
        debugPrint("AI did not return a JSON array: $cleanJson");
        return [];
      }
      // ---------------------------------

      final List<dynamic> jsonList = jsonDecode(cleanJson);

      return jsonList.map((item) {
        return Insight(
          type: _parseType(item['type']),
          title: item['title'],
          description: item['description'],
          icon: _parseIcon(item['icon_name']),
        );
      }).toList();

    } catch (e) {
      debugPrint("AI Error: $e");
      // Print the raw text to console so you can see what went wrong next time
      return [
        Insight(
            type: InsightType.error,
            title: "Analysis Failed",
            description: "Technical error parsing AI response.",
            icon: Icons.error_outline
        )
      ];
    }

  }

  InsightType _parseType(String? type) {
    switch (type?.toLowerCase()) {
      case 'warning': return InsightType.warning;
      case 'error': return InsightType.error;
      case 'advice': return InsightType.advice;
      default: return InsightType.info;
    }
  }

  IconData _parseIcon(String? iconName) {
    switch (iconName?.toLowerCase()) {
      case 'trending_up': return Icons.trending_up;
      case 'trending_down': return Icons.trending_down;
      case 'warning': return Icons.warning;
      case 'lightbulb': return Icons.lightbulb;
      case 'category': return Icons.category;
      case 'attach_money': return Icons.attach_money;
      default: return Icons.info;
    }
  }
}