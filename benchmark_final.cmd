@echo off
setlocal
cd /d "%~dp0"

if not exist results mkdir results

if not exist results\expected_pairs.txt (
    echo ERROR: results\expected_pairs.txt is missing.
    exit /b 1
)

set OMP_DYNAMIC=FALSE

rem Warm up each configuration. These runs are not measured.
call :run serial warmup
if errorlevel 1 exit /b 1

for %%t in (1 2 3 4 5 6 7 8 9 10 11 12) do (
    call :run %%t warmup
    if errorlevel 1 exit /b 1
)

rem Reverse configuration order on alternate rounds.
rem This reduces a consistent first/last configuration bias.
for %%r in (1 2 3 4 5) do (
    if %%r==2 (
        call :reverse %%r
    ) else if %%r==4 (
        call :reverse %%r
    ) else (
        call :forward %%r
    )
    if errorlevel 1 exit /b 1
)

echo.
echo SUCCESS: all measured runs completed and matched the baseline.
exit /b 0

:forward
for %%c in (serial 1 2 3 4 5 6 7 8 9 10 11 12) do (
    call :run %%c %1
    if errorlevel 1 exit /b 1
)
exit /b 0

:reverse
for %%c in (12 11 10 9 8 7 6 5 4 3 2 1 serial) do (
    call :run %%c %1
    if errorlevel 1 exit /b 1
)
exit /b 0

:run
set "config=%~1"
set "trial=%~2"
set "output=results\final_%config%_%trial%.txt"

if "%config%"=="serial" (
    set "program=build\final_serial.exe"
) else (
    set "OMP_NUM_THREADS=%config%"
    set "program=build\final_openmp.exe"
)

echo Running %config%, trial %trial%...
"%program%" > "%output%"
if errorlevel 1 (
    echo ERROR: program failed for %config%, trial %trial%.
    exit /b 1
)

findstr /C:" -> " "%output%" > "results\final_%config%_%trial%_pairs.txt"
if errorlevel 1 (
    echo ERROR: no comparison results found.
    exit /b 1
)

fc /b results\expected_pairs.txt "results\final_%config%_%trial%_pairs.txt" > "results\final_%config%_%trial%_validation.txt"
if errorlevel 1 (
    echo ERROR: output mismatch for %config%, trial %trial%.
    exit /b 1
)

echo PASS: %config%, trial %trial%
exit /b 0