@echo off
IF EXIST "*.exe" (
    move /Y *.exe .\installer\files\
)
IF EXIST "*_stripped.au3" (
    del /q *_stripped.au3
)
copy /Y .\AideBacBackup\AideBB.chm .\installer\files\
pause