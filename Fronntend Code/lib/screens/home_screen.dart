import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import 'analysis_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _tickerController = TextEditingController();
  final _authService = AuthService();
  final _apiService = ApiService();
  String _selectedPeriod = "1mo";
  List<Map<String, dynamic>> _searchHistory = [];
  bool _isLoading = false;

  final List<String> _periods = ["1mo", "3mo", "6mo", "1y"];

  final List<Map<String, String>> _popularStocks = [
    {"ticker": "AAPL", "name": "Apple"},
    {"ticker": "TSLA", "name": "Tesla"},
    {"ticker": "GOOGL", "name": "Google"},
    {"ticker": "RELIANCE.NS", "name": "Reliance"},
    {"ticker": "ADANIPOWER.NS", "name": "Adani Power"},
    {"ticker": "TATAMOTORS.NS", "name": "Tata Motors"},
  ];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final history = await _apiService.getSearchHistory();
    setState(() => _searchHistory = history);
  }

  void _clearSearchUI() {
    setState(() {
      _searchHistory = [];
      _tickerController.clear();
    });
  }

  Future<void> _analyzeStock(String ticker) async {
    setState(() => _isLoading = true);
    try {
      final result = await _apiService.analyzeStock(ticker, _selectedPeriod);
      final news = await _apiService.getStockNews(ticker);
      await _loadHistory();

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AnalysisScreen(
              ticker: ticker,
              analysis: result["analysis"],
              news: news["news"] ?? [],
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1D1E33),
        title: Row(
          children: [
            const Icon(Icons.candlestick_chart, color: Color(0xFF4CAF50)),
            const SizedBox(width: 8),
            Text(
              "FinanceAI",
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.grey),
            onPressed: () => _authService.logout(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search Section
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF1D1E33),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Analyze Any Stock",
                    style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Powered by AI — supports US & Indian stocks",
                    style: GoogleFonts.inter(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: _tickerController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: "Enter ticker (e.g. AAPL, RELIANCE.NS)",
                            hintStyle: const TextStyle(color: Colors.grey),
                            prefixIcon: const Icon(
                              Icons.search,
                              color: Colors.grey,
                            ),
                            filled: true,
                            fillColor: const Color(0xFF0A0E21),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedPeriod,
                          dropdownColor: const Color(0xFF1D1E33),
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: const Color(0xFF0A0E21),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          items: _periods
                              .map(
                                (p) =>
                                    DropdownMenuItem(value: p, child: Text(p)),
                              )
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _selectedPeriod = v!),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isLoading
                              ? null
                              : () => _analyzeStock(
                                  _tickerController.text.trim().toUpperCase(),
                                ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4CAF50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(
                                  color: Colors.white,
                                )
                              : const Text(
                                  "Analyze",
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Popular Stocks
            Text(
              "Popular Stocks",
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _popularStocks
                  .map(
                    (stock) => GestureDetector(
                      onTap: () => _analyzeStock(stock["ticker"]!),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1D1E33),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color(0xFF4CAF50).withOpacity(0.3),
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              stock["ticker"]!,
                              style: GoogleFonts.inter(
                                color: const Color(0xFF4CAF50),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              stock["name"]!,
                              style: GoogleFonts.inter(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 24),

            // Search History
            if (_searchHistory.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Recent Searches",
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _clearSearchUI,
                    icon: const Icon(Icons.clear_all, color: Colors.grey),
                    label: Text(
                      "Clear",
                      style: GoogleFonts.inter(color: Colors.grey),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ..._searchHistory.map(
                (search) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1D1E33),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        search["ticker"],
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        search["timestamp"].toString().substring(0, 10),
                        style: GoogleFonts.inter(color: Colors.grey),
                      ),
                      ElevatedButton(
                        onPressed: () => _analyzeStock(search["ticker"]),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4CAF50),
                        ),
                        child: const Text("Re-analyze"),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
