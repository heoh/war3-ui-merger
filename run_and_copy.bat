set DESTINATION_DIR="..\..\wc3\UI"

call "run.bat"
copy ".\output\*" "%DESTINATION_DIR%"

pause
