"""Builds the NeuroSense stroke-prediction Kaggle notebook."""
import json
from pathlib import Path

def md(*lines):
    return {"cell_type": "markdown", "metadata": {}, "source": [l + "\n" for l in lines[:-1]] + [lines[-1]]}

def code(*lines):
    src = [l + "\n" for l in lines[:-1]] + [lines[-1]]
    return {"cell_type": "code", "metadata": {}, "execution_count": None, "outputs": [], "source": src}

cells = []

cells.append(md(
    "# NeuroSense — Stroke Prediction",
    "",
    "End-to-end pipeline on the Stroke Prediction Dataset.",
    "",
    "**Plan**",
    "1. Load + inspect data",
    "2. EDA",
    "3. Clean (BMI `N/A`, singleton gender, etc.)",
    "4. Preprocessing pipeline (encode + scale)",
    "5. Stratified train/test split",
    "6. Handle the 95/5 class imbalance with **three strategies**: `class_weight`, `scale_pos_weight`, and **SMOTE**",
    "7. Train Logistic Regression, Random Forest, XGBoost",
    "8. Compare on **ROC-AUC** and **PR-AUC** (PR-AUC is the right metric for imbalanced data)",
    "9. Tune the decision threshold for the best model",
    "10. Inspect feature importance and save the model"
))

cells.append(md("## 1. Imports"))
cells.append(code(
    "import os",
    "import warnings",
    "import numpy as np",
    "import pandas as pd",
    "import matplotlib.pyplot as plt",
    "import seaborn as sns",
    "",
    "from sklearn.model_selection import train_test_split, StratifiedKFold, cross_val_score",
    "from sklearn.preprocessing import StandardScaler, OneHotEncoder",
    "from sklearn.compose import ColumnTransformer",
    "from sklearn.pipeline import Pipeline",
    "from sklearn.impute import SimpleImputer",
    "from sklearn.linear_model import LogisticRegression",
    "from sklearn.ensemble import RandomForestClassifier",
    "from sklearn.metrics import (",
    "    roc_auc_score, average_precision_score, classification_report,",
    "    confusion_matrix, precision_recall_curve, roc_curve, f1_score,",
    "    ConfusionMatrixDisplay,",
    ")",
    "",
    "from imblearn.over_sampling import SMOTE",
    "from imblearn.pipeline import Pipeline as ImbPipeline",
    "",
    "import xgboost as xgb",
    "import joblib",
    "",
    "warnings.filterwarnings('ignore')",
    "sns.set_theme(style='whitegrid')",
    "RANDOM_STATE = 42"
))

cells.append(md("## 2. Load data",
                "",
                "Tries the standard Kaggle input path first, falls back to a local copy."))
cells.append(code(
    "CANDIDATE_PATHS = [",
    "    '/kaggle/input/stroke-prediction-dataset/healthcare-dataset-stroke-data.csv',",
    "    'healthcare-dataset-stroke-data.csv',",
    "    '../input/stroke-prediction-dataset/healthcare-dataset-stroke-data.csv',",
    "]",
    "csv_path = next((p for p in CANDIDATE_PATHS if os.path.exists(p)), None)",
    "assert csv_path is not None, 'CSV not found — attach the Stroke Prediction Dataset to this Kaggle notebook.'",
    "print('Loading from:', csv_path)",
    "",
    "df = pd.read_csv(csv_path)",
    "print('Shape:', df.shape)",
    "df.head()"
))

cells.append(md("## 3. Quick inspection"))
cells.append(code(
    "df.info()"
))
cells.append(code(
    "df.describe(include='all').T"
))
cells.append(code(
    "print('Missing per column:')",
    "print(df.isna().sum())",
    "print()",
    "print('Sentinel N/A in bmi (string):', (df['bmi'].astype(str) == 'N/A').sum())",
    "print('Unknown smoking_status:', (df['smoking_status'] == 'Unknown').sum())",
    "print()",
    "print('Target distribution:')",
    "print(df['stroke'].value_counts())",
    "print('Stroke rate: {:.2%}'.format(df['stroke'].mean()))"
))

cells.append(md("## 4. EDA"))
cells.append(code(
    "fig, ax = plt.subplots(1, 2, figsize=(11, 4))",
    "df['stroke'].value_counts().plot(kind='bar', ax=ax[0], color=['#4C72B0', '#C44E52'])",
    "ax[0].set_title('Class balance (0 = no stroke, 1 = stroke)')",
    "ax[0].set_xticklabels(['No stroke', 'Stroke'], rotation=0)",
    "",
    "sns.histplot(data=df, x='age', hue='stroke', bins=40, ax=ax[1], multiple='stack')",
    "ax[1].set_title('Age distribution by stroke')",
    "plt.tight_layout(); plt.show()"
))
cells.append(code(
    "tmp = df.copy()",
    "tmp['age_band'] = pd.cut(tmp['age'], bins=[0,20,30,40,50,60,70,80,90])",
    "rate = tmp.groupby('age_band')['stroke'].mean() * 100",
    "rate.plot(kind='bar', figsize=(9,4), color='#C44E52')",
    "plt.ylabel('Stroke rate (%)'); plt.title('Stroke rate by age band'); plt.show()"
))
cells.append(code(
    "fig, axes = plt.subplots(2, 2, figsize=(12, 8))",
    "for ax, col in zip(axes.ravel(), ['hypertension', 'heart_disease', 'ever_married', 'smoking_status']):",
    "    rate = df.groupby(col)['stroke'].mean() * 100",
    "    rate.plot(kind='bar', ax=ax, color='#4C72B0')",
    "    ax.set_title(f'Stroke rate by {col}')",
    "    ax.set_ylabel('%')",
    "plt.tight_layout(); plt.show()"
))

cells.append(md("## 5. Cleaning",
                "",
                "- Drop `id` (identifier, no signal)",
                "- Drop the single `Other` gender row (unsplittable in train/val)",
                "- Convert `bmi` `'N/A'` strings to numeric — impute median later in pipeline",
                "- Keep `Unknown` smoking_status as its own category (~30% of data — too much to drop)"))
cells.append(code(
    "df = df.drop(columns=['id'])",
    "df = df[df['gender'] != 'Other'].copy()",
    "df['bmi'] = pd.to_numeric(df['bmi'], errors='coerce')",
    "print('Shape after cleaning:', df.shape)",
    "print('NaN bmi after coercion:', df['bmi'].isna().sum())"
))

cells.append(md("## 6. Train/test split",
                "",
                "Stratify on `stroke` so both splits keep the ~5% positive rate."))
cells.append(code(
    "TARGET = 'stroke'",
    "X = df.drop(columns=[TARGET])",
    "y = df[TARGET]",
    "",
    "X_train, X_test, y_train, y_test = train_test_split(",
    "    X, y, test_size=0.2, stratify=y, random_state=RANDOM_STATE",
    ")",
    "print('Train:', X_train.shape, '  pos rate:', y_train.mean().round(4))",
    "print('Test :', X_test.shape, '  pos rate:', y_test.mean().round(4))"
))

cells.append(md("## 7. Preprocessing pipeline",
                "",
                "Numeric: median impute + scale.  Categorical: most-frequent impute + one-hot.",
                "Wrapped in a `ColumnTransformer` so it lives inside each model pipeline."))
cells.append(code(
    "numeric_features = ['age', 'avg_glucose_level', 'bmi']",
    "categorical_features = ['gender', 'ever_married', 'work_type', 'Residence_type', 'smoking_status']",
    "binary_features = ['hypertension', 'heart_disease']  # already 0/1",
    "",
    "numeric_pipe = Pipeline([",
    "    ('imputer', SimpleImputer(strategy='median')),",
    "    ('scaler', StandardScaler()),",
    "])",
    "",
    "categorical_pipe = Pipeline([",
    "    ('imputer', SimpleImputer(strategy='most_frequent')),",
    "    ('onehot', OneHotEncoder(handle_unknown='ignore', sparse_output=False)),",
    "])",
    "",
    "preprocessor = ColumnTransformer([",
    "    ('num', numeric_pipe, numeric_features),",
    "    ('cat', categorical_pipe, categorical_features),",
    "    ('bin', 'passthrough', binary_features),",
    "])"
))

cells.append(md("## 8. Evaluation helper",
                "",
                "PR-AUC is our primary metric — ROC-AUC can look optimistic on imbalanced data."))
cells.append(code(
    "def evaluate(name, model, X_te, y_te, threshold=0.5):",
    "    proba = model.predict_proba(X_te)[:, 1]",
    "    pred = (proba >= threshold).astype(int)",
    "    metrics = {",
    "        'model': name,",
    "        'roc_auc': roc_auc_score(y_te, proba),",
    "        'pr_auc':  average_precision_score(y_te, proba),",
    "        'f1':      f1_score(y_te, pred),",
    "        'recall_pos': (pred[y_te == 1] == 1).mean(),",
    "        'precision_pos': pred[pred == 1].mean() if pred.sum() else 0.0,",
    "        'threshold': threshold,",
    "    }",
    "    return metrics, proba, pred",
    "",
    "def show_report(name, y_te, proba, pred):",
    "    print(f'--- {name} ---')",
    "    print(classification_report(y_te, pred, digits=3))",
    "    print('ROC-AUC: {:.4f}   PR-AUC: {:.4f}'.format(",
    "        roc_auc_score(y_te, proba), average_precision_score(y_te, proba)))",
    "    cm = confusion_matrix(y_te, pred)",
    "    ConfusionMatrixDisplay(cm, display_labels=['No stroke','Stroke']).plot(values_format='d')",
    "    plt.title(name); plt.show()"
))

cells.append(md("## 9. Imbalance strategy A — class weighting",
                "",
                "Tell the model that mistakes on the minority class cost more."))
cells.append(code(
    "logreg_cw = Pipeline([",
    "    ('prep', preprocessor),",
    "    ('clf', LogisticRegression(max_iter=2000, class_weight='balanced', random_state=RANDOM_STATE)),",
    "])",
    "logreg_cw.fit(X_train, y_train)",
    "m, p, pr = evaluate('LogReg (class_weight)', logreg_cw, X_test, y_test)",
    "show_report('LogReg (class_weight)', y_test, p, pr)",
    "results = [m]"
))
cells.append(code(
    "rf_cw = Pipeline([",
    "    ('prep', preprocessor),",
    "    ('clf', RandomForestClassifier(",
    "        n_estimators=400, max_depth=None, n_jobs=-1,",
    "        class_weight='balanced', random_state=RANDOM_STATE)),",
    "])",
    "rf_cw.fit(X_train, y_train)",
    "m, p, pr = evaluate('RandomForest (class_weight)', rf_cw, X_test, y_test)",
    "show_report('RandomForest (class_weight)', y_test, p, pr)",
    "results.append(m)"
))

cells.append(md("## 10. Imbalance strategy B — `scale_pos_weight` (XGBoost)"))
cells.append(code(
    "neg, pos = (y_train == 0).sum(), (y_train == 1).sum()",
    "spw = neg / pos",
    "print('scale_pos_weight =', round(spw, 2))",
    "",
    "xgb_spw = Pipeline([",
    "    ('prep', preprocessor),",
    "    ('clf', xgb.XGBClassifier(",
    "        n_estimators=600, max_depth=4, learning_rate=0.05,",
    "        subsample=0.9, colsample_bytree=0.9,",
    "        scale_pos_weight=spw, eval_metric='aucpr',",
    "        random_state=RANDOM_STATE, n_jobs=-1, tree_method='hist')),",
    "])",
    "xgb_spw.fit(X_train, y_train)",
    "m, p, pr = evaluate('XGBoost (scale_pos_weight)', xgb_spw, X_test, y_test)",
    "show_report('XGBoost (scale_pos_weight)', y_test, p, pr)",
    "results.append(m)"
))

cells.append(md("## 11. Imbalance strategy C — SMOTE oversampling",
                "",
                "Synthesise new minority-class samples in the *training* fold only.",
                "Using `imblearn.Pipeline` so SMOTE runs after preprocessing and never touches the test set."))
cells.append(code(
    "logreg_smote = ImbPipeline([",
    "    ('prep', preprocessor),",
    "    ('smote', SMOTE(random_state=RANDOM_STATE)),",
    "    ('clf', LogisticRegression(max_iter=2000, random_state=RANDOM_STATE)),",
    "])",
    "logreg_smote.fit(X_train, y_train)",
    "m, p, pr = evaluate('LogReg + SMOTE', logreg_smote, X_test, y_test)",
    "show_report('LogReg + SMOTE', y_test, p, pr)",
    "results.append(m)"
))
cells.append(code(
    "rf_smote = ImbPipeline([",
    "    ('prep', preprocessor),",
    "    ('smote', SMOTE(random_state=RANDOM_STATE)),",
    "    ('clf', RandomForestClassifier(",
    "        n_estimators=400, n_jobs=-1, random_state=RANDOM_STATE)),",
    "])",
    "rf_smote.fit(X_train, y_train)",
    "m, p, pr = evaluate('RandomForest + SMOTE', rf_smote, X_test, y_test)",
    "show_report('RandomForest + SMOTE', y_test, p, pr)",
    "results.append(m)"
))
cells.append(code(
    "xgb_smote = ImbPipeline([",
    "    ('prep', preprocessor),",
    "    ('smote', SMOTE(random_state=RANDOM_STATE)),",
    "    ('clf', xgb.XGBClassifier(",
    "        n_estimators=600, max_depth=4, learning_rate=0.05,",
    "        subsample=0.9, colsample_bytree=0.9, eval_metric='aucpr',",
    "        random_state=RANDOM_STATE, n_jobs=-1, tree_method='hist')),",
    "])",
    "xgb_smote.fit(X_train, y_train)",
    "m, p, pr = evaluate('XGBoost + SMOTE', xgb_smote, X_test, y_test)",
    "show_report('XGBoost + SMOTE', y_test, p, pr)",
    "results.append(m)"
))

cells.append(md("## 12. Cross-validated PR-AUC for the leaders",
                "",
                "Single-split numbers wobble for the minority class — confirm with 5-fold stratified CV."))
cells.append(code(
    "cv = StratifiedKFold(n_splits=5, shuffle=True, random_state=RANDOM_STATE)",
    "for name, mdl in [",
    "    ('LogReg (class_weight)', logreg_cw),",
    "    ('XGBoost (scale_pos_weight)', xgb_spw),",
    "    ('XGBoost + SMOTE', xgb_smote),",
    "]:",
    "    scores = cross_val_score(mdl, X_train, y_train, cv=cv, scoring='average_precision', n_jobs=-1)",
    "    print(f'{name:30s}  PR-AUC = {scores.mean():.4f} ± {scores.std():.4f}')"
))

cells.append(md("## 13. Model comparison"))
cells.append(code(
    "results_df = pd.DataFrame(results).sort_values('pr_auc', ascending=False).reset_index(drop=True)",
    "results_df"
))
cells.append(code(
    "best_name = results_df.iloc[0]['model']",
    "name_to_model = {",
    "    'LogReg (class_weight)':       logreg_cw,",
    "    'RandomForest (class_weight)': rf_cw,",
    "    'XGBoost (scale_pos_weight)':  xgb_spw,",
    "    'LogReg + SMOTE':              logreg_smote,",
    "    'RandomForest + SMOTE':        rf_smote,",
    "    'XGBoost + SMOTE':             xgb_smote,",
    "}",
    "best_model = name_to_model[best_name]",
    "print('Best model:', best_name)"
))

cells.append(md("## 14. Threshold tuning",
                "",
                "Default 0.5 is rarely optimal under imbalance. Pick the threshold that maximises F1 on the positive class — adjust if your use case prefers recall over precision (in stroke screening you usually do)."))
cells.append(code(
    "proba = best_model.predict_proba(X_test)[:, 1]",
    "prec, rec, thr = precision_recall_curve(y_test, proba)",
    "f1s = 2 * prec * rec / (prec + rec + 1e-9)",
    "best_idx = np.argmax(f1s[:-1])  # last point has no threshold",
    "best_thr = thr[best_idx]",
    "print(f'Best F1 threshold = {best_thr:.3f}   F1 = {f1s[best_idx]:.3f}   '",
    "      f'precision = {prec[best_idx]:.3f}   recall = {rec[best_idx]:.3f}')",
    "",
    "fig, ax = plt.subplots(1, 2, figsize=(12, 4))",
    "ax[0].plot(rec, prec); ax[0].set_xlabel('Recall'); ax[0].set_ylabel('Precision')",
    "ax[0].set_title(f'PR curve — {best_name}')",
    "fpr, tpr, _ = roc_curve(y_test, proba)",
    "ax[1].plot(fpr, tpr); ax[1].plot([0,1],[0,1],'--', color='grey')",
    "ax[1].set_xlabel('FPR'); ax[1].set_ylabel('TPR'); ax[1].set_title('ROC curve')",
    "plt.tight_layout(); plt.show()"
))
cells.append(code(
    "pred_tuned = (proba >= best_thr).astype(int)",
    "show_report(f'{best_name} @ thr={best_thr:.3f}', y_test, proba, pred_tuned)"
))

cells.append(md("## 15. Feature importance",
                "",
                "Pull names out of the fitted `ColumnTransformer` and rank features."))
cells.append(code(
    "fitted_prep = best_model.named_steps['prep']",
    "feature_names = (",
    "    numeric_features",
    "    + list(fitted_prep.named_transformers_['cat'].named_steps['onehot'].get_feature_names_out(categorical_features))",
    "    + binary_features",
    ")",
    "",
    "clf = best_model.named_steps['clf']",
    "if hasattr(clf, 'feature_importances_'):",
    "    importances = clf.feature_importances_",
    "elif hasattr(clf, 'coef_'):",
    "    importances = np.abs(clf.coef_[0])",
    "else:",
    "    importances = None",
    "",
    "if importances is not None:",
    "    imp = pd.Series(importances, index=feature_names).sort_values(ascending=True).tail(15)",
    "    imp.plot(kind='barh', figsize=(8,6), color='#4C72B0')",
    "    plt.title(f'Top features — {best_name}'); plt.tight_layout(); plt.show()",
    "else:",
    "    print('Model does not expose feature importances.')"
))

cells.append(md("## 16. Save the model",
                "",
                "Saved as `stroke_model.joblib`. On Kaggle, write to `/kaggle/working/` so it appears as an output artifact."))
cells.append(code(
    "out_dir = '/kaggle/working' if os.path.exists('/kaggle/working') else '.'",
    "out_path = os.path.join(out_dir, 'stroke_model.joblib')",
    "joblib.dump({'model': best_model, 'threshold': float(best_thr), 'name': best_name}, out_path)",
    "print('Saved to', out_path)"
))

cells.append(md("## 17. Inference example"))
cells.append(code(
    "sample = X_test.iloc[:5].copy()",
    "proba_sample = best_model.predict_proba(sample)[:, 1]",
    "pred_sample = (proba_sample >= best_thr).astype(int)",
    "out = sample.assign(stroke_proba=proba_sample.round(4), stroke_pred=pred_sample, stroke_true=y_test.iloc[:5].values)",
    "out"
))

notebook = {
    "cells": cells,
    "metadata": {
        "kernelspec": {"display_name": "Python 3", "language": "python", "name": "python3"},
        "language_info": {"name": "python", "version": "3.10"},
    },
    "nbformat": 4,
    "nbformat_minor": 5,
}

out = Path(__file__).parent / "neurosense_stroke_prediction.ipynb"
out.write_text(json.dumps(notebook, indent=1), encoding="utf-8")
print("Wrote", out, "—", len(cells), "cells")
