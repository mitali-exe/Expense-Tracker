import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'database_helper.dart';
import 'login_page.dart';
import 'registration_page.dart';
import 'settings_page.dart';
import 'about_page.dart';
import 'help_support_page.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:csv/csv.dart';
import 'package:file_selector/file_selector.dart';
import 'dart:io';
import 'savings_page.dart';
import 'currency_service.dart';
import 'analysis_page.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  runApp(const MyMoneyApp());
}

class MyMoneyApp extends StatefulWidget {
  const MyMoneyApp({super.key});

  @override
  State<MyMoneyApp> createState() => _MyMoneyAppState();
}

class _MyMoneyAppState extends State<MyMoneyApp> {
  bool _isDarkTheme = false;
  User? _currentUser;
  String _selectedCurrency = 'INR'; // Default currency
  Map<String, double> _exchangeRates = {};

  @override
  void initState() {
    super.initState();
    _loadPersistedUser();
    _loadPersistedCurrency();
    _fetchExchangeRates();
  }

  Future<void> _loadPersistedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('current_user_id');
    if (userId != null) {
      try {
        final user = await DatabaseHelper.instance.getUserById(userId);
        if (user != null) {
          _setCurrentUser(user);
          print('Auto-logged in as ${user.username}');
        } else {
          _clearPersistedUser();
        }
      } catch (e) {
        _clearPersistedUser();
        print('Error loading persisted user: $e');
      }
    }
  }

  Future<void> _loadPersistedCurrency() async {
    final prefs = await SharedPreferences.getInstance();
    final currency = prefs.getString('selected_currency') ?? 'INR';
    setState(() {
      _selectedCurrency = currency;
    });
  }

  Future<void> _savePersistedCurrency(String currency) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_currency', currency);
  }

  void _toggleTheme(bool isDark) {
    setState(() {
      _isDarkTheme = isDark;
    });
  }

  // Add method to fetch rates
  Future<void> _fetchExchangeRates() async {
    try {
      final rates = await CurrencyService.getExchangeRates();
      setState(() {
        _exchangeRates = rates;
      });
    } catch (e) {
      print('Error fetching rates: $e');  // Handle silently or show snackbar
    }
  }

  void _setCurrentUser(User? user) {
    print('Setting current user: ${user?.username ?? 'null'}');
    setState(() {
      _currentUser = user;
    });
    if (user != null) {
      _savePersistedUser(user.id);
    } else {
      _clearPersistedUser();
    }
  }

  Future<void> _savePersistedUser(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('current_user_id', userId);
  }

  Future<void> _clearPersistedUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('current_user_id');
  }

  void _setCurrency(String currency) {
    setState(() {
      _selectedCurrency = currency;
    });
    _savePersistedCurrency(currency);
    _fetchExchangeRates();
  }

  void _logoutUser() {
    print('Logging out user');
    setState(() {
      _currentUser = null;
    });
    _clearPersistedUser();
  }


  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MyMoney Clone',
      theme: _isDarkTheme
          ? ThemeData.dark()
          : ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        scaffoldBackgroundColor: Colors.grey[100],
      ),
      home: AppWrapper(
        currentUser: _currentUser,
        isDarkTheme: _isDarkTheme,
        selectedCurrency: _selectedCurrency,
        onThemeChanged: _toggleTheme,
        onUserChanged: _setCurrentUser,
        onCurrencyChanged: _setCurrency,
        onLogout: _logoutUser,
        exchangeRates: _exchangeRates,
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}

// Wrapper widget to handle login state and pass params to HomeScreen
class AppWrapper extends StatelessWidget {
  final User? currentUser;
  final bool isDarkTheme;
  final String selectedCurrency;
  final ValueChanged<bool> onThemeChanged;
  final ValueChanged<User?> onUserChanged;
  final ValueChanged<String> onCurrencyChanged;
  final VoidCallback onLogout;
  final Map<String, double> exchangeRates;

  const AppWrapper({
    super.key,
    required this.currentUser,
    required this.isDarkTheme,
    required this.selectedCurrency,
    required this.onThemeChanged,
    required this.onUserChanged,
    required this.onCurrencyChanged,
    required this.onLogout,
    required this.exchangeRates,
  });

  @override
  Widget build(BuildContext context) {
    print('AppWrapper rebuild: currentUser = ${currentUser?.username ?? 'null'}');
    if (currentUser == null) {
      return LoginPage(
        onLoginSuccess: (user) {
          print('Login success callback triggered for ${user.username}');
          onUserChanged(user);
        },
      );
    } else {
      return HomeScreen(
        currentUser: currentUser!,
        isDarkTheme: isDarkTheme,
        selectedCurrency: selectedCurrency,
        onThemeChanged: onThemeChanged,
        onCurrencyChanged: onCurrencyChanged,
        onLogout: onLogout,
        onUserChanged: onUserChanged,
        exchangeRates: exchangeRates,
      );
    }
  }
}


class HomeScreen extends StatefulWidget {
  final User currentUser;
  final bool isDarkTheme;
  final String selectedCurrency;
  final ValueChanged<bool> onThemeChanged;
  final ValueChanged<String> onCurrencyChanged;
  final VoidCallback onLogout;
  final ValueChanged<User?> onUserChanged;
  final Map<String, double> exchangeRates;

  const HomeScreen({
    super.key,
    required this.currentUser,
    required this.isDarkTheme,
    required this.selectedCurrency,
    required this.onThemeChanged,
    required this.onCurrencyChanged,
    required this.onLogout,
    required this.onUserChanged,
    required this.exchangeRates,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  // Local lists (loaded from DB for current user)
  List<Transaction> _transactions = [];
  List<Budget> _budgets = [];

  // Categories list (in memory for now)
  List<String> _categories = [
    'Food',
    'Bills',
    'Entertainment',
    'Transport',
    'Income',
    'Other',
  ];

  // Search query for transactions
  String _searchQuery = '';

  // Filtered transactions for date search
  List<Transaction> _filteredTransactions = [];
  bool _isDateFilterActive = false;
  bool _isDataLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDataFromDatabase();
  }



  Future<void> _loadDataFromDatabase() async {
    if (mounted) {
      setState(() {
        _isDataLoading = true;
      });
    }

    try {
      final transactions = await DatabaseHelper.instance.getAllTransactions(widget.currentUser.id);
      final budgets = await DatabaseHelper.instance.getAllBudgets(widget.currentUser.id);
      setState(() {
        _transactions = transactions;
        _budgets = budgets;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    }
    finally {
      // Set loading to false when done, regardless of success or error
      if (mounted) {
        setState(() {
          _isDataLoading = false;
        });
      }
    }
  }


  Future<void> _pickProfilePhoto() async {
    final picker = ImagePicker();
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Image Source'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, ImageSource.camera),
            child: const Text('Camera'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, ImageSource.gallery),
            child: const Text('Gallery'),
          ),
        ],
      ),
    );

    if (source != null) {
      try {
        final pickedFile = await picker.pickImage(source: source);
        if (pickedFile != null && pickedFile.path.isNotEmpty) {
          // Check if file exists
          final file = File(pickedFile.path);
          if (await file.exists()) {
            print('Selected image path: ${pickedFile.path}');  // Debug
            // Save path to database
            await DatabaseHelper.instance.updateUserProfilePhoto(widget.currentUser.id, pickedFile.path);
            print('Database updated');  // Debug
            // Create a new User object with updated photo
            final updatedUser = User(
              id: widget.currentUser.id,
              username: widget.currentUser.username,
              email: widget.currentUser.email,
              password: widget.currentUser.password,
              profilePhoto: pickedFile.path,
            );
            // Update the parent widget's currentUser via callback
            widget.onUserChanged(updatedUser);
            print('User updated in state');  // Debug
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Profile photo updated')),
            );
          } else {
            print('File does not exist: ${pickedFile.path}');  // Debug
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Selected file is invalid')),
            );
          }
        } else {
          print('No file selected or path is empty');  // Debug
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No image selected')),
          );
        }
      } catch (e) {
        print('Error picking or saving photo: $e');  // Debug
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating photo: $e')),
        );
      }
    }
  }


  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      _searchQuery = ''; // reset search when switching tabs
      _filteredTransactions.clear(); // reset date filter
    });
  }

  double _convertAmount(double amount) {
    if (widget.exchangeRates.isEmpty) return amount;  // Fallback if no rates
    try {
      return CurrencyService.convertAmount(amount, 'INR', widget.selectedCurrency, widget.exchangeRates);
    } catch (e) {
      print('Conversion error: $e');
      return amount;
    }
  }

  double get _totalIncome {
    return _transactions
        .where((t) => t.type == TransactionType.income && !t.isSaving)
        .fold(0.0, (sum, item) => sum + _convertAmount(item.amount));
  }


  double get _totalExpense {
    return _transactions
        .where((t) => t.type == TransactionType.expense && !t.isSaving)
        .fold(0.0, (sum, item) => sum + _convertAmount(item.amount));
  }


  List<Transaction> get _filteredTransactionsByQuery {
    final query = _searchQuery.toLowerCase();

    final List<Transaction> baseList;
    if (_isDateFilterActive) {
      baseList = _filteredTransactions; // Use the (possibly empty) date-filtered list
    } else {
      baseList = _transactions; // Use the full list
    }


    if (_searchQuery.isEmpty) {
      return baseList;
    }
    return baseList.where((t) {
      final dateStr = DateFormat('yyyy-MM-dd').format(t.date).toLowerCase();
      final dateStrAlt = DateFormat('MMM dd').format(t.date).toLowerCase();
      return t.title.toLowerCase().contains(query) ||
          t.category.toLowerCase().contains(query) ||
          dateStr.contains(query) ||
          dateStrAlt.contains(query);
    }).toList();
  }

  double _getSpentForCategory(String category) {
    return _transactions
        .where((t) => t.category == category && t.type == TransactionType.expense)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  void _logout() {
    try {
      // Clear local data to prevent memory leaks or stale data
      setState(() {
        _transactions.clear();
        _budgets.clear();
        _searchQuery = '';
        _selectedIndex = 0;
        _filteredTransactions.clear();
      });

      // Show confirmation
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Logged out successfully'),
          duration: Duration(seconds: 2),
        ),
      );

      // Call global logout to clear user state and persisted data
      widget.onLogout();

      // Safely close drawer if open
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop(); // Close drawer
      }

      // No manual navigation; rely on state rebuild in AppWrapper
    } catch (e) {
      print('Logout error: $e'); // Debug
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Logout error: $e')),
      );
    }
  }

  // Helper to get currency symbol
  String get _currencySymbol {
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
        return '\$'; // USD
    }
  }

  void _searchByDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (pickedDate != null) {
      setState(() {
        _searchQuery = '';
        _filteredTransactions = _transactions.where((t) {
          return t.date.year == pickedDate.year &&
              t.date.month == pickedDate.month &&
              t.date.day == pickedDate.day;
        }).toList();
        _isDateFilterActive = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Showing transactions for ${DateFormat('yyyy-MM-dd').format(pickedDate)}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: _buildDrawer(),
      appBar: AppBar(
        title: Text(_getAppBarTitle()),
        backgroundColor:
        widget.isDarkTheme ? Colors.grey[900] : Colors.blue[700],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: _selectedIndex == 1
            ? [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              showSearch(
                context: context,
                delegate: TransactionSearchDelegate(
                  transactions: _transactions,
                  currencySymbol: _currencySymbol,
                  onSelected: (transaction) {
                    // Optional: Handle selection
                  },
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () => _searchByDate(),
          ),
        ]
            : [],
      ),
      body: _isDataLoading
          ? const Center(child: CircularProgressIndicator())
          : _selectedIndex == 0
          ? _buildDashboard()
          : _selectedIndex == 1
          ? _buildTransactions()
          : _selectedIndex == 2
          ? _buildBudgets()
          : _selectedIndex == 3
          ? AnalysisPage(
              isDarkTheme: widget.isDarkTheme,
              userId: widget.currentUser.id,
              selectedCurrency: widget.selectedCurrency,
              exchangeRates: widget.exchangeRates,
            )
          : _buildProfile(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_selectedIndex == 2) {
            _showAddBudgetDialog(context);
          } else {
            _showAddTransactionDialog(context);
          }
        },
        backgroundColor:
        widget.isDarkTheme ? Colors.blue[300] : Colors.blue[700],
        child: Icon(
          _selectedIndex == 2 ? Icons.add_chart : Icons.add,
          color: Colors.white,
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list),
            label: 'Transactions',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet),
            label: 'Budgets',
          ),
          BottomNavigationBarItem(  // New tab
            icon: Icon(Icons.analytics),
            label: 'Analysis',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),

        ],
        currentIndex: _selectedIndex,
        selectedItemColor:
        widget.isDarkTheme ? Colors.blue[300] : Colors.blue[700],
        unselectedItemColor:
        widget.isDarkTheme ? Colors.grey[400] : Colors.grey,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        backgroundColor: widget.isDarkTheme ? Colors.grey[850] : Colors.white,
      ),
    );
  }

  String _getAppBarTitle() {
    switch (_selectedIndex) {
      case 0:
        return 'MyMoney';
      case 1:
        return 'Transactions';
      case 2:
        return 'Budgets';
      case 3:
        return 'Analysis';
      case 4:
        return 'Profile';
      default:
        return 'MyMoney';
    }
  }

  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(
              color: widget.isDarkTheme ? Colors.grey[900] : Colors.blue[700],
            ),
            accountName: Text(widget.currentUser.username),
            accountEmail: Text(widget.currentUser.email),
            currentAccountPicture: CircleAvatar(
              backgroundColor:
              widget.isDarkTheme ? Colors.blue[300] : Colors.white,
              child: const Icon(
                Icons.person,
                size: 50,
                color: Colors.blue,
              ),
            ),
          ),
          SwitchListTile(
            title: const Text('Dark Theme'),
            secondary: Icon(
              widget.isDarkTheme ? Icons.dark_mode : Icons.light_mode,
              color: widget.isDarkTheme ? Colors.blue[300] : Colors.orange,
            ),
            value: widget.isDarkTheme,
            onChanged: (bool value) {
              widget.onThemeChanged(value);
              Navigator.pop(context); // close drawer
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Settings'),
            onTap: () {
              Navigator.pop(context); // Close drawer
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SettingsPage(
                    selectedCurrency: widget.selectedCurrency,
                    onCurrencyChanged: widget.onCurrencyChanged,
                    isDarkTheme: widget.isDarkTheme,
                    userId: widget.currentUser.id,
                    onDataReset: _loadDataFromDatabase,
                    onAccountDeleted: _onAccountDeleted,
                  ),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('About'),
            onTap: () {
              Navigator.pop(context); // Close drawer
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AboutPage(
                    isDarkTheme: widget.isDarkTheme,
                  ),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.upload_file),
            title: const Text('Import Data'),
            onTap: () {
              Navigator.pop(context); // Close drawer
              _showImportFormatDialog();
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.exit_to_app),
            title: const Text('Logout'),
            onTap: () {
              Navigator.pop(context); // Close drawer first
              _logout(); // Call the enhanced logout
            },
          ),
        ],
      ),
    );
  }

  // Add back the format dialog
  void _showImportFormatDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import CSV Format'),
        content: const Text(
          'Upload a CSV file with the following format:\n\n'
              'For Transactions:\n'
              'title,amount,date,category,type\n'
              'Example: "Lunch,15.50,2023-10-01,Food,expense"\n\n'
              'For Budgets:\n'
              'category,allocated,spent\n'
              'Example: "Food,200,50"\n\n'
              'Note: First row is header, type is "income" or "expense".',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(onPressed: () {
            Navigator.pop(context);
            _importData();
          }, child: const Text('Select File')),
        ],
      ),
    );
  }

// Update _importData to use file_selector
  void _importData() async {
    const XTypeGroup typeGroup = XTypeGroup(
      label: 'CSV files',
      extensions: ['csv'],
    );

    final XFile? file = await openFile(acceptedTypeGroups: [typeGroup]);

    if (file != null) {
      try {
        final input = await file.readAsString();
        final fields = const CsvToListConverter().convert(input);
        int importedTransactions = 0;
        int importedBudgets = 0;

        for (var row in fields.skip(1)) { // Skip header
          if (row.length >= 5) {
            // Transaction: title,amount,date,category,type
            final amount = double.tryParse(row[1].toString());
            final date = DateTime.tryParse(row[2].toString());
            if (amount != null && date != null) {
              final transaction = Transaction(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                title: row[0].toString(),
                amount: amount,
                date: date,
                category: row[3].toString(),
                type: row[4].toString().toLowerCase() == 'income' ? TransactionType.income : TransactionType.expense,
              );
              await DatabaseHelper.instance.insertTransaction(transaction, widget.currentUser.id);
              importedTransactions++;
            }
          } else if (row.length >= 3) {
            // Budget: category,allocated,spent
            final allocated = double.tryParse(row[1].toString());
            final spent = double.tryParse(row[2].toString());
            if (allocated != null && spent != null) {
              final budget = Budget(
                category: row[0].toString(),
                allocated: allocated,
                spent: spent,
              );
              await DatabaseHelper.instance.insertBudget(budget, widget.currentUser.id);
              importedBudgets++;
            }
          }
        }

        // Reload data
        await _loadDataFromDatabase();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Imported $importedTransactions transactions and $importedBudgets budgets')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error importing data: $e')),
        );
      }
    }
  }

  void _showPlaceholderDialog(String title) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text('$title page is not implemented yet.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          )
        ],
      ),
    );
  }

  Widget _buildDashboard() {
    final double balance = _totalIncome - _totalExpense;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Balance Card
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Current Balance',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_currencySymbol}${balance.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildIncomeExpenseTile(
                        'Income',
                        _totalIncome,
                      ),
                      _buildIncomeExpenseTile(
                        'Expense',
                        _totalExpense,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Recent Transactions
          const Text(
            'Recent Transactions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          if (_transactions.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(
                child: Text('No transactions added yet.'),
              ),
            )
          else
            ..._transactions
                .take(3)
                .map((transaction) => _buildTransactionItem(transaction))
                .toList(),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                setState(() {
                  _selectedIndex = 1;
                });
              },
              child: const Text('View All'),
            ),
          ),
          const SizedBox(height: 24),
          // Budget Overview
          const Text(
            'Budget Overview',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          if (_budgets.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(
                child: Text('No budgets set yet.'),
              ),
            )
          else
            ..._budgets.map((budget) {
              final spent = _getSpentForCategory(budget.category);
              return _buildBudgetItemWithSpent(budget, spent);
            }).toList(),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                setState(() {
                  _selectedIndex = 2;
                });
              },
              child: const Text('View All'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIncomeExpenseTile(String title, double amount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${_currencySymbol}${amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: title == 'Income' ? Colors.green : Colors.red,
          ),
        ),
      ],
    );
  }

  Widget _buildTransactions() {
    final transactionsToShow = _filteredTransactionsByQuery.where((t) => !t.isSaving).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    labelText: 'Search transactions (title, category, date)',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
              ),
              if (_filteredTransactions.isNotEmpty || _searchQuery.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    setState(() {
                      _filteredTransactions.clear();
                      _searchQuery = '';
                      _isDateFilterActive = false;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Filter cleared')),
                    );
                  },
                ),
            ],
          ),
        ),
        Expanded(
          child: transactionsToShow.isEmpty
              ? const Center(
            child: Text('No transactions found.'),
          )
              : ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: transactionsToShow.length,
            itemBuilder: (context, index) {
              return _buildTransactionItem(transactionsToShow[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionItem(Transaction transaction) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: transaction.type == TransactionType.income
                ? Colors.green[100]
                : Colors.red[100],
            shape: BoxShape.circle,
          ),
          child: Icon(
            transaction.type == TransactionType.income
                ? Icons.arrow_upward
                : Icons.arrow_downward,
            color: transaction.type == TransactionType.income
                ? Colors.green
                : Colors.red,
            size: 20,
          ),
        ),
        title: Text(
          transaction.title,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          '${transaction.category} • ${DateFormat('MMM dd').format(transaction.date)}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${_currencySymbol}${_convertAmount(transaction.amount).toStringAsFixed(2)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: transaction.type == TransactionType.income
                    ? Colors.green
                    : Colors.red,
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') {
                  _editTransaction(transaction);
                } else if (value == 'delete') {
                  _deleteTransaction(transaction);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Text('Edit'),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _editTransaction(Transaction transaction) {
    final titleController = TextEditingController(text: transaction.title);
    final amountController = TextEditingController(text: transaction.amount.toString());
    String selectedCategory = transaction.category;
    TransactionType selectedType = transaction.type;
    DateTime selectedDate = transaction.date;

    showDialog(
      context: context,
      builder: (BuildContext outerContext) {
        return StatefulBuilder(builder: (BuildContext dialogContext, StateSetter setStateDialog) {
          return AlertDialog(
            title: const Text('Edit Transaction'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: amountController,
                    decoration: InputDecoration(
                      labelText: 'Amount (${_currencySymbol})',
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedCategory,
                    items: _categories
                        .map((category) => DropdownMenuItem(
                      value: category,
                      child: Text(category),
                    ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setStateDialog(() {
                          selectedCategory = value;
                        });
                      }
                    },
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Expanded(child: Text('Date: ')),
                      Expanded(
                        flex: 3,
                        child: TextButton(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: dialogContext,
                              initialDate: selectedDate,
                              firstDate: DateTime(2000),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (picked != null) {
                              setStateDialog(() {
                                selectedDate = picked;
                              });
                            }
                          },
                          child: Text(DateFormat('yyyy-MM-dd').format(selectedDate)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: RadioListTile<TransactionType>(
                          title: const Text('Income'),
                          value: TransactionType.income,
                          groupValue: selectedType,
                          onChanged: (value) {
                            if (value != null) {
                              setStateDialog(() {
                                selectedType = value;
                              });
                            }
                          },
                        ),
                      ),
                      Expanded(
                        child: RadioListTile<TransactionType>(
                          title: const Text('Expense'),
                          value: TransactionType.expense,
                          groupValue: selectedType,
                          onChanged: (value) {
                            if (value != null) {
                              setStateDialog(() {
                                selectedType = value;
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(outerContext).pop();
                },
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final title = titleController.text.trim();
                  final amountText = amountController.text.trim();
                  if (title.isEmpty || amountText.isEmpty) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(
                        content: Text('Please enter title and amount'),
                      ),
                    );
                    return;
                  }
                  final amount = double.tryParse(amountText);
                  if (amount == null || amount <= 0) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(
                        content: Text('Please enter a valid positive amount'),
                      ),
                    );
                    return;
                  }

                  final updatedTransaction = Transaction(
                    id: transaction.id, // Keep same ID
                    title: title,
                    amount: amount,
                    date: selectedDate,
                    category: selectedCategory,
                    type: selectedType,
                  );

                  try {
                    await DatabaseHelper.instance.updateTransaction(updatedTransaction, widget.currentUser.id);
                    setState(() {
                      final index = _transactions.indexWhere((t) => t.id == transaction.id);
                      if (index != -1) {
                        _transactions[index] = updatedTransaction;
                      }
                    });
                    Navigator.of(outerContext).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Transaction updated')),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(outerContext).showSnackBar(
                      SnackBar(content: Text('Error updating transaction: $e')),
                    );
                  }
                },
                child: const Text('Save'),
              ),
            ],
          );
        });
      },
    );
  }

  void _deleteTransaction(Transaction transaction) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Transaction'),
        content: const Text('Are you sure you want to delete this transaction?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await DatabaseHelper.instance.deleteTransaction(transaction.id, widget.currentUser.id);
                setState(() {
                  _transactions.removeWhere((t) => t.id == transaction.id);
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Transaction deleted')),
                );
              } catch (e) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error deleting transaction: $e')),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _buildBudgets() {
    return Column(
      children: [
        Expanded(
          child: _budgets.isEmpty
              ? const Center(child: Text('No budgets set yet.'))
              : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _budgets.length,
            itemBuilder: (context, index) {
              final budget = _budgets[index];
              final spent = _getSpentForCategory(budget.category);
              return _buildBudgetItemWithSpent(budget, spent);
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Add Budget / Category'),
            onPressed: () {
              _showAddBudgetDialog(context);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBudgetItemWithSpent(Budget budget, double spent) {
    final double progress = budget.allocated > 0 ? spent / budget.allocated : 0;
    final Color progressColor = progress > 0.9
        ? Colors.red
        : progress > 0.7
        ? Colors.orange
        : Colors.green;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  budget.category,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                _buildBudgetItemActions(budget), // New: Actions for modify/delete
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progress > 1 ? 1 : progress,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 8),
            Text(
              '${_currencySymbol}${_convertAmount(spent).toStringAsFixed(2)} spent of ${_currencySymbol}${_convertAmount(budget.allocated).toStringAsFixed(2)} (${(progress * 100).toStringAsFixed(0)}%)',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // New: Budget actions (Modify/Delete)
  Widget _buildBudgetItemActions(Budget budget) {
    return PopupMenuButton<String>(
      onSelected: (value) {
        if (value == 'modify') {
          _showAddBudgetDialog(context, budget: budget);
        } else if (value == 'delete') {
          _deleteBudget(budget);
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'modify',
          child: Text('Modify Budget'),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: Text('Delete Budget'),
        ),
      ],
    );
  }

  void _deleteBudget(Budget budget) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Budget'),
        content: Text('Are you sure you want to delete the budget for ${budget.category}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await DatabaseHelper.instance.deleteBudget(budget.category, widget.currentUser.id);
                setState(() {
                  _budgets.removeWhere((b) => b.category == budget.category);
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${budget.category} budget deleted')),
                );
              } catch (e) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error deleting budget: $e')),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _onAccountDeleted() {
    // Perform any necessary local cleanup before logging out
    setState(() {
      _transactions.clear();
      _budgets.clear();
      _searchQuery = '';
      _selectedIndex = 0;
      _filteredTransactions.clear();
    });
    // Call the global logout function to clear SharedPreferences and navigate
    widget.onLogout();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Account successfully deleted.'),
        duration: Duration(seconds: 3),
      ),
    );
  }


  Widget _buildProfile() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GestureDetector(  // Make avatar clickable
            onTap: _pickProfilePhoto,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: widget.isDarkTheme ? Colors.blue[300] : Colors.blue[100],
                shape: BoxShape.circle,  // Ensures round shape
                image: widget.currentUser.profilePhoto != null
                    ? DecorationImage(
                  image: FileImage(File(widget.currentUser.profilePhoto!)),
                  fit: BoxFit.cover,  // Covers the circle fully
                )
                    : null,
              ),
              child: widget.currentUser.profilePhoto == null
                  ? Icon(
                Icons.person,
                size: 60,
                color: widget.isDarkTheme ? Colors.white : Colors.blue,
              )
                  : null,  // No child if photo is present
            ),
          ),
          const SizedBox(height: 24),
          Text(
            widget.currentUser.username,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.currentUser.email,
            style: TextStyle(
              fontSize: 16,
              color: widget.isDarkTheme ? Colors.grey[300] : Colors.grey[600],
            ),
          ),
          _buildProfileOption(Icons.lock, 'Change Password', onTap: _showChangePasswordDialog),
          _buildProfileOption(Icons.savings, 'Saving', onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SavingsPage(
                  isDarkTheme: widget.isDarkTheme,
                  userId: widget.currentUser.id,
                  selectedCurrency: widget.selectedCurrency,
                  exchangeRates: widget.exchangeRates,

                ),
              ),
            );
          }),
          _buildProfileOption(Icons.settings, 'Settings', onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SettingsPage(
                  selectedCurrency: widget.selectedCurrency,
                  onCurrencyChanged: widget.onCurrencyChanged,
                  isDarkTheme: widget.isDarkTheme,
                  userId: widget.currentUser.id,
                  onDataReset: _loadDataFromDatabase,
                  onAccountDeleted: _onAccountDeleted,
                ),
              ),
            );
          }),
          _buildProfileOption(Icons.help, 'Help & Support', onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => HelpSupportPage(
                  isDarkTheme: widget.isDarkTheme,
                ),
              ),
            );
          }),
          _buildProfileOption(Icons.exit_to_app, 'Logout', onTap: _logout),
        ],
      ),
    );
  }


  Widget _buildProfileOption(IconData icon, String title, {VoidCallback? onTap}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Card(
        elevation: 1,
        child: ListTile(
          leading: Icon(icon, color: Colors.blue),
          title: Text(title),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: onTap ?? () {
            _showPlaceholderDialog(title);
          },
        ),
      ),
    );
  }

  void _showChangePasswordDialog() {
    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,  // Allows full height if needed
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),  // Rounded top corners
      ),
      builder: (BuildContext bottomSheetContext) {
        bool isOldPasswordVisible = false;
        bool isNewPasswordVisible = false;
        bool isConfirmPasswordVisible = false;

        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setStateDialog) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,  // Keyboard adjustment
                left: 16,
                right: 16,
                top: 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,  // Shrink to fit content
                children: [
                  // Title
                  const Text(
                    'Change Password',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  // Scrollable content
                  SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: oldPasswordController,
                          decoration: InputDecoration(
                            labelText: 'Current Password',
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: Icon(
                                isOldPasswordVisible ? Icons.visibility : Icons.visibility_off,
                              ),
                              onPressed: () {
                                setStateDialog(() {
                                  isOldPasswordVisible = !isOldPasswordVisible;
                                });
                              },
                            ),
                          ),
                          obscureText: !isOldPasswordVisible,
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: newPasswordController,
                          decoration: InputDecoration(
                            labelText: 'New Password',
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: Icon(
                                isNewPasswordVisible ? Icons.visibility : Icons.visibility_off,
                              ),
                              onPressed: () {
                                setStateDialog(() {
                                  isNewPasswordVisible = !isNewPasswordVisible;
                                });
                              },
                            ),
                          ),
                          obscureText: !isNewPasswordVisible,
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: confirmPasswordController,
                          decoration: InputDecoration(
                            labelText: 'Confirm New Password',
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: Icon(
                                isConfirmPasswordVisible ? Icons.visibility : Icons.visibility_off,
                              ),
                              onPressed: () {
                                setStateDialog(() {
                                  isConfirmPasswordVisible = !isConfirmPasswordVisible;
                                });
                              },
                            ),
                          ),
                          obscureText: !isConfirmPasswordVisible,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () {
                          Navigator.of(bottomSheetContext).pop();
                        },
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () async {
                          final oldPassword = oldPasswordController.text.trim();
                          final newPassword = newPasswordController.text.trim();
                          final confirmPassword = confirmPasswordController.text.trim();

                          if (oldPassword.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty) {
                            // Use showDialog for errors
                            showDialog(
                              context: bottomSheetContext,
                              builder: (context) => AlertDialog(
                                title: const Text('Error'),
                                content: const Text('Please fill all fields'),
                                actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
                              ),
                            );
                            return;
                          }

                          if (newPassword != confirmPassword) {
                            // Use showDialog for errors
                            showDialog(
                              context: bottomSheetContext,
                              builder: (context) => AlertDialog(
                                title: const Text('Error'),
                                content: const Text('New passwords do not match'),
                                actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
                              ),
                            );
                            return;
                          }

                          if (newPassword.length < 6) {
                            // Use showDialog for errors
                            showDialog(
                              context: bottomSheetContext,
                              builder: (context) => AlertDialog(
                                title: const Text('Error'),
                                content: const Text('New password must be at least 6 characters'),
                                actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
                              ),
                            );
                            return;
                          }

                          try {
                            // Verify old password
                            final user = await DatabaseHelper.instance.loginUser(widget.currentUser.email, oldPassword);
                            if (user == null) {
                              // Use showDialog for errors
                              showDialog(
                                context: bottomSheetContext,
                                builder: (context) => AlertDialog(
                                  title: const Text('Error'),
                                  content: const Text('Current password is incorrect'),
                                  actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
                                ),
                              );
                              return;
                            }

                            // Update password
                            final hashedNewPassword = DatabaseHelper.instance.hashPassword(newPassword);
                            await DatabaseHelper.instance.updateUserPassword(widget.currentUser.id, hashedNewPassword);

                            // Close bottom sheet first, then show success dialog
                            Navigator.of(bottomSheetContext).pop();
                            showDialog(
                              context: context,  // Main context
                              builder: (context) => AlertDialog(
                                title: const Text('Success'),
                                content: const Text('Password changed successfully'),
                                actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
                              ),
                            );
                          } catch (e) {
                            // Use showDialog for errors
                            showDialog(
                              context: bottomSheetContext,
                              builder: (context) => AlertDialog(
                                title: const Text('Error'),
                                content: Text('Error changing password: $e'),
                                actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
                              ),
                            );
                          }
                        },
                        child: const Text('Change'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),  // Bottom padding
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showAddTransactionDialog(BuildContext context) {
    final titleController = TextEditingController();
    final amountController = TextEditingController();
    String selectedCategory = _categories.isNotEmpty ? _categories.first : 'Other';
    TransactionType selectedType = TransactionType.expense;
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (BuildContext outerContext) {
        return StatefulBuilder(builder: (BuildContext dialogContext, StateSetter setStateDialog) {
          return AlertDialog(
            title: const Text('Add New Transaction'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: amountController,
                    decoration: InputDecoration(
                      labelText: 'Amount (${_currencySymbol})',
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedCategory,
                    items: _categories
                        .map((category) => DropdownMenuItem(
                      value: category,
                      child: Text(category),
                    ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setStateDialog(() {
                          selectedCategory = value;
                        });
                      }
                    },
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Expanded(child: Text('Date: ')),
                      Expanded(
                        flex: 3,
                        child: TextButton(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: dialogContext,
                              initialDate: selectedDate,
                              firstDate: DateTime(2000),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (picked != null) {
                              setStateDialog(() {
                                selectedDate = picked;
                              });
                            }
                          },
                          child: Text(DateFormat('yyyy-MM-dd').format(selectedDate)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: RadioListTile<TransactionType>(
                          title: const Text('Income'),
                          value: TransactionType.income,
                          groupValue: selectedType,
                          onChanged: (value) {
                            if (value != null) {
                              setStateDialog(() {
                                selectedType = value;
                              });
                            }
                          },
                        ),
                      ),
                      Expanded(
                        child: RadioListTile<TransactionType>(
                          title: const Text('Expense'),
                          value: TransactionType.expense,
                          groupValue: selectedType,
                          onChanged: (value) {
                            if (value != null) {
                              setStateDialog(() {
                                selectedType = value;
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(outerContext).pop();
                },
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final title = titleController.text.trim();
                  final amountText = amountController.text.trim();
                  if (title.isEmpty || amountText.isEmpty) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(
                        content: Text('Please enter title and amount'),
                      ),
                    );
                    return;
                  }
                  final amount = double.tryParse(amountText);
                  if (amount == null || amount <= 0) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(
                        content: Text('Please enter a valid positive amount'),
                      ),
                    );
                    return;
                  }


                  final newTransaction = Transaction(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    title: title,
                    amount: amount,
                    date: selectedDate,
                    category: selectedCategory,
                    type: selectedType,
                  );

                  try {
                    await DatabaseHelper.instance.insertTransaction(newTransaction, widget.currentUser.id);
                    setState(() {
                      _transactions.insert(0, newTransaction);
                    });
                    Navigator.of(outerContext).pop();
                  } catch (e) {
                    ScaffoldMessenger.of(outerContext).showSnackBar(
                      SnackBar(content: Text('Error saving transaction: $e')),
                    );
                  }
                },
                child: const Text('Add'),
              ),
            ],
          );
        });
      },
    );
  }

  void _showAddBudgetDialog(BuildContext context, {Budget? budget}) { // Added optional Budget parameter
    final budgetController = TextEditingController(text: budget?.allocated.toString() ?? '');
    String selectedCategory = budget?.category ?? (_categories.isNotEmpty ? _categories.first : 'Other');
    final newCategoryController = TextEditingController();
    bool isAddingNewCategory = budget == null ? false : false; // Can't add new category when modifying existing

    if (budget != null) {
      // Ensure the budget category is in the list for editing dropdown
      if (!_categories.contains(budget.category)) {
        selectedCategory = _categories.isNotEmpty ? _categories.first : 'Other';
      }
    }

    showDialog(
      context: context,
      builder: (BuildContext outerContext) {
        return StatefulBuilder(builder: (BuildContext dialogContext, StateSetter setStateDialog) {
          return AlertDialog(
            title: Text(budget == null ? 'Add New Budget' : 'Edit Budget: ${budget.category}'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isAddingNewCategory)
                    DropdownButtonFormField<String>(
                      value: selectedCategory,
                      items: _categories
                          .map((category) => DropdownMenuItem(
                        value: category,
                        child: Text(category),
                      ))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setStateDialog(() {
                            selectedCategory = value;
                          });
                        }
                      },
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  if (isAddingNewCategory)
                    TextField(
                      controller: newCategoryController,
                      decoration: const InputDecoration(
                        labelText: 'New Category',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: budgetController,
                    decoration: InputDecoration(
                      labelText: 'Budget Amount (${_currencySymbol})',
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 16),
                  if (budget == null) // Only allow adding new categories when adding a new budget
                    TextButton.icon(
                      icon: Icon(isAddingNewCategory ? Icons.cancel : Icons.add),
                      label: Text(isAddingNewCategory
                          ? 'Cancel New Category'
                          : 'Add New Category'),
                      onPressed: () {
                        setStateDialog(() {
                          isAddingNewCategory = !isAddingNewCategory;
                          if (!isAddingNewCategory) {
                            newCategoryController.clear();
                          }
                        });
                      },
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(outerContext).pop();
                },
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  String categoryToUse = selectedCategory;
                  if (isAddingNewCategory) {
                    final newCat = newCategoryController.text.trim();
                    if (newCat.isEmpty) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter a category name'),
                        ),
                      );
                      return;
                    }
                    if (!_categories.contains(newCat)) {
                      setState(() {
                        _categories.add(newCat);
                      });
                    }
                    categoryToUse = newCat;
                  }

                  final budgetText = budgetController.text.trim();
                  if (budgetText.isEmpty) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(
                        content: Text('Please enter budget amount'),
                      ),
                    );
                    return;
                  }
                  final budgetAmount = double.tryParse(budgetText);
                  if (budgetAmount == null || budgetAmount <= 0) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(
                        content: Text('Please enter a valid positive amount'),
                      ),
                    );
                    return;
                  }

                  final newBudget = Budget(
                    category: categoryToUse,
                    allocated: budgetAmount,
                    spent: 0, // spent is calculated dynamically
                  );

                  try {
                    final existingBudgetIndex = _budgets.indexWhere(
                            (b) => b.category == categoryToUse);
                    if (existingBudgetIndex >= 0) {
                      // Update existing budget
                      await DatabaseHelper.instance.updateBudget(newBudget, widget.currentUser.id);
                      setState(() {
                        _budgets[existingBudgetIndex] = newBudget;
                      });
                    } else {
                      // Add new budget
                      await DatabaseHelper.instance.insertBudget(newBudget, widget.currentUser.id);
                      setState(() {
                        _budgets.add(newBudget);
                      });
                    }
                    Navigator.of(outerContext).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Budget for $categoryToUse saved')),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(outerContext).showSnackBar(
                      SnackBar(content: Text('Error saving budget: $e')),
                    );
                  }
                },
                child: const Text('Save'),
              ),
            ],
          );
        });
      },
    );
  }
}


/// Search Delegate for Transactions
class TransactionSearchDelegate extends SearchDelegate<Transaction?> {
  final List<Transaction> transactions;
  final String currencySymbol;
  final ValueChanged<Transaction> onSelected;

  TransactionSearchDelegate({
    required this.transactions,
    required this.currencySymbol,
    required this.onSelected,
  });

  @override
  String get searchFieldLabel => 'Search transactions (title, category, date)';

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () {
            query = '';
            showSuggestions(context);
          },
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    final results = transactions.where((t) {
      final q = query.toLowerCase();
      final dateStr = DateFormat('yyyy-MM-dd').format(t.date).toLowerCase();
      final dateStrAlt = DateFormat('MMM dd').format(t.date).toLowerCase();
      return t.title.toLowerCase().contains(q) ||
          t.category.toLowerCase().contains(q) ||
          dateStr.contains(q) ||
          dateStrAlt.contains(q);
    }).toList();

    if (results.isEmpty) {
      return const Center(
        child: Text('No transactions found.'),
      );
    }

    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        final transaction = results[index];
        return ListTile(
          leading: Icon(
            transaction.type == TransactionType.income
                ? Icons.arrow_upward
                : Icons.arrow_downward,
            color: transaction.type == TransactionType.income
                ? Colors.green
                : Colors.red,
          ),
          title: Text(transaction.title),
          subtitle: Text(
              '${transaction.category} • ${DateFormat('MMM dd, yyyy').format(transaction.date)}'),
          trailing: Text(
            '${currencySymbol}${transaction.amount.toStringAsFixed(2)}',
            style: TextStyle(
              color: transaction.type == TransactionType.income
                  ? Colors.green
                  : Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
          onTap: () {
            onSelected(transaction);
            close(context, transaction);
          },
        );
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final suggestions = transactions.where((t) {
      final q = query.toLowerCase();
      final dateStr = DateFormat('yyyy-MM-dd').format(t.date).toLowerCase();
      final dateStrAlt = DateFormat('MMM dd').format(t.date).toLowerCase();
      return t.title.toLowerCase().contains(q) ||
          t.category.toLowerCase().contains(q) ||
          dateStr.contains(q) ||
          dateStrAlt.contains(q);
    }).toList();

    return ListView.builder(
      itemCount: suggestions.length,
      itemBuilder: (context, index) {
        final transaction = suggestions[index];
        return ListTile(
          leading: Icon(
            transaction.type == TransactionType.income
                ? Icons.arrow_upward
                : Icons.arrow_downward,
            color: transaction.type == TransactionType.income
                ? Colors.green
                : Colors.red,
          ),
          title: Text(transaction.title),
          subtitle: Text(
              '${transaction.category} • ${DateFormat('MMM dd, yyyy').format(transaction.date)}'),
          trailing: Text(
            '${currencySymbol}${transaction.amount.toStringAsFixed(2)}',
            style: TextStyle(
              color: transaction.type == TransactionType.income
                  ? Colors.green
                  : Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
          onTap: () {
            onSelected(transaction);
            close(context, transaction);
          },
        );
      },
    );
  }
}