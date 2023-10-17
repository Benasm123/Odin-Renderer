@ECHO OFF
forfiles /p src /m *.* /c "cmd /c ECHO Compiling @file&glslc.exe @file -o ../Compiled/@file.spv"
Rem forfiles /p src /m *.frag /c "cmd /c ECHO Compiling @file&glslc.exe @file -o ../Compiled/@file.spv"
Rem forfiles /p src /m *.tess /c "cmd /c ECHO Compiling @file&glslc.exe @file -o ../Compiled/@file.spv"
Rem forfiles /p src /m *.geom /c "cmd /c ECHO Compiling @file&glslc.exe @file -o ../Compiled/@file.spv"
Rem forfiles /p src /m *.comp /c "cmd /c ECHO Compiling @file&glslc.exe @file -o ../Compiled/@file.spv"
PAUSE
