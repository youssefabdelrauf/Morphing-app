import cv2
import numpy as np
import os
import glob
import base64
import mediapipe as mp
from typing import Dict, List, Optional, Any


class FaceService:
    """Face morphing service that processes frames and applies face filters."""
    
    _instance = None
    
    def __new__(cls):
        if cls._instance is None:
            cls._instance = super().__new__(cls)
            cls._instance._initialized = False
        return cls._instance
    
    def __init__(self):
        if self._initialized:
            return
            
        self._initialized = True
        
        # Assets directory path (relative to backend folder)
        self.assets_dir = os.path.join(os.path.dirname(__file__), "..", "UI", "assets")
        
        # Initialize MediaPipe Face Mesh
        self.mp_face_mesh = mp.solutions.face_mesh
        self.mp_selfie_segmentation = mp.solutions.selfie_segmentation

        # Live stream mesh (faster)
        self.face_mesh = self.mp_face_mesh.FaceMesh(
            static_image_mode=False, 
            max_num_faces=1, 
            refine_landmarks=True,
            min_detection_confidence=0.5
        )

        # Asset loader mesh (higher accuracy)
        self.asset_loader_mesh = self.mp_face_mesh.FaceMesh(
            static_image_mode=True,
            max_num_faces=1,
            refine_landmarks=True,
            min_detection_confidence=0.1
        )

        self.segmenter = self.mp_selfie_segmentation.SelfieSegmentation(model_selection=1)

        # Initialize face cascade for face detection (used in gender detection)
        cascade_path = cv2.data.haarcascades + 'haarcascade_frontalface_default.xml'
        self.face_cascade = cv2.CascadeClassifier(cascade_path)

        # Initialize Gender Detection Model
        self.gender_model_dir = os.path.join(os.path.dirname(__file__), "..", "task_5_ai_gender")
        self.gender_proto = os.path.join(self.gender_model_dir, "deploy.prototxt")
        self.gender_model = os.path.join(self.gender_model_dir, "gender_net.caffemodel")
        
        self.gender_net = None
        self.gender_list = ['Male', 'Female']
        self.mean_values = (104, 117, 123)
        
        if os.path.exists(self.gender_proto) and os.path.exists(self.gender_model):
            try:
                self.gender_net = cv2.dnn.readNetFromCaffe(self.gender_proto, self.gender_model)
                print("Gender model loaded successfully")
            except Exception as e:
                print(f"Error loading gender model: {e}")
        else:
            print(f"Gender model files not found at {self.gender_model_dir}")
        
        # Load all assets
        self.categories: Dict[str, List[Dict[str, Any]]] = {}
        self._load_assets()
        self._load_overlay_assets()
        
        # Audio & Video State
        self.movie_path = os.path.join(os.path.dirname(__file__), "output.avi")
        self.out_video = None
        self.is_recording = False
        self.recording_frames_count = 0
        
        print(f"FaceService initialized with {len(self.categories)} categories")

    
    def _load_assets(self):
        """Load all assets from the assets directory."""
        if not os.path.exists(self.assets_dir):
            print(f"Assets directory not found: {self.assets_dir}")
            return
        
        folders = [f for f in os.listdir(self.assets_dir) 
                   if os.path.isdir(os.path.join(self.assets_dir, f))]
        
        for folder in folders:
            folder_path = os.path.join(self.assets_dir, folder)
            self.categories[folder] = []
            
            extensions = ('*.png', '*.webp', '*.jpg', '*.jpeg', '*.PNG', '*.JPG', '*.JPEG')
            all_files = []
            for ext in extensions:
                all_files.extend(glob.glob(os.path.join(folder_path, ext)))
            
            unique_files = list(set(all_files))
            
            for idx, fpath in enumerate(unique_files):
                try:
                    asset_data = self._process_asset(fpath, f"{folder}_{idx}")
                    if asset_data:
                        self.categories[folder].append(asset_data)
                except Exception as e:
                    print(f"Error loading asset {fpath}: {e}")
            
            print(f"Loaded {len(self.categories[folder])} assets from {folder}")

    def _load_overlay_assets(self):
        """Load simple overlay assets (no face detection needed)."""
        overlay_folders = ['Male', 'Female']
        for folder in overlay_folders:
            folder_path = os.path.join(self.assets_dir, folder)
            if not os.path.isdir(folder_path):
                continue
            
            # Ensure category exists
            if folder not in self.categories:
                self.categories[folder] = []
                
            extensions = ('*.png', '*.webp', '*.jpg', '*.jpeg', '*.PNG', '*.JPG', '*.JPEG')
            all_files = []
            for ext in extensions:
                all_files.extend(glob.glob(os.path.join(folder_path, ext)))
            
            unique_files = list(set(all_files))
            
            for idx, fpath in enumerate(unique_files):
                # Skip if already loaded (by _load_assets, though unlikely if they failed face check)
                existing_ids = [a['id'] for a in self.categories[folder]]
                asset_id = f"{folder}_{idx}_overlay"
                
                # Basic load without mediapipe
                img = cv2.imread(fpath, cv2.IMREAD_UNCHANGED)
                if img is None: continue
                
                # Ensure RGBA
                if img.shape[2] == 3:
                    img = cv2.cvtColor(img, cv2.COLOR_BGR2BGRA)
                
                # Thumbnail
                h, w = img.shape[:2]
                scale = 60 / max(h, w)
                thumb = cv2.resize(img, (int(w*scale), int(h*scale)))
                
                # Center on 60x60
                thumb_final = np.zeros((60, 60, 4), dtype=np.uint8)
                ty = (60 - thumb.shape[0]) // 2
                tx = (60 - thumb.shape[1]) // 2
                thumb_final[ty:ty+thumb.shape[0], tx:tx+thumb.shape[1]] = thumb
                
                _, thumb_buffer = cv2.imencode('.png', thumb_final)
                thumb_b64 = base64.b64encode(thumb_buffer).decode('utf-8')

                asset_data = {
                    "id": asset_id,
                    "name": os.path.basename(fpath),
                    "img": img, # Raw RGBA image
                    "type": "overlay",
                    "folder": folder,
                    "thumbnail": thumb_b64
                }
                self.categories[folder].append(asset_data)
        
        print(f"Loaded overlay assets for {overlay_folders}")
    
    def calculate_delaunay(self, points):
        rect = (0, 0, 4000, 4000)
        subdiv = cv2.Subdiv2D(rect)
        for p in points: subdiv.insert((float(p[0]), float(p[1])))
        pt_dict = {(p[0], p[1]): i for i, p in enumerate(points)}
        triangles = []
        for t in subdiv.getTriangleList():
            pts = [(int(t[0]), int(t[1])), (int(t[2]), int(t[3])), (int(t[4]), int(t[5]))]
            if all(pt in pt_dict for pt in pts): triangles.append([pt_dict[pt] for pt in pts])
        return triangles

    def get_user_boundary_points(self, user_lm, frame_w, frame_h):
        x_min, y_min = np.min(user_lm, axis=0)
        x_max, y_max = np.max(user_lm, axis=0)
        wf, hf = x_max - x_min, y_max - y_min
        cx, cy = (x_min + x_max) // 2, (y_min + y_max) // 2
        s = 0.6
        nx1, nx2 = max(0, cx-int(wf*(0.5+s))), min(frame_w, cx+int(wf*(0.5+s)))
        ny1, ny2 = max(0, cy-int(hf*(0.5+s))), min(frame_h, cy+int(hf*(0.5+s)))
        return np.array([[nx1,ny1],[cx,ny1],[nx2,ny1],[nx2,cy],[nx2,ny2],[cx,ny2],[nx1,ny2],[nx1,cy]], dtype=np.int32)
    
    def warp_face_transparent(self, frame, asset, user_lm, opacity=1.0):
        frame_h, frame_w = frame.shape[:2]
        src_img, src_pts, tris = asset["img"], asset["lm"], asset["tri"]
        user_pts = np.vstack((user_lm, self.get_user_boundary_points(user_lm, frame_w, frame_h)))
        warped_rgba = np.zeros((frame_h, frame_w, 4), dtype=np.uint8)

        for tri in tris:
            ps = [src_pts[i] for i in tri]
            pt = [user_pts[i] for i in tri]
            r1, r2 = cv2.boundingRect(np.float32(ps)), cv2.boundingRect(np.float32(pt))
            if r1[2]<=0 or r1[3]<=0 or r2[2]<=0 or r2[3]<=0: continue
            ts = [(p[0]-r1[0], p[1]-r1[1]) for p in ps]
            tt = [(p[0]-r2[0], p[1]-r2[1]) for p in pt]
            mask = np.zeros((r2[3], r2[2]), dtype=np.uint8)
            cv2.fillConvexPoly(mask, np.int32(tt), 255)
            img1 = src_img[r1[1]:r1[1]+r1[3], r1[0]:r1[0]+r1[2]]
            mat = cv2.getAffineTransform(np.float32(ts), np.float32(tt))
            img2 = cv2.warpAffine(img1, mat, (r2[2], r2[3]), None, flags=cv2.INTER_LINEAR, borderMode=cv2.BORDER_CONSTANT, borderValue=(0,0,0,0))
            y1, y2, x1, x2 = r2[1], r2[1]+r2[3], r2[0], r2[0]+r2[2]
            if y1<0 or x1<0 or y2>frame_h or x2>frame_w: continue
            target = warped_rgba[y1:y2, x1:x2]
            target[mask>0] = img2[mask>0]

        rgb = warped_rgba[:,:,:3]
        final_alpha = (warped_rgba[:,:,3]/255.0) * opacity 
        a3 = np.dstack([final_alpha]*3)
        final_img = (rgb.astype(np.float32) * a3 + frame.astype(np.float32) * (1.0 - a3)).astype(np.uint8)
        return final_img

    def _process_asset(self, fpath: str, asset_id: str) -> Optional[Dict]:
        """Process a single asset image and prepare it for warp."""
        img_original = cv2.imread(fpath)
        if img_original is None: return None

        # Check for sound (metadata only for now)
        base_name = os.path.splitext(fpath)[0]
        sound_path = None
        if os.path.exists(base_name + ".wav"): sound_path = base_name + ".wav"
        elif os.path.exists(base_name + ".mp3"): sound_path = base_name + ".mp3"
            
        img_rgb = cv2.cvtColor(img_original, cv2.COLOR_BGR2RGB)
        h, w = img_original.shape[:2]

        res = self.asset_loader_mesh.process(img_rgb)
        if not res.multi_face_landmarks:
            temp_img = cv2.resize(img_rgb, (w*2, h*2))
            res = self.asset_loader_mesh.process(temp_img)
            if not res.multi_face_landmarks: return None
            landmarks = np.array([[int(p.x * w), int(p.y * h)] for p in res.multi_face_landmarks[0].landmark], dtype=np.int32)
        else:
            landmarks = np.array([[int(p.x * w), int(p.y * h)] for p in res.multi_face_landmarks[0].landmark], dtype=np.int32)
        
        folder_name = os.path.basename(os.path.dirname(fpath))
        
        # 1. Animals Logic
        if folder_name.lower() == 'animals':
            seg_res = self.segmenter.process(img_rgb)
            mask_val = seg_res.segmentation_mask if seg_res.segmentation_mask is not None else np.ones((h, w), dtype=np.float32)
            final_mask = (mask_val > 0.4).astype(np.uint8) * 255
        else:
            # 2. Face/Neck cut logic
            # JAWLINE_INDICES from original Face.py
            JAWLINE_INDICES = [234, 93, 132, 58, 172, 136, 150, 149, 176, 148, 152, 377, 400, 378, 379, 365, 397, 288, 361, 323, 454]
            jaw_points = landmarks[JAWLINE_INDICES]
            
            poly_points = [[0, 0]] 
            poly_points.append([w, 0])
            poly_points.append([w, jaw_points[-1][1]])
            for p in reversed(jaw_points):
                poly_points.append([p[0], p[1]])
            poly_points.append([0, jaw_points[0][1]])
            
            poly_points_np = np.array(poly_points, dtype=np.int32)
            
            face_shape_mask = np.zeros((h, w), dtype=np.uint8)
            cv2.fillPoly(face_shape_mask, [poly_points_np], 255)
            
            # Remove background using segmentation
            seg_res = self.segmenter.process(img_rgb)
            mask_val = seg_res.segmentation_mask if seg_res.segmentation_mask is not None else np.ones((h, w), dtype=np.float32)
            seg_mask = (mask_val > 0.4).astype(np.uint8) * 255
            
            final_mask = cv2.bitwise_and(seg_mask, face_shape_mask)

        # --- White Background Removal Mask ---
        # Convert to grayscale and identify pixels close to pure white (above 240)
        gray = cv2.cvtColor(img_rgb, cv2.COLOR_RGB2GRAY)
        _, white_mask = cv2.threshold(gray, 240, 255, cv2.THRESH_BINARY_INV)
        
        # Combine white removal with existing segmentation mask
        final_mask = cv2.bitwise_and(final_mask, white_mask)

        final_mask = cv2.GaussianBlur(final_mask, (5, 5), 0)
        b, g, r = cv2.split(img_original)
        img_rgba = cv2.merge((b, g, r, final_mask))
        
        # Thumbnail generation
        thumb = cv2.resize(img_rgba, (60, 60))
        mask_c = np.zeros((60, 60), dtype=np.uint8)
        cv2.circle(mask_c, (30, 30), 30, 255, -1)
        tb, tg, tr, ta = cv2.split(thumb)
        ta = cv2.bitwise_and(ta, ta, mask=mask_c)
        thumb_final = cv2.merge((tb, tg, tr, ta))
        
        # Encode thumbnail
        _, thumb_buffer = cv2.imencode('.png', thumb_final)
        thumb_b64 = base64.b64encode(thumb_buffer).decode('utf-8')
        
        # Calculate Triangulation for warping
        boundary = np.array([[0,0], [w//2,0], [w-1,0], [w-1,h//2], [w-1,h-1], [w//2,h-1], [0,h-1], [0,h//2]])
        full_lm = np.vstack((landmarks, boundary))
        tri = self.calculate_delaunay(full_lm)
        
        return {
            "id": asset_id,
            "name": os.path.basename(fpath),
            "img": img_rgba,
            "lm": full_lm,
            "tri": tri,
            "thumb": thumb_final,
            "sound": sound_path,
            "thumbnail": thumb_b64
        }
    
    def get_categories(self) -> List[str]:
        """Get list of available categories."""
        return list(self.categories.keys())
    
    def get_category_assets(self, category: str) -> List[Dict]:
        """Get assets for a specific category."""
        if category not in self.categories:
            return []
        
        return [
            {
                "id": asset["id"],
                "name": asset["name"],
                "thumbnail": asset["thumbnail"],
                "folder": category,
                "has_sound": asset.get("sound") is not None,
                "sound_file": os.path.basename(asset["sound"]) if asset.get("sound") else None
            }
            for asset in self.categories[category]
        ]
    
    def get_asset_by_id(self, asset_id: str) -> Optional[Dict]:
        """Find an asset by its ID."""
        for category in self.categories.values():
            for asset in category:
                if asset["id"] == asset_id:
                    return asset
        return None
    
    def process_frame(self, frame_b64: str, asset_id: str, opacity: float = 1.0) -> Optional[Dict[str, Any]]:
        """
        Process a frame with face overlay.
        Returns dict with 'frame' (base64) and 'mouth_open' (bool).
        """
        mouth_open = False
        
        # Decode base64 image
        try:
            img_data = base64.b64decode(frame_b64)
            nparr = np.frombuffer(img_data, np.uint8)
            frame = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        except Exception as e:
            print(f"Error decoding image: {e}")
            return None
        
        if frame is None:
            return None
        
        frame_h, frame_w = frame.shape[:2]
        
        # Initialize video writer if recording
        if self.is_recording and self.out_video is None:
             # Initialize lazily with actual frame size
             fourcc = cv2.VideoWriter_fourcc(*'MJPG')
             self.out_video = cv2.VideoWriter(self.movie_path, fourcc, 20.0, (frame_w, frame_h))
             print(f"Video Writer Initialized: {frame_w}x{frame_h}")

        # Get asset
        asset = self.get_asset_by_id(asset_id)
        if asset is None:
            # Just return original frame if no asset
            _, buffer = cv2.imencode('.jpg', frame)
            
            # Record original even if no asset
            if self.is_recording and self.out_video is not None:
                self.out_video.write(frame)
                self.recording_frames_count += 1
                
            return {
                "frame": base64.b64encode(buffer).decode('utf-8'),
                "mouth_open": False
            }
            
        output = frame.copy()
        
        # Process with Face Mesh
        rgb_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        res = self.face_mesh.process(rgb_frame)
        
        if res.multi_face_landmarks:
            raw_landmarks = res.multi_face_landmarks[0].landmark
            pts = np.array([[int(p.x * frame_w), int(p.y * frame_h)] for p in raw_landmarks], dtype=np.int32)
            
            # Check asset type and apply appropriate overlay
            asset_type = asset.get("type", "mask") # Default to mask
            
            if asset_type == "overlay" or asset_type == "prop":
                 output = self.apply_overlay(frame, asset, pts, opacity)
            else:
                 # Default Face Warp
                 output = self.warp_face_transparent(frame, asset, pts, opacity)
            
            # Detect mouth open (same logic as Face.py)
            if asset.get("sound"):
                upper_lip_y = raw_landmarks[13].y
                lower_lip_y = raw_landmarks[14].y
                face_height = raw_landmarks[152].y - raw_landmarks[10].y
                if face_height > 0:
                    ratio = (lower_lip_y - upper_lip_y) / face_height
                    is_open = ratio > 0.02  # تم تصغيرها من 0.05
                    if is_open != mouth_open:
                        # This avoids spamming logs but shows transition
                        # Note: we return current state to flutter
                        mouth_open = is_open
                        print(f"[DEBUG] Backend Mouth Status: {'OPEN' if mouth_open else 'CLOSED'} (Ratio: {ratio:.4f})")
        
        # Write to video if recording
        if self.is_recording and self.out_video is not None:
            self.out_video.write(output)
            self.recording_frames_count += 1

        # Encode result
        _, buffer = cv2.imencode('.jpg', output)
        return {
            "frame": base64.b64encode(buffer).decode('utf-8'),
            "mouth_open": mouth_open
        }

    def start_recording(self, width: int = 640, height: int = 480, fps: int = 20):
        try:
            # We ignore width/height here and use the first frame's dimension in process_frame
            self.is_recording = True
            # Reset writer if it exists
            if self.out_video:
                self.out_video.release()
                self.out_video = None
            self.recording_frames_count = 0
            print("Recording mode enabled...")
            return True
        except Exception as e:
            print(f"Error starting recording: {e}")
            return False

    def stop_recording(self) -> Optional[str]:
        self.is_recording = False
        if self.out_video:
            self.out_video.release()
            self.out_video = None
            print(f"Recording stopped. Total frames: {self.recording_frames_count}")
        
        # If no frames were recorded, return None
        if self.recording_frames_count == 0:
            print("No frames recorded.")
            return None
            
        # Read file and return base64
        if os.path.exists(self.movie_path):
            try:
                with open(self.movie_path, "rb") as video_file:
                    b64_video = base64.b64encode(video_file.read()).decode('utf-8')
                return b64_video
            except Exception as e:
                print(f"Error reading video file: {e}")
                return None
        return None

    def apply_overlay(self, frame, asset, landmarks, opacity=1.0):
        """
        Apply simple PNG overlay at landmark positions.
        Replaces overlay_rigid with opacity support.
        """
        img_original = asset["img"] # This is RGBA
        folder_name = asset.get("folder", "")
        
        # 1. Determine Anchor Points based on category/filename
        # Default defaults
        center_x = landmarks[1][0] # Nose tip
        center_y = landmarks[1][1]
        scale_factor = 1.0
        angle_deg = 0
        
        name = asset["name"].lower()
        
        if folder_name == "Male" and "glasses" in name:
            p1 = landmarks[33]  # Left Eye inner
            p2 = landmarks[263] # Right Eye inner
            center_x = (p1[0] + p2[0]) // 2
            center_y = (p1[1] + p2[1]) // 2 
            
            # Width based on outer eye corners
            ref_width = np.linalg.norm(landmarks[359] - landmarks[130])
            scale_factor = ref_width / (img_original.shape[1] * 0.45)
            
        elif folder_name == "Male" and "mustache" in name:
            center = landmarks[164] # Philtrum
            center_x, center_y = center[0], center[1]
            
            p1 = landmarks[33]
            p2 = landmarks[263]
            
            ref_width = np.linalg.norm(landmarks[291] - landmarks[61]) # Mouth width
            scale_factor = ref_width / (img_original.shape[1] * 0.6)
            
        else:
            # Fallback / Generic
            p1 = landmarks[33]
            p2 = landmarks[263]
            if "hat" in name:
                center_x = landmarks[10][0] # Forehead top
                center_y = landmarks[10][1]
                ref_width = np.linalg.norm(landmarks[234] - landmarks[454])
                scale_factor = ref_width / (img_original.shape[1] * 0.6)
            else:
                # Default logic from previous overlay_rigid
                center_x = landmarks[1][0]
                center_y = landmarks[1][1]
                ref_width = np.linalg.norm(landmarks[234] - landmarks[454])
                scale_factor = ref_width / img_original.shape[1]

        # 2. Calculate Rotation Angle
        if 'p1' in locals() and 'p2' in locals():
            delta_x = p2[0] - p1[0]
            delta_y = p2[1] - p1[1]
            angle_deg = np.degrees(np.arctan2(delta_y, delta_x))
            
        # 3. Rotate and Scale Image
        h, w = img_original.shape[:2]
        center_img = (w // 2, h // 2)
        
        M = cv2.getRotationMatrix2D(center_img, -angle_deg, scale_factor)
        
        cos = np.abs(M[0, 0])
        sin = np.abs(M[0, 1])
        new_w = int((h * sin) + (w * cos))
        new_h = int((h * cos) + (w * sin))
        
        M[0, 2] += (new_w / 2) - center_img[0]
        M[1, 2] += (new_h / 2) - center_img[1]
        
        rotated_img = cv2.warpAffine(img_original, M, (new_w, new_h), flags=cv2.INTER_LINEAR, borderMode=cv2.BORDER_CONSTANT, borderValue=(0,0,0,0))
        
        # 4. Overlay onto Frame
        y1 = int(center_y - new_h // 2)
        y2 = y1 + new_h
        x1 = int(center_x - new_w // 2)
        x2 = x1 + new_w
        
        frame_h, frame_w = frame.shape[:2]
        
        src_x1, src_y1 = 0, 0
        src_x2, src_y2 = new_w, new_h
        
        if y1 < 0:
            src_y1 -= y1
            y1 = 0
        if x1 < 0:
            src_x1 -= x1
            x1 = 0
        if y2 > frame_h:
            output_h = frame_h - y1
            src_y2 = src_y1 + output_h
            y2 = frame_h
        if x2 > frame_w:
            output_w = frame_w - x1
            src_x2 = src_x1 + output_w
            x2 = frame_w
            
        if y2 <= y1 or x2 <= x1:
            return frame 
            
        target_roi = frame[y1:y2, x1:x2]
        overlay_roi = rotated_img[src_y1:src_y2, src_x1:src_x2]
        
        # Alpha blending with opacity support
        if overlay_roi.shape[2] == 4:
            alpha_overlay = (overlay_roi[:, :, 3] / 255.0) * opacity
            alpha_frame = 1.0 - alpha_overlay
            
            for c in range(3):
                target_roi[:, :, c] = (alpha_overlay * overlay_roi[:, :, c] + 
                                     alpha_frame * target_roi[:, :, c])
                                     
            frame[y1:y2, x1:x2] = target_roi
            
        return frame


    def detect_gender(self, frame_b64: str) -> Dict[str, Any]:
        """
        Detect gender from a base64 encoded frame.
        
        Args:
            frame_b64: Base64 encoded image
            
        Returns:
            Dictionary with gender label and confidence
        """
        if self.gender_net is None:
            return {"error": "Gender model not initialized"}

        # Decode base64 image
        try:
            img_data = base64.b64decode(frame_b64)
            nparr = np.frombuffer(img_data, np.uint8)
            frame = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        except Exception as e:
            print(f"Error decoding image: {e}")
            return {"error": "Invalid image data"}
        
        if frame is None:
            return {"error": "Failed to decode image"}
            
        # Detect face
        gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
        faces = self.face_cascade.detectMultiScale(gray, 1.1, 4, minSize=(50, 50))
        
        if len(faces) == 0:
            return {"gender": "Unknown", "confidence": 0.0}
            
        # Get the largest face
        faces = sorted(faces, key=lambda x: x[2] * x[3], reverse=True)
        x, y, w, h = faces[0]
        
        # Padding
        padding = 20
        face_img = frame[max(0, y-padding):min(frame.shape[0], y+h+padding),
                         max(0, x-padding):min(frame.shape[1], x+w+padding)]
                         
        if face_img.size == 0:
             return {"gender": "Unknown", "confidence": 0.0}
             
        # Prepare input blob for Caffe model
        blob = cv2.dnn.blobFromImage(face_img, 1.0, (227, 227), self.mean_values, swapRB=False)
        self.gender_net.setInput(blob)
        preds = self.gender_net.forward()
        
        i = preds[0].argmax()
        gender = self.gender_list[i]
        confidence = preds[0][i]
        
        return {
            "gender": gender,
            "confidence": float(confidence)
        }


# Singleton instance
face_service = FaceService()

