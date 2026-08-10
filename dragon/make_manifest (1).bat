@echo off
setlocal EnableExtensions EnableDelayedExpansion
title manifest.json 생성

rem ============================================================
rem  dragon\{번호}\ 를 훑어서 manifest.json 을 만듭니다.
rem  json / atlas / png 세 짝이 모두 있는 세트만 담습니다.
rem  (폴더 이름이 숫자인지는 검사하지 않습니다. 세 짝이 없으면
rem   어차피 드래곤 폴더가 아니므로 자동으로 걸러집니다)
rem
rem  결과: dragon\manifest.json  (저장소에 같이 올리세요)
rem  사용법: 이 파일을 dragon 폴더에 두고 더블클릭
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

set "OUT=%ROOT%\manifest.json"
set "EMPTYLOG=%TEMP%\dv_empty_%RANDOM%.txt"
if exist "%EMPTYLOG%" del /q "%EMPTYLOG%"

echo.
echo  대상 폴더 : %ROOT%
echo  생성 중...
echo.

set /a TOTAL=0
set /a DRAGONS=0
set /a SETS=0
set /a EMPTY=0
set "FIRST=1"

> "%OUT%" (
  echo {
  for /d %%D in ("%ROOT%\*") do (
    set /a TOTAL+=1
    set "ITEMS="

    for %%J in ("%%D\*.json") do (
      if exist "%%~dpnJ.atlas" if exist "%%~dpnJ.png" (
        set /a SETS+=1
        if defined ITEMS set "ITEMS=!ITEMS!,"%%~nJ""
        if not defined ITEMS set "ITEMS="%%~nJ""
      )
    )

    if not defined ITEMS set /a EMPTY+=1
    if not defined ITEMS >>"%EMPTYLOG%" echo %%~nxD

    if defined ITEMS set /a DRAGONS+=1
    if defined ITEMS if defined FIRST echo "%%~nxD":[!ITEMS!]
    if defined ITEMS if not defined FIRST echo ,"%%~nxD":[!ITEMS!]
    if defined ITEMS set "FIRST="
  )
  echo }
)

if not exist "%OUT%" (
  echo  [오류] manifest.json 을 만들지 못했습니다.
  goto :done
)

for %%F in ("%OUT%") do set "BYTES=%%~zF"

echo  ------------------------------------------------
echo   전체 폴더       : %TOTAL% 개
echo   기록된 드래곤   : %DRAGONS% 개
echo   세트 합계       : %SETS% 개
echo   세트가 없는 폴더: %EMPTY% 개
echo   manifest.json   : %BYTES% 바이트
echo  ------------------------------------------------

if %EMPTY% gtr 0 (
  echo.
  echo  [json+atlas+png 세 짝이 없어 제외된 폴더]
  set /a N=0
  for /f "usebackq delims=" %%L in ("%EMPTYLOG%") do (
    set /a N+=1
    if !N! leq 15 echo    "%%L"
  )
)

echo.
echo  위치: %OUT%
echo.
echo  미리보기 3줄:
set /a N=0
for /f "usebackq delims=" %%L in ("%OUT%") do (
  set /a N+=1
  if !N! leq 3 echo    %%L
)

if exist "%EMPTYLOG%" del /q "%EMPTYLOG%"

:done
echo.
pause
endlocal
