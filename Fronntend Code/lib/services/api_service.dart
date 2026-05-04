import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ApiService {
  final String baseUrl = "https://financeai-backend-lwjh.onrender.com";
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get stock info
  Future<Map<String, dynamic>> getStockInfo(String ticker) async {
    final response = await http.post(
      Uri.parse("$baseUrl/stock/info"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"ticker": ticker}),
    );
    return jsonDecode(response.body);
  }

  // Get stock analysis
  Future<Map<String, dynamic>> analyzeStock(
    String ticker,
    String period,
  ) async {
    final response = await http.post(
      Uri.parse("$baseUrl/stock/analyze"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"ticker": ticker, "period": period}),
    );
    final data = jsonDecode(response.body);

    // Save analysis to Firestore
    final user = _auth.currentUser;
    if (user != null) {
      await _firestore
          .collection("users")
          .doc(user.uid)
          .collection("searches")
          .add({
            "ticker": ticker,
            "analysis": data["analysis"],
            "timestamp": DateTime.now().toIso8601String(),
          });

      await _firestore.collection("users").doc(user.uid).update({
        "searches": FieldValue.increment(1),
      });
    }

    return data;
  }

  // Get stock news
  Future<Map<String, dynamic>> getStockNews(String ticker) async {
    final response = await http.post(
      Uri.parse("$baseUrl/stock/news"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"ticker": ticker}),
    );
    return jsonDecode(response.body);
  }

  // Get anomalies
  Future<Map<String, dynamic>> getAnomalies(String ticker) async {
    final response = await http.post(
      Uri.parse("$baseUrl/stock/anomaly"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"ticker": ticker, "period": "3mo"}),
    );
    final data = jsonDecode(response.body);

    // Save anomalies to Firestore
    final user = _auth.currentUser;
    if (user != null) {
      await _firestore
          .collection("users")
          .doc(user.uid)
          .collection("anomalies")
          .add({
            "ticker": ticker,
            "total_anomalies": data["total_anomalies"],
            "anomalies": data["anomalies"],
            "timestamp": DateTime.now().toIso8601String(),
          });

      await _firestore.collection("users").doc(user.uid).update({
        "anomaly_checks": FieldValue.increment(1),
      });
    }

    return data;
  }

  // Get forecast
  Future<Map<String, dynamic>> getForecast(String ticker) async {
    final response = await http.post(
      Uri.parse("$baseUrl/stock/forecast"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"ticker": ticker, "period": "1y"}),
    );
    final data = jsonDecode(response.body);

    // Save forecast to Firestore
    final user = _auth.currentUser;
    if (user != null) {
      await _firestore
          .collection("users")
          .doc(user.uid)
          .collection("forecasts")
          .add({
            "ticker": ticker,
            "forecast_7_days": data["forecast_7_days"],
            "timestamp": DateTime.now().toIso8601String(),
          });

      await _firestore.collection("users").doc(user.uid).update({
        "forecasts": FieldValue.increment(1),
      });
    }

    return data;
  }

  // Save search to Firestore
  Future<void> saveSearch(String ticker, String analysis) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore
        .collection("users")
        .doc(user.uid)
        .collection("searches")
        .add({
          "ticker": ticker,
          "analysis": analysis,
          "timestamp": DateTime.now().toIso8601String(),
        });

    await _firestore.collection("users").doc(user.uid).update({
      "searches": FieldValue.increment(1),
    });
  }

  // Get search history
  Future<List<Map<String, dynamic>>> getSearchHistory() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    final snapshot = await _firestore
        .collection("users")
        .doc(user.uid)
        .collection("searches")
        .orderBy("timestamp", descending: true)
        .limit(10)
        .get();

    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  // Get anomaly history
  Future<List<Map<String, dynamic>>> getAnomalyHistory() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    final snapshot = await _firestore
        .collection("users")
        .doc(user.uid)
        .collection("anomalies")
        .orderBy("timestamp", descending: true)
        .limit(10)
        .get();

    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  // Get forecast history
  Future<List<Map<String, dynamic>>> getForecastHistory() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    final snapshot = await _firestore
        .collection("users")
        .doc(user.uid)
        .collection("forecasts")
        .orderBy("timestamp", descending: true)
        .limit(10)
        .get();

    return snapshot.docs.map((doc) => doc.data()).toList();
  }
}
