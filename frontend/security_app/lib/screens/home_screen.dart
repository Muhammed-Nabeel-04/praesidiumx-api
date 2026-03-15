import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import 'login_screen.dart';
import 'dashboard_screen.dart';
import 'package:file_picker/file_picker.dart';
import 'package:fl_chart/fl_chart.dart';
import 'history_screen.dart';
import 'package:flutter/foundation.dart';
import 'ml_details_screen.dart';

class HomeScreen extends StatefulWidget {
  final String token;
  const HomeScreen({super.key, required this.token});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  String? _filePath;
  Uint8List? _fileBytes;
  String? _fileName;

  Map<String, dynamic>? _result;
  bool _loading = false;
  String? _errorMsg;
  String _progressMsg = "Initialising...";

  late AnimationController _fadeCtrl;
  late AnimationController _pulseCtrl;
  late Animation<double> _fadeAnim;
  late Animation<double> _pulseAnim;

  late AnimationController _dotCtrl;
  late Animation<double> _dotAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOutCubic);

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(
      begin: 0.4,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _dotCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
    _dotAnim = CurvedAnimation(parent: _dotCtrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _pulseCtrl.dispose();
    _dotCtrl.dispose();
    super.dispose();
  }

  // ── File Picker ──────────────────────────────────────────────────────────────
  Future<void> _pickFile() async {
    HapticFeedback.lightImpact();
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: kIsWeb,
    );

    if (picked != null) {
      setState(() {
        _fileBytes = kIsWeb ? picked.files.single.bytes : null;
        _fileName = picked.files.single.name;
        _filePath = kIsWeb ? null : picked.files.single.path;
        _result = null;
        _errorMsg = null;
      });
      _fadeCtrl.reset();
    }
  }

  // ── Analyze with polling ──────────────────────────────────────────────────────
  Future<void> _analyze() async {
    // ── DEBUG ──────────────────────────────────────
    print("filePath: $_filePath");
    print("fileBytes null: ${_fileBytes == null}");
    print("fileBytes length: ${_fileBytes?.length}");
    print("fileName: $_fileName");
    // ───────────────────────────────────────────────

    if (_filePath == null && _fileBytes == null) {
      HapticFeedback.mediumImpact();
      _showSnack("Select a CSV file first", isError: true);
      return;
    }

    HapticFeedback.lightImpact();

    setState(() {
      _loading = true;
      _errorMsg = null;
      _result = null;
      _progressMsg = "Uploading file...";
    });

    try {
      final data = await ApiService.analyzeFile(
        _filePath,
        widget.token,
        fileBytes: _fileBytes,
        fileName: _fileName,
        onProgress: (msg) {
          if (mounted) setState(() => _progressMsg = msg);
        },
      );
      if (!mounted) return;
      setState(() => _result = data);
      _fadeCtrl.forward();
      HapticFeedback.mediumImpact();
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMsg = e.toString().replaceAll("Exception: ", ""));
      HapticFeedback.heavyImpact();
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  // ── Logout ───────────────────────────────────────────────────────────────────
  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: AppColors.danger, size: 20),
            SizedBox(width: 10),
            Text(
              "LOGOUT",
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
        content: const Text(
          "Are you sure you want to end your session?",
          style: TextStyle(
            color: AppColors.textSecond,
            fontSize: 13,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              "CANCEL",
              style: TextStyle(
                color: AppColors.textSecond,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              "LOGOUT",
              style: TextStyle(
                color: AppColors.danger,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await AuthService.logout();

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const LoginScreen(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white)),
        backgroundColor: isError ? AppColors.danger : AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────
  String _getTopPort() {
    if (_result?['top_ports'] == null) return "N/A";
    final ports = Map<String, dynamic>.from(_result!['top_ports']);
    return ports.isEmpty ? "None" : ports.entries.first.key;
  }

  ({String label, Color color, IconData icon}) _threatInfo() {
    if (_result == null) {
      return (
        label: "—",
        color: AppColors.textSecond,
        icon: Icons.help_outline,
      );
    }
    final attacks = ((_result!['attacks'] ?? 0) as num).toDouble();
    final anomalies = ((_result!['anomalies'] ?? 0) as num).toDouble();
    final benign = ((_result!['benign'] ?? 0) as num).toDouble();
    final total = attacks + benign;

    if (total == 0) {
      return (
        label: "No Data",
        color: AppColors.textSecond,
        icon: Icons.remove_circle_outline,
      );
    }

    final ratio = (attacks + anomalies) / total;

    if (ratio > 0.5) {
      return (
        label: "CRITICAL",
        color: AppColors.danger,
        icon: Icons.dangerous_outlined,
      );
    }
    if (ratio > 0.2) {
      return (
        label: "HIGH",
        color: AppColors.warning,
        icon: Icons.warning_amber_outlined,
      );
    }
    if (ratio > 0.05) {
      return (
        label: "MODERATE",
        color: AppColors.warning,
        icon: Icons.info_outline,
      );
    }
    return (
      label: "LOW",
      color: AppColors.success,
      icon: Icons.verified_outlined,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildSliverAppBar(),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 20),
                _buildFileSection(),
                const SizedBox(height: 14),
                _buildAnalyzeButton(),
                const SizedBox(height: 20),
                if (_loading) _buildPollingLoader(),
                if (_errorMsg != null) _buildErrorBanner(),
                if (!_loading && _result == null && _errorMsg == null)
                  _buildEmptyState(),
                if (_result != null)
                  FadeTransition(
                    opacity: _fadeAnim,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildThreatBanner(),
                        const SizedBox(height: 16),
                        _buildStatsRow(),
                        const SizedBox(height: 16),
                        _buildViewDashboardButton(),
                        const SizedBox(height: 16),
                        _buildPieChart(),
                        const SizedBox(height: 16),
                        _buildBarChart(),
                      ],
                    ),
                  ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Sliver App Bar ───────────────────────────────────────────────────────────
  Widget _buildSliverAppBar() => SliverAppBar(
    expandedHeight: 120,
    pinned: true,
    backgroundColor: AppColors.appBar,
    elevation: 0,
    surfaceTintColor: AppColors.appBar,
    flexibleSpace: FlexibleSpaceBar(
      titlePadding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      title: Row(
        children: [
          AnimatedBuilder(
            animation: _pulseAnim,
            builder: (_, __) => Opacity(
              opacity: _pulseAnim.value,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.success.withOpacity(0.8),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            "PraesidiumX",
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: 3,
            ),
          ),
        ],
      ),
      background: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.appBar, AppColors.surface],
          ),
        ),
        child: CustomPaint(painter: _GridPainter()),
      ),
    ),
    actions: [
      IconButton(
        icon: const Icon(Icons.history),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => HistoryScreen(token: widget.token),
            ),
          );
        },
      ),
      IconButton(
        icon: const Icon(
          Icons.science_rounded,
          color: AppColors.primary,
          size: 20,
        ),
        tooltip: 'ML Model Details',
        onPressed: () => Navigator.push(
          context,
          PageRouteBuilder(
            // Change this line in your science icon button:
            pageBuilder: (_, __, ___) => MLDetailsScreen(token: widget.token),
            transitionsBuilder: (_, anim, __, child) =>
                FadeTransition(opacity: anim, child: child),
            transitionDuration: const Duration(milliseconds: 350),
          ),
        ),
      ),
      IconButton(
        icon: const Icon(
          Icons.logout_rounded,
          color: AppColors.textSecond,
          size: 20,
        ),
        onPressed: _logout,
      ),
      const SizedBox(width: 8),
    ],
  );

  // ─── File Section ─────────────────────────────────────────────────────────────
  Widget _buildFileSection() {
    final hasFile = _filePath != null || _fileBytes != null;
    final displayFileName = _fileName ?? "Selected File";

    return GestureDetector(
      onTap: _pickFile,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: hasFile
              ? AppColors.primaryDim.withOpacity(0.5)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasFile
                ? AppColors.primary.withOpacity(0.5)
                : AppColors.cardBorder,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: hasFile
                    ? AppColors.primary.withOpacity(0.15)
                    : AppColors.surfaceHigh,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                hasFile ? Icons.task_alt_rounded : Icons.folder_open_rounded,
                color: hasFile ? AppColors.primary : AppColors.textSecond,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasFile ? "File Ready" : "No File Selected",
                    style: TextStyle(
                      color: hasFile ? AppColors.primary : AppColors.textSecond,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasFile ? displayFileName : "Tap to browse CSV files",
                    style: TextStyle(
                      color: hasFile
                          ? AppColors.textPrimary
                          : AppColors.textMuted,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.primary.withOpacity(0.3)),
              ),
              child: const Text(
                "BROWSE",
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Analyze Button ───────────────────────────────────────────────────────────
  Widget _buildAnalyzeButton() => GestureDetector(
    onTap: _loading ? null : _analyze,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: _loading ? AppColors.cardBorder : AppColors.primary,
        borderRadius: BorderRadius.circular(14),
        boxShadow: _loading
            ? []
            : [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _loading ? Icons.hourglass_top_rounded : Icons.radar_rounded,
            color: _loading ? AppColors.textSecond : AppColors.bg,
            size: 20,
          ),
          const SizedBox(width: 10),
          Text(
            _loading ? "ANALYSING..." : "RUN ANALYSIS",
            style: TextStyle(
              color: _loading ? AppColors.textSecond : AppColors.bg,
              fontWeight: FontWeight.w900,
              fontSize: 14,
              letterSpacing: 2.5,
            ),
          ),
        ],
      ),
    ),
  );

  // ─── Polling Loader ───────────────────────────────────────────────────────────
  Widget _buildPollingLoader() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 40),
    child: Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 72,
              height: 72,
              child: CircularProgressIndicator(
                color: AppColors.primary.withOpacity(0.15),
                strokeWidth: 1,
              ),
            ),
            SizedBox(
              width: 52,
              height: 52,
              child: CircularProgressIndicator(
                color: AppColors.primary,
                strokeWidth: 2,
              ),
            ),
            const Icon(Icons.radar_rounded, color: AppColors.primary, size: 24),
          ],
        ),
        const SizedBox(height: 20),
        AnimatedBuilder(
          animation: _dotAnim,
          builder: (_, __) {
            final dots = List.generate(3, (i) {
              final opacity = (((_dotAnim.value * 3) - i).clamp(0.0, 1.0));
              return Opacity(
                opacity: opacity,
                child: const Text(
                  ".",
                  style: TextStyle(color: AppColors.primary, fontSize: 20),
                ),
              );
            });
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _progressMsg,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
                ...dots,
              ],
            );
          },
        ),
        const SizedBox(height: 8),
        const Text(
          "SHAP computation may take 20–60 seconds",
          style: TextStyle(color: AppColors.textSecond, fontSize: 11),
        ),
      ],
    ),
  );

  // ─── Error Banner ─────────────────────────────────────────────────────────────
  Widget _buildErrorBanner() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.dangerDim,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.danger.withOpacity(0.4)),
    ),
    child: Row(
      children: [
        const Icon(
          Icons.error_outline_rounded,
          color: AppColors.danger,
          size: 20,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            _errorMsg!,
            style: const TextStyle(
              color: AppColors.danger,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ),
        GestureDetector(
          onTap: () => setState(() => _errorMsg = null),
          child: const Icon(
            Icons.close_rounded,
            color: AppColors.danger,
            size: 18,
          ),
        ),
      ],
    ),
  );

  // ─── Empty State ─────────────────────────────────────────────────────────────
  Widget _buildEmptyState() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 60),
    child: Column(
      children: [
        AnimatedBuilder(
          animation: _pulseAnim,
          builder: (_, __) => Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surface,
              border: Border.all(
                color: AppColors.primary.withOpacity(_pulseAnim.value * 0.3),
              ),
            ),
            child: Icon(
              Icons.radar_rounded,
              size: 44,
              color: AppColors.primary.withOpacity(_pulseAnim.value * 0.6),
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          "AWAITING INPUT",
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 3,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          "Upload a network traffic CSV\nto begin XAI-powered analysis",
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textSecond,
            fontSize: 13,
            height: 1.6,
          ),
        ),
      ],
    ),
  );

  // ─── Threat Banner ────────────────────────────────────────────────────────────
  Widget _buildThreatBanner() {
    final info = _threatInfo();
    final atk = ((_result!['attacks'] ?? 0) as num).toDouble();
    final ano = ((_result!['anomalies'] ?? 0) as num).toDouble();
    final ben = ((_result!['benign'] ?? 0) as num).toDouble();
    final total = atk + ben;
    final ratio = total == 0 ? 0.0 : (atk + ano) / total;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: info.color.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: info.color.withOpacity(0.08),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: info.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(info.icon, color: info.color, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "THREAT LEVEL",
                  style: TextStyle(
                    color: AppColors.textSecond,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  info.label,
                  style: TextStyle(
                    color: info.color,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 56,
            height: 56,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: ratio.clamp(0.0, 1.0),
                  strokeWidth: 4,
                  backgroundColor: info.color.withOpacity(0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(info.color),
                ),
                Text(
                  "${(ratio * 100).toStringAsFixed(0)}%",
                  style: TextStyle(
                    color: info.color,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Stats Row ────────────────────────────────────────────────────────────────
  Widget _buildStatsRow() => Row(
    children: [
      Expanded(
        child: _stat(
          "ATTACKS",
          _result?['attacks'] ?? 0,
          AppColors.danger,
          Icons.gpp_bad_outlined,
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: _stat(
          "BENIGN",
          _result?['benign'] ?? 0,
          AppColors.success,
          Icons.verified_outlined,
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: _stat(
          "ANOMALIES",
          _result?['anomalies'] ?? 0,
          AppColors.warning,
          Icons.bolt_outlined,
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: _stat(
          "TOP PORT",
          _getTopPort(),
          AppColors.purple,
          Icons.router_outlined,
        ),
      ),
    ],
  );

  Widget _stat(String label, dynamic value, Color color, IconData icon) =>
      Container(
        padding: const EdgeInsets.fromLTRB(10, 14, 10, 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 8),
            Text(
              value.toString(),
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecond,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );

  // ─── Dashboard Button ─────────────────────────────────────────────────────────
  Widget _buildViewDashboardButton() => GestureDetector(
    onTap: () {
      HapticFeedback.lightImpact();
      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => DashboardScreen(result: _result!),
          transitionsBuilder: (_, anim, __, child) => SlideTransition(
            position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
                .animate(
                  CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
                ),
            child: child,
          ),
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    },
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.dashboard_rounded, color: AppColors.primary, size: 18),
          SizedBox(width: 10),
          Text(
            "VIEW DETAILED DASHBOARD",
            style: TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w800,
              fontSize: 12,
              letterSpacing: 2,
            ),
          ),
          SizedBox(width: 8),
          Icon(
            Icons.arrow_forward_ios_rounded,
            color: AppColors.primary,
            size: 12,
          ),
        ],
      ),
    ),
  );

  // ─── Pie Chart ────────────────────────────────────────────────────────────────
  Widget _buildPieChart() {
    final atk = ((_result!['attacks'] ?? 0) as num).toDouble();
    final ben = ((_result!['benign'] ?? 0) as num).toDouble();
    final total = atk + ben;
    if (total == 0) return const SizedBox();
    return _chartCard(
      title: "TRAFFIC DISTRIBUTION",
      icon: Icons.donut_large_rounded,
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 170,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                  sections: [
                    PieChartSectionData(
                      value: atk,
                      color: AppColors.danger,
                      title: "${((atk / total) * 100).toStringAsFixed(1)}%",
                      titleStyle: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                      radius: 55,
                    ),
                    PieChartSectionData(
                      value: ben,
                      color: AppColors.success,
                      title: "${((ben / total) * 100).toStringAsFixed(1)}%",
                      titleStyle: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                      radius: 55,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _dot(AppColors.danger, "Attacks", atk.toInt()),
              const SizedBox(height: 14),
              _dot(AppColors.success, "Benign", ben.toInt()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dot(Color color, String label, int count) => Row(
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 8),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: AppColors.textSecond, fontSize: 11),
          ),
          Text(
            count.toString(),
            style: TextStyle(
              color: color,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    ],
  );

  // ─── Bar Chart ────────────────────────────────────────────────────────────────
  Widget _buildBarChart() {
    if (_result?['top_ports'] == null) return const SizedBox();
    final ports = Map<String, dynamic>.from(_result!['top_ports']);
    if (ports.isEmpty) {
      return _chartCard(
        title: "TOP PORTS ACTIVITY",
        icon: Icons.bar_chart_rounded,
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 30),
          child: Center(
            child: Text(
              "No attack ports detected",
              style: TextStyle(color: AppColors.textSecond),
            ),
          ),
        ),
      );
    }

    final sorted =
        (ports.entries.toList()
              ..sort((a, b) => (b.value as num).compareTo(a.value as num)))
            .take(5)
            .toList();

    return _chartCard(
      title: "TOP PORTS ACTIVITY",
      icon: Icons.bar_chart_rounded,
      child: SizedBox(
        height: 200,
        child: BarChart(
          BarChartData(
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) =>
                  const FlLine(color: AppColors.cardBorder, strokeWidth: 1),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 42,
                  getTitlesWidget: (v, _) => Text(
                    v.toInt().toString(),
                    style: const TextStyle(
                      color: AppColors.textSecond,
                      fontSize: 10,
                    ),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (v, _) {
                    final i = v.toInt();
                    if (i < 0 || i >= sorted.length) return const SizedBox();
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        sorted[i].key,
                        style: const TextStyle(
                          color: AppColors.textSecond,
                          fontSize: 10,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            barGroups: List.generate(
              sorted.length,
              (i) => BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: (sorted[i].value as num).toDouble(),
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.purple],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                    width: 20,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(6),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _chartCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.cardBorder),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 16),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                color: AppColors.textSecond,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Divider(color: AppColors.cardBorder, height: 20),
        child,
      ],
    ),
  );
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary.withOpacity(0.04)
      ..strokeWidth = 0.5;
    for (double x = 0; x < size.width; x += 30) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += 30) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}
