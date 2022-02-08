set INPUT_DIR=".\input"
set OUTPUT_DIR=".\output"

rmdir /s/q %OUTPUT_DIR%
mkdir output

PowerShell .\UIMerger.ps1 "%INPUT_DIR%" "%OUTPUT_DIR%"

pause
