
import sys
import os
import cv2
import numpy as np
import base64
from unittest.mock import MagicMock

# Mock mediapipe before importing face_service
sys.modules['mediapipe'] = MagicMock()
sys.modules['mediapipe'].solutions = MagicMock()
sys.modules['mediapipe'].solutions.face_mesh = MagicMock()
sys.modules['mediapipe'].solutions.selfie_segmentation = MagicMock()

# Add backend to path
sys.path.append(os.path.join(os.getcwd(), 'backend'))

from face_service import face_service

def test_initialization():
    print("Testing FaceService initialization...")
    categories = face_service.get_categories()
    print(f"Categories: {categories}")
    
    if 'Male' in categories and 'Female' in categories:
        print("PASS: Male and Female categories loaded.")
    else:
        print("FAIL: Male/Female categories missing.")
        return False
        
    male_assets = face_service.get_category_assets('Male')
    print(f"Male assets count: {len(male_assets)}")
    
    if len(male_assets) > 0:
        asset = face_service.get_asset_by_id(male_assets[0]['id'])
        print(f"First Male asset type: {asset.get('type')}")
        if asset.get('type') == 'overlay':
            print("PASS: Asset type is correctly set to 'overlay'.")
        else:
            print(f"FAIL: Asset type is {asset.get('type')}")
            return False
            
    return True

def test_process_frame():
    print("\nTesting process_frame with overlay...")
    # Create a dummy image with a face (using just a blank image for now, 
    # but face_service needs landmarks)
    # Ideally we need a real image with a face to get landmarks.
    # We can try to load one from assets if available, or just skip if no face found logic handles it gracefully?
    # Actually, process_frame REQUIRES a face to be detected to do anything.
    
    img = np.zeros((480, 640, 3), dtype=np.uint8)
    cv2.circle(img, (320, 240), 100, (200, 200, 200), -1) # Pseudo face
    
    # We can't easily mock MediaPipe results without a real face image.
    # So we will skip the functional test of process_frame unless we have a face image.
    # However, we can check if the function runs without crashing.
    
    _, buffer = cv2.imencode('.jpg', img)
    img_b64 = base64.b64encode(buffer).decode('utf-8')
    
    # Pick an asset
    male_assets = face_service.get_category_assets('Male')
    if not male_assets:
        print("No male assets to test.")
        return
        
    asset_id = male_assets[0]['id']
    
    try:
        result = face_service.process_frame(img_b64, asset_id)
        if result:
            print("PASS: process_frame executed (result returned).")
        else:
            print("INFO: process_frame returned None (expected if no face detected).")
    except Exception as e:
        print(f"FAIL: process_frame crashed: {e}")

if __name__ == "__main__":
    if test_initialization():
        test_process_frame()
