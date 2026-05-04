import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';

class AnomalyScreen extends StatefulWidget {
  final String ticker;
  const AnomalyScreen({super.key, required this.ticker});

  @override
  State<AnomalyScreen> createState() => _AnomalyScreenState();
}

class _AnomalyScreenState extends State<AnomalyScreen> {
  final _apiService = ApiService();
  Map<String, dynamic>? _anomalyData;
  bool _isLoading = true;
  bool _isRefreshing = false;
  DateTime? _lastUpdated;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loadAnomalies();
    // Auto refresh every 60 seconds
    _timer = Timer.periodic(const Duration(seconds: 60), (timer) {
      _refreshAnomalies();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadAnomalies() async {
    try {
      final data = await _apiService.getAnomalies(widget.ticker);
      setState(() {
        _anomalyData = data;
        _isLoading = false;
        _lastUpdated = DateTime.now();
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshAnomalies() async {
    setState(() => _isRefreshing = true);
    try {
      final data = await _apiService.getAnomalies(widget.ticker);
      setState(() {
        _anomalyData = data;
        _lastUpdated = DateTime.now();
        _isRefreshing = false;
      });
    } catch (e) {
      setState(() => _isRefreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1D1E33),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "${widget.ticker} — Anomaly Detection",
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
                  color: Colors.orange,
                  strokeWidth: 2,
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.orange),
              onPressed: _refreshAnomalies,
              tooltip: "Refresh Anomalies",
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.orange),
                  SizedBox(height: 16),
                  Text(
                    "Detecting Anomalies...",
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
          : _anomalyData == null
          ? const Center(
              child: Text(
                "Error loading anomalies",
                style: TextStyle(color: Colors.red),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Summary Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1D1E33),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.warning_amber,
                                  color: Colors.orange,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  "Anomaly Summary",
                                  style: GoogleFonts.inter(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
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
                        const SizedBox(height: 16),
                        Text(
                          "Total Anomalies Detected: ${_anomalyData!["total_anomalies"]}",
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Analysis Period: Last 3 Months",
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Method: Z-Score Statistical Analysis (threshold: 2.0)",
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            "Auto-refreshes every 60s",
                            style: GoogleFonts.inter(
                              color: Colors.orange,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Anomaly List
                  Text(
                    "Detected Anomalies",
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if ((_anomalyData!["anomalies"] as List).isEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1D1E33),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          "No anomalies detected in this period!",
                          style: GoogleFonts.inter(color: Colors.grey),
                        ),
                      ),
                    )
                  else
                    ...(_anomalyData!["anomalies"] as List).map((anomaly) {
                      final isCrash = anomaly["type"] == "Crash";
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1D1E33),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isCrash
                                ? Colors.red.withOpacity(0.5)
                                : const Color(0xFF4CAF50).withOpacity(0.5),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isCrash
                                    ? Colors.red.withOpacity(0.1)
                                    : const Color(0xFF4CAF50).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                isCrash
                                    ? Icons.trending_down
                                    : Icons.trending_up,
                                color: isCrash
                                    ? Colors.red
                                    : const Color(0xFF4CAF50),
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    anomaly["date"],
                                    style: GoogleFonts.inter(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "Close Price: \$${anomaly["close"]}",
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isCrash
                                        ? Colors.red.withOpacity(0.2)
                                        : const Color(
                                            0xFF4CAF50,
                                          ).withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    anomaly["type"],
                                    style: GoogleFonts.inter(
                                      color: isCrash
                                          ? Colors.red
                                          : const Color(0xFF4CAF50),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "${anomaly["return_pct"]}%",
                                  style: GoogleFonts.inter(
                                    color: isCrash
                                        ? Colors.red
                                        : const Color(0xFF4CAF50),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  "Z: ${anomaly["z_score"]}",
                                  style: GoogleFonts.inter(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }
}
