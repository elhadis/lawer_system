@echo off
REM Default "flutter run -d windows" uses Debug and fails with LNK1104 on this PC.
cd /d "%~dp0"
flutter run -d windows --release
