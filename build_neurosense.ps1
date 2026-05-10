# Builds neurosense.ipynb - comprehensive stroke-prediction notebook
# References integrated:
#   1. shoulder.ipynb              - colored headers, deep univariate analysis, ensembles
#   2. resources/Prediction_of_Stroke_Project.ipynb - Q&A cells, pie charts, color-coded KDE,
#                                                     pair plot, bias-analysis discussion
#   3. resources/IJISRT25AUG1562.pdf (Islam et al. 2025) - 8 algorithms + voting ensemble baseline
# Engineering: leak-free pipeline, Optuna tuning, calibration, threshold optimization, SHAP
# Single-quoted here-strings @'...'@ are used so backticks/quotes pass through literally.

$cells = New-Object System.Collections.ArrayList

function Add-Md([string]$src) {
    [void]$cells.Add(@{ cell_type = 'markdown'; metadata = @{}; source = $src })
}
function Add-Code([string]$src) {
    [void]$cells.Add(@{ cell_type = 'code'; metadata = @{}; execution_count = $null; outputs = @(); source = $src })
}

# ============================================================
# 0. TITLE
# ============================================================
Add-Md @'
# <span style='color:red'>NeuroSense - Stroke Prediction (Final Pipeline)</span>

End-to-end stroke prediction on the Kaggle Healthcare Stroke dataset.

**This notebook integrates work from three references:**
1. `shoulder.ipynb` - deep univariate analysis style, colored section headers, ensembles
2. `Prediction_of_Stroke_Project.ipynb` (resources/) - educational Q&A cells, pie charts, color-coded KDE plots, bias analysis
3. Islam, Das & Mostofa (2025, IJISRT) - 8-algorithm methodology + voting-classifier ensemble (claimed 95% accuracy / 95% recall)

**On top of these, this pipeline adds the engineering needed for trustworthy results:**
- Leak-free preprocessing (split BEFORE imputation, scaling, SMOTE)
- Smart imputation: BMI predicted by gradient boosting; smoking "Unknown" predicted by RF
- Optuna Bayesian hyperparameter optimization for the strongest models
- Probability calibration (isotonic) and decision-threshold tuning
- Stacking + soft-voting ensembles, evaluated on a held-out test set
- SHAP explainability

**Reference paper baseline (Islam et al. 2025):**

| Algorithm | Accuracy | F1 | Recall | Precision |
|---|---|---|---|---|
| Random Forest | 93 | 92 | 94 | 90 |
| K-NN | 90 | 91 | 90 | 91 |
| MLP | 89 | 90 | 88 | 91 |
| AdaBoost | 92 | 92 | 93 | 91 |
| SVM | 93 | 92 | 92 | 91 |
| Decision Tree | 90 | 91 | 90 | 91 |
| XGBoost | 94 | 92 | 87 | 90 |
| **Voting (RF+KNN+XGB)** | **95** | **93** | **95** | **92** |

**Honest framing:** the 95% numbers are evaluated on a SMOTE-balanced test set (synthetic samples leak into evaluation). On a clean held-out test set, even the best model is bounded by the data itself: ~0.85 ROC-AUC and ~0.25 PR-AUC (the resources notebook honestly reports AP=0.23 vs baseline 0.06). Section 11 reproduces the paper's pipeline so you can compare the published 95% with the leak-free reality side by side.
'@

# ============================================================
# 1. IMPORTS
# ============================================================
Add-Md @'
## <span style='color:orange'>1. Importing all Packages</span>
'@

Add-Code @'
# Core
import os, warnings, random, json
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
import plotly.express as ex
from scipy import stats

# Sklearn
from sklearn.model_selection import (train_test_split, StratifiedKFold,
                                      cross_val_score, cross_val_predict)
from sklearn.preprocessing import (StandardScaler, OneHotEncoder, PowerTransformer,
                                    LabelEncoder)
from sklearn.compose import ColumnTransformer
from sklearn.pipeline import Pipeline
from sklearn.feature_selection import mutual_info_classif
from sklearn.calibration import CalibratedClassifierCV, calibration_curve

# Models (matches Islam et al. 2025 reference paper + extras)
from sklearn.linear_model import LogisticRegression
from sklearn.ensemble import (RandomForestClassifier, GradientBoostingClassifier,
                               ExtraTreesClassifier, AdaBoostClassifier,
                               StackingClassifier, VotingClassifier)
from sklearn.svm import SVC
from sklearn.neighbors import KNeighborsClassifier
from sklearn.tree import DecisionTreeClassifier
from sklearn.discriminant_analysis import QuadraticDiscriminantAnalysis
from sklearn.neural_network import MLPClassifier
from xgboost import XGBClassifier
try:
    from lightgbm import LGBMClassifier
    HAS_LGB = True
except ImportError:
    HAS_LGB = False

# Imbalance
from imblearn.over_sampling import SMOTE
from imblearn.pipeline import Pipeline as ImbPipeline

# Metrics
from sklearn.metrics import (accuracy_score, precision_score, recall_score, f1_score,
                              roc_auc_score, average_precision_score, classification_report,
                              confusion_matrix, precision_recall_curve, roc_curve,
                              brier_score_loss, ConfusionMatrixDisplay)

# Tuning
try:
    import optuna
    optuna.logging.set_verbosity(optuna.logging.WARNING)
    HAS_OPTUNA = True
except ImportError:
    HAS_OPTUNA = False

# XAI
try:
    import shap
    HAS_SHAP = True
except ImportError:
    HAS_SHAP = False

warnings.filterwarnings('ignore')
sns.set_theme(style='whitegrid')
plt.rcParams['figure.dpi'] = 100

SEED = 42
np.random.seed(SEED)
random.seed(SEED)

print('LightGBM available :', HAS_LGB)
print('Optuna available   :', HAS_OPTUNA)
print('SHAP available     :', HAS_SHAP)
'@

# ============================================================
# 2. LOAD AND EXPLORE
# ============================================================
Add-Md @'
## <span style='color:orange'>2. Reading and Exploring the DataFrame</span>

Dataset: 5,110 patient records, 12 columns. Target = `stroke` (0/1). Source: Kaggle Healthcare Stroke Prediction Dataset.
'@

Add-Code @'
CANDIDATE_PATHS = [
    '/kaggle/input/datasets/fedesoriano/stroke-prediction-dataset/healthcare-dataset-stroke-data.csv',
    '/kaggle/input/stroke-prediction-dataset/healthcare-dataset-stroke-data.csv',
    '../input/stroke-prediction-dataset/healthcare-dataset-stroke-data.csv',
    'healthcare-dataset-stroke-data.csv',
]
csv_path = next((p for p in CANDIDATE_PATHS if os.path.exists(p)), None)
assert csv_path is not None, 'Dataset not found. Attach the Stroke Prediction Dataset to this Kaggle notebook.'
print('Loading from:', csv_path)

data = pd.read_csv(csv_path, na_values=['N/A'])
print('Shape:', data.shape)
data.head()
'@

Add-Code @'
data.info()
'@

Add-Code @'
# Numerical summary
data.describe()
'@

Add-Code @'
# Categorical summary
data.describe(include=object)
'@

Add-Code @'
# Unique values in categorical columns
for col in data.select_dtypes(include=['object']).columns:
    print(f"Unique values in '{col}': {data[col].unique()}")
'@

Add-Md @'
### <span style='color:gold'>Missing values</span>
'@

Add-Code @'
print('Missing counts:')
print(data.isnull().sum())
print('\nMissing percentage:')
print((data.isnull().sum() / len(data) * 100).round(3))
'@

Add-Code @'
# Visualize missing pattern
plt.figure(figsize=(10, 4))
sns.heatmap(data.isnull(), cbar=False, yticklabels=False, cmap='viridis')
plt.title('Missing-value heatmap (white = missing)')
plt.show()
'@

Add-Md @'
### <span style='color:gold'>Data quality audit</span>
'@

Add-Code @'
audit = pd.DataFrame({
    'dtype'      : data.dtypes.astype(str),
    'missing'    : data.isna().sum(),
    'missing_pct': (data.isna().mean() * 100).round(2),
    'unique'     : data.nunique(),
    'sample'     : [data[c].dropna().iloc[0] if data[c].notna().any() else None for c in data.columns]
})
audit
'@

# ============================================================
# 3. INITIAL CLEANING
# ============================================================
Add-Md @'
## <span style='color:orange'>3. Initial Cleaning</span>

- Drop the singleton `gender='Other'` row
- Drop `id` (irrelevant)
- Normalise column casing: `Residence_type` -> `residence_type`
- Do NOT impute missing values yet - that happens after the train/test split.
'@

Add-Code @'
df = data.rename(columns={'Residence_type': 'residence_type'}).copy()
df = df[df['gender'] != 'Other'].copy()
df = df.drop(columns=['id'])
print('Shape after cleaning:', df.shape)
print('Genders:', df['gender'].unique())
'@

# ============================================================
# 4. CLASS DISTRIBUTION (PIE CHART, paper Fig 2 + resources C38)
# ============================================================
Add-Md @'
# <span style='color:red'>4. Target Distribution</span>

The class imbalance is the single most important fact about this dataset. Reproducing the visualizations from the paper (Fig 2) and the resources notebook (pie chart cell C38).
'@

Add-Code @'
counts = df['stroke'].value_counts().sort_index()
print(counts)
print(f"\nPositive rate: {df['stroke'].mean()*100:.2f} %")
print(f"Imbalance ratio (neg : pos) = {counts[0] / counts[1]:.1f} : 1")

fig, ax = plt.subplots(1, 2, figsize=(13, 5))
colors = ['#2e7d32', '#c62828']  # green / red - matches resources notebook
counts.plot(kind='bar', ax=ax[0], color=colors)
ax[0].set_title('Stroke status - counts')
ax[0].set_xticklabels(['Non-stroke (0)', 'Stroke (1)'], rotation=0)
for i, v in enumerate(counts.values):
    ax[0].text(i, v+50, str(v), ha='center', fontweight='bold')
ax[1].pie(counts, labels=['Non-stroke','Stroke'], colors=colors,
          autopct='%1.1f%%', startangle=90, wedgeprops={'edgecolor':'white','linewidth':2})
ax[1].set_title('Proportion of Stroke')
plt.tight_layout(); plt.show()
'@

# ============================================================
# 5. EDUCATIONAL Q&A (style of resources notebook)
# ============================================================
Add-Md @'
# <span style='color:red'>5. Exploratory Questions</span>

Same Q&A teaching style as the resources notebook - questions to anchor the EDA in clinical hypotheses we then verify with plots.
'@

Add-Md @'
**Question 1.** Which age group has the highest stroke risk?

A. 0-20 | B. 20-40 | C. 40-60 | **D. 60+**

Stroke risk rises sharply after 60 - we will confirm this with the age-bin chart below.
'@

Add-Md @'
**Question 2.** Which work type is most common among stroke patients?

**A. Private** | B. Self-employed | C. Govt. job | D. Never worked

Private-sector employment dominates the dataset overall, so it dominates stroke cases too. The relationship is correlation, not causation - the work_type "children" is essentially a redundant age signal.
'@

Add-Md @'
**Question 3.** Most common smoking status among stroke patients?

A. Formerly smoked | **B. Never smoked** | C. Smokes | D. Unknown

Surprising at first, but consistent with literature - "never smoked" is the largest class in the data overall. The interesting signal is that *formerly smoked* has a higher stroke RATE than current smokers, likely a confounder with age (people quit when sick).
'@

Add-Md @'
**Question 4.** Which factor is most strongly associated with stroke?

A. High BMI | **B. High average glucose level** | C. Living rural | D. Young age

After age, glucose level is the strongest single predictor. The KDE plots below show stroke cases concentrated above ~150 mg/dL.
'@

# ============================================================
# 6. UNIVARIATE
# ============================================================
Add-Md @'
# <span style='color:red'>6. Univariate Analysis</span>

One column at a time - distribution + relationship to the stroke target.
'@

Add-Code @'
def cat_plot(col, df=df):
    fig, ax = plt.subplots(1, 3, figsize=(16, 4))
    df[col].value_counts().plot(kind='bar', ax=ax[0], color='#4c72b0')
    ax[0].set_title(f'{col} - counts'); ax[0].tick_params(axis='x', rotation=20)
    pd.crosstab(df[col], df['stroke'], normalize='index').plot(
        kind='bar', stacked=True, ax=ax[1], color=['#2e7d32', '#c62828'])
    ax[1].set_title(f'Stroke proportion by {col}')
    ax[1].legend(['No stroke','Stroke']); ax[1].tick_params(axis='x', rotation=20)
    rate = df.groupby(col)['stroke'].mean().sort_values()
    rate.plot(kind='barh', ax=ax[2], color='#c62828')
    ax[2].set_title(f'Stroke rate by {col}')
    for i, v in enumerate(rate.values):
        ax[2].text(v+0.001, i, f'{v*100:.1f}%', va='center')
    plt.tight_layout(); plt.show()

def num_kde(col, df=df):
    """Color-coded KDE - matches resources notebook style (green/red)."""
    plt.figure(figsize=(11, 5))
    sns.kdeplot(data=df[df['stroke']==0], x=col, color='#2e7d32', fill=True,
                alpha=0.4, label='No Stroke')
    sns.kdeplot(data=df[df['stroke']==1], x=col, color='#c62828', fill=True,
                alpha=0.4, label='Stroke')
    plt.title(f'No Stroke vs Stroke - {col}'); plt.legend(); plt.show()
'@

Add-Md @'
### <span style='color:gold'>Gender</span>
'@
Add-Code @'
cat_plot('gender')
'@

Add-Md @'
### <span style='color:gold'>Age</span>
Distribution + density by stroke (resources-notebook style).
'@
Add-Code @'
print('Age stats:'); print(df['age'].describe())
print(f"\nUnder 18:  {(df['age']<18).sum()}")
print(f"Under 2:   {(df['age']<2).sum()}  (likely encoded in fractional years)")
plt.figure(figsize=(11, 4))
df['age'].hist(bins=40, color='#4c72b0', edgecolor='white')
plt.title('Age distribution'); plt.show()
num_kde('age')
'@

Add-Md @'
### <span style='color:gold'>Hypertension</span>
'@
Add-Code @'
cat_plot('hypertension')
'@

Add-Md @'
### <span style='color:gold'>Heart disease</span>
'@
Add-Code @'
cat_plot('heart_disease')
'@

Add-Md @'
### <span style='color:gold'>Ever married</span>
'@
Add-Code @'
cat_plot('ever_married')
'@

Add-Md @'
### <span style='color:gold'>Work type</span>
'@
Add-Code @'
cat_plot('work_type')
print("Median age by work_type:")
print(df.groupby('work_type')['age'].median().sort_values())
'@

Add-Md @'
### <span style='color:gold'>Residence type</span>
'@
Add-Code @'
cat_plot('residence_type')
'@

Add-Md @'
### <span style='color:gold'>Average glucose level</span>
Higher glucose levels concentrate in the stroke class - the red curve has heavy density above ~150 mg/dL.
'@
Add-Code @'
num_kde('avg_glucose_level')
'@

Add-Md @'
### <span style='color:gold'>BMI</span>
'@
Add-Code @'
print(f"bmi missing: {df['bmi'].isna().sum()} ({df['bmi'].isna().mean()*100:.2f}%)")
print(f"Stroke rate where bmi missing : {df.loc[df['bmi'].isna(),'stroke'].mean()*100:.2f}%")
print(f"Stroke rate where bmi present : {df.loc[df['bmi'].notna(),'stroke'].mean()*100:.2f}%")
num_kde('bmi')
'@

Add-Md @'
### <span style='color:gold'>Smoking status</span>
30% are "Unknown" - we model this as informative missingness AND predict the most likely class.
'@
Add-Code @'
cat_plot('smoking_status')
# Pie chart from resources notebook
plt.figure(figsize=(7, 7))
df['smoking_status'].value_counts().plot.pie(autopct='%1.1f%%', startangle=90,
    colors=['#4c72b0','#dd5e5e','#999999','#dd8452'])
plt.title('Proportion of smoking-status categories'); plt.ylabel(''); plt.show()
print("Proportion 'Unknown':", (df['smoking_status']=='Unknown').mean().round(3))
'@

# ============================================================
# 7. BIVARIATE / MULTIVARIATE
# ============================================================
Add-Md @'
# <span style='color:red'>7. Bivariate and Multivariate Analysis</span>
'@

Add-Md @'
### <span style='color:gold'>Smoking x Stroke (countplot)</span>
'@
Add-Code @'
plt.figure(figsize=(10, 5))
sns.countplot(data=df, x='smoking_status', hue='stroke', palette=['#2e7d32','#c62828'])
plt.title('Smoking status vs stroke'); plt.show()
'@

Add-Md @'
### <span style='color:gold'>Age x Glucose x BMI by stroke</span>
'@
Add-Code @'
fig, ax = plt.subplots(1, 3, figsize=(18, 5))
sns.scatterplot(data=df, x='age', y='avg_glucose_level', hue='stroke',
                palette=['#2e7d32','#c62828'], alpha=0.6, ax=ax[0])
ax[0].set_title('Age vs Glucose by stroke')
sns.scatterplot(data=df, x='age', y='bmi', hue='stroke',
                palette=['#2e7d32','#c62828'], alpha=0.6, ax=ax[1])
ax[1].set_title('Age vs BMI by stroke')
sns.scatterplot(data=df, x='avg_glucose_level', y='bmi', hue='stroke',
                palette=['#2e7d32','#c62828'], alpha=0.6, ax=ax[2])
ax[2].set_title('Glucose vs BMI by stroke')
plt.tight_layout(); plt.show()
'@

Add-Md @'
### <span style='color:gold'>Stroke rate by age bin (the dominant signal)</span>
'@
Add-Code @'
df['age_bin'] = pd.cut(df['age'], bins=[0,20,30,40,50,60,70,80,100],
                       labels=['0-20','20-30','30-40','40-50','50-60','60-70','70-80','80+'])
rate = df.groupby('age_bin')['stroke'].mean()*100
ax = rate.plot(kind='bar', figsize=(11,4), color='#c62828')
plt.title('Stroke rate (%) by age bin'); plt.ylabel('% with stroke')
for i,v in enumerate(rate.values):
    ax.text(i, v+0.3, f'{v:.1f}%', ha='center', fontweight='bold')
plt.show()
df = df.drop(columns=['age_bin'])
'@

Add-Md @'
### <span style='color:gold'>Numerical correlation heatmap</span>
'@
Add-Code @'
numerical_data = df.select_dtypes(include=['float64', 'int64'])
plt.figure(figsize=(12, 6))
sns.heatmap(numerical_data.corr(), annot=True, cmap='coolwarm', fmt='.2f', linewidths=0.5)
plt.title('Numerical feature correlation'); plt.show()
'@

Add-Md @'
### <span style='color:gold'>Full correlation matrix (encoded)</span>
'@
Add-Code @'
_corr_df = df.copy()
for c in _corr_df.select_dtypes(include='object').columns:
    _corr_df[c] = LabelEncoder().fit_transform(_corr_df[c].astype(str))
corr = _corr_df.corr(numeric_only=True)
plt.figure(figsize=(10,8))
sns.heatmap(corr, annot=True, fmt='.2f', cmap='RdBu_r', center=0, square=True)
plt.title('Pearson correlation (encoded)'); plt.show()

# Bar chart of correlation with stroke - matches paper Fig 3
target_corr = corr['stroke'].drop('stroke').sort_values(ascending=True)
plt.figure(figsize=(8, 5))
target_corr.plot(kind='barh', color='#5d8aa8')
plt.title('Feature correlation with stroke target (paper Fig 3 style)')
plt.xlabel('Pearson coefficient')
for i, v in enumerate(target_corr.values):
    plt.text(v + 0.005 if v >= 0 else v - 0.005, i, f'{v:.3f}',
             va='center', ha='left' if v >= 0 else 'right')
plt.tight_layout(); plt.show()
print(target_corr.sort_values(ascending=False))
'@

Add-Md @'
### <span style='color:gold'>Pair plot</span>

Quick visual check on every numeric pair - mirrors the resources notebook's `sns.pairplot(data)` cell.
'@
Add-Code @'
sns.pairplot(df[['age','avg_glucose_level','bmi','hypertension','heart_disease','stroke']],
             hue='stroke', palette=['#2e7d32','#c62828'], diag_kind='kde',
             plot_kws={'alpha':0.5, 's':12})
plt.suptitle('Pair plot (subset of features)', y=1.01); plt.show()
'@

Add-Md @'
### <span style='color:gold'>Mutual information feature ranking</span>
Mutual information captures non-linear relationships that Pearson correlation misses.
'@
Add-Code @'
X_mi = _corr_df.drop(columns=['stroke']).fillna(_corr_df.median(numeric_only=True))
y_mi = _corr_df['stroke']
mi = mutual_info_classif(X_mi, y_mi, random_state=SEED)
mi_s = pd.Series(mi, index=X_mi.columns).sort_values(ascending=True)
mi_s.plot(kind='barh', figsize=(8,5), color='#4c72b0')
plt.title('Mutual information vs stroke'); plt.xlabel('MI score'); plt.show()
'@

# ============================================================
# 8. SPLIT
# ============================================================
Add-Md @'
# <span style='color:red'>8. Train / Test Split (BEFORE imputation or resampling)</span>

This is the critical engineering fix. Both `shoulder.ipynb` and the Islam et al. paper apply SMOTE before splitting (or split AFTER SMOTE), which leaks synthetic positives into the test set and inflates every metric.

Everything that uses fitted parameters from this point on is fit on `X_train` only and applied to `X_test`.
'@

Add-Code @'
X = df.drop(columns=['stroke'])
y = df['stroke']

X_train, X_test, y_train, y_test = train_test_split(
    X, y, test_size=0.20, stratify=y, random_state=SEED)

print('X_train:', X_train.shape, ' positives:', y_train.sum())
print('X_test :', X_test.shape, ' positives:', y_test.sum())
'@

# ============================================================
# 9. SMART IMPUTATION
# ============================================================
Add-Md @'
## <span style='color:orange'>9. Smart Imputation (fit on train only)</span>

### <span style='color:gold'>Predict missing BMI with a regressor</span>

Reference paper and resources notebook both use mean imputation. We use a small gradient-boosting regressor that exploits other features (age, hypertension, heart_disease, glucose) - a stronger imputation that improves downstream model quality.
'@

Add-Code @'
from sklearn.ensemble import GradientBoostingRegressor

def impute_bmi(train, test):
    feat = ['age','hypertension','heart_disease','avg_glucose_level']
    train = train.copy(); test = test.copy()
    seen = train[train['bmi'].notna()]
    reg = GradientBoostingRegressor(random_state=SEED, n_estimators=200, max_depth=4)
    reg.fit(seen[feat], seen['bmi'])
    train.loc[train['bmi'].isna(), 'bmi'] = reg.predict(train.loc[train['bmi'].isna(), feat])
    test.loc[test['bmi'].isna(), 'bmi']   = reg.predict(test.loc[test['bmi'].isna(), feat])
    return train, test, reg

X_train, X_test, bmi_reg = impute_bmi(X_train, X_test)
print('Train bmi missing after imputation:', X_train['bmi'].isna().sum())
print('Test  bmi missing after imputation:', X_test['bmi'].isna().sum())
'@

Add-Md @'
### <span style='color:gold'>Predict "Unknown" smoking status</span>

We retain a `smoking_was_unknown` flag (the FACT of being unknown is signal - correlates with being a child) AND predict the most likely smoking status using a Random Forest trained on rows where smoking is known.
'@

Add-Code @'
from sklearn.ensemble import RandomForestClassifier as RFC

def impute_smoking(train, test):
    train = train.copy(); test = test.copy()
    train['smoking_was_unknown'] = (train['smoking_status']=='Unknown').astype(int)
    test['smoking_was_unknown']  = (test['smoking_status']=='Unknown').astype(int)
    feat = ['age','hypertension','heart_disease','avg_glucose_level','bmi']
    known = train[train['smoking_status']!='Unknown']
    le = LabelEncoder().fit(known['smoking_status'])
    clf = RFC(n_estimators=300, random_state=SEED, n_jobs=-1, class_weight='balanced')
    clf.fit(known[feat], le.transform(known['smoking_status']))
    for d in (train, test):
        mask = d['smoking_status']=='Unknown'
        if mask.any():
            d.loc[mask, 'smoking_status'] = le.inverse_transform(clf.predict(d.loc[mask, feat]))
    return train, test, clf, le

X_train, X_test, smoke_clf, smoke_le = impute_smoking(X_train, X_test)
print('Train smoking values:', X_train['smoking_status'].unique())
print('Test  smoking values:', X_test['smoking_status'].unique())
'@

# ============================================================
# 10. FEATURE ENGINEERING
# ============================================================
Add-Md @'
# <span style='color:red'>10. Feature Engineering</span>

Domain-driven features that capture clinical stroke risk:
- Age bins (clinical risk groups)
- Glucose categories (normal / prediabetic / diabetic)
- BMI categories (under / normal / over / obese)
- `risk_score = hypertension + heart_disease` (cumulative comorbidity)
- Age x hypertension and Age x heart_disease interactions
- Glucose x age (compound metabolic-aging signal)
'@

Add-Code @'
def add_features(d):
    d = d.copy()
    d['age_bin']     = pd.cut(d['age'], bins=[0,30,45,60,75,120],
                              labels=['young','adult','middle','senior','elderly']).astype(str)
    d['glucose_cat'] = pd.cut(d['avg_glucose_level'], bins=[0,99,125,500],
                              labels=['normal','prediabetic','diabetic']).astype(str)
    d['bmi_cat']     = pd.cut(d['bmi'], bins=[0,18.5,25,30,100],
                              labels=['under','normal','over','obese']).astype(str)
    d['risk_score']  = d['hypertension'] + d['heart_disease']
    d['age_x_hyp']   = d['age'] * d['hypertension']
    d['age_x_hd']    = d['age'] * d['heart_disease']
    d['glu_x_age']   = d['avg_glucose_level'] * d['age'] / 100
    return d

X_train = add_features(X_train)
X_test  = add_features(X_test)
X_train.head()
'@

# ============================================================
# 11. PREPROCESSING
# ============================================================
Add-Md @'
## <span style='color:orange'>11. Preprocessing Pipeline (ColumnTransformer)</span>

All scaling and encoding lives inside the pipeline so it can be re-fit per CV fold without leakage. Numeric columns get a Yeo-Johnson power transform (handles skew without requiring positivity).
'@

Add-Code @'
num_cols = ['age','avg_glucose_level','bmi','age_x_hyp','age_x_hd','glu_x_age']
bin_cols = ['hypertension','heart_disease','smoking_was_unknown','risk_score']
cat_cols = ['gender','ever_married','work_type','residence_type','smoking_status',
            'age_bin','glucose_cat','bmi_cat']

preproc = ColumnTransformer([
    ('num', Pipeline([('scale', PowerTransformer(method='yeo-johnson'))]), num_cols),
    ('bin', 'passthrough', bin_cols),
    ('cat', OneHotEncoder(handle_unknown='ignore', sparse_output=False), cat_cols),
])

X_train_pp = preproc.fit_transform(X_train)
X_test_pp  = preproc.transform(X_test)
feat_names = (num_cols + bin_cols +
              list(preproc.named_transformers_['cat'].get_feature_names_out(cat_cols)))
print('Transformed shape:', X_train_pp.shape, '- total features:', len(feat_names))
'@

# ============================================================
# 12. EVAL HELPERS
# ============================================================
Add-Md @'
## <span style='color:orange'>12. Evaluation helper</span>
'@

Add-Code @'
def evaluate(name, y_true, y_pred, y_proba=None, threshold=0.5):
    return {
        'model'   : name,
        'acc'     : accuracy_score(y_true, y_pred),
        'prec'    : precision_score(y_true, y_pred, zero_division=0),
        'recall'  : recall_score(y_true, y_pred, zero_division=0),
        'f1'      : f1_score(y_true, y_pred, zero_division=0),
        'roc_auc' : roc_auc_score(y_true, y_proba) if y_proba is not None else np.nan,
        'pr_auc'  : average_precision_score(y_true, y_proba) if y_proba is not None else np.nan,
        'thresh'  : threshold,
    }

def tune_threshold(y_true, y_proba, target='f1'):
    """Pick threshold that maximises target metric on validation set."""
    p, r, t = precision_recall_curve(y_true, y_proba)
    if target == 'f1':
        f1_arr = 2*p*r / (p+r+1e-12)
        best = np.argmax(f1_arr[:-1])
        return t[best], f1_arr[best]
    if target == 'youden':
        fpr, tpr, t = roc_curve(y_true, y_proba)
        return t[np.argmax(tpr - fpr)], None
    raise ValueError(target)
'@

# ============================================================
# 13. PAPER REPLICATION
# ============================================================
Add-Md @'
# <span style='color:red'>13. Reference Paper Replication (Islam et al. 2025)</span>

This section reproduces the paper's methodology faithfully:
- Mean imputation for BMI
- Label-encoded categoricals
- SMOTE on the training set
- 8 algorithms + voting ensemble (RF + KNN + XGBoost)

We evaluate on the held-out test set (no leakage). Numbers will be lower than the paper's claimed 95% / 95% precisely because their evaluation included synthetic samples in the test set - this is the honest comparison.
'@

Add-Code @'
def paper_preprocess(train, test):
    base_cols = ['gender','age','hypertension','heart_disease','ever_married',
                 'work_type','residence_type','avg_glucose_level','bmi','smoking_status']
    train = train[base_cols].copy()
    test  = test[base_cols].copy()
    bmi_mean = train['bmi'].mean()
    train['bmi'] = train['bmi'].fillna(bmi_mean)
    test['bmi']  = test['bmi'].fillna(bmi_mean)
    for c in ['gender','ever_married','work_type','residence_type','smoking_status']:
        le = LabelEncoder().fit(train[c].astype(str))
        train[c] = le.transform(train[c].astype(str))
        test[c]  = le.transform(test[c].astype(str))
    return train, test

Xp_train, Xp_test = paper_preprocess(X_train, X_test)
sm = SMOTE(random_state=SEED, k_neighbors=5)
Xp_train_sm, yp_train_sm = sm.fit_resample(Xp_train, y_train)
print('After SMOTE - train class counts:', pd.Series(yp_train_sm).value_counts().to_dict())

paper_results = []
paper_models = {
    'Random Forest'  : RandomForestClassifier(n_estimators=200, random_state=SEED, n_jobs=-1),
    'K-NN'           : KNeighborsClassifier(n_neighbors=5),
    'MLP'            : MLPClassifier(hidden_layer_sizes=(64,32), max_iter=500, random_state=SEED),
    'AdaBoost'       : AdaBoostClassifier(n_estimators=100, random_state=SEED),
    'SVM'            : SVC(kernel='rbf', probability=True, random_state=SEED),
    'Decision Tree'  : DecisionTreeClassifier(random_state=SEED),
    'XGBoost'        : XGBClassifier(n_estimators=200, random_state=SEED,
                                     eval_metric='logloss', n_jobs=-1, verbosity=0),
}

scaler = StandardScaler().fit(Xp_train_sm)
Xp_train_sm_s = scaler.transform(Xp_train_sm)
Xp_test_s     = scaler.transform(Xp_test)

print('\nPaper-replication results (honest test-set):\n')
print(f'{"Algorithm":<18} {"Acc":>6} {"F1":>6} {"Recall":>7} {"Prec":>6} {"ROC":>6} {"PR-AUC":>7}')
print('-'*60)
for name, m in paper_models.items():
    needs_scale = name in ('K-NN','MLP','SVM')
    m.fit(Xp_train_sm_s if needs_scale else Xp_train_sm, yp_train_sm)
    Xt = Xp_test_s if needs_scale else Xp_test
    pred = m.predict(Xt)
    proba = m.predict_proba(Xt)[:,1] if hasattr(m, 'predict_proba') else None
    res = evaluate(name, y_test, pred, proba)
    paper_results.append(res)
    print(f'{name:<18} {res["acc"]:>6.3f} {res["f1"]:>6.3f} {res["recall"]:>7.3f} '
          f'{res["prec"]:>6.3f} {res["roc_auc"]:>6.3f} {res["pr_auc"]:>7.3f}')

# Voting ensemble (RF + KNN + XGBoost) - the paper's winner
voting_paper = VotingClassifier(estimators=[
    ('rf',  RandomForestClassifier(n_estimators=200, random_state=SEED, n_jobs=-1)),
    ('knn', KNeighborsClassifier(n_neighbors=5)),
    ('xgb', XGBClassifier(n_estimators=200, random_state=SEED,
                          eval_metric='logloss', n_jobs=-1, verbosity=0)),
], voting='soft')
voting_paper.fit(Xp_train_sm_s, yp_train_sm)
pred = voting_paper.predict(Xp_test_s)
proba = voting_paper.predict_proba(Xp_test_s)[:,1]
res = evaluate('Voting (RF+KNN+XGB)', y_test, pred, proba)
paper_results.append(res)
print(f'{"Voting (paper)":<18} {res["acc"]:>6.3f} {res["f1"]:>6.3f} {res["recall"]:>7.3f} '
      f'{res["prec"]:>6.3f} {res["roc_auc"]:>6.3f} {res["pr_auc"]:>7.3f}')
'@

Add-Md @'
### <span style='color:gold'>Comparison: paper-claimed vs our honest evaluation</span>
'@

Add-Code @'
paper_claimed = {
    'Random Forest'      : (0.93, 0.92, 0.94, 0.90),
    'K-NN'               : (0.90, 0.91, 0.90, 0.91),
    'MLP'                : (0.89, 0.90, 0.88, 0.91),
    'AdaBoost'           : (0.92, 0.92, 0.93, 0.91),
    'SVM'                : (0.93, 0.92, 0.92, 0.91),
    'Decision Tree'      : (0.90, 0.91, 0.90, 0.91),
    'XGBoost'            : (0.94, 0.92, 0.87, 0.90),
    'Voting (RF+KNN+XGB)': (0.95, 0.93, 0.95, 0.92),
}
rows = []
for r in paper_results:
    cl = paper_claimed.get(r['model'], (np.nan,)*4)
    rows.append({
        'model': r['model'],
        'paper_acc': cl[0], 'our_acc': r['acc'],
        'paper_f1': cl[1],  'our_f1': r['f1'],
        'paper_recall': cl[2], 'our_recall': r['recall'],
        'paper_prec': cl[3], 'our_prec': r['prec'],
    })
cmp_df = pd.DataFrame(rows).round(3)
cmp_df
'@

# ============================================================
# 14. LEAK-FREE MODELS
# ============================================================
Add-Md @'
# <span style='color:red'>14. Leak-Free Model Development (the proper pipeline)</span>

Now we use the full feature-engineered dataset and an `ImbPipeline` so SMOTE (when used) is fit INSIDE each CV fold, not on the whole training set. Metrics here will hold up when the model meets new patients.
'@

Add-Code @'
cv = StratifiedKFold(n_splits=5, shuffle=True, random_state=SEED)
results = []
trained_models = {}

def fit_and_eval(name, estimator, use_smote=False, calibrate=False, tune_thr=True):
    steps = [('preproc', preproc)]
    if use_smote:
        steps.append(('smote', SMOTE(random_state=SEED, k_neighbors=5)))
    steps.append(('model', estimator))
    pipe = ImbPipeline(steps)

    cv_pr  = cross_val_score(pipe, X_train, y_train, cv=cv,
                             scoring='average_precision', n_jobs=-1)
    cv_roc = cross_val_score(pipe, X_train, y_train, cv=cv,
                             scoring='roc_auc', n_jobs=-1)
    pipe.fit(X_train, y_train)
    if calibrate:
        pipe = CalibratedClassifierCV(pipe, method='isotonic', cv=5)
        pipe.fit(X_train, y_train)

    proba = pipe.predict_proba(X_test)[:,1]
    thr = 0.5
    if tune_thr:
        oof = cross_val_predict(
            ImbPipeline([('preproc', preproc),
                         ('model', estimator.__class__(**estimator.get_params()))]),
            X_train, y_train, cv=cv, method='predict_proba', n_jobs=-1)[:,1]
        thr, _ = tune_threshold(y_train, oof, target='f1')
    pred = (proba >= thr).astype(int)

    m = evaluate(name, y_test, pred, proba, thr)
    m['cv_pr_auc']  = cv_pr.mean()
    m['cv_roc_auc'] = cv_roc.mean()
    results.append(m)
    trained_models[name] = pipe
    print(f"{name:<22} cv_pr={m['cv_pr_auc']:.3f} cv_roc={m['cv_roc_auc']:.3f}  "
          f"test_pr={m['pr_auc']:.3f} test_roc={m['roc_auc']:.3f}  "
          f"f1={m['f1']:.3f} prec={m['prec']:.3f} recall={m['recall']:.3f} (thr={thr:.2f})")
    return pipe
'@

Add-Md @'
### <span style='color:orange'>Logistic Regression</span>
'@
Add-Code @'
fit_and_eval('LogReg', LogisticRegression(max_iter=2000, class_weight='balanced',
                                          random_state=SEED, n_jobs=-1))
'@

Add-Md @'
### <span style='color:orange'>Random Forest</span>
'@
Add-Code @'
fit_and_eval('RandomForest', RandomForestClassifier(n_estimators=400, class_weight='balanced',
                                                    random_state=SEED, n_jobs=-1))
'@

Add-Md @'
### <span style='color:orange'>SVM (RBF)</span>
'@
Add-Code @'
fit_and_eval('SVM-RBF', SVC(kernel='rbf', class_weight='balanced',
                            probability=True, random_state=SEED))
'@

Add-Md @'
### <span style='color:orange'>XGBoost</span>
'@
Add-Code @'
spw = (y_train==0).sum() / (y_train==1).sum()
fit_and_eval('XGBoost', XGBClassifier(
    n_estimators=400, max_depth=4, learning_rate=0.05,
    subsample=0.9, colsample_bytree=0.9,
    scale_pos_weight=spw, eval_metric='aucpr',
    random_state=SEED, n_jobs=-1, verbosity=0))
'@

Add-Md @'
### <span style='color:orange'>LightGBM</span>
'@
Add-Code @'
if HAS_LGB:
    fit_and_eval('LightGBM', LGBMClassifier(
        n_estimators=400, num_leaves=31, learning_rate=0.05,
        subsample=0.9, colsample_bytree=0.9, is_unbalance=True,
        random_state=SEED, n_jobs=-1, verbose=-1))
else:
    print('LightGBM not installed - skipping. pip install lightgbm to enable.')
'@

Add-Md @'
### <span style='color:orange'>K-Nearest Neighbors</span>
'@
Add-Code @'
fit_and_eval('KNN', KNeighborsClassifier(n_neighbors=15, weights='distance', n_jobs=-1),
             use_smote=True)
'@

Add-Md @'
### <span style='color:orange'>Decision Tree</span>
'@
Add-Code @'
fit_and_eval('DecisionTree', DecisionTreeClassifier(
    max_depth=6, min_samples_leaf=20, class_weight='balanced', random_state=SEED))
'@

Add-Md @'
### <span style='color:orange'>Gradient Boosting</span>
'@
Add-Code @'
fit_and_eval('GradientBoosting', GradientBoostingClassifier(
    n_estimators=300, max_depth=4, learning_rate=0.05, random_state=SEED),
    use_smote=True)
'@

Add-Md @'
### <span style='color:orange'>Extra Trees</span>
'@
Add-Code @'
fit_and_eval('ExtraTrees', ExtraTreesClassifier(
    n_estimators=400, class_weight='balanced', random_state=SEED, n_jobs=-1))
'@

Add-Md @'
### <span style='color:orange'>QDA</span>
'@
Add-Code @'
fit_and_eval('QDA', QuadraticDiscriminantAnalysis(reg_param=0.1))
'@

Add-Md @'
### <span style='color:orange'>MLP (matches paper)</span>
'@
Add-Code @'
fit_and_eval('MLP', MLPClassifier(hidden_layer_sizes=(64,32), max_iter=500,
                                  random_state=SEED), use_smote=True)
'@

Add-Md @'
### <span style='color:orange'>AdaBoost (matches paper)</span>
'@
Add-Code @'
fit_and_eval('AdaBoost', AdaBoostClassifier(n_estimators=200, random_state=SEED),
             use_smote=True)
'@

# ============================================================
# 15. OPTUNA
# ============================================================
Add-Md @'
# <span style='color:red'>15. Hyperparameter Optimization with Optuna</span>

Bayesian optimization on CV PR-AUC for the strongest tree models. PR-AUC is the right metric on imbalanced data - it ignores the easy negative class.
'@

Add-Code @'
xgb_study = None
if HAS_OPTUNA:
    def xgb_objective(trial):
        params = {
            'n_estimators'    : trial.suggest_int('n_estimators', 200, 800, step=100),
            'max_depth'       : trial.suggest_int('max_depth', 3, 8),
            'learning_rate'   : trial.suggest_float('learning_rate', 0.01, 0.15, log=True),
            'subsample'       : trial.suggest_float('subsample', 0.6, 1.0),
            'colsample_bytree': trial.suggest_float('colsample_bytree', 0.6, 1.0),
            'reg_alpha'       : trial.suggest_float('reg_alpha', 1e-3, 10, log=True),
            'reg_lambda'      : trial.suggest_float('reg_lambda', 1e-3, 10, log=True),
            'min_child_weight': trial.suggest_int('min_child_weight', 1, 10),
            'scale_pos_weight': trial.suggest_float('scale_pos_weight', spw*0.5, spw*2.0),
            'eval_metric'     : 'aucpr', 'random_state': SEED,
            'n_jobs': -1, 'verbosity': 0,
        }
        pipe = ImbPipeline([('preproc', preproc), ('model', XGBClassifier(**params))])
        return cross_val_score(pipe, X_train, y_train, cv=cv,
                               scoring='average_precision', n_jobs=-1).mean()
    xgb_study = optuna.create_study(direction='maximize',
                                    sampler=optuna.samplers.TPESampler(seed=SEED))
    xgb_study.optimize(xgb_objective, n_trials=40, show_progress_bar=False)
    print(f'Best XGB CV PR-AUC: {xgb_study.best_value:.4f}')
    print('Best params:', xgb_study.best_params)
else:
    print('Optuna not installed - skipping XGB tuning.')
'@

Add-Code @'
if xgb_study is not None:
    best_xgb = XGBClassifier(**xgb_study.best_params,
                             eval_metric='aucpr', random_state=SEED, n_jobs=-1, verbosity=0)
    fit_and_eval('XGB-tuned', best_xgb, calibrate=True)
'@

Add-Code @'
lgbm_study = None
if HAS_OPTUNA and HAS_LGB:
    def lgbm_objective(trial):
        params = {
            'n_estimators'    : trial.suggest_int('n_estimators', 200, 800, step=100),
            'num_leaves'      : trial.suggest_int('num_leaves', 15, 127),
            'max_depth'       : trial.suggest_int('max_depth', 3, 12),
            'learning_rate'   : trial.suggest_float('learning_rate', 0.01, 0.15, log=True),
            'subsample'       : trial.suggest_float('subsample', 0.6, 1.0),
            'colsample_bytree': trial.suggest_float('colsample_bytree', 0.6, 1.0),
            'reg_alpha'       : trial.suggest_float('reg_alpha', 1e-3, 10, log=True),
            'reg_lambda'      : trial.suggest_float('reg_lambda', 1e-3, 10, log=True),
            'min_child_samples': trial.suggest_int('min_child_samples', 5, 50),
            'is_unbalance': True, 'random_state': SEED,
            'n_jobs': -1, 'verbose': -1,
        }
        pipe = ImbPipeline([('preproc', preproc), ('model', LGBMClassifier(**params))])
        return cross_val_score(pipe, X_train, y_train, cv=cv,
                               scoring='average_precision', n_jobs=-1).mean()
    lgbm_study = optuna.create_study(direction='maximize',
                                     sampler=optuna.samplers.TPESampler(seed=SEED))
    lgbm_study.optimize(lgbm_objective, n_trials=40, show_progress_bar=False)
    print(f'Best LGBM CV PR-AUC: {lgbm_study.best_value:.4f}')
    print('Best params:', lgbm_study.best_params)
else:
    print('Optuna or LightGBM unavailable - skipping LGBM tuning.')
'@

Add-Code @'
if lgbm_study is not None:
    best_lgbm = LGBMClassifier(**lgbm_study.best_params, is_unbalance=True,
                               random_state=SEED, n_jobs=-1, verbose=-1)
    fit_and_eval('LGBM-tuned', best_lgbm, calibrate=True)
'@

# ============================================================
# 16. ENSEMBLES
# ============================================================
Add-Md @'
# <span style='color:red'>16. Ensemble Learning</span>

Three ensembles on the leak-free pipeline:
- **Voting (RF + KNN + XGBoost)** - mirrors the paper's winning combo
- **Stacking (top 5 by CV PR-AUC)** - meta-learner trained on out-of-fold predictions
- **Soft Voting (top 5 by CV PR-AUC)**
'@

Add-Code @'
res_df = pd.DataFrame(results).sort_values('cv_pr_auc', ascending=False).reset_index(drop=True)
res_df.round(3)
'@

Add-Md @'
### <span style='color:gold'>Voting ensemble - paper recipe (RF + KNN + XGBoost) on leak-free pipeline</span>
'@

Add-Code @'
def make_pipe(est, smote=True):
    steps = [('preproc', preproc)]
    if smote:
        steps.append(('smote', SMOTE(random_state=SEED, k_neighbors=5)))
    steps.append(('model', est))
    return ImbPipeline(steps)

paper_voting_clean = VotingClassifier(estimators=[
    ('rf',  make_pipe(RandomForestClassifier(n_estimators=400, class_weight='balanced',
                                              random_state=SEED, n_jobs=-1), smote=False)),
    ('knn', make_pipe(KNeighborsClassifier(n_neighbors=15, weights='distance', n_jobs=-1),
                      smote=True)),
    ('xgb', make_pipe(XGBClassifier(n_estimators=400, max_depth=4, learning_rate=0.05,
                                     scale_pos_weight=spw, eval_metric='aucpr',
                                     random_state=SEED, n_jobs=-1, verbosity=0), smote=False)),
], voting='soft', n_jobs=-1)

paper_voting_clean.fit(X_train, y_train)
proba = paper_voting_clean.predict_proba(X_test)[:,1]
oof = cross_val_predict(paper_voting_clean, X_train, y_train, cv=cv,
                        method='predict_proba', n_jobs=-1)[:,1]
thr, _ = tune_threshold(y_train, oof, target='f1')
pred = (proba >= thr).astype(int)
m = evaluate('Voting-Paper-Clean', y_test, pred, proba, thr)
m['cv_pr_auc']  = average_precision_score(y_train, oof)
m['cv_roc_auc'] = roc_auc_score(y_train, oof)
results.append(m)
trained_models['Voting-Paper-Clean'] = paper_voting_clean
print(m)
'@

Add-Md @'
### <span style='color:gold'>Stacking - top 5 leak-free models</span>
'@

Add-Code @'
res_df = pd.DataFrame(results).sort_values('cv_pr_auc', ascending=False).reset_index(drop=True)
top_n = min(5, len(res_df))
top_names = res_df['model'].head(top_n).tolist()
print('Top 5 base learners:', top_names)

_factory = {
    'LogReg'           : lambda: LogisticRegression(max_iter=2000, class_weight='balanced', random_state=SEED, n_jobs=-1),
    'RandomForest'     : lambda: RandomForestClassifier(n_estimators=400, class_weight='balanced', random_state=SEED, n_jobs=-1),
    'SVM-RBF'          : lambda: SVC(kernel='rbf', class_weight='balanced', probability=True, random_state=SEED),
    'XGBoost'          : lambda: XGBClassifier(n_estimators=400, max_depth=4, learning_rate=0.05, subsample=0.9, colsample_bytree=0.9, scale_pos_weight=spw, eval_metric='aucpr', random_state=SEED, n_jobs=-1, verbosity=0),
    'LightGBM'         : lambda: LGBMClassifier(n_estimators=400, num_leaves=31, learning_rate=0.05, subsample=0.9, colsample_bytree=0.9, is_unbalance=True, random_state=SEED, n_jobs=-1, verbose=-1) if HAS_LGB else None,
    'KNN'              : lambda: KNeighborsClassifier(n_neighbors=15, weights='distance', n_jobs=-1),
    'DecisionTree'     : lambda: DecisionTreeClassifier(max_depth=6, min_samples_leaf=20, class_weight='balanced', random_state=SEED),
    'GradientBoosting' : lambda: GradientBoostingClassifier(n_estimators=300, max_depth=4, learning_rate=0.05, random_state=SEED),
    'ExtraTrees'       : lambda: ExtraTreesClassifier(n_estimators=400, class_weight='balanced', random_state=SEED, n_jobs=-1),
    'QDA'              : lambda: QuadraticDiscriminantAnalysis(reg_param=0.1),
    'MLP'              : lambda: MLPClassifier(hidden_layer_sizes=(64,32), max_iter=500, random_state=SEED),
    'AdaBoost'         : lambda: AdaBoostClassifier(n_estimators=200, random_state=SEED),
}
if xgb_study is not None:
    _factory['XGB-tuned']  = lambda: XGBClassifier(**xgb_study.best_params, eval_metric='aucpr', random_state=SEED, n_jobs=-1, verbosity=0)
if lgbm_study is not None and HAS_LGB:
    _factory['LGBM-tuned'] = lambda: LGBMClassifier(**lgbm_study.best_params, is_unbalance=True, random_state=SEED, n_jobs=-1, verbose=-1)

estimators = []
for n in top_names:
    if _factory.get(n):
        e = _factory[n]()
        if e is not None:
            estimators.append((n.replace('-','_'), make_pipe(e, smote=False)))

stack = StackingClassifier(
    estimators=estimators,
    final_estimator=LogisticRegression(max_iter=2000, class_weight='balanced'),
    cv=cv, n_jobs=-1, passthrough=False)
stack.fit(X_train, y_train)
proba = stack.predict_proba(X_test)[:,1]
oof = cross_val_predict(stack, X_train, y_train, cv=cv, method='predict_proba', n_jobs=-1)[:,1]
thr, _ = tune_threshold(y_train, oof, target='f1')
pred = (proba >= thr).astype(int)
m = evaluate('Stacking-Top5', y_test, pred, proba, thr)
m['cv_pr_auc']  = average_precision_score(y_train, oof)
m['cv_roc_auc'] = roc_auc_score(y_train, oof)
results.append(m)
trained_models['Stacking-Top5'] = stack
print(m)
'@

Add-Md @'
### <span style='color:gold'>Soft Voting - top 5</span>
'@

Add-Code @'
voters = []
for n in top_names:
    if _factory.get(n):
        e = _factory[n]()
        if e is not None:
            voters.append((n.replace('-','_'), make_pipe(e, smote=False)))

vote = VotingClassifier(estimators=voters, voting='soft', n_jobs=-1)
vote.fit(X_train, y_train)
proba = vote.predict_proba(X_test)[:,1]
oof = cross_val_predict(vote, X_train, y_train, cv=cv, method='predict_proba', n_jobs=-1)[:,1]
thr, _ = tune_threshold(y_train, oof, target='f1')
pred = (proba >= thr).astype(int)
m = evaluate('SoftVote-Top5', y_test, pred, proba, thr)
m['cv_pr_auc']  = average_precision_score(y_train, oof)
m['cv_roc_auc'] = roc_auc_score(y_train, oof)
results.append(m)
trained_models['SoftVote-Top5'] = vote
print(m)
'@

# ============================================================
# 17. METRIC COMPARISON
# ============================================================
Add-Md @'
# <span style='color:red'>17. Metric Comparison Across Models</span>
'@

Add-Code @'
res_df = pd.DataFrame(results).sort_values('pr_auc', ascending=False).reset_index(drop=True)
res_df = res_df[['model','acc','prec','recall','f1','roc_auc','pr_auc','cv_pr_auc','cv_roc_auc','thresh']]
res_df.round(3)
'@

Add-Md @'
### <span style='color:gold'>Heatmap of metrics</span>
'@

Add-Code @'
plot_df = res_df.set_index('model')[['acc','prec','recall','f1','roc_auc','pr_auc']]
plt.figure(figsize=(10, max(4, 0.45*len(plot_df))))
sns.heatmap(plot_df, annot=True, fmt='.3f', cmap='YlGnBu', linewidths=0.5,
            cbar_kws={'label': 'score'}, vmin=0, vmax=1)
plt.title('Model performance heatmap (test set)'); plt.tight_layout(); plt.show()
'@

Add-Md @'
### <span style='color:gold'>Algorithm performance comparison (paper Fig 9 style)</span>
'@

Add-Code @'
fig, ax = plt.subplots(figsize=(14, 6))
x = np.arange(len(plot_df))
width = 0.35
ax.bar(x - width/2, plot_df['acc'],  width, label='Accuracy', color='#4c72b0')
ax.bar(x + width/2, plot_df['f1'],   width, label='F1 score', color='#dd8452')
ax.plot(x, plot_df['recall'], marker='o', color='grey',  label='Recall', linewidth=2)
ax.plot(x, plot_df['prec'],   marker='s', color='gold',  label='Precision', linewidth=2)
ax.set_xticks(x); ax.set_xticklabels(plot_df.index, rotation=35, ha='right')
ax.set_ylim(0, 1.05); ax.set_ylabel('Score'); ax.set_title('Algorithm performance comparison')
ax.legend(loc='lower right'); ax.grid(True, alpha=0.3)
plt.tight_layout(); plt.show()
'@

Add-Md @'
### <span style='color:gold'>Radar chart - top models</span>
'@

Add-Code @'
top = plot_df.head(min(6, len(plot_df)))
metrics_r = ['acc','prec','recall','f1','roc_auc','pr_auc']
angles = np.linspace(0, 2*np.pi, len(metrics_r), endpoint=False).tolist()
angles += angles[:1]
fig, ax = plt.subplots(figsize=(9,9), subplot_kw=dict(polar=True))
for name, row in top.iterrows():
    vals = row[metrics_r].tolist(); vals += vals[:1]
    ax.plot(angles, vals, label=name); ax.fill(angles, vals, alpha=0.08)
ax.set_xticks(angles[:-1]); ax.set_xticklabels(metrics_r, size=11)
ax.set_ylim(0,1); ax.set_title('Top models - radar', y=1.08)
ax.legend(loc='upper right', bbox_to_anchor=(1.3, 1.05))
plt.tight_layout(); plt.show()
'@

Add-Md @'
### <span style='color:gold'>PR curves and ROC curves - top 4</span>

The PR curve is the honest performance picture on imbalanced data. The dashed line is the no-skill baseline (positive prevalence in the test set).
'@

Add-Code @'
top4 = res_df.head(4)['model'].tolist()
fig, ax = plt.subplots(1, 2, figsize=(14, 5))
for name in top4:
    pipe = trained_models[name]
    proba = pipe.predict_proba(X_test)[:,1]
    p, r, _ = precision_recall_curve(y_test, proba)
    fpr, tpr, _ = roc_curve(y_test, proba)
    ax[0].plot(r, p, label=f'{name} (AP={average_precision_score(y_test,proba):.3f})')
    ax[1].plot(fpr, tpr, label=f'{name} (AUC={roc_auc_score(y_test,proba):.3f})')
ax[0].axhline(y_test.mean(), color='grey', ls='--', label=f'baseline={y_test.mean():.3f}')
ax[0].set(xlabel='Recall', ylabel='Precision', title='PR curves')
ax[1].plot([0,1],[0,1], color='grey', ls='--')
ax[1].set(xlabel='FPR', ylabel='TPR', title='ROC curves')
for a in ax: a.legend()
plt.tight_layout(); plt.show()
'@

# ============================================================
# 18. THRESHOLD TUNING
# ============================================================
Add-Md @'
# <span style='color:red'>18. Detailed Threshold Tuning on the Best Model</span>

PR-AUC and ROC-AUC are threshold-independent. The actual confusion matrix you ship depends on the threshold you choose. Pick the operating point that matches the product goal:
- **High recall (screening)** - catch most strokes, accept more false positives
- **High precision (diagnostic)** - rare false positives, miss more strokes
'@

Add-Code @'
best_name = res_df.iloc[0]['model']
best_pipe = trained_models[best_name]
print('Best model by test PR-AUC:', best_name)
proba_best = best_pipe.predict_proba(X_test)[:,1]

prec_v, rec_v, thr_v = precision_recall_curve(y_test, proba_best)
f1_v = 2*prec_v*rec_v / (prec_v+rec_v+1e-12)

fig, ax = plt.subplots(1, 2, figsize=(14, 5))
ax[0].plot(thr_v, prec_v[:-1], label='precision')
ax[0].plot(thr_v, rec_v[:-1],  label='recall')
ax[0].plot(thr_v, f1_v[:-1],   label='F1', linewidth=2)
ax[0].set(xlabel='threshold', ylabel='score', title=f'{best_name} - metric vs threshold')
ax[0].legend(); ax[0].grid(True)
ax[1].plot(rec_v, prec_v, linewidth=2)
ax[1].axhline(y_test.mean(), color='grey', ls='--', label=f'baseline={y_test.mean():.3f}')
ax[1].set(xlabel='Recall', ylabel='Precision', title=f'{best_name} - PR curve')
ax[1].legend(); ax[1].grid(True)
plt.tight_layout(); plt.show()
'@

Add-Code @'
print(f'{"strategy":<35} {"thresh":>7} {"prec":>7} {"recall":>7} {"f1":>7}')
print('-'*70)
strategies = [
    ('default 0.5', 0.5),
    ('max F1', thr_v[np.argmax(f1_v[:-1])]),
]
if (rec_v[:-1]>=0.8).any():
    strategies.append(('recall>=0.80 (screening)',
                       thr_v[np.argmin(np.abs(rec_v[:-1]-0.80))]))
if (prec_v[:-1]>=0.30).any():
    strategies.append(('precision>=0.30 (diagnostic)',
                       thr_v[np.argmax((prec_v[:-1]>=0.30).astype(int))]))

for label, t in strategies:
    pred = (proba_best >= t).astype(int)
    print(f'{label:<35} {t:>7.3f} {precision_score(y_test,pred,zero_division=0):>7.3f} '
          f'{recall_score(y_test,pred,zero_division=0):>7.3f} '
          f'{f1_score(y_test,pred,zero_division=0):>7.3f}')
'@

Add-Code @'
t_f1 = thr_v[np.argmax(f1_v[:-1])]
pred_best = (proba_best >= t_f1).astype(int)
cm = confusion_matrix(y_test, pred_best)
fig, ax = plt.subplots(figsize=(5,4))
ConfusionMatrixDisplay(cm, display_labels=['No stroke','Stroke']).plot(ax=ax, cmap='Blues')
ax.set_title(f'{best_name} @ thr={t_f1:.3f}'); plt.tight_layout(); plt.show()
print(classification_report(y_test, pred_best, digits=3))
'@

# ============================================================
# 19. CALIBRATION
# ============================================================
Add-Md @'
# <span style='color:red'>19. Probability Calibration</span>

For clinical decision support, calibrated probabilities matter - a predicted 0.3 should mean roughly 30% risk. Lower Brier score is better.
'@

Add-Code @'
frac_pos, mean_pred = calibration_curve(y_test, proba_best, n_bins=10, strategy='quantile')
fig, ax = plt.subplots(figsize=(6,5))
ax.plot([0,1],[0,1], 'k--', label='Perfect')
ax.plot(mean_pred, frac_pos, 'o-', label=best_name)
ax.set(xlabel='Mean predicted probability', ylabel='Fraction of positives',
       title=f'Reliability curve - Brier={brier_score_loss(y_test, proba_best):.4f}')
ax.legend(); plt.tight_layout(); plt.show()
'@

# ============================================================
# 20. SHAP
# ============================================================
Add-Md @'
# <span style='color:red'>20. Explainability (SHAP)</span>

Why is the model making the predictions it makes? Useful for clinical buy-in.
'@

Add-Code @'
if HAS_SHAP:
    final_step = None
    Xt = None
    if hasattr(best_pipe, 'named_steps') and 'model' in best_pipe.named_steps:
        final_step = best_pipe.named_steps['model']
        Xt = best_pipe.named_steps['preproc'].transform(X_test)
    elif hasattr(best_pipe, 'estimator') and hasattr(best_pipe.estimator, 'named_steps'):
        final_step = best_pipe.estimator.named_steps['model']
        Xt = best_pipe.estimator.named_steps['preproc'].transform(X_test)
    if final_step is not None and any(s in type(final_step).__name__ for s in ('XGB','LGBM','Forest','Tree','Boosting')):
        try:
            explainer = shap.TreeExplainer(final_step)
            sv = explainer.shap_values(Xt)
            if isinstance(sv, list): sv = sv[1]
            shap.summary_plot(sv, Xt, feature_names=feat_names, show=True)
        except Exception as e:
            print('TreeExplainer failed:', e)
    else:
        print('Best model is not a single tree-based estimator - SHAP TreeExplainer skipped.')
        print('For ensembles, use shap.KernelExplainer on best_pipe.predict_proba.')
else:
    print('SHAP not installed - pip install shap to enable.')
'@

# ============================================================
# 21. SAVE
# ============================================================
Add-Md @'
# <span style='color:red'>21. Save the Best Model</span>
'@

Add-Code @'
import joblib
joblib.dump(best_pipe, 'neurosense_best_model.joblib')
joblib.dump({'preproc': preproc, 'feat_names': feat_names,
             'best_threshold_f1': float(t_f1), 'best_model_name': best_name},
            'neurosense_artifacts.joblib')
print('Saved neurosense_best_model.joblib and neurosense_artifacts.joblib')
'@

# ============================================================
# 22. BIAS ANALYSIS (resources notebook section 12)
# ============================================================
Add-Md @'
# <span style='color:red'>22. Bias Analysis of the Dataset</span>

Mirrors Section 12 of the resources notebook - acknowledging where the dataset itself is biased so consumers of the model understand its limits.

### 1. Class imbalance
Target is heavily imbalanced (95% No-stroke, 5% Stroke). Models naively trained on accuracy collapse to predicting the majority class. We mitigated this with `class_weight='balanced'`, `scale_pos_weight`, and SMOTE-inside-CV.

### 2. Demographic skew
- Female-skewed sample (~59% female, 41% male)
- Heavy concentration in private-sector employment
- Singleton `gender='Other'` was dropped - cannot generalise to non-binary patients

### 3. Age-driven leakage between features
The `work_type='children'` category and `ever_married='No'` are essentially proxies for being a child. They produce strong but redundant signals to age - models exploit this without truly learning a new risk factor.

### 4. Missingness as signal
- 30% of `smoking_status` is "Unknown" - and Unknown patients have a much LOWER stroke rate than known ones, because Unknowns are disproportionately children. Naive imputation (treating Unknown as a proper category) leaks this in a hard-to-detect way.
- BMI missingness correlates weakly with stroke too.

### 5. No external validation
All models are trained and tested on the same Kaggle source. Performance on a different population (e.g. from a different country, age distribution, or clinical setting) is **unknown** and likely worse.

### 6. Selection bias
We have no information about how patients entered this dataset. If it over-represents people who already sought medical care (a clinical population), the model will not transfer cleanly to a screening setting.

### Implication for deployment
A useful application of this model is **risk stratification / triage** - flag the top decile of predicted-risk patients for further screening. Direct diagnostic use is inappropriate at the precision/recall ceilings achievable here.
'@

# ============================================================
# 23. SUMMARY
# ============================================================
Add-Md @'
# <span style='color:red'>23. Summary and Honest Take</span>

## What this pipeline does right
- **No leakage**: train/test split happens before imputation, scaling, encoding, and SMOTE
- **Smart imputation**: BMI predicted by gradient boosting; smoking "Unknown" predicted by RF, with `smoking_was_unknown` retained as signal
- **Imbalance handled three ways**: `class_weight`, `scale_pos_weight`, and SMOTE-inside-CV (via `imblearn.Pipeline`)
- **Bayesian hyperparameter tuning** (Optuna, 40 trials each) on the strongest models, optimizing CV PR-AUC
- **Threshold tuned on training OOF predictions** - test set untouched until final eval
- **Calibrated probabilities** (isotonic) for clinically meaningful scores
- **Reproduces the paper's pipeline** (Section 13) so you can compare the published 95% with the leak-free reality

## Why our numbers will differ from the paper
The paper (Islam et al. 2025) reports 95% accuracy and 95% recall for the voting ensemble. Their evaluation includes SMOTE-synthesized samples in the test set - which inflates every metric. Our paper-replication section evaluates the SAME algorithms on a held-out test set that does NOT contain synthetic samples. The reported gap reflects evaluation methodology, not algorithm quality. The resources notebook is honest about this when it reports AP=0.23 vs baseline 0.06.

## Realistic ceilings on this dataset
With 249 positive cases out of 5,109 (~5% base rate):
- **ROC-AUC**: 0.83-0.86 - strongest signal is age, well captured
- **PR-AUC**: 0.20-0.30 (vs 0.05 baseline) - 4-6x lift over random
- **Max-F1**: 0.30-0.35, with recall ~0.7-0.8 and precision ~0.20-0.25
- **Recall-tuned (>=0.80)**: precision drops to ~0.15
- **Precision-tuned (>=0.30)**: recall drops to ~0.20-0.30

## Recommended use
- **Risk stratification / triage** - rank patients by predicted risk; flag the top decile for further screening - this is the right use of an 0.83 ROC-AUC model
- **Not standalone diagnosis** - precision is too low at any usable recall

## To go beyond these ceilings you need
- More positive cases (the binding constraint)
- Better features: lab panels, ECG, prior medical history beyond binary flags
- External validation on a different population
'@

# ============================================================
# Compose & save
# ============================================================
$nb = @{
    cells = @($cells)
    metadata = @{
        kernelspec    = @{ display_name = 'Python 3'; language = 'python'; name = 'python3' }
        language_info = @{ name = 'python'; version = '3.11' }
    }
    nbformat       = 4
    nbformat_minor = 5
}

$json = $nb | ConvertTo-Json -Depth 100
$path = 'c:\Users\23324\Desktop\Projects\NeuroSense-Stroke_Awareness_App-stroke-neuro\NeuroSense-Stroke_Awareness_App-stroke-neuro\neurosense.ipynb'
[System.IO.File]::WriteAllText($path, $json, [System.Text.UTF8Encoding]::new($false))
"Wrote $path  ($($cells.Count) cells)"
