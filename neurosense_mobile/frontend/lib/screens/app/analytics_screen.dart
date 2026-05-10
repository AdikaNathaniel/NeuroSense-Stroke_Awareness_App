import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../services/language_service.dart';
import '../../services/local_history.dart';
import '../../theme/app_theme.dart';
import '../../widgets/profile_button.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});
  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> with LanguageAware {
  List<dynamic> _history = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    LocalHistory.revision.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    LocalHistory.revision.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await LocalHistory.getAll();
      if (mounted) setState(() { _history = data; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _error = 'Failed to load analytics.'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Analytics')),
        centerTitle: true,
        actions: const [ProfileIconButton()],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _errorState()
              : _history.isEmpty
                  ? _emptyState()
                  : _charts(),
    );
  }

  Widget _errorState() => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.wifi_off_rounded, size: 48, color: AppColors.textSecondary),
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _load, child: Text(tr('Retry'))),
        ]),
      );

  Widget _emptyState() => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), shape: BoxShape.circle),
            child: const Icon(Icons.bar_chart_rounded, size: 44, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          Text(tr('No data yet'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(tr('Complete your first risk assessment to see your personal analytics here.'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary, height: 1.5)),
          ),
        ]),
      );

  Widget _charts() {
    final latest = _history.last;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _statsRow(),
          const SizedBox(height: 20),
          _sectionHeader(tr('Risk Score Trend'), Icons.show_chart_rounded),
          const SizedBox(height: 12),
          _riskTrendChart(),
          const SizedBox(height: 24),
          _sectionHeader(tr('Risk Band Distribution'), Icons.pie_chart_rounded),
          const SizedBox(height: 12),
          _riskBandDonut(),
          const SizedBox(height: 24),
          _sectionHeader(tr('Vitals vs Healthy Range'), Icons.monitor_heart_rounded),
          const SizedBox(height: 12),
          _vitalsBarChart(latest),
          const SizedBox(height: 24),
          _sectionHeader(tr('Risk Factor Breakdown (Latest)'), Icons.donut_large_rounded),
          const SizedBox(height: 12),
          _riskFactorPie(latest),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ── Stats summary row ──────────────────────────────────────────────────────

  Widget _statsRow() {
    final count = _history.length;
    final probs = _history.map((h) => (h['probability'] as num).toDouble() * 100).toList();
    final avg   = probs.reduce((a, b) => a + b) / probs.length;
    final latest = probs.last;
    final trend  = probs.length > 1 ? latest - probs[probs.length - 2] : 0.0;

    return Row(children: [
      _statCard(tr('Assessments'), '$count', Icons.assignment_rounded, AppColors.primary),
      const SizedBox(width: 10),
      _statCard(tr('Avg Risk'), '${avg.toStringAsFixed(1)}%', Icons.analytics_rounded, AppColors.primaryLight),
      const SizedBox(width: 10),
      _statCard(tr('Trend'), '${trend >= 0 ? '+' : ''}${trend.toStringAsFixed(1)}%',
          trend <= 0 ? Icons.trending_down_rounded : Icons.trending_up_rounded,
          trend <= 0 ? AppColors.riskLow : AppColors.riskHigh),
    ]);
  }

  Widget _statCard(String label, String value, IconData icon, Color color) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
            Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          ]),
        ),
      );

  // ── Section header ─────────────────────────────────────────────────────────

  Widget _sectionHeader(String title, IconData icon) => Row(children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        ),
      ]);

  Widget _card(Widget child) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: child,
      );

  // ── 1. Line chart — Risk % trend over time ─────────────────────────────────

  Widget _riskTrendChart() {
    final spots = _history.asMap().entries.map((e) {
      final prob = (e.value['probability'] as num).toDouble() * 100;
      return FlSpot(e.key.toDouble(), prob);
    }).toList();

    return _card(SizedBox(
      height: 200,
      child: LineChart(LineChartData(
        minY: 0, maxY: 100,
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => Colors.white,
            tooltipBorder: const BorderSide(color: AppColors.divider, width: 1),
            tooltipRoundedRadius: 8,
            tooltipPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            getTooltipItems: (spots) => spots.map((s) => LineTooltipItem(
                  'Assessment #${s.x.toInt() + 1}\n${s.y.toStringAsFixed(1)}% risk',
                  const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600, fontSize: 12, height: 1.4),
                )).toList(),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(color: AppColors.divider, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 36,
            interval: 25,
            getTitlesWidget: (v, _) => Text('${v.toInt()}%',
                style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
          )),
          bottomTitles: AxisTitles(sideTitles: SideTitles(
            showTitles: true,
            interval: 1,
            getTitlesWidget: (v, _) {
              final i = v.toInt();
              if (i < 0 || i >= _history.length) return const SizedBox();
              return Text('#${i + 1}', style: const TextStyle(fontSize: 10, color: AppColors.textSecondary));
            },
          )),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: AppColors.primary,
            barWidth: 3,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                radius: 5,
                color: Colors.white,
                strokeWidth: 2.5,
                strokeColor: AppColors.primary,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [AppColors.primary.withOpacity(0.18), AppColors.primary.withOpacity(0.01)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      )),
    ));
  }

  // ── 2. Donut chart — Risk band distribution ────────────────────────────────

  Widget _riskBandDonut() {
    final counts = <String, int>{'LOW': 0, 'MEDIUM': 0, 'HIGH': 0, 'CRITICAL': 0};
    for (final h in _history) {
      final band = (h['riskBand'] as String?) ?? 'LOW';
      counts[band] = (counts[band] ?? 0) + 1;
    }

    final colors = {
      'LOW': AppColors.riskLow,
      'MEDIUM': AppColors.riskMedium,
      'HIGH': AppColors.riskHigh,
      'CRITICAL': AppColors.riskCritical,
    };

    final sections = counts.entries
        .where((e) => e.value > 0)
        .map((e) => PieChartSectionData(
              value: e.value.toDouble(),
              color: colors[e.key]!,
              title: '${e.value}',
              radius: 40,
              titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
            ))
        .toList();

    return _card(Row(children: [
      SizedBox(
        height: 150,
        width: 150,
        child: PieChart(PieChartData(
          sections: sections,
          centerSpaceRadius: 30,
          sectionsSpace: 3,
        )),
      ),
      const SizedBox(width: 22),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: counts.entries.map((e) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(children: [
              Container(width: 12, height: 12, decoration: BoxDecoration(color: colors[e.key]!, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Expanded(
                child: Text('${e.key}  ${e.value}x',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w500)),
              ),
            ]),
          )).toList(),
        ),
      ),
    ]));
  }

  // ── 3. Bar chart — BMI & Glucose vs healthy range ─────────────────────────

  Widget _vitalsBarChart(Map<String, dynamic> latest) {
    final bmi     = (latest['bmi'] as num?)?.toDouble() ?? 0;
    final glucose = (latest['avg_glucose_level'] as num?)?.toDouble() ?? 0;

    // Healthy reference midpoints: BMI 22, Glucose 85.
    // Reference uses a neutral light-blue so it never gets confused with the
    // user-value rod (which can be green/orange/red/blue depending on band).
    final referenceColor = AppColors.primary.withOpacity(0.22);
    final groups = [
      BarChartGroupData(x: 0, barRods: [
        BarChartRodData(toY: bmi, color: _bmiColor(bmi), width: 22, borderRadius: BorderRadius.circular(6)),
        BarChartRodData(toY: 22, color: referenceColor, width: 22, borderRadius: BorderRadius.circular(6)),
      ]),
      BarChartGroupData(x: 1, barRods: [
        BarChartRodData(toY: glucose, color: _glucoseColor(glucose), width: 22, borderRadius: BorderRadius.circular(6)),
        BarChartRodData(toY: 85, color: referenceColor, width: 22, borderRadius: BorderRadius.circular(6)),
      ]),
    ];

    return _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(
        height: 200,
        child: BarChart(BarChartData(
          barGroups: groups,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(color: AppColors.divider, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, _) => Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(v == 0 ? 'BMI' : 'Glucose',
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
              ),
            )),
            leftTitles: AxisTitles(sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              getTitlesWidget: (v, _) => Text(v.toInt().toString(),
                  style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
            )),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => Colors.white,
              tooltipBorder: const BorderSide(color: AppColors.divider, width: 1),
              tooltipRoundedRadius: 8,
              tooltipPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              getTooltipItem: (group, _, rod, rodIndex) {
                final metric = group.x == 0 ? tr('BMI') : tr('Glucose (mg/dL)');
                final isUserRod = rodIndex == 0;
                final label = isUserRod ? '${tr('Your value')}: $metric' : '${tr('Healthy reference')}: $metric';
                return BarTooltipItem(
                  '$label\n${rod.toY.toStringAsFixed(1)}',
                  const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600, fontSize: 12, height: 1.4),
                );
              },
            ),
          ),
        )),
      ),
      const SizedBox(height: 10),
      Wrap(
        spacing: 16,
        runSpacing: 6,
        children: [
          _legend(referenceColor, tr('Healthy reference')),
          _legend(AppColors.textSecondary, tr('Your value')),
        ],
      ),
    ]));
  }

  Color _bmiColor(double v) {
    if (v < 18.5) return AppColors.primaryLight;
    if (v < 25)   return AppColors.riskLow;
    if (v < 30)   return AppColors.riskMedium;
    return AppColors.riskHigh;
  }

  Color _glucoseColor(double v) {
    if (v < 100) return AppColors.riskLow;
    if (v < 126) return AppColors.riskMedium;
    return AppColors.riskHigh;
  }

  Widget _legend(Color color, String label) => Row(children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ]);

  // ── 4. Pie chart — Modifiable vs Non-modifiable risk factors ──────────────

  Widget _riskFactorPie(Map<String, dynamic> latest) {
    int modifiable = 0;
    int nonModifiable = 0;

    // Non-modifiable
    if ((latest['age'] as num? ?? 0) > 60) nonModifiable++;
    if ((latest['heart_disease'] as num? ?? 0) == 1) nonModifiable++;
    if ((latest['gender'] as String? ?? '') == 'Male') nonModifiable++;

    // Modifiable
    if ((latest['hypertension'] as num? ?? 0) == 1) modifiable++;
    if ((latest['bmi'] as num? ?? 0) > 25) modifiable++;
    if ((latest['avg_glucose_level'] as num? ?? 0) > 100) modifiable++;
    final smoking = latest['smoking_status'] as String? ?? '';
    if (smoking == 'smokes' || smoking == 'formerly smoked') modifiable++;

    final total = modifiable + nonModifiable;
    if (total == 0) {
      return _card(const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text('No elevated risk factors detected in your latest assessment.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, height: 1.5)),
        ),
      ));
    }

    final sections = [
      if (modifiable > 0)
        PieChartSectionData(
          value: modifiable.toDouble(),
          color: AppColors.riskMedium,
          title: '${((modifiable / total) * 100).toStringAsFixed(0)}%',
          radius: 65,
          titleStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
        ),
      if (nonModifiable > 0)
        PieChartSectionData(
          value: nonModifiable.toDouble(),
          color: AppColors.primary,
          title: '${((nonModifiable / total) * 100).toStringAsFixed(0)}%',
          radius: 65,
          titleStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
        ),
    ];

    return _card(Row(children: [
      SizedBox(
        height: 150,
        width: 150,
        child: PieChart(PieChartData(sections: sections, sectionsSpace: 3, centerSpaceRadius: 32)),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _pieLegend(AppColors.riskMedium, tr('Modifiable'), '$modifiable factor${modifiable != 1 ? 's' : ''}',
              '${tr('BMI')}, ${tr('Glucose').toLowerCase()}, ${tr('Hypertension').toLowerCase()}, ${tr('smokes').toLowerCase()}'),
          const SizedBox(height: 14),
          _pieLegend(AppColors.primary, tr('Non-Modifiable'), '$nonModifiable factor${nonModifiable != 1 ? 's' : ''}',
              '${tr('Age')}, ${tr('Gender').toLowerCase()}, ${tr('Heart Disease').toLowerCase()}'),
        ]),
      ),
    ]));
  }

  Widget _pieLegend(Color color, String title, String count, String sub) {
    // Split the comma-separated sub-label into individual tokens so we can let
    // them flow across lines independently — no single token is wide enough
    // to overflow, so two long items meeting (e.g. "hypertension,smoking")
    // get pushed to the next line automatically.
    final parts = sub.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Container(
              width: 12, height: 12,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            Text(count,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Wrap(
              spacing: 4,
              runSpacing: 2,
              children: List<Widget>.generate(parts.length, (i) {
                final isLast = i == parts.length - 1;
                return Text(
                  isLast ? parts[i] : '${parts[i]},',
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.4),
                );
              }),
            ),
          ]),
        ),
      ],
    );
  }
}
