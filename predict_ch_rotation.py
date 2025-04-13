import pandas as pd
import joblib

# Load the saved model
model = joblib.load("ch_rotation_model.pkl")

# Load new data (make sure it has same structure as training data)
# For example, loading a CSV with similar columns:
new_data = pd.read_csv("newest_dataset.csv")  # Should contain TrafficLoad, PacketReceived, ResidualEnergy, DistanceToBS

# Select features
features = new_data[['TrafficLoad', 'PacketReceived', 'ResidualEnergy', 'DistanceToBS']]

# Predict Optimal CH Rotation (1 = Rotate CH, 0 = Retain CH)
predictions = model.predict(features)

# Add predictions to the dataframe
new_data['Predicted_CH_Rotation'] = predictions

# Show results
print(new_data[['TrafficLoad', 'PacketReceived', 'ResidualEnergy', 'DistanceToBS', 'Predicted_CH_Rotation']])

# Optionally, save the predictions to a new file
new_data.to_csv("predicted_ch_rotation1.csv", index=False)
print("Predictions saved to 'predicted_ch_rotation1.csv' ✅")
