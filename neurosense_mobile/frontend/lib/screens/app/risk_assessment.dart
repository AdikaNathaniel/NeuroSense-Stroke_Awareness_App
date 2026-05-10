import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import '../../services/language_service.dart';
import '../../services/local_history.dart';
import '../../services/local_predictor.dart';
import '../../theme/app_theme.dart';
import '../../widgets/profile_button.dart';

class RiskAssessmentScreen extends StatefulWidget {
  const RiskAssessmentScreen({super.key});
  @override
  State<RiskAssessmentScreen> createState() => _RiskAssessmentScreenState();
}

class _RiskAssessmentScreenState extends State<RiskAssessmentScreen> with LanguageAware {
  final _formKey = GlobalKey<FormState>();
  final _ageCtrl      = TextEditingController();
  final _glucoseCtrl  = TextEditingController();
  final _bmiCtrl      = TextEditingController();

  String _gender        = 'Male';
  String _everMarried   = 'Yes';
  String _workType      = 'Private';
  String _residenceType = 'Urban';
  String _smokingStatus = 'never smoked';
  int _hypertension  = 0;
  int _heartDisease  = 0;
  bool _loading = false;

  @override
  void dispose() {
    _ageCtrl.dispose();
    _glucoseCtrl.dispose();
    _bmiCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final age = double.parse(_ageCtrl.text);
      final glu = double.parse(_glucoseCtrl.text);
      final bmi = double.parse(_bmiCtrl.text);
      final res = await LocalPredictor.instance.predict(PredictionInputs(
        gender: _gender,
        age: age,
        hypertension: _hypertension,
        heartDisease: _heartDisease,
        everMarried: _everMarried,
        workType: _workType,
        residenceType: _residenceType,
        avgGlucoseLevel: glu,
        bmi: bmi,
        smokingStatus: _smokingStatus,
      ));
      // Save to local history so the analytics tab can chart it.
      await LocalHistory.add({
        'gender': _gender,
        'age': age,
        'hypertension': _hypertension,
        'heart_disease': _heartDisease,
        'ever_married': _everMarried,
        'work_type': _workType,
        'residence_type': _residenceType,
        'avg_glucose_level': glu,
        'bmi': bmi,
        'smoking_status': _smokingStatus,
        'probability': res['probability'],
        'riskBand': res['riskBand'],
      });
      if (!mounted) return;
      Navigator.pushNamed(context, '/result', arguments: {
        ...res,
        'inputs': {
          'gender': _gender,
          'age': age,
          'hypertension': _hypertension,
          'heart_disease': _heartDisease,
          'avg_glucose_level': glu,
          'bmi': bmi,
          'smoking_status': _smokingStatus,
        },
      });
    } catch (e, st) {
      if (!mounted) return;
      _showPredictionErrorDialog(e, st);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showPredictionErrorDialog(Object error, StackTrace stack) {
    final isPredException = error is PredictionException;
    final stage = isPredException ? error.stage : 'unknown';
    final fullText = '$error\n\nStack:\n$stack';
    debugPrint('PREDICTION FAILED [$stage]\n$fullText');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
        contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
        actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: AppColors.riskHigh),
            const SizedBox(width: 10),
            Text(tr('Prediction failed'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.riskHigh.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(stage, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.riskHigh)),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 360),
          child: SingleChildScrollView(
            child: SelectableText(
              fullText,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 11.5, height: 1.4, color: AppColors.textPrimary),
            ),
          ),
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.copy, size: 16),
            label: Text(tr('Copy')),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: fullText));
              ScaffoldMessenger.of(ctx).showSnackBar(
                const SnackBar(content: Text('Error copied to clipboard'), duration: Duration(seconds: 2)),
              );
            },
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(tr('Close')),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 10),
        child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.primary)),
      );

  Widget _toggle(String labelKey, int value, void Function(int) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tr(labelKey), style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        Row(
          children: [
            _ToggleChip(label: tr('No'),  selected: value == 0, onTap: () => onChanged(0)),
            const SizedBox(width: 12),
            _ToggleChip(label: tr('Yes'), selected: value == 1, onTap: () => onChanged(1)),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Risk Assessment')),
        centerTitle: true,
        actions: const [ProfileIconButton()],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.divider)),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: AppColors.primary, size: 20),
                      const SizedBox(width: 10),
                      Expanded(child: Text(tr('Fill in your details accurately for the best prediction.'),
                          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary))),
                    ],
                  ),
                ),

                _sectionTitle(tr('Personal Information')),
                DropdownButtonFormField<String>(
                  value: _gender,
                  decoration: InputDecoration(labelText: tr('Gender'), prefixIcon: const Icon(Icons.person_outline)),
                  items: ['Male', 'Female'].map((v) => DropdownMenuItem(value: v, child: Text(tr(v)))).toList(),
                  onChanged: (v) => setState(() => _gender = v!),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _ageCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: tr('Age'), prefixIcon: const Icon(Icons.cake_outlined)),
                  validator: (v) {
                    if (v == null || v.isEmpty) return tr('Required');
                    final n = double.tryParse(v);
                    if (n == null || n < 1 || n > 120) return tr('Required');
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: _everMarried,
                  decoration: InputDecoration(labelText: tr('Ever Married'), prefixIcon: const Icon(Icons.favorite_outline)),
                  items: ['Yes', 'No'].map((v) => DropdownMenuItem(value: v, child: Text(tr(v)))).toList(),
                  onChanged: (v) => setState(() => _everMarried = v!),
                ),

                _sectionTitle(tr('Work & Lifestyle')),
                DropdownButtonFormField<String>(
                  value: _workType,
                  decoration: InputDecoration(labelText: tr('Work Type'), prefixIcon: const Icon(Icons.work_outline)),
                  items: ['Private', 'Self-employed', 'Govt_job', 'children', 'Never_worked']
                      .map((v) => DropdownMenuItem(value: v, child: Text(tr(v)))).toList(),
                  onChanged: (v) => setState(() => _workType = v!),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: _residenceType,
                  decoration: InputDecoration(labelText: tr('Residence Type'), prefixIcon: const Icon(Icons.home_outlined)),
                  items: ['Urban', 'Rural'].map((v) => DropdownMenuItem(value: v, child: Text(tr(v)))).toList(),
                  onChanged: (v) => setState(() => _residenceType = v!),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: _smokingStatus,
                  decoration: InputDecoration(labelText: tr('Smoking Status'), prefixIcon: const Icon(Icons.smoking_rooms_outlined)),
                  items: ['never smoked', 'formerly smoked', 'smokes', 'Unknown']
                      .map((v) => DropdownMenuItem(value: v, child: Text(tr(v)))).toList(),
                  onChanged: (v) => setState(() => _smokingStatus = v!),
                ),

                _sectionTitle(tr('Health Conditions')),
                _toggle('Hypertension', _hypertension, (v) => setState(() => _hypertension = v)),
                const SizedBox(height: 16),
                _toggle('Heart Disease', _heartDisease, (v) => setState(() => _heartDisease = v)),

                _sectionTitle(tr('Medical Measurements')),
                TextFormField(
                  controller: _glucoseCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                      labelText: tr('Avg Glucose Level (mg/dL)'), prefixIcon: const Icon(Icons.bloodtype_outlined)),
                  validator: (v) {
                    if (v == null || v.isEmpty) return tr('Required');
                    if (double.tryParse(v) == null) return tr('Required');
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _bmiCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                      labelText: tr('BMI (kg/m²)'), prefixIcon: const Icon(Icons.monitor_weight_outlined)),
                  validator: (v) {
                    if (v == null || v.isEmpty) return tr('Required');
                    if (double.tryParse(v) == null) return tr('Required');
                    return null;
                  },
                ),
                const SizedBox(height: 32),

                _loading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton.icon(
                        onPressed: _submit,
                        icon: const Icon(Icons.analytics_outlined),
                        label: Text(tr('Get My Risk Score')),
                      ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ToggleChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? AppColors.primary : AppColors.divider),
        ),
        child: Text(label,
            style: TextStyle(color: selected ? Colors.white : AppColors.textSecondary, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
