import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show rootBundle;
import 'package:tflite_flutter/tflite_flutter.dart';

/// Raw inputs collected from the assess form — same 10 fields the backend's
/// PredictDto expected.
class PredictionInputs {
  final String gender;
  final double age;
  final int hypertension;
  final int heartDisease;
  final String everMarried;
  final String workType;
  final String residenceType;
  final double avgGlucoseLevel;
  final double bmi;
  final String smokingStatus;

  const PredictionInputs({
    required this.gender,
    required this.age,
    required this.hypertension,
    required this.heartDisease,
    required this.everMarried,
    required this.workType,
    required this.residenceType,
    required this.avgGlucoseLevel,
    required this.bmi,
    required this.smokingStatus,
  });
}

/// Stage labels for [PredictionException]. Each labels exactly one phase of
/// the predict pipeline so callers can pinpoint where things fell over.
class PredictStage {
  static const loadConfig       = 'load_config';      // rootBundle.loadString of the JSON
  static const parseConfig      = 'parse_config';     // jsonDecode + schema sanity
  static const loadModelBytes   = 'load_model_bytes'; // rootBundle.load of the .tflite
  static const createInterpreter= 'create_interpreter'; // tfLiteInterpreterCreate native call
  static const buildFeatures    = 'build_features';   // sklearn-equivalent transform
  static const runInference     = 'run_inference';    // interpreter.run
  static const decodeOutput     = 'decode_output';    // unwrap output tensor → probability
}

class PredictionException implements Exception {
  final String stage;
  final String message;
  final Object? cause;
  final StackTrace? causeStack;
  final Map<String, Object?> context;

  const PredictionException(
    this.stage,
    this.message, {
    this.cause,
    this.causeStack,
    this.context = const {},
  });

  @override
  String toString() {
    final buf = StringBuffer('[$stage] $message');
    if (context.isNotEmpty) {
      buf.writeln();
      context.forEach((k, v) => buf.writeln('  $k: $v'));
    }
    if (cause != null) {
      buf.writeln('  cause: ${cause.runtimeType}: $cause');
    }
    return buf.toString().trimRight();
  }
}

/// On-device stroke-risk prediction. Loads the TFLite model + the preprocessing
/// metadata exported from sklearn's training pipeline, applies the identical
/// transform, and runs inference.
class LocalPredictor {
  LocalPredictor._();
  static final LocalPredictor instance = LocalPredictor._();

  static const _kJsonAsset  = 'assets/mobile-model/neurosense_preproc.json';
  static const _kModelAsset = 'assets/mobile-model/neurosense_model.tflite';

  Interpreter? _interpreter;
  Map<String, dynamic>? _config;
  Future<void>? _loading;
  // Cached for diagnostics in error messages.
  int _modelByteLen = 0;
  String _modelMagic = '';
  List<int> _inputShape = const [];
  String _inputType = '';
  List<int> _outputShape = const [];
  String _outputType = '';

  Future<void> _ensureLoaded() {
    return _loading ??= _load();
  }

  Future<void> _load() async {
    // ── 1. Load preproc JSON ─────────────────────────────────────────────────
    String jsonStr;
    try {
      jsonStr = await rootBundle.loadString(_kJsonAsset);
      debugPrint('LocalPredictor: loaded $_kJsonAsset (${jsonStr.length} chars)');
    } catch (e, st) {
      throw PredictionException(
        PredictStage.loadConfig,
        'Could not load preproc JSON asset.',
        cause: e, causeStack: st,
        context: {'asset': _kJsonAsset},
      );
    }

    // ── 2. Parse JSON ────────────────────────────────────────────────────────
    try {
      _config = jsonDecode(jsonStr) as Map<String, dynamic>;
      // Sanity: required keys
      for (final k in const ['feature_order', 'encoder', 'power_transformer']) {
        if (!_config!.containsKey(k)) {
          throw FormatException('preproc JSON missing required key "$k"');
        }
      }
    } catch (e, st) {
      throw PredictionException(
        PredictStage.parseConfig,
        'preproc JSON is malformed or missing required keys.',
        cause: e, causeStack: st,
        context: {
          'json_first_120_chars': jsonStr.length > 120 ? '${jsonStr.substring(0, 120)}…' : jsonStr,
        },
      );
    }

    // ── 3. Load model bytes ──────────────────────────────────────────────────
    Uint8List modelBytes;
    try {
      final byteData = await rootBundle.load(_kModelAsset);
      modelBytes = byteData.buffer.asUint8List();
      _modelByteLen = modelBytes.length;
      _modelMagic = modelBytes.length >= 8
          ? String.fromCharCodes(modelBytes.sublist(4, 8))
          : '';
      debugPrint('LocalPredictor: loaded $_kModelAsset ($_modelByteLen bytes, magic="$_modelMagic")');
    } catch (e, st) {
      throw PredictionException(
        PredictStage.loadModelBytes,
        'Could not load .tflite asset bytes.',
        cause: e, causeStack: st,
        context: {'asset': _kModelAsset},
      );
    }
    if (_modelMagic != 'TFL3') {
      throw PredictionException(
        PredictStage.loadModelBytes,
        'Asset bytes are not a valid TFLite v3 file (magic mismatch).',
        context: {
          'asset': _kModelAsset,
          'bytes': _modelByteLen,
          'magic_seen': _modelMagic,
          'magic_expected': 'TFL3',
        },
      );
    }

    // ── 4. Create interpreter ────────────────────────────────────────────────
    try {
      _interpreter = Interpreter.fromBuffer(modelBytes);
    } catch (e, st) {
      throw PredictionException(
        PredictStage.createInterpreter,
        'TFLite native runtime rejected the model.',
        cause: e, causeStack: st,
        context: {
          'model_bytes': _modelByteLen,
          'magic': _modelMagic,
          'hint': 'Possible cause: model min_runtime_version newer than the bundled TF Lite runtime, '
                  'or unsupported op for the device. Try upgrading tflite_flutter or re-converting '
                  'with target_spec.supported_ops set to the basic ops set.',
        },
      );
    }

    // Cache tensor metadata for later diagnostic use.
    try {
      final inT  = _interpreter!.getInputTensor(0);
      final outT = _interpreter!.getOutputTensor(0);
      _inputShape  = List<int>.from(inT.shape);
      _inputType   = inT.type.toString();
      _outputShape = List<int>.from(outT.shape);
      _outputType  = outT.type.toString();
      debugPrint('LocalPredictor: model ready — input $_inputShape $_inputType, output $_outputShape $_outputType');
    } catch (e, st) {
      throw PredictionException(
        PredictStage.createInterpreter,
        'Interpreter created but tensor metadata could not be read.',
        cause: e, causeStack: st,
      );
    }
  }

  Future<Map<String, dynamic>> predict(PredictionInputs raw) async {
    await _ensureLoaded();

    // ── Build features ─────────────────────────────────────────────────────
    final List<double> features;
    try {
      features = _buildFeatureVector(raw);
    } catch (e, st) {
      throw PredictionException(
        PredictStage.buildFeatures,
        'Could not transform user inputs into model features.',
        cause: e, causeStack: st,
        context: _rawInputContext(raw),
      );
    }
    if (_inputShape.isNotEmpty && features.length != _inputShape.last) {
      throw PredictionException(
        PredictStage.buildFeatures,
        'Built feature vector width does not match the model input.',
        context: {
          'features_built': features.length,
          'input_shape':    _inputShape,
          'expected_width': _inputShape.last,
          'feature_order_len': (_config?['feature_order'] as List?)?.length,
        },
      );
    }

    // ── Run inference ──────────────────────────────────────────────────────
    final List<List<double>> output;
    try {
      output = List.generate(
        _outputShape.isNotEmpty ? _outputShape[0] : 1,
        (_) => List<double>.filled(
          _outputShape.length > 1 ? _outputShape[1] : 1, 0.0,
        ),
      );
      _interpreter!.run([features], output);
    } catch (e, st) {
      throw PredictionException(
        PredictStage.runInference,
        'TFLite interpreter.run() threw.',
        cause: e, causeStack: st,
        context: {
          'features_len':  features.length,
          'input_shape':   _inputShape,
          'input_type':    _inputType,
          'output_shape':  _outputShape,
          'output_type':   _outputType,
        },
      );
    }

    // ── Decode output ──────────────────────────────────────────────────────
    double probability;
    try {
      // [1,1] → sigmoid; [1,2] → softmax (positive class index 1).
      final row = output[0];
      probability = (row.length >= 2 ? row[1] : row[0]).clamp(0.0, 1.0);
      debugPrint('LocalPredictor: raw output=$row → probability=$probability');
    } catch (e, st) {
      throw PredictionException(
        PredictStage.decodeOutput,
        'Could not interpret output tensor.',
        cause: e, causeStack: st,
        context: {
          'output_shape': _outputShape,
          'raw_output':   output,
        },
      );
    }

    return {
      'probability':   probability,
      'riskBand':      _band(probability),
      'recommendation':_recommendation(probability),
    };
  }

  Map<String, Object?> _rawInputContext(PredictionInputs r) => {
    'age': r.age,
    'gender': r.gender,
    'hypertension': r.hypertension,
    'heart_disease': r.heartDisease,
    'avg_glucose_level': r.avgGlucoseLevel,
    'bmi': r.bmi,
    'smoking_status': r.smokingStatus,
    'ever_married': r.everMarried,
    'work_type': r.workType,
    'residence_type': r.residenceType,
  };

  // ── Feature engineering (mirrors neurosense.ipynb cell 67) ─────────────────
  List<double> _buildFeatureVector(PredictionInputs raw) {
    final featureOrder = (_config!['feature_order'] as List).cast<String>();
    final pt = _config!['power_transformer'] as Map<String, dynamic>;
    final ptColumns = (pt['columns'] as List).cast<String>();
    final ptLambdas = _toDoubles(pt['lambdas']);
    final ptMean    = _toDoubles(pt['mean']);
    final ptScale   = _toDoubles(pt['scale']);
    final encoder = _config!['encoder'] as Map<String, dynamic>;
    final encColumns    = (encoder['columns'] as List).cast<String>();
    final encCategories = (encoder['categories'] as List)
        .map((c) => (c as List).cast<String>())
        .toList();

    final age = raw.age;
    final glu = raw.avgGlucoseLevel;
    final bmi = raw.bmi;
    final hyp = raw.hypertension;
    final hd  = raw.heartDisease;
    final ageXHyp = age * hyp;
    final ageXHd  = age * hd;
    final gluXAge = glu * age / 100.0;
    final riskScore = hyp + hd;
    final smokingWasUnknown = raw.smokingStatus == 'Unknown' ? 1 : 0;

    final rawNumerics = <String, double>{
      'age': age,
      'avg_glucose_level': glu,
      'bmi': bmi,
      'age_x_hyp': ageXHyp,
      'age_x_hd':  ageXHd,
      'glu_x_age': gluXAge,
    };

    // Apply Yeo-Johnson + standardize per column.
    final transformed = <String, double>{};
    for (var i = 0; i < ptColumns.length; i++) {
      final col = ptColumns[i];
      final yj = _yeoJohnson(rawNumerics[col]!, ptLambdas[i]);
      transformed[col] = (yj - ptMean[i]) / ptScale[i];
    }

    // Categorical values fed to the encoder.
    final catValues = <String, String>{
      'gender':         raw.gender,
      'ever_married':   raw.everMarried,
      'work_type':      raw.workType,
      'residence_type': raw.residenceType,
      'smoking_status': raw.smokingStatus,  // 'Unknown' → all zeros (handle_unknown='ignore')
      'age_bin':        _ageBin(age),
      'glucose_cat':    _glucoseCat(glu),
      'bmi_cat':        _bmiCat(bmi),
    };

    final featureMap = <String, double>{};

    // Numerics (transformed)
    for (final col in ptColumns) {
      featureMap[col] = transformed[col]!;
    }
    // Passthrough binaries / counts
    featureMap['hypertension']        = hyp.toDouble();
    featureMap['heart_disease']       = hd.toDouble();
    featureMap['smoking_was_unknown'] = smokingWasUnknown.toDouble();
    featureMap['risk_score']          = riskScore.toDouble();
    // One-hot encode categoricals
    for (var i = 0; i < encColumns.length; i++) {
      final col  = encColumns[i];
      final cats = encCategories[i];
      final value = catValues[col];
      for (final cat in cats) {
        featureMap['${col}_$cat'] = (value == cat) ? 1.0 : 0.0;
      }
    }

    // Assemble in the exact order the model was trained on.
    return featureOrder.map((name) => featureMap[name] ?? 0.0).toList();
  }

  // ── Bins (pd.cut with right=True, mirrors notebook cell 67) ────────────────
  String _ageBin(double age) {
    if (age <= 30) return 'young';
    if (age <= 45) return 'adult';
    if (age <= 60) return 'middle';
    if (age <= 75) return 'senior';
    return 'elderly';
  }

  String _glucoseCat(double g) {
    if (g <= 99)  return 'normal';
    if (g <= 125) return 'prediabetic';
    return 'diabetic';
  }

  String _bmiCat(double b) {
    if (b <= 18.5) return 'under';
    if (b <= 25)   return 'normal';
    if (b <= 30)   return 'over';
    return 'obese';
  }

  // ── Yeo-Johnson power transform (sklearn formula) ──────────────────────────
  double _yeoJohnson(double x, double lambda) {
    const eps = 1e-19;
    if (x >= 0) {
      if (lambda.abs() < eps) return math.log(x + 1);
      return (math.pow(x + 1, lambda).toDouble() - 1) / lambda;
    } else {
      if ((2 - lambda).abs() < eps) return -math.log(-x + 1);
      return -(math.pow(-x + 1, 2 - lambda).toDouble() - 1) / (2 - lambda);
    }
  }

  // ── Risk band + recommendation (matches the previous backend behavior) ────
  String _band(double p) {
    if (p < 0.25) return 'LOW';
    if (p < 0.50) return 'MEDIUM';
    if (p < 0.75) return 'HIGH';
    return 'CRITICAL';
  }

  String _recommendation(double p) {
    if (p < 0.25) return 'Your stroke risk is low. Keep up healthy habits: stay active, eat well, and avoid smoking.';
    if (p < 0.50) return 'You have a moderate risk. Consider lifestyle changes: reduce salt intake, exercise regularly, and monitor your blood pressure.';
    if (p < 0.75) return 'Your risk is high. Please consult your General Practitioner soon to discuss your cardiovascular health and risk factors.';
    return 'Critical risk detected. Please seek medical attention immediately or call emergency services.';
  }

  List<double> _toDoubles(dynamic list) =>
      (list as List).map((e) => (e as num).toDouble()).toList();
}
