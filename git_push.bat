@echo off
cd /d "%~dp0"

echo ODD app - Git upload (v3.23.0)
echo.

del /f /q ".git\index.lock" 2>nul

echo [1/3] git add ...
git add -A

echo [2/3] git commit ...
git commit -m "v3.23.0: map new-auth(NCP_KEY_ID), explore top-map, page transitions, D-day banner, remove AI text, Gowun Dodum font"

echo [3/3] git push origin main ...
git push origin main

echo.
echo Done. If there are no red errors above, upload succeeded.
pause
