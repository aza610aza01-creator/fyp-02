Windows YOLO camera feed for the Flutter app

1. Run SETUP.bat once. It selects an installed Python 3.11+ interpreter, creates a local .venv, installs the camera/MediaPipe/Ultralytics dependencies, and downloads yolov8n-pose.pt plus pose_landmarker_full.task.
2. Open the Flutter app's Camera screen. It starts the local Python service automatically and displays real-time YOLO detections and pose coaching.
3. Select Push-Up, then choose Front or Side view. The guide-driven rep counter and form feedback are validated for push-ups; the other exercise phase estimates are prototypes.
4. On Windows, choose Import video for YOLO analysis in the dashboard's Running & pose tab or the Camera screen to analyze a local video. The app shows the annotated frame, measured joint angles, recognized phase, and form guidance; the file is processed locally and is not uploaded.
5. If the app cannot discover this folder, set AI_GYM_PYTHON_POSE_DIR to its path. Set AI_GYM_PYTHON_EXE to an existing Python interpreter when its environment is outside this folder; it must have the packages in requirements.txt installed.
6. The app stops a service it started when the camera closes. A manually started service remains under your control.

The bridge binds to localhost only. Use --camera-index N with gym_pose_yolo.py if the default webcam is not the camera you want. The existing RUN_SIDE.bat and RUN_FRONT.bat scripts continue to launch the standalone pose coach.
