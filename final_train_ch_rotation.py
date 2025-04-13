import pandas as pd
import numpy as np
from sklearn.model_selection import train_test_split
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import accuracy_score
import joblib
import random

# Load dataset
df = pd.read_csv("dataset.csv")

# Regenerate labels with slight noise if missing
if 'OptimalCHRotation' not in df.columns:
    def noisy_label(row):
        base_label = 1 if (
            row['ResidualEnergy'] < 40 or 
            row['TrafficLoad'] > 3000 or 
            row['PacketReceived'] < 1000
        ) else 0
        return 1 - base_label if random.random() < 0.07 else base_label

    df['OptimalCHRotation'] = df.apply(noisy_label, axis=1)
    df.to_csv("dataset_updated.csv", index=False)

# Label distribution
print("\nLabel distribution:")
print(df['OptimalCHRotation'].value_counts())

# Features & target
X = df[['TrafficLoad', 'PacketReceived', 'ResidualEnergy', 'DistanceToBS']]
Y = df['OptimalCHRotation']

# Train-test split
X_train, X_test, Y_train, Y_test = train_test_split(
    X, Y, test_size=0.3, random_state=42, shuffle=True
)

# Random Forest model
model = RandomForestClassifier(
    n_estimators=50,
    max_depth=5,
    class_weight='balanced',
    random_state=42
)
model.fit(X_train, Y_train)

# Prediction and evaluation
Y_pred = model.predict(X_test)
accuracy = accuracy_score(Y_test, Y_pred)
print(f"\nModel Accuracy: {accuracy:.2f}")

# Save model
joblib.dump(model, "ch_rotation_model.pkl")
