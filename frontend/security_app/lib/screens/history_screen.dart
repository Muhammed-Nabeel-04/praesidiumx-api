import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import 'dashboard_screen.dart';

class HistoryScreen extends StatefulWidget {
  final String token;

  const HistoryScreen({super.key, required this.token});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<dynamic> _history = [];
  List<dynamic> _filtered = [];
  bool _loading = true;
  String _search = "";
  String _sortMode = "Newest";

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);

    try {
      final data = await ApiService.getHistory(widget.token);

      if (mounted) {
        setState(() {
          _history = data;
          _applyFilters();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error fetching log: $e"),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _applyFilters() {
    var temp = _history.where((item) {
      final name = item["dataset_name"]?.toString().toLowerCase() ?? "";
      final date = item["created_at"]?.toString().toLowerCase() ?? "";
      return name.contains(_search.toLowerCase()) ||
          date.contains(_search.toLowerCase());
    }).toList();

    if (_sortMode == "Newest") {
      temp.sort(
        (a, b) => (b["created_at"] ?? "").compareTo(a["created_at"] ?? ""),
      );
    } else if (_sortMode == "Oldest") {
      temp.sort(
        (a, b) => (a["created_at"] ?? "").compareTo(b["created_at"] ?? ""),
      );
    } else if (_sortMode == "Risk") {
      temp.sort((a, b) {
        final aVal = (a["attacks"] ?? 0) as num;
        final bVal = (b["attacks"] ?? 0) as num;
        return bVal.compareTo(aVal);
      });
    }

    setState(() {
      _filtered = temp;
    });
  }

  Future<void> _delete(dynamic id, int index) async {
    HapticFeedback.mediumImpact();

    setState(() {
      _filtered.removeAt(index);
      _history.removeWhere((item) => item["id"].toString() == id.toString());
    });

    try {
      await ApiService.deleteHistoryRecord(id.toString(), widget.token);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Record purged from database"),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (mounted) _load();
    }
  }

  void _openDashboard(dynamic item) {
    HapticFeedback.lightImpact();

    Map<String, dynamic> dashboardData;

    try {
      if (item["full_result"] is String) {
        dashboardData = jsonDecode(item["full_result"]);
      } else {
        dashboardData = Map<String, dynamic>.from(item["full_result"] ?? {});
      }

      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => DashboardScreen(result: dashboardData),
          transitionsBuilder: (_, anim, __, child) => SlideTransition(
            position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
                .animate(
                  CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
                ),
            child: child,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Corruption detected in data: $e"),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  void _export(dynamic item) {
    HapticFeedback.selectionClick();
    dynamic dataToExport = item["full_result"];
    if (dataToExport is String) {
      dataToExport = jsonDecode(dataToExport);
    }

    final jsonStr = const JsonEncoder.withIndent("  ").convert(dataToExport);

    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: AppColors.bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.cardBorder, width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: AppColors.surfaceHigh,
                borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.terminal_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      "RAW DATA EXPORT",
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(
                      Icons.close_rounded,
                      color: AppColors.textMuted,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              height: 400,
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: const Color(0xFF000000),
              child: SingleChildScrollView(
                child: Text(
                  jsonStr,
                  style: const TextStyle(
                    color: AppColors.success,
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  ({String label, Color color}) _getRiskData(dynamic item) {
    final attacks = ((item['attacks'] ?? 0) as num).toDouble();
    final anomalies = ((item['anomalies'] ?? 0) as num).toDouble();
    final benign = ((item['benign'] ?? 0) as num).toDouble();
    final total = attacks + benign;

    if (total == 0) return (label: "NO DATA", color: AppColors.textMuted);
    final ratio = (attacks + anomalies) / total;

    if (ratio > 0.5) return (label: "CRITICAL", color: AppColors.danger);
    if (ratio > 0.2) return (label: "HIGH RISK", color: AppColors.warning);
    if (ratio > 0.05) return (label: "MODERATE", color: AppColors.warning);
    return (label: "SECURE", color: AppColors.success);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.appBar,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        title: const Text(
          "SECURITY AUDIT LOG",
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : Column(
              children: [
                _buildTopBar(),
                Expanded(
                  child: _filtered.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          color: AppColors.primary,
                          backgroundColor: AppColors.surfaceHigh,
                          onRefresh: _load,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(20),
                            physics: const AlwaysScrollableScrollPhysics(),
                            itemCount: _filtered.length,
                            itemBuilder: (context, index) =>
                                _buildCard(_filtered[index], index),
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      decoration: const BoxDecoration(
        color: AppColors.appBar,
        border: Border(bottom: BorderSide(color: AppColors.cardBorder)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              onChanged: (val) {
                setState(() {
                  _search = val;
                  _applyFilters();
                });
              },
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
              ),
              decoration: InputDecoration(
                hintText: "Search dataset...",
                hintStyle: const TextStyle(color: AppColors.textMuted),
                prefixIcon: const Icon(
                  Icons.search,
                  color: AppColors.textSecond,
                  size: 20,
                ),
                filled: true,
                fillColor: AppColors.surfaceHigh,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.surfaceHigh,
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _sortMode,
                dropdownColor: AppColors.surfaceHigh,
                icon: const Icon(
                  Icons.sort_rounded,
                  color: AppColors.textSecond,
                  size: 18,
                ),
                items: ["Newest", "Oldest", "Risk"]
                    .map(
                      (e) => DropdownMenuItem<String>(
                        value: e,
                        child: Text(
                          e,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (val) {
                  setState(() {
                    _sortMode = val!;
                    _applyFilters();
                  });
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.history_toggle_off_rounded,
            size: 64,
            color: AppColors.textMuted,
          ),
          const SizedBox(height: 16),
          Text(
            _search.isEmpty
                ? "No audit records found."
                : "No matching records.",
            style: const TextStyle(color: AppColors.textSecond, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(dynamic item, int index) {
    final risk = _getRiskData(item);
    String dateStr = "Unknown Date";
    try {
      if (item['created_at'] != null) {
        final date = DateTime.parse(item['created_at']);
        dateStr =
            "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}  ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
      }
    } catch (_) {}

    return Dismissible(
      key: Key(item["id"].toString()),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _delete(item["id"], index),
      background: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: AppColors.danger,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Icon(
          Icons.delete_sweep_rounded,
          color: Colors.white,
          size: 28,
        ),
      ),
      child: GestureDetector(
        onTap: () => _openDashboard(item),
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.cardBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      item["dataset_name"] ?? "Unknown Log",
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: risk.color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: risk.color.withOpacity(0.5)),
                    ),
                    child: Text(
                      risk.label,
                      style: TextStyle(
                        color: risk.color,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                dateStr,
                style: const TextStyle(
                  color: AppColors.textSecond,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 16),
              const Divider(color: AppColors.cardBorder, height: 1),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _miniStat(
                            Icons.gpp_bad_rounded,
                            AppColors.danger,
                            (item["attacks"] ?? 0).toString(),
                          ),
                          const SizedBox(width: 16),
                          _miniStat(
                            Icons.bolt_rounded,
                            AppColors.warning,
                            (item["anomalies"] ?? 0).toString(),
                          ),
                          const SizedBox(width: 16),
                          _miniStat(
                            Icons.verified_rounded,
                            AppColors.success,
                            (item["benign"] ?? 0).toString(),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => _export(item),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceHigh,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.code_rounded,
                            color: AppColors.primary,
                            size: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.arrow_forward_ios_rounded,
                          color: AppColors.primary,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniStat(IconData icon, Color color, String value) {
    return Row(
      children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 4),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
