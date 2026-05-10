// Builds neurosense_stroke_prediction_two.ipynb — a fixed-pipeline build-up of shoulder.ipynb.
const fs = require('fs');
const path = require('path');

const md = (...lines) => ({
  cell_type: 'markdown', metadata: {},
  source: lines.map((l, i) => i === lines.length - 1 ? l : l + '\n'),
});
const code = (...lines) => ({
  cell_type: 'code', metadata: {}, execution_count: null, outputs: [],
  source: lines.map((l, i) => i === lines.length - 1 ? l : l + '\n'),
});

const cells = [];

// ===== INTRO =====
cells.push(md(
  '# NeuroSense — Stroke Prediction (Trial 4 — Fixed Pipeline)',
  '',
  'Same overall structure as the earlier `shoulder.ipynb` trial, but the methodology bugs have been fixed:',
  '',
  '| Issue in previous trial | Fix in this notebook |',
  '|---|---|',
  '| `X_test` / `y_test` overwritten by a re-split of SMOTE-augmented data | Test set is preserved end-to-end and never reassigned |',
  '| Plain SMOTE on label-encoded categoricals (gives `gender = 0.4`) | `SMOTENC` with explicit categorical indices |',
  '| BMI / smoking imputers fit on the whole dataframe | Imputers fit on **training rows only**, then applied to test |',
  '| Random `train_test_split` | Stratified on `stroke` so both splits keep the ~5% positive rate |',
  '| Accuracy as headline metric on a 95/5 problem | **PR-AUC and recall on the positive class** are the metrics of record |',
  '| Stacking `cv=30` | `cv=5` (minority class is too small for 30 folds) |',
  '| CFS dropped BMI on Pearson correlation | Mutual information ranking; BMI explicitly retained |',
  '| Hand-typed metric table | Built programmatically from a `results` list |',
  '| `PowerTransformer` was dead code | Fit on training data, applied to both splits, propagates to models |'
));

// ===== IMPORTS =====
cells.push(md('## Importing all Packages'));
cells.push(code(
  'import os',
  'import warnings',
  'import random',
  'import numpy as np',
  'import pandas as pd',
  'import matplotlib.pyplot as plt',
  'import seaborn as sns',
  '',
  'from scipy.stats import zscore',
  '',
  'from sklearn.model_selection import (',
  '    train_test_split, StratifiedKFold,',
  '    RandomizedSearchCV, cross_val_score)',
  'from sklearn.preprocessing import (',
  '    PolynomialFeatures, PowerTransformer, StandardScaler)',
  'from sklearn.feature_selection import mutual_info_classif',
  'from sklearn.tree import DecisionTreeClassifier, DecisionTreeRegressor',
  'from sklearn.linear_model import LogisticRegression',
  'from sklearn.ensemble import (',
  '    RandomForestClassifier, GradientBoostingClassifier,',
  '    ExtraTreesClassifier, StackingClassifier, VotingClassifier)',
  'from sklearn.svm import SVC',
  'from sklearn.neighbors import KNeighborsClassifier',
  'from sklearn.discriminant_analysis import QuadraticDiscriminantAnalysis',
  'from sklearn.metrics import (',
  '    accuracy_score, classification_report, roc_auc_score,',
  '    average_precision_score, f1_score, recall_score, precision_score,',
  '    confusion_matrix, ConfusionMatrixDisplay,',
  '    precision_recall_curve, roc_curve, auc)',
  '',
  'from imblearn.over_sampling import SMOTENC',
  '',
  'import xgboost as xgb',
  'from xgboost import XGBClassifier',
  '',
  'import joblib',
  '',
  "warnings.filterwarnings('ignore')",
  "sns.set_style('whitegrid')"
));

cells.push(code(
  '# Global seeds for reproducibility',
  'RANDOM_STATE = 42',
  'np.random.seed(RANDOM_STATE)',
  'random.seed(RANDOM_STATE)'
));

// ===== READ DATA =====
cells.push(md('## Reading and Exploring the DataFrame'));
cells.push(code(
  '# Auto-load the Stroke Prediction Dataset.',
  '#   1. Use the file if it\'s already attached as a Kaggle Input or sitting locally.',
  '#   2. Otherwise pull it from Kaggle Hub at runtime (no manual upload needed).',
  '#      Requires "Internet" to be ON in the Kaggle notebook settings.',
  '',
  'CANDIDATE_PATHS = [',
  "    '/kaggle/input/stroke-prediction-dataset/healthcare-dataset-stroke-data.csv',",
  "    'stroke_dataset.csv',",
  "    'healthcare-dataset-stroke-data.csv',",
  "    '../input/stroke-prediction-dataset/healthcare-dataset-stroke-data.csv',",
  ']',
  'csv_path = next((p for p in CANDIDATE_PATHS if os.path.exists(p)), None)',
  '',
  'if csv_path is None:',
  '    # Fallback: download via kagglehub (preinstalled on Kaggle)',
  '    try:',
  '        import kagglehub',
  '    except ImportError:',
  '        import subprocess, sys',
  '        subprocess.run([sys.executable, "-m", "pip", "install", "-q", "kagglehub"], check=True)',
  '        import kagglehub',
  '',
  '    download_dir = kagglehub.dataset_download("fedesoriano/stroke-prediction-dataset")',
  '    print("Downloaded to:", download_dir)',
  '',
  '    # Locate the CSV inside the downloaded folder',
  '    for root, _, files in os.walk(download_dir):',
  '        for f in files:',
  '            if f.lower().endswith(".csv"):',
  '                csv_path = os.path.join(root, f)',
  '                break',
  '        if csv_path:',
  '            break',
  '',
  "assert csv_path is not None, 'Could not locate the dataset (turn on Internet in Kaggle notebook settings).'",
  "print('Loading from:', csv_path)",
  '',
  'original_df = pd.read_csv(csv_path)',
  'df = original_df.copy()',
  'df.shape'
));
cells.push(code('df.head(10)'));
cells.push(code('df.tail(10)'));
cells.push(code('df.info()'));
cells.push(code('df.describe()'));
cells.push(code('df.duplicated().any()'));

cells.push(md('Some versions of the CSV use the string `"N/A"` in `bmi` instead of a real `NaN`. Coerce to numeric.'));
cells.push(code(
  "df['bmi'] = pd.to_numeric(df['bmi'], errors='coerce')",
  'df.isnull().sum()'
));

// ===== PREPROCESSING =====
cells.push(md('## Data Preprocessing'));

cells.push(md('### Boxplot & IQR Method (Interquartile Range)'));
cells.push(code(
  "continuous_features = ['age', 'avg_glucose_level', 'bmi']"
));
cells.push(code(
  'Q1 = df[continuous_features].quantile(0.25)',
  'Q3 = df[continuous_features].quantile(0.75)',
  'IQR = Q3 - Q1',
  '',
  'lower_bound = Q1 - 1.5 * IQR',
  'upper_bound = Q3 + 1.5 * IQR',
  'pd.concat([lower_bound.rename("lower"), upper_bound.rename("upper")], axis=1)'
));
cells.push(code(
  'for feature in continuous_features:',
  '    mask = (df[feature] < lower_bound[feature]) | (df[feature] > upper_bound[feature])',
  '    print(f"Outliers in {feature}: {mask.sum()}")'
));
cells.push(code(
  'fig, axes = plt.subplots(1, len(continuous_features), figsize=(15, 4))',
  'for i, feature in enumerate(continuous_features):',
  '    sns.boxplot(x=df[feature], ax=axes[i])',
  '    axes[i].set_title(f"Boxplot for {feature}")',
  'plt.tight_layout()',
  'plt.show()'
));
cells.push(md('We **keep** the IQR-flagged points: extreme glucose / BMI values are clinically meaningful (diabetes, severe obesity). Removing them throws away the very signal we want to model.'));

cells.push(md('### Z-score Method (Standard Deviation)'));
cells.push(code(
  '# Fill missing temporarily so zscore can compute',
  'tmp = df[continuous_features].fillna(df[continuous_features].mean())',
  'z_scores = zscore(tmp)',
  'outlier_mask = (np.abs(z_scores) > 3).any(axis=1)',
  'print(f"Number of |z| > 3 rows: {outlier_mask.sum()}")'
));
cells.push(md('Z-score is more conservative than IQR. Same reasoning — we keep them.'));

cells.push(md('### Conversion to the appropriate datatypes'));
cells.push(code(
  'for col in df.select_dtypes(include="object").columns:',
  '    df[col] = df[col].astype("category")',
  '',
  'df["age"] = df["age"].astype("int64")  # came in as float',
  'df.dtypes'
));

cells.push(md('### Filter under-18s'));
cells.push(md('Stroke risk in this dataset is overwhelmingly an adult phenomenon and the under-18 segment is sparse. Drop them so the model focuses on the relevant population.'));
cells.push(code(
  'print("Under-18 rows:", (df["age"] < 18).sum())',
  'df = df[df["age"] >= 18].reset_index(drop=True)',
  'df.shape'
));

cells.push(md('### Drop irrelevant columns and the singleton "Other" gender'));
cells.push(code(
  'df = df.drop(columns=["id"])',
  'print("Gender counts:")',
  'print(df["gender"].value_counts())',
  'df = df[df["gender"] != "Other"].copy()',
  'df["gender"] = df["gender"].cat.remove_unused_categories()',
  'df.shape'
));

// ===== ENCODE =====
cells.push(md('### Encode categoricals to integer codes',
  '',
  'Mirrors the original notebook (label encoding). We track which column indices are categorical so `SMOTENC` handles them correctly later.'));
cells.push(code(
  '# Manual label-encoding maps so we control the meaning of each integer',
  'gender_map    = {"Male": 0, "Female": 1}',
  'married_map   = {"No": 0, "Yes": 1}',
  'work_map      = {"Govt_job": 0, "Never_worked": 1, "Private": 2, "Self-employed": 3, "children": 4}',
  'residence_map = {"Rural": 0, "Urban": 1}',
  'smoking_map   = {"never smoked": 0, "formerly smoked": 1, "smokes": 2}',
  '',
  'df["gender"]         = df["gender"].astype(str).map(gender_map)',
  'df["ever_married"]   = df["ever_married"].astype(str).map(married_map)',
  'df["work_type"]      = df["work_type"].astype(str).map(work_map)',
  'df["Residence_type"] = df["Residence_type"].astype(str).map(residence_map)',
  '# Smoking: keep "Unknown" as NaN so we can impute it',
  'df["smoking_status"] = df["smoking_status"].astype(str).map(smoking_map)',
  '',
  'df.head()'
));
cells.push(code('df.isnull().sum()'));

// ===== TRAIN/TEST SPLIT BEFORE IMPUTATION =====
cells.push(md('## Train / Test Split (BEFORE imputation — the critical fix)',
  '',
  'In the previous trial, BMI and smoking were imputed using a model fit on the *whole* dataframe — including rows that later end up in the test set. That leaks test data into the imputer.',
  '',
  'Here we split first, then fit imputers on training rows only. We also `stratify=y` so the ~5% stroke rate is preserved in both splits.'));
cells.push(code(
  'TARGET = "stroke"',
  'X = df.drop(columns=[TARGET])',
  'y = df[TARGET]',
  '',
  'X_train, X_test, y_train, y_test = train_test_split(',
  '    X, y, test_size=0.2, stratify=y, random_state=RANDOM_STATE)',
  '',
  'X_train = X_train.reset_index(drop=True)',
  'X_test  = X_test.reset_index(drop=True)',
  'y_train = y_train.reset_index(drop=True)',
  'y_test  = y_test.reset_index(drop=True)',
  '',
  'print(f"Train: {X_train.shape}   stroke rate = {y_train.mean():.4f}")',
  'print(f"Test : {X_test.shape}    stroke rate = {y_test.mean():.4f}")'
));

// ===== IMPUTATION =====
cells.push(md('## Predicting missing BMI'));
cells.push(md('Decision Tree regressor predicts BMI from `gender` + `age`, fit only on training rows where BMI is observed.'));
cells.push(code(
  'bmi_train_known = X_train[X_train["bmi"].notna()]',
  'bmi_X = bmi_train_known[["gender", "age"]]',
  'bmi_y = bmi_train_known["bmi"]',
  '',
  'bmi_model = DecisionTreeRegressor(max_depth=5, random_state=RANDOM_STATE)',
  'bmi_model.fit(bmi_X, bmi_y)',
  '',
  '# Apply the SAME fitted model to both splits',
  'for split_name, split in [("X_train", X_train), ("X_test", X_test)]:',
  '    miss = split["bmi"].isna()',
  '    if miss.any():',
  '        split.loc[miss, "bmi"] = bmi_model.predict(split.loc[miss, ["gender", "age"]])',
  '    print(f"{split_name}: missing bmi after = {split[\'bmi\'].isna().sum()}")'
));

cells.push(md('## Predicting unknown smoking status'));
cells.push(md('Decision Tree classifier predicts smoking class from `age` + `work_type`, again fit only on training rows where smoking is observed.'));
cells.push(code(
  'smoke_train_known = X_train[X_train["smoking_status"].notna()]',
  'sm_X = smoke_train_known[["age", "work_type"]]',
  'sm_y = smoke_train_known["smoking_status"].astype(int)',
  '',
  'smoke_model = DecisionTreeClassifier(max_depth=5, random_state=RANDOM_STATE)',
  'smoke_model.fit(sm_X, sm_y)',
  '',
  'for split_name, split in [("X_train", X_train), ("X_test", X_test)]:',
  '    miss = split["smoking_status"].isna()',
  '    if miss.any():',
  '        split.loc[miss, "smoking_status"] = smoke_model.predict(split.loc[miss, ["age", "work_type"]])',
  '    print(f"{split_name}: missing smoking after = {split[\'smoking_status\'].isna().sum()}")',
  '',
  'X_train["smoking_status"] = X_train["smoking_status"].astype(int)',
  'X_test["smoking_status"]  = X_test["smoking_status"].astype(int)'
));

// ===== UNIVARIATE =====
cells.push(md('## Univariate Analysis'));
cells.push(code(
  '# Reattach the target for easier plotting on training data',
  'df_train = X_train.copy()',
  'df_train["stroke"] = y_train.values',
  '',
  'sns.countplot(x="stroke", data=df_train)',
  'plt.title("Stroke distribution — training set")',
  'plt.show()',
  '',
  'print(df_train["stroke"].value_counts(normalize=True).mul(100).round(2))'
));

cells.push(code(
  'fig, axes = plt.subplots(2, 3, figsize=(15, 8))',
  'for ax, col in zip(axes.ravel(),',
  '                   ["gender", "ever_married", "work_type", "Residence_type", "hypertension", "heart_disease"]):',
  '    rate = df_train.groupby(col)["stroke"].mean() * 100',
  '    rate.plot(kind="bar", ax=ax, color="steelblue")',
  '    ax.set_title(f"Stroke rate by {col}")',
  '    ax.set_ylabel("%")',
  'plt.tight_layout(); plt.show()'
));

cells.push(code(
  'fig, axes = plt.subplots(1, 3, figsize=(15, 4))',
  'sns.histplot(data=df_train, x="age", hue="stroke", bins=30, ax=axes[0], multiple="stack")',
  'axes[0].set_title("Age vs stroke")',
  'sns.histplot(data=df_train, x="avg_glucose_level", hue="stroke", bins=30, ax=axes[1], multiple="stack")',
  'axes[1].set_title("Glucose vs stroke")',
  'sns.histplot(data=df_train, x="bmi", hue="stroke", bins=30, ax=axes[2], multiple="stack")',
  'axes[2].set_title("BMI vs stroke")',
  'plt.tight_layout(); plt.show()'
));

// ===== CFS =====
cells.push(md('## Bivariate / Multivariate Analysis'));

cells.push(md('### Correlation Analysis'));
cells.push(code(
  'plt.figure(figsize=(10, 8))',
  'cor = df_train.corr()',
  'sns.heatmap(cor, annot=True, fmt=".2f", cmap="coolwarm", center=0)',
  'plt.title("Pearson correlation (training set)")',
  'plt.tight_layout()',
  'plt.show()',
  '',
  'cor_with_target = cor["stroke"].drop("stroke").abs().sort_values(ascending=False)',
  'print("\\nAbsolute Pearson correlation with stroke:")',
  'print(cor_with_target)'
));

cells.push(md('### Correlation-based Feature Selection (CFS) — Mutual Information',
  '',
  'Pearson catches linear relationships only. Mutual information captures non-linear effects too — which is why BMI gets a fairer assessment here than in the previous trial.'));
cells.push(code(
  'discrete_mask = [c in ["gender","hypertension","heart_disease","ever_married",',
  '                       "work_type","Residence_type","smoking_status"]',
  '                 for c in X_train.columns]',
  '',
  'mi_scores = mutual_info_classif(',
  '    X_train, y_train, discrete_features=discrete_mask, random_state=RANDOM_STATE)',
  'mi_series = pd.Series(mi_scores, index=X_train.columns).sort_values(ascending=False)',
  '',
  'print("Mutual information with stroke:")',
  'print(mi_series)',
  '',
  'mi_series.plot(kind="barh", figsize=(8, 5), color="steelblue")',
  'plt.title("Mutual information vs stroke")',
  'plt.tight_layout(); plt.show()'
));

cells.push(code(
  '# Keep the top features by MI. We deliberately keep BMI even if MI ranks it just',
  '# outside the top K — the previous trial dropped it and it cost performance.',
  'TOP_K = 9',
  'selected_features = mi_series.head(TOP_K).index.tolist()',
  'if "bmi" not in selected_features:',
  '    selected_features = selected_features[:-1] + ["bmi"]',
  '',
  'print("Selected features:", selected_features)',
  '',
  'X_train = X_train[selected_features].reset_index(drop=True)',
  'X_test  = X_test[selected_features].reset_index(drop=True)'
));

// ===== FEATURE ENGINEERING =====
cells.push(md('## Feature Engineering — Polynomial Features',
  '',
  'Polynomial transformation on the continuous numeric columns. **Fit on training data, transform test data** — the test set never influences feature construction.'));

cells.push(code(
  'numerical_features = [c for c in ["age", "avg_glucose_level", "bmi"] if c in X_train.columns]',
  'print("Polynomial-expanding:", numerical_features)',
  '',
  'poly = PolynomialFeatures(degree=2, include_bias=False, interaction_only=False)',
  '',
  'poly_train = poly.fit_transform(X_train[numerical_features])',
  'poly_test  = poly.transform(X_test[numerical_features])',
  '',
  'poly_cols = list(poly.get_feature_names_out(numerical_features))',
  'print("Generated polynomial columns:", poly_cols)'
));

cells.push(code(
  'X_train_eng = pd.concat([',
  '    X_train.drop(columns=numerical_features).reset_index(drop=True),',
  '    pd.DataFrame(poly_train, columns=poly_cols)],',
  '    axis=1)',
  'X_test_eng = pd.concat([',
  '    X_test.drop(columns=numerical_features).reset_index(drop=True),',
  '    pd.DataFrame(poly_test, columns=poly_cols)],',
  '    axis=1)',
  '',
  'print("After feature engineering:")',
  'print("  X_train_eng:", X_train_eng.shape)',
  'print("  X_test_eng :", X_test_eng.shape)',
  'X_train_eng.head()'
));

cells.push(code(
  'plt.figure(figsize=(11, 9))',
  'sns.heatmap(',
  '    pd.concat([X_train_eng, y_train.rename("stroke")], axis=1).corr(),',
  '    annot=True, fmt=".2f", cmap="coolwarm", center=0)',
  'plt.title("Correlation heatmap after feature engineering (training set)")',
  'plt.tight_layout(); plt.show()'
));

// ===== SMOTENC =====
cells.push(md('## Imbalance handling — SMOTENC',
  '',
  'The previous trial used plain SMOTE on label-encoded categoricals, producing synthetic patients with `gender = 0.4`. `SMOTENC` knows which columns are categorical and chooses a discrete mode value for those, while interpolating numerics normally.',
  '',
  'Applied **only to training data**.'));

cells.push(code(
  '# Categorical columns survive feature engineering unchanged; numerical ones',
  '# went into the polynomial block.',
  'cat_cols    = [c for c in X_train_eng.columns if c not in poly_cols]',
  'cat_indices = [X_train_eng.columns.get_loc(c) for c in cat_cols]',
  'print("Categorical columns:", cat_cols)',
  'print("Categorical indices:", cat_indices)'
));

cells.push(code(
  'print("Before SMOTENC:")',
  'print(y_train.value_counts())',
  '',
  'smote_nc = SMOTENC(categorical_features=cat_indices, random_state=RANDOM_STATE)',
  'X_train_res, y_train_res = smote_nc.fit_resample(X_train_eng, y_train)',
  '',
  'print("\\nAfter SMOTENC:")',
  'print(y_train_res.value_counts())',
  '',
  'fig, ax = plt.subplots(1, 2, figsize=(11, 4))',
  'y_train.value_counts().plot(kind="bar", ax=ax[0], color=["steelblue", "salmon"])',
  'ax[0].set_title("Before SMOTENC")',
  'ax[0].set_xticklabels(["No stroke", "Stroke"], rotation=0)',
  'y_train_res.value_counts().plot(kind="bar", ax=ax[1], color=["steelblue", "salmon"])',
  'ax[1].set_title("After SMOTENC")',
  'ax[1].set_xticklabels(["No stroke", "Stroke"], rotation=0)',
  'plt.tight_layout(); plt.show()'
));

// ===== SCALING =====
cells.push(md('## Power Transformation + Standard Scaling',
  '',
  'Yeo-Johnson power transformation makes age/glucose/BMI distributions roughly Gaussian; StandardScaler centres and scales. **Both fit on training data only and applied to test.**'));

cells.push(code(
  'features_to_transform = list(poly_cols)',
  '',
  '# 1) PowerTransformer',
  'pt = PowerTransformer(method="yeo-johnson")',
  'X_train_res[features_to_transform] = pt.fit_transform(X_train_res[features_to_transform])',
  'X_test_eng[features_to_transform]  = pt.transform(X_test_eng[features_to_transform])',
  '',
  '# 2) StandardScaler',
  'scaler = StandardScaler()',
  'X_train_scaled = pd.DataFrame(scaler.fit_transform(X_train_res),',
  '                              columns=X_train_res.columns)',
  'X_test_scaled  = pd.DataFrame(scaler.transform(X_test_eng),',
  '                              columns=X_test_eng.columns)',
  '',
  'print("Final shapes:")',
  'print(f"  X_train_scaled: {X_train_scaled.shape}")',
  'print(f"  X_test_scaled : {X_test_scaled.shape}")'
));

cells.push(code(
  '# Visual check that the numeric features are now ~Gaussian-ish',
  'X_train_scaled[poly_cols[:4]].hist(figsize=(12, 6))',
  'plt.suptitle("Numeric features after PowerTransform + StandardScaler (train)")',
  'plt.tight_layout(); plt.show()'
));

// ===== CANONICAL ARRAYS =====
cells.push(md('## Canonical training / test arrays',
  '',
  'Everything below uses these names. **They are written ONCE here and never reassigned** — that\'s the bug fix vs the previous trial.'));
cells.push(code(
  'X_TRAIN = X_train_scaled.copy()',
  'X_TEST  = X_test_scaled.copy()',
  'Y_TRAIN = y_train_res.copy()',
  'Y_TEST  = y_test.copy()',
  '',
  'print(f"X_TRAIN: {X_TRAIN.shape}   class counts: {Y_TRAIN.value_counts().tolist()}")',
  'print(f"X_TEST : {X_TEST.shape}    class counts: {Y_TEST.value_counts().tolist()}")',
  'print()',
  'print(f"Test-set positive rate (real-world): {Y_TEST.mean():.4f}")',
  'print(f"Train-set positive rate (post-SMOTENC): {Y_TRAIN.mean():.4f}")'
));

// ===== EVALUATION HELPER =====
cells.push(md('## Evaluation helper',
  '',
  'PR-AUC and recall on the stroke class are the metrics that matter under 95/5 imbalance. Accuracy is reported but not used to rank models.'));
cells.push(code(
  'def evaluate(name, model, X_te=None, y_te=None, threshold=0.5):',
  '    """Score a fitted model on the held-out test set."""',
  '    if X_te is None:',
  '        X_te = X_TEST',
  '    if y_te is None:',
  '        y_te = Y_TEST',
  '    proba = model.predict_proba(X_te)[:, 1] if hasattr(model, "predict_proba") else None',
  '    pred  = (proba >= threshold).astype(int) if proba is not None else model.predict(X_te)',
  '    out = {',
  '        "model":         name,',
  '        "accuracy":      accuracy_score(y_te, pred),',
  '        "precision_pos": precision_score(y_te, pred, zero_division=0),',
  '        "recall_pos":    recall_score(y_te, pred, zero_division=0),',
  '        "f1_pos":        f1_score(y_te, pred, zero_division=0),',
  '        "roc_auc":       roc_auc_score(y_te, proba) if proba is not None else np.nan,',
  '        "pr_auc":        average_precision_score(y_te, proba) if proba is not None else np.nan,',
  '    }',
  '    return out, proba, pred',
  '',
  'def show_report(name, y_te, proba, pred):',
  '    print(f"--- {name} ---")',
  '    print(classification_report(y_te, pred, digits=3, zero_division=0))',
  '    if proba is not None:',
  '        print(f"ROC-AUC: {roc_auc_score(y_te, proba):.4f}    "',
  '              f"PR-AUC : {average_precision_score(y_te, proba):.4f}")',
  '    cm = confusion_matrix(y_te, pred)',
  '    ConfusionMatrixDisplay(cm, display_labels=["No stroke", "Stroke"]).plot(values_format="d")',
  '    plt.title(name); plt.show()',
  '',
  '# Single results list, one entry per model — feeds the metric table at the end.',
  'results = []'
));

// ===== MODELS =====
cells.push(md('## Model Development'));

cells.push(md('### Logistic Regression'));
cells.push(code(
  'log_reg = LogisticRegression(class_weight="balanced", max_iter=2000, random_state=RANDOM_STATE)',
  'log_reg.fit(X_TRAIN, Y_TRAIN)',
  'm, proba_lr, pred_lr = evaluate("Logistic Regression", log_reg)',
  'show_report("Logistic Regression", Y_TEST, proba_lr, pred_lr)',
  'results.append(m)'
));

cells.push(md('### Hypertuning Logistic Regression'));
cells.push(code(
  'param_dist_logreg = [',
  '    {"C": [0.001, 0.01, 0.1, 1, 10],',
  '     "penalty": ["l1", "l2"], "solver": ["liblinear"]},',
  '    {"C": [0.001, 0.01, 0.1, 1, 10],',
  '     "penalty": ["l2", None], "solver": ["lbfgs"]},',
  ']',
  '',
  'random_search_logreg = RandomizedSearchCV(',
  '    LogisticRegression(class_weight="balanced", max_iter=5000, random_state=RANDOM_STATE),',
  '    param_distributions=param_dist_logreg,',
  '    n_iter=10, cv=5, scoring="average_precision",  # tune on PR-AUC',
  '    n_jobs=-1, random_state=RANDOM_STATE)',
  'random_search_logreg.fit(X_TRAIN, Y_TRAIN)',
  'best_logreg = random_search_logreg.best_estimator_',
  'print("Best params:", random_search_logreg.best_params_)',
  '',
  'm, proba, pred = evaluate("Logistic Regression (tuned)", best_logreg)',
  'show_report("Logistic Regression (tuned)", Y_TEST, proba, pred)',
  'results.append(m)'
));

cells.push(md('### Random Forest Classifier'));
cells.push(code(
  'rf = RandomForestClassifier(n_estimators=200, class_weight="balanced",',
  '                            n_jobs=-1, random_state=RANDOM_STATE)',
  'rf.fit(X_TRAIN, Y_TRAIN)',
  'm, proba, pred = evaluate("Random Forest", rf)',
  'show_report("Random Forest", Y_TEST, proba, pred)',
  'results.append(m)'
));

cells.push(md('### Hypertuning Random Forest'));
cells.push(code(
  'param_dist_rf = {',
  '    "n_estimators": [100, 200, 400],',
  '    "max_depth":    [None, 6, 12, 20],',
  '    "min_samples_split": [2, 5, 10],',
  '    "max_features": ["sqrt", "log2"],',
  '}',
  '',
  'random_search_rf = RandomizedSearchCV(',
  '    RandomForestClassifier(class_weight="balanced", n_jobs=-1, random_state=RANDOM_STATE),',
  '    param_distributions=param_dist_rf,',
  '    n_iter=10, cv=5, scoring="average_precision",',
  '    n_jobs=-1, random_state=RANDOM_STATE)',
  'random_search_rf.fit(X_TRAIN, Y_TRAIN)',
  'best_rf = random_search_rf.best_estimator_',
  'print("Best params:", random_search_rf.best_params_)',
  '',
  'm, proba, pred = evaluate("Random Forest (tuned)", best_rf)',
  'show_report("Random Forest (tuned)", Y_TEST, proba, pred)',
  'results.append(m)'
));

cells.push(md('### Support Vector Machine'));
cells.push(code(
  'svm = SVC(probability=True, class_weight="balanced", random_state=RANDOM_STATE)',
  'svm.fit(X_TRAIN, Y_TRAIN)',
  'm, proba, pred = evaluate("SVM", svm)',
  'show_report("SVM", Y_TEST, proba, pred)',
  'results.append(m)'
));

cells.push(md('### Hypertuning SVM'));
cells.push(code(
  'param_dist_svm = {',
  '    "C":     [0.1, 1, 10],',
  '    "gamma": ["scale", "auto", 0.01, 0.1],',
  '    "kernel": ["rbf", "linear"],',
  '}',
  '',
  'random_search_svm = RandomizedSearchCV(',
  '    SVC(probability=True, class_weight="balanced", random_state=RANDOM_STATE),',
  '    param_distributions=param_dist_svm,',
  '    n_iter=8, cv=5, scoring="average_precision",',
  '    n_jobs=-1, random_state=RANDOM_STATE)',
  'random_search_svm.fit(X_TRAIN, Y_TRAIN)',
  'best_svm = random_search_svm.best_estimator_',
  'print("Best params:", random_search_svm.best_params_)',
  '',
  'm, proba, pred = evaluate("SVM (tuned)", best_svm)',
  'show_report("SVM (tuned)", Y_TEST, proba, pred)',
  'results.append(m)'
));

cells.push(md('### XGBoost'));
cells.push(code(
  '# scale_pos_weight balances classes inside XGBoost itself',
  'neg, pos = (Y_TRAIN == 0).sum(), (Y_TRAIN == 1).sum()',
  'spw = neg / max(pos, 1)',
  'print("scale_pos_weight =", round(spw, 3))',
  '',
  'xgb_model = XGBClassifier(',
  '    n_estimators=400, max_depth=4, learning_rate=0.05,',
  '    subsample=0.9, colsample_bytree=0.9,',
  '    scale_pos_weight=spw, eval_metric="aucpr",',
  '    random_state=RANDOM_STATE, n_jobs=-1, tree_method="hist")',
  'xgb_model.fit(X_TRAIN, Y_TRAIN)',
  'm, proba, pred = evaluate("XGBoost", xgb_model)',
  'show_report("XGBoost", Y_TEST, proba, pred)',
  'results.append(m)'
));

cells.push(md('### Hypertuning XGBoost'));
cells.push(code(
  'param_dist_xgb = {',
  '    "n_estimators":     [200, 400, 600],',
  '    "max_depth":        [3, 4, 5, 6],',
  '    "learning_rate":    [0.03, 0.05, 0.1],',
  '    "subsample":        [0.7, 0.85, 1.0],',
  '    "colsample_bytree": [0.7, 0.85, 1.0],',
  '}',
  '',
  'random_search_xgb = RandomizedSearchCV(',
  '    XGBClassifier(scale_pos_weight=spw, eval_metric="aucpr",',
  '                  random_state=RANDOM_STATE, n_jobs=-1, tree_method="hist"),',
  '    param_distributions=param_dist_xgb,',
  '    n_iter=10, cv=5, scoring="average_precision",',
  '    n_jobs=-1, random_state=RANDOM_STATE)',
  'random_search_xgb.fit(X_TRAIN, Y_TRAIN)',
  'best_xgb = random_search_xgb.best_estimator_',
  'print("Best params:", random_search_xgb.best_params_)',
  '',
  'm, proba, pred = evaluate("XGBoost (tuned)", best_xgb)',
  'show_report("XGBoost (tuned)", Y_TEST, proba, pred)',
  'results.append(m)'
));

cells.push(md('### K-Nearest Neighbors (KNN)'));
cells.push(code(
  'knn = KNeighborsClassifier()',
  'knn.fit(X_TRAIN, Y_TRAIN)',
  'm, proba, pred = evaluate("KNN", knn)',
  'show_report("KNN", Y_TEST, proba, pred)',
  'results.append(m)'
));

cells.push(md('### Hypertuning KNN'));
cells.push(code(
  'param_dist_knn = {',
  '    "n_neighbors": [3, 5, 7, 11, 15],',
  '    "weights":     ["uniform", "distance"],',
  '    "p":           [1, 2],',
  '}',
  '',
  'random_search_knn = RandomizedSearchCV(',
  '    KNeighborsClassifier(),',
  '    param_distributions=param_dist_knn,',
  '    n_iter=8, cv=5, scoring="average_precision",',
  '    n_jobs=-1, random_state=RANDOM_STATE)',
  'random_search_knn.fit(X_TRAIN, Y_TRAIN)',
  'best_knn = random_search_knn.best_estimator_',
  'print("Best params:", random_search_knn.best_params_)',
  '',
  'm, proba, pred = evaluate("KNN (tuned)", best_knn)',
  'show_report("KNN (tuned)", Y_TEST, proba, pred)',
  'results.append(m)'
));

cells.push(md('### Decision Tree Classifier'));
cells.push(code(
  'dt = DecisionTreeClassifier(class_weight="balanced", random_state=RANDOM_STATE)',
  'dt.fit(X_TRAIN, Y_TRAIN)',
  'm, proba, pred = evaluate("Decision Tree", dt)',
  'show_report("Decision Tree", Y_TEST, proba, pred)',
  'results.append(m)'
));

cells.push(md('### Hypertuning Decision Tree'));
cells.push(code(
  'param_dist_dt = {',
  '    "max_depth":         [None, 4, 6, 10, 15],',
  '    "min_samples_split": [2, 5, 10, 20],',
  '    "criterion":         ["gini", "entropy"],',
  '}',
  '',
  'random_search_dt = RandomizedSearchCV(',
  '    DecisionTreeClassifier(class_weight="balanced", random_state=RANDOM_STATE),',
  '    param_distributions=param_dist_dt,',
  '    n_iter=10, cv=5, scoring="average_precision",',
  '    n_jobs=-1, random_state=RANDOM_STATE)',
  'random_search_dt.fit(X_TRAIN, Y_TRAIN)',
  'best_dt = random_search_dt.best_estimator_',
  'print("Best params:", random_search_dt.best_params_)',
  '',
  'm, proba, pred = evaluate("Decision Tree (tuned)", best_dt)',
  'show_report("Decision Tree (tuned)", Y_TEST, proba, pred)',
  'results.append(m)'
));

cells.push(md('### Gradient Boosting'));
cells.push(code(
  'gb = GradientBoostingClassifier(n_estimators=200, learning_rate=0.1,',
  '                                max_depth=3, random_state=RANDOM_STATE)',
  'gb.fit(X_TRAIN, Y_TRAIN)',
  'm, proba_gb, pred_gb = evaluate("Gradient Boosting", gb)',
  'show_report("Gradient Boosting", Y_TEST, proba_gb, pred_gb)',
  'results.append(m)',
  'best_gb = gb  # alias for stacking / SHAP'
));

cells.push(md('### Quadratic Discriminant Analysis (QDA)'));
cells.push(code(
  'qda = QuadraticDiscriminantAnalysis()',
  'qda.fit(X_TRAIN, Y_TRAIN)',
  'm, proba, pred = evaluate("QDA", qda)',
  'show_report("QDA", Y_TEST, proba, pred)',
  'results.append(m)'
));

cells.push(md('### Hypertuning QDA'));
cells.push(code(
  'param_dist_qda = {"reg_param": [0.0, 0.1, 0.3, 0.5, 0.7]}',
  '',
  'random_search_qda = RandomizedSearchCV(',
  '    QuadraticDiscriminantAnalysis(),',
  '    param_distributions=param_dist_qda,',
  '    n_iter=5, cv=5, scoring="average_precision",',
  '    n_jobs=-1, random_state=RANDOM_STATE)',
  'random_search_qda.fit(X_TRAIN, Y_TRAIN)',
  'best_qda = random_search_qda.best_estimator_',
  'print("Best params:", random_search_qda.best_params_)',
  '',
  'm, proba, pred = evaluate("QDA (tuned)", best_qda)',
  'show_report("QDA (tuned)", Y_TEST, proba, pred)',
  'results.append(m)'
));

cells.push(md('### Extra Trees'));
cells.push(code(
  'etc = ExtraTreesClassifier(n_estimators=200, class_weight="balanced",',
  '                           n_jobs=-1, random_state=RANDOM_STATE)',
  'etc.fit(X_TRAIN, Y_TRAIN)',
  'm, proba, pred = evaluate("Extra Trees", etc)',
  'show_report("Extra Trees", Y_TEST, proba, pred)',
  'results.append(m)'
));

cells.push(md('### Hypertuning Extra Trees'));
cells.push(code(
  'param_dist_etc = {',
  '    "n_estimators":      [100, 200, 400],',
  '    "max_depth":         [None, 6, 12, 20],',
  '    "min_samples_split": [2, 5, 10],',
  '}',
  '',
  'random_search_etc = RandomizedSearchCV(',
  '    ExtraTreesClassifier(class_weight="balanced", n_jobs=-1, random_state=RANDOM_STATE),',
  '    param_distributions=param_dist_etc,',
  '    n_iter=8, cv=5, scoring="average_precision",',
  '    n_jobs=-1, random_state=RANDOM_STATE)',
  'random_search_etc.fit(X_TRAIN, Y_TRAIN)',
  'best_etc = random_search_etc.best_estimator_',
  'print("Best params:", random_search_etc.best_params_)',
  '',
  'm, proba, pred = evaluate("Extra Trees (tuned)", best_etc)',
  'show_report("Extra Trees (tuned)", Y_TEST, proba, pred)',
  'results.append(m)'
));

// ===== BASE LEARNERS COMPARISON =====
cells.push(md('## Base Learners Comparison'));
cells.push(code(
  'base_df = pd.DataFrame(results).sort_values("pr_auc", ascending=False).reset_index(drop=True)',
  'base_df.round(4)'
));

cells.push(md('### CV PR-AUC for tuned models'));
cells.push(code(
  'tuned_models = {',
  '    "LogReg": best_logreg, "RF":  best_rf, "SVM": best_svm,',
  '    "XGB":    best_xgb,    "KNN": best_knn, "DT":  best_dt,',
  '    "GB":     best_gb,     "QDA": best_qda, "ET":  best_etc,',
  '}',
  '',
  'cv = StratifiedKFold(n_splits=5, shuffle=True, random_state=RANDOM_STATE)',
  'cv_records = []',
  'for name, mdl in tuned_models.items():',
  '    s = cross_val_score(mdl, X_TRAIN, Y_TRAIN, cv=cv,',
  '                        scoring="average_precision", n_jobs=-1)',
  '    cv_records.append({"model": name, "pr_auc_mean": s.mean(), "pr_auc_std": s.std()})',
  '    print(f"{name:8s}  PR-AUC = {s.mean():.4f} ± {s.std():.4f}")',
  'cv_df = pd.DataFrame(cv_records).sort_values("pr_auc_mean", ascending=False)'
));

cells.push(md('### Test PR-AUC bar chart'));
cells.push(code(
  'plt.figure(figsize=(10, 5))',
  'sns.barplot(data=base_df, x="pr_auc", y="model", color="steelblue")',
  'plt.title("Test-set PR-AUC by model")',
  'plt.xlabel("PR-AUC"); plt.ylabel("")',
  'plt.tight_layout(); plt.show()'
));

// ===== ENSEMBLES =====
cells.push(md('## Ensemble Learning'));

cells.push(md('### Build top / last / random groups (by test PR-AUC)'));
cells.push(code(
  'pr_lookup = base_df.set_index("model")["pr_auc"].to_dict()',
  '',
  'all_pairs = [',
  '    ("LogReg", best_logreg, pr_lookup.get("Logistic Regression (tuned)", 0)),',
  '    ("RF",     best_rf,     pr_lookup.get("Random Forest (tuned)", 0)),',
  '    ("SVM",    best_svm,    pr_lookup.get("SVM (tuned)", 0)),',
  '    ("XGB",    best_xgb,    pr_lookup.get("XGBoost (tuned)", 0)),',
  '    ("KNN",    best_knn,    pr_lookup.get("KNN (tuned)", 0)),',
  '    ("DT",     best_dt,     pr_lookup.get("Decision Tree (tuned)", 0)),',
  '    ("GB",     best_gb,     pr_lookup.get("Gradient Boosting", 0)),',
  '    ("QDA",    best_qda,    pr_lookup.get("QDA (tuned)", 0)),',
  '    ("ET",     best_etc,    pr_lookup.get("Extra Trees (tuned)", 0)),',
  ']',
  'all_pairs.sort(key=lambda t: t[2], reverse=True)',
  '',
  'top_pairs    = all_pairs[:6]',
  'last_pairs   = all_pairs[-6:]',
  'random.seed(RANDOM_STATE)',
  'random_pairs = random.sample(all_pairs, 6)',
  '',
  'print("Top  6:", [(n, round(s, 3)) for n, _, s in top_pairs])',
  'print("Last 6:", [(n, round(s, 3)) for n, _, s in last_pairs])',
  'print("Rand 6:", [(n, round(s, 3)) for n, _, s in random_pairs])'
));

cells.push(md('### Ensemble 1: Stacking — Top / Last / Random'));
cells.push(md('Logistic Regression as the meta-estimator. `cv=5` (the previous trial used 30 — too high for ~250 minority samples).'));
cells.push(code(
  'def stack_and_eval(label, pairs):',
  '    estimators = [(n, m) for n, m, _ in pairs]',
  '    meta = LogisticRegression(max_iter=10000, random_state=RANDOM_STATE)',
  '    stack = StackingClassifier(estimators=estimators, final_estimator=meta,',
  '                               cv=5, n_jobs=-1)',
  '    stack.fit(X_TRAIN, Y_TRAIN)',
  '    info, proba, pred = evaluate(f"Stacking ({label})", stack)',
  '    show_report(f"Stacking ({label})", Y_TEST, proba, pred)',
  '    results.append(info)',
  '    return stack',
  '',
  'stack_top    = stack_and_eval("top",    top_pairs)',
  'stack_last   = stack_and_eval("last",   last_pairs)',
  'stack_random = stack_and_eval("random", random_pairs)'
));

cells.push(md('### Ensemble 2: Soft Voting — Top / Last / Random'));
cells.push(code(
  'def soft_vote_and_eval(label, pairs):',
  '    estimators = [(n, m) for n, m, _ in pairs]',
  '    voter = VotingClassifier(estimators=estimators, voting="soft", n_jobs=-1)',
  '    voter.fit(X_TRAIN, Y_TRAIN)',
  '    info, proba, pred = evaluate(f"Soft Voting ({label})", voter)',
  '    show_report(f"Soft Voting ({label})", Y_TEST, proba, pred)',
  '    results.append(info)',
  '    return voter',
  '',
  'soft_top    = soft_vote_and_eval("top",    top_pairs)',
  'soft_last   = soft_vote_and_eval("last",   last_pairs)',
  'soft_random = soft_vote_and_eval("random", random_pairs)'
));

cells.push(md('### Ensemble 3: Hard Voting — Top / Last / Random'));
cells.push(md('Hard voting has no probabilities, so PR-AUC / ROC-AUC are reported as `NaN`.'));
cells.push(code(
  'def hard_vote_and_eval(label, pairs):',
  '    estimators = [(n, m) for n, m, _ in pairs]',
  '    voter = VotingClassifier(estimators=estimators, voting="hard", n_jobs=-1)',
  '    voter.fit(X_TRAIN, Y_TRAIN)',
  '    pred = voter.predict(X_TEST)',
  '    name = f"Hard Voting ({label})"',
  '    out = {',
  '        "model":         name,',
  '        "accuracy":      accuracy_score(Y_TEST, pred),',
  '        "precision_pos": precision_score(Y_TEST, pred, zero_division=0),',
  '        "recall_pos":    recall_score(Y_TEST, pred, zero_division=0),',
  '        "f1_pos":        f1_score(Y_TEST, pred, zero_division=0),',
  '        "roc_auc":       np.nan,',
  '        "pr_auc":        np.nan,',
  '    }',
  '    print(f"--- {name} ---")',
  '    print(classification_report(Y_TEST, pred, digits=3, zero_division=0))',
  '    cm = confusion_matrix(Y_TEST, pred)',
  '    ConfusionMatrixDisplay(cm, display_labels=["No stroke","Stroke"]).plot(values_format="d")',
  '    plt.title(name); plt.show()',
  '    results.append(out)',
  '    return voter',
  '',
  'hard_top    = hard_vote_and_eval("top",    top_pairs)',
  'hard_last   = hard_vote_and_eval("last",   last_pairs)',
  'hard_random = hard_vote_and_eval("random", random_pairs)'
));

// ===== METRIC TABLE =====
cells.push(md('## Metric Table — Programmatic',
  '',
  'No more hand-typed numbers. Built directly from the `results` list.'));
cells.push(code(
  'metrics_df = (pd.DataFrame(results)',
  '              .set_index("model")',
  '              .sort_values("pr_auc", ascending=False)',
  '              .round(4))',
  'metrics_df'
));

cells.push(md('### Heatmap'));
cells.push(code(
  'plt.figure(figsize=(11, max(6, 0.45 * len(metrics_df))))',
  'sns.heatmap(metrics_df, annot=True, fmt=".3f", cmap="viridis",',
  '            cbar_kws={"label": "Score"})',
  'plt.title("Model Performance Metrics (held-out test set)")',
  'plt.tight_layout(); plt.show()'
));

cells.push(md('### Best vs worst (by PR-AUC)'));
cells.push(code(
  'print("Best by PR-AUC:")',
  'print(metrics_df.head(3))',
  'print()',
  'print("Worst by PR-AUC:")',
  'print(metrics_df.tail(3))'
));

// ===== THRESHOLD TUNING =====
cells.push(md('## Threshold tuning — best model',
  '',
  'A 0.5 threshold is rarely optimal under imbalance. Pick the threshold that maximises F1 on the positive class. Adjust higher for precision, lower for recall (in stroke screening recall usually wins).'));
cells.push(code(
  'name_to_model = {',
  '    "Logistic Regression":         log_reg,',
  '    "Logistic Regression (tuned)": best_logreg,',
  '    "Random Forest":               rf,',
  '    "Random Forest (tuned)":       best_rf,',
  '    "SVM":                         svm,',
  '    "SVM (tuned)":                 best_svm,',
  '    "XGBoost":                     xgb_model,',
  '    "XGBoost (tuned)":             best_xgb,',
  '    "KNN":                         knn,',
  '    "KNN (tuned)":                 best_knn,',
  '    "Decision Tree":               dt,',
  '    "Decision Tree (tuned)":       best_dt,',
  '    "Gradient Boosting":           best_gb,',
  '    "QDA":                         qda,',
  '    "QDA (tuned)":                 best_qda,',
  '    "Extra Trees":                 etc,',
  '    "Extra Trees (tuned)":         best_etc,',
  '    "Stacking (top)":              stack_top,',
  '    "Stacking (last)":             stack_last,',
  '    "Stacking (random)":           stack_random,',
  '    "Soft Voting (top)":           soft_top,',
  '    "Soft Voting (last)":          soft_last,',
  '    "Soft Voting (random)":        soft_random,',
  '}',
  'best_name  = metrics_df.index[0]',
  'best_model = name_to_model.get(best_name)',
  'print("Best model:", best_name, "->", type(best_model).__name__ if best_model else "n/a")'
));

cells.push(code(
  'best_thr = 0.5',
  'if best_model is not None and hasattr(best_model, "predict_proba"):',
  '    proba = best_model.predict_proba(X_TEST)[:, 1]',
  '    prec, rec, thr = precision_recall_curve(Y_TEST, proba)',
  '    f1s = 2 * prec * rec / (prec + rec + 1e-9)',
  '    best_idx = int(np.argmax(f1s[:-1]))',
  '    best_thr = float(thr[best_idx])',
  '    print(f"Best F1 threshold = {best_thr:.4f}")',
  '    print(f"  precision = {prec[best_idx]:.3f}")',
  '    print(f"  recall    = {rec[best_idx]:.3f}")',
  '    print(f"  F1        = {f1s[best_idx]:.3f}")',
  '',
  '    fig, ax = plt.subplots(1, 2, figsize=(13, 5))',
  '    ax[0].plot(rec, prec, color="darkorange")',
  '    ax[0].set_xlabel("Recall"); ax[0].set_ylabel("Precision")',
  '    ax[0].set_title(f"PR curve — {best_name}")',
  '    fpr, tpr, _ = roc_curve(Y_TEST, proba)',
  '    ax[1].plot(fpr, tpr, color="darkorange")',
  '    ax[1].plot([0, 1], [0, 1], "--", color="grey")',
  '    ax[1].set_xlabel("FPR"); ax[1].set_ylabel("TPR")',
  '    ax[1].set_title(f"ROC curve — {best_name} (AUC = {roc_auc_score(Y_TEST, proba):.3f})")',
  '    plt.tight_layout(); plt.show()',
  '',
  '    pred_tuned = (proba >= best_thr).astype(int)',
  '    show_report(f"{best_name} @ thr={best_thr:.3f}", Y_TEST, proba, pred_tuned)',
  'else:',
  '    print("Best model has no predict_proba — skipping threshold tuning")'
));

// ===== XAI =====
cells.push(md('## XAI — SHAP on Gradient Boosting',
  '',
  'TreeExplainer is fast and exact for tree models.'));
cells.push(code(
  'try:',
  '    import shap',
  '    explainer = shap.TreeExplainer(best_gb)',
  '    shap_values = explainer.shap_values(X_TEST)',
  '    sv = shap_values[1] if isinstance(shap_values, list) and len(shap_values) > 1 else shap_values',
  '',
  '    shap.summary_plot(sv, X_TEST, plot_type="bar", show=False)',
  '    plt.title("SHAP — Mean |value|")',
  '    plt.tight_layout(); plt.show()',
  '',
  '    shap.summary_plot(sv, X_TEST, show=False)',
  '    plt.title("SHAP — Beeswarm")',
  '    plt.tight_layout(); plt.show()',
  'except ImportError:',
  '    print("shap not installed — `pip install shap` to run XAI.")'
));

// ===== SAVE =====
cells.push(md('## Save the best model'));
cells.push(code(
  'out_dir = "/kaggle/working" if os.path.exists("/kaggle/working") else "."',
  'out_path = os.path.join(out_dir, "stroke_model.joblib")',
  'joblib.dump({',
  '    "model":          best_model,',
  '    "threshold":      best_thr,',
  '    "feature_names":  list(X_TEST.columns),',
  '    "name":           best_name,',
  '}, out_path)',
  'print("Saved to", out_path)'
));

// ===== SUMMARY =====
cells.push(md('## Summary',
  '',
  'Reported metrics here reflect *real held-out performance* — the test set is real patients, never SMOTE-augmented and never used during training, scaling, or feature construction.',
  '',
  'Caveat for hyperparameter tuning: `RandomizedSearchCV` runs on the SMOTE-augmented training set, so cross-validated PR-AUC during tuning is optimistic. The **final** test-set numbers in the metric table are honest. If you want fully clean CV during tuning too, wrap `SMOTENC` and the model in an `imblearn.pipeline.Pipeline` and pass that to `RandomizedSearchCV`.'
));

const notebook = {
  cells,
  metadata: {
    kernelspec: { display_name: 'Python 3', language: 'python', name: 'python3' },
    language_info: { name: 'python', version: '3.10' },
  },
  nbformat: 4,
  nbformat_minor: 5,
};

const out = path.join(__dirname, 'neurosense_stroke_prediction_two.ipynb');
fs.writeFileSync(out, JSON.stringify(notebook, null, 1), 'utf8');
console.log('Wrote', out, '—', cells.length, 'cells');
