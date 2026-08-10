@echo off
setlocal EnableExtensions EnableDelayedExpansion
title pvr.ccz 정리

rem ============================================================
rem  .pvr.ccz 파일을 지웁니다. (png 로 이미 변환된 원본)
rem
rem  안전장치
rem   - 같은 이름의 .png 가 옆에 있는 것만 지웁니다.
rem   - png 짝이 없는 ccz 는 지우지 않고 따로 알려줍니다.
rem   - 목록을 먼저 보여주고, DELETE 를 입력해야 실행됩니다.
rem
rem  사용법
rem   1) 이 파일을 dragon 폴더 안에 두고 더블클릭
rem   2) 또는 폴더를 이 파일 위로 끌어다 놓기
rem ============================================================

if not "%~1"=="" (
  set "ROOT=%~1"
) else (
  set "ROOT=%~dp0"
)
if "%ROOT:~-1%"=="\" set "ROOT=%ROOT:~0,-1%"

if not exist "%ROOT%\" (
  echo [오류] 폴더를 찾을 수 없습니다: "%ROOT%"
  goto :done
)

echo.
echo  대상 폴더 : %ROOT%
echo.

set "LIST=%TEMP%\dv_ccz_%RANDOM%.txt"
set "ORPH=%TEMP%\dv_orphan_%RANDOM%.txt"
if exist "%LIST%" del /q "%LIST%"
if exist "%ORPH%" del /q "%ORPH%"

rem ---------- 1단계: 대상 수집 ----------
echo  검사 중...
set /a TOTAL=0
set /a ORPHANS=0

> "%LIST%" (
  for /r "%ROOT%" %%F in (*.ccz) do (
    set "BASE=%%~nF"
    rem 확장자가 .pvr.ccz 인 것만 - %%~nF 는 "이름.pvr" 형태
    if /i "!BASE:~-4!"==".pvr" (
      set /a TOTAL+=1
      set "STEM=%%~dpnF"
      set "STEM=!STEM:~0,-4!"
      if exist "!STEM!.png" (
        echo %%F
      ) else (
        set /a ORPHANS+=1
        >>"%ORPH%" echo %%F
      )
    )
  )
)

set /a FILES=0
for /f %%C in ('find /c /v "" ^< "%LIST%"') do set /a FILES=%%C

if %TOTAL%==0 (
  echo.
  echo  .pvr.ccz 파일이 없습니다. 이미 정리된 상태입니다.
  goto :cleanup
)

rem ---------- 용량 ----------
set "SIZEFILE=%TEMP%\dv_size_%RANDOM%.txt"
set "SIZETXT="
powershell -NoProfile -Command "$t=0; Get-Content -LiteralPath '%LIST%' | ForEach-Object { $f=Get-Item -LiteralPath $_ -ErrorAction SilentlyContinue; if($f){$t+=$f.Length} }; Write-Output ('{0:N1} MB' -f ($t/1MB))" > "%SIZEFILE%" 2>nul
if exist "%SIZEFILE%" set /p SIZETXT=<"%SIZEFILE%"
if exist "%SIZEFILE%" del /q "%SIZEFILE%"

echo.
echo  ------------------------------------------------
echo   찾은 .pvr.ccz      : %TOTAL% 개
echo   지울 것 (png 있음) : %FILES% 개
if defined SIZETXT echo   확보되는 용량      : %SIZETXT%
if %ORPHANS% gtr 0 echo   건너뜀 (png 없음)  : %ORPHANS% 개
echo  ------------------------------------------------

if %ORPHANS% gtr 0 (
  echo.
  echo  [주의] png 가 없어 지우지 않는 파일:
  set /a N=0
  for /f "usebackq delims=" %%L in ("%ORPH%") do (
    set /a N+=1
    if !N! leq 10 echo    %%L
  )
  echo  이 파일들은 아직 png 로 변환되지 않았습니다. 그대로 둡니다.
)

if %FILES%==0 (
  echo.
  echo  지울 수 있는 파일이 없습니다.
  goto :cleanup
)

echo.
echo  지울 파일 예시:
set /a N=0
for /f "usebackq delims=" %%L in ("%LIST%") do (
  set /a N+=1
  if !N! leq 6 echo    %%L
)
echo.

rem ---------- 2단계: 확인 ----------
set "OK="
set /p "OK=정말 지우시겠습니까? 지우려면 DELETE 를 입력하세요: "
if /i not "%OK%"=="DELETE" (
  echo.
  echo  취소했습니다. 아무것도 지우지 않았습니다.
  goto :cleanup
)

rem ---------- 3단계: 삭제 ----------
echo.
echo  삭제 중...
set /a DONE=0
set /a FAIL=0
set /a TICK=0
for /f "usebackq delims=" %%L in ("%LIST%") do (
  del /f /q "%%L" 2>nul
  if exist "%%L" (
    set /a FAIL+=1
    echo  [실패] %%L
  ) else (
    set /a DONE+=1
    set /a TICK+=1
    if !TICK! geq 500 (
      echo    !DONE! / %FILES%
      set /a TICK=0
    )
  )
)

echo.
echo  ------------------------------------------------
echo   삭제 완료 : !DONE! 개
if !FAIL! gtr 0 echo   실패      : !FAIL! 개
echo  ------------------------------------------------

:cleanup
if exist "%LIST%" del /q "%LIST%"
if exist "%ORPH%" del /q "%ORPH%"

:done
echo.
pause
endlocal
