@echo off 

:: Set path
set substancePath="%userprofile%\Documents\Adobe\Adobe Substance 3D Painter\assets\"

echo Folder destination for our files are...
echo %substancePath%
echo:

echo Moving files...
@xcopy "assets\" %substancePath% /S/Y/I

echo:
echo We are done here! 
echo:

pause

:: /F = This option will display the full path and file name of both the source and destination files being copied.
:: /I = Use the /i option to force xcopy to assume that destination is a directory.
:: /R = Use this option to overwrite read-only files in destination. 
:: /U = This option will only copy files in source that are already in destination.
:: /Q = A kind of opposite of the /f option, the /q switch will put xcopy into "quiet" mode, skipping the on-screen display of each file being copied.
:: /Y = Use this option to stop the xcopy command from prompting you about overwriting files from source that already exist in destination.
:: /S = Copy folders and subfolders