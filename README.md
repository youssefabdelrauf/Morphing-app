<div align="center">
  
# MORPHY - Face Morphing Mobile App 
A real-time face morphing application that allows users to transform their appearance using advanced image processing and facial manipulation technology.
![ApplicationOverview](https://github.com/youssefabdelrauf/Morphing-app/blob/main/assets/main.jpeg)
</p></div>

## Overview 
This mobile application provides real-time face morphing capabilities through the device camera, enabling users to blend their facial features with various preset options including animals, celebrities, historical figures, human races, and accessories. The app uses AI-powered gender detection to intelligently customize available morphing options.

---

## Table of Contents

- [Features](#features)
- [System Architecture](#system-architecture)
- [Technology Stack](#technology-stack)
- [Installation](#-installation)
- [Module Overview](#-module-overview)
- [Usage Guide](#-usage-guide)
- [Demo Videos](#-demo-videos)
- [Technical Documentation](#-technical-documentation)
- [Development Team](#-development-team)
- [License](#-license)

---
## Features

### core capabilities 
- **Multi-Platform Support**: Runs on Android, iOS, Windows, macOS, Linux, and Web
- **User Authentication**: Sign in with email and username
- **Theme Customization**: Multiple theme options for personalized experience
- **Real-Time Processing**: Live face morphing directly from camera feed at 30+ FPS
- **AI Gender Detection**: Automatically detects user gender to display appropriate morphing options
- **Morphing Slider**: Smooth transition control between original face (0%) and full morph (100%)
- **Video Recording**: Capture and export morphing sessions as high-quality video files
- **Interactive Audio**: Mouth-triggered sound effects for select filters (plays when mouth opens, stops when closed)
- **Instant Preview**: See transformations in real-time with zero lag
- **Export Options**: Save recordings to device gallery with one tap

###  Five Specialized Categories 
Each category contains 4 unique morphing options:

1. **Animals** - Transform with animal characteristics
2. **Celebrities** - Morph into famous personalities from entertainment and sports
3. **Historical Figures** - Blend features with influential figures from different eras
4. **Human Races** - Explore facial features representing different ethnic backgrounds
5. **Add-ons** - Apply virtual accessories and enhancements according to your gender
---
## System Architecture

```
Morphing-app/
├──  .gitignore                   # Git ignore rules
├──  README.md                    # Main project documentation
├──  .vscode/                     # VS Code workspace settings
│   └── settings.json
│
├──  UI/                          # UI-related Python experiments & assets
│   ├── Face.py                   # Face processing / UI-side testing script
│   └── assets/                   # Images, icons, and UI resources
│
├──  backend/                     # FastAPI backend server
│   ├── main.py                   # FastAPI app entry point & API routes
│   ├── face_service.py           # Core face morphing logic
│   ├── requirements.txt          # Backend Python dependencies
│   ├── output.avi                # Sample recorded morphing output
│   └── __pycache__/              # Python cache files
│
├──  task5_face_app/              # Flutter application (multi-platform)
│   ├── android/                  # Android platform configuration
│   ├── ios/                      # iOS platform configuration
│   ├── linux/                    # Linux desktop support
│   ├── macos/                    # macOS desktop support
│   ├── windows/                  # Windows desktop support
│   ├── web/                      # Web platform support
│   ├── lib/                      # Dart source code (UI & app logic)
│   ├── test/                     # Flutter unit & widget tests
│   ├── pubspec.yaml              # Flutter dependencies
│   ├── pubspec.lock              # Locked dependency versions
│   └── analysis_options.yaml     # Dart analyzer configuration
│
├──  task5_ai_gender/             # AI gender detection module
│   ├── AgeGenderDeepLearning-master/ # Reference deep learning implementation
│   ├── deploy.prototxt           # Model architecture definition
│   ├── gender_net.caffemodel     # Pre-trained gender classification model
│   ├── gender_model.keras        # Keras-based gender model
│   ├── realtime_test.py          # Real-time gender detection test
│   └── train_gender.py           # Gender model training script
│
├──  test_mp.py                    # MediaPipe / multiprocessing test script
├──  verify_backend.py             # Backend verification & testing script
├──  run_backend.bat               # Windows batch script to start backend
└──  info.jpg                      # Project overview / demo image

```
---
## Technology Stack

| Component | Technology | Purpose |
|---------|------------|---------|
| **Mobile Framework** | Flutter 3.0+ | Cross-platform app (Android, iOS, Desktop, Web) |
| **Frontend Language** | Dart 2.17+ | Flutter application development |
| **Backend Framework** | FastAPI (Python) | RESTful API server for face processing |
| **Web Server** | Uvicorn / ASGI | High-performance asynchronous server |
| **Authentication** | Email / Password | User account management |
| **UI Theming** | Flutter Themes | Customizable application appearance |
| **AI** / **ML** | TensorFlow, PyTorch | Gender detection and AI-based models |
| **Image Processing** | OpenCV, NumPy, Pillow | Facial landmark detection and manipulation |
| **Data Validation** | Pydantic | Request and response schema validation |
| **Video Processing** | OpenCV (cv2) | Video recording and encoding |
| **Build System** | C++ / CMake | Native module compilation |

---
## Installation
**Prerequisites**

```bash
# Python Version
Python 3.8 or higher

# Flutter SDK
Flutter 3.0+
Dart SDK 2.17+

# System Requirements
- OS: Android 8.0+ / iOS 12.0+ / Windows 10+ / macOS 10.15+ / Linux (Ubuntu 20.04+)
- RAM: 4GB minimum, 6GB recommended
- Camera: Front-facing camera with 720p resolution minimum
- Storage: 500MB available space
- Internet: Required for initial setup and authentication
```
**Setup Instructions**

1. Clone the Repository
   ```bash
   git clone https://github.com/youssefabdelrauf/Morphing-app
   ```
2. Install Python Dependencies
  ```bash
   pip install fastapi uvicorn pydantic opencv-python numpy pillow tensorflow
   # Or if you have requirements.txt:
   pip install -r requirements.txt
   ```
