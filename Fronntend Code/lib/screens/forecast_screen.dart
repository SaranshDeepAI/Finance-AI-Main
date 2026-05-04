import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';

class ForecastScreen extends StatefulWidget {
  final String ticker;
  const ForecastScreen({super.key, required this.ticker});

  @override
  State<ForecastScreen> createState() => _ForecastScreenState();
}

class _ForecastScreenState extends State<ForecastScreen> {
  final _apiService = ApiService();
  Map<String, dynamic>? _forecastData;
  bool _isLoading = true;
  bool _isRefreshing = false;
  DateTime? _lastUpdated;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loadForecast();
    _timer = Timer.periodic(const Duration(seconds: 60), (timer) {
      _refreshForecast();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String getCurrencySymbol(String ticker) {
    if (ticker.endsWith(".NS") || ticker.endsWith(".BO")) return "₹";
    if (ticker.endsWith(".L")) return "£";
    if (ticker.endsWith(".DE") || ticker.endsWith(".PA")) return "€";
    if (ticker.endsWith(".T")) return "¥";
    return "\$";
  }

  Future<void> _loadForecast() async {
    try {
      final data = await _apiService.getForecast(widget.ticker);
      setState(() {
        _forecastData = data;
        _isLoading = false;
        _lastUpdated = DateTime.now();
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshForecast() async {
    setState(() => _isRefreshing = true);
    try {
      final data = await _apiService.getForecast(widget.ticker);
      setState(() {
        _forecastData = data;
        _lastUpdated = DateTime.now();
        _isRefreshing = false;
      });
    } catch (e) {
      setState(() => _isRefreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final symbol = getCurrencySymbol(widget.ticker);
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1D1E33),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "${widget.ticker} — 7 Day Forecast",
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        actions: [
          if (_isRefreshing)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Color(0xFF4CAF50),
                  strokeWidth: 2,
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh, color: Color(0xFF4CAF50)),
              onPressed: _refreshForecast,
              tooltip: "Refresh Forecast",
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFF4CAF50)),
                  SizedBox(height: 16),
                  Text(
                    "Training LSTM Model...",
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
          : _forecastData == null
          ? const Center(
              child: Text(
                "Error loading forecast",
                style: TextStyle(color: Colors.red),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Last Updated
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "7 Day Price Forecast",
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        _lastUpdated != null
                            ? "Updated: ${_lastUpdated!.hour}:${_lastUpdated!.minute.toString().padLeft(2, '0')}"
                            : "",
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Powered by LSTM Deep Learning • Auto-refreshes every 60s",
                    style: GoogleFonts.inter(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),

                  // 7 Day Forecast Cards
                  SizedBox(
                    height: 140,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount:
                          (_forecastData!["forecast_7_days"] as List).length,
                      itemBuilder: (context, index) {
                        final price = _forecastData!["forecast_7_days"][index];
                        final prevPrice = index == 0
                            ? price
                            : _forecastData!["forecast_7_days"][index - 1];
                        final isUp = price >= prevPrice;
                        return Container(
                          width: 110,
                          margin: const EdgeInsets.only(right: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1D1E33),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isUp
                                  ? const Color(0xFF4CAF50).withOpacity(0.5)
                                  : Colors.red.withOpacity(0.5),
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Day ${index + 1}",
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Icon(
                                isUp ? Icons.trending_up : Icons.trending_down,
                                color: isUp
                                    ? const Color(0xFF4CAF50)
                                    : Colors.red,
                                size: 18,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "$symbol$price",
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: isUp
                                      ? const Color(0xFF4CAF50)
                                      : Colors.red,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Prediction vs Actual Table
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Predicted vs Actual (Test Period)",
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4CAF50).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          "Live Data",
                          style: GoogleFonts.inter(
                            color: const Color(0xFF4CAF50),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1D1E33),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        // Header
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  "Date",
                                  style: GoogleFonts.inter(
                                    color: Colors.grey,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  "Actual",
                                  style: GoogleFonts.inter(
                                    color: Colors.grey,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  "Predicted",
                                  style: GoogleFonts.inter(
                                    color: Colors.grey,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  "Diff",
                                  style: GoogleFonts.inter(
                                    color: Colors.grey,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(color: Colors.grey, height: 1),
                        // Rows — show most recent 15 days
                        ...(_forecastData!["history"] as List).reversed
                            .take(15)
                            .toList()
                            .reversed
                            .map((item) {
                              final diff = (item["predicted"] - item["actual"])
                                  .toDouble();
                              final isClose = diff.abs() < 5;
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item["date"].toString().substring(5),
                                        style: GoogleFonts.inter(
                                          color: Colors.white,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        "$symbol${item["actual"]}",
                                        style: GoogleFonts.inter(
                                          color: Colors.white,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        "$symbol${item["predicted"]}",
                                        style: GoogleFonts.inter(
                                          color: const Color(0xFF4CAF50),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        "${diff > 0 ? "+" : ""}${diff.toStringAsFixed(1)}",
                                        style: GoogleFonts.inter(
                                          color: isClose
                                              ? Colors.green
                                              : Colors.orange,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
