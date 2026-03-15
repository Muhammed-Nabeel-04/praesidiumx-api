import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import '../theme/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  DASHBOARD SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class DashboardScreen extends StatefulWidget {
  final Map<String, dynamic> result;
  const DashboardScreen({super.key, required this.result});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  late AnimationController _staggerCtrl;
  late List<Animation<double>> _staggerAnims;

  // Chart toggles
  static const _chartTypes = ['Bar', 'Line', 'Pie'];
  int _trafficChart = 0;
  int _portsChart = 0;
  int _timelineChart = 1;
  int _touchedPie = -1;

  // State for the flow list expansion
  bool _flowsExpanded = false;

  // Port filter
  String? _selectedPort;

  // Parsed
  late double attacks;
  late double benign;
  late double anomalies;
  late double total;
  late double riskRatio;
  late Map<String, dynamic> ports;
  late List<MapEntry<String, dynamic>> sortedPorts;
  late List<double> anomalySeries;
  late List<Map<String, dynamic>> flows;

  // Timeline series (from backend)
  late List<double> attackSeries;
  late List<double> benignSeries;

  @override
  void initState() {
    super.initState();
    _parse();
    _staggerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _staggerAnims = List.generate(9, (i) {
      final s = i * 0.08, e = (s + 0.4).clamp(0.0, 1.0);
      return CurvedAnimation(
        parent: _staggerCtrl,
        curve: Interval(s, e, curve: Curves.easeOutCubic),
      );
    });
    _staggerCtrl.forward();
  }

  void _parse() {
    attacks = ((widget.result['attacks'] ?? 0) as num).toDouble();
    benign = ((widget.result['benign'] ?? 0) as num).toDouble();
    anomalies = ((widget.result['anomalies'] ?? 0) as num).toDouble();
    total = attacks + benign;
    riskRatio = total == 0 ? 0 : (attacks + anomalies) / total;
    ports = Map<String, dynamic>.from(widget.result['top_ports'] ?? {});
    sortedPorts =
        (ports.entries.toList()
              ..sort((a, b) => (b.value as num).compareTo(a.value as num)))
            .take(5)
            .toList();

    // Anomaly timeline from backend
    final raw = widget.result['anomaly_series'];
    anomalySeries = raw != null
        ? List<double>.from((raw as List).map((e) => (e as num).toDouble()))
        : List.filled(60, 0.0);

    // Flows
    final rawFlows = widget.result['flows'];
    flows = rawFlows != null ? List<Map<String, dynamic>>.from(rawFlows) : [];

    // Generate attack/benign timeline from aggregate (deterministic)
    final rng = Random(42);
    attackSeries = _dist(attacks.toInt(), 60, rng, peak: 14);
    benignSeries = _dist(benign.toInt(), 60, rng, peak: 10);
  }

  List<double> _dist(int total, int pts, Random rng, {int peak = 12}) {
    if (total == 0) return List.filled(pts, 0);
    final w = List.generate(
      pts,
      (i) =>
          exp(-((i - peak) * (i - peak)).toDouble() / 20) +
          rng.nextDouble() * 0.3,
    );
    final sum = w.reduce((a, b) => a + b);
    return w.map((x) => x / sum * total).toList();
  }

  @override
  void dispose() {
    _staggerCtrl.dispose();
    super.dispose();
  }

  List<MapEntry<String, dynamic>> get _filteredPorts => _selectedPort == null
      ? sortedPorts
      : sortedPorts.where((e) => e.key == _selectedPort).toList();

  ({String label, String sub, Color color, Color bg, IconData icon})
  get _threat {
    if (riskRatio > 0.5) {
      return (
        label: "CRITICAL",
        sub: "Immediate response required",
        color: AppColors.danger,
        bg: AppColors.dangerDim,
        icon: Icons.dangerous_rounded,
      );
    }
    if (riskRatio > 0.2) {
      return (
        label: "HIGH RISK",
        sub: "Significant threat activity detected",
        color: AppColors.warning,
        bg: AppColors.warningDim,
        icon: Icons.warning_rounded,
      );
    }
    if (riskRatio > 0.05) {
      return (
        label: "MODERATE",
        sub: "Suspicious patterns identified",
        color: AppColors.warning,
        bg: AppColors.warningDim,
        icon: Icons.info_rounded,
      );
    }
    return (
      label: "LOW RISK",
      sub: "Network appears normal",
      color: AppColors.success,
      bg: AppColors.successDim,
      icon: Icons.verified_rounded,
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
          _appBar(),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 20),
                _anim(0, _threatCard()),
                const SizedBox(height: 16),
                _anim(1, _kpiRow()),
                const SizedBox(height: 16),
                _anim(2, _riskMeter()),
                const SizedBox(height: 16),
                _anim(3, _trafficChartCard()),
                const SizedBox(height: 16),
                _anim(4, _anomalyTimelineCard()),
                const SizedBox(height: 16),
                _anim(5, _portsChartCard()),
                const SizedBox(height: 16),
                _anim(6, _flowListCard()),
                const SizedBox(height: 16),
                _anim(7, _summaryCard()),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _anim(int i, Widget child) => FadeTransition(
    opacity: _staggerAnims[i],
    child: SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.08),
        end: Offset.zero,
      ).animate(_staggerAnims[i]),
      child: child,
    ),
  );

  // ─── App Bar ──────────────────────────────────────────────────────────────────
  SliverAppBar _appBar() => SliverAppBar(
    pinned: true,
    expandedHeight: 110,
    backgroundColor: AppColors.appBar,
    elevation: 0,
    surfaceTintColor: AppColors.appBar,
    leading: IconButton(
      onPressed: () {
        HapticFeedback.lightImpact();
        Navigator.pop(context);
      },
      icon: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(
          Icons.arrow_back_ios_new_rounded,
          size: 16,
          color: AppColors.textPrimary,
        ),
      ),
    ),
    flexibleSpace: FlexibleSpaceBar(
      titlePadding: const EdgeInsets.fromLTRB(64, 0, 20, 14),
      title: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            "SECURITY ANALYTICS",
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
          Text(
            "XAI • Per-flow explainability",
            style: TextStyle(color: AppColors.textMuted, fontSize: 10),
          ),
        ],
      ),
    ),
    actions: [
      Padding(
        padding: const EdgeInsets.only(right: 16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _threat.bg,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Icon(_threat.icon, color: _threat.color, size: 12),
              const SizedBox(width: 6),
              Text(
                _threat.label,
                style: TextStyle(
                  color: _threat.color,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );

  // ─── Threat Card ──────────────────────────────────────────────────────────────
  Widget _threatCard() {
    final t = _threat;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: t.bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: t.color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: t.color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(t.icon, color: t.color, size: 32),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.label,
                  style: TextStyle(
                    color: t.color,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  t.sub,
                  style: TextStyle(
                    color: t.color.withOpacity(0.7),
                    fontSize: 12,
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
                  value: riskRatio.clamp(0.0, 1.0),
                  strokeWidth: 5,
                  backgroundColor: t.color.withOpacity(0.15),
                  valueColor: AlwaysStoppedAnimation(t.color),
                ),
                Text(
                  "${(riskRatio * 100).toStringAsFixed(0)}%",
                  style: TextStyle(
                    color: t.color,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── KPI Row ──────────────────────────────────────────────────────────────────
  Widget _kpiRow() => Row(
    children: [
      Expanded(
        child: _kpi(
          "Attacks",
          attacks.toInt(),
          AppColors.danger,
          Icons.gpp_bad_outlined,
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: _kpi(
          "Benign",
          benign.toInt(),
          AppColors.success,
          Icons.verified_outlined,
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: _kpi(
          "Anomalies",
          anomalies.toInt(),
          AppColors.warning,
          Icons.bolt_outlined,
        ),
      ),
    ],
  );

  Widget _kpi(String label, int value, Color color, IconData icon) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: color.withOpacity(0.2)),
    ),
    child: Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 10),
        Text(
          value.toString(),
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );

  // ─── Risk Meter ───────────────────────────────────────────────────────────────
  Widget _riskMeter() => _card(
    "RISK BREAKDOWN",
    Icons.analytics_outlined,
    Column(
      children: [
        _bar(
          "Attacks",
          attacks,
          total > 0 ? attacks / total : 0,
          AppColors.danger,
        ),
        const SizedBox(height: 12),
        _bar(
          "Benign",
          benign,
          total > 0 ? benign / total : 0,
          AppColors.success,
        ),
        const SizedBox(height: 12),
        _bar(
          "Anomalies",
          anomalies,
          total > 0 ? anomalies / (total + anomalies + 1) : 0,
          AppColors.warning,
        ),
      ],
    ),
  );

  Widget _bar(String lbl, double v, double r, Color c) => Column(
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            lbl,
            style: const TextStyle(
              color: AppColors.textSecond,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            v.toInt().toString(),
            style: TextStyle(
              color: c,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
      const SizedBox(height: 6),
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: r.clamp(0.0, 1.0),
          minHeight: 7,
          backgroundColor: c.withOpacity(0.1),
          valueColor: AlwaysStoppedAnimation(c),
        ),
      ),
    ],
  );

  // ─── Traffic Distribution ─────────────────────────────────────────────────────
  Widget _trafficChartCard() {
    if (total == 0) return const SizedBox();
    return _card(
      "TRAFFIC DISTRIBUTION",
      Icons.donut_large_rounded,
      Column(
        children: [
          _toggle(
            _trafficChart,
            (i) => setState(() {
              _trafficChart = i;
              _touchedPie = -1;
            }),
          ),
          const SizedBox(height: 16),
          _switchAnim(_trafficChart, [_tBar(), _tLine(), _tPie()]),
        ],
      ),
    );
  }

  Widget _tBar() => SizedBox(
    height: 200,
    child: InteractiveViewer(
      scaleEnabled: true,
      panEnabled: true,
      minScale: 1,
      maxScale: 3,
      child: BarChart(
        BarChartData(
          gridData: _grid(),
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
                reservedSize: 44,
                getTitlesWidget: (v, _) => Text(
                  v.toInt().toString(),
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 10,
                  ),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (v, _) {
                  const l = ["Attacks", "Benign", "Anomalies"];
                  final i = v.toInt();
                  if (i < 0 || i >= l.length) return const SizedBox();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      l[i],
                      style: const TextStyle(
                        color: AppColors.textSecond,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: [
            _bg(0, attacks, AppColors.danger),
            _bg(1, benign, AppColors.success),
            _bg(2, anomalies, AppColors.warning),
          ],
        ),
      ),
    ),
  );

  Widget _tLine() => SizedBox(
    height: 200,
    child: InteractiveViewer(
      scaleEnabled: true,
      panEnabled: true,
      minScale: 1,
      maxScale: 3,
      child: LineChart(
        LineChartData(
          gridData: _grid(),
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
                reservedSize: 44,
                getTitlesWidget: (v, _) => Text(
                  v.toInt().toString(),
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 10,
                  ),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (v, _) {
                  const l = ["Atk", "Ben", "Ano"];
                  final i = v.toInt();
                  if (i < 0 || i >= l.length) return const SizedBox();
                  return Text(
                    l[i],
                    style: const TextStyle(
                      color: AppColors.textSecond,
                      fontSize: 10,
                    ),
                  );
                },
              ),
            ),
          ),
          lineBarsData: [
            _lb([
              FlSpot(0, attacks),
              FlSpot(1, benign),
              FlSpot(2, anomalies),
            ], AppColors.primary),
          ],
        ),
      ),
    ),
  );

  Widget _tPie() => Row(
    children: [
      Expanded(
        flex: 3,
        child: SizedBox(
          height: 200,
          child: PieChart(
            PieChartData(
              pieTouchData: PieTouchData(
                touchCallback: (ev, resp) {
                  setState(
                    () => _touchedPie =
                        (!ev.isInterestedForInteractions ||
                            resp?.touchedSection == null)
                        ? -1
                        : resp!.touchedSection!.touchedSectionIndex,
                  );
                },
              ),
              sectionsSpace: 3,
              centerSpaceRadius: 44,
              sections: [
                _ps(attacks, total + anomalies, "Attacks", AppColors.danger, 0),
                _ps(benign, total + anomalies, "Benign", AppColors.success, 1),
                _ps(
                  anomalies,
                  total + anomalies,
                  "Anomalies",
                  AppColors.warning,
                  2,
                ),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(width: 16),
      Expanded(
        flex: 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _pl(AppColors.danger, "Attacks", attacks.toInt()),
            const SizedBox(height: 16),
            _pl(AppColors.success, "Benign", benign.toInt()),
            const SizedBox(height: 16),
            _pl(AppColors.warning, "Anomalies", anomalies.toInt()),
          ],
        ),
      ),
    ],
  );

  PieChartSectionData _ps(double v, double t, String lbl, Color c, int idx) {
    final touched = _touchedPie == idx;
    final pct = t > 0 ? (v / t * 100).toStringAsFixed(1) : "0.0";
    return PieChartSectionData(
      value: v,
      color: c,
      radius: touched ? 70 : 58,
      title: touched ? "${v.toInt()}\n$lbl" : "$pct%",
      titleStyle: TextStyle(
        color: AppColors.textPrimary,
        fontSize: touched ? 9 : 11,
        fontWeight: FontWeight.w800,
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  //  ANOMALY SCORE TIMELINE
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _anomalyTimelineCard() => _card(
    "ANOMALY SCORE TIMELINE",
    Icons.timeline_rounded,
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _miniStat(
              "Peak Score",
              anomalySeries.isNotEmpty
                  ? anomalySeries.reduce(max).toStringAsFixed(4)
                  : "0",
              AppColors.danger,
            ),
            const SizedBox(width: 20),
            _miniStat(
              "Avg Score",
              anomalySeries.isNotEmpty
                  ? (anomalySeries.reduce((a, b) => a + b) /
                            anomalySeries.length)
                        .toStringAsFixed(4)
                  : "0",
              AppColors.warning,
            ),
            const SizedBox(width: 20),
            _miniStat(
              "Data Points",
              anomalySeries.length.toString(),
              AppColors.primary,
            ),
          ],
        ),
        const SizedBox(height: 16),
        _toggle(
          _timelineChart,
          (i) => setState(() => _timelineChart = i),
          twoOnly: true,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _dotLegend(AppColors.warning, "Anomaly Score"),
            const SizedBox(width: 16),
            _dotLegend(AppColors.danger, "Attack Rate"),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 220,
          child: InteractiveViewer(
            scaleEnabled: true,
            panEnabled: true,
            minScale: 1,
            maxScale: 6,
            child: _switchAnim(_timelineChart, [
              _anomalyBar(),
              _anomalyLine(),
              _anomalyLine(),
            ]),
          ),
        ),
        const SizedBox(height: 8),
        _hint(),
      ],
    ),
  );

  Widget _miniStat(String label, String value, Color color) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
      ),
      Text(
        value,
        style: TextStyle(
          color: color,
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      ),
    ],
  );

  Widget _anomalyLine() => LineChart(
    LineChartData(
      clipData: const FlClipData.all(),
      gridData: _grid(),
      borderData: FlBorderData(show: false),
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipItems: (spots) => spots
              .map(
                (s) => LineTooltipItem(
                  "Bucket ${s.x.toInt()}: ${s.y.toStringAsFixed(4)}",
                  TextStyle(
                    color: s.bar.color ?? AppColors.textPrimary,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
              .toList(),
        ),
      ),
      titlesData: _timelineTitles(),
      lineBarsData: [
        LineChartBarData(
          spots: List.generate(
            anomalySeries.length,
            (i) => FlSpot(i.toDouble(), anomalySeries[i]),
          ),
          color: AppColors.warning,
          barWidth: 2.5,
          isCurved: true,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              colors: [
                AppColors.warning.withOpacity(0.3),
                AppColors.warning.withOpacity(0),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        LineChartBarData(
          spots: List.generate(
            attackSeries.length,
            (i) => FlSpot(i.toDouble(), attackSeries[i]),
          ),
          color: AppColors.danger,
          barWidth: 2,
          isCurved: true,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              colors: [
                AppColors.danger.withOpacity(0.15),
                AppColors.danger.withOpacity(0),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _anomalyBar() => BarChart(
    BarChartData(
      groupsSpace: 2,
      gridData: _grid(),
      borderData: FlBorderData(show: false),
      titlesData: _timelineTitles(),
      barGroups: List.generate(
        anomalySeries.length,
        (i) => BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: anomalySeries[i],
              color: AppColors.warning,
              width: 3,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(2),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  FlTitlesData _timelineTitles() => FlTitlesData(
    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    leftTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 52,
        getTitlesWidget: (v, _) => Text(
          v.toStringAsFixed(3),
          style: const TextStyle(color: AppColors.textMuted, fontSize: 8),
        ),
      ),
    ),
    bottomTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        interval: 10,
        getTitlesWidget: (v, _) {
          final h = v.toInt();
          if (h % 10 != 0) return const SizedBox();
          return Text(
            "B$h",
            style: const TextStyle(color: AppColors.textMuted, fontSize: 9),
          );
        },
      ),
    ),
  );

  // ─────────────────────────────────────────────────────────────────────────────
  //  PER-FLOW LIST
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _flowListCard() {
    if (flows.isEmpty) {
      return _card(
        "FLOW INTELLIGENCE",
        Icons.manage_search_rounded,
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Center(
            child: Text(
              "No flow data available",
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
        ),
      );
    }

    final previewFlows = flows.take(4).toList();
    final displayFlows = _flowsExpanded
        ? flows.take(50).toList()
        : previewFlows;
    final hiddenCount = flows.length - 4;

    return _card(
      "FLOW INTELLIGENCE",
      Icons.manage_search_rounded,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "${flows.length} sampled flows",
                style: const TextStyle(
                  color: AppColors.textSecond,
                  fontSize: 12,
                ),
              ),
              const Text(
                "TAP FLOW FOR XAI",
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceHigh,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                SizedBox(
                  width: 60,
                  child: Text(
                    "STATUS",
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    "FLOW ID",
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                SizedBox(
                  width: 60,
                  child: Text(
                    "PORT",
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(
                  width: 70,
                  child: Text(
                    "ANOMALY",
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),

          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            switchInCurve: Curves.easeOutCubic,
            child: Column(
              key: ValueKey(_flowsExpanded),
              children: displayFlows.map((f) => _flowRow(f)).toList(),
            ),
          ),

          const SizedBox(height: 12),

          if (!_flowsExpanded && hiddenCount > 0)
            GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _flowsExpanded = true);
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceHigh,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.expand_more_rounded,
                      color: AppColors.textSecond,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "Show $hiddenCount more flows",
                      style: const TextStyle(
                        color: AppColors.textSecond,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          if (_flowsExpanded)
            GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _flowsExpanded = false);
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceHigh,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.expand_less_rounded,
                      color: AppColors.textSecond,
                      size: 18,
                    ),
                    SizedBox(width: 8),
                    Text(
                      "Show less",
                      style: TextStyle(
                        color: AppColors.textSecond,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _flowRow(Map<String, dynamic> flow) {
    final isAttack = (flow['prediction'] as int) == 1;
    final isAnomaly = flow['is_anomaly'] as bool? ?? false;
    final score = (flow['anomaly_score'] as num).toDouble();
    final port = flow['destination_port'] as String? ?? "—";
    final id = flow['id'] as int;

    final Color statusColor = isAttack ? AppColors.danger : AppColors.success;
    final String statusLabel = isAttack ? "ATTACK" : "BENIGN";

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        _showShapSheet(flow);
      },
      child: Container(
        margin: const EdgeInsets.only(top: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isAttack
              ? AppColors.dangerDim.withOpacity(0.3)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isAttack
                ? AppColors.danger.withOpacity(0.2)
                : AppColors.cardBorder,
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 60,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Text(
                "#$id",
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            SizedBox(
              width: 60,
              child: Text(
                port,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSecond,
                  fontSize: 12,
                ),
              ),
            ),
            SizedBox(
              width: 70,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (isAnomaly)
                    Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.only(right: 5),
                      decoration: const BoxDecoration(
                        color: AppColors.warning,
                        shape: BoxShape.circle,
                      ),
                    ),
                  Text(
                    score.toStringAsFixed(4),
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: isAnomaly
                          ? AppColors.warning
                          : AppColors.textMuted,
                      fontSize: 11,
                      fontWeight: isAnomaly
                          ? FontWeight.w700
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textMuted,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  // ─── SHAP Bottom Sheet ────────────────────────────────────────────────────────
  void _showShapSheet(Map<String, dynamic> flow) {
    final isAttack = (flow['prediction'] as int) == 1;
    final score = (flow['anomaly_score'] as num).toDouble();
    final port = flow['destination_port'] as String? ?? "N/A";
    final id = flow['id'] as int;
    final shapRaw = Map<String, dynamic>.from(flow['shap_values'] as Map);
    final shapValues = shapRaw.map(
      (k, v) => MapEntry(k, (v as num).toDouble()),
    );

    final sorted = shapValues.entries.toList()
      ..sort((a, b) => b.value.abs().compareTo(a.value.abs()));

    final maxAbs = sorted.isNotEmpty ? sorted.first.value.abs() : 1.0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.cardBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color:
                                (isAttack
                                        ? AppColors.danger
                                        : AppColors.success)
                                    .withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            isAttack ? "⚠ ATTACK FLOW" : "✅ BENIGN FLOW",
                            style: TextStyle(
                              color: isAttack
                                  ? AppColors.danger
                                  : AppColors.success,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          "Flow #$id",
                          style: const TextStyle(
                            color: AppColors.textSecond,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _sheetStat("Port", port, AppColors.primary),
                        const SizedBox(width: 20),
                        _sheetStat(
                          "Anomaly Score",
                          score.toStringAsFixed(5),
                          AppColors.warning,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Row(
                      children: [
                        Icon(
                          Icons.psychology_rounded,
                          color: AppColors.primary,
                          size: 16,
                        ),
                        SizedBox(width: 8),
                        Text(
                          "SHAP FEATURE IMPACT",
                          style: TextStyle(
                            color: AppColors.textSecond,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "Positive → pushes toward ATTACK   Negative → pushes toward BENIGN",
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 10,
                      ),
                    ),
                    const Divider(height: 20, color: AppColors.cardBorder),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: controller,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
                  itemCount: sorted.length,
                  itemBuilder: (_, i) {
                    final entry = sorted[i];
                    final val = entry.value;
                    final ratio = maxAbs == 0 ? 0.0 : (val / maxAbs);
                    final isPos = val > 0;
                    final color = isPos ? AppColors.danger : AppColors.success;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  entry.key,
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                val.toStringAsFixed(5),
                                style: TextStyle(
                                  color: color,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          SizedBox(
                            height: 10,
                            child: Row(
                              children: [
                                Expanded(
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                    child: isPos
                                        ? const SizedBox()
                                        : FractionallySizedBox(
                                            widthFactor: ratio.abs().clamp(
                                              0.0,
                                              1.0,
                                            ),
                                            child: Container(
                                              decoration: const BoxDecoration(
                                                color: AppColors.success,
                                                borderRadius:
                                                    BorderRadius.horizontal(
                                                      left: Radius.circular(4),
                                                    ),
                                              ),
                                            ),
                                          ),
                                  ),
                                ),
                                Container(
                                  width: 1,
                                  height: 10,
                                  color: AppColors.cardBorder,
                                ),
                                Expanded(
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: isPos
                                        ? FractionallySizedBox(
                                            widthFactor: ratio.abs().clamp(
                                              0.0,
                                              1.0,
                                            ),
                                            child: Container(
                                              decoration: const BoxDecoration(
                                                color: AppColors.danger,
                                                borderRadius:
                                                    BorderRadius.horizontal(
                                                      right: Radius.circular(4),
                                                    ),
                                              ),
                                            ),
                                          )
                                        : const SizedBox(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sheetStat(String label, String value, Color color) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
      ),
      Text(
        value,
        style: TextStyle(
          color: color,
          fontSize: 14,
          fontWeight: FontWeight.w800,
        ),
      ),
    ],
  );

  // ─── Ports Chart ──────────────────────────────────────────────────────────────
  Widget _portsChartCard() {
    if (sortedPorts.isEmpty) {
      return _card(
        "TOP ATTACK PORTS",
        Icons.router_outlined,
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Center(
            child: Text(
              "No port data available",
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
        ),
      );
    }
    final displayed = _filteredPorts;
    final maxVal = sortedPorts.isNotEmpty
        ? (sortedPorts.first.value as num).toDouble()
        : 1.0;

    return _card(
      "TOP ATTACK PORTS",
      Icons.router_outlined,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _toggle(_portsChart, (i) => setState(() => _portsChart = i)),
          const SizedBox(height: 14),
          const Text(
            "FILTER BY PORT",
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _chip(
                  "All",
                  _selectedPort == null,
                  () => setState(() => _selectedPort = null),
                ),
                ...sortedPorts.map(
                  (e) => _chip(
                    "Port ${e.key}",
                    _selectedPort == e.key,
                    () => setState(
                      () =>
                          _selectedPort = _selectedPort == e.key ? null : e.key,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            child: KeyedSubtree(
              key: ValueKey("$_portsChart-$_selectedPort"),
              child: displayed.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          "No data",
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                      ),
                    )
                  : _portsChart == 0
                  ? SizedBox(
                      height: 200,
                      child: InteractiveViewer(
                        scaleEnabled: true,
                        panEnabled: true,
                        minScale: 1,
                        maxScale: 4,
                        child: _pBar(displayed, maxVal),
                      ),
                    )
                  : _portsChart == 1
                  ? SizedBox(
                      height: 200,
                      child: InteractiveViewer(
                        scaleEnabled: true,
                        panEnabled: true,
                        minScale: 1,
                        maxScale: 4,
                        child: _pLine(displayed),
                      ),
                    )
                  : _pPie(displayed),
            ),
          ),
          const SizedBox(height: 8),
          _hint(),
        ],
      ),
    );
  }

  Widget _pBar(List<MapEntry<String, dynamic>> data, double mx) => BarChart(
    BarChartData(
      gridData: _grid(),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 44,
            getTitlesWidget: (v, _) => Text(
              v.toInt().toString(),
              style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
            ),
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (v, _) {
              final i = v.toInt();
              if (i < 0 || i >= data.length) return const SizedBox();
              return Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  data[i].key,
                  style: const TextStyle(
                    color: AppColors.textSecond,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            },
          ),
        ),
      ),
      barGroups: List.generate(data.length, (i) {
        final val = (data[i].value as num).toDouble();
        final intensity = mx > 0 ? val / mx : 0.0;
        return BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: val,
              width: 24,
              gradient: LinearGradient(
                colors: [
                  Color.lerp(AppColors.primary, AppColors.danger, intensity)!,
                  Color.lerp(
                    AppColors.primaryDim,
                    AppColors.dangerDim,
                    intensity,
                  )!,
                ],
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(8),
              ),
            ),
          ],
        );
      }),
    ),
  );

  Widget _pLine(List<MapEntry<String, dynamic>> data) => LineChart(
    LineChartData(
      gridData: _grid(),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 44,
            getTitlesWidget: (v, _) => Text(
              v.toInt().toString(),
              style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
            ),
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (v, _) {
              final i = v.toInt();
              if (i < 0 || i >= data.length) return const SizedBox();
              return Text(
                data[i].key,
                style: const TextStyle(
                  color: AppColors.textSecond,
                  fontSize: 10,
                ),
              );
            },
          ),
        ),
      ),
      lineBarsData: [
        _lb(
          List.generate(
            data.length,
            (i) => FlSpot(i.toDouble(), (data[i].value as num).toDouble()),
          ),
          AppColors.primary,
        ),
      ],
    ),
  );

  Widget _pPie(List<MapEntry<String, dynamic>> data) {
    const colors = [
      AppColors.primary,
      AppColors.danger,
      AppColors.success,
      AppColors.warning,
      AppColors.purple,
    ];
    final sum = data.fold<double>(0, (a, e) => a + (e.value as num).toDouble());
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sectionsSpace: 3,
                centerSpaceRadius: 36,
                sections: List.generate(data.length, (i) {
                  final val = (data[i].value as num).toDouble();
                  final pct = sum > 0
                      ? (val / sum * 100).toStringAsFixed(1)
                      : "0";
                  return PieChartSectionData(
                    value: val,
                    color: colors[i % colors.length],
                    radius: 60,
                    title: "$pct%",
                    titleStyle: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              data.length,
              (i) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _pl(
                  colors[i % colors.length],
                  "Port ${data[i].key}",
                  (data[i].value as num).toInt(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─── Summary ──────────────────────────────────────────────────────────────────
  Widget _summaryCard() => _card(
    "SUMMARY METRICS",
    Icons.table_rows_outlined,
    Column(
      children: [
        _row("Total Packets", (attacks + benign).toInt().toString()),
        _row("Attack Packets", attacks.toInt().toString()),
        _row("Benign Packets", benign.toInt().toString()),
        _row("Anomalies", anomalies.toInt().toString()),
        _row("Risk Score", "${(riskRatio * 100).toStringAsFixed(2)}%"),
        _row(
          "Top Attack Port",
          sortedPorts.isNotEmpty ? sortedPorts.first.key : "N/A",
        ),
        _row("Sampled Flows", flows.length.toString()),
        _row("Anomaly Buckets", anomalySeries.length.toString()),
      ],
    ),
  );

  Widget _row(String lbl, String val) => Container(
    padding: const EdgeInsets.symmetric(vertical: 12),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: AppColors.cardBorder)),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          lbl,
          style: const TextStyle(color: AppColors.textSecond, fontSize: 13),
        ),
        Text(
          val,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );

  // ─── Shared Helpers ───────────────────────────────────────────────────────────

  Widget _toggle(
    int current,
    ValueChanged<int> onChanged, {
    bool twoOnly = false,
  }) {
    final types = twoOnly ? _chartTypes.take(2).toList() : _chartTypes;
    final icons = [
      Icons.bar_chart_rounded,
      Icons.show_chart_rounded,
      Icons.pie_chart_rounded,
    ];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: List.generate(types.length, (i) {
          final sel = current == i;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                onChanged(i);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: sel ? AppColors.cardBorder : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      icons[i],
                      size: 14,
                      color: sel ? AppColors.textPrimary : AppColors.textMuted,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      types[i],
                      style: TextStyle(
                        color: sel
                            ? AppColors.textPrimary
                            : AppColors.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _switchAnim(int idx, List<Widget> charts) => AnimatedSwitcher(
    duration: const Duration(milliseconds: 350),
    switchInCurve: Curves.easeOutCubic,
    switchOutCurve: Curves.easeInCubic,
    transitionBuilder: (child, anim) => FadeTransition(
      opacity: anim,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.05, 0),
          end: Offset.zero,
        ).animate(anim),
        child: child,
      ),
    ),
    child: KeyedSubtree(
      key: ValueKey(idx),
      child: charts[idx.clamp(0, charts.length - 1)],
    ),
  );

  Widget _chip(String lbl, bool sel, VoidCallback onTap) => GestureDetector(
    onTap: () {
      HapticFeedback.selectionClick();
      onTap();
    },
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: sel ? AppColors.primaryDim : AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: sel ? AppColors.primary : Colors.transparent),
      ),
      child: Text(
        lbl,
        style: TextStyle(
          color: sel ? AppColors.primary : AppColors.textSecond,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );

  Widget _card(String title, IconData icon, Widget child) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.cardBorder),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 16),
            const SizedBox(width: 10),
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
        const Divider(color: AppColors.cardBorder, height: 20),
        child,
      ],
    ),
  );

  Widget _pl(Color c, String lbl, int count) => Row(
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: c,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
      const SizedBox(width: 10),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            lbl,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),
          Text(
            count.toString(),
            style: TextStyle(
              color: c,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    ],
  );

  Widget _dotLegend(Color c, String lbl) => Row(
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: c, shape: BoxShape.circle),
      ),
      const SizedBox(width: 6),
      Text(
        lbl,
        style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
      ),
    ],
  );

  Widget _hint({String msg = "📌 Pinch to zoom • Drag to scroll"}) => Text(
    msg,
    style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
    textAlign: TextAlign.center,
  );

  FlGridData _grid() => FlGridData(
    show: true,
    drawVerticalLine: false,
    getDrawingHorizontalLine: (_) =>
        const FlLine(color: AppColors.cardBorder, strokeWidth: 1),
  );

  BarChartGroupData _bg(int x, double y, Color c) => BarChartGroupData(
    x: x,
    barRods: [
      BarChartRodData(
        toY: y,
        width: 36,
        gradient: LinearGradient(
          colors: [c.withOpacity(0.7), c],
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
      ),
    ],
  );

  LineChartBarData _lb(List<FlSpot> spots, Color c) => LineChartBarData(
    spots: spots,
    color: c,
    barWidth: 2.5,
    isCurved: true,
    dotData: const FlDotData(show: false),
    belowBarData: BarAreaData(
      show: true,
      gradient: LinearGradient(
        colors: [c.withOpacity(0.2), c.withOpacity(0)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
    ),
  );
}
