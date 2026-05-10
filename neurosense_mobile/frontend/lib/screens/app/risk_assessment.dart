import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/profile_button.dart';

class RiskAssessmentScreen extends StatefulWidget {
  const RiskAssessmentScreen({super.key});
  @override
  State<RiskAssessmentScreen> createState() => _RiskAssessmentScreenState();
}

class _RiskAssessmentScreenState extends State<RiskAssessmentScreen> {
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
      final res = await ApiService.predict({
        'gender': _gender,
        'age': double.parse(_ageCtrl.text),
        'hypertension': _hypertension,
        'heart_disease': _heartDisease,
        'ever_married': _everMarried,
        'work_type': _workType,
        'residence_type': _residenceType,
        'avg_glucose_level': double.parse(_glucoseCtrl.text),
        'bmi': double.parse(_bmiCtrl.text),
        'smoking_status': _smokingStatus,
      });
      if (!mounted) return;
      Navigator.pushNamed(context, '/result', arguments: res);
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to get prediction. Check your connection.'),
            backgroundColor: AppColors.riskHigh),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _sectionTitle(String title) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 10),
        child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.primary)),
      );

  Widget _toggle(String label, int value, void Function(int) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        Row(
          children: [
            _ToggleChip(label: 'No',  selected: value == 0, onTap: () => onChanged(0)),
            const SizedBox(width: 12),
            _ToggleChip(label: 'Yes', selected: value == 1, onTap: () => onChanged(1)),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Risk Assessment'),
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
                    children: const [
                      Icon(Icons.info_outline, color: AppColors.primary, size: 20),
                      SizedBox(width: 10),
                      Expanded(child: Text('Fill in your details accurately for the best prediction.',
                          style: TextStyle(fontSize: 13, color: AppColors.textSecondary))),
                    ],
                  ),
                ),

                _sectionTitle('Personal Information'),
                DropdownButtonFormField<String>(
                  value: _gender,
                  decoration: const InputDecoration(labelText: 'Gender', prefixIcon: Icon(Icons.person_outline)),
                  items: ['Male', 'Female'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                  onChanged: (v) => setState(() => _gender = v!),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _ageCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Age', prefixIcon: Icon(Icons.cake_outlined)),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Enter your age';
                    final n = double.tryParse(v);
                    if (n == null || n < 1 || n > 120) return 'Enter a valid age';
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: _everMarried,
                  decoration: const InputDecoration(labelText: 'Ever Married', prefixIcon: Icon(Icons.favorite_outline)),
                  items: ['Yes', 'No'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                  onChanged: (v) => setState(() => _everMarried = v!),
                ),

                _sectionTitle('Work & Lifestyle'),
                DropdownButtonFormField<String>(
                  value: _workType,
                  decoration: const InputDecoration(labelText: 'Work Type', prefixIcon: Icon(Icons.work_outline)),
                  items: ['Private', 'Self-employed', 'Govt_job', 'children', 'Never_worked']
                      .map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                  onChanged: (v) => setState(() => _workType = v!),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: _residenceType,
                  decoration: const InputDecoration(labelText: 'Residence Type', prefixIcon: Icon(Icons.home_outlined)),
                  items: ['Urban', 'Rural'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                  onChanged: (v) => setState(() => _residenceType = v!),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: _smokingStatus,
                  decoration: const InputDecoration(labelText: 'Smoking Status', prefixIcon: Icon(Icons.smoking_rooms_outlined)),
                  items: ['never smoked', 'formerly smoked', 'smokes', 'Unknown']
                      .map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                  onChanged: (v) => setState(() => _smokingStatus = v!),
                ),

                _sectionTitle('Health Conditions'),
                _toggle('Hypertension', _hypertension, (v) => setState(() => _hypertension = v)),
                const SizedBox(height: 16),
                _toggle('Heart Disease', _heartDisease, (v) => setState(() => _heartDisease = v)),

                _sectionTitle('Medical Measurements'),
                TextFormField(
                  controller: _glucoseCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                      labelText: 'Avg Glucose Level (mg/dL)', prefixIcon: Icon(Icons.bloodtype_outlined)),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Enter glucose level';
                    if (double.tryParse(v) == null) return 'Enter a valid number';
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _bmiCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                      labelText: 'BMI (kg/m²)', prefixIcon: Icon(Icons.monitor_weight_outlined)),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Enter BMI';
                    if (double.tryParse(v) == null) return 'Enter a valid number';
                    return null;
                  },
                ),
                const SizedBox(height: 32),

                _loading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton.icon(
                        onPressed: _submit,
                        icon: const Icon(Icons.analytics_outlined),
                        label: const Text('Get My Risk Score'),
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
