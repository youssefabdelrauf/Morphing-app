<div align="center">
  
# MORPHY - Face Morphing Mobile App 
A real-time face morphing application that allows users to transform their appearance using advanced image processing and facial manipulation technology.
![ApplicationOverview](https://github.com/youssefabdelrauf/Morphing-app/blob/main/assets/main.jpeg)
</p></div>

## Overview 
This mobile application provides real-time face morphing capabilities through the device camera, enabling users to blend their facial features with various preset options including animals, celebrities, historical figures, human races, and accessories. The app uses AI-powered gender detection to intelligently customize available morphing options.

---

## Table of Contents

- [Features](#-features)
- [System Architecture](#️-system-architecture)
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

## System Architecture

```
Morphing-app/
├── 📄 .gitignore                # Git ignore configuration
├── 📝 README.md                 # Project documentation
├── 🗂️ .vscode/                  # VS Code workspace settings
├── 🎨 UI/                       # User interface assets
│   └── assets/                  # Images, sounds, icons
├── ⚙️ backend/                  # FastAPI backend server
│   ├── main.py                  # FastAPI application & routes
│   ├── face_service.py          # Core morphing logic
│   └── [Model files & utilities]
├── 📱 task5_face_app/           # Flutter mobile application
│   ├── android/                 # Android build configuration
│   ├── ios/                     # iOS build configuration
│   ├── linux/                   # Linux desktop support
│   ├── macos/                   # macOS desktop support
│   ├── windows/                 # Windows desktop support
│   ├── web/                     # Web platform support
│   ├── lib/                     # Dart source code
│   ├── test/                    # Unit & widget tests
│   ├── pubspec.yaml             # Flutter dependencies
│   ├── pubspec.lock             # Locked dependency versions
│   └── analysis_options.yaml   # Dart analyzer configuration
├── 🤖 task_5_ai_gender/         # AI gender detection module
│   └── [ML models & inference scripts]
├── 🧪 test_mp.py                # Multiprocessing test suite
├── 🔍 verify_backend.py         # Backend verification script
├── ▶️ run_backend.bat           # Backend startup script (Windows)
└── 📊 info.jpg                  # Project information graphic

```
