import os
import cv2
import numpy as np
from tqdm import tqdm
from sklearn.model_selection import train_test_split
import tensorflow as tf
from tensorflow.keras.applications import MobileNetV2
from tensorflow.keras.layers import Dense, GlobalAveragePooling2D
from tensorflow.keras.models import Model

# -----------------------------
# CONFIG
# -----------------------------
DATASET_PATH = "/Users/rahma/Desktop/genderـdetection/dataset/UTKFace"
IMG_SIZE = 128
BATCH_SIZE = 32
EPOCHS = 15        # training الأول
FINE_TUNE_EPOCHS = 5

# -----------------------------
# LOAD DATA
# -----------------------------
images = []
labels = []

print("Loading dataset...")

for file in tqdm(os.listdir(DATASET_PATH)):
    if file.endswith(".jpg"):
        try:
            parts = file.split("_")
            if len(parts) < 2:
                continue

            gender = int(parts[1])   # 0 = male, 1 = female
            if gender not in [0, 1]:
                continue

            img_path = os.path.join(DATASET_PATH, file)
            img = cv2.imread(img_path)
            if img is None:
                continue

            img = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
            img = cv2.resize(img, (IMG_SIZE, IMG_SIZE))
            img = img / 255.0

            images.append(img)
            labels.append(gender)

        except:
            continue

X = np.array(images, dtype=np.float32)
y = np.array(labels, dtype=np.int32)

print("Total samples:", len(X))
print("Label distribution:", np.unique(y, return_counts=True))

# -----------------------------
# SPLIT DATA
# -----------------------------
X_train, X_val, y_train, y_val = train_test_split(
    X, y,
    test_size=0.2,
    random_state=42,
    stratify=y
)

# -----------------------------
# BUILD MODEL
# -----------------------------
base_model = MobileNetV2(
    input_shape=(IMG_SIZE, IMG_SIZE, 3),
    include_top=False,
    weights="imagenet"
)

# Feature Extraction stage
base_model.trainable = False

x = base_model.output
x = GlobalAveragePooling2D()(x)
output = Dense(1, activation="sigmoid")(x)

model = Model(inputs=base_model.input, outputs=output)

model.compile(
    optimizer=tf.keras.optimizers.Adam(learning_rate=1e-4),
    loss="binary_crossentropy",
    metrics=["accuracy"]
)

model.summary()

# -----------------------------
# TRAIN (FEATURE EXTRACTION)
# -----------------------------
print("\nStarting initial training...")
history = model.fit(
    X_train, y_train,
    validation_data=(X_val, y_val),
    epochs=EPOCHS,
    batch_size=BATCH_SIZE
)

# -----------------------------
# FINE-TUNING
# -----------------------------
print("\nStarting fine-tuning...")

base_model.trainable = True

# freeze early layers, train last 30
for layer in base_model.layers[:-30]:
    layer.trainable = False

model.compile(
    optimizer=tf.keras.optimizers.Adam(learning_rate=1e-5),
    loss="binary_crossentropy",
    metrics=["accuracy"]
)

history_finetune = model.fit(
    X_train, y_train,
    validation_data=(X_val, y_val),
    epochs=FINE_TUNE_EPOCHS,
    batch_size=BATCH_SIZE
)

# -----------------------------
# SAVE MODEL
# -----------------------------
model.save("gender_model.keras")
print("Model saved as 'gender_model.keras'")