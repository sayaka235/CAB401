@echo off
setlocal
cd /d "%~dp0"

if not exist results mkdir results

if not exist results\expected_pairs.txt (
    echo ERROR: results\expected_pairs.txt is missing.
    exit /b 1
)

set OMP_DYNAMIC=FALSE

rem Warm-up runs. These runs are not measured.
call :run before warmup
if errorlevel 1 exit /b 1

call :run serial warmup
if errorlevel 1 exit /b 1

for %%t in (1 2 3 4 5 6 7 8) do (
    call :run %%t warmup
    if errorlevel 1 exit /b 1
)

rem Five measured rounds.
rem Reverse configuration order on alternate rounds.
rem This reduces consistent first/last configuration bias.
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
for %%c in (before serial 1 2 3 4 5 6 7 8) do (
    call :run %%c %1
    if errorlevel 1 exit /b 1
)
exit /b 0


:reverse
for %%c in (8 7 6 5 4 3 2 1 serial before) do (
    call :run %%c %1
    if errorlevel 1 exit /b 1
)
exit /b 0


:run
set "config=%~1"
set "trial=%~2"
set "output=results\final_%config%_%trial%.txt"

if "%config%"=="before" (
    set "program=build\cvtree_before.exe"
) else if "%config%"=="serial" (
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
    echo ERROR: no comparison results found for %config%, trial %trial%.
    exit /b 1
)

fc /b results\expected_pairs.txt "results\final_%config%_%trial%_pairs.txt" > "results\final_%config%_%trial%_validation.txt"

if errorlevel 1 (
    echo ERROR: output mismatch for %config%, trial %trial%.
    exit /b 1
)

echo PASS: %config%, trial %trial%
exit /b 0