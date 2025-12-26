import cv2
import numpy as np
import os

# Paths to model files (relative to this script)
GENDER_PROTO = "deploy.prototxt"
GENDER_MODEL = "gender_net.caffemodel"

# Load face detector
face_cascade = cv2.CascadeClassifier(cv2.data.haarcascades + 'haarcascade_frontalface_default.xml')

# Load gender network using the official model
net = cv2.dnn.readNetFromCaffe(GENDER_PROTO, GENDER_MODEL)

# Labels
GENDER_LIST = ['Male', 'Female']

# Model parameters
MODEL_MEAN_VALUES = (104, 117, 123)
IMG_SIZE = 227


def get_gender(face_roi):
    """
    Predict gender for a face ROI
    Returns: gender label and confidence
    """
    # Resize face to model input size
    face_blob = cv2.resize(face_roi, (IMG_SIZE, IMG_SIZE))
    
    # Create blob with mean subtraction (critical for accurate predictions)
    blob = cv2.dnn.blobFromImage(
        face_blob,
        scalefactor=1.0,
        size=(IMG_SIZE, IMG_SIZE),
        mean=MODEL_MEAN_VALUES,
        swapRB=False,
        crop=False
    )
    
    # Set input and get prediction
    net.setInput(blob)
    predictions = net.forward()
    
    # Get gender prediction (2 outputs: [Male, Female])
    gender_idx = np.argmax(predictions[0])
    gender_confidence = predictions[0][gender_idx]
    
    return GENDER_LIST[gender_idx], gender_confidence


# Open webcam
cap = cv2.VideoCapture(0)

if not cap.isOpened():
    print("❌ Cannot open camera")
    exit()

print("✅ Camera started. Press 'q' to quit.")
print("Using AgeGenderDeepLearning pre-trained models for accurate gender detection.")

while True:
    ret, frame = cap.read()
    if not ret:
        break

    # Flip frame for selfie view
    frame = cv2.flip(frame, 1)
    
    # Convert to grayscale for face detection
    gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
    
    # Detect faces
    faces = face_cascade.detectMultiScale(gray, 1.3, 5, minSize=(30, 30))
    
    if len(faces) > 0:
        for (x, y, w, h) in faces:
            # Extract face ROI
            face_roi = frame[y:y+h, x:x+w]
            
            # Predict gender
            gender, confidence = get_gender(face_roi)
            
            # Draw rectangle around face
            color = (0, 255, 0)
            cv2.rectangle(frame, (x, y), (x+w, y+h), color, 2)
            
            # Draw gender and confidence
            text = f"{gender} ({confidence*100:.1f}%)"
            cv2.putText(frame, text, (x, y-10),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.9,
                        color, 2)
    else:
        # No face detected
        cv2.putText(frame, "No face detected", (20, 40),
                    cv2.FONT_HERSHEY_SIMPLEX, 1,
                    (0, 0, 255), 2)
    
    # Display instructions
    cv2.putText(frame, "Press 'q' to quit", (20, frame.shape[0] - 20),
                cv2.FONT_HERSHEY_SIMPLEX, 0.7,
                (255, 255, 255), 2)
    
    # Show frame
    cv2.imshow("Gender Detection - AgeGenderDeepLearning", frame)
    
    # Exit on 'q' key
    if cv2.waitKey(1) & 0xFF == ord('q'):
        break

cap.release()
cv2.destroyAllWindows()